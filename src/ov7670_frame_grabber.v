`timescale 1ns / 1ps

module ov7670_frame_grabber (
    input             i_pclk,
    input             i_rstn,
    input             i_hsync,
    input             i_vsync,
    input      [ 7:0] pixel_data,
    output reg [15:0] pixel_frame,
    output reg [22:0] line_counter,
    output reg [ 9:0] frame_counter
);

  // 640 x 480 resolution
  localparam H_PIX = 307200;
  // Frame synchronizer
  reg       vsync_ff1;
  reg       vsync_ff2;
  reg [2:0] frame_state;

  localparam WAIT_NEW_FRAME = 0;
  localparam FRAME_MSB = 1;
  localparam FRAME_LSB = 2;
  localparam END_FRAME = 3;

  always @(posedge i_pclk) begin
    if (!i_rstn) begin
      line_counter  <= 0;
      frame_counter <= 0;
      vsync_ff1     <= 1'b0;
      vsync_ff2     <= 1'b0;
      frame_state   <= WAIT_NEW_FRAME;
    end else begin
      case (frame_state)
        WAIT_NEW_FRAME: begin
          vsync_ff1 <= i_vsync;
          vsync_ff2 <= vsync_ff1;
          if (vsync_ff1 && vsync_ff2) begin
            //if (i_vsync) begin
            line_counter  <= 0;
            frame_counter <= frame_counter + 1'b1;
            frame_state   <= FRAME_MSB;
          end
        end
        FRAME_MSB: begin
          if (i_hsync) begin
            line_counter      <= line_counter + 1'b1;
            pixel_frame[15:8] <= pixel_data;
            frame_state       <= FRAME_LSB;
          end
        end
        FRAME_LSB: begin
          if (i_hsync) begin
            pixel_frame[7:0] <= pixel_data;
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


endmodule
