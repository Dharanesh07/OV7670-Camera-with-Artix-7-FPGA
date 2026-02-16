module bram #(
    parameter WIDTH = 16,
    parameter DEPTH = 101,
    parameter INIT_FILE = "reg.mem",
    parameter LEN = $clog2(DEPTH)
) (
    input                  i_bram_clkrd,
    input                  i_bram_rstn,
    input                  i_bram_rden,
    input      [  LEN-1:0] i_bram_rdaddr,
    output reg [WIDTH-1:0] o_bram_dataout,
    output                 o_bram_rd_comp
);

  (* ram_style = "block" *) reg [WIDTH-1:0] block_ram[0:DEPTH-1];

  initial begin
    $display("Loading init file '%s' into bram", INIT_FILE);
    $readmemh(INIT_FILE, block_ram, 0, DEPTH - 1);
  end

  reg [LEN-1:0] count;

  always @(posedge i_bram_clkrd) begin
    if (!i_bram_rstn) begin
      o_bram_dataout <= 0;
      count          <= 0;
    end else if (i_bram_rden) begin
      o_bram_dataout <= block_ram[i_bram_rdaddr];
      count          <= count + 1;
    end
  end

  assign o_bram_rd_comp = (count == DEPTH) ? 1'b1 : 1'b0;

endmodule
