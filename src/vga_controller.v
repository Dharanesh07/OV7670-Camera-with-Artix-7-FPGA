`timescale 1ns / 10ps

module vga_controller (
    input             i_clk_25mhz,
    input             i_rstn,
    input             fifo_empty,
    input      [15:0] fifo_datain,
    output reg        fifo_rden,
    output            vga_hsync,
    output            vga_vsync,
    output     [ 3:0] vga_red,
    output     [ 3:0] vga_blue,
    output     [ 3:0] vga_green
);

  wire [9:0] x_pos;
  wire [9:0] y_pos;
  reg  [3:0] red;
  reg  [3:0] blue;
  reg  [3:0] green;
  reg        vga_enable;

  vga inst_vga (
      .i_clk_25mhz(i_clk_25mhz),
      .i_rstn     (i_rstn),
      .vga_en     (),
      .active_pix (disp_enable),
      .h_pos      (x_pos),
      .v_pos      (y_pos),
      .vga_hsync  (vga_hsync),
      .vga_vsync  (vga_vsync)
  );

  assign vga_red   = red;
  assign vga_blue  = blue;
  assign vga_green = green;


  always @(posedge i_clk_25mhz) begin
    if (!i_rstn) begin
      vga_enable <= 1'b0;
      red        <= 0;
      blue       <= 0;
      green      <= 0;
    end else begin
      if (!fifo_empty) begin
        vga_enable <= 1'b1;
        fifo_rden  <= 1'b1;
        red        <= fifo_datain[14:11];
        green      <= fifo_datain[9:6];
        blue       <= fifo_datain[3:0];
      end
    end
  end
endmodule


