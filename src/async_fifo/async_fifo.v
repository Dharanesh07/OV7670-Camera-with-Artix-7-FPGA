module async_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
) (
    input              i_wr_inc,
    input              i_wr_clk,
    input              i_wrrst_n,
    input              i_rd_inc,
    input              i_rd_clk,
    input              i_rdrst_n,
    output             wr_full,
    output             rd_empty,
    input  [WIDTH-1:0] i_datain,
    output [WIDTH-1:0] o_dataout
);


  parameter ADDR_SIZE = $clog2(DEPTH);

  wire [ADDR_SIZE-1:0] waddr, raddr;
  wire [ADDR_SIZE:0] wptr, rptr, wq2_rptr, rq2_wptr;


  synchronizer #(
      .WIDTH(ADDR_SIZE + 1)
  ) inst_r2w (
      .i_clk   (i_wr_clk),
      .i_rst_n (i_wrrst_n),
      .i_datain(rptr),
      .o_q2    (wq2_rptr)
  );


  synchronizer #(
      .WIDTH(ADDR_SIZE + 1)
  ) inst_w2r (
      .i_clk   (i_rd_clk),
      .i_rst_n (i_rdrst_n),
      .i_datain(wptr),
      .o_q2    (rq2_wptr)
  );
  fifo_mem #(
      .DATA_SIZE(WIDTH),
      .ADDR_SIZE(ADDR_SIZE)
  ) inst_fifo_mem (
      .i_rstn   (i_rdrst_n),
      .rdata  (o_dataout),
      .wdata  (i_datain),
      .waddr  (waddr),
      .raddr  (raddr),
      .wclk_en(i_wr_inc),
      .wfull  (wr_full),
      .wclk   (i_wr_clk),
      .rclk   (i_rd_clk)
  );

  read_ptr #(
      .ADDR_SIZE(ADDR_SIZE)
  ) inst_read_ptr (
      .i_rd_inc       (i_rd_inc),
      .i_rd_clk       (i_rd_clk),
      .i_rdrst_n      (i_rdrst_n),
      .o_rd_empty     (rd_empty),
      .o_rd_addr      (raddr),
      .o_gray_rdptr   (rptr),
      .i_gray_q2_wrptr(rq2_wptr)
  );

  write_ptr #(
      .ADDR_SIZE(ADDR_SIZE)
  ) inst_write_ptr (
      .i_wr_inc     (i_wr_inc),
      .i_wr_clk(i_wr_clk),
      .i_wrrst_n(i_wrrst_n),
      .o_wr_full(wr_full),
      .o_wr_addr(waddr),
      .o_gray_wrptr(wptr),
      .i_gray_q2_rdptr(wq2_rptr)
  );
endmodule

// ---------------------------EXPLANATION---------------------------------
// This module is a FIFO implementation with configurable data and address
// sizes. It consists of a memory module, read and write pointer handling
// modules, and read and write pointer synchronization modules. The read and
// write pointers are synchronized to the respective clock domains, and the
// read and write pointers are checked for empty and full conditions,
// respectively. The FIFO memory module stores the data and handles the
// read and write operations.
// -----------------------------------------------------------------------
