module vga (
    input            i_clk_25mhz,
    input            i_rstn,
    output           dp_en,
    output     [9:0] h_pos,
    output     [9:0] v_pos,
    output reg       vga_hsync,
    output reg       vga_vsync
);


  localparam H_ACTIVE_PIXEL = 640;
  localparam H_FRONT_PORCH = 16;
  localparam H_SYNC_PULSE = 96;
  localparam H_BACK_PORCH = 48;
  localparam H_TOTAL_PIXEL = (H_ACTIVE_PIXEL + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH - 1);

  localparam V_ACTIVE_PIXEL = 480;
  localparam V_FRONT_PORCH = 10;
  localparam V_SYNC_PULSE = 2;
  localparam V_BACK_PORCH = 33;
  localparam V_TOTAL_PIXEL = (V_ACTIVE_PIXEL + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH - 1);

  reg [9:0] hsync_count;
  reg [9:0] vsync_count;

  // Pixel counters
  always @(posedge i_clk_25mhz) begin
    if (!i_rstn) begin
      hsync_count <= 0;
      vsync_count <= 0;
    end else begin
      // Horizontal counter
      if (hsync_count == H_TOTAL_PIXEL) begin
        hsync_count <= 0;
        // Vertical counter
        if (vsync_count == V_TOTAL_PIXEL) begin
          vsync_count <= 0;
        end else begin
          vsync_count <= vsync_count + 1'b1;
        end
      end else begin
        hsync_count <= hsync_count + 1'b1;
      end
    end
  end

  // Synchronize sync pulses with clock
  always @(posedge i_clk_25mhz) begin
    if (!i_rstn) begin
      vga_hsync <= 0;
      vga_vsync <= 0;
    end else begin
      vga_hsync <= hsync_nxt;
      vga_vsync <= vsync_nxt;
    end

  end

  // Horizontal sync: active low during sync pulse
  assign hsync_nxt = ((hsync_count >= (H_ACTIVE_PIXEL + H_FRONT_PORCH)) && 
                        (hsync_count < (H_ACTIVE_PIXEL + H_FRONT_PORCH + H_SYNC_PULSE))) ? 
                       1'b0 : 1'b1;

  // Vertical sync: active low during sync pulse  
  assign vsync_nxt = ((vsync_count >= (V_ACTIVE_PIXEL + V_FRONT_PORCH)) && 
                        (vsync_count < (V_ACTIVE_PIXEL + V_FRONT_PORCH + V_SYNC_PULSE))) ? 
                       1'b0 : 1'b1;

  assign dp_en = ((hsync_count <= H_ACTIVE_PIXEL) && (vsync_count <= V_ACTIVE_PIXEL)) ? 1'b1 : 1'b0;

  assign h_pos = hsync_count;
  assign v_pos = vsync_count;

endmodule
