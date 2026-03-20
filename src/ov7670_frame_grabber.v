`timescale 1ns / 10ps

module ov7670_frame_grabber (
    input             i_pclk,
    input             i_hsync,
    input             i_vsync,
    input      [ 7:0] i_8b_data,
    output     [15:0] o_16b_px_data,
    output reg        new_frame,
    output reg        px_dataval
    //output reg [22:0] line_counter,
    //output reg [ 9:0] frame_counter
);

  // 640 x 480 resolution
  localparam H_PIX = 307200;
  // Frame synchronizer
  reg        vsync_ff1;
  reg        vsync_ff2;
  reg [ 2:0] frame_state;
  reg [22:0] line_counter;

  localparam WAIT_NEW_FRAME = 0;
  localparam FRAME_MSB = 1;
  localparam FRAME_LSB = 2;
  localparam END_FRAME = 3;

  localparam POWER_ON_RESET_CYCLES = 5;

  // Internal reset signals
  reg i_rstn = 0;
  reg [15:0] reset_counter = 0;

  // Generate power-on reset
  always @(posedge i_pclk) begin
    if (reset_counter < POWER_ON_RESET_CYCLES) begin
      reset_counter <= reset_counter + 1;
      i_rstn <= 1'b0;
    end else begin
      i_rstn <= 1'b1;
    end
  end

  reg [15:0] buf_a;
  reg [15:0] buf_b;
  reg        act_buf;

  always @(posedge i_pclk) begin
    if (!i_rstn) begin
      //line_counter  <= 0;
      //frame_counter <= 0;
      buf_b       <= 0;
      buf_a       <= 0;
      act_buf     <= 0;
      px_dataval  <= 1'b0;
      new_frame   <= 1'b0;
      vsync_ff1   <= 1'b0;
      vsync_ff2   <= 1'b0;
      frame_state <= WAIT_NEW_FRAME;
    end else begin
      case (frame_state)
        WAIT_NEW_FRAME: begin
          new_frame  <= 1'b0;
          px_dataval <= 1'b0;
          vsync_ff1  <= i_vsync;
          vsync_ff2  <= vsync_ff1;
          if (vsync_ff1 && vsync_ff2) begin
            new_frame    <= 1'b1;
            line_counter <= 0;
            //frame_counter <= frame_counter + 1'b1;
            frame_state  <= FRAME_MSB;
          end
        end
        FRAME_MSB: begin
          new_frame  <= 1'b0;
          px_dataval <= 1'b0;
          if (i_hsync) begin
            line_counter <= line_counter + 1'b1;
            if (act_buf) buf_b[15:8] <= i_8b_data;
            else buf_a[15:8] <= i_8b_data;
            frame_state <= FRAME_LSB;
          end
        end
        FRAME_LSB: begin
          new_frame <= 1'b0;
          if (i_hsync) begin
            if (act_buf) buf_b[7:0] <= i_8b_data;
            else buf_a[7:0] <= i_8b_data;
            px_dataval <= 1'b1;
            act_buf <= ~act_buf;
            if (line_counter == H_PIX) frame_state <= END_FRAME;
            else frame_state <= FRAME_MSB;
          end
        end
        END_FRAME: begin
          if ((!i_hsync) && (!i_vsync)) frame_state <= WAIT_NEW_FRAME;
        end
        default: begin
          frame_state <= WAIT_NEW_FRAME;
        end
      endcase

    end
  end

  assign o_16b_px_data = act_buf ? buf_a : buf_b;

endmodule
