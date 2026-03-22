`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 8000000;
  parameter CLK_PERIOD = 20;  // 20ns = 50MHz

  wire        ov7670_rstn;
  wire        ov7670_pwdn;
  wire        ov7670_hsync;
  wire        ov7670_pclk;
  wire        ov7670_scl;
  wire        ov7670_sda;
  wire        ov7670_vsync;
  wire [ 7:0] ov7670_data;
  wire        pll_lock;
  wire [ 3:0] rstate;
  wire        xclk;
  wire        vga_hsync;
  wire        vga_vsync;
  wire [ 3:0] vga_red;
  wire [ 3:0] vga_green;
  wire [ 3:0] vga_blue;
  wire [ 7:0] dbg_led;

  wire        tb_sdram_clk;
  wire        tb_sdram_cke;
  wire [ 1:0] tb_sdram_dqm;
  wire        tb_sdram_casn;
  wire        tb_sdram_rasn;
  wire        tb_sdram_wen;
  wire        tb_sdram_csn;
  wire [ 1:0] tb_sdram_ba;
  wire [12:0] tb_sdram_addr;
  wire [15:0] tb_sdram_data;
  wire [ 7:0] tb_debug_led;
  reg         r_clk;
  wire        ov7670_init_done;

  initial begin
    r_clk = 0;
    forever #(CLK_PERIOD / 2) r_clk = ~r_clk;
  end

  top inst_top (
      .sys_clk_50mhz   (r_clk),
      .ov7670_pclk     (ov7670_pclk),
      .ov7670_hsync    (ov7670_hsync),
      .ov7670_vsync    (ov7670_vsync),
      .ov7670_data     (ov7670_data),
      .ov7670_rstn     (ov7670_rstn),
      .ov7670_pwdn     (ov7670_pwdn),
      .ov7670_xclk     (ov7670_xclk),
      .ov7670_scl      (ov7670_scl),
      .ov7670_sda      (ov7670_sda),
      .sdram_clk       (tb_sdram_clk),
      .sdram_cke       (tb_sdram_cke),
      .sdram_dqm       (tb_sdram_dqm),
      .sdram_casn      (tb_sdram_casn),
      .sdram_rasn      (tb_sdram_rasn),
      .sdram_wen       (tb_sdram_wen),
      .sdram_csn       (tb_sdram_csn),
      .sdram_ba        (tb_sdram_ba),
      .sdram_addr      (tb_sdram_addr),
      .sdram_data      (tb_sdram_data),
      .vga_hsync       (vga_hsync),
      .vga_vsync       (vga_vsync),
      .vga_red         (vga_red),
      .vga_blue        (vga_blue),
      .vga_green       (vga_green),
      .debug_led       (dbg_led),
      .ov7670_init_done(ov7670_init_done)
  );


  wire dbg_scl;
  wire dbg_sda;
  // Instantiate VCD stimulus generator
  ov7670_vcd inst (
      .clk             (rclk),
      .ov7670_init_done(ov7670_init_done),
      .dbg_hsync       (ov7670_hsync),
      .dbg_pclk        (ov7670_pclk),
      .dbg_vsync       (ov7670_vsync),
      .p_0_in          (ov7670_data)
  );



  mt48lc16m16a2 sim_model (
      .Dq   (tb_sdram_data),
      .Addr (tb_sdram_addr),
      .Ba   (tb_sdram_ba),
      .Clk  (tb_sdram_clk),
      .Cke  (tb_sdram_cke),
      .Cs_n (tb_sdram_csn),
      .Ras_n(tb_sdram_rasn),
      .Cas_n(tb_sdram_casn),
      .We_n (tb_sdram_wen),
      .Dqm  (tb_sdram_dqm)
  );




  reg [3:0] bit_count;
  reg [7:0] rx_byte;
  reg       active;

  reg       sda_q;
  reg       scl_q;
  reg       sda_drive;  // 1 = drive SDA low (ACK), 0 = release

  initial begin
    bit_count = 0;
    rx_byte = 0;
    active = 0;
    sda_drive = 0;
    sda_q = 0;
    scl_q = 0;
  end

  always @(posedge r_clk) begin
    sda_q <= ov7670_sda;
    scl_q <= ov7670_scl;
  end

  wire start_condition = (sda_q == 1'b1) && (ov7670_sda == 1'b0) && (ov7670_scl == 1'b1);
  wire stop_condition = (sda_q == 1'b0) && (ov7670_sda == 1'b1) && (ov7670_scl == 1'b1);

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

  always @(posedge ov7670_scl) begin
    if (active) begin
      if (bit_count < 8) begin
        rx_byte[7-bit_count] <= ov7670_sda;
      end

      bit_count <= bit_count + 1;

      if (bit_count == 8) begin
        //sda_drive <= 1'b1;  // drive ACK (pull low)
        $display("Time %0t : Received byte 0x%02h", $time, rx_byte);
      end
    end
  end

  // Drive ACK BEFORE 9th rising edge
  always @(negedge ov7670_scl) begin
    if (active && bit_count == 8) begin
      sda_drive <= 1'b1;  // pull SDA low for ACK
    end
  end

  always @(negedge ov7670_scl) begin
    if (active && bit_count == 9 && sda_drive == 1) begin
      sda_drive <= 1'b0;  // release line
      bit_count <= 0;
      $display("Time %0t : ACK sent", $time);
    end
  end


  assign ov7670_sda = (sda_drive) ? 1'b0 : 1'bz;
  pullup (ov7670_sda);

  initial begin
    $dumpfile("sim_output/top_tb.vcd");
    $dumpvars(0, top_tb);
  end
  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end

endmodule



