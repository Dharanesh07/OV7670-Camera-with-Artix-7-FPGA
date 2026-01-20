module vga#(

)(
   input i_clk_25mhz,
   input i_rstn,
   output vga_clk,
   output vga_hsync,
   output vga_vsync,
    input [3:0] red,
    input [3:0] blue,
    input [3:0] green,
   output reg [3:0] vga_red,
   output reg [3:0] vga_blue,
   output reg [3:0] vga_green
);

localparam H_ACTIVE_PIXEL = 640;
localparam V_ACITVE_PIXEL = 480;

localparam H_FRONT_PORCH = 16;
localparam H_SYNC_PULSE = 96;
localparam H_BACK_PORCH = 48;

localparam V_FRONT_PORCH = 10;
localparam V_SYNC_PULSE = 2;
localparam V_BACK_PORCH = 33; 

// V_TOTAL_PIXEL = V_ACTIVE_PIXEL + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH
// H_TOTAL_PIXEL = H_ACTIVE_PIXEL + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH

localparam H_TOTAL_PIXEL = 800;
localparam V_TOTAL_PIXEL = 525;

reg [9:0] hsync_count;
reg [9:0] vsync_count;

always @(posedge i_clk_25mhz) begin
    if(!i_rstn) begin
        hsync_count <= 0;
        vsync_count <= 0;
    end else begin
        hsync_count <= hsync_count + 1'b1;
        if(hsync_count == H_TOTAL_PIXEL) begin
            hsync_count <= 0;
            vsync_count <= vsync_count + 1'b1;
            if(vsync_count == V_TOTAL_PIXEL) vsync_count <= 0;
        end 
    end
end

always @(*) begin
    if(hsync_count < H_ACTIVE_PIXEL) begin
        
    end

end

assign vga_hsync = (hsync_count > (H_ACTIVE_PIXEL+ H_FRONT_PORCH) && hsync_count <= (H_ACTIVE_PIXEL+H_FRONT_PORCH+H_SYNC_PULSE)):1'b0:1'b1;
assign vga_vsync = (vsync_count > (V_ACTIVE_PIXEL+ V_FRONT_PORCH) && vsync_count <= (V_ACTIVE_PIXEL+V_FRONT_PORCH+V_SYNC_PULSE)):1'b0:1'b1;


endmodule
