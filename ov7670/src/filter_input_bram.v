module filter_input_bram #(
    parameter SIG_WIDTH = 16,
    parameter SIG_DEPTH = 101,
    parameter SIG_FILE  = "sig.txt",
    parameter SIG_LEN   = 100
) (
    input i_clk,
    input i_rstn,
    output reg fir_valid,
    output reg sig_comp,
    output wire [SIG_WIDTH-1:0] sig_out
);

  //Block ram 
  parameter LEN = $clog2(SIG_DEPTH);
  reg o_bram_rden;
  reg [LEN-1:0] o_bram_addr;
  wire [SIG_WIDTH-1:0] i_bram_dat;
  reg [LEN:0] count;
  reg [SIG_WIDTH-1:0] bram_data_reg;



  bram #(
      .WIDTH    (SIG_WIDTH),
      .DEPTH    (SIG_DEPTH),
      .INIT_FILE(SIG_FILE),
      .END_COUNT(SIG_LEN),
      .LEN      (LEN)
  ) coeff_mem (
      .i_bram_clkrd  (i_clk),
      .i_bram_rstn   (i_rstn),
      .i_bram_rden   (o_bram_rden),
      .o_bram_dataout(i_bram_dat),
      .i_bram_rdaddr (o_bram_addr)
  );

  always @(posedge i_clk) begin
    if (!i_rstn) begin
      sig_comp <= 1'b0;
      o_bram_rden <= 1'b0;
      o_bram_addr <= 0;
      count <= 0;
      bram_data_reg <= 0;
      fir_valid <= 1'b0;
    end else begin
      o_bram_rden <= 1'b1;
      if (count < SIG_LEN - 1) begin
        //o_bram_rden <= 1'b1;
        o_bram_addr <= count;
        bram_data_reg <= i_bram_dat;
        count <= count + 1;
        fir_valid <= 1'b1;
      end else begin
        fir_valid <= 1'b0;
        o_bram_rden <= 1'b0;
        sig_comp <= 1'b1;
      end
    end
  end
  assign sig_out = bram_data_reg;

endmodule


/*
module filter_input_bram #(
    parameter SIG_WIDTH = 16,
    parameter SIG_DEPTH = 101,
    parameter SIG_FILE  = "sig.txt",
    parameter SIG_LEN   = 100
) (
    input i_clk,
    input i_rstn,
    output reg fir_valid,
    output reg sig_comp,
    output reg [SIG_WIDTH-1:0] sig_out  // Changed to reg for better synthesis
);

    // Local parameters for better synthesis
    localparam LEN = $clog2(SIG_DEPTH);
    
    // Internal signals
    reg o_bram_rden;
    reg [LEN-1:0] o_bram_addr;
    wire [SIG_WIDTH-1:0] i_bram_dat;
    reg [LEN-1:0] count;
    
    // State machine for better control
    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam COMPLETE = 2'b10;

    // BRAM instance
    bram #(
        .WIDTH    (SIG_WIDTH),
        .DEPTH    (SIG_DEPTH),
        .INIT_FILE(SIG_FILE),
        .END_COUNT(SIG_LEN),
        .LEN      (LEN)
    ) signal_memory (
        .i_bram_clkrd  (i_clk),         // Direct clock connection
        .i_bram_rstn   (i_rstn),
        .i_bram_rden   (o_bram_rden),
        .o_bram_dataout(i_bram_dat),
        .i_bram_rdaddr (o_bram_addr)
    );

    // Main control logic with proper state machine
    always @(posedge i_clk) begin
        if (!i_rstn) begin
            o_bram_rden <= 1'b0;
            o_bram_addr <= {LEN{1'b0}};
            count <= {LEN{1'b0}};
            sig_comp <= 1'b0;
            fir_valid <= 1'b0;
            sig_out <= {SIG_WIDTH{1'b0}};
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    count <= {LEN{1'b0}};
                    o_bram_addr <= {LEN{1'b0}};
                    o_bram_rden <= 1'b1;
                    sig_comp <= 1'b0;
                    fir_valid <= 1'b0;
                    state <= READING;
                end
                
                READING: begin
                    if (count < SIG_LEN) begin
                        o_bram_rden <= 1'b1;
                        o_bram_addr <= count;
                        sig_out <= i_bram_dat;  // Register the output
                        fir_valid <= 1'b1;
                        
                        if (count == SIG_LEN - 1) begin
                            state <= COMPLETE;
                        end else begin
                            count <= count + 1'b1;
                        end
                    end
                end
                
                COMPLETE: begin
                    fir_valid <= 1'b0;
                    o_bram_rden <= 1'b0;
                    sig_comp <= 1'b1;
                    // Stay in complete state
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule



*/

