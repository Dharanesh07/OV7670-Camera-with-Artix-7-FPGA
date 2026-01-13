`timescale 1ns / 1ps

module sdram_tb ();

  parameter DURATION = 10000000;

  // required clk = 133MHz
  // 1/133 = 0.00000000751879699248s
  //
  parameter CLK_PERIOD_NS = 7.51879;  // 10ns = 100MHz

  parameter SDRAM_CLK_FREQ_MHZ = 133;
  parameter TRP_NS = 20;
  parameter TRC_NS = 66;
  parameter TRCD_NS = 20;
  parameter TCH_NS = 2;
  parameter CAS = 3'd2;

  reg         r_clk;
  reg         o_rstn;
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

  sdram_ctrl #(
      .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
      .TRP_NS            (TRP_NS),
      .TRC_NS            (TRC_NS),
      .TRCD_NS           (TRCD_NS),
      .TCH_NS            (TCH_NS),
      .CAS               (CAS)
  ) inst_sdram_ctrl (
      .i_clk     (r_clk),
      .i_rstn    (o_rstn),
      .i_addr    (o_addr),
      .i_sdram_en(o_sdram_en),
      .i_datain  (o_datain),
      .i_rw      (o_rw),
      .o_dataval (i_dataval),
      .is_writing(i_writing),
      .o_dataout (i_dataout),
      .o_ready   (i_ready),
      .sdram_clk (tb_sdram_clk),
      .sdram_cke (tb_sdram_cke),
      .sdram_dqm (tb_sdram_dqm),
      .sdram_addr(tb_sdram_addr),
      .sdram_ba  (tb_sdram_ba),
      .sdram_csn (tb_sdram_csn),
      .sdram_wen (tb_sdram_wen),
      .sdram_rasn(tb_sdram_rasn),
      .sdram_casn(tb_sdram_casn),
      .sdram_data(tb_sdram_data)
  );

  /*

  mt48lc16m16a2 sim_model (
      .Dq   (tb_sdram_data),
      .Addr (tb_sdram_addr),
      .Ba   (tb_sdram_ba),
      .Clk  (tb_sdram_clk),
      .Cke  (tb_sdram_cke),
      .Cs_n (tb_sdram_csn),
      .Ras_n(tb_sdram_rasn),
      .Cas_n(tb_sdram_casn),
      .We_n (tb_sdram_wen),
      .Dqm  (tb_sdram_dqm)
  );
*/
  initial begin
    r_clk      = 0;
    o_rw       = 0;
    o_sdram_en = 0;
    o_addr     = 0;
    o_datain   = 0;
    forever #(CLK_PERIOD_NS / 2) r_clk = ~r_clk;
  end

  initial begin
    #50 o_rstn = 0;
    #100 o_rstn = 1;
    #100;
    wait (o_rstn == 1);
    wait (i_ready == 1);

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






