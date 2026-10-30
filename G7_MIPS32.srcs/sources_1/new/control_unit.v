`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Control Unit (CU)
// Description: Control Unit for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

// ============================================================================
// COMMON ISA (17 Instructions) - Mandatory for all groups
// ============================================================================
// R-type:  [opcode = 0x00, ALU op selected by funct]
//   add      -> opcode 0x00, funct 0x20   [DONE], adds two registers and stores the result in a register
//   sub      -> opcode 0x00, funct 0x22   [DONE], subtracts two registers and stores the result in a register
//   and      -> opcode 0x00, funct 0x24   [DONE], performs bitwise AND on two registers and stores the result in a register
//   or       -> opcode 0x00, funct 0x25   [DONE], performs bitwise OR on two registers and stores the result in a register
//   slt      -> opcode 0x00, funct 0x2A   [DONE], sets a register to 1 if one register is less than another, otherwise sets it to 0
//   xor      -> opcode 0x00, funct 0x26   [DONE], performs bitwise XOR on two registers and stores the result in a register
//   sll      -> opcode 0x00, funct 0x00   [DONE], shifts a register left by a specified number of bits and stores the result in a register
//   srl      -> opcode 0x00, funct 0x02   [DONE], shifts a register right by a specified number of bits and stores the result in a register
//   jr       -> opcode 0x00, funct 0x08   [DONE], jumps to the address contained in a register (used for function returns)
//
// I-type:  [opcode selects instruction, rs/rt/imm = instr fields]
//   addi     -> opcode 0x08               [DONE], adds a register and an immediate value and stores the result in a register
//   lw       -> opcode 0x23               [DONE], loads a word from memory into a register
//   sw       -> opcode 0x2B               [DONE], stores a word from a register into memory
//   beq      -> opcode 0x04               [DONE], branches to a specified address if two registers are equal
//   bne      -> opcode 0x05               [DONE], branches to a specified address if two registers are not equal
//   lui      -> opcode 0x0F               [DONE], loads an immediate value into the upper half of a register, setting the lower half to zero
//
// J-type:  [opcode selects instruction, target = instr[25:0]]
//   j        -> opcode 0x02               [DONE], jumps to a specified address
//   jal      -> opcode 0x03               [DONE], jumps to a specified address and stores the return address in the link register ($ra)
//
// ============================================================================
// GROUP 7 ISA (7 Instructions) - Our custom subset
// ============================================================================
// I-type:  [opcode selects instruction, rs/rt/imm = instr fields]
//   bltz     -> opcode 0x01, rt = 0x00    [DONE], branches to a specified address if a register is less than zero
//   bgez     -> opcode 0x01, rt = 0x01    [DONE], branches to a specified address if a register is greater than or equal to zero
//   bgtz     -> opcode 0x07, rt = 0x00    [DONE], branches to a specified address if a register is greater than zero
//   blez     -> opcode 0x06, rt = 0x00    [DONE], branches to a specified address if a register is less than or equal to zero
//
// R-type:  [opcode = 0x00, ALU op selected by funct]
//   jalr     -> opcode 0x00, funct 0x09   [DONE], jumps to the address contained in a register and stores the return address in another register
//(PC = rs; writes rd = PC+4)
//   wsbh     -> opcode 0x1F, funct 0x20   [DONE], swaps the bytes in a word (word swap byte halfword)
//(SPECIAL3 format: rd = swap_bytes(rt))
//   rotr     -> opcode 0x00, funct 0x02   [DONE], rotates the bits in a register to the right by a specified number of bits
//(SPECIAL format: rs = 1, rd = rotate(rt))
// -----------------------------------------------------------------------------


module control_unit(
    input  wire [5:0] i_op,
    input  wire [4:0] i_rs,
    input  wire [4:0] i_rt,
    input  wire [5:0] i_funct,

    output reg         o_reg_dst,       // register destination select (0=rt, 1=rd)
    output reg         o_alu_src,       // alu source select (0=reg, 1=imm)
    output reg         o_mem_to_reg,    // memory to register select (0=ALU, 1=mem)
    output reg         o_reg_write,     // register file write enable
    output reg         o_mem_read,      // memory read enable
    output reg         o_mem_write,     // memory write enable
    output reg         o_branch,        // branch instruction flag
    output reg         o_jump,          // jump instruction flag
    output reg         o_jump_reg,      // jump target comes from register rs
    output reg         o_link,          // write PC+4 to the selected destination
    output reg [3:0]   o_branch_cond,   // branch condition code (4 bits)
    // ALU control signals (4 bits) to the ALU block, MIPS R-types instructions-
    // will have at most 4 bits of control, meaning 16 differents operations
    output reg [3:0]   o_alu_ctrl   
    );

    always @(*) begin
        // Default values for control signals
        o_reg_dst     = 1'b0;   // register destination select (0=rt, 1=rd)
        o_alu_src     = 1'b0;   // alu source select (0=reg, 1=imm)
        o_mem_to_reg  = 1'b0;   // memory to register select (0=ALU, 1=mem)
        o_reg_write   = 1'b0;   // register file write enable 
        o_mem_read    = 1'b0;   // memory read enable
        o_mem_write   = 1'b0;   // memory write enable
        o_branch      = 1'b0;   // branch instruction flag
        o_jump        = 1'b0;   // jump instruction flag
        o_jump_reg    = 1'b0;   // register-target jump flag
        o_link        = 1'b0;   // link flag
        o_branch_cond = 4'b0000; // branch condition code (4 bits)
        o_alu_ctrl    = 4'b0010;// alu function control (default to add)

        // ---------------------------------------------------------------------
        // Decode table by instruction format
        // ---------------------------------------------------------------------
        // MIPS instruction formats:
        //   - R-type:  op = 0x00, funct decides the exact operation
        //   - I-type:  op gives the operation, immediate is used in the instruction
        //   - J-type:  op gives the operation, target is encoded in the address field
        // ---------------------------------------------------------------------
        case (i_op)
            // -----------------------------------------------------------------
            // R-type format (opcode = 000000)
            // Format: [op=6][rs=5][rt=5][rd=5][shamt=5][funct=6]
            // Here, the funct field selects the ALU operation.
            // -----------------------------------------------------------------
            6'b000000: begin
                o_reg_dst   = 1'b1;     // Write result to rd
                o_reg_write = 1'b1;     // General register write enable

                case (i_funct)
                    6'h20: o_alu_ctrl = 4'b0010;    // add
                    6'h22: o_alu_ctrl = 4'b0110;    // sub
                    6'h24: o_alu_ctrl = 4'b0000;    // and
                    6'h25: o_alu_ctrl = 4'b0001;    // or
                    6'h2A: o_alu_ctrl = 4'b0111;    // slt
                    6'h26: o_alu_ctrl = 4'b0011;    // xor
                    6'h00: o_alu_ctrl = 4'b1001;    // sll
                    6'h02: o_alu_ctrl = (i_rs == 5'd1) ? 4'b1101 : 4'b1010; // rotr / srl
                    6'h08: begin                       // jr
                        o_jump = 1'b1;              // jump to address in rs
                        o_jump_reg = 1'b1;
                        o_reg_write = 1'b0;         // no register write for jr
                    end
                    6'h09: begin                       // jalr
                        o_jump = 1'b1;              // jump to address in rs
                        o_jump_reg = 1'b1;          // jump target comes from register rs
                        o_link = 1'b1;              // link: write return address to rd
                        o_reg_write = 1'b1;         // write return address to rd
                    end
                    default: o_alu_ctrl = 4'b0010;  // default to add for unsupported funct
                endcase
            end

            6'h1F: begin // SPECIAL3
                if (i_funct == 6'h20) begin
                    o_reg_dst   = 1'b1;
                    o_reg_write = 1'b1;
                    o_alu_ctrl  = 4'b1100; // wsbh
                end
            end

            // -----------------------------------------------------------------
            // I-type format (opcode = immediate-based instructions)
            // Format: [op=6][rs=5][rt=5][imm=16]
            // The operation is determined by the opcode, while the lower bits
            // carry the sign-extended immediate value.
            // -----------------------------------------------------------------
            6'h04: begin    // beq   rs, rt, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0110;  // subtract to compare rs - rt
                o_branch_cond = 4'b0000; // branch if equal
            end

            6'h05: begin    // bne   rs, rt, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0110;  // subtract to compare rs - rt
                o_branch_cond = 4'b0001; // branch if not equal
            end

            6'h01: begin    // bltz and bgez
                o_branch    = 1'b1;
                case (i_rt)
                    5'b00000: o_branch_cond = 4'b0010; // bltz
                    5'b00001: o_branch_cond = 4'b0011; // bgez
                    default: o_branch_cond = 4'b0000; // default to beq behavior
                endcase
            end

            6'h07: begin    // bgtz  rs, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0110;  // subtract to compare rs - 0
                o_branch_cond = 4'b0111; // branch if greater than zero
            end

            6'h06: begin    // blez  rs, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0110;  // subtract to compare rs - 0
                o_branch_cond = 4'b0110; // branch if less than or equal to zero
            end

            6'h08: begin    // addi  rt, rs, imm
                o_alu_src   = 1'b1;
                o_reg_write = 1'b1;
                o_alu_ctrl  = 4'b0010;  // ADD
            end

            6'h23: begin    // lw    rt, imm(rs)
                o_alu_src    = 1'b1;
                o_mem_to_reg = 1'b1;
                o_reg_write  = 1'b1;
                o_mem_read   = 1'b1;
                o_alu_ctrl   = 4'b0010;  // effective address = rs + sign_ext(imm)
            end

            6'h2B: begin    // sw    rt, imm(rs)
                o_alu_src   = 1'b1;
                o_mem_write = 1'b1;
                o_alu_ctrl  = 4'b0010;  // effective address = rs + sign_ext(imm)
            end

            6'h0F: begin    // lui   rt, imm
                o_alu_src   = 1'b1;
                o_reg_write = 1'b1;
                o_alu_ctrl  = 4'b1000;  // LUI operation (shift left by 16)
            end

            // -----------------------------------------------------------------
            // J-type format (opcode = jump instructions)
            // Format: [op=6][target=26]
            // The final target address is formed from the upper bits of PC+4 and
            // the 26-bit jump field, shifted left by 2 bits to keep word alignment.
            // This gives a jump region of 256 MB in the MIPS address space.
            // -----------------------------------------------------------------
            6'h02: begin    // j    target
                o_jump = 1'b1;
            end

            6'h03: begin    // jal  target
                o_jump    = 1'b1;
                o_link    = 1'b1; 
                o_reg_write = 1'b1;
            end

            // Unsupported or not-yet-implemented instruction opcodes
            default: begin
                // Keep all control signals at their safe default values.
            end
        endcase

    end

endmodule