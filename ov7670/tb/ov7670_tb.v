`timescale 1ns / 1ps

module ov7670_tb ();

  parameter DURATION = 100000000;
  parameter CLK_PERIOD = 20;  // 20ns = 50MHz

  reg        r_clk;
  wire [7:0] cam_data;
  wire       cam_pclk;
  wire       cam_hsync;
  wire       cam_vsync;
  wire       cam_rstn;
  wire       cam_pwdn;
  wire       cam_xclk;
  wire       cam_scl;
  wire       cam_sda;
  wire [7:0] dbg_led;


  reg  [3:0] bit_count;
  reg  [7:0] rx_byte;
  reg        active;

  reg        sda_q;
  reg        scl_q;
  reg        sda_drive;  // 1 = drive SDA low (ACK), 0 = release

  initial begin
    bit_count = 0;
    rx_byte = 0;
    active = 0;
  end

  ov7670 inst_ov7670 (
      .i_ov7670_clk  (r_clk),
      .i_ov7670_pclk (cam_pclk),
      .i_ov7670_hsync(cam_hsync),
      .i_ov7670_vsync(cam_vsync),
      .i_ov7670_data (cam_data),
      .o_ov7670_rstn (cam_rstn),
      .o_ov7670_pwdn (cam_pwdn),
      .o_ov7670_xclk (cam_xclk),
      .ov7670_scl    (cam_scl),
      .ov7670_sda    (cam_sda),
      .debug_led     (dbg_led)
  );

  initial begin
    sda_drive = 0;
    r_clk = 0;
    forever #(CLK_PERIOD / 2) r_clk = ~r_clk;
  end

  pullup (cam_sda);

  always @(posedge r_clk) begin
    sda_q <= cam_sda;
    scl_q <= cam_scl;
  end

  wire start_condition = (sda_q == 1'b1) && (cam_sda == 1'b0) && (cam_scl == 1'b1);
  wire stop_condition = (sda_q == 1'b0) && (cam_sda == 1'b1) && (cam_scl == 1'b1);

  always @(posedge r_clk) begin
    if (start_condition) begin
      active    <= 1'b1;
      bit_count <= 0;
      sda_drive <= 1'b0;
      $display("Time %0t : START detected", $time);
    end

    if (stop_condition) begin
      active    <= 1'b0;
      sda_drive <= 1'b0;
      $display("Time %0t : STOP detected", $time);
    end
  end

  always @(posedge cam_scl) begin
    if (active) begin
      if (bit_count < 8) begin
        rx_byte[7-bit_count] <= cam_sda;
      end

      bit_count <= bit_count + 1;

      if (bit_count == 8) begin
        //sda_drive <= 1'b1;  // drive ACK (pull low)
        $display("Time %0t : Received byte 0x%02h", $time, rx_byte);
      end
    end
  end

  // Drive ACK BEFORE 9th rising edge
  always @(negedge cam_scl) begin
    if (active && bit_count == 8) begin
      sda_drive <= 1'b1;  // pull SDA low for ACK
    end
  end

  always @(negedge cam_scl) begin
    if (active && bit_count == 9 && sda_drive == 1) begin
      sda_drive <= 1'b0;  // release line
      bit_count <= 0;
      $display("Time %0t : ACK sent", $time);
    end
  end


  assign cam_sda = (sda_drive) ? 1'b0 : 1'bz;

  initial begin
    $dumpfile("sim_output/ov7670_tb.vcd");
    $dumpvars(0, ov7670_tb);
  end

  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end
endmodule

