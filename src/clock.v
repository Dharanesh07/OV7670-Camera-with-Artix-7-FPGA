// VCO clock freq should be between 800 MHz to 1200 MHz
// VCO = Input × MULT / DIVCLK = 50 × 24 / 1 = 1200 MHz ✓

// Output frequencies:
// CLKOUT0: 1200 / 7.228916 ≈ 166.0 MHz (SDRAM)
// CLKOUT1: 1200 / 50 = 24.0 MHz (OV7670)
// CLKOUT2: 1200 / 48 = 25.0 MHz (VGA)

`timescale 1ns / 10ps


module clock (
    input  clk_in_50mhz,
    input  i_rstn,
    output clk_166mhz,
    output clk_24mhz,
    output clk_25mhz,
    output pll_locked
);

  localparam real CLKIN_PERIOD = 20.0;  // 50 MHz input = 20ns period
  localparam integer DIVCLK_DIVIDE = 1;
  localparam real CLKFBOUT_MULT_F = 24.0;  // For 1200 MHz VCO

  localparam real CLKOUT0_DIVIDE_F = 7.228916;  // 166.00 MHz
  localparam integer CLKOUT1_DIVIDE = 50;  // 24.00 MHz
  localparam integer CLKOUT2_DIVIDE = 48;  // 25.00 MHz

  // Internal signals
  wire clk_in_50_buf;
  wire clk_fb;
  wire clk_fb_buf;


  // Output signals
  wire clk_166_unbuf;
  wire clk_24_unbuf;
  wire clk_25_unbuf;

  wire pll_lock;

  // Input buffer
  IBUF ibuf_clkin (
      .I(clk_in_50mhz),
      .O(clk_in_50_buf)
  );

  // MMCM instantiation
  MMCME2_ADV #(
      .BANDWIDTH         ("OPTIMIZED"),
      .CLKFBOUT_MULT_F   (CLKFBOUT_MULT_F),
      .CLKFBOUT_PHASE    (0.0),
      .CLKIN1_PERIOD     (CLKIN_PERIOD),
      .DIVCLK_DIVIDE     (DIVCLK_DIVIDE),
      .REF_JITTER1       (0.010),
      // 166 mhz
      .CLKOUT0_DIVIDE_F  (CLKOUT0_DIVIDE_F),
      .CLKOUT0_PHASE     (0.0),
      .CLKOUT0_DUTY_CYCLE(0.5),
      // 24 mhz
      .CLKOUT1_DIVIDE    (CLKOUT1_DIVIDE),
      .CLKOUT1_PHASE     (0.0),
      .CLKOUT1_DUTY_CYCLE(0.5),
      // 25 mhz 
      .CLKOUT2_DIVIDE    (CLKOUT2_DIVIDE),
      .CLKOUT2_PHASE     (0.0),
      .CLKOUT2_DUTY_CYCLE(0.5),

      .STARTUP_WAIT("FALSE")
  ) mmcm_inst (
      // Clock outputs
      .CLKOUT0 (clk_166_unbuf),
      .CLKOUT1 (clk_24_unbuf),
      .CLKOUT2 (clk_25_unbuf),
      .CLKOUT3 (),
      .CLKOUT4 (),
      .CLKOUT5 (),
      .CLKOUT6 (),
      // Feedback clocks
      .CLKFBOUT(clk_fb),
      .CLKFBIN (clk_fb_buf),
      // Input clock
      .CLKIN1  (clk_in_50_buf),
      .CLKIN2  (1'b0),
      .CLKINSEL(1'b1),           // Select CLKIN1
      // Control
      .RST     (~(i_rstn)),
      .PWRDWN  (1'b0),
      .LOCKED  (pll_lock),
      // DRP Dynamic Reconfiguration not used
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
  BUFG bufg_166 (
      .I(clk_166_unbuf),
      .O(clk_166mhz)
  );

  BUFG bufg_24 (
      .I(clk_24_unbuf),
      .O(clk_24mhz)
  );

  BUFG bufg_25 (
      .I(clk_25_unbuf),
      .O(clk_25mhz)
  );

  assign pll_locked = pll_lock;

endmodule
