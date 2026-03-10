// -------------PARAMETERS------------
// WIDTH: Size of the input data bus

// The module has two flip-flops, q1 and q2, which store the input data. 
// On each clock cycle, the data is shifted from q1 to q2, and new data 
// is loaded into q1. The reset signal (rst_n) is active low, meaning the 
// FIFO is reset when rst_n is low.  


module synchronizer #(
    parameter WIDTH = 4
) (
    input i_clk,
    input i_rst_n,
    input [WIDTH-1:0] i_datain,
    output reg [WIDTH-1:0] o_q2
);

  //output of first flip-flop
  reg [WIDTH-1:0] o_q1;
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      o_q1 <= 0;
      o_q2 <= 0;
    end else begin
      o_q1 <= i_datain;
      o_q2 <= o_q1;
    end
  end


endmodule
