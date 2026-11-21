`timescale 1ns / 1ps

module board_demo_io(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [1:0]  i_sw,
    input  wire        i_btn1,
    input  wire [7:0]  i_offset,
    input  wire        i_re,
    input  wire        i_we,
    input  wire [2:0]  i_led_pattern,
    output reg  [31:0] o_rdata,
    output reg  [2:0]  o_led
    );

    localparam [7:0] SWITCH_OFFSET = 8'h00;
    localparam [7:0] BUTTON_OFFSET = 8'h04;
    localparam [7:0] LED_OFFSET    = 8'h08;

    (* ASYNC_REG = "TRUE" *) reg [2:0] inputs_meta, inputs_sync;

    always @(posedge i_clk) begin
        inputs_meta <= {i_btn1, i_sw};
        inputs_sync <= inputs_meta;
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_rdata <= 32'b0;
            o_led   <= 3'b000;
        end else begin
            if (i_re) begin
                case (i_offset)
                    SWITCH_OFFSET: o_rdata <= {30'b0, inputs_sync[1:0]};
                    BUTTON_OFFSET: o_rdata <= {31'b0, inputs_sync[2]};
                    default:       o_rdata <= 32'b0;
                endcase
            end

            if (i_we && (i_offset == LED_OFFSET))
                o_led <= i_led_pattern;
        end
    end
endmodule
