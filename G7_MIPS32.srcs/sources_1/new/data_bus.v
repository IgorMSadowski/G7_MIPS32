`timescale 1ns / 1ps

// Routes word accesses to RAM or ParIO and keeps one read response for LOAD.
module data_bus(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire [31:0] i_address,
    input  wire        i_read_request,
    input  wire        i_write_request,
    input  wire [31:0] i_ram_read_data,
    input  wire [31:0] i_pario_read_data,
    input  wire        i_load_complete,
    output wire        o_ram_read_enable,
    output wire        o_ram_write_enable,
    output wire        o_pario_read_enable,
    output wire        o_pario_write_enable,
    output reg  [31:0] o_read_data,
    output wire        o_read_response_valid
    );

    localparam [31:0] PARIO_ADDRESS = 32'h8000_0000;
    localparam [1:0] NO_READ = 2'd0, READ_FROM_RAM = 2'd1, READ_FROM_PARIO = 2'd2;

    wire access_enabled = i_en && !i_rst;
    wire word_aligned = (i_address[1:0] == 2'b00);
    wire ram_selected = word_aligned && (i_address[31:8] == 24'b0);
    wire pario_selected = (i_address == PARIO_ADDRESS);

    assign o_ram_read_enable = access_enabled && ram_selected && i_read_request;
    assign o_ram_write_enable = access_enabled && ram_selected && i_write_request;
    assign o_pario_read_enable = access_enabled && pario_selected && i_read_request;
    assign o_pario_write_enable = access_enabled && pario_selected && i_write_request;

    reg [1:0] read_source;
    reg [31:0] saved_pario_data;

    // RAM already registers its output. Capture ParIO inputs on the request edge.
    always @(posedge i_clk) begin
        if (i_rst) begin
            read_source <= NO_READ;
            saved_pario_data <= 32'b0;
        end else if (o_ram_read_enable) begin
            read_source <= READ_FROM_RAM;
        end else if (o_pario_read_enable) begin
            read_source <= READ_FROM_PARIO;
            saved_pario_data <= i_pario_read_data;
        end else if (i_load_complete) begin
            read_source <= NO_READ;
        end
    end

    assign o_read_response_valid = (read_source != NO_READ);

    always @(*) begin
        case (read_source)
            READ_FROM_RAM:   o_read_data = i_ram_read_data;
            READ_FROM_PARIO: o_read_data = saved_pario_data;
            default:         o_read_data = 32'b0;
        endcase
    end
endmodule
