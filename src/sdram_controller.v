`timescale 1ns / 10ps

module sdram_controller (
    input             i_clk_166mhz,
    input             i_rstn,
    // SDRAM hardware
    output            sdram_clk,
    output            sdram_cke,
    output     [ 1:0] sdram_dqm,
    output            sdram_casn,
    output            sdram_rasn,
    output            sdram_wen,
    output            sdram_csn,
    output     [ 1:0] sdram_ba,
    output     [12:0] sdram_addr,
    inout      [15:0] sdram_data,
    // FIFO signals
    output reg [15:0] vga_fifo_data,
    output reg        vga_fifo_wren,
    input      [15:0] ov7670_fifo_data,
    input             ov7670_half_full,
    input             ov7670_fifo_empty,
    output reg        ov7670_fifo_rden,
    input             vga_read_request
);

  localparam SDRAM_CLK_FREQ_MHZ = 166;
  localparam TRP_NS = 15;
  localparam TRC_NS = 66;
  localparam TRCD_NS = 15;
  localparam TCH_NS = 2;
  localparam CAS = 3'd3;

  localparam BURST_LENGTH = 512;

  // sdram control signals
  reg  [14:0] o_addr;
  reg  [15:0] wr_data;
  reg         o_rw;
  reg         o_sdram_en;

  // sdram status signals
  wire [15:0] rd_data;
  wire        i_ready;
  wire        i_dataval;
  wire        i_writing;

  sdram #(
      .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
      .TRP_NS(TRP_NS),
      .TRC_NS(TRC_NS),
      .TRCD_NS(TRCD_NS),
      .TCH_NS(TCH_NS),
      .CAS(CAS)
  ) sdram_inst (
      .i_clk     (i_clk_166mhz),
      .i_rstn    (i_rstn),
      .i_addr    (o_addr),
      .i_sdram_en(o_sdram_en),
      .i_datain  (wr_data),
      .i_rw      (o_rw),
      .o_dataval (i_dataval),
      .is_writing(i_writing),
      .o_dataout (rd_data),
      .o_ready   (i_ready),
      .sdram_clk (sdram_clk),
      .sdram_cke (sdram_cke),
      .sdram_dqm (sdram_dqm),
      .sdram_addr(sdram_addr),
      .sdram_ba  (sdram_ba),
      .sdram_csn (sdram_csn),
      .sdram_wen (sdram_wen),
      .sdram_rasn(sdram_rasn),
      .sdram_casn(sdram_casn),
      .sdram_data(sdram_data)
  );

  localparam IDLE = 0;
  localparam WRITE_MODE = 1;
  localparam WRITE_BURST = 2;
  localparam READ_MODE = 3;
  localparam READ_WAIT = 4;
  localparam READ_BURST = 5;
  localparam WAIT = 6;

  reg [2:0] state;
  reg [2:0] ret_state;
  reg [9:0] burst_count;
  reg [4:0] wait_cycles;

  localparam REFRESH_DELAY = 6;

  always @(posedge i_clk_166mhz) begin
    if (!i_rstn) begin
      state            <= IDLE;
      o_addr           <= 0;
      o_rw             <= 0;
      wr_data          <= 0;
      o_sdram_en       <= 0;
      ov7670_fifo_rden <= 0;
      vga_fifo_wren    <= 0;
      burst_count      <= 0;
      ret_state        <= 0;
      wait_cycles      <= 0;
    end else begin
      case (state)

        IDLE: begin
          if (ov7670_half_full) begin
            state      <= WRITE_MODE;
            o_sdram_en <= 1'b1;
            o_rw       <= 1'b0;  // Write
          end
        end

        WRITE_MODE: begin
          // set the row and bank address to start write
          // ful page mode
          o_sdram_en       <= 1'b1;
          o_rw             <= 1'b0;  // Write
          o_addr           <= 0;
          ov7670_fifo_rden <= 1'b1;
          wr_data          <= ov7670_fifo_data;
          state            <= WRITE_BURST;
        end


        WRITE_BURST: begin
          ov7670_fifo_rden <= 1'b0;
          if (i_ready && i_writing) begin
            burst_count      <= 0;
            ov7670_fifo_rden <= 1'b1;
            wr_data          <= ov7670_fifo_data;
            burst_count      <= burst_count + 1;

            //if (sdram_burst_done) begin
            if (burst_count == BURST_LENGTH - 1) begin
              ov7670_fifo_rden <= 1'b0;
              wait_cycles      <= REFRESH_DELAY;
              state            <= WAIT;
              burst_count      <= 0;
              o_addr           <= 0;
              o_rw             <= 1;  // Read
              ret_state        <= READ_BURST;
            end
          end
        end


        READ_BURST: begin
          if (i_dataval) begin
            vga_fifo_data <= rd_data;
            vga_fifo_wren <= 1'b1;
            burst_count   <= burst_count + 1;

            //if (sdram_burst_done) begin

            if (burst_count == BURST_LENGTH - 1) begin
              vga_fifo_wren <= 1'b0;
              o_sdram_en    <= 1'b0;
              o_rw          <= 1'b0;
              wait_cycles   <= REFRESH_DELAY;
              state         <= WAIT;
              ret_state     <= IDLE;
            end
          end
        end

        WAIT: begin
          wait_cycles = wait_cycles - 1'b1;
          if (wait_cycles == 0) state <= ret_state;
        end

        default: state <= IDLE;
      endcase
    end
  end

  /*
  parameter OUTPUT_FILE = "sdram_data.txt";
  integer file;

  initial begin
    file = $fopen(OUTPUT_FILE, "w");
    if (!file) begin
      $display("Error: Could not open output file.");
      $finish;
    end
  end

  reg rden_d;
  always @(posedge i_clk_166mhz) begin
    rden_d <= ov7670_fifo_rden;
    if (rden_d) $fdisplay(file, "%h", ov7670_fifo_data);
  end
*/
endmodule
