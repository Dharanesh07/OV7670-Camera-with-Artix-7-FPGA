module top (
    input         sys_clk,
    output        sdram_clk,
    output        sdram_cke,
    output [ 1:0] sdram_dqm,
    output        sdram_casn,
    output        sdram_rasn,
    output        sdram_wen,
    output        sdram_csn,
    output [ 1:0] sdram_ba,
    output [12:0] sdram_addr,
    inout  [15:0] sdram_data,
    output [ 7:0] debug_led

);


  reg  [14:0] r_rst_cycle = 0;
  reg         o_rstn = 1'b0;
  wire        clk_133mhz;
  wire        pll_lock;

  clock_133mhz inst_clock (
      .clk_in       (sys_clk),
      .i_rstn       (1'b1),
      .clk_out0     (clk_133mhz),
      .clk_out1     (),
      .is_pll_locked(pll_lock)
  );
  /*
  clock_1mhz inst_clock (
      .clk_in       (sys_clk),
      .i_rstn       (1'b1),
      .clk_out0     (clk_133mhz),
      .is_pll_locked(pll_lock)
  );
*/

  //assign clk_133mhz = sys_clk;

  parameter SDRAM_CLK_FREQ_MHZ = 133;
  parameter TRP_NS = 15;
  parameter TRC_NS = 66;
  parameter TRCD_NS = 15;
  parameter TCH_NS = 2;
  parameter CAS = 3'd3;

  wire [15:0] s2f_dataout;
  wire        is_sdram_ready;
  reg  [14:0] f2s_addr;
  wire [15:0] f2s_datain;
  wire        i_dataval;
  reg         o_rw;
  reg         o_sdram_en;
  wire        i_writing;
  reg  [15:0] data;
  wire [15:0] rd_data;
  wire [15:0] wr_data;
  reg  [ 7:0] test_count;

  sdram_ctrl #(
      .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
      .TRP_NS            (TRP_NS),
      .TRC_NS            (TRC_NS),
      .TRCD_NS           (TRCD_NS),
      .TCH_NS            (TCH_NS),
      .CAS               (CAS)
  ) inst_sdram_ctrl (
      .i_clk     (clk_133mhz),
      .i_rstn    (o_rstn),
      .i_addr    (f2s_addr),
      .i_sdram_en(o_sdram_en),
      .i_datain  (f2s_datain),
      .i_rw      (o_rw),
      .o_dataval (i_dataval),
      .is_writing(i_writing),
      .o_dataout (s2f_dataout),
      .o_ready   (is_sdram_ready),
      .sdram_clk (sdram_clk),
      .sdram_cke (sdram_cke),
      .sdram_dqm (sdram_dqm),
      .sdram_addr(sdram_addr),
      .sdram_ba  (sdram_ba),
      .sdram_csn (sdram_csn),
      .sdram_wen (sdram_wen),
      .sdram_rasn(sdram_rasn),
      .sdram_casn(sdram_casn),
      .sdram_data(sdram_data),
      .rd_data   (rd_data),
      .wr_data   (wr_data)
  );



  localparam START = 0;
  localparam RESET = 1;
  localparam WRITE_DATA_INIT = 2;
  localparam WRITE_DATA = 3;
  localparam READ_DATA_INIT = 4;
  localparam READ_DATA = 5;
  localparam IDLE = 6;

  reg [2:0] rstate;
  reg       rst_done = 0;
  reg [9:0] burst_index;





  always @(posedge clk_133mhz) begin

    case (rstate)
      START: begin
        if (!rst_done) rstate <= RESET;
        else begin
          if (is_sdram_ready) begin
            rstate <= WRITE_DATA_INIT;
          end
        end
      end

      WRITE_DATA_INIT: begin
        o_sdram_en <= 1'b1;  // Pulse once
        o_rw       <= 1'b0;
        rstate     <= WRITE_DATA;
      end

      WRITE_DATA: begin
        o_sdram_en <= 1'b0;
        o_rw       <= 1'b0;
        if (burst_index == 512) begin
          o_rw        <= 1'b1;  //read mode
          burst_index <= 0;
          rstate      <= READ_DATA_INIT;
        end else begin
          if (i_writing) begin
            burst_index <= burst_index + 1;
          end
        end
      end


      READ_DATA_INIT: begin
        o_sdram_en <= 1'b1;  // Pulse once
        o_rw       <= 1'b1;
        rstate     <= READ_DATA;
      end

      READ_DATA: begin
        o_sdram_en <= 1'b0;
        if (burst_index == 512) begin
          burst_index <= 0;
          rstate      <= IDLE;
        end else begin
          if (i_dataval) begin
            data <= s2f_dataout;
            if (s2f_dataout == (777 + burst_index)) begin  // Check current data
              test_count <= test_count + 1;
            end
            burst_index <= burst_index + 1;
          end else rstate <= READ_DATA;
        end
        //if (burst_index >= 512) rstate <= START;
      end

      IDLE: begin
        rstate <= IDLE;
      end

      RESET: begin
        if (r_rst_cycle < 10000) begin
          r_rst_cycle <= r_rst_cycle + 1;
          o_rstn      <= 0;
          o_sdram_en  <= 0;
          burst_index <= 0;
          data        <= 0;
          test_count  <= 0;
          o_rw        <= 0;
          f2s_addr    <= 0;
        end else begin
          o_rstn   <= 1'b1;
          rst_done <= 1'b1;
          rstate   <= START;
        end
      end
      default: rstate <= START;
    endcase
  end



  assign f2s_datain = burst_index + 16'd777;
  assign debug_led  = ~(test_count);

  /*
  ila_0 test_ila (
      .clk   (clk_133mhz),  // ILA clock
      .probe0(sdram_casn),  // 1-bit
      .probe1(sdram_rasn),  // 1-bit
      .probe2(sdram_csn),  // 1-bit
      .probe3(sdram_wen),   // 1-bit
      .probe4(sdram_addr),
      .probe5(wr_data),
      .probe6(rd_data)  // 15-bit
  );
*/

endmodule


