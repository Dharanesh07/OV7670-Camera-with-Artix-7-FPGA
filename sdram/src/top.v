module top (
    input             sys_clk,
    input             uart_rx,
    output            sdram_clk,
    output            sdram_cke,
    output     [ 1:0] sdram_dqm,
    output            sdram_casn,
    output            sdram_rasn,
    output            sdram_wen,
    output            sdram_csn,
    output     [ 1:0] sdram_ba,
    output     [12:0] sdram_addr,
    output     [15:0] sdram_data,
    output reg [ 7:0] debug_led

);


  parameter real CLKIN_PERIOD = 20.0;  // 50 MHz input = 20ns period
  parameter integer DIVCLK_DIVIDE = 1;
  parameter real CLKFBOUT_MULT = 20.0;  // For 1000 MHz VCO
  parameter real CLKOUT0_DIVIDE = 7.5;  // For 133.33 MHz output
  parameter real CLKOUT1_DIVIDE = 40.0;  // For 25 MHz output


  reg  [14:0] r_rst_cycle = 0;
  reg         o_rstn = 1'b0;
  wire        clk_133mhz;
  wire        pll_lock;

  clock_133mhz inst_clock (
      .clk_in       (sys_clk),
      .i_rstn       (1'b1),
      .clk_out0     (clk_133mhz),
      .clk_out1     (),
      .is_pll_locked(pll_lock)
  );

  parameter SDRAM_CLK_FREQ_MHZ = 133;
  parameter TRP_NS = 20;
  parameter TRC_NS = 66;
  parameter TRCD_NS = 20;
  parameter TCH_NS = 2;
  parameter CAS = 3'd2;

  wire [15:0] s2f_dataout;
  wire        is_sdram_ready;
  wire [14:0] f2s_addr;
  reg  [15:0] f2s_datain;
  wire        i_dataval;
  reg         o_rw;
  reg         o_sdram_en;
  wire        i_writing;
  reg  [15:0] data;


  sdram_ctrl #(
      .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
      .TRP_NS            (TRP_NS),
      .TRC_NS            (TRC_NS),
      .TRCD_NS           (TRCD_NS),
      .TCH_NS            (TCH_NS),
      .CAS               (CAS)
  ) inst_sdram_ctrl (
      .i_clk     (clk_133mhz),
      .i_rstn    (o_rstn),
      .i_addr    (f2s_addr),
      .i_sdram_en(o_sdram_en),
      .i_datain  (f2s_datain),
      .i_rw      (o_rw),
      .o_dataval (i_dataval),
      .is_writing(i_writing),
      .o_dataout (s2f_dataout),
      .o_ready   (is_sdram_ready),
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

  ila_0 test_ila (
      .clk   (clk_133mhz),
      .probe0(sdram_casn),
      .probe1(sdram_rasn),
      .probe2(sdram_data),
      .probe3(i_ready),
      .probe4(i_dataout)
  );




  localparam START = 0;
  localparam RESET = 1;
  localparam WRITE_DATA = 2;
  localparam READ_DATA = 3;

  reg [2:0] rstate;
  reg       rst_done = 0;
  reg [9:0] burst_index;


  //assign debug_led = ~(w_rxbyte);

  always @(posedge clk_133mhz) begin

    case (rstate)
      START: begin
        if (!rst_done) rstate <= RESET;
        else begin
          if (is_sdram_ready) begin
            rstate <= WRITE_DATA;
          end
        end
      end

      WRITE_DATA: begin
        o_sdram_en <= 1'b1;
        //f2s_addr   <= 0;
        o_rw       <= 1'b0;  //write mode
        f2s_datain <= 16'hAAAA;
        if (burst_index >= 512) begin
          o_rw        <= 1'b1;  //read mode
          burst_index <= 0;
          rstate      <= READ_DATA;
        end else begin
          if (!i_writing) begin
            burst_index <= burst_index + 1;
          end
          rstate <= WRITE_DATA;
        end
      end

      READ_DATA: begin
        o_sdram_en <= 1'b1;
        o_rw       <= 1'b1;
        if (burst_index >= 512) begin
          o_sdram_en  <= 1'b0;  //read mode
          burst_index <= 0;
          rstate      <= IDLE;
        end else begin
          if (o_ready) begin
            data <= s2f_dataout;
            burst_index <= burst_index + 1;
          end
          rstate <= READ_DATA;
        end
      end

      IDLE: begin
        debug_led <= 8'b00000001;
        rstate <= IDLE;
      end

      RESET: begin
        if (r_rst_cycle < 10000) begin
          r_rst_cycle <= r_rst_cycle + 1;
          o_rstn      <= 0;
          burst_index <= 0;
        end else begin
          o_rstn   <= 1'b1;
          rst_done <= 1'b1;
          rstate   <= START;
        end
      end
      default: rstate <= START;
    endcase
  end

  assign f2s_addr = burst_index;
endmodule


