`timescale 1ns / 1ps

module I2S #(
    // Positive number of i_clk cycles per half BCK period.
    // At 50 MHz, 8 gives 3.125 MHz BCK and a 48.828125 kHz sample rate.
    parameter integer CLOCKS_PER_HALF_BIT = 8
)(
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // Sample input
    input  wire [31:0] i_sample,      // Left [31:16], right [15:0]
    input  wire        i_sample_valid, // Submit when o_sample_ready is high

    // Sample handshake
    output wire        o_sample_ready, // A frame can be queued

    // I2S serial interface
    output reg         o_bck,
    output reg         o_lrck,        // 0 = left, 1 = right
    output reg         o_din
);

    localparam integer COUNTER_WIDTH = (CLOCKS_PER_HALF_BIT <= 1) ? 1 : $clog2(CLOCKS_PER_HALF_BIT);
    localparam integer LAST_HALF_BIT_CLOCK = CLOCKS_PER_HALF_BIT - 1;

    reg [COUNTER_WIDTH-1:0] clock_count;
    reg [5:0] frame_bit;  // Two 32-bit slots per stereo frame
    reg [31:0] queued_sample;
    reg        sample_pending;
    reg [31:0] sample_shift;

    wire half_bit_done = (clock_count == LAST_HALF_BIT_CLOCK[COUNTER_WIDTH-1:0]);
    wire frame_start = half_bit_done && o_bck && (frame_bit == 6'd0);

    assign o_sample_ready = !i_rst && !sample_pending;

    always @(posedge i_clk) begin
        if (i_rst) begin
            queued_sample  <= 32'd0;
            sample_pending <= 1'b0;
        end else if (i_sample_valid && o_sample_ready) begin
            queued_sample  <= i_sample;
            sample_pending <= 1'b1;
        end else if (frame_start) begin
            sample_pending <= 1'b0;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            clock_count  <= 0;
            frame_bit    <= 6'd0;
            sample_shift <= 32'd0;
            o_bck        <= 1'b0;
            o_lrck       <= 1'b1;
            o_din        <= 1'b0;
        end else if (half_bit_done) begin
            clock_count <= 0;
            o_bck <= ~o_bck;

            // Old BCK is high here, so the outputs change on its falling edge.
            if (o_bck) begin
                frame_bit <= frame_bit + 6'd1;

                if (frame_bit[4:0] == 5'd0) begin
                    o_lrck <= frame_bit[5];
                    o_din  <= 1'b0;
                    if (frame_bit == 6'd0)
                        sample_shift <= sample_pending ? queued_sample : 32'd0;
                end else if (frame_bit[4:0] <= 5'd16) begin
                    // The MSB comes one BCK after LRCK changes.
                    o_din <= sample_shift[31];
                    sample_shift <= {sample_shift[30:0], 1'b0};
                end else begin
                    o_din <= 1'b0;
                end
            end
        end else begin
            clock_count <= clock_count + 1'b1;
        end
    end

endmodule
