// Uses a reset controller, so reset input is not required


`timescale 1ns / 1ps

module ov7670 (
    input            i_ov7670_clk,
    //input         i_ov7670_rstn,
    input            i_ov7670_pclk,
    input            i_ov7670_hsync,
    input            i_ov7670_vsync,
    input      [7:0] i_ov7670_data,
    output reg       o_ov7670_rstn,
    output reg       o_ov7670_pwdn,
    output           o_ov7670_xclk,
    inout            ov7670_scl,
    inout            ov7670_sda,
    output     [7:0] debug_led
);

  wire global_rstn;
  wire global_rst_done;

  // 1 clock cycle at 50MHz = 20 nS
  // For 10000 clock cycles, delay = 0.2 mS
  localparam RESET_CYCLES = 10000;

  reset #(
      .RESET_CYCLES(RESET_CYCLES)
  ) inst (
      .i_rst_clk (i_ov7670_clk),
      .o_rstn    (global_rstn),
      .o_rst_done(global_rst_done)
  );


  // 1 clock cycle at 50MHz = 20 nS
  localparam OV7670_START_DELAY = 300000;  // 60mS
  localparam OV7670_RESET_DELAY = 250000;  // 50 mS
  localparam OV7670_I2C_DELAY = 33000;


  localparam OV7670_RD_ADDR = 8'h43;
  localparam OV7670_WR_ADDR = 8'h42;

  localparam START = 0;
  localparam DEV_ADDR = 1;
  localparam WAIT_ACK = 2;
  localparam READ_BRAM = 3;
  localparam WRITE_ADDR = 4;
  localparam WRITE_DATA = 5;
  localparam INIT_DONE = 6;
  localparam DELAY = 7;
  localparam READ_BRAM_WAIT = 8;


  reg  [ 3:0] rstate;
  reg  [ 3:0] rstate_nxt;
  reg  [ 3:0] delay_ret_state;
  reg  [ 3:0] delay_ret_state_nxt;
  reg         sccb_tx_start;
  reg         sccb_tx_start_nxt;
  reg         sccb_tx_stop;
  reg         sccb_tx_stop_nxt;
  reg  [ 7:0] sccb_wrbyte;
  reg  [ 7:0] sccb_wrbyte_nxt;
  wire [ 7:0] sccb_rdbyte;
  wire        sccb_ack;
  wire        sccb_dataval;
  wire        sccb_tx_done;
  reg         sccb_rep_start;
  reg         sccb_rep_start_nxt;
  reg  [31:0] delay_counter;
  reg  [31:0] delay_counter_nxt;
  wire        is_cam_rst;
  reg         sccb_wait;
  reg         sccb_wait_nxt;

  localparam I2C_FREQ = 100000;
  localparam CLK_FREQ = 50000000;

  i2c #(
      .I2C_FREQ   (I2C_FREQ),
      .IP_CLK_FREQ(CLK_FREQ)
  ) inst_i2c (
      .i_clk          (i_ov7670_clk),
      .i_rstn         (global_rstn),
      .i_i2c_start    (sccb_tx_start),
      .i_i2c_stop     (sccb_tx_stop),
      .i_i2c_wr_byte  (sccb_wrbyte),
      .i_i2c_rep_start(sccb_rep_start),
      .o_i2c_tx_done  (sccb_tx_done),
      .o_i2c_ack      (sccb_ack),
      .o_i2c_dataval  (sccb_dataval),
      .o_i2c_rd_byte  (sccb_rdbyte),
      .i2c_scl        (ov7670_scl),
      .i2c_sda        (ov7670_sda)
  );


  localparam SIG_WIDTH = 16;
  localparam SIG_DEPTH = 78;
  localparam SIG_FILE = "src/reg.mem";
  localparam LEN = $clog2(SIG_DEPTH);

  reg                  o_bram_rden;
  reg                  o_bram_rden_nxt;
  reg  [      LEN-1:0] o_bram_addr;
  reg  [      LEN-1:0] o_bram_addr_nxt;
  wire [SIG_WIDTH-1:0] i_bram_dat;
  wire                 bram_rd_comp;


  bram #(
      .WIDTH    (SIG_WIDTH),
      .DEPTH    (SIG_DEPTH),
      .INIT_FILE(SIG_FILE),
      .LEN      (LEN)
  ) config_reg (
      .i_bram_clkrd  (i_ov7670_clk),
      .i_bram_rstn   (global_rstn),
      .i_bram_rden   (o_bram_rden),
      .i_bram_rdaddr (o_bram_addr),
      .o_bram_dataout(i_bram_dat),
      .o_bram_rd_comp(bram_rd_comp)
  );



  always @(posedge i_ov7670_clk) begin
    if (!global_rstn) begin
      rstate          <= 0;
      delay_ret_state <= 0;
      sccb_wrbyte     <= 0;
      sccb_tx_start   <= 1'b0;
      sccb_tx_stop    <= 1'b0;
      sccb_rep_start  <= 1'b0;
      o_ov7670_rstn   <= 1'b0;
      o_ov7670_pwdn   <= 1'b0;
    end else begin
      rstate          <= rstate_nxt;
      delay_ret_state <= delay_ret_state_nxt;
      sccb_tx_start   <= sccb_tx_start_nxt;
      sccb_tx_stop    <= sccb_tx_stop_nxt;
      sccb_wrbyte     <= sccb_wrbyte_nxt;
      sccb_rep_start  <= sccb_rep_start_nxt;
      o_bram_rden     <= o_bram_rden_nxt;
      o_bram_addr     <= o_bram_addr_nxt;
      delay_counter   <= delay_counter_nxt;
    end
  end


  always @(*) begin
    rstate_nxt          = rstate;
    delay_ret_state_nxt = delay_ret_state;
    sccb_wrbyte_nxt     = sccb_wrbyte;
    sccb_tx_stop_nxt    = 1'b0;
    sccb_tx_start_nxt   = 1'b0;
    sccb_rep_start_nxt  = 1'b0;
    o_bram_rden_nxt     = 1'b0;
    o_bram_addr_nxt     = o_bram_addr;
    delay_counter_nxt   = delay_counter;

    case (rstate)
      START: begin  //0
        if (global_rst_done) begin
          delay_counter_nxt   = OV7670_START_DELAY;
          rstate_nxt          = DELAY;
          o_bram_addr_nxt     = 0;
          delay_ret_state_nxt = DEV_ADDR;
        end
      end

      DEV_ADDR: begin  //1 
        sccb_wrbyte_nxt   = OV7670_WR_ADDR;
        sccb_tx_start_nxt = 1'b1;
        rstate_nxt        = READ_BRAM;
      end

      READ_BRAM: begin  // 3
        if (!sccb_ack) begin
          o_bram_rden_nxt = 1'b1;
          rstate_nxt      = READ_BRAM_WAIT;
        end
      end
      READ_BRAM_WAIT: begin
        rstate_nxt = WRITE_ADDR;
      end

      WRITE_ADDR: begin  // 4
        sccb_wrbyte_nxt   = i_bram_dat[15:8];  // send address
        sccb_tx_start_nxt = 1'b1;
        rstate_nxt        = WRITE_DATA;
      end


      WRITE_DATA: begin  // 5
        if (!sccb_ack) begin
          sccb_wrbyte_nxt   = i_bram_dat[7:0];  // send data
          sccb_tx_start_nxt = 1'b1;
          if (bram_rd_comp) begin
            rstate_nxt          = DELAY;
            delay_counter_nxt   = OV7670_I2C_DELAY;
            delay_ret_state_nxt = INIT_DONE;
          end else begin
            if (is_cam_rst) delay_counter_nxt = OV7670_RESET_DELAY;
            else delay_counter_nxt = OV7670_I2C_DELAY;
            rstate_nxt          = DELAY;
            delay_ret_state_nxt = DEV_ADDR;
            o_bram_addr_nxt     = o_bram_addr + 1'b1;
          end
        end
      end

      INIT_DONE: begin  // 6
        sccb_tx_stop_nxt = 1'b1;
      end

      DELAY: begin  // 7
        sccb_tx_stop_nxt  = 1'b1;
        delay_counter_nxt = delay_counter - 1;
        if (delay_counter == 0) begin
          rstate_nxt = delay_ret_state;
        end
      end

      default: begin
        rstate_nxt = START;
      end
    endcase
  end

  assign is_cam_rst = (o_bram_addr == 1) ? 1'b1 : 1'b0;

  /*
  ila_0 test (
      .clk   (i_ov7670_clk),
      .probe0(dbg_scl),
      .probe1(dbg_sda),
      .probe2(dbg_i2c_state),
      .probe3(dbg_rw_flag),
      .probe4(sccb_tx_stop),
      .probe5(sccb_ack),
      .probe6(sccb_tx_done),
      .probe7(dbg_scl_lo),
      .probe8(dbg_scl_hi),
      .probe9(sccb_tx_start_nxt)
  );
*/

endmodule
