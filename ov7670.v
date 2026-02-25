`timescale 1ns / 1ps

module ov7670 (
    input        i_clk_100m,
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

wire global_rstn;
wire global_rst_done;
localparam RESET_CYCLES = 10000;
reset #(
  .RESET_CYCLES(RESET_CYCLES)
)inst (
    .i_clk(i_clk_100m),
    .o_rstn(global_rstn),
    .o_rst_done(global_rst_done)
);

localparam OV7670_START_DELAY = 5000;
localparam OV7670_RD_ADDR = 8'h43;
localparam OV7670_WR_ADDR = 8'h42;

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
  reg        sccb_tx_start;
  reg        sccb_tx_start_nxt;
  reg        sccb_tx_stop;
  reg        sccb_tx_stop_nxt;
  wire [7:0] sccb_wrbyte;
  reg  [7:0] sccb_wrbyte_nxt;
  wire [7:0] sccb_rdbyte;
  wire       sccb_ack;
  wire       sccb_dataval;
  wire       sccb_tx_done;
  reg        sccb_rep_start;
  reg        sccb_rep_start_nxt;
  reg [10:0] delay_counter;
  reg [10:0] delay_counter_nxt;
  
  localparam I2C_FREQ = 100000;
  localparam CLK_FREQ = 50000000;

  i2c #(
      .I2C_FREQ   (I2C_FREQ),
      .IP_CLK_FREQ(CLK_FREQ)
  ) inst_i2c (
      .i_clk          (i_clk_100m),
      .i_rstn         (global_rstn),
      .i_i2c_start    (sccb_tx_start),
      .i_i2c_stop     (sccb_tx_stop),
      .i_i2c_wr_byte  (sccb_wrbyte),
      .i_i2c_rep_start(sccb_rep_start),
      .o_i2c_tx_done  (sscb_tx_done),
      .o_i2c_ack      (sscb_ack),
      .o_i2c_dataval  (sscb_dataval),
      .o_i2c_rd_byte  (sscb_rdbyte),
      .i2c_scl        (ov7670_scl),
      .i2c_sda        (ov7670_sda)
  );


  localparam SIG_WIDTH = 16;
  localparam SIG_DEPTH = 77;
  localparam SIG_FILE = "reg.mem";
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
      .i_bram_clkrd  (i_clk_100m),
      .i_bram_rstn   (global_rstn),
      .i_bram_rden   (o_bram_rden),
      .i_bram_rdaddr (o_bram_addr),
      .o_bram_dataout(i_bram_dat),
      .o_bram_rd_comp(bram_rd_comp)
  );


  // flip-flop vsync synchronizer
  reg vsync_ff1;
  reg vsync_ff2;
  always @(posedge i_clk_100m) begin
    if(i_rstn) begin
      vsync_ff1 <= 1'b0;
      vsync_ff2 <= 1'b0;
    end else begin
    vsync_ff1 <= i_ov7670_vsync;
    vsync_ff2 <= vsync_ff1;
    end
  end

  // flip-flop hsync synchronizer
  reg hsync_ff1;
  reg hsync_ff2;
  always @(posedge i_clk_100m) begin
    if(i_rstn) begin
      hsync_ff1 <= 1'b0;
      hsync_ff2 <= 1'b0;
    end else begin
    hsync_ff1 <= i_ov7670_hsync;
    hsync_ff2 <= hsync_ff1;
    end
  end
  
  // flip-flop vsync synchronizer
  reg vsync_ff1;
  reg vsync_ff2;
  always @(posedge i_clk_100m) begin
    if(i_rstn) begin
      vsync_ff1 <= 1'b0;
      vsync_ff2 <= 1'b0;
    end else begin
    vsync_ff1 <= i_ov7670_vsync;
    vsync_ff2 <= vsync_ff1;
    end
  end
  
  assign debug_led = ~({4'b1010, rstate, status});

  always @(posedge i_clk_100m) begin
    if (!rstn) begin
      rstate       <= 0;
      sccb_wrbyte   <= 0;
      sccb_tx_start <= 1'b0;
      sccb_tx_stop  <= 1'b0;
      sccb_rep_start    <= 1'b0;
    end else begin
      rstate       <= rstate_nxt;
      sccb_tx_start <= sccb_tx_start_nxt;
      sccb_tx_stop  <= sccb_tx_stop_nxt;
      sccb_wrbyte   <= sscb_wrbyte_nxt;
      sccb_rep_start    <= sccb_rep_start_nxt;
      o_bram_rden <= o_bram_rden_nxt;
      o_bram_addr <= o_bram_addr_nxt;
      delay_counter <= delay_counter_nxt;
    end
  end


  always @(*) begin

    rstate_nxt       = rstate;
    sscb_wrbyte_nxt   = sccb_wrbyte;
    sccb_tx_stop_nxt  = 1'b0;
    sccb_tx_start_nxt = 1'b0;
    sccb_rep_start_nxt    = 1'b0;
    o_bram_rden_nxt = 1'b0;
    o_bram_addr_nxt = o_bram_addr;
    delay_counter_nxt = delay_counter;
    case (rstate)
      START: begin  //0
        if (rst_done) begin
          delay_counter_nxt = OV7670_START_DELAY;
          rstate_nxt = DELAY;
        end
      end
      
      DEV_ADDR: begin
        sccb_wrbyte_nxt = OV7670_WR_ADDR;
        sccb_tx_start_nxt = 1'b1;
        rstate_nxt = WAIT_ACK;
      end

      WAIT_ACK: begin
        if(!sccb_ack && sccb_tx_done) begin
          rstate_nxt = READ_BRAM;
        end
      end
      
      READ_BRAM: begin  // 1
        o_bram_rden_nxt = 1'b1;
        rstate_nxt = WRITE_ADDR;
      end

      WRITE_ADDR: begin
        if(!sscb_ack) begin
          sscb_wrbyte_nxt = i_bram_dat[15:8]; // send address
          rstate_nxt = WRITE_DATA
        end
      end

      WRITE_DATA: begin  // 2
        if (!sscb_ack && !bram_rd_comp) begin
          rstate_nxt       = READ_BRAM;
        end else rstate_nxt = INIT_DONE;
      end


      INIT_DONE: begin  // 6
        sccb_tx_stop_nxt = 1'b1;
      end

      DELAY: begin
        delay_counter_nxt = delay_counter -1;
        if(delay_counter == 0) begin
          rstate_nxt = READ_BRAM;
        end
      end

      default: begin
        rstate_nxt = START;
      end
    endcase
  end

  /*
  ila_0 test (
      .clk   (i_clk_100m),
      .probe0(dbg_scl),
      .probe1(dbg_sda),
      .probe2(dbg_i2c_state),
      .probe3(dbg_rw_flag),
      .probe4(sccb_tx_stop),
      .probe5(sscb_ack),
      .probe6(sscb_tx_done),
      .probe7(dbg_scl_lo),
      .probe8(dbg_scl_hi),
      .probe9(sccb_tx_start_nxt)
  );
*/

endmodule