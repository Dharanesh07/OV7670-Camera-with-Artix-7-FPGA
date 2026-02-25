module #(
    parameter RESET_CYCLES = 32'd100000
) reset(
    input i_clk,
    wire o_rstn,
    wire o_rst_done
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
    end else begin
      rstn <= 1'b1;
      rst_done <= 1'b1;
    end
  end

assign o_rstn = rstn;
assign o_rst_done = rst_done;

endmodule