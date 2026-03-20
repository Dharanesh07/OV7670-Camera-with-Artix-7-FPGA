`timescale 1ns / 10ps

module sdram_controller (
    input             i_clk_166mhz,
    input             i_rstn,
    // sdram hw connections
    output            sdram_clk,
    output            sdram_cke,
    output     [ 1:0] sdram_dqm,
    output            sdram_casn,
    output            sdram_rasn,
    output            sdram_wen,
    output            sdram_csn,
    output     [ 1:0] sdram_ba,
    output     [12:0] sdram_addr,
    inout      [15:0] sdram_data,
    // fifo signals
    output reg [15:0] vga_fifo_data,
    output reg        vga_fifo_wren,
    input      [15:0] ov7670_fifo_data,
    input             ov7670_half_full,
    input             ov7670_fifo_empty,
    output reg        ov7670_fifo_rden
);


  localparam SDRAM_CLK_FREQ_MHZ = 166;
  localparam TRP_NS = 15;
  localparam TRC_NS = 66;
  localparam TRCD_NS = 15;
  localparam TCH_NS = 2;
  localparam CAS = 3'd3;

  // sdram control signals
  reg  [14:0] o_addr;
  reg  [15:0] wr_data;
  reg         o_rw;
  reg         o_sdram_en;

  // sdram status signals
  wire [15:0] rd_data;
  wire        i_ready;
  wire        i_dataval;
  wire        i_writing;

  sdram #(
      .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
      .TRP_NS            (TRP_NS),
      .TRC_NS            (TRC_NS),
      .TRCD_NS           (TRCD_NS),
      .TCH_NS            (TCH_NS),
      .CAS               (CAS)
  ) sdram_interface (
      .i_clk     (i_clk_166mhz),
      .i_rstn    (i_rstn),
      .i_addr    (o_addr),
      .i_sdram_en(o_sdram_en),
      .i_datain  (wr_data),
      .i_rw      (o_rw),
      .o_dataval (i_dataval),
      .is_writing(i_writing),
      .o_dataout (rd_data),
      .o_ready   (i_ready),
      .sdram_clk (sdram_clk),
      .sdram_cke (sdram_cke),
      .sdram_dqm (sdram_dqm),
      .sdram_addr(sdram_addr),
      .sdram_ba  (sdram_ba),
      .sdram_csn (sdram_csn),
      .sdram_wen (sdram_wen),
      .sdram_rasn(sdram_rasn),
      .sdram_casn(sdram_casn),
      .sdram_data(sdram_data)
  );


  localparam START = 3'd0;
  localparam WRITE_BURST_DATA = 3'd1;
  localparam READ_BURST_DATA = 3'd2;

  reg [2:0] r_state;


  always @(posedge i_clk_166mhz) begin
    if (!i_rstn) begin
      r_state          <= 0;
      o_addr           <= 0;
      o_rw             <= 0;
      o_sdram_en       <= 0;
      ov7670_fifo_rden <= 1'b0;
      vga_fifo_data    <= 0;
      vga_fifo_wren    <= 1'b0;
    end else begin
      case (r_state)
        START: begin
          if (ov7670_half_full) begin
            o_sdram_en <= 1'b1;
            r_state    <= WRITE_BURST_DATA;
          end
        end

        WRITE_BURST_DATA: begin
          if (i_ready && !ov7670_fifo_empty) begin
            o_rw             <= 1'b0;
            ov7670_fifo_rden <= 1'b1;
            wr_data          <= ov7670_fifo_data;
            if (o_addr == 640) begin
              o_addr           <= 0;
              ov7670_fifo_rden <= 1'b0;
              r_state          <= READ_BURST_DATA;
            end else o_addr <= o_addr + 1'b1;
          end
        end

        READ_BURST_DATA: begin

          if (i_ready) begin
            o_rw          <= 1'b1;
            vga_fifo_wren <= 1'b1;
            vga_fifo_data <= rd_data;
            if (o_addr == 640) begin
              o_addr        <= 0;
              vga_fifo_wren <= 1'b0;
              r_state       <= WRITE_BURST_DATA;
            end else o_addr <= o_addr + 1'b1;

          end
        end

        default: begin
          r_state <= START;
        end
      endcase
    end

  end


endmodule
