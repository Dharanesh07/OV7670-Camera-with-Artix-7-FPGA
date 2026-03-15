module sdram_control (
    input         i_clk_166mhz,  // 165 MHz
    input         i_rstn,
    // sdram hw connections
    output        sdram_clk,
    output        sdram_cke,
    output [ 1:0] sdram_dqm,
    output        sdram_casn,
    output        sdram_rasn,
    output        sdram_wen,
    output        sdram_csn,
    output [ 1:0] sdram_ba,
    output [12:0] sdram_addr,
    inout  [15:0] sdram_data
);



  parameter SDRAM_CLK_FREQ_MHZ = 166;
  parameter TRP_NS = 15;
  parameter TRC_NS = 66;
  parameter TRCD_NS = 15;
  parameter TCH_NS = 2;
  parameter CAS = 3'd3;

  wire [15:0] s2f_dataout;
  wire        is_sdram_ready;
  reg  [14:0] f2s_addr;
  reg  [15:0] f2s_datain;
  wire        i_dataval;
  reg         o_rw;
  reg         o_sdram_en;
  wire        i_writing;
  reg  [15:0] data;
  wire [15:0] rd_data;
  wire [15:0] wr_data;
  reg  [ 7:0] test_count;

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
      .i_addr    (),
      .i_sdram_en(),
      .i_datain  (),
      .i_rw      (),
      .o_dataval (),
      .is_writing(),
      .o_dataout (),
      .o_ready   (),
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




endmodule
