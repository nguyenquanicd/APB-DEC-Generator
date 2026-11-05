//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_apbdec_half
//Function: APB Decoder Testbench
//Author:  qtt\pc
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//Generated: 2026-11-05 23:43:45
//--------------------------------------

`timescale 1ns/1ps

// ============================================================================
// Self-checking testbench of m_apbdec_half
// Address width 12, data width 16, strobe 2, 3 slave(s), Address Rebase 1
// ============================================================================
module m_apbdec_half_tb;

  localparam int ADDR_WIDTH = 12;
  localparam int DATA_WIDTH = 16;
  localparam int STRB_WIDTH = 2;
  localparam int NUM_SLAVES = 3;

  logic i_clk;
  logic i_rst_n;
  logic i_unmapped_err_en;

  // Requester side (master BFM drives, decoder answers)
  logic [ADDR_WIDTH-1:0] m_paddr;
  logic [DATA_WIDTH-1:0] m_pwdata;
  logic [DATA_WIDTH-1:0] m_prdata;
  logic                  m_pwrite;
  logic                  m_psel;
  logic                  m_penable;
  logic                  m_pready;
  logic                  m_pslverr;
  logic [STRB_WIDTH-1:0] m_pstrb;
  logic [2:0]            m_pprot;

  // Slave side
  logic        o_psel_timer;
  logic        o_penable_timer;
  logic        o_pwrite_timer;
  logic [6:0] o_paddr_timer;
  logic [DATA_WIDTH-1:0] o_pwdata_timer;
  logic [STRB_WIDTH-1:0] o_pstrb_timer;
  logic [2:0]  o_pprot_timer;
  logic        i_pready_timer;
  logic        i_pslverr_timer;
  logic [DATA_WIDTH-1:0] i_prdata_timer;
  logic        o_psel_gpio;
  logic        o_penable_gpio;
  logic        o_pwrite_gpio;
  logic [7:0] o_paddr_gpio;
  logic [DATA_WIDTH-1:0] o_pwdata_gpio;
  logic [STRB_WIDTH-1:0] o_pstrb_gpio;
  logic [2:0]  o_pprot_gpio;
  logic        i_pready_gpio;
  logic        i_pslverr_gpio;
  logic [DATA_WIDTH-1:0] i_prdata_gpio;
  logic        o_psel_wdog;
  logic        o_penable_wdog;
  logic        o_pwrite_wdog;
  logic [3:0] o_paddr_wdog;
  logic [DATA_WIDTH-1:0] o_pwdata_wdog;
  logic [STRB_WIDTH-1:0] o_pstrb_wdog;
  logic [2:0]  o_pprot_wdog;
  logic        i_pready_wdog;
  logic        i_pslverr_wdog;
  logic [DATA_WIDTH-1:0] i_prdata_wdog;

  integer n_chk;
  integer n_fail;

  // ---------------------------------------------------------------- DUT
  m_apbdec_half u_m_apbdec_half (
    .i_paddr(m_paddr),
    .i_pprot(m_pprot),
    .i_psel(m_psel),
    .i_penable(m_penable),
    .i_pwrite(m_pwrite),
    .i_pwdata(m_pwdata),
    .i_pstrb(m_pstrb),
    .o_pready(m_pready),
    .o_prdata(m_prdata),
    .o_pslverr(m_pslverr),
    .i_unmapped_err_en(i_unmapped_err_en),
    .o_psel_timer(o_psel_timer),
    .o_penable_timer(o_penable_timer),
    .o_pwrite_timer(o_pwrite_timer),
    .o_paddr_timer(o_paddr_timer),
    .o_pwdata_timer(o_pwdata_timer),
    .o_pstrb_timer(o_pstrb_timer),
    .o_pprot_timer(o_pprot_timer),
    .i_pready_timer(i_pready_timer),
    .i_pslverr_timer(i_pslverr_timer),
    .i_prdata_timer(i_prdata_timer),
    .o_psel_gpio(o_psel_gpio),
    .o_penable_gpio(o_penable_gpio),
    .o_pwrite_gpio(o_pwrite_gpio),
    .o_paddr_gpio(o_paddr_gpio),
    .o_pwdata_gpio(o_pwdata_gpio),
    .o_pstrb_gpio(o_pstrb_gpio),
    .o_pprot_gpio(o_pprot_gpio),
    .i_pready_gpio(i_pready_gpio),
    .i_pslverr_gpio(i_pslverr_gpio),
    .i_prdata_gpio(i_prdata_gpio),
    .o_psel_wdog(o_psel_wdog),
    .o_penable_wdog(o_penable_wdog),
    .o_pwrite_wdog(o_pwrite_wdog),
    .o_paddr_wdog(o_paddr_wdog),
    .o_pwdata_wdog(o_pwdata_wdog),
    .o_pstrb_wdog(o_pstrb_wdog),
    .o_pprot_wdog(o_pprot_wdog),
    .i_pready_wdog(i_pready_wdog),
    .i_pslverr_wdog(i_pslverr_wdog),
    .i_prdata_wdog(i_prdata_wdog)
  );

  // ---------------------------------------------------------------- clock and reset
  initial begin
    i_clk = 1'b0;
    forever #5 i_clk = ~i_clk;
  end

  initial begin
    i_rst_n = 1'b0;
    #50;
    i_rst_n = 1'b1;
  end

  // ---------------------------------------------------------------- BFMs
  apb_master_bfm #(
    .PARA_ADDR_WIDTH(ADDR_WIDTH),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0)
  ) u_master_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_paddr(m_paddr),
    .o_pwdata(m_pwdata),
    .i_prdata(m_prdata),
    .o_pwrite(m_pwrite),
    .o_psel(m_psel),
    .o_penable(m_penable),
    .i_pready(m_pready),
    .i_pslverr(m_pslverr),
    .o_pstrb(m_pstrb),
    .o_pprot(m_pprot)
  );

  // Slave 0: TIMER
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(7),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0),
    .PARA_MEM_WORDS(16),
    .PARA_MEM_ALIAS(0)
  ) u_timer_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_timer),
    .i_pwdata(o_pwdata_timer),
    .o_prdata(i_prdata_timer),
    .i_pwrite(o_pwrite_timer),
    .i_psel(o_psel_timer),
    .i_penable(o_penable_timer),
    .o_pready(i_pready_timer),
    .o_pslverr(i_pslverr_timer),
    .i_pstrb(o_pstrb_timer),
    .i_pprot(o_pprot_timer)
  );

  // Slave 1: GPIO
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(1),
    .PARA_MEM_WORDS(64),
    .PARA_MEM_ALIAS(1)
  ) u_gpio_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_gpio),
    .i_pwdata(o_pwdata_gpio),
    .o_prdata(i_prdata_gpio),
    .i_pwrite(o_pwrite_gpio),
    .i_psel(o_psel_gpio),
    .i_penable(o_penable_gpio),
    .o_pready(i_pready_gpio),
    .o_pslverr(i_pslverr_gpio),
    .i_pstrb(o_pstrb_gpio),
    .i_pprot(o_pprot_gpio)
  );

  // Slave 2: WDOG
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(4),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(2),
    .PARA_MEM_WORDS(4),
    .PARA_MEM_ALIAS(1)
  ) u_wdog_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_wdog),
    .i_pwdata(o_pwdata_wdog),
    .o_prdata(i_prdata_wdog),
    .i_pwrite(o_pwrite_wdog),
    .i_psel(o_psel_wdog),
    .i_penable(o_penable_wdog),
    .o_pready(i_pready_wdog),
    .o_pslverr(i_pslverr_wdog),
    .i_pstrb(o_pstrb_wdog),
    .i_pprot(o_pprot_wdog)
  );

  // ---------------------------------------------------------------- waveform dump
  initial begin
`ifdef VCS
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, m_apbdec_half_tb, "+mda");
`else
    $dumpfile("wave.vcd");
    $dumpvars(0, m_apbdec_half_tb);
`endif
  end

  // ---------------------------------------------------------------- check helper
  task automatic chk(input bit cond, input string what);
    n_chk = n_chk + 1;
    if (!cond) begin
      n_fail = n_fail + 1;
      $display("[TB] FAIL @%0t: %s", $time, what);
    end
  endtask

  // ---------------------------------------------------------------- reference model
  // Owner of an address: slave index, or -1 when no window contains it.
  function automatic integer owner_of(input logic [ADDR_WIDTH-1:0] a);
    owner_of = -1;
    if (a >= 12'h10 && a <= 12'h5F) owner_of = 0;
    if (a >= 12'h100 && a <= 12'h1FF) owner_of = 1;
    if (a >= 12'h300 && a <= 12'h30B) owner_of = 2;
  endfunction

  // Expected local address of slave k for the requester address a.
  function automatic logic [31:0] exp_local(input integer k, input logic [ADDR_WIDTH-1:0] a);
    exp_local = 32'd0;
    case (k)
      0: exp_local = (32'(a) - 32'h10) & 32'h7F;
      1: exp_local = (32'(a) - 32'h100) & 32'hFF;
      2: exp_local = (32'(a) - 32'h300) & 32'hF;
      default: exp_local = 32'd0;
    endcase
  endfunction

  // Local address that slave k actually sees.
  function automatic logic [31:0] act_local(input integer k);
    act_local = 32'd0;
    case (k)
      0: act_local = 32'(o_paddr_timer);
      1: act_local = 32'(o_paddr_gpio);
      2: act_local = 32'(o_paddr_wdog);
      default: act_local = 32'd0;
    endcase
  endfunction

  function automatic logic sl_pready(input integer k);
    sl_pready = 1'b0;
    case (k)
      0: sl_pready = i_pready_timer;
      1: sl_pready = i_pready_gpio;
      2: sl_pready = i_pready_wdog;
      default: sl_pready = 1'b0;
    endcase
  endfunction

  function automatic logic sl_pslverr(input integer k);
    sl_pslverr = 1'b0;
    case (k)
      0: sl_pslverr = i_pslverr_timer;
      1: sl_pslverr = i_pslverr_gpio;
      2: sl_pslverr = i_pslverr_wdog;
      default: sl_pslverr = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] sl_prdata(input integer k);
    sl_prdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: sl_prdata = i_prdata_timer;
      1: sl_prdata = i_prdata_gpio;
      2: sl_prdata = i_prdata_wdog;
      default: sl_prdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  // Slave error that the slave BFM answers for the local address (slave 0 only, see slave_ram).
  function automatic logic exp_slverr(input integer k, input logic [31:0] local_addr);
    exp_slverr = 1'b0;
    case (k)
      0: exp_slverr = ((local_addr >> 2) >= 16);
      default: exp_slverr = 1'b0;
    endcase
  endfunction


  // ---------------------------------------------------------------- transaction scoreboard
  // One requester transfer must give exactly one slave access at the owner of the address (none
  // for a hole), with the attributes and the local address of the reference model, and the
  // response of the requester side must be the response of that slave (or of the hole).
  logic [NUM_SLAVES-1:0] w_psel_vec;
  logic [NUM_SLAVES-1:0] w_dn_done_vec;
  assign w_psel_vec = {o_psel_wdog, o_psel_gpio, o_psel_timer};
  assign w_dn_done_vec = {(o_psel_wdog & o_penable_wdog & i_pready_wdog), (o_psel_gpio & o_penable_gpio & i_pready_gpio), (o_psel_timer & o_penable_timer & i_pready_timer)};

  function automatic logic dn_pwrite(input integer k);
    dn_pwrite = 1'b0;
    case (k)
      0: dn_pwrite = o_pwrite_timer;
      1: dn_pwrite = o_pwrite_gpio;
      2: dn_pwrite = o_pwrite_wdog;
      default: dn_pwrite = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] dn_pwdata(input integer k);
    dn_pwdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: dn_pwdata = o_pwdata_timer;
      1: dn_pwdata = o_pwdata_gpio;
      2: dn_pwdata = o_pwdata_wdog;
      default: dn_pwdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [STRB_WIDTH-1:0] dn_pstrb(input integer k);
    dn_pstrb = {STRB_WIDTH{1'b0}};
    case (k)
      0: dn_pstrb = o_pstrb_timer;
      1: dn_pstrb = o_pstrb_gpio;
      2: dn_pstrb = o_pstrb_wdog;
      default: dn_pstrb = {STRB_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [2:0] dn_pprot(input integer k);
    dn_pprot = 3'd0;
    case (k)
      0: dn_pprot = o_pprot_timer;
      1: dn_pprot = o_pprot_gpio;
      2: dn_pprot = o_pprot_wdog;
      default: dn_pprot = 3'd0;
    endcase
  endfunction

  logic                  sb_open;
  integer                sb_owner;
  integer                sb_cnt;
  integer                sb_txn;
  integer                sb_age;
  integer                sb_k;
  logic [ADDR_WIDTH-1:0] sb_addr;
  logic                  sb_write;
  logic [DATA_WIDTH-1:0] sb_wdata;
  logic [STRB_WIDTH-1:0] sb_strb;
  logic [2:0]            sb_prot;
  logic [31:0]           sb_dn_local;
  logic                  sb_dn_write;
  logic [DATA_WIDTH-1:0] sb_dn_wdata;
  logic [STRB_WIDTH-1:0] sb_dn_strb;
  logic [2:0]            sb_dn_prot;
  logic [DATA_WIDTH-1:0] sb_dn_rdata;
  logic                  sb_dn_err;

  initial begin
    sb_open = 1'b0;
    sb_owner = -1;
    sb_cnt = 0;
    sb_txn = 0;
    sb_age = 0;
  end

  always @(posedge i_clk) begin
    if (i_rst_n === 1'b1) begin
      chk($onehot0(w_psel_vec), "at most one slave select");
      if (sb_open)
        sb_age = sb_age + 1;
      // the requester setup phase opens a transaction
      if (m_psel && !m_penable && !sb_open) begin
        sb_open  = 1'b1;
        sb_owner = owner_of(m_paddr);
        sb_addr  = m_paddr;
        sb_write = m_pwrite;
        sb_wdata = m_pwdata;
        sb_strb  = m_pstrb;
        sb_prot  = m_pprot;
        sb_cnt   = 0;
        sb_age   = 0;
      end
      if (!sb_open)
        chk(w_psel_vec === {NUM_SLAVES{1'b0}}, "no slave select without a requester transfer");
      // end of an access phase at a slave
      for (sb_k = 0; sb_k < NUM_SLAVES; sb_k = sb_k + 1) begin
        if (w_dn_done_vec[sb_k]) begin
          chk(sb_open && sb_k == sb_owner, "an access ends only at the owner of the address");
          if (sb_open && sb_k == sb_owner) begin
            sb_cnt      = sb_cnt + 1;
            sb_dn_local = act_local(sb_k);
            sb_dn_write = dn_pwrite(sb_k);
            sb_dn_wdata = dn_pwdata(sb_k);
            sb_dn_strb  = dn_pstrb(sb_k);
            sb_dn_prot  = dn_pprot(sb_k);
            sb_dn_rdata = sl_prdata(sb_k);
            sb_dn_err   = sl_pslverr(sb_k);
          end
        end
      end
      // end of the requester transfer
      if (sb_open && m_psel && m_penable && m_pready) begin
        chk(sb_cnt == ((sb_owner >= 0) ? 1 : 0), "one slave access for a mapped address, none for a hole");
        if (sb_owner >= 0 && sb_cnt == 1) begin
          chk(sb_dn_local === exp_local(sb_owner, sb_addr), "local address seen by the slave");
          chk(sb_dn_write === sb_write, "PWRITE seen by the slave");
          chk(sb_dn_strb === sb_strb, "PSTRB seen by the slave");
          chk(sb_dn_prot === sb_prot, "PPROT seen by the slave");
          if (sb_write)
            chk(sb_dn_wdata === sb_wdata, "PWDATA seen by the slave");
          else
            chk(m_prdata === sb_dn_rdata, "PRDATA returned to the requester");
          chk(m_pslverr === sb_dn_err, "PSLVERR returned to the requester");
        end else if (sb_owner < 0) begin
          if (!sb_write)
            chk(m_prdata === {DATA_WIDTH{1'b0}}, "hole: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "hole: PSLVERR follows the pin");
          chk(sb_age == 1, "hole: cycles from the setup to the end of the transfer");
        end
        sb_open = 1'b0;
        sb_txn  = sb_txn + 1;
      end
    end
  end

  // ---------------------------------------------------------------- monitor
  // Compares the decoder with the reference model in every cycle after reset.
  integer      mon_owner;
  logic [NUM_SLAVES-1:0] mon_exp_vec;

  always @(posedge i_clk) begin
    if (i_rst_n === 1'b1) begin
      mon_owner = owner_of(m_paddr);
      mon_exp_vec = {NUM_SLAVES{1'b0}};
      if (m_psel && mon_owner >= 0)
        mon_exp_vec[mon_owner] = 1'b1;
      chk(w_psel_vec === mon_exp_vec, "select vector (one-hot owner, none for a hole)");
      chk($onehot0(w_psel_vec), "at most one slave select");
      chk(o_penable_timer === (m_penable & o_psel_timer) && o_pwrite_timer === m_pwrite &&
          o_pwdata_timer === m_pwdata && o_pstrb_timer === m_pstrb &&
          o_pprot_timer === m_pprot, "forwarded attributes of timer");
      chk(o_penable_gpio === (m_penable & o_psel_gpio) && o_pwrite_gpio === m_pwrite &&
          o_pwdata_gpio === m_pwdata && o_pstrb_gpio === m_pstrb &&
          o_pprot_gpio === m_pprot, "forwarded attributes of gpio");
      chk(o_penable_wdog === (m_penable & o_psel_wdog) && o_pwrite_wdog === m_pwrite &&
          o_pwdata_wdog === m_pwdata && o_pstrb_wdog === m_pstrb &&
          o_pprot_wdog === m_pprot, "forwarded attributes of wdog");
      if (m_psel && mon_owner >= 0) begin
        chk(act_local(mon_owner) === exp_local(mon_owner, m_paddr), "local address of the owner");
      end
      if (!m_psel || !m_penable)
        chk(m_pslverr === 1'b0, "PSLVERR low when PSEL or PENABLE is low");
      if (m_psel && m_penable) begin
        if (mon_owner < 0) begin
          chk(m_pready === 1'b1, "unmapped address: PREADY high");
          chk(m_prdata === {DATA_WIDTH{1'b0}}, "unmapped address: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "unmapped address: PSLVERR follows the pin");
        end else begin
          chk(m_pready === sl_pready(mon_owner), "PREADY of the selected slave");
          chk(m_prdata === sl_prdata(mon_owner), "PRDATA of the selected slave");
          chk(m_pslverr === (m_pready & sl_pslverr(mon_owner)), "PSLVERR of the selected slave");
        end
      end
    end
  end

  // ---------------------------------------------------------------- protocol checkers
  integer w_chk_cnt_req;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(ADDR_WIDTH),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(0)
  ) u_chk_req (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(m_paddr), .i_pprot(m_pprot), .i_psel(m_psel),
    .i_penable(m_penable), .i_pwrite(m_pwrite), .i_pwdata(m_pwdata), .i_pstrb(m_pstrb),
    .i_pready(m_pready), .i_pslverr(m_pslverr), .o_err_cnt(w_chk_cnt_req)
  );

  integer w_chk_cnt_timer;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(7),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(1)
  ) u_chk_timer (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_timer), .i_pprot(o_pprot_timer),
    .i_psel(o_psel_timer), .i_penable(o_penable_timer), .i_pwrite(o_pwrite_timer),
    .i_pwdata(o_pwdata_timer), .i_pstrb(o_pstrb_timer), .i_pready(i_pready_timer),
    .i_pslverr(i_pslverr_timer), .o_err_cnt(w_chk_cnt_timer)
  );

  integer w_chk_cnt_gpio;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(2)
  ) u_chk_gpio (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_gpio), .i_pprot(o_pprot_gpio),
    .i_psel(o_psel_gpio), .i_penable(o_penable_gpio), .i_pwrite(o_pwrite_gpio),
    .i_pwdata(o_pwdata_gpio), .i_pstrb(o_pstrb_gpio), .i_pready(i_pready_gpio),
    .i_pslverr(i_pslverr_gpio), .o_err_cnt(w_chk_cnt_gpio)
  );

  integer w_chk_cnt_wdog;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(4),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(3)
  ) u_chk_wdog (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_wdog), .i_pprot(o_pprot_wdog),
    .i_psel(o_psel_wdog), .i_penable(o_penable_wdog), .i_pwrite(o_pwrite_wdog),
    .i_pwdata(o_pwdata_wdog), .i_pstrb(o_pstrb_wdog), .i_pready(i_pready_wdog),
    .i_pslverr(i_pslverr_wdog), .o_err_cnt(w_chk_cnt_wdog)
  );

  // ---------------------------------------------------------------- directed helpers
  function automatic logic [DATA_WIDTH-1:0] pat(input logic [31:0] seed);
    pat = DATA_WIDTH'(seed * 32'h9E3779B1 + 32'h1234567);
  endfunction

  // Let the bus return to idle before the pin changes (the pin is stable while PSEL is high).
  task automatic tick_idle;
    repeat (3) @(posedge i_clk);
  endtask

  task automatic set_pin(input logic v);
    tick_idle();
    i_unmapped_err_en = v;
    tick_idle();
  endtask

  logic [DATA_WIDTH-1:0] v_rdata;
  logic                  lane_e;

  // Read: the response must follow the model.
  task automatic rd_chk(input logic [ADDR_WIDTH-1:0] a);
    integer k;
    logic [31:0] la;
    k = owner_of(a);
    u_master_bfm.read(a, v_rdata);
    if (k < 0) begin
      chk(u_master_bfm.last_pslverr === i_unmapped_err_en, "read of a hole: PSLVERR is the pin");
      chk(v_rdata === {DATA_WIDTH{1'b0}}, "read of a hole: data zero");
    end else begin
      la = exp_local(k, a);
      chk(u_master_bfm.last_pslverr === exp_slverr(k, la), "read of a mapped address: PSLVERR");
      chk(act_local(k) === la, "local address after a read");
    end
  endtask

  // Write: the response must follow the model.
  task automatic wr_chk(input logic [ADDR_WIDTH-1:0] a, input logic [DATA_WIDTH-1:0] d);
    integer k;
    k = owner_of(a);
    u_master_bfm.write(a, d);
    if (k < 0)
      chk(u_master_bfm.last_pslverr === i_unmapped_err_en, "write to a hole: PSLVERR is the pin");
    else
      chk(u_master_bfm.last_pslverr === exp_slverr(k, exp_local(k, a)),
          "write to a mapped address: PSLVERR");
  endtask

  // Write then read back a mapped address.
  task automatic wr_rd_chk(input logic [ADDR_WIDTH-1:0] a, input logic [DATA_WIDTH-1:0] d);
    integer k;
    logic        e;
    k = owner_of(a);
    chk(k >= 0, "wr_rd_chk address belongs to a slave");
    e = exp_slverr(k, exp_local(k, a));
    wr_chk(a, d);
    u_master_bfm.read(a, v_rdata);
    chk(u_master_bfm.last_pslverr === e, "read back: PSLVERR");
    chk(v_rdata === (e ? {DATA_WIDTH{1'b0}} : d), "read back: data");
    chk(act_local(k) === exp_local(k, a), "local address after read back");
  endtask

  // Random traffic: window and random addresses, reads and writes, protection and strobe.
  task automatic random_traffic(input integer count);
    integer j, k;
    logic [ADDR_WIDTH-1:0] a;
    logic [31:0] r;
    for (j = 0; j < count; j = j + 1) begin
      r = $urandom;
      k = r % (NUM_SLAVES + 2);
      a = $urandom;
      case (k)
        0: a = 12'h10 + (12'($urandom) % 12'd80);
        1: a = 12'h100 + (12'($urandom) % 12'd256);
        2: a = 12'h300 + (12'($urandom) % 12'd12);
        default: a = $urandom;
      endcase
      if (j % 7 == 0)
        set_pin(~i_unmapped_err_en);
      u_master_bfm.write_strb(a, $urandom, $urandom, $urandom);
      chk(u_master_bfm.last_pslverr === (owner_of(a) < 0 ? i_unmapped_err_en :
          exp_slverr(owner_of(a), exp_local(owner_of(a), a))), "random write PSLVERR");
      u_master_bfm.read(a, v_rdata, $urandom);
      chk(u_master_bfm.last_pslverr === (owner_of(a) < 0 ? i_unmapped_err_en :
          exp_slverr(owner_of(a), exp_local(owner_of(a), a))), "random read PSLVERR");
    end
  endtask

  // ---------------------------------------------------------------- test sequence
  initial begin
    n_chk = 0;
    n_fail = 0;
    i_unmapped_err_en = 1'b1;
    v_rdata = {DATA_WIDTH{1'b0}};

    @(posedge i_rst_n);
    tick_idle();

    $display("");
    $display("========================================");
    $display("APB Decoder Testbench: m_apbdec_half");
    $display("========================================");

    // Mapped windows: edges, middle, neighbors, write and read back
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);

  // ---- Slave 0: TIMER 0x10 to 0x5F (80 B)
  wr_rd_chk(12'h10, pat(32'd1));
  wr_rd_chk(12'h5F, pat(32'd2));
  wr_rd_chk(12'h38, pat(32'd3));
  rd_chk(12'hF);
  rd_chk(12'h60);

  // ---- Slave 1: GPIO 0x100 to 0x1FF (256 B)
  wr_rd_chk(12'h100, pat(32'd11));
  wr_rd_chk(12'h1FF, pat(32'd12));
  wr_rd_chk(12'h180, pat(32'd13));
  rd_chk(12'hFF);
  rd_chk(12'h200);

  // ---- Slave 2: WDOG 0x300 to 0x30B (12 B)
  wr_rd_chk(12'h300, pat(32'd21));
  wr_rd_chk(12'h30B, pat(32'd22));
  wr_rd_chk(12'h306, pat(32'd23));
  rd_chk(12'h2FF);
  rd_chk(12'h30C);
    end

    // Unmapped holes with the pin at 1 (error) and at 0 (ready only)
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);
  rd_chk(12'h0);
  wr_chk(12'h0, pat(32'd0));
  rd_chk(12'hF);
  wr_chk(12'hF, pat(32'd15));
  rd_chk(12'h7);
  wr_chk(12'h7, pat(32'd7));
  rd_chk(12'h60);
  wr_chk(12'h60, pat(32'd96));
  rd_chk(12'hFF);
  wr_chk(12'hFF, pat(32'd255));
  rd_chk(12'hAF);
  wr_chk(12'hAF, pat(32'd175));
  rd_chk(12'h200);
  wr_chk(12'h200, pat(32'd512));
  rd_chk(12'h2FF);
  wr_chk(12'h2FF, pat(32'd767));
  rd_chk(12'h27F);
  wr_chk(12'h27F, pat(32'd639));
  rd_chk(12'h30C);
  wr_chk(12'h30C, pat(32'd780));
  rd_chk(12'hFFF);
  wr_chk(12'hFFF, pat(32'd4095));
  rd_chk(12'h985);
  wr_chk(12'h985, pat(32'd2437));
    end

  // ---- Byte lanes: only the enabled lane changes (slave 0)
  tick_idle();
  lane_e = exp_slverr(0, exp_local(0, 12'h10));
  u_master_bfm.write(12'h10, 16'd0);
  u_master_bfm.write_strb(12'h10, ~16'd0, 2'd1);
  u_master_bfm.read(12'h10, v_rdata);
  chk(u_master_bfm.last_pslverr === lane_e, "byte lane read PSLVERR");
  if (!lane_e)
    chk(v_rdata === 16'hFF, "only lane 0 written");

    // Random traffic with the pin changing between transfers
    random_traffic(300);

    tick_idle();
    chk((w_chk_cnt_req + w_chk_cnt_timer + w_chk_cnt_gpio + w_chk_cnt_wdog) == 0, "the APB protocol checkers report no violation");
    chk(sb_txn > 0, "the scoreboard saw transfers");
    $display("");
    $display("========================================");
    $display("[TB] Test Summary");
    $display("[TB] Transactions: %0d", sb_txn);
    $display("========================================");
    $display("[TB] Checks: %0d", n_chk);
    $display("[TB] Failed: %0d", n_fail);
    $display("========================================");
    if (n_fail > 0 || n_chk == 0) begin
      $display("[TB] OVERALL RESULT: FAIL");
      $fatal(1, "APB decoder testbench failed");
    end else begin
      $display("[TB] OVERALL RESULT: PASS");
      $finish;
    end
  end

  // Watchdog: the run must end by itself (the longest configuration needs about 0.1 ms)
  initial begin
    #5000000;
    $display("[TB] OVERALL RESULT: FAIL (timeout)");
    $fatal(1, "APB decoder testbench timeout");
  end

endmodule
