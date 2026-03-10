/*

// -------------PARAMETERS------------
// DATA_SIZE: Size of the data bus
// ADDR_SIZE: Size of the address bus
// The module has a memory array (mem) with a depth of 2^ADDR_SIZE.
// The read and write addresses are used to access the memory array.
// The write clock enable (wclk_en) and write full (wfull) signals are used
// to control the writing process. The write data is stored in the memory
// array on the rising edge of the write clock (wclk).

module fifo_mem #(
    parameter DATA_SIZE = 8,
    parameter ADDR_SIZE = 4
) (
    output [DATA_SIZE-1:0] rdata,
    input  [DATA_SIZE-1:0] wdata,
    input  [ADDR_SIZE-1:0] waddr,
    input  [ADDR_SIZE-1:0] raddr,
    input                  wclk_en,
    input                  wfull,
    input rclk,
    input                  wclk
);

  localparam DEPTH = 1 << ADDR_SIZE;  // Depth of the FIFO memory
  reg [DATA_SIZE-1:0] mem[0:DEPTH-1];  // Memory array

  always @(posedge wclk) begin
    if (wclk_en && !wfull) mem[waddr] <= wdata;  // Write data
  end

  assign rdata = mem[raddr];  // Read data

endmodule

*/


module fifo_mem #(
    parameter DATA_SIZE = 8,
    parameter ADDR_SIZE = 4
) (
    input                      i_rstn,
    output reg [DATA_SIZE-1:0] rdata,
    input      [DATA_SIZE-1:0] wdata,
    input      [ADDR_SIZE-1:0] waddr,
    input      [ADDR_SIZE-1:0] raddr,
    input                      wclk_en,
    input                      wfull,
    input                      wclk,
    input                      rclk       // Added read clock
);

  localparam DEPTH = 1 << ADDR_SIZE;
  reg [DATA_SIZE-1:0] mem[0:DEPTH-1];

  // Write port
  always @(posedge wclk) begin
    if (wclk_en && !wfull) mem[waddr] <= wdata;
  end

  // Read port (synchronous)
  always @(posedge rclk) begin
    if (!i_rstn) rdata <= 32'b0;
    else rdata <= mem[raddr];
  end

endmodule
