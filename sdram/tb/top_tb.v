`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 10000000;

  // required clk = 50MHz
  // 1/50 = 0.00000002s
  //
  parameter CLK_PERIOD_NS = 20;  // 10nS = 100MHz, 20nS = 50MHz

  reg         r_clk;
  wire tb_sdram_clk;
  wire tb_sdram_cke;
  wire [1:0] tb_sdram_dqm;
  wire tb_sdram_casn;
  wire tb_sdram_wen;
  wire tb_sdram_csn;
  wire [1:0] tb_sdram_ba;
  wire [12:0] tb_sdram_addr;
  wire [15:0] tb_sdram_data;
  wire [7:0] tb_debug_led;


top uut(
    .sys_clk(r_clk),
    .sdram_clk(tb_sdram_clk),
    .sdram_cke(tb_sdram_cke),
    .sdram_dqm(tb_sdram_dqm),
    .sdram_casn(tb_sdram_casn),
    .sdram_wen(tb_sdram_wen),
    .sdram_csn(tb_sdram_csn),
    .sdram_ba(tb_sdram_ba),
    .sdram_addr(tb_sdram_addr),
    .sdram_data(tb_sdram_data),
    .debug_led(tb_debug_led)
);


  initial begin
    r_clk      = 0;
    forever #(CLK_PERIOD_NS / 2) r_clk = ~r_clk;
  end


  initial begin
    $dumpfile("sim_output/top_tb.vcd");
    $dumpvars(0, top_tb);
  end

  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end

endmodule





