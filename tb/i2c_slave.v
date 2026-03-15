`timescale 1ns / 1ps

module i2c_slave #(
    parameter SLAVE_ADDR = 7'h50  // 7-bit I2C slave address
) (
    input            i_clk,
    input            i_rstn,
    // I2C Interface
    input            i2c_scl,
    inout            i2c_sda,
    // Internal Interface
    output reg       o_reg_write,  // Pulse when register write occurs
    output reg [7:0] o_reg_addr,   // Register address being accessed
    output reg [7:0] o_reg_wdata,  // Data to write to register
    input      [7:0] i_reg_rdata,  // Data read from register
    output reg       o_addr_valid  // Address has been latched
);

  // State machine states
  localparam IDLE = 4'd0;
  localparam START_DET = 4'd1;
  localparam RX_ADDR = 4'd2;
  localparam SEND_ACK_ADDR = 4'd3;
  localparam RX_DATA = 4'd4;
  localparam SEND_ACK_DATA = 4'd5;
  localparam TX_DATA = 4'd6;
  localparam RX_ACK_DATA = 4'd7;
  localparam STOP_DET = 4'd8;

  reg [3:0] state, state_nxt;
  reg [7:0] shift_reg, shift_reg_nxt;
  reg [3:0] bit_count, bit_count_nxt;
  reg [7:0] reg_addr, reg_addr_nxt;
  reg [7:0] reg_wdata, reg_wdata_nxt;
  reg sda_out, sda_out_nxt;
  reg sda_oe, sda_oe_nxt;  // Output enable for SDA
  reg rw_bit, rw_bit_nxt;  // 0=write, 1=read
  reg addr_match, addr_match_nxt;

  // Edge detection for SCL and SDA
  reg [2:0] scl_sync;
  reg [2:0] sda_sync;

  wire scl_posedge;
  wire scl_negedge;
  wire sda_fall;
  wire sda_rise;
  wire start_condition;
  wire stop_condition;

  // Synchronize SCL and SDA to system clock
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      scl_sync <= 3'b111;
      sda_sync <= 3'b111;
    end else begin
      scl_sync <= {scl_sync[1:0], i2c_scl};
      sda_sync <= {sda_sync[1:0], i2c_sda};
    end
  end

  // Edge detection
  assign scl_posedge = (scl_sync[2:1] == 2'b01);
  assign scl_negedge = (scl_sync[2:1] == 2'b10);
  assign sda_fall = (sda_sync[2:1] == 2'b10);
  assign sda_rise = (sda_sync[2:1] == 2'b01);

  // Start condition: SDA falls while SCL is high
  assign start_condition = sda_fall && scl_sync[1];

  // Stop condition: SDA rises while SCL is high
  assign stop_condition = sda_rise && scl_sync[1];

  // Sequential logic
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      state      <= IDLE;
      shift_reg  <= 8'h00;
      bit_count  <= 4'd0;
      reg_addr   <= 8'h00;
      reg_wdata  <= 8'h00;
      sda_out    <= 1'b1;
      sda_oe     <= 1'b0;
      rw_bit     <= 1'b0;
      addr_match <= 1'b0;
    end else begin
      state      <= state_nxt;
      shift_reg  <= shift_reg_nxt;
      bit_count  <= bit_count_nxt;
      reg_addr   <= reg_addr_nxt;
      reg_wdata  <= reg_wdata_nxt;
      sda_out    <= sda_out_nxt;
      sda_oe     <= sda_oe_nxt;
      rw_bit     <= rw_bit_nxt;
      addr_match <= addr_match_nxt;
    end
  end

  // Combinational logic
  always @(*) begin
    // Default assignments
    state_nxt      = state;
    shift_reg_nxt  = shift_reg;
    bit_count_nxt  = bit_count;
    reg_addr_nxt   = reg_addr;
    reg_wdata_nxt  = reg_wdata;
    sda_out_nxt    = sda_out;
    sda_oe_nxt     = sda_oe;
    rw_bit_nxt     = rw_bit;
    addr_match_nxt = addr_match;
    o_reg_write    = 1'b0;
    o_addr_valid   = 1'b0;

    case (state)
      IDLE: begin
        sda_oe_nxt = 1'b0;  // Release SDA
        if (start_condition) begin
          state_nxt      = RX_ADDR;
          bit_count_nxt  = 4'd7;
          shift_reg_nxt  = 8'h00;
          addr_match_nxt = 1'b0;
        end
      end

      RX_ADDR: begin
        if (scl_posedge) begin
          shift_reg_nxt = {shift_reg[6:0], sda_sync[1]};
          if (bit_count == 4'd0) begin
            // Check if address matches
            if (shift_reg[7:1] == SLAVE_ADDR) begin
              addr_match_nxt = 1'b1;
              rw_bit_nxt = shift_reg[0];  // LSB is R/W bit
              state_nxt = SEND_ACK_ADDR;
            end else begin
              // Address doesn't match, go back to idle
              state_nxt = IDLE;
            end
          end else begin
            bit_count_nxt = bit_count - 1;
          end
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      SEND_ACK_ADDR: begin
        if (scl_negedge) begin
          sda_out_nxt = 1'b0;  // Send ACK (pull SDA low)
          sda_oe_nxt  = 1'b1;
        end else if (scl_posedge) begin
          sda_oe_nxt = 1'b0;  // Release SDA after ACK
          bit_count_nxt = 4'd7;
          shift_reg_nxt = 8'h00;

          if (rw_bit == 1'b0) begin
            // Write mode: receive register address next
            state_nxt = RX_DATA;
          end else begin
            // Read mode: send data
            shift_reg_nxt = i_reg_rdata;
            state_nxt = TX_DATA;
          end
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      RX_DATA: begin
        if (scl_posedge) begin
          shift_reg_nxt = {shift_reg[6:0], sda_sync[1]};
          if (bit_count == 4'd0) begin
            state_nxt = SEND_ACK_DATA;
            if (reg_addr == 8'hFF) begin
              // First byte is register address
              reg_addr_nxt = shift_reg_nxt;
              o_addr_valid = 1'b1;
            end else begin
              // Subsequent bytes are data
              reg_wdata_nxt = shift_reg_nxt;
              o_reg_write   = 1'b1;
            end
          end else begin
            bit_count_nxt = bit_count - 1;
          end
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      SEND_ACK_DATA: begin
        if (scl_negedge) begin
          sda_out_nxt = 1'b0;  // Send ACK
          sda_oe_nxt  = 1'b1;
        end else if (scl_posedge) begin
          sda_oe_nxt = 1'b0;  // Release SDA
          bit_count_nxt = 4'd7;
          shift_reg_nxt = 8'h00;

          // Mark that we've received the address
          if (reg_addr == 8'hFF) begin
            reg_addr_nxt = 8'h00;  // Reset flag
          end

          state_nxt = RX_DATA;  // Continue receiving data
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      TX_DATA: begin
        if (scl_negedge) begin
          sda_out_nxt = shift_reg[7];  // Send MSB
          sda_oe_nxt = 1'b1;
          shift_reg_nxt = {shift_reg[6:0], 1'b0};
          if (bit_count == 4'd0) begin
            state_nxt = RX_ACK_DATA;
          end else begin
            bit_count_nxt = bit_count - 1;
          end
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      RX_ACK_DATA: begin
        if (scl_negedge) begin
          sda_oe_nxt = 1'b0;  // Release SDA to receive ACK
        end else if (scl_posedge) begin
          if (sda_sync[1] == 1'b0) begin
            // ACK received, send next byte
            bit_count_nxt = 4'd7;
            reg_addr_nxt = reg_addr + 1;  // Auto-increment address
            shift_reg_nxt = i_reg_rdata;  // Load next data
            state_nxt = TX_DATA;
          end else begin
            // NACK received, transaction done
            state_nxt = IDLE;
          end
        end

        if (stop_condition) begin
          state_nxt = IDLE;
        end
      end

      default: begin
        state_nxt = IDLE;
      end
    endcase

    // Global stop condition handling
    if (stop_condition && state != IDLE) begin
      state_nxt = IDLE;
      reg_addr_nxt = 8'hFF;  // Reset address flag
    end
  end

  // Output assignments
  assign i2c_sda = sda_oe ? sda_out : 1'bz;

  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      o_reg_addr  <= 8'h00;
      o_reg_wdata <= 8'h00;
    end else begin
      o_reg_addr  <= reg_addr;
      o_reg_wdata <= reg_wdata;
    end
  end

endmodule
