module dual_port_bram #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 128,
    parameter ADDR_WIDTH = $clog2(DEPTH + 1)
) (
    input  wire                  clk,
    input  wire                  i_rstn,
    input  wire                  we_en,
    input  wire [  ADDR_WIDTH:0] addr_wr,
    input  wire [  ADDR_WIDTH:0] addr_rd,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out
);

  (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem[0:DEPTH];
  parameter INIT_FILE = "dualportbram.txt";

  initial begin
    $display("Loading init file '%s' into bram", INIT_FILE);
    $readmemb(INIT_FILE, mem, 0, DEPTH);
  end

  always @(posedge clk) begin
    if (!i_rstn) data_out <= 0;
    else if (we_en) mem[addr_wr] <= data_in;
    data_out <= mem[addr_rd];
  end

endmodule

