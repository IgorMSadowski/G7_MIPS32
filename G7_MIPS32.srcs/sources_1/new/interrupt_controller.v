`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Interrupt Controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Interrupt Controller for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

module interrupt_controller(
    input wire i_clk,
    input wire i_reset,
    input wire events[3:0],
    input wire i_irq_ack,
    input wire i_return_pc[31:0],

    input wire i_offset[7:0],
    input wire i_en,
    input wire i_we,
    input wire i_wdata[31:0],

    output wire o_irq_request,
    output wire o_irq_vector[31:0],

    output wire o_rdata[31:0],
);

    reg global_enable;
    reg source_enable[3:0];
    reg pending[3:0];
    reg selected[3:0];

    wire eligible[3:0] = pending & source_enable;
    assign o_irq_request = global_enable && (|eligible);






endmodule





    output reg  [31:0] o_irq_vector,
    output reg  [31:0] o_rdata
);

    reg        global_enable;
    reg [3:0]  source_enable;
    reg [3:0]  pending;
    reg [3:0]  selected;

    wire [3:0] eligible = pending & source_enable;
    assign o_irq_request = global_enable && (|eligible);

    always @(*) begin
        selected = 4'b0000;
        o_irq_vector = 32'b0;

        if (o_irq_request) begin
            if (eligible[0]) begin
                selected = 4'b0001;
                o_irq_vector = 32'h00000004;
            end else if (eligible[1]) begin
                selected = 4'b0010;
                o_irq_vector = 32'h00000008;
            end else if (eligible[2]) begin
                selected = 4'b0100;
                o_irq_vector = 32'h0000000C;
            end else begin
                selected = 4'b1000;
                o_irq_vector = 32'h00000010;
            end
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            global_enable <= 1'b0;
            source_enable <= 4'b0000;
            pending       <= 4'b0000;
            o_rdata       <= 32'b0;
        end else begin
            if (i_we && i_offset == 8'h00) begin
                global_enable <= i_wdata[4];
                source_enable <= i_wdata[3:0];
            end

            // Clear the accepted source. A new event on this edge stays pending.
            if (i_irq_ack)
                pending <= (pending & ~selected) | events;
            else
                pending <= pending | events;

            // Capture the reply on the read edge and hold it for LW write-back.
            if (i_re) begin
                case (i_offset)
                    8'h00:   o_rdata <= {27'b0, global_enable, source_enable};
                    8'h04:   o_rdata <= {28'b0, pending};
                    8'h08:   o_rdata <= i_return_pc;
                    default: o_rdata <= 32'b0;
                endcase
            end
        end
    end

endmodule



datapath
reg        irq_active;
reg [31:0] saved_pc;

// jr_k1 is high when the current instruction is JR $k1.
wire return_irq = o_commit && irq_active && jr_k1;
wire take_irq = !i_rst && o_commit && irq_request && !irq_active;

assign irq_ack = take_irq;  // Sampled on the same edge as interrupt entry

wire [31:0] committed_next_pc = take_irq ? irq_vector : _pc_next;

always @(posedge i_clk) begin
    if (i_rst) begin
        irq_active <= 1'b0;
        saved_pc   <= 32'b0;
    end else if (return_irq) begin
        irq_active <= 1'b0;
    end else if (take_irq) begin
        irq_active <= 1'b1;
        saved_pc   <= _pc_next;
    end
end