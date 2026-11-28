`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Datapath (DP)
// Description: Datapath for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

module datapath(
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // Instruction ROM and data bus inputs
    input  wire [31:0] i_instr,
    input  wire [31:0] i_rdata,

    // ALU operand and operation selects
    input  wire        i_alu_a_shamt,
    input  wire        i_alu_src,
    input  wire [3:0]  i_alu_ctrl,

    // Register file and write-back control
    input  wire        i_reg_dst,
    input  wire        i_mem_to_reg,
    input  wire        i_link,
    input  wire        i_link_to_ra,
    input  wire        i_rf_we,

    // Program counter control
    input  wire [1:0]  i_pc_sel,
    input  wire        i_commit,

    // Interrupt request and vector
    input  wire        i_irq_request,
    input  wire [31:0] i_irq_vector,

    // Instruction ROM address
    output wire [31:0] o_pc,

    // Data bus address and write data
    output wire [31:0] o_alu_out,
    output wire [31:0] o_wdata,

    // Branch feedback to the control unit
    output wire [31:0] o_rs_value,
    output wire        o_equal,

    // Interrupt acceptance, return and saved address for MMIO reads
    output wire        o_irq_ack,
    output wire        o_irq_return,
    output wire [31:0] o_return_pc
    );

    // Instruction operand shared by the ALU and branch address calculation
    wire [31:0] _imm_ext;
    assign _imm_ext = {{16{i_instr[15]}}, i_instr[15:0]};

    // Register file read values are shared by the PC, ALU and data bus.
    wire [31:0] _rd1_v;  // rs
    wire [31:0] _rd2_v;  // rt

    // Program counter and instruction fetch
    reg  [31:0] _pc_r;
    wire [31:0] _pc4;
    wire [31:0] _imm_sl2;
    wire [31:0] _br_tgt;
    wire [31:0] _jmp_tgt;
    wire [31:0] _pc_next;

    assign _pc4 = _pc_r + 32'd4;
    assign _imm_sl2 = _imm_ext << 2;  // Convert the branch word offset to bytes.
    assign _br_tgt = _pc4 + _imm_sl2;
    assign _jmp_tgt = {_pc4[31:28], i_instr[25:0], 2'b00};

    // The control unit selects a register jump, direct jump, branch or PC + 4.
    assign _pc_next = (i_pc_sel == 2'd3) ? _rd1_v :
                      (i_pc_sel == 2'd2) ? _jmp_tgt :
                      (i_pc_sel == 2'd1) ? _br_tgt : _pc4;

    // Present the next address to the synchronous ROM on the commit edge.
    // Before the first commit or during a stall, keep the current address.
    // IRQ entry selects the vector. Software stacks the saved addresses.
    reg [1:0]  irq_depth;
    reg [31:0] saved_pc;
    wire irq_active = (irq_depth != 2'd0);

    // JR $k1 uses the normal jump target and also ends one IRQ level.
    wire jr_k1 = (i_instr[31:26] == 6'h00) &&
                 (i_instr[25:21] == 5'd27) && (i_instr[5:0] == 6'h08);
    wire return_irq = i_commit && irq_active && jr_k1;
    wire take_irq = !i_rst && i_commit && i_irq_request &&
                    !return_irq && (irq_depth < 2'd2);
    wire [31:0] committed_next_pc = take_irq ? i_irq_vector : _pc_next;

    assign o_irq_ack = take_irq;
    assign o_irq_return = return_irq;
    assign o_return_pc = saved_pc;
    assign o_pc = i_commit ? committed_next_pc : _pc_r;

    always @(posedge i_clk) begin
        if (i_rst) begin
            irq_depth <= 2'd0;
            saved_pc  <= 32'b0;
        end else if (return_irq) begin
            irq_depth <= irq_depth - 2'd1;
        end else if (take_irq) begin
            irq_depth <= irq_depth + 2'd1;
            saved_pc  <= _pc_next;  // The ISR reads this before enabling IRQs.
        end
    end

    always @(posedge i_clk) begin
        if (i_rst)
            _pc_r <= 32'b0;
        else if (i_commit)
            _pc_r <= committed_next_pc;
    end

    // ALU operands and result
    wire [31:0] _src_a;
    wire [31:0] _src_b;
    wire        _zero;  // ALU zero flag for debug

    assign _src_a = i_alu_a_shamt ? {27'b0, i_instr[10:6]} : _rd1_v;
    assign _src_b = i_alu_src ? _imm_ext : _rd2_v;

    alu execution_unit(
        .i_a(_src_a),
        .i_b(_src_b),

        .i_ctrl(i_alu_ctrl),

        .o_y(o_alu_out),  // ALU result or data-bus byte address
        .o_zero(_zero)
    );

    // Register file destination and write-back data
    wire [4:0]  _wa;
    wire [4:0]  _wa_final;
    wire [31:0] _ret_addr;
    wire [31:0] _alu_mem;
    wire [31:0] _wb;

    assign _wa = i_reg_dst ? i_instr[15:11] : i_instr[20:16];  // rd or rt
    assign _wa_final = i_link_to_ra ? 5'd31 : _wa;            // JAL writes $ra.
    assign _ret_addr = _pc4;                                 // JAL and JALR link value
    assign _alu_mem = i_mem_to_reg ? i_rdata : o_alu_out;
    assign _wb = i_link ? _ret_addr : _alu_mem;

    register_file registers(
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_ra1(i_instr[25:21]),
        .i_ra2(i_instr[20:16]),

        .i_we(i_rf_we),
        .i_wa(_wa_final),
        .i_wdata(_wb),

        .o_rd1(_rd1_v),
        .o_rd2(_rd2_v)
    );

    // Store data and branch feedback
    assign o_wdata = _rd2_v;  // SW sends the rt value to the data bus.
    assign o_rs_value = _rd1_v;
    assign o_equal = (_rd1_v == _rd2_v);

endmodule
