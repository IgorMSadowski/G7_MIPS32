`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Core Processing Unit (CPU)
// Description: Connects the control unit and datapath.
//////////////////////////////////////////////////////////////////////////////////

module cpu(
    // inputs
    input  wire        i_clk,           // System clock
    input  wire        i_rst,           // Active-high reset
    input  wire        i_en,            // Global enable
    input  wire [31:0] i_instr,         // Instruction word from IMEM
    input  wire [31:0] i_rdata,         // Read data from DMEM

    // outputs
    output wire [31:0] o_wdata,         // Store data to DMEM
    output wire [31:0] o_pc,            // IMEM address
    output wire        o_imem_en,       // ROM advances only when enabled
    output wire [31:0] o_alu_out,       // ALU result / DMEM address
    output wire        o_mem_read,      // DMEM read enable (lw)
    output wire        o_mem_write      // DMEM write enable (sw)
    );

    // Instruction fields and decoded control signals
    wire [5:0]  _op;                    // instruction[31:26] - opcode
    wire [4:0]  _rs;                    // instruction[25:21] - rs register number
    wire [5:0]  _funct;                 // instruction[5:0]   - R-type funct
    wire [4:0]  _rt;                    // instruction[20:16] - rt register number
    wire [4:0]  _shamt;                 // instruction[10:6] - shift/encoding field
    wire        _reg_dst;               // 0 = write rt, 1 = write rd
    wire        _alu_src;               // 0 = ALU B = rt, 1 = ALU B = immediate
    wire        _mem_to_reg;            // 0 = WB = ALU, 1 = WB = memory
    wire        _rf_we;
    wire        _link;
    wire        _link_to_ra;
    wire        _alu_a_shamt;
    wire [3:0]  _alu_ctrl;
    wire [1:0]  _pc_sel;
    wire [31:0] _rs_value;
    wire        _equal;
    wire        _commit;

    // Instruction field extraction
    assign _op    = i_instr[31:26];
    assign _rs    = i_instr[25:21];
    assign _funct = i_instr[5:0];
    assign _rt    = i_instr[20:16];
    assign _shamt = i_instr[10:6];

    control_unit u_cu(
        .i_clk(i_clk), .i_rst(i_rst), .i_en(i_en),
        .i_rs_value(_rs_value), .i_equal(_equal),
        .i_op(_op), .i_rs(_rs), .i_shamt(_shamt), .i_rt(_rt), .i_funct(_funct),
        .o_reg_dst(_reg_dst), .o_alu_src(_alu_src), .o_mem_to_reg(_mem_to_reg),
        .o_reg_write(), .o_mem_read(), .o_mem_write(),
        .o_branch(), .o_branch_cond(), .o_jump(), .o_jump_reg(),
        .o_link(_link), .o_alu_ctrl(_alu_ctrl),
        .o_alu_a_shamt(_alu_a_shamt), .o_link_to_ra(_link_to_ra),
        .o_pc_sel(_pc_sel), .o_rf_we(_rf_we), .o_commit(_commit),
        .o_imem_en(o_imem_en), .o_load_issue(o_mem_read), .o_store_commit(o_mem_write)
    );

    datapath u_dp(
        .i_clk(i_clk), .i_rst(i_rst), .i_instr(i_instr), .i_rdata(i_rdata),
        .i_reg_dst(_reg_dst), .i_alu_src(_alu_src), .i_mem_to_reg(_mem_to_reg),
        .i_link(_link), .i_alu_ctrl(_alu_ctrl),
        .i_alu_a_shamt(_alu_a_shamt), .i_link_to_ra(_link_to_ra),
        .i_pc_sel(_pc_sel), .i_rf_we(_rf_we), .i_commit(_commit),
        .o_rs_value(_rs_value), .o_equal(_equal),
        .o_pc(o_pc), .o_alu_out(o_alu_out), .o_wdata(o_wdata)
    );

endmodule
