`timescale 1ns / 1ps

module sdram_tb ();

  parameter DURATION = 1000;
  parameter CLK_PERIOD_NS = 0.1941;  // 10ns = 100MHz

  parameter SDRAM_CLK_FREQ_MHZ = 100;
  parameter TRP_NS = 20;
  parameter TRC_NS = 66;
  parameter TRCD_NS = 20;
  parameter TCH_NS = 2;
  parameter CAS = 3'd2;

  reg         r_clk;
  reg         o_rst_n;
  wire [31:0] i_dataout;
  wire        i_ready;
  reg  [22:0] o_addr;
  reg  [31:0] o_datain;

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
      .i_datain  (o_datain),
      .i_rw_en   (o_rw_en),
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

  initial begin
    r_clk = 0;
    forever #(CLK_PERIOD_NS / 2) r_clk = ~r_clk;
  end

  initial begin
    #50 o_rst_n = 0;
    #100 o_rst_n = 1;
    #1000;
    wait (o_rst_n == 1);


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






