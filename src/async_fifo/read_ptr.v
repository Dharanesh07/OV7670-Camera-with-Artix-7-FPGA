
//-------------PARAMETERS---------------------------


// ADDR_SIZE: Size of the address bus
// The module implements a read pointer for a FIFO with an empty flag.
// The read pointer is implemented in gray code to avoid glitches when
// transitioning between clock domains. The read pointer is incremented based
// on the read increment signal and the empty flag. The empty flag is set
// when the read pointer is equal to the write pointer, indicating that
// the FIFO is empty. The read pointer and empty flag are updated on each
// clock cycle, and the read address is calculated from the read pointer.


module read_ptr #(
    parameter ADDR_SIZE = 4
) (

    input                      i_rd_inc,
    input                      i_rd_clk,
    input                      i_rdrst_n,
    input      [ADDR_SIZE : 0] i_gray_q2_wrptr,
    output reg                 o_rd_empty,       // Empty flag
    output     [ADDR_SIZE-1:0] o_rd_addr,        // Read address
    output reg [ADDR_SIZE : 0] o_gray_rdptr      // Read pointer
);

  reg  [ADDR_SIZE:0] rd_bin;  // Binary read pointer
  wire [ADDR_SIZE:0] rd_gray_next;  // Next read pointer in gray code
  wire [ADDR_SIZE:0] rd_bin_next;  // Next read pointer in binary code
  wire               rd_empty_val;  // Empty flag value

  always @(posedge i_rd_clk) begin
    if (!i_rdrst_n) begin
      rd_bin <= 0;
      o_gray_rdptr <= 0;
    end else begin
      rd_bin <= rd_bin_next;
      o_gray_rdptr <= rd_gray_next;
    end
  end


  always @(posedge i_rd_clk) begin
    if (!i_rdrst_n) o_rd_empty <= 1'b1;
    else o_rd_empty <= rd_empty_val;
  end


  assign o_rd_addr = rd_bin[ADDR_SIZE-1:0];  // Read address calculation from the read pointer
  assign rd_bin_next = rd_bin + (i_rd_inc & ~o_rd_empty);  // Increment the read pointer if not empty
  assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;  // Convert binary to gray code

  // Check if the FIFO is empty
  assign rd_empty_val = (rd_gray_next == i_gray_q2_wrptr);  // Empty flag calculation



endmodule

