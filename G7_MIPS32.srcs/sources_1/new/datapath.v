`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Datapath (DP)
// Description: Datapath for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

module datapath(
    input  wire        i_clk,           
    input  wire        i_rst,           
    input  wire        i_en,            
    input  wire [31:0] i_instr,         // Current instruction word (from IMEM)
    input  wire [31:0] i_rdata,         // Data from DMEM (valid one cycle after address)
    input  wire        i_reg_dst,       // 0 = write rt, 1 = write rd
    input  wire        i_alu_src,       // 0 = ALU B = rt, 1 = ALU B = immediate
    input  wire        i_mem_to_reg,    // 0 = WB = ALU, 1 = WB = memory
    input  wire        i_reg_write,     // 1 = commit to register file
    input  wire        i_branch,        // 1 = branch instruction
    input  wire        i_jump,          // 1 = jump instruction
    input  wire        i_jump_reg,      // 1 = jump target is register rs
    input  wire        i_link,          // 1 = write PC+4 to the selected destination
    
    input  wire [3:0]  i_branch_cond,   // Branch condition code
    input  wire [3:0]  i_alu_ctrl,      // ALU operation select
    
    input  wire        i_mem_read,      // 1 when the CU decodes LW

    output wire [31:0] o_pc,            // IMEM byte address
    output wire [31:0] o_alu_out,       // ALU result,   o_y
    output wire [31:0] o_wdata,         // Store data (register target, rt, value for sw)
    
    output wire        o_imem_en,       // ROM enable: prime or retire
    output wire        o_load_issue,    // Start one synchronous RAM read
    output wire        o_commit         // Complete the current instruction
    );

    reg        _rom_ready;     // The ROM has returned its first instruction.
    reg        _load_pending;  // The held LW has issued its RAM read.
    reg [31:0] _pc_r;

    wire _stall = _rom_ready && i_mem_read && !_load_pending;
    wire _enabled = i_en && !i_rst;

    assign o_commit     = _enabled && _rom_ready && !_stall;
    assign o_load_issue = _enabled && _stall;
    assign o_imem_en    = _enabled && (!_rom_ready || o_commit);

    // Intermediate signals
    wire [31:0] _pc4;            // PC + 4 (next sequential address)
    wire [31:0] _br_tgt;         // Branch target address
    wire [31:0] _jmp_tgt;        // Jump target address
    wire [31:0] _imm_ext;        // Sign-extended 16-bit immediate
    wire [31:0] _imm_sl2;        // Immediate shifted left by 2 (×4)
    wire [31:0] _rd1_v;          // RF read port 1 (rs value)
    wire [31:0] _rd2_v;          // RF read port 2 (rt value)
    wire [31:0] _src_a;          // ALU operand A (shift amount for shifts, otherwise rs)
    wire [31:0] _src_b;          // ALU operand B (rt or immediate)
    wire [31:0] _wb;             // Final write-back value to RF
    wire [31:0] _ret_addr;       // link address = PC + 4
    wire [4:0]  _wa;             // RF write address from reg_dst mux (rt or rd)
    wire [4:0]  _wa_final;       // _wa with $ra override for jal
    wire        _branch_taken;   // Branch condition evaluated
    wire        _zero;           // Internal ALU zero flag for BEQ/BNE
    wire [31:0] _pc_next;        // Next PC value
    wire        _do_rf_we;       // Register file write enable

    // PC arithmetic
    assign _pc4 = _pc_r + 32'd4;

    // Priority: jump > branch taken > sequential
    assign _pc_next = i_jump ? (i_jump_reg ? _rd1_v : _jmp_tgt) :
                      (i_branch && _branch_taken) ? _br_tgt : _pc4;

    // The ROM holds the LW until its RAM result is ready.
    assign o_pc = o_commit ? _pc_next : _pc_r;

    // ALU operand A select
    // For shift instructions, ALU operand A = shamt (instruction[10:6])
    // For all other instructions, ALU operand A = rs value (from RF)
    // ALU control codes for shifts/rotate: SLL=0101, SRL=0110, ROTR=1000
    assign _src_a = (i_alu_ctrl == 4'b0101 ||
                     i_alu_ctrl == 4'b0110 ||
                     i_alu_ctrl == 4'b1000)
                    ? {27'b0, i_instr[10:6]} : _rd1_v;

    // Immediate / branch target
    sign_extend immediate_extend(
        .i_imm(i_instr[15:0]),
        .o_ext(_imm_ext)
    );

    shift_left_two branch_shift(
        .i_in(_imm_ext),
        .o_out(_imm_sl2)
    );

    assign _br_tgt  = _pc4 + _imm_sl2;                                  // PC+4 + (imm<<2)
    assign _jmp_tgt = {_pc4[31:28], i_instr[25:0], 2'b00};              // {PC+4[31:28], target, 00}

    // Register write address
    // i_reg_dst 0 = write rt, 1 = write rd
    // WHERE to write
    mux2_5bit reg_dst_mux(      
        .i_a(i_instr[20:16]),   // I-Type rt field
        .i_b(i_instr[15:11]),   // R-Type rd field
        .i_sel(i_reg_dst),
        .o_y(_wa)
    );

    // Write Address: If its a JAL the link forces the write address to be the reg 31 all '1's 
    assign _wa_final = (i_link && !i_jump_reg) ? 5'd31 : _wa;


    // Link address used by jal and jalr.
    assign _ret_addr = _pc4;

    // The held instruction still supplies its own destination and controls.
    assign _do_rf_we = o_commit && i_reg_write;

    // -------------------------------------------------------------------------
    // Register file
    // -------------------------------------------------------------------------
    register_file registers(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_we(_do_rf_we),
        .i_ra1(i_instr[25:21]),   // rs field wired from the instruction memory
        .i_ra2(i_instr[20:16]),   // rt field
        .i_wa(_wa_final),         // destination of the held instruction
        .i_wdata(_wb),            // write-back value
        .o_rd1(_rd1_v),           // rs value wired to the ALU
        .o_rd2(_rd2_v)            // rt value
    );

    assign o_wdata = _rd2_v;        // store data path (rt value for sw)

    // -------------------------------------------------------------------------
    // ALU operand select
    // if i_alu_src = 0, ALU operand B = rt value (from RF)
    // if i_alu_src = 1, ALU operand B = sign-extended immediate (from instruction)
    // sign
    // -------------------------------------------------------------------------
    mux2_32bit alu_src_mux(
        .i_a(_rd2_v),         
        .i_b(_imm_ext),     
        .i_sel(i_alu_src),
        .o_y(_src_b)        // Source B to ALU (rt or immediate)
    );

    // -------------------------------------------------------------------------
    // ALU
    // Performs arithmetic and logic operations on two 32-bit operands, producing a 32-bit result and a zero flag.
    // The operation is determined by the 4-bit control signal i_alu_ctrl.
    // -------------------------------------------------------------------------
    alu execution_unit(
        .i_a(_src_a),
        .i_b(_src_b),        // ALU operand B, takes the alu_src_mux output (rt or immediate)
        .i_ctrl(i_alu_ctrl),  // ALU control signals from CU
        .o_y(o_alu_out),      // ALU result (to DMEM address and/or WB )
        .o_zero(_zero)        // Internal ALU-to-BDU connection
    );

    // -------------------------------------------------------------------------
    // Branch decision unit
    // -------------------------------------------------------------------------
    bdu branch_decision_unit(
        .i_branch(i_branch),
        .i_branch_cond(i_branch_cond),
        .i_rs(_rd1_v),
        .i_zero(_zero),
        .o_branch_taken(_branch_taken)
    );

    // -------------------------------------------------------------------------
    // Write-back mux
    // WHAT to write back to the register file: ALU result, memory read data
    // -------------------------------------------------------------------------
    wire [31:0] _alu_mem;
    mux2_32bit mem_to_reg_mux(
        .i_a(o_alu_out),        // ALU result
        .i_b(i_rdata),          // memory read data
        .i_sel(i_mem_to_reg),
        .o_y(_alu_mem)
    );

    assign _wb = i_link ? _ret_addr : _alu_mem;

    always @(posedge i_clk) begin
        if (i_rst) begin
            _rom_ready    <= 1'b0;
            _load_pending <= 1'b0;
            _pc_r         <= 32'b0;
        end else if (i_en) begin
            _rom_ready    <= 1'b1;
            _load_pending <= o_load_issue;
            if (o_commit)
                _pc_r <= _pc_next;
        end
    end

endmodule
