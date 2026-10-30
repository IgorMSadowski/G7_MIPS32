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
    
    input  wire        i_mem_read,      // 1 when current insn is lw/lb (from CU)

    output wire [31:0] o_pc,            // IMEM address (current PC or pre-fetched PC+4)
    output wire [31:0] o_alu_out,       // ALU result,   o_y
    output wire [31:0] o_wdata,         // Store data (register target, rt, value for sw)
    output wire        o_zero,          // ALU zero flag
    
    output wire        o_state_exec     // 1 while in S_EXEC (used by cpu.v to gate mem_write)
    );

    // FSM state encoding
    localparam S_FETCH = 2'd0;   // post-reset prime: present PC=0 to IMEM
    localparam S_EXEC  = 2'd1;   // execute current insn; prefetch next
    localparam S_LOAD  = 2'd2;   // lw only: DMEM data valid, commit to RF

    reg [1:0]  _state;           // Current FSM state
    reg [31:0] _pc_r;            // Program counter register

    assign o_state_exec = (_state == S_EXEC);   // exported for cpu.v gate

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
    wire [31:0] _alu_mem;        // Mux output: ALU result or memory data
    wire [31:0] _wb;             // Final write-back value to RF
    wire [31:0] _wb_exec;        // Write-back during S_EXEC (non-load)
    wire [31:0] _ret_addr;       // link address = PC + 4
    wire [4:0]  _wa;             // RF write address from reg_dst mux (rt or rd)
    wire [4:0]  _wa_final;       // _wa with $ra override for jal
    wire [4:0]  _wa_use;         // _wa_final or _wa_hold (during S_LOAD)
    wire        _branch_taken;   // Branch condition evaluated
    wire [31:0] _pc_next;        // Next PC value
    wire [31:0] _imem_addr;      // Address presented to IMEM this cycle
    wire        _is_load;        // 1 if current insn is lw/lb
    wire        _do_rf_we;       // FSM-aware RF write enable

    // PC arithmetic
    assign _pc4 = _pc_r + 32'd4;

    // Priority: jump > branch taken > sequential
    assign _pc_next = i_jump ? (i_jump_reg ? _rd1_v : _jmp_tgt) :
                      (i_branch && _branch_taken) ? _br_tgt : _pc4;

    // During S_EXEC, present _pc_next to IMEM so the address is captured at
    // the upcoming posedge.  One cycle later, that instruction arrives on
    // i_instr - just in time.  This is why non-load instructions finish in
    // 1 cycle despite latency-1 BRAM.  Not pipelining - one instruction in
    // the datapath at a time.
    assign _imem_addr = (_state == S_EXEC) ? _pc_next : _pc_r;
    assign o_pc       = _imem_addr;

    assign _is_load = i_mem_read;   // mem_read comes from CU; 1 only for lw/lb
    assign _src_a = (i_alu_ctrl == 4'b1001 ||
                     i_alu_ctrl == 4'b1010 ||
                     i_alu_ctrl == 4'b1101)
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

    // hold write address across S_LOAD.
    // During S_LOAD, i_instr is already the NEXT instruction.  If we used the live rt field in S_LOAD
    // we'd write the load result into the wrong register.  Capture at end of S_EXEC (when the lw was still on the bus).
    reg [4:0] _wa_hold;         // Registered write address (holds lw's rt across S_LOAD)

    // If its load stores the write address to use later 
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst)                              _wa_hold <= 5'd0;
        else if (_state == S_EXEC && _is_load)  _wa_hold <= _wa_final;
    end

    // Write Address: If LOAD its the write address from the previous cycle, if not its the Final
    assign _wa_use = (_state == S_LOAD) ? _wa_hold : _wa_final;

    // -------------------------------------------------------------------------
    // FSM-aware register-file write enable
    //   S_EXEC : write non-load instructions only.
    //            For a load, the loaded data is not available yet
    //            (_wb would carry the load address, not the value),
    //            so the write must wait for S_LOAD.
    //   S_LOAD : write the load result.  The write address comes from
    //            _wa_hold because i_instr already points at the next
    //            instruction, whose rt/rd fields are wrong for this load.
    //   S_FETCH: never write.
    // -------------------------------------------------------------------------
    // Do Register File Write Enable
    // 0 dont change, 1 take _wb and overwrite the register chosen by _wa_use
    assign _do_rf_we = ((_state == S_EXEC) & i_reg_write & ~_is_load) | (_state == S_LOAD);

    // -------------------------------------------------------------------------
    // Register file
    // -------------------------------------------------------------------------
    register_file registers(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_we(_do_rf_we & i_en),
        .i_ra1(i_instr[25:21]),   // rs field wired from the instruction memory
        .i_ra2(i_instr[20:16]),   // rt field
        .i_wa(_wa_use),           // held address during S_LOAD
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
        .o_zero(o_zero)       // ALU zero flag (used by branch unit)
    );

    // -------------------------------------------------------------------------
    // Branch decision unit
    // -------------------------------------------------------------------------
    bdu branch_decision_unit(
        .i_branch(i_branch),
        .i_branch_cond(i_branch_cond),
        .i_rs(_rd1_v),
        .i_zero(o_zero),
        .o_branch_taken(_branch_taken)
    );

    // -------------------------------------------------------------------------
    // Write-back mux
    // WHAT to write back to the register file: ALU result, memory read data
    // -------------------------------------------------------------------------
    mux2_32bit mem_to_reg_mux(
        .i_a(o_alu_out),        // ALU result
        .i_b(i_rdata),          // memory read data
        .i_sel(i_mem_to_reg),
        .o_y(_alu_mem)
    );

    // Writeback value 
    assign _wb_exec = i_link ? _ret_addr : _alu_mem;
    
    // If its a LOAD the writeback value is the read memory value. If not its the Writeback_Execute Value
    assign _wb      = (_state == S_LOAD) ? i_rdata : _wb_exec;   // loads force memory data

    // -------------------------------------------------------------------------
    // FSM + PC update
    // -------------------------------------------------------------------------
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            _state <= S_FETCH;
            _pc_r  <= 32'b0;
        end else if (i_en) begin
            case (_state)
                S_FETCH: _state <= S_EXEC;                        // one priming cycle

                S_EXEC: begin
                    _pc_r  <= _pc_next;                           // advance PC
                    _state <= _is_load ? S_LOAD : S_EXEC;         // lw needs one more cycle
                end

                S_LOAD: _state <= S_EXEC;                         // PC held; load commits
            endcase
        end
    end

endmodule