module top (
    input         sys_clk_50mhz,
    // OV7670 camera pins 
    input         ov7670_rstn,
    input         ov7670_pclk,
    input         ov7670_hsync,
    input         ov7670_vsync,
    input  [ 7:0] ov7670_data,
    output        ov7670_rstn,
    output        ov7670_pwdn,
    output        ov7670_xclk,
    inout         ov7670_scl,
    inout         ov7670_sda,
    // SDRAM pins
    output        sdram_clk,
    output        sdram_cke,
    output [ 1:0] sdram_dqm,
    output        sdram_casn,
    output        sdram_rasn,
    output        sdram_wen,
    output        sdram_csn,
    output [ 1:0] sdram_ba,
    output [12:0] sdram_addr,
    inout  [15:0] sdram_data,
    // VGA pins
    output        vga_hsync,
    output        vga_vsync,
    output [ 3:0] vga_red,
    output [ 3:0] vga_blue,
    output [ 3:0] vga_green,
    // Debug LED 
    output [ 7:0] debug_led
);


  wire clk_24mhz;

  clock_24mhz inst_clock_24mhz (
      .clk_in       (sys_clk),
      .i_rstn       (1'b1),
      .clk_out0     (clk_24mhz),
      .is_pll_locked()
  );

  wire global_rstn;
  wire global_rst_done;
  localparam RESET_CYCLES = 32'd25000;

  reset #(
      .RESET_CYCLES(RESET_CYCLES)
  ) inst (
      .i_rst_clk (clk_24mhz),
      .o_rstn    (global_rstn),
      .o_rst_done(global_rst_done)
  );



  async_fifo #(
      .WIDTH(2 * SIG_WIDTH),
      .DEPTH(OP_FIFO_LEN)
  ) fir2uarttx_fifo (
      .i_wr_inc (fir_fifo_wren),
      .i_wr_clk (fir_clk),
      .i_wrrst_n(fir_rstn),
      .i_rd_inc (fifo_rd_en),
      .i_rd_clk (clk),
      .i_rdrst_n(r_rstn),
      .wr_full  (ff_full),
      .rd_empty (ff_empty),
      .i_datain (fir_dataout),
      .o_dataout(fifo_dataout)
  );

endmodule
