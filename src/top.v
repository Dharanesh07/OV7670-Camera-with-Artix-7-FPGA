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

  // Reset controller
  wire global_rstn;
  wire global_rst_done;
  localparam RESET_CYCLES = 32'd25000;

  reset #(
      .RESET_CYCLES(RESET_CYCLES)
  ) inst (
      .i_rst_clk (sys_clk_50mhz),
      .o_rstn    (global_rstn),
      .o_rst_done(global_rst_done)
  );

  wire sdram_rstn;
  wire ov7670_rstn;
  wire vga_rstn;

  // dual ff synchronizer for reset signals
  synchronizer #(
      .WIDTH(1)
  ) rst_synch_166mhz (
      .i_clk(clk_166mhz),
      .i_rst_n(1'b1),
      .i_datain(global_rstn),
      .o_q2(sdram_rstn)
  );

  synchronizer #(
      .WIDTH(1)
  ) rst_synch_24mhz (
      .i_clk(clk_24mhz),
      .i_rst_n(1'b1),
      .i_datain(global_rstn),
      .o_q2(ov7670_rstn)
  );

  synchronizer #(
      .WIDTH(1)
  ) rst_synch_25mhz (
      .i_clk(clk_25mhz),
      .i_rst_n(1'b1),
      .i_datain(global_rstn),
      .o_q2(vga_rstn)
  );

  // clock controller
  wire global_clk_166mhz;
  wire global_clk_24mhz;
  wire global_clk_25mhz;
  wire pll_lock;

  clock inst_clock (
      .clk_in_50mhz(sys_clk_50mhz),
      .i_rstn      (1'b1),
      .clk_166mhz  (global_clk_166mhz),
      .clk_24mhz   (global_clk_24mhz),
      .clk_25mhz   (global_clk_25mhz),
      .pll_locked  (pll_lock)
  );



  ov7670 inst_ov7670 (
      .i_clk_24mhz   (global_clk_24mhz),
      .i_ov7670_rstn (),
      .i_ov7670_pclk (ov7670_pclk),
      .i_ov7670_hsync(ov7670_hsync),
      .i_ov7670_vsync(ov7670_vsync),
      .i_ov7670_data (ov7670_data),
      .o_ov7670_rstn (ov7670_rstn),
      .o_ov7670_pwdn (ov7670_pwdn),
      .o_ov7670_xclk (ov7670_xclk),
      .ov7670_scl    (ov7670_scl),
      .ov7670_sda    (ov7670_sda)
  );

  // OV7670 to SDRAM Async FIFO
  localparam WIDTH = 16;
  localparam FIFO_LEN = 512;

  wire        fifo1_full;
  wire        fifo1_empty;
  wire        fifo1_rden;
  wire        fifo1_wren;
  wire [15:0] fifo1_datain;
  wire [15:0] fifo1_dataout;

  async_fifo #(
      .WIDTH(WIDTH),
      .DEPTH(FIFO_LEN)
  ) cam2ram_fifo (
      .i_wr_inc (fifo1_wren),
      .i_wr_clk (global_clk_24mhz),
      .i_wrrst_n(ov7670_rstn),
      .i_rd_inc (fifo1_rden),
      .i_rd_clk (global_clk_166mhz),
      .i_rdrst_n(sdram_rstn),
      .wr_full  (fifo1_full),
      .rd_empty (fifo1_empty),
      .i_datain (fifo1_datain),
      .o_dataout(fifo1_dataout)
  );

  sdram_control inst_sdram_control (
      .i_clk_166mhz(clk_166mhz),
      .i_rstn      (sdram_rstn),
      // sdram hw connections
      .sdram_clk   (sdram_clk),
      .sdram_cke   (sdram_cke),
      .sdram_dqm   (sdram_dqm),
      .sdram_casn  (sdram_casn),
      .sdram_rasn  (sdram_rasn),
      .sdram_wen   (sdram_wen),
      .sdram_csn   (sdram_csn),
      .sdram_ba    (sdram_ba),
      .sdram_addr  (sdram_addr),
      .sdram_data  (sdram_data)
  );

  // SDRAM to VGA Async FIFO
  wire        fifo2_full;
  wire        fifo2_empty;
  wire [15:0] fifo2_datain;
  wire [15:0] fifo2_dataout;
  wire        fifo2_rden;
  wire        fifo2_wren;

  async_fifo #(
      .WIDTH(WIDTH),
      .DEPTH(FIFO_LEN)
  ) ram2vga_fifo (
      .i_wr_inc (fifo2_wren),
      .i_wr_clk (global_clk_166mhz),
      .i_wrrst_n(sdram_rstn),
      .i_rd_inc (fifo2_rden),
      .i_rd_clk (global_clk_25mhz),
      .i_rdrst_n(vga_rstn),
      .wr_full  (fifo2_full),
      .rd_empty (fifo2_empty),
      .i_datain (fifo2_datain),
      .o_dataout(fifo2_dataout)
  );



  vga_controller inst_vga (
      .i_clk_25mhz(global_clk_25mhz),
      .i_rstn     (vga_rstn),
      .fifo_rden  (fifo2_rden),
      .fifo_empty (fifo2_empty),
      .fifo_datain(fifo2_dataout),
      .vga_hsync  (vga_hsync),
      .vga_vsync  (vga_vsync),
      .vga_red    (vga_red),
      .vga_blue   (vga_blue),
      .vga_green  (vga_green)
  );


endmodule
