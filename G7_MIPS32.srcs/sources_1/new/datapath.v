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
    input  wire [31:0] i_instr,
    input  wire [31:0] i_rdata,
    input  wire        i_reg_dst,
    input  wire        i_alu_src,
    input  wire        i_alu_a_shamt,
    input  wire        i_mem_to_reg,
    input  wire        i_rf_we,
    input  wire        i_link,
    input  wire        i_link_to_ra,
    input  wire [3:0]  i_alu_ctrl,
    input  wire [1:0]  i_pc_sel,
    input  wire        i_commit,

    output wire [31:0] o_pc,
    output wire [31:0] o_alu_out,
    output wire [31:0] o_wdata,
    output wire [31:0] o_rs_value,
    output wire        o_equal
    );

    reg [31:0] _pc_r;

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
    wire        _zero;           // ALU result is zero (debug)
    
    assign o_rs_value = _rd1_v;
    assign o_equal = (_rd1_v == _rd2_v);
    
    wire [31:0] _pc_next;        // Next PC value
    assign _pc4 = _pc_r + 32'd4;
    assign _pc_next = (i_pc_sel == 2'd3) ? _rd1_v :
                      (i_pc_sel == 2'd2) ? _jmp_tgt :
                      (i_pc_sel == 2'd1) ? _br_tgt : _pc4;
    assign o_pc = i_commit ? _pc_next : _pc_r;

    assign _src_a = i_alu_a_shamt ? {27'b0, i_instr[10:6]} : _rd1_v;

    // Extend the immediate to 32 bits, preserving its sign.
    assign _imm_ext = {{16{i_instr[15]}}, i_instr[15:0]};
    // Branch offsets count words; shift left two bits to obtain a byte offset.
    assign _imm_sl2 = _imm_ext << 2;

    // PC+4 + (imm<<2)
    assign _br_tgt  = _pc4 + _imm_sl2;
    // {PC+4[31:28], target, 00}                            
    assign _jmp_tgt = {_pc4[31:28], i_instr[25:0], 2'b00};

    // Register write address
    // i_reg_dst 0 = write rt, 1 = write rd
    // WHERE to write
    assign _wa = i_reg_dst ? i_instr[15:11] : i_instr[20:16];
    // Write Address: If its a JAL the link forces the write address to be the reg 31 all '1's 
    assign _wa_final = i_link_to_ra ? 5'd31 : _wa;


    // Link address used by jal and jalr.
    assign _ret_addr = _pc4;

    // Register file
    register_file registers(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_we(i_rf_we),
        .i_ra1(i_instr[25:21]),   // rs field wired from the instruction memory
        .i_ra2(i_instr[20:16]),   // rt field
        .i_wa(_wa_final),         // destination of the held instruction
        .i_wdata(_wb),            // write-back value
        .o_rd1(_rd1_v),           // rs value wired to the ALU
        .o_rd2(_rd2_v)            // rt value
    );

    assign o_wdata = _rd2_v;        // store data path (rt value for sw)

    // ALU operand select
    // if i_alu_src = 0, ALU operand B = rt value (from RF)
    // if i_alu_src = 1, ALU operand B = sign-extended immediate (from instruction)
    // sign
    assign _src_b = i_alu_src ? _imm_ext : _rd2_v;

    // ALU
    // Performs arithmetic and logic operations on two 32-bit operands, producing a 32-bit result and a zero flag.
    // The operation is determined by the 4-bit control signal i_alu_ctrl.
    alu execution_unit(
        .i_a(_src_a),
        .i_b(_src_b),        // ALU operand B, takes the alu_src_mux output (rt or immediate)
        .i_ctrl(i_alu_ctrl),  // ALU control signals from CU
        .o_y(o_alu_out),      // ALU result (to DMEM address and/or WB )
        .o_zero(_zero)
    );

    // Write-back mux
    // WHAT to write back to the register file: ALU result, memory read data
    wire [31:0] _alu_mem;
    assign _alu_mem = i_mem_to_reg ? i_rdata : o_alu_out;

    assign _wb = i_link ? _ret_addr : _alu_mem;

    always @(posedge i_clk) begin
        if (i_rst)
            _pc_r <= 32'b0;
        else if (i_commit)
            _pc_r <= _pc_next;
    end

endmodule
