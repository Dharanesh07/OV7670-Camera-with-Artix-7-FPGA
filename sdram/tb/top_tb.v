`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 10000000;

  // required clk = 133MHz
  // 1/133 = 0.00000000751879699248s
  //
  parameter CLK_PERIOD_NS = 7.51879;  // 10ns = 100MHz

  reg         r_clk;
  wire [15:0] i_dataout;
  wire        i_ready;
  reg  [14:0] o_addr;
  reg  [15:0] o_datain;
  wire        i_dataval;
  reg         o_rw;
  reg         o_sdram_en;
  // sdram Signals
  wire        tb_sdram_clk;
  wire        tb_sdram_cke;
  wire [ 1:0] tb_sdram_dqm;
  wire [12:0] tb_sdram_addr;
  wire [ 1:0] tb_sdram_ba;
  wire        tb_sdram_csn;
  wire        tb_sdram_wen;
  wire        tb_sdram_rasn;
  wire        tb_sdram_casn;
  wire [15:0] tb_sdram_data;
  wire        i_writing;

  initial begin
    r_clk      = 0;
    o_rw       = 0;
    o_sdram_en = 0;
    o_addr     = 0;
    o_datain   = 0;
    forever #(CLK_PERIOD_NS / 2) r_clk = ~r_clk;
  end

  initial begin

    @(posedge r_clk);
    o_sdram_en = 1'b1;
    #100;

    @(posedge r_clk);
    o_addr     = 15'h0000;
    o_datain   = 16'hBEEF;
    o_rw       = 1'b0;
    o_sdram_en = 1'b1;

    @(posedge r_clk);
    o_sdram_en = 1'b0;

    #1000;
    //wait (i_writing == 0);
    o_rw = 1'b1;
    o_sdram_en = 1'b1;
    o_addr = 0;

    @(posedge r_clk);
    o_sdram_en = 1'b0;

    // Check result
    wait (i_dataval == 1);
    $display(" %h, ", i_dataout);
  end




  initial begin
    $dumpfile("sim_output/sdram_tb.vcd");
    $dumpvars(0, sdram_tb);
  end

  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end

endmodule





