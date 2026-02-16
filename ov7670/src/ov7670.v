`timescale 1ns / 1ps

module ov7670 (
    input        sys_clk,
    input        i_ov7670_pclk,
    input        i_ov7670_hsync,
    input        i_ov7670_vsync,
    input  [7:0] i_ov7670_data,
    output       o_ov7670_rstn,
    output       o_ov7670_pwdn,
    output       o_ov7670_xclk,
    inout        ov7670_scl,
    inout        ov7670_sda,
    output [7:0] debug_led
);


  reg rstn = 0;
  reg rst_done = 0;
  reg [32:0] r_rst_cycle = 0;

  // 10 seconds at 50MHz
  // localparam RESET_CYCLES = 32'd500000000;
  localparam RESET_CYCLES = 32'd100000;

  reg status;
  always @(posedge sys_clk) begin
    if ((r_rst_cycle < RESET_CYCLES) && (!rst_done)) begin
      r_rst_cycle <= r_rst_cycle + 1;
      rstn        <= 1'b0;
      status      <= 1'b0;
    end else begin
      rstn <= 1'b1;
      rst_done <= 1'b1;
      status <= 1'b1;
    end
  end

  localparam START = 0;
  localparam DEV_ADDR = 1;
  localparam WRITE_DATA = 2;
  localparam REPEAT_START = 3;
  localparam READ_ADDR = 4;
  localparam READ_DATA = 5;
  localparam IDLE = 6;
  localparam STOP1 = 7;

  reg  [2:0] rstate;
  reg  [2:0] rstate_nxt;
  reg        i2c_tx_start;
  reg        i2c_tx_start_nxt;
  reg        i2c_tx_stop;
  reg        i2c_tx_stop_nxt;
  reg  [7:0] i2c_wrbyte;
  reg  [7:0] i2c_wrbyte_nxt;
  wire [7:0] i2c_rdbyte;
  wire       i2c_ack;
  wire       i2c_dataval;
  wire       i2c_tx_done;
  reg        rep_start;
  reg        rep_start_nxt;


  localparam I2C_FREQ = 100000;
  localparam CLK_FREQ = 50000000;

  i2c #(
      .I2C_FREQ   (I2C_FREQ),
      .IP_CLK_FREQ(CLK_FREQ)
  ) inst_i2c (
      .i_clk          (sys_clk),
      .i_rstn         (rstn),
      .i_i2c_start    (i2c_tx_start),
      .i_i2c_stop     (i2c_tx_stop),
      .i_i2c_wr_byte  (i2c_wrbyte),
      .i_i2c_rep_start(rep_start),
      .o_i2c_tx_done  (i2c_tx_done),
      .o_i2c_ack      (i2c_ack),
      .o_i2c_dataval  (i2c_dataval),
      .o_i2c_rd_byte  (i2c_rdbyte),
      .i2c_scl        (i2c_scl),
      .i2c_sda        (i2c_sda)
  );


  localparam SIG_WIDTH = 16;
  localparam SIG_DEPTH = 77;
  localparam SIG_FILE = "reg.mem";
  localparam LEN = $clog2(SIG_DEPTH);

  reg                  o_bram_rden;
  reg  [      LEN-1:0] o_bram_addr;
  wire [SIG_WIDTH-1:0] i_bram_dat;
  wire                 bram_rd_comp;
  bram #(
      .WIDTH    (SIG_WIDTH),
      .DEPTH    (SIG_DEPTH),
      .INIT_FILE(SIG_FILE),
      .LEN      (LEN)
  ) coeff_mem (
      .i_bram_clkrd  (i_clk),
      .i_bram_rstn   (i_rstn),
      .i_bram_rden   (o_bram_rden),
      .i_bram_rdaddr (o_bram_addr),
      .o_bram_dataout(i_bram_dat),
      .o_bram_rd_comp(bram_rd_comp)
  );



  assign debug_led = ~({4'b1010, rstate, status});

  always @(posedge sys_clk) begin
    if (!rstn) begin
      rstate       <= 0;
      i2c_wrbyte   <= 0;
      i2c_tx_start <= 1'b0;
      i2c_tx_stop  <= 1'b0;
      rep_start    <= 1'b0;
    end else begin
      rstate       <= rstate_nxt;
      i2c_tx_start <= i2c_tx_start_nxt;
      i2c_tx_stop  <= i2c_tx_stop_nxt;
      i2c_wrbyte   <= i2c_wrbyte_nxt;
      rep_start    <= rep_start_nxt;
    end
  end


  always @(*) begin

    rstate_nxt       = rstate;
    i2c_wrbyte_nxt   = i2c_wrbyte;
    //i2c_tx_start_nxt = i2c_tx_start;
    i2c_tx_stop_nxt  = 1'b0;
    i2c_tx_start_nxt = 1'b0;
    rep_start_nxt    = 1'b0;
    case (rstate)
      START: begin  //0
        if (rst_done) begin
          i2c_wrbyte_nxt = DS3231M_WR_ADDR;
          i2c_tx_start_nxt = 1'b1;
          rstate_nxt = DEV_ADDR;
        end
      end
      DEV_ADDR: begin  // 1
        if (!i2c_ack) begin
          i2c_wrbyte_nxt = DS3231M_SEC_REG;
          i2c_tx_start_nxt = 1'b1;
          rstate_nxt = WRITE_DATA;
        end
      end

      WRITE_DATA: begin  // 2
        if (!i2c_ack) begin
          i2c_wrbyte_nxt   = 8'h30;
          i2c_tx_start_nxt = 1'b1;
          rstate_nxt       = REPEAT_START;
        end
      end

      REPEAT_START: begin  // 3
        if (!i2c_ack) begin
          i2c_wrbyte_nxt  = DS3231M_RD_ADDR;
          i2c_tx_stop_nxt = 1'b1;
          rstate_nxt      = STOP1;
        end
      end

      STOP1: begin
        i2c_tx_start_nxt = 1'b1;
        rstate_nxt = READ_ADDR;
      end

      READ_ADDR: begin  // 4
        i2c_tx_start_nxt = 1'b1;
        if (!i2c_ack) begin
          i2c_wrbyte_nxt   = 8'h00;
          i2c_tx_start_nxt = 1'b1;
          rstate_nxt       = READ_DATA;
        end
      end

      READ_DATA: begin  // 5
        if (i2c_dataval) begin
          i2c_tx_stop_nxt = 1'b1;
          rstate_nxt      = IDLE;
        end
      end

      IDLE: begin  // 6
        i2c_tx_stop_nxt = 1'b1;
      end

      default: begin
        rstate_nxt = START;
      end
    endcase
  end

  /*
  ila_0 test (
      .clk   (sys_clk),
      .probe0(dbg_scl),
      .probe1(dbg_sda),
      .probe2(dbg_i2c_state),
      .probe3(dbg_rw_flag),
      .probe4(i2c_tx_stop),
      .probe5(i2c_ack),
      .probe6(i2c_tx_done),
      .probe7(dbg_scl_lo),
      .probe8(dbg_scl_hi),
      .probe9(i2c_tx_start_nxt)
  );
*/

endmodule
