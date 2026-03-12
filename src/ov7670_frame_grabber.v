module ov7670_frame_grabber (
    input i_pclk,
    input i_hsync,
    input i_vsync,
    input [7:0] pixel_data
);

  // Frame synchronizer
  reg vsync_ff1;
  reg vsync_ff2;
  reg [2:0] frame_state;

  localparam WAIT_NEW_FRAME = 0;
  localparam START_FRAME = 1;
  localparam FRAME_MSB = 2;
  localparam FRAME_LSB = 3;
  localparam END_FRAME = 4;

  always @(posedge i_pclk) begin
    if (!global_rstn) begin
      vsync_ff1   <= 1'b0;
      vsync_ff2   <= 1'b0;
      frame_state <= WAIT_NEW_FRAME;
    end else begin
      case (frame_state)
        WAIT_NEW_FRAME: begin
          vsync_ff1 <= i_vsync;
          vsync_ff2 <= vsync_ff1;
          if (vsync_ff1 && vsync_ff2) begin
            frame_state <= FRAME_MSB;
          end
        end
        FRAME_MSB: begin
          if (i_hsync) begin
            pixel_frame[15:8] <= pixel_data;
            frame_state <= FRAME_LSB;
          end
        end
        FRAME_LSB: begin
          if (i_hsync) begin
            pixel_frame[7:0] <= pixel_data;
            frame_state <= END_FRAME;
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
