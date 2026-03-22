//-------------PARAMETERS---------------------------
// ADDR_SIZE: Size of the address bus

// The module implements a write pointer for a FIFO with a full flag.
// The write pointer is implemented in gray code to avoid glitches when
// transitioning between clock domains. The write pointer is incremented based
// on the write increment signal and the full flag. The full flag is set
// when the write pointer is equal to the read pointer, indicating that
// the FIFO is full. The write pointer and full flag are updated on each
// clock cycle, and the write address is calculated from the write pointer.

//ADDR_SIZE:0 is used for pointers because they need an extra bit to track wrap-around conditions.
//ADDR_SIZE-1:0 is used for addresses because they directly index into the FIFO memory and do not need the extra bit.

`timescale 1ns / 10ps

module write_ptr #(
    parameter ADDR_SIZE = 4
) (
    input                      i_wr_inc,
    input                      i_wr_clk,
    input                      i_wrrst_n,
    output reg                 half_full,
    output reg                 o_wr_full,
    output     [ADDR_SIZE-1:0] o_wr_addr,
    output reg [ADDR_SIZE : 0] o_gray_wrptr,
    input      [ADDR_SIZE : 0] i_gray_q2_rdptr
);

  reg  [ADDR_SIZE:0] wr_bin;
  wire [ADDR_SIZE:0] wr_gray_next;
  wire [ADDR_SIZE:0] wr_bin_next;
  wire               wr_full_val;
  wire               wr_half_full;

  always @(posedge i_wr_clk) begin
    if (!i_wrrst_n) begin
      o_gray_wrptr <= 0;
      wr_bin <= 0;
    end else begin
      wr_bin <= wr_bin_next;
      o_gray_wrptr <= wr_gray_next;
    end
  end

  always @(posedge i_wr_clk) begin
    if (!i_wrrst_n) begin
      o_wr_full <= 1'b0;
      half_full <= 1'b0;
    end else begin
      o_wr_full <= wr_full_val;
      half_full <= wr_half_full;
    end
  end


  assign o_wr_addr = wr_bin[ADDR_SIZE-1:0];  // Write address calculation from the write pointer
  assign wr_bin_next = wr_bin + (i_wr_inc & ~o_wr_full);  // Increment the write pointer if not full
  assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;  // Convert binary to gray code


  //In gray code, the FIFO is full when:
  //The MSB (Most Significant Bit) of the write pointer is inverted compared to the read pointer.
  //The second MSB of the write pointer is inverted compared to the read pointer.
  //The remaining bits of the write pointer are equal to the read pointer.

  assign wr_full_val = (wr_gray_next == {~i_gray_q2_rdptr[ADDR_SIZE:ADDR_SIZE-1],i_gray_q2_rdptr[ADDR_SIZE-2:0]});

  // Gray to binary conversion for the synchronized read pointer
  wire [ADDR_SIZE:0] rd_bin_sync;
  genvar i;
  generate
    for (i = ADDR_SIZE; i > 0; i = i - 1) begin : gray2bin
      assign rd_bin_sync[i-1] = ^(i_gray_q2_rdptr >> (i - 1));
    end
  endgenerate
  assign rd_bin_sync[ADDR_SIZE] = i_gray_q2_rdptr[ADDR_SIZE];

  // Occupancy = write pointer - read pointer (wraps correctly due to extra bit)
  wire [ADDR_SIZE:0] fifo_occupancy;
  assign fifo_occupancy = wr_bin_next - rd_bin_sync;

  // Half-full when occupancy >= half the FIFO depth
  assign wr_half_full   = fifo_occupancy >= (1 << (ADDR_SIZE - 1));

endmodule




// Check if the FIFO is full
//------------------------------------------------------------------
// Simplified version of the three necessary full-tests:
// assign wr_full_val=((wr_gray_next[ADDR_SIZE] !=i_gray_q2_rdptr[ADDR_SIZE] ) &&
// (wr_gray_next[ADDR_SIZE-1] !=i_gray_q2_rdptr[ADDR_SIZE-1]) &&
// (wr_gray_next[ADDR_SIZE-2:0]==i_gray_q2_rdptr[ADDR_SIZE-2:0]));
//------------------------------------------------------------------
