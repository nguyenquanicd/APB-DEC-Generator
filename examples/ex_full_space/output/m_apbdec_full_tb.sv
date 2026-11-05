//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_apbdec_full
//Function: APB Decoder Testbench
//Author:  qtt\pc
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//Generated: 2026-11-05 23:43:45
//--------------------------------------

`timescale 1ns/1ps

// ============================================================================
// Self-checking testbench of m_apbdec_full
// Address width 8, data width 32, strobe 4, 1 slave(s), Address Rebase 1
// ============================================================================
module m_apbdec_full_tb;

  localparam int ADDR_WIDTH = 8;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = 4;
  localparam int NUM_SLAVES = 1;

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
  logic        o_psel_all;
  logic        o_penable_all;
  logic        o_pwrite_all;
  logic [7:0] o_paddr_all;
  logic [DATA_WIDTH-1:0] o_pwdata_all;
  logic [STRB_WIDTH-1:0] o_pstrb_all;
  logic [2:0]  o_pprot_all;
  logic        i_pready_all;
  logic        i_pslverr_all;
  logic [DATA_WIDTH-1:0] i_prdata_all;

  integer n_chk;
  integer n_fail;

  // ---------------------------------------------------------------- DUT
  m_apbdec_full u_m_apbdec_full (
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
    .o_psel_all(o_psel_all),
    .o_penable_all(o_penable_all),
    .o_pwrite_all(o_pwrite_all),
    .o_paddr_all(o_paddr_all),
    .o_pwdata_all(o_pwdata_all),
    .o_pstrb_all(o_pstrb_all),
    .o_pprot_all(o_pprot_all),
    .i_pready_all(i_pready_all),
    .i_pslverr_all(i_pslverr_all),
    .i_prdata_all(i_prdata_all)
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

  // Slave 0: ALL
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0),
    .PARA_MEM_WORDS(32),
    .PARA_MEM_ALIAS(0)
  ) u_all_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_all),
    .i_pwdata(o_pwdata_all),
    .o_prdata(i_prdata_all),
    .i_pwrite(o_pwrite_all),
    .i_psel(o_psel_all),
    .i_penable(o_penable_all),
    .o_pready(i_pready_all),
    .o_pslverr(i_pslverr_all),
    .i_pstrb(o_pstrb_all),
    .i_pprot(o_pprot_all)
  );

  // ---------------------------------------------------------------- waveform dump
  initial begin
`ifdef VCS
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, m_apbdec_full_tb, "+mda");
`else
    $dumpfile("wave.vcd");
    $dumpvars(0, m_apbdec_full_tb);
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
    if (a >= 8'h0 && a <= 8'hFF) owner_of = 0;
  endfunction

  // Expected local address of slave k for the requester address a.
  function automatic logic [31:0] exp_local(input integer k, input logic [ADDR_WIDTH-1:0] a);
    exp_local = 32'd0;
    case (k)
      0: exp_local = (32'(a) - 32'h0) & 32'hFF;
      default: exp_local = 32'd0;
    endcase
  endfunction

  // Local address that slave k actually sees.
  function automatic logic [31:0] act_local(input integer k);
    act_local = 32'd0;
    case (k)
      0: act_local = 32'(o_paddr_all);
      default: act_local = 32'd0;
    endcase
  endfunction

  function automatic logic sl_pready(input integer k);
    sl_pready = 1'b0;
    case (k)
      0: sl_pready = i_pready_all;
      default: sl_pready = 1'b0;
    endcase
  endfunction

  function automatic logic sl_pslverr(input integer k);
    sl_pslverr = 1'b0;
    case (k)
      0: sl_pslverr = i_pslverr_all;
      default: sl_pslverr = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] sl_prdata(input integer k);
    sl_prdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: sl_prdata = i_prdata_all;
      default: sl_prdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  // Slave error that the slave BFM answers for the local address (slave 0 only, see slave_ram).
  function automatic logic exp_slverr(input integer k, input logic [31:0] local_addr);
    exp_slverr = 1'b0;
    case (k)
      0: exp_slverr = ((local_addr >> 2) >= 32);
      default: exp_slverr = 1'b0;
    endcase
  endfunction


  // ---------------------------------------------------------------- transaction scoreboard
  // One requester transfer must give exactly one slave access at the owner of the address (none
  // for a hole), with the attributes and the local address of the reference model, and the
  // response of the requester side must be the response of that slave (or of the hole).
  logic [NUM_SLAVES-1:0] w_psel_vec;
  logic [NUM_SLAVES-1:0] w_dn_done_vec;
  assign w_psel_vec = {o_psel_all};
  assign w_dn_done_vec = {(o_psel_all & o_penable_all & i_pready_all)};

  function automatic logic dn_pwrite(input integer k);
    dn_pwrite = 1'b0;
    case (k)
      0: dn_pwrite = o_pwrite_all;
      default: dn_pwrite = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] dn_pwdata(input integer k);
    dn_pwdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: dn_pwdata = o_pwdata_all;
      default: dn_pwdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [STRB_WIDTH-1:0] dn_pstrb(input integer k);
    dn_pstrb = {STRB_WIDTH{1'b0}};
    case (k)
      0: dn_pstrb = o_pstrb_all;
      default: dn_pstrb = {STRB_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [2:0] dn_pprot(input integer k);
    dn_pprot = 3'd0;
    case (k)
      0: dn_pprot = o_pprot_all;
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
      chk(o_penable_all === (m_penable & o_psel_all) && o_pwrite_all === m_pwrite &&
          o_pwdata_all === m_pwdata && o_pstrb_all === m_pstrb &&
          o_pprot_all === m_pprot, "forwarded attributes of all");
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

  integer w_chk_cnt_all;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(1)
  ) u_chk_all (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_all), .i_pprot(o_pprot_all),
    .i_psel(o_psel_all), .i_penable(o_penable_all), .i_pwrite(o_pwrite_all),
    .i_pwdata(o_pwdata_all), .i_pstrb(o_pstrb_all), .i_pready(i_pready_all),
    .i_pslverr(i_pslverr_all), .o_err_cnt(w_chk_cnt_all)
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
        0: a = $urandom;
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
    $display("APB Decoder Testbench: m_apbdec_full");
    $display("========================================");

    // Mapped windows: edges, middle, neighbors, write and read back
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);

  // ---- Slave 0: ALL 0x0 to 0xFF (256 B)
  wr_rd_chk(8'h0, pat(32'd1));
  wr_rd_chk(8'hFF, pat(32'd2));
  wr_rd_chk(8'h80, pat(32'd3));
    end

    // Unmapped holes with the pin at 1 (error) and at 0 (ready only)
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);
  // the slaves cover the whole address space: there is no unmapped address
    end

  // ---- Byte lanes: only the enabled lane changes (slave 0)
  tick_idle();
  lane_e = exp_slverr(0, exp_local(0, 8'h0));
  u_master_bfm.write(8'h0, 32'd0);
  u_master_bfm.write_strb(8'h0, ~32'd0, 4'd1);
  u_master_bfm.read(8'h0, v_rdata);
  chk(u_master_bfm.last_pslverr === lane_e, "byte lane read PSLVERR");
  if (!lane_e)
    chk(v_rdata === 32'hFF, "only lane 0 written");

    // Random traffic with the pin changing between transfers
    random_traffic(300);

    tick_idle();
    chk((w_chk_cnt_req + w_chk_cnt_all) == 0, "the APB protocol checkers report no violation");
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
