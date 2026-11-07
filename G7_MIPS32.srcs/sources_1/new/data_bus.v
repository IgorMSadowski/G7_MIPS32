`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Data Bus
// Address decoder and read-response mux for DMEM and memory-mapped peripherals.
//////////////////////////////////////////////////////////////////////////////////

module data_bus(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire [31:0] i_addr,
    input  wire        i_mem_read,
    input  wire        i_mem_write,
    input  wire        i_io_sel,
    input  wire [31:0] i_dmem_rdata,
    input  wire [31:0] i_mmio_rdata,
    input  wire        i_rsp_consume,
    output wire        o_dmem_re,
    output wire        o_dmem_we,
    output wire        o_mmio_re,
    output wire        o_mmio_we,
    output wire [31:0] o_rdata,
    output reg         o_rsp_valid
    );

    wire _access_en = i_en && !i_rst;
    wire _dmem_addr_valid = (i_addr[31:8] == 24'b0) &&
                            (i_addr[1:0] == 2'b00);
    wire _mmio_addr_valid = i_addr[31] && i_io_sel &&
                            (i_addr[1:0] == 2'b00);
    reg  _rsp_is_mmio;
    reg  [31:0] _mmio_rdata_hold;

    assign o_dmem_re = _access_en && i_mem_read &&
                       !i_addr[31] && _dmem_addr_valid;
    assign o_dmem_we = _access_en && i_mem_write &&
                       !i_addr[31] && _dmem_addr_valid;
    assign o_mmio_re = _access_en && i_mem_read && _mmio_addr_valid;
    assign o_mmio_we = _access_en && i_mem_write && _mmio_addr_valid;

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_rsp_valid <= 1'b0;
            _rsp_is_mmio <= 1'b0;
            _mmio_rdata_hold <= 32'b0;
        end else begin
            if (i_rsp_consume)
                o_rsp_valid <= 1'b0;

            if (o_dmem_re || o_mmio_re) begin
                o_rsp_valid <= 1'b1;
                _rsp_is_mmio <= o_mmio_re;
                if (o_mmio_re)
                    _mmio_rdata_hold <= i_mmio_rdata;
            end
        end
    end

    assign o_rdata = !o_rsp_valid ? 32'b0 :
                     _rsp_is_mmio ? _mmio_rdata_hold : i_dmem_rdata;

endmodule
