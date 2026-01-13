`timescale 1ps / 1ps

module clock #(
    parameter real    CLKIN_PERIOD   = 20.0,  // 50 MHz input = 20ns period
    parameter integer DIVCLK_DIVIDE  = 1,
    parameter real    CLKFBOUT_MULT  = 20.0,  // For 1000 MHz VCO
    parameter real    CLKOUT0_DIVIDE = 7.5,   // For 133.33 MHz output
    parameter real    CLKOUT1_DIVIDE = 40.0   // For 25 MHz output (if needed)
) (
    input  wire clk_in,    // 50 MHz input
    input  wire reset,     // Active high reset
    output wire clk_out0,  // First output clock
    output wire clk_out1,  // Second output clock (optional)
    output wire locked     // PLL locked indicator
);

  // Internal signals
  wire clk_in_buf;
  wire clk_fb;
  wire clk_fb_buf;
  wire clk_out0_unbuf;
  wire clk_out1_unbuf;
  wire locked_int;

  // Input buffer
  IBUF ibuf_clkin (
      .I(clk_in),
      .O(clk_in_buf)
  );

  // MMCM instantiation
  MMCME2_ADV #(
      .BANDWIDTH         ("OPTIMIZED"),
      .CLKFBOUT_MULT_F   (CLKFBOUT_MULT),
      .CLKFBOUT_PHASE    (0.0),
      .CLKIN1_PERIOD     (CLKIN_PERIOD),
      .CLKOUT0_DIVIDE_F  (CLKOUT0_DIVIDE),
      .CLKOUT0_PHASE     (0.0),
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT1_DIVIDE    (CLKOUT1_DIVIDE),
      .CLKOUT1_PHASE     (0.0),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .DIVCLK_DIVIDE     (DIVCLK_DIVIDE),
      .REF_JITTER1       (0.010),
      .STARTUP_WAIT      ("FALSE")
  ) mmcm_inst (
      // Clock outputs
      .CLKOUT0 (clk_out0_unbuf),
      .CLKOUT1 (clk_out1_unbuf),
      .CLKOUT2 (),
      .CLKOUT3 (),
      .CLKOUT4 (),
      .CLKOUT5 (),
      .CLKOUT6 (),
      // Feedback clocks
      .CLKFBOUT(clk_fb),
      .CLKFBIN (clk_fb_buf),
      // Input clock
      .CLKIN1  (clk_in_buf),
      .CLKIN2  (1'b0),
      .CLKINSEL(1'b1),            // Select CLKIN1
      // Control
      .RST     (reset),
      .PWRDWN  (1'b0),
      .LOCKED  (locked_int),
      // DRP (Dynamic Reconfiguration) - not used
      .DADDR   (7'h0),
      .DI      (16'h0),
      .DWE     (1'b0),
      .DEN     (1'b0),
      .DCLK    (1'b0),
      .DO      (),
      .DRDY    ()
  );

  // Feedback buffer
  BUFG bufg_fb (
      .I(clk_fb),
      .O(clk_fb_buf)
  );

  // Output buffers
  BUFG bufg_clk0 (
      .I(clk_out0_unbuf),
      .O(clk_out0)
  );

  BUFG bufg_clk1 (
      .I(clk_out1_unbuf),
      .O(clk_out1)
  );

  assign locked = locked_int;

endmodule
