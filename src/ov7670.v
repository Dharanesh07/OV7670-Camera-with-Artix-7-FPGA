// Uses a reset controller, so reset input is not required

`timescale 1ns / 10ps

module ov7670 (
    input             i_clk_24mhz,
    // OV7670 camera IO signals
    input             i_ov7670_rstn,
    input             i_ov7670_pclk,
    input             i_ov7670_hsync,
    input             i_ov7670_vsync,
    input      [ 7:0] i_ov7670_data,
    output reg        o_ov7670_rstn,
    output reg        o_ov7670_pwdn,
    output            o_ov7670_xclk,
    inout             ov7670_scl,
    inout             ov7670_sda,
    // FIFO
    output     [15:0] ov7670_fifo_data,
    output            ov7670_fifo_wren,
    output            ov7670_new_frame,
    output reg        ov7670_init_done

);

  assign o_ov7670_xclk = i_clk_24mhz;

  // 1 clock cycle at 24MHz = 41.66 nS
  localparam OV7670_START_DELAY = 300000;  // 60mS
  localparam OV7670_RESET_DELAY = 250000;  // 50 mS
  localparam OV7670_I2C_DELAY = 330000;

  // for simulation
  //localparam OV7670_START_DELAY = 1;  // 60mS
  //localparam OV7670_RESET_DELAY = 1;  // 50 mS
  //localparam OV7670_I2C_DELAY = 1;

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
  reg         ov7670_init_done_nxt;
  wire        fifo_wr;

  localparam I2C_FREQ = 100000;
  localparam CLK_FREQ = 24000000;

  i2c #(
      .I2C_FREQ   (I2C_FREQ),
      .IP_CLK_FREQ(CLK_FREQ)
  ) inst_i2c (
      .i_clk          (i_clk_24mhz),
      .i_rstn         (i_ov7670_rstn),
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
  //localparam SIG_DEPTH = 78;
  //localparam SIG_FILE = "src/ov7670_config.mem";
  localparam SIG_DEPTH = 19;
  localparam SIG_FILE = "src/ov7670_test_pattern.mem";
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
      .i_bram_clkrd  (i_clk_24mhz),
      .i_bram_rstn   (i_ov7670_rstn),
      .i_bram_rden   (o_bram_rden),
      .i_bram_rdaddr (o_bram_addr),
      .o_bram_dataout(i_bram_dat),
      .o_bram_rd_comp(bram_rd_comp)
  );


  wire [15:0] dbg_pixel_frame;
  wire [11:0] dbg_line_counter;
  wire [ 9:0] dbg_frame_counter;
  wire [15:0] ov_data;
  ov7670_frame_grabber inst_ov7670_frame_grabber (
      .i_pclk       (i_ov7670_pclk),
      .i_hsync      (i_ov7670_hsync),
      .i_vsync      (i_ov7670_vsync),
      .i_8b_data    (i_ov7670_data),
      .o_16b_px_data(ov_data),
      .new_frame    (ov7670_new_frame),
      .px_dataval   (fifo_wr)
  );
  // ov7670_frame_grabber uses pclk and it arrives only after sensor is
  // configured
  assign ov7670_fifo_wren = (ov7670_init_done == 1'b1) ? fifo_wr : 1'b0;
  assign ov7670_fifo_data = (ov7670_init_done == 1'b1) ? ov_data : 0;

  always @(posedge i_clk_24mhz) begin
    if (!i_ov7670_rstn) begin
      rstate           <= 0;
      delay_ret_state  <= 0;
      sccb_wrbyte      <= 0;
      sccb_tx_start    <= 1'b0;
      sccb_tx_stop     <= 1'b0;
      sccb_rep_start   <= 1'b0;
      o_ov7670_rstn    <= 1'b0;
      o_ov7670_pwdn    <= 1'b0;
      ov7670_init_done <= 1'b0;
    end else begin
      o_ov7670_rstn    <= 1'b1;
      rstate           <= rstate_nxt;
      delay_ret_state  <= delay_ret_state_nxt;
      sccb_tx_start    <= sccb_tx_start_nxt;
      sccb_tx_stop     <= sccb_tx_stop_nxt;
      sccb_wrbyte      <= sccb_wrbyte_nxt;
      sccb_rep_start   <= sccb_rep_start_nxt;
      o_bram_rden      <= o_bram_rden_nxt;
      o_bram_addr      <= o_bram_addr_nxt;
      delay_counter    <= delay_counter_nxt;
      ov7670_init_done <= ov7670_init_done_nxt;
    end
  end


  always @(*) begin
    rstate_nxt           = rstate;
    delay_ret_state_nxt  = delay_ret_state;
    sccb_wrbyte_nxt      = sccb_wrbyte;
    sccb_tx_stop_nxt     = 1'b0;
    sccb_tx_start_nxt    = 1'b0;
    sccb_rep_start_nxt   = 1'b0;
    o_bram_rden_nxt      = 1'b0;
    o_bram_addr_nxt      = o_bram_addr;
    delay_counter_nxt    = delay_counter;
    ov7670_init_done_nxt = ov7670_init_done;

    case (rstate)
      START: begin  //0
        if (i_ov7670_rstn) begin
          delay_counter_nxt   = OV7670_START_DELAY;
          rstate_nxt          = DELAY;
          o_bram_addr_nxt     = 0;
          delay_ret_state_nxt = DEV_ADDR;
        end
      end

      DEV_ADDR: begin  //1 
        sccb_wrbyte_nxt   = OV7670_WR_ADDR;
        sccb_tx_start_nxt = 1'b1;
        o_bram_rden_nxt   = 1'b1;
        rstate_nxt        = READ_BRAM;
      end

      READ_BRAM: begin  // 3
        if (sccb_tx_done) begin
          sccb_wrbyte_nxt   = i_bram_dat[15:8];  // send address
          sccb_tx_start_nxt = 1'b1;
          rstate_nxt        = WRITE_ADDR;
        end
      end

      WRITE_ADDR: begin  // 4
        rstate_nxt = WRITE_DATA;
      end


      WRITE_DATA: begin  // 5
        if (sccb_tx_done) begin
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
        sccb_tx_stop_nxt     = 1'b1;
        ov7670_init_done_nxt = 1'b1;
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


endmodule
