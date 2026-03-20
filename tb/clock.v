// Output frequencies:
// CLKOUT0: 1200 / 7.228916 ≈ 166.0 MHz (SDRAM)
// CLKOUT1: 1200 / 50 = 24.0 MHz (OV7670)
// CLKOUT2: 1200 / 48 = 25.0 MHz (VGA)

`timescale 1ns / 10ps


module clock (
    input clk_in_50mhz,
    input i_rstn,
    output reg clk_166mhz,
    output reg clk_24mhz,
    output reg clk_25mhz,
    output pll_locked
);

  parameter CLK_PERIOD_24MHZ = 41.66;
  parameter CLK_PERIOD_25MHZ = 40;
  parameter CLK_PERIOD_166MHZ = 6.02409;

  initial begin
    clk_25mhz = 0;
    forever #(CLK_PERIOD_25MHZ / 2) clk_25mhz = ~clk_25mhz;
  end
  initial begin
    clk_24mhz = 0;
    forever #(CLK_PERIOD_24MHZ / 2) clk_24mhz = ~clk_24mhz;
  end

  initial begin
    clk_166mhz = 0;
    forever #(CLK_PERIOD_166MHZ / 2) clk_166mhz = ~clk_166mhz;
  end
endmodule
