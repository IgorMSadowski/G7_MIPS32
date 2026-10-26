#!/usr/bin/env python3
# python3 asm.py FILE.asm -l
"""
MIPS assembler for the G7 single-cycle CPU (Vivado project).

Supports the 24-instruction G7_ISA:
  R-type: add addu sub subu and or xor nor slt sll srl jr
  I-type: addi addiu lw sw beq bne bgtz blez bltz bgez
  J-type: j jal

Also accepts the pseudo-instruction: nop

Usage:
  python3 asm.py prog.asm                    # writes prog.mem
  python3 asm.py prog.asm -o my.mem          # custom output
  python3 asm.py prog.asm -l                 # print listing (addr + hex)
"""
import sys, re, argparse, os

REG = {
    'zero':0,'at':1,'v0':2,'v1':3,'a0':4,'a1':5,'a2':6,'a3':7,
    't0':8,'t1':9,'t2':10,'t3':11,'t4':12,'t5':13,'t6':14,'t7':15,
    's0':16,'s1':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,
    't8':24,'t9':25,'k0':26,'k1':27,'gp':28,'sp':29,'fp':30,'ra':31,
}

# mnemonic: (opcode, funct, kind)
#   'r'   rd, rs, rt          R-type arithmetic
#   'sh'  rd, rt, shamt       shift (source is rt, shamt is immediate)
#   'jr'  rs                  register jump
#   'i'   rt, rs, imm         I-type arithmetic (dest is rt)
#   'mem' rt, offset(rs)      load/store
#   'br2' rs, rt, target      branch with 2 reg compare
#   'br1' rs, target          branch with 1 reg (rt fixed by mnemonic)
#   'j'   target              jump
ISA = {
    'add':  (0x00, 0x20, 'r'),
    'addu': (0x00, 0x21, 'r'),
    'sub':  (0x00, 0x22, 'r'),
    'subu': (0x00, 0x23, 'r'),
    'and':  (0x00, 0x24, 'r'),
    'or':   (0x00, 0x25, 'r'),
    'xor':  (0x00, 0x26, 'r'),
    'nor':  (0x00, 0x27, 'r'),
    'slt':  (0x00, 0x2A, 'r'),
    'sll':  (0x00, 0x00, 'sh'),
    'srl':  (0x00, 0x02, 'sh'),
    'jr':   (0x00, 0x08, 'jr'),
    'addi':  (0x08, 0, 'i'),
    'addiu': (0x09, 0, 'i'),
    'lw':    (0x23, 0, 'mem'),
    'sw':    (0x2B, 0, 'mem'),
    'beq':   (0x04, 0, 'br2'),
    'bne':   (0x05, 0, 'br2'),
    'bgtz':  (0x07, 0, 'br1'),
    'blez':  (0x06, 0, 'br1'),
    'bltz':  (0x01, 0, 'br1'),
    'bgez':  (0x01, 0, 'br1'),
    'j':   (0x02, 0, 'j'),
    'jal': (0x03, 0, 'j'),
}

def reg(s):
    s = s.strip()
    if not s.startswith('$'): raise ValueError(f"bad register '{s}'")
    n = s[1:].lower()
    if n in REG: return REG[n]
    if n.isdigit() and 0 <= int(n) <= 31: return int(n)
    raise ValueError(f"unknown register '{s}'")

def imm(s):
    """Parse an immediate: decimal, 0x hex, 0b binary, may be negative."""
    return int(s.strip(), 0)

def parse_mem_op(s):
    """Parse '4($sp)', '($sp)', '4'."""
    s = s.strip()
    m = re.match(r'^(.+?)\(\s*(\$\w+)\s*\)$', s)
    if m:
        return imm(m.group(1)), reg(m.group(2))
    m = re.match(r'^\(\s*(\$\w+)\s*\)$', s)
    if m:
        return 0, reg(m.group(1))
    raise ValueError(f"bad memory operand '{s}' (expected 'offset($reg)')")

def resolve_target(tgt, labels, pc, lineno, is_jump=False):
    """
    Resolve a branch/jump target.

    - If `tgt` is a known label: return offset (branches) or absolute address (jumps).
    - Else if `tgt` is a numeric literal: return it as-is.
    - Else: raise a clear "undefined label" error listing the labels we do know.
    """
    tgt = tgt.strip()
    if tgt in labels:
        addr = labels[tgt]
        return addr if is_jump else (addr - (pc + 4)) // 4
    try:
        return imm(tgt)
    except ValueError:
        known = ', '.join(sorted(labels)) or '(none)'
        raise ValueError(
            f"line {lineno}: undefined label '{tgt}' "
            f"(known labels: {known})"
        )

def parse_file(path):
    out = []
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.split('#')[0].split(';')[0].strip()
            if not line:
                continue
            m = re.match(r'^(\w+):\s*(.*)$', line)
            if m:
                out.append((lineno, 'label', m.group(1)))
                line = m.group(2).strip()
                if not line:
                    continue
            parts = line.split(None, 1)
            mnem = parts[0].lower()
            ops = [p.strip() for p in parts[1].split(',')] if len(parts) > 1 else []
            out.append((lineno, 'instr', (mnem, ops)))
    return out

def assemble(in_path, out_path, listing=False):
    program = parse_file(in_path)

    # ---- pass 1: label addresses ----
    labels = {}
    pc = 0
    for lineno, kind, payload in program:
        if kind == 'label':
            if payload in labels:
                raise ValueError(f"line {lineno}: duplicate label '{payload}'")
            labels[payload] = pc
        elif kind == 'instr':
            pc += 4

    # ---- pass 2: emit ----
    words, listing_lines = [], []
    pc = 0
    for lineno, kind, payload in program:
        if kind != 'instr': continue
        mnem, ops = payload

        if mnem == 'nop':
            w = 0x00000000
            listing_lines.append((pc, lineno, mnem, w))
            words.append(w); pc += 4; continue

        if mnem not in ISA:
            raise ValueError(f"line {lineno}: unknown instruction '{mnem}'")
        opcode, funct, kind_op = ISA[mnem]

        if kind_op == 'r':
            if len(ops) != 3: raise ValueError(f"line {lineno}: '{mnem}' needs rd, rs, rt")
            rd, rs, rt = reg(ops[0]), reg(ops[1]), reg(ops[2])
            w = (opcode<<26)|(rs<<21)|(rt<<16)|(rd<<11)|(0<<6)|funct
        elif kind_op == 'sh':
            if len(ops) != 3: raise ValueError(f"line {lineno}: '{mnem}' needs rd, rt, shamt")
            rd, rt, sa = reg(ops[0]), reg(ops[1]), imm(ops[2])
            if not 0 <= sa <= 31: raise ValueError(f"line {lineno}: shamt out of range 0..31")
            w = (opcode<<26)|(0<<21)|(rt<<16)|(rd<<11)|(sa<<6)|funct
        elif kind_op == 'jr':
            if len(ops) != 1: raise ValueError(f"line {lineno}: 'jr' needs rs")
            rs = reg(ops[0])
            w = (opcode<<26)|(rs<<21)|(0<<16)|(0<<11)|(0<<6)|funct
        elif kind_op == 'i':
            if len(ops) != 3: raise ValueError(f"line {lineno}: '{mnem}' needs rt, rs, imm")
            rt, rs, im = reg(ops[0]), reg(ops[1]), imm(ops[2])
            w = (opcode<<26)|(rs<<21)|(rt<<16)|(im & 0xFFFF)
        elif kind_op == 'mem':
            if len(ops) != 2: raise ValueError(f"line {lineno}: '{mnem}' needs rt, offset(rs)")
            rt = reg(ops[0])
            off, rs = parse_mem_op(ops[1])
            w = (opcode<<26)|(rs<<21)|(rt<<16)|(off & 0xFFFF)
        elif kind_op == 'br2':
            if len(ops) != 3: raise ValueError(f"line {lineno}: '{mnem}' needs rs, rt, target")
            rs, rt = reg(ops[0]), reg(ops[1])
            off = resolve_target(ops[2], labels, pc, lineno)
            if not -32768 <= off <= 32767:
                raise ValueError(f"line {lineno}: branch offset out of range ({off})")
            w = (opcode<<26)|(rs<<21)|(rt<<16)|(off & 0xFFFF)
        elif kind_op == 'br1':
            if len(ops) != 2: raise ValueError(f"line {lineno}: '{mnem}' needs rs, target")
            rs = reg(ops[0])
            rt = 1 if mnem == 'bgez' else 0
            off = resolve_target(ops[1], labels, pc, lineno)
            if not -32768 <= off <= 32767:
                raise ValueError(f"line {lineno}: branch offset out of range ({off})")
            w = (opcode<<26)|(rs<<21)|(rt<<16)|(off & 0xFFFF)
        elif kind_op == 'j':
            if len(ops) != 1: raise ValueError(f"line {lineno}: '{mnem}' needs target")
            tpc = resolve_target(ops[0], labels, pc, lineno, is_jump=True)
            if tpc & 0x3:
                raise ValueError(f"line {lineno}: jump target must be word-aligned (0x{tpc:08X})")
            w = (opcode<<26)|((tpc >> 2) & 0x03FFFFFF)
        else:
            raise ValueError(f"line {lineno}: internal error kind={kind_op}")

        listing_lines.append((pc, lineno, mnem, w))
        words.append(w); pc += 4

    with open(out_path, 'w') as f:
        for w in words:
            f.write(f"{w:08X}\n")

    print(f"Wrote {len(words)} instructions to {out_path}")
    print(f"Labels: {', '.join(sorted(labels)) or '(none)'}")
    if listing:
        print(f"\n{'addr':>6} {'line':>4}  {'instr':<24} {'word':>10}")
        print('-' * 60)
        for p, ln, mn, w in listing_lines:
            print(f"{p:>6X} {ln:>4}  {mn:<24} 0x{w:08X}")

def main():
    ap = argparse.ArgumentParser(description="MIPS assembler for G7 single-cycle CPU")
    ap.add_argument('input', help=".asm file")
    ap.add_argument('-o', '--output', default=None,
                    help="output file (default: same name as input, .mem)")
    ap.add_argument('-l', '--listing', action='store_true')
    args = ap.parse_args()

    # If no output file is specified, derive it from the input file
    if args.output is None:
        base, _ = os.path.splitext(args.input)
        args.output = base + '.mem'

    try:
        assemble(args.input, args.output, args.listing)
    except (ValueError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()