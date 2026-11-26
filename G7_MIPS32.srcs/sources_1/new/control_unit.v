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


module control_unit(
    // Clock, reset and CPU enable
    input  wire        i_clk,
    input  wire        i_rst,           // Active-high synchronous reset
    input  wire        i_en,            // Enables instruction execution

    // Branch feedback from the datapath
    input  wire [31:0] i_rs_value,      // Value used by branches against zero
    input  wire        i_equal,         // rs == rt for BEQ and BNE

    // Instruction fields
    input  wire [5:0]  i_op,
    input  wire [4:0]  i_rs,
    input  wire [4:0]  i_shamt,
    input  wire [4:0]  i_rt,
    input  wire [5:0]  i_funct,

    // ALU and register controls
    output reg         o_reg_dst,      // 0 = rt, 1 = rd
    output reg         o_alu_src,      // ALU B: 0 = rt value, 1 = immediate
    output reg         o_mem_to_reg,   // Write-back: 0 = ALU, 1 = memory
    output reg         o_reg_write,    // Decoded instruction writes a register

    // Decoded memory requests
    output reg         o_mem_read,     // Instruction is LW
    output reg         o_mem_write,    // Instruction is SW

    // Control flow
    output reg         o_branch,       // Instruction is a conditional branch
    output reg         o_jump,         // Instruction is a jump
    output reg         o_jump_reg,     // Jump target comes from rs
    output reg         o_link,         // Select PC + 4 for write-back
    output reg [3:0]   o_branch_cond,  // Comparison to perform in the BDU

    // ALU and datapath mux selects
    output reg [3:0]   o_alu_ctrl,     // ALU operation
    output wire        o_alu_a_shamt,  // ALU A: 0 = rs value, 1 = shamt
    output wire        o_link_to_ra,   // JAL forces the write address to $ra
    output wire [1:0]  o_pc_sel,       // 0 = PC + 4, 1 = branch, 2 = jump, 3 = rs

    // Cycle control and enables
    output wire        o_rf_we,        // Write a register on the commit edge
    output wire        o_load_issue,   // Start the LW read on its first edge
    output wire        o_store_commit, // Enable the data bus write on the store edge
    output wire        o_imem_en,      // Fetch the first or next instruction
    output wire        o_commit        // Allow the instruction to complete
    );

    // Fetch and load state
    reg _rom_ready;     // Set after the first instruction fetch
    reg _load_pending;  // Set after the LW read so it can write back next cycle

    // Branch result and cycle conditions
    wire _branch_taken; // The BDU comparison passed for the current branch
    wire _run = i_en && !i_rst;
    wire _stall = _rom_ready && o_mem_read && !_load_pending; // First cycle of LW

    assign o_load_issue = _run && _stall;
    assign o_commit = _run && _rom_ready && !_stall;
    assign o_imem_en = _run && (!_rom_ready || o_commit);
    assign o_rf_we = o_commit && o_reg_write;
    assign o_store_commit = o_commit && o_mem_write;

    assign o_alu_a_shamt = (o_alu_ctrl == 4'b0101) ||
                          (o_alu_ctrl == 4'b0110) ||
                          (o_alu_ctrl == 4'b1000);
                          
    assign o_link_to_ra = o_link && !o_jump_reg;
    assign o_pc_sel = o_jump ? (o_jump_reg ? 2'd3 : 2'd2) :
                       _branch_taken ? 2'd1 : 2'd0;


    // Branch decision unit instantiation
    bdu branch_decision_unit(
        .i_branch(o_branch),
        .i_branch_cond(o_branch_cond),
        .i_rs(i_rs_value),
        .i_equal(i_equal),
        .o_branch_taken(_branch_taken)
    );

    //update the _rom_ready and _load_pending flags on each clock cycle
    always @(posedge i_clk) begin
        if (i_rst) begin
            _rom_ready <= 1'b0;
            _load_pending <= 1'b0;
        end else if (i_en) begin
            _rom_ready <= 1'b1;
            _load_pending <= o_load_issue;
        end
    end

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
        o_alu_ctrl    = 4'b0000;// alu function control (default to add)

        // Decode table by instruction format
        // MIPS instruction formats:
        //   - R-type:  op = 0x00, funct decides the exact operation
        //   - I-type:  op gives the operation, immediate is used in the instruction
        //   - J-type:  op gives the operation, target is encoded in the address field
        case (i_op)
            // R-type format (opcode = 000000)
            // Format: [op=6][rs=5][rt=5][rd=5][shamt=5][funct=6]
            // Here, the funct field selects the ALU operation.
            6'b000000: begin
                o_reg_dst   = 1'b1;     // Write result to rd
                o_reg_write = 1'b1;     // General register write enable

                case (i_funct)
                    6'h20: o_alu_ctrl = 4'b0000;    // add
                    6'h22: o_alu_ctrl = 4'b0001;    // sub
                    6'h24: o_alu_ctrl = 4'b0010;    // and
                    6'h25: o_alu_ctrl = 4'b0011;    // or
                    6'h2A: o_alu_ctrl = 4'b1010;    // slt
                    6'h26: o_alu_ctrl = 4'b0111;    // xor
                    6'h00: o_alu_ctrl = 4'b0101;    // sll
                    // MIPS32: bits 25:22 must be zero; bit 21 selects SRL/ROTR.
                    6'h02: begin
                        case (i_rs)
                            5'b00000: o_alu_ctrl = 4'b0110; // SRL
                            5'b00001: o_alu_ctrl = 4'b1000; // ROTR
                            default: o_reg_write = 1'b0; // unsupported encoding
                        endcase
                    end
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
                    default: o_reg_write = 1'b0; // unsupported funct has no state effect
                endcase
            end

            6'h1F: begin // SPECIAL3
                if (i_funct == 6'h20 && i_shamt == 5'd2 && i_rs == 5'd0) begin
                    o_reg_dst   = 1'b1;
                    o_reg_write = 1'b1;
                    o_alu_ctrl  = 4'b1001; // wsbh
                end
            end

            // I-type format (opcode = immediate-based instructions)
            // Format: [op=6][rs=5][rt=5][imm=16]
            // The operation is determined by the opcode, while the lower bits
            // carry the sign-extended immediate value.
            6'h04: begin    // beq   rs, rt, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0001;  // ALU subtraction result for debug
                o_branch_cond = 4'b0000; // branch if equal
            end

            6'h05: begin    // bne   rs, rt, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0001;  // ALU subtraction result for debug
                o_branch_cond = 4'b0001; // branch if not equal
            end

            // REGIMM
            6'h01: begin    // bltz and bgez
                o_branch    = 1'b1;
                case (i_rt)
                    5'b00000: o_branch_cond = 4'b0010; // bltz
                    5'b00001: o_branch_cond = 4'b0011; // bgez
                    default: o_branch = 1'b0; // unsupported REGIMM selector: no branch
                endcase
            end

            6'h07: begin    // bgtz  rs, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0001;  // subtract to compare rs - 0
                o_branch_cond = 4'b0101; // branch if greater than zero
            end

            6'h06: begin    // blez  rs, offset
                o_branch    = 1'b1;
                o_alu_ctrl  = 4'b0001;  // subtract to compare rs - 0
                o_branch_cond = 4'b0100; // branch if less than or equal to zero
            end

            6'h08: begin    // addi  rt, rs, imm
                o_alu_src   = 1'b1;
                o_reg_write = 1'b1;
                o_alu_ctrl  = 4'b0000;  // ADD
            end

            6'h23: begin    // lw    rt, imm(rs)
                o_alu_src    = 1'b1;
                o_mem_to_reg = 1'b1;
                o_reg_write  = 1'b1;
                o_mem_read   = 1'b1;
                o_alu_ctrl   = 4'b0000;  // effective address = rs + sign_ext(imm)
            end

            6'h2B: begin    // sw    rt, imm(rs)
                o_alu_src   = 1'b1;
                o_mem_write = 1'b1;
                o_alu_ctrl  = 4'b0000;  // effective address = rs + sign_ext(imm)
            end

            6'h0F: begin    // lui   rt, imm
                o_alu_src   = 1'b1;
                o_reg_write = 1'b1;
                o_alu_ctrl  = 4'b0100;  // LUI operation (shift left by 16)
            end

            // J-type format (opcode = jump instructions)
            // Format: [op=6][target=26]
            // The final target address is formed from the upper bits of PC+4 and
            // the 26-bit jump field, shifted left by 2 bits to keep word alignment.
            // This gives a jump region of 256 MB in the MIPS address space.
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
