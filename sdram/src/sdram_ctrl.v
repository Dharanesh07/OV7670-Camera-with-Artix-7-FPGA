`timescale 1ns / 1ps
/*
P/N: W9825G6KH

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
    parameter CAS                = 3'd2
) (
    input             i_clk,
    input             i_rstn,
    input      [14:0] i_addr,      //Input address
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
    inout      [15:0] sdram_data
);


  localparam REFRESH_COUNT_VAL = 1037;  // 7.8uS refresh cycle
  // For 50MHz clk freq
  // one clk period = 1/50MHz
  // 1 uS = 1/(1/50) = 50 clks  
  localparam ONE_MICROSECOND = SDRAM_CLK_FREQ_MHZ;
  localparam WAIT_100US = 100 * ONE_MICROSECOND;
  // command period; PRE to ACT in ns, e.g. 20ns
  localparam TRP = ((TRP_NS * ONE_MICROSECOND / 1000) + 1);
  // tRC command period (REF to REF/ACT TO ACT) in ns
  localparam TRC = ((TRC_NS * ONE_MICROSECOND / 1000) + 1);  //
  // tRCD active command to read/write command delay; row-col-delay in ns
  localparam TRCD = ((TRCD_NS * ONE_MICROSECOND / 1000) + 1);
  // tCH command hold time
  localparam TCH = ((TCH_NS * ONE_MICROSECOND / 1000) + 1);

  localparam BURST_LENGTH = 3'b111;  // 000=1, 001=2, 010=4, 011=8
  localparam ADDRESS_MODE = 1'b0;  // 0=sequential, 1=interleaved
  localparam CAS_LATENCY = CAS;  // 2/3 allowed, tRCD=20ns -> 3 cycles@128MHz
  localparam OP_MODE = 2'b00;  // only 00 (standard operation) allowed
  localparam NO_WRITE_BURST = 1'b0;  // 0= write burst enabled, 1=only single access write
  localparam SDRAM_MODE = {1'b0, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ADDRESS_MODE, BURST_LENGTH};


  //W9825G6KH Datasheet, refer page 12
  // (CS, RAS, CAS, WE) Active low signals
  localparam CMD_MRS = 4'b0000;  // mode register set
  localparam CMD_BANK_ACTIVATE = 4'b0011;  // bank active
  localparam CMD_READ = 4'b0101;  // to have read variant with autoprecharge set A10=H
  localparam CMD_WRITE = 4'b0100;  // A10=H to have autoprecharge
  localparam CMD_BURST_STOP = 4'b0110;  // burst stop
  localparam CMD_PRECHARGE = 4'b0010;  // precharge selected bank, A10=H both banks
  localparam CMD_SELF_REFRESH_ENTRY = 4'b0001;  // auto refresh (cke=H), selfrefresh assign cke=L
  localparam CMD_NOP = 4'b0111;  // no operation
  localparam CMD_SELF_REFRESH_EXIT = 4'b1xxx;

  reg        clk_en;
  reg        clk_en_nxt;
  reg        en;
  reg        en_nxt;
  reg        rw_nxt;
  reg        rw;
  reg [ 3:0] cmd;
  reg [ 3:0] cmd_nxt;
  reg        dqm;
  reg        dqm_nxt;
  reg [ 1:0] bank_addr;
  reg [ 1:0] bank_addr_nxt;
  reg [15:0] data;
  reg [15:0] data_nxt;
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
  localparam WAIT_STATE_WIDTH = $clog2(WAIT_100US);

  reg  [     STATE_WIDTH -1:0] state;
  reg  [     STATE_WIDTH -1:0] state_nxt;
  reg  [     STATE_WIDTH -1:0] ret_state;
  reg  [     STATE_WIDTH -1:0] ret_state_nxt;
  reg  [WAIT_STATE_WIDTH -1:0] wait_states;
  reg  [WAIT_STATE_WIDTH -1:0] wait_states_nxt;

  wire [                 11:0] select_col;
  wire [                 11:0] select_row;
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
    end else begin
      data          <= data_nxt;
      o_dataout     <= o_dataout_nxt;
      state         <= state_nxt;
      o_dataval     <= o_dataval_nxt;
      o_ready       <= o_ready_nxt;
      clk_en        <= clk_en_nxt;
      dqm           <= dqm_nxt;
      cmd           <= cmd_nxt;
      wait_states   <= wait_states_nxt;
      ret_state     <= ret_state_nxt;
      bank_addr     <= bank_addr_nxt;
      addr          <= addr_nxt;
      tristate_en   <= tristate_en_nxt;
      refresh_flag  <= refresh_flag_nxt;
      refresh_count <= refresh_count_nxt;
      burst_index   <= burst_index_nxt;
      rw            <= rw_nxt;
      en            <= en_nxt;
      is_writing    <= is_writing_nxt;
    end
  end


  always @(*) begin
    wait_states_nxt   = wait_states;
    state_nxt         = state;
    cmd_nxt           = CMD_NOP;
    o_dataval_nxt     = o_dataval;
    o_ready_nxt       = o_ready;
    clk_en_nxt        = clk_en;
    dqm_nxt           = dqm;
    cmd_nxt           = cmd;
    ret_state_nxt     = ret_state;
    bank_addr_nxt     = bank_addr;
    addr_nxt          = addr;
    dqm_nxt           = dqm;
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


    refresh_count_nxt = refresh_count + 1;
    if (refresh_count == REFRESH_COUNT_VAL) begin
      refresh_count_nxt = 0;
      refresh_flag = 1'b1;
    end

    case (state)
      START: begin
        //$display("t=%0t: START", $time);
        clk_en_nxt      = 1'b0;
        wait_states_nxt = WAIT_100US;
        ret_state_nxt   = INIT_PRECHARGE;
        state_nxt       = WAIT_STATE;
      end

      ASSERT_CKE: begin
        clk_en_nxt      = 1'b1;
        wait_states_nxt = 2;
        ret_state_nxt   = INIT_AUTO_REFRESH0;
        state_nxt       = WAIT_STATE;
      end

      INIT_PRECHARGE: begin
        clk_en_nxt      = 1'b1;
        cmd_nxt         = CMD_PRECHARGE;
        addr_nxt[10]    = 1'b1;
        wait_states_nxt = TRP;
        ret_state_nxt   = INIT_AUTO_REFRESH0;
        state_nxt       = WAIT_STATE;
        //$display("t=%0t: INIT_PRECHARGE, addr[10]=%b", $time, addr_nxt[10]);
      end

      INIT_AUTO_REFRESH0: begin
        clk_en_nxt      = 1'b1;
        cmd_nxt         = CMD_SELF_REFRESH_ENTRY;
        wait_states_nxt = TRC;
        ret_state_nxt   = INIT_AUTO_REFRESH1;
        state_nxt       = WAIT_STATE;
        //$display("t=%0t: INIT_AUTO_REFRESH0", $time);
      end

      INIT_AUTO_REFRESH1: begin
        clk_en_nxt      = 1'b1;
        cmd_nxt         = CMD_SELF_REFRESH_ENTRY;
        wait_states_nxt = TRC;
        ret_state_nxt   = INIT_LOAD_MODE;
        state_nxt       = WAIT_STATE;
        //$display("t=%0t: INIT_AUTO_REFRESH1", $time);
      end

      INIT_LOAD_MODE: begin
        cmd_nxt         = CMD_MRS;
        addr_nxt        = SDRAM_MODE;
        wait_states_nxt = TCH;
        ret_state_nxt   = IDLE;
        state_nxt       = WAIT_STATE;
        //$display("t=%0t: INIT_LOAD_MODE, mode=%b", $time, addr_nxt);
      end

      IDLE: begin
        //$display("t=%0t: Reached IDLE - init complete!", $time);
        tristate_en_nxt = 1'b0;
        dqm_nxt         = 2'b00;
        o_dataval_nxt   = 1'b0;
        o_ready_nxt     = 1'b1;
        if (en) begin
          cmd_nxt         = CMD_BANK_ACTIVATE;
          burst_index_nxt = 0;
          bank_addr_nxt   = select_bank;
          addr_nxt        = select_row;
          wait_states_nxt = TRCD;
          ret_state_nxt   = rw ? READ : WRITE;
          state_nxt       = WAIT_STATE;
          en_nxt          = 1'b0;
        end  // refresh every 7.7uS and refresh before burst read or write
        else if (refresh_flag || i_sdram_en) begin  // entry point
          wait_states_nxt  = TRCD;
          cmd_nxt          = CMD_PRECHARGE;
          addr_nxt[10]     = 1'b1;
          refresh_flag_nxt = 0;
          if (i_sdram_en) begin  // sample all the reqd data
            en_nxt   = i_sdram_en;
            addr_nxt = i_addr;
            rw_nxt   = i_rw;
          end
          state_nxt     = WAIT_STATE;
          ret_state_nxt = REFRESH;
        end
      end

      REFRESH: begin
        cmd_nxt         = CMD_SELF_REFRESH_ENTRY;
        wait_states_nxt = TRC;
        state_nxt       = WAIT_STATE;
        ret_state_nxt   = IDLE;
      end

      READ: begin
        cmd_nxt         = CMD_READ;
        addr_nxt        = 0;
        wait_states_nxt = CAS_LATENCY;
        addr_nxt[10]    = 1'b0;
        bank_addr_nxt   = select_bank;
        ret_state_nxt   = READ_BURST_DATA;
        state_nxt       = WAIT_STATE;
      end

      READ_BURST_DATA: begin
        o_dataout_nxt   = sdram_data;
        o_dataval_nxt   = 1'b1;
        burst_index_nxt = burst_index + 1;
        if (burst_index == 512) begin
          o_dataval_nxt   = 1'b0;
          cmd_nxt         = CMD_PRECHARGE;
          wait_states_nxt = TRP;
          ret_state_nxt   = IDLE;
          state_nxt       = WAIT_STATE;
        end
      end

      WRITE: begin
        data_nxt        = i_datain;
        cmd_nxt         = CMD_WRITE;
        addr_nxt        = 0;
        bank_addr_nxt   = select_bank;
        addr_nxt[10]    = 1'b0;
        tristate_en_nxt = 1'b1;
        is_writing_nxt  = 1'b1;
        burst_index_nxt = burst_index + 1;
        state_nxt       = WRITE_BURST_DATA;
      end

      WRITE_BURST_DATA: begin
        data_nxt        = i_datain;
        tristate_en_nxt = 1'b1;
        is_writing_nxt  = 1'b1;
        burst_index_nxt = burst_index + 1;
        if (burst_index == 512) begin
          tristate_en_nxt = 1'b0;
          is_writing_nxt  = 1'b0;
          cmd_nxt         = CMD_PRECHARGE;
          wait_states_nxt = TRP + TCH;
          ret_state_nxt   = IDLE;
          state_nxt       = WAIT_STATE;
        end
      end

      WAIT_STATE: begin
        cmd_nxt         = CMD_NOP;
        wait_states_nxt = wait_states - 1;
        if (wait_states == 1) begin
          state_nxt = ret_state;
          if (ret_state == WRITE) tristate_en_nxt = 1;
        end
      end
      default: begin
        state_nxt = START;
      end
    endcase

  end


  //assign select_col  = {4'b0100, addr[8:2], 1'b0};
  assign select_row  = addr[12:2];
  assign select_bank = addr[1:0];

  assign sdram_clk   = i_clk;
  assign sdram_cke   = clk_en;
  assign sdram_addr  = addr;
  assign sdram_dqm   = dqm;
  assign sdram_ba    = bank_addr;
  assign sdram_data  = tristate_en ? data : 16'hz;

  assign {sdram_csn, sdram_rasn, sdram_casn, sdram_wen} = cmd;

endmodule
