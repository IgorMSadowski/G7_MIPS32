`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Core Processing Unit (CPU)
// Description: CPU core module that connects the control unit and datapath.
//              Includes an external write-enable gate on o_mem_write to prevent
//              stale memory writes during non-execution datapath FSM states.
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
    output wire [31:0] o_alu_out,       // ALU result / DMEM address
    output wire        o_zero,          // ALU zero flag
    output wire        o_mem_read,      // DMEM read enable (lw)
    output wire        o_mem_write      // DMEM write enable (sw) - gated
    );

    // Instruction fields and decoded control signals
    wire [5:0]  _op;                    // instruction[31:26] - opcode
    wire [5:0]  _funct;                 // instruction[5:0]   - R-type funct
    wire [4:0]  _rt;                    // instruction[20:16] - rt register number
    wire        _reg_dst;               // 0 = write rt, 1 = write rd
    wire        _alu_src;               // 0 = ALU B = rt, 1 = ALU B = immediate
    wire        _mem_to_reg;            // 0 = WB = ALU, 1 = WB = memory
    wire        _reg_write;             // 1 = write to Register File
    wire        _branch;                // 1 = branch
    wire        _jump;                  // 1 = jump
    wire        _jump_reg;              // jump target comes from register rs
    wire        _link;                  // write PC+4 to the link destination
    wire [3:0]  _alu_ctrl;              // ALU operation select
    wire [3:0]  _branch_cond;           // Branch condition code

    wire        _mem_read;              // from CU, drives both CPU output and datapath
    wire        _mem_write_raw;         // Raw CU mem_write (may be stale during non-EXEC states)
    wire        _state_exec;            // From datapath: 1 only in S_EXEC

    // Instruction field extraction
    assign _op    = i_instr[31:26];
    assign _funct = i_instr[5:0];
    assign _rt    = i_instr[20:16];

    control_unit u_cu(
        .i_op(_op),
        .i_rt(_rt),
        .i_funct(_funct),
        .o_reg_dst(_reg_dst),
        .o_alu_src(_alu_src),
        .o_mem_to_reg(_mem_to_reg),
        .o_reg_write(_reg_write),
        .o_mem_read(_mem_read),        // Connected to internal wire _mem_read
        .o_mem_write(_mem_write_raw),   // captured raw; gated below
        .o_branch(_branch),
        .o_jump(_jump),
        .o_jump_reg(_jump_reg),
        .o_link(_link),
        .o_alu_ctrl(_alu_ctrl),
        .o_branch_cond(_branch_cond)
    );
    
    assign o_mem_read = _mem_read;      // CPU output port still reflects CU
    
    datapath u_dp(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(i_en),
        .i_instr(i_instr),
        .i_rdata(i_rdata),
        .i_reg_dst(_reg_dst),
        .i_alu_src(_alu_src),
        .i_mem_to_reg(_mem_to_reg),
        .i_reg_write(_reg_write),
        .i_branch(_branch),
        .i_jump(_jump),
        .i_jump_reg(_jump_reg),
        .i_link(_link),
        .i_alu_ctrl(_alu_ctrl),
        .i_branch_cond(_branch_cond),
        .i_mem_read(_mem_read),        
        .o_pc(o_pc),
        .o_alu_out(o_alu_out),
        .o_wdata(o_wdata),
        .o_zero(o_zero),
        .o_state_exec(_state_exec)
    );

    // -------------------------------------------------------------------------
    // WRITE GATE
    // -------------------------------------------------------------------------
    // During S_FETCH and S_LOAD, i_instr is either garbage or the next
    // instruction.  If that stale instruction happens to be "sw", the raw
    // o_mem_write would be 1 for an extra cycle, causing a double write.
    // AND-ing with _state_exec guarantees a store only commits in the exact
    // cycle it was decoded.
    assign o_mem_write = _mem_write_raw & _state_exec;

endmodule