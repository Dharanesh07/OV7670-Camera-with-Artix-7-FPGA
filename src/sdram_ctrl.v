`timescale 1ns / 1ps
/*
P/N: W9825G6KH
// QMTECH Wukong On-Board 32MB Winbond SDRAM, W9825G6KH-6


4M words × 4 banks × 16 bits
= 16M words × 16 bits
= 256 Mbits
= 32 MB
*/

//TRP_NS - Minimum Precharge to Active Command Period
//TRC_NS - Minimum Active Command Period
//TRCD_NS - Minimum Active to Read/Write Command Delay
//TCH_NS - Clock high level width

// Row address: 14:2
// Bank address: 1:0
// Column address: Not required since we are accessing the entire page of 512
// words


module sdram_ctrl #(
    parameter SDRAM_CLK_FREQ_MHZ = 64,
    parameter TRP_NS             = 20,
    parameter TRC_NS             = 66,
    parameter TRCD_NS            = 20,
    parameter TCH_NS             = 2,
    parameter CAS                = 3'd3
) (
    input             i_clk,
    input             i_rstn,
    input      [14:0] i_addr,      //Input address, row -> 14:2, bank -> 1:0
    input      [15:0] i_datain,    //SDRAM input data to write
    input             i_rw,        //Read -1, Write-0
    input             i_sdram_en,  //Enabled for SDRAM read or write operation
    output reg [15:0] o_dataout,   //Output from SDRAM
    output reg        o_dataval,   //Indicates valid data
    output reg        is_writing,  // Indicates write operation
    output reg        o_ready,     //Indicates SDRAM has completed initialization
    output            sdram_clk,
    output            sdram_cke,
    output     [ 1:0] sdram_dqm,
    output     [12:0] sdram_addr,  //row/col address
    output     [ 1:0] sdram_ba,    //bank address
    output            sdram_csn,   //command
    output            sdram_wen,   //command
    output            sdram_rasn,  //command
    output            sdram_casn,  //command
    inout      [15:0] sdram_data,
    output     [15:0] rd_data,
    output     [15:0] wr_data
);


  localparam REFRESH_COUNT_VAL = 1037;  // 7.8uS refresh cycle
  // For 50MHz clk freq
  // one clk period = 1/50MHz
  // 1 uS = 1/(1/50) = 50 clks  
  localparam ONE_MICROSECOND = SDRAM_CLK_FREQ_MHZ;
  localparam WAIT_200US = 200 * ONE_MICROSECOND;
  // command period; PRE to ACT in ns, e.g. 20ns
  localparam TRP = (((TRP_NS * ONE_MICROSECOND) / 1000) + 1);
  // tRC command period (REF to REF/ACT TO ACT) in ns
  localparam TRC = (((TRC_NS * ONE_MICROSECOND) / 1000) + 1);  //
  // tRCD active command to read/write command delay; row-col-delay in ns
  localparam TRCD = (((TRCD_NS * ONE_MICROSECOND) / 1000) + 1);
  // tCH command hold time
  localparam TCH = (((TCH_NS * ONE_MICROSECOND) / 1000) + 1);

  localparam TWR = 2;  // Write recovery time 2 clocks
  localparam TMRD = 2;  // two clocks wait for mode register

  initial begin
    $display("TRP = %f", TRP);
    $display("TRC = %f", TRC);
    $display("TRCD = %f", TRCD);
    $display("TCH = %f", TCH);
  end

  localparam BURST_LENGTH = 3'b111;  // 000=1, 001=2, 010=4, 011=8, 111 = full page mode
  localparam ADDRESS_MODE = 1'b0;  // 0=sequential, 1=interleaved
  localparam CAS_LATENCY = CAS;  // 2/3 allowed, tRCD=20ns -> 3 cycles@128MHz
  localparam RES_BIT = 2'b00;  // only 00 (standard operation) allowed
  localparam WRITE_MODE = 1'b0;  // 0= write burst enabled, 1=only single access write
  localparam SDRAM_MODE = {3'b000, WRITE_MODE, RES_BIT, CAS_LATENCY, ADDRESS_MODE, BURST_LENGTH};


  //W9825G6KH Datasheet, refer page 12
  // (CSn, RASn, CASn, WEn) Active low signals
  localparam CMD_MRS = 4'b0000;  // mode register set
  localparam CMD_BANK_ACTIVATE = 4'b0011;  // bank active
  localparam CMD_READ = 4'b0101;  // to have read variant with autoprecharge set A10=H
  localparam CMD_BURST_WRITE = 4'b0100;  // A10=H to have autoprecharge
  localparam CMD_BURST_STOP = 4'b0110;  // burst stop
  localparam CMD_PRECHARGE = 4'b0010;  // precharge selected bank, A10=H both banks
  localparam CMD_REFRESH = 4'b0001;  // auto refresh (cke=H), selfrefresh assign cke=L
  localparam CMD_NOP = 4'b1111;  // no operation

  reg        clk_en;
  reg        clk_en_nxt;
  reg        en;
  reg        en_nxt;
  reg        rw_nxt;
  reg        rw;
  reg        en_req;
  reg        en_req_nxt;
  reg [ 3:0] cmd;
  reg [ 3:0] cmd_nxt;
  reg [ 1:0] dqm;
  reg [ 1:0] dqm_nxt;
  reg [ 1:0] bank_addr;
  reg [ 1:0] bank_addr_nxt;
  reg [15:0] data;
  reg [15:0] data_nxt;
  reg [14:0] input_addr;
  reg [14:0] input_addr_nxt;
  reg [12:0] addr;
  reg [12:0] addr_nxt;
  reg        tristate_en;
  reg        tristate_en_nxt;
  reg        o_ready_nxt;
  reg [15:0] o_dataout_nxt;
  reg        o_dataval_nxt;
  reg [10:0] refresh_count;
  reg [10:0] refresh_count_nxt;
  reg        refresh_flag;
  reg        refresh_flag_nxt;
  reg [ 9:0] burst_index;
  reg [ 9:0] burst_index_nxt;
  reg        is_writing_nxt;
  assign rd_data = o_dataout_nxt;
  assign wr_data = data;

  //States
  localparam START = 0;
  localparam ASSERT_CKE = 1;
  localparam INIT_PRECHARGE = 2;
  localparam INIT_AUTO_REFRESH0 = 3;
  localparam INIT_AUTO_REFRESH1 = 4;
  localparam INIT_LOAD_MODE = 5;
  localparam IDLE = 6;
  localparam REFRESH = 7;
  localparam READ = 8;
  localparam READ_BURST_DATA = 9;
  localparam WRITE = 10;
  localparam WRITE_BURST_DATA = 11;
  localparam WAIT_STATE = 12;
  localparam LAST_STATE = 13;

  localparam STATE_WIDTH = $clog2(LAST_STATE);
  localparam WAIT_STATE_WIDTH = $clog2(WAIT_200US);

  reg  [     STATE_WIDTH -1:0] state;
  reg  [     STATE_WIDTH -1:0] state_nxt;
  reg  [     STATE_WIDTH -1:0] ret_state;
  reg  [     STATE_WIDTH -1:0] ret_state_nxt;
  reg  [WAIT_STATE_WIDTH -1:0] wait_states;
  reg  [WAIT_STATE_WIDTH -1:0] wait_states_nxt;

  wire [                 12:0] select_row;
  wire [                  1:0] select_bank;


  always @(posedge i_clk) begin
    if (~i_rstn) begin
      state         <= START;
      ret_state     <= START;
      cmd           <= CMD_NOP;
      wait_states   <= 0;
      o_dataval     <= 1'b0;
      o_ready       <= 1'b0;
      o_dataout     <= 0;
      tristate_en   <= 1'b0;
      data          <= 0;
      dqm           <= 2'b00;
      bank_addr     <= 2'b00;
      addr          <= 0;
      refresh_flag  <= 1'b0;
      refresh_count <= 0;
      burst_index   <= 0;
      en            <= 1'b0;
      rw            <= 1'b0;
      is_writing    <= 1'b0;
      input_addr    <= 0;
      clk_en        <= 1'b1;
      en_req        <= 1'b0;
    end else begin
      state         <= state_nxt;
      ret_state     <= ret_state_nxt;
      cmd           <= cmd_nxt;
      wait_states   <= wait_states_nxt;
      data          <= data_nxt;
      refresh_count <= refresh_count_nxt;
      o_dataout     <= o_dataout_nxt;
      o_dataval     <= o_dataval_nxt;
      o_ready       <= o_ready_nxt;
      clk_en        <= clk_en_nxt;
      dqm           <= dqm_nxt;
      bank_addr     <= bank_addr_nxt;
      addr          <= addr_nxt;
      tristate_en   <= tristate_en_nxt;
      refresh_flag  <= refresh_flag_nxt;
      burst_index   <= burst_index_nxt;
      rw            <= rw_nxt;
      en            <= en_nxt;
      is_writing    <= is_writing_nxt;
      input_addr    <= input_addr_nxt;
      en_req        <= en_req_nxt;
    end
  end


  always @(*) begin
    wait_states_nxt   = wait_states;
    state_nxt         = state;
    o_dataval_nxt     = o_dataval;
    o_ready_nxt       = o_ready;
    clk_en_nxt        = clk_en;
    dqm_nxt           = dqm;
    cmd_nxt           = cmd;
    ret_state_nxt     = ret_state;
    bank_addr_nxt     = bank_addr;
    addr_nxt          = addr;
    cmd_nxt           = cmd;
    tristate_en_nxt   = tristate_en;
    data_nxt          = data;
    o_dataout_nxt     = o_dataout;
    refresh_flag_nxt  = refresh_flag;
    refresh_count_nxt = refresh_count;
    burst_index_nxt   = burst_index;
    rw_nxt            = rw;
    en_nxt            = en;
    is_writing_nxt    = is_writing;
    input_addr_nxt    = input_addr;
    tristate_en_nxt   = 1'b0;
    dqm_nxt           = 2'b00;
    o_dataval_nxt     = 1'b0;
    en_req_nxt        = en_req;



    // refresh every 7.8uS
    refresh_count_nxt = refresh_count + 1;
    if (refresh_count == REFRESH_COUNT_VAL) begin
      refresh_count_nxt = 0;
      refresh_flag_nxt  = 1'b1;
    end

    // sdram_en capture latch
    if (i_sdram_en && !en_req && !en) begin
      en_req_nxt     = 1'b1;
      input_addr_nxt = i_addr;
      rw_nxt         = i_rw;
    end

    case (state)
      START: begin  //0
        clk_en_nxt      = 1'b1;
        wait_states_nxt = WAIT_200US;
        ret_state_nxt   = INIT_PRECHARGE;
        state_nxt       = WAIT_STATE;
        addr_nxt        = 0;
        bank_addr_nxt   = 0;

      end
      /*
      ASSERT_CKE: begin  // 1
        clk_en_nxt      = 1'b1;
        wait_states_nxt = 2;
        ret_state_nxt   = INIT_AUTO_REFRESH0;
        state_nxt       = WAIT_STATE;
      end
*/
      INIT_PRECHARGE: begin  // 2
        clk_en_nxt      = 1'b1;
        cmd_nxt         = CMD_PRECHARGE;
        addr_nxt[10]    = 1'b1;
        wait_states_nxt = TRP;
        ret_state_nxt   = INIT_AUTO_REFRESH0;
        state_nxt       = WAIT_STATE;
      end

      INIT_AUTO_REFRESH0: begin  // 3
        cmd_nxt         = CMD_REFRESH;
        wait_states_nxt = TRC;
        ret_state_nxt   = INIT_AUTO_REFRESH1;
        state_nxt       = WAIT_STATE;
      end

      INIT_AUTO_REFRESH1: begin  // 4
        cmd_nxt         = CMD_REFRESH;
        wait_states_nxt = TRC;
        ret_state_nxt   = INIT_LOAD_MODE;
        state_nxt       = WAIT_STATE;
      end

      INIT_LOAD_MODE: begin  // 5
        cmd_nxt         = CMD_MRS;
        addr_nxt        = SDRAM_MODE;
        wait_states_nxt = TMRD;
        bank_addr_nxt   = 2'b00;
        ret_state_nxt   = IDLE;
        state_nxt       = WAIT_STATE;
      end

      IDLE: begin  // 6
        o_ready_nxt = 1'b1;
        if (en) begin
          cmd_nxt         = CMD_BANK_ACTIVATE;
          burst_index_nxt = 0;
          bank_addr_nxt   = select_bank;
          addr_nxt        = select_row;
          wait_states_nxt = TRCD;
          ret_state_nxt   = rw ? READ : WRITE;
          state_nxt       = WAIT_STATE;
          en_nxt          = 1'b0;
        end  // refresh before burst read or write
        else if (refresh_flag || en_req) begin  // entry point
          if (en_req) begin
            en_nxt = 1'b1;
            en_req_nxt = 1'b0;
          end
          wait_states_nxt  = TRP;
          cmd_nxt          = CMD_PRECHARGE;
          addr_nxt[10]     = 1'b1;
          refresh_flag_nxt = 0;
          state_nxt        = WAIT_STATE;
          ret_state_nxt    = REFRESH;
        end
      end

      REFRESH: begin  // 7
        cmd_nxt         = CMD_REFRESH;
        wait_states_nxt = TRC;
        state_nxt       = WAIT_STATE;
        ret_state_nxt   = IDLE;
      end

      READ: begin  // 8
        cmd_nxt         = CMD_READ;
        addr_nxt        = 0;
        wait_states_nxt = CAS_LATENCY;
        addr_nxt[10]    = 1'b0;
        bank_addr_nxt   = select_bank;
        ret_state_nxt   = READ_BURST_DATA;
        state_nxt       = WAIT_STATE;
      end

      READ_BURST_DATA: begin  // 9
        o_dataout_nxt   = sdram_data;
        o_dataval_nxt   = 1'b1;
        burst_index_nxt = burst_index + 1;  // burst_index 1 to 512
        if (burst_index == 512) begin
          o_dataval_nxt   = 1'b0;
          cmd_nxt         = CMD_PRECHARGE;
          wait_states_nxt = TRP;
          ret_state_nxt   = IDLE;
          state_nxt       = WAIT_STATE;
        end
      end

      WRITE: begin  // 10
        data_nxt        = i_datain;
        tristate_en_nxt = 1'b1;
        cmd_nxt         = CMD_BURST_WRITE;
        addr_nxt        = 0;
        bank_addr_nxt   = select_bank;
        addr_nxt[10]    = 1'b0;
        is_writing_nxt  = 1'b1;
        burst_index_nxt = burst_index + 1;
        state_nxt       = WRITE_BURST_DATA;
      end

      WRITE_BURST_DATA: begin  // 11
        cmd_nxt         = CMD_NOP;  // To prevent from restarting burst transaction
        data_nxt        = i_datain;
        tristate_en_nxt = 1'b1;
        is_writing_nxt  = 1'b1;
        burst_index_nxt = burst_index + 1;  // burst_index 1 to 512
        if (burst_index == 512) begin
          tristate_en_nxt = 1'b0;
          is_writing_nxt  = 1'b0;
          cmd_nxt         = CMD_PRECHARGE;
          wait_states_nxt = TWR + TRP + 1;
          ret_state_nxt   = IDLE;
          state_nxt       = WAIT_STATE;
        end
      end

      WAIT_STATE: begin  // 12
        cmd_nxt         = CMD_NOP;
        wait_states_nxt = wait_states - 1;
        if (wait_states == 1) state_nxt = ret_state;
      end


      default: begin
        state_nxt = START;
      end
    endcase

  end


  //assign select_col  = {4'b0100, addr[8:2], 1'b0};
  //14:2=row(13)  , 1:0=bank(2) , no column address 
  //full page mode will always start from zero and end with 512 words
  assign select_row  = input_addr[14:2];
  assign select_bank = input_addr[1:0];

  assign sdram_clk   = i_clk;
  assign sdram_cke   = clk_en; // not used, always high
  assign sdram_addr  = addr;
  assign sdram_dqm   = dqm;
  assign sdram_ba    = bank_addr;
  assign sdram_data  = tristate_en ? data : 16'hz;

  assign {sdram_csn, sdram_rasn, sdram_casn, sdram_wen} = cmd;



endmodule
