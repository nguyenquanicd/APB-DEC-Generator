#!/usr/bin/env python3
"""
APB Decoder Testbench Generator (revision 0.2)

Reads the JSON file of apb_dec_rtl_generator.py (json_version 2) and writes a self-checking
SystemVerilog testbench for the decoder, plus the file list with the testbench.

The testbench contains a reference model of the memory map (owner of an address, local address
of a slave) written from the JSON values, and a monitor that compares the decoder with it in
every cycle: select vector, local address, forwarded attributes and the response of the
requester side. The directed part checks, for every slave, the first and last address of the
window, a middle address, the address just below the start and just above the end, write and read
back and the local address; the unmapped holes are checked with i_unmapped_err_en equal to 1 and
to 0; a random part mixes window and random addresses, slave wait states, a slave error and a
change of the pin between transfers. A failing check ends the run with $fatal (exit code != 0).
"""

import json
import os
import subprocess
import sys
from datetime import datetime

SLAVE_RAM_WORDS_MAX = 1024     # words of one slave BFM memory (larger windows alias)
HOLE_SAMPLES_MAX = 12          # directed unmapped addresses
RANDOM_TRANSFERS = 300


REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUIET = False   # set True by the tests to silence the 'Generated:' lines


def _say(msg):
    if not QUIET:
        print(msg)


def get_author():
    """Get current system username."""
    try:
        return subprocess.check_output(['whoami'], text=True).strip()
    except Exception:
        return 'unknown'


def generate_header(module_name, description):
    return (f"//--------------------------------------\n"
            f"//Project: APB Decoder Generator\n"
            f"//Module:  {module_name}\n"
            f"//Function: {description}\n"
            f"//Author:  {get_author()}\n"
            f"//Script Author: Thang Luong (superzeldalink)\n"
            f"//Page:    VLSI Technology\n"
            f"//Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"//--------------------------------------\n")


def load_json_config(json_path):
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def find_holes(slaves, addr_width):
    """Sample addresses that belong to no slave: first and last address of every gap, the
    address 0 and the highest address when they are free. Returns a sorted list (at most
    HOLE_SAMPLES_MAX entries) and the total number of unmapped addresses."""
    max_addr = (1 << addr_width) - 1
    ranges = sorted((s['start_val'], s['end_val']) for s in slaves)
    gaps = []
    prev_end = -1
    for st, en in ranges:
        if st > prev_end + 1:
            gaps.append((prev_end + 1, st - 1))
        prev_end = max(prev_end, en)
    if prev_end < max_addr:
        gaps.append((prev_end + 1, max_addr))
    total = sum(b - a + 1 for a, b in gaps)
    samples = []
    for a, b in gaps:
        samples.append(a)
        samples.append(b)
        if b - a > 2:
            samples.append(a + (b - a) // 2)
    seen = []
    for v in samples:
        if v not in seen:
            seen.append(v)
    return seen[:HOLE_SAMPLES_MAX], total


def slave_ram(index, width):
    """Memory model of the slave BFM: (words, alias flag, words that answer without error).
    Slave 0 with a port of 4 to 12 bits answers a slave error in the upper half of its words, so
    that the error pass-through of the decoder is exercised; the others alias into a memory of
    at most SLAVE_RAM_WORDS_MAX words."""
    full = 1 << max(width - 2, 1)
    if index == 0 and 4 <= width <= 12:
        return full // 2, 0, full // 2
    return min(full, SLAVE_RAM_WORDS_MAX), 1, None


def generate_tb_sv(config, output_path):
    mod = config['module_name']
    aw = config['address_width']
    dw = config['data_width']
    st = config['write_strobe']
    rebase = config.get('address_rebase', 1)
    slaves = config['slaves']
    n = len(slaves)
    max_addr = (1 << aw) - 1
    holes, hole_total = find_holes(slaves, aw)

    def lit(v):
        return f"{aw}'h{v:X}"

    low = [s['name'].lower() for s in slaves]

    # ---------------------------------------------------------------- declarations
    decl = ""
    for s, lo in zip(slaves, low):
        w = s['address_width']
        decl += (f"  logic        o_psel_{lo};\n  logic        o_penable_{lo};\n"
                 f"  logic        o_pwrite_{lo};\n  logic [{w - 1}:0] o_paddr_{lo};\n"
                 f"  logic [DATA_WIDTH-1:0] o_pwdata_{lo};\n  logic [STRB_WIDTH-1:0] o_pstrb_{lo};\n"
                 f"  logic [2:0]  o_pprot_{lo};\n  logic        i_pready_{lo};\n"
                 f"  logic        i_pslverr_{lo};\n  logic [DATA_WIDTH-1:0] i_prdata_{lo};\n")

    dut_ports = ("    .i_paddr(m_paddr),\n    .i_pprot(m_pprot),\n    .i_psel(m_psel),\n"
                 "    .i_penable(m_penable),\n    .i_pwrite(m_pwrite),\n    .i_pwdata(m_pwdata),\n"
                 "    .i_pstrb(m_pstrb),\n    .o_pready(m_pready),\n    .o_prdata(m_prdata),\n"
                 "    .o_pslverr(m_pslverr),\n    .i_unmapped_err_en(i_unmapped_err_en)")
    for lo in low:
        for p in ("o_psel", "o_penable", "o_pwrite", "o_paddr", "o_pwdata", "o_pstrb", "o_pprot",
                  "i_pready", "i_pslverr", "i_prdata"):
            dut_ports += f",\n    .{p}_{lo}({p}_{lo})"

    bfms = ""
    for i, (s, lo) in enumerate(zip(slaves, low)):
        w = s['address_width']
        words, alias, ok_words = slave_ram(i, w)
        bfms += f"""
  // Slave {i}: {s['name']}
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH({w}),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES({i % 3}),
    .PARA_MEM_WORDS({words}),
    .PARA_MEM_ALIAS({alias})
  ) u_{lo}_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_{lo}),
    .i_pwdata(o_pwdata_{lo}),
    .o_prdata(i_prdata_{lo}),
    .i_pwrite(o_pwrite_{lo}),
    .i_psel(o_psel_{lo}),
    .i_penable(o_penable_{lo}),
    .o_pready(i_pready_{lo}),
    .o_pslverr(i_pslverr_{lo}),
    .i_pstrb(o_pstrb_{lo}),
    .i_pprot(o_pprot_{lo})
  );
"""

    # ---------------------------------------------------------------- reference model
    owner = ""
    for i, s in enumerate(slaves):
        owner += (f"    if (a >= {lit(s['start_val'])} && a <= {lit(s['end_val'])}) "
                  f"owner_of = {i};\n")

    local_cases = ""
    act_cases = ""
    pready_cases = ""
    pslverr_cases = ""
    prdata_cases = ""
    errwords_cases = ""
    for i, (s, lo) in enumerate(zip(slaves, low)):
        w = s['address_width']
        mask = (1 << w) - 1
        if rebase:
            local_cases += (f"      {i}: exp_local = (32'(a) - 32'h{s['start_val']:X}) & "
                            f"32'h{mask:X};\n")
        else:
            local_cases += f"      {i}: exp_local = 32'(a) & 32'h{mask:X};\n"
        act_cases += f"      {i}: act_local = 32'(o_paddr_{lo});\n"
        pready_cases += f"      {i}: sl_pready = i_pready_{lo};\n"
        pslverr_cases += f"      {i}: sl_pslverr = i_pslverr_{lo};\n"
        prdata_cases += f"      {i}: sl_prdata = i_prdata_{lo};\n"
        words, alias, ok_words = slave_ram(i, w)
        if ok_words is not None:
            errwords_cases += f"      {i}: exp_slverr = ((local_addr >> 2) >= {ok_words});\n"

    fwd = ""
    for lo in low:
        fwd += (f"      chk(o_penable_{lo} === (m_penable & o_psel_{lo}) && o_pwrite_{lo} === m_pwrite &&\n"
                f"          o_pwdata_{lo} === m_pwdata && o_pstrb_{lo} === m_pstrb &&\n"
                f"          o_pprot_{lo} === m_pprot, \"forwarded attributes of {lo}\");\n")

    psel_vec = ", ".join(f"o_psel_{lo}" for lo in reversed(low))

    # ---------------------------------------------------------------- directed sequence
    seq = ""
    for i, s in enumerate(slaves):
        a0, a1 = s['start_val'], s['end_val']
        mid = a0 + s['size_bytes'] // 2
        seq += f"\n  // ---- Slave {i}: {s['name']} 0x{a0:X} to 0x{a1:X} ({s['size']})\n"
        seq += f"  wr_rd_chk({lit(a0)}, pat(32'd{i * 10 + 1}));\n"
        if a1 != a0:
            seq += f"  wr_rd_chk({lit(a1)}, pat(32'd{i * 10 + 2}));\n"
        if mid not in (a0, a1):
            seq += f"  wr_rd_chk({lit(mid)}, pat(32'd{i * 10 + 3}));\n"
        if a0 > 0:
            seq += f"  rd_chk({lit(a0 - 1)});\n"
        if a1 < max_addr:
            seq += f"  rd_chk({lit(a1 + 1)});\n"

    holes_seq = ""
    for h in holes:
        holes_seq += f"  rd_chk({lit(h)});\n  wr_chk({lit(h)}, pat(32'd{h & 0xFFFF}));\n"
    if not holes:
        holes_seq = "  // the slaves cover the whole address space: there is no unmapped address\n"

    lane_test = ""
    if st >= 2:
        a0 = slaves[0]['start_val']
        lane_test = f"""
  // ---- Byte lanes: only the enabled lane changes (slave 0)
  tick_idle();
  lane_e = exp_slverr(0, exp_local(0, {lit(a0)}));
  u_master_bfm.write({lit(a0)}, {dw}'d0);
  u_master_bfm.write_strb({lit(a0)}, ~{dw}'d0, {st}'d1);
  u_master_bfm.read({lit(a0)}, v_rdata);
  chk(u_master_bfm.last_pslverr === lane_e, "byte lane read PSLVERR");
  if (!lane_e)
    chk(v_rdata === {dw}'h{(1 << 8) - 1:X}, "only lane 0 written");
"""

    exp_slverr_body = ("      default: exp_slverr = 1'b0;\n" if not errwords_cases else
                       errwords_cases + "      default: exp_slverr = 1'b0;\n")

    monitor_comb = f"""  // ---------------------------------------------------------------- monitor
  // Compares the decoder with the reference model in every cycle after reset.
  integer      mon_owner;
  logic [NUM_SLAVES-1:0] mon_exp_vec;

  always @(posedge i_clk) begin
    if (i_rst_n === 1'b1) begin
      mon_owner = owner_of(m_paddr);
      mon_exp_vec = {{NUM_SLAVES{{1'b0}}}};
      if (m_psel && mon_owner >= 0)
        mon_exp_vec[mon_owner] = 1'b1;
      chk(w_psel_vec === mon_exp_vec, "select vector (one-hot owner, none for a hole)");
      chk($onehot0(w_psel_vec), "at most one slave select");
{fwd}      if (m_psel && mon_owner >= 0) begin
        chk(act_local(mon_owner) === exp_local(mon_owner, m_paddr), "local address of the owner");
      end
      if (!m_psel || !m_penable)
        chk(m_pslverr === 1'b0, "PSLVERR low when PSEL or PENABLE is low");
      if (m_psel && m_penable) begin
        if (mon_owner < 0) begin
          chk(m_pready === 1'b1, "unmapped address: PREADY high");
          chk(m_prdata === {{DATA_WIDTH{{1'b0}}}}, "unmapped address: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "unmapped address: PSLVERR follows the pin");
        end else begin
          chk(m_pready === sl_pready(mon_owner), "PREADY of the selected slave");
          chk(m_prdata === sl_prdata(mon_owner), "PRDATA of the selected slave");
          chk(m_pslverr === (m_pready & sl_pslverr(mon_owner)), "PSLVERR of the selected slave");
        end
      end
    end
  end

"""

    # ---------------------------------------------------------------- register options
    piped = bool(config.get('register_inputs') or config.get('register_outputs'))
    if piped:
        dut_ports = "    .i_clk_apb(i_clk),\n    .i_rst_n_apb(i_rst_n),\n" + dut_ports

    done_vec = ", ".join(f"(o_psel_{lo} & o_penable_{lo} & i_pready_{lo})" for lo in reversed(low))
    dn_cases = {k: "" for k in ('pwrite', 'pwdata', 'pstrb', 'pprot')}
    for i, lo in enumerate(low):
        for k in dn_cases:
            dn_cases[k] += f"      {i}: dn_{k} = o_{k}_{lo};\n"

    checkers = f"""  // ---------------------------------------------------------------- protocol checkers
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
"""
    sum_expr = "w_chk_cnt_req"
    for i, (s, lo) in enumerate(zip(slaves, low)):
        w = s['address_width']
        checkers += f"""
  integer w_chk_cnt_{lo};
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH({w}),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID({i + 1})
  ) u_chk_{lo} (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_{lo}), .i_pprot(o_pprot_{lo}),
    .i_psel(o_psel_{lo}), .i_penable(o_penable_{lo}), .i_pwrite(o_pwrite_{lo}),
    .i_pwdata(o_pwdata_{lo}), .i_pstrb(o_pstrb_{lo}), .i_pready(i_pready_{lo}),
    .i_pslverr(i_pslverr_{lo}), .o_err_cnt(w_chk_cnt_{lo})
  );
"""
        sum_expr += f" + w_chk_cnt_{lo}"

    hole_age = 1 + 2 * int(bool(config.get('register_inputs'))) + 2 * int(bool(config.get('register_outputs')))

    scoreboard = f"""
  // ---------------------------------------------------------------- transaction scoreboard
  // One requester transfer must give exactly one slave access at the owner of the address (none
  // for a hole), with the attributes and the local address of the reference model, and the
  // response of the requester side must be the response of that slave (or of the hole).
  logic [NUM_SLAVES-1:0] w_psel_vec;
  logic [NUM_SLAVES-1:0] w_dn_done_vec;
  assign w_psel_vec = {{{psel_vec}}};
  assign w_dn_done_vec = {{{done_vec}}};

  function automatic logic dn_pwrite(input integer k);
    dn_pwrite = 1'b0;
    case (k)
{dn_cases['pwrite']}      default: dn_pwrite = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] dn_pwdata(input integer k);
    dn_pwdata = {{DATA_WIDTH{{1'b0}}}};
    case (k)
{dn_cases['pwdata']}      default: dn_pwdata = {{DATA_WIDTH{{1'b0}}}};
    endcase
  endfunction

  function automatic logic [STRB_WIDTH-1:0] dn_pstrb(input integer k);
    dn_pstrb = {{STRB_WIDTH{{1'b0}}}};
    case (k)
{dn_cases['pstrb']}      default: dn_pstrb = {{STRB_WIDTH{{1'b0}}}};
    endcase
  endfunction

  function automatic logic [2:0] dn_pprot(input integer k);
    dn_pprot = 3'd0;
    case (k)
{dn_cases['pprot']}      default: dn_pprot = 3'd0;
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
        chk(w_psel_vec === {{NUM_SLAVES{{1'b0}}}}, "no slave select without a requester transfer");
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
            chk(m_prdata === {{DATA_WIDTH{{1'b0}}}}, "hole: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "hole: PSLVERR follows the pin");
          chk(sb_age == {hole_age}, "hole: cycles from the setup to the end of the transfer");
        end
        sb_open = 1'b0;
        sb_txn  = sb_txn + 1;
      end
    end
  end

"""
    monitor_section = scoreboard + ('' if piped else monitor_comb) + checkers + "\n"

    header = generate_header(mod, "APB Decoder Testbench")
    tb = header + f"""
`timescale 1ns/1ps

// ============================================================================
// Self-checking testbench of {mod}
// Address width {aw}, data width {dw}, strobe {st}, {n} slave(s), Address Rebase {rebase}
// ============================================================================
module {mod}_tb;

  localparam int ADDR_WIDTH = {aw};
  localparam int DATA_WIDTH = {dw};
  localparam int STRB_WIDTH = {st};
  localparam int NUM_SLAVES = {n};

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
{decl}
  integer n_chk;
  integer n_fail;

  // ---------------------------------------------------------------- DUT
  {mod} u_{mod} (
{dut_ports}
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
{bfms}
  // ---------------------------------------------------------------- waveform dump
  initial begin
`ifdef VCS
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, {mod}_tb, "+mda");
`else
    $dumpfile("wave.vcd");
    $dumpvars(0, {mod}_tb);
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
{owner}  endfunction

  // Expected local address of slave k for the requester address a.
  function automatic logic [31:0] exp_local(input integer k, input logic [ADDR_WIDTH-1:0] a);
    exp_local = 32'd0;
    case (k)
{local_cases}      default: exp_local = 32'd0;
    endcase
  endfunction

  // Local address that slave k actually sees.
  function automatic logic [31:0] act_local(input integer k);
    act_local = 32'd0;
    case (k)
{act_cases}      default: act_local = 32'd0;
    endcase
  endfunction

  function automatic logic sl_pready(input integer k);
    sl_pready = 1'b0;
    case (k)
{pready_cases}      default: sl_pready = 1'b0;
    endcase
  endfunction

  function automatic logic sl_pslverr(input integer k);
    sl_pslverr = 1'b0;
    case (k)
{pslverr_cases}      default: sl_pslverr = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] sl_prdata(input integer k);
    sl_prdata = {{DATA_WIDTH{{1'b0}}}};
    case (k)
{prdata_cases}      default: sl_prdata = {{DATA_WIDTH{{1'b0}}}};
    endcase
  endfunction

  // Slave error that the slave BFM answers for the local address (slave 0 only, see slave_ram).
  function automatic logic exp_slverr(input integer k, input logic [31:0] local_addr);
    exp_slverr = 1'b0;
    case (k)
{exp_slverr_body}    endcase
  endfunction

{monitor_section}  // ---------------------------------------------------------------- directed helpers
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
      chk(v_rdata === {{DATA_WIDTH{{1'b0}}}}, "read of a hole: data zero");
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
    chk(v_rdata === (e ? {{DATA_WIDTH{{1'b0}}}} : d), "read back: data");
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
{_random_window_cases(slaves, aw)}        default: a = $urandom;
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
    v_rdata = {{DATA_WIDTH{{1'b0}}}};

    @(posedge i_rst_n);
    tick_idle();

    $display("");
    $display("========================================");
    $display("APB Decoder Testbench: {mod}");
    $display("========================================");

    // Mapped windows: edges, middle, neighbors, write and read back
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);
{seq}    end

    // Unmapped holes with the pin at 1 (error) and at 0 (ready only)
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);
{holes_seq}    end
{lane_test}
    // Random traffic with the pin changing between transfers
    random_traffic({RANDOM_TRANSFERS});

    tick_idle();
    chk(({sum_expr}) == 0, "the APB protocol checkers report no violation");
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
"""
    with open(output_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(tb)
    _say(f"Generated: {output_path}")
    return holes, hole_total


def _random_window_cases(slaves, aw):
    """case items of random_traffic: a random address inside window k."""
    out = ""
    for i, s in enumerate(slaves):
        out += (f"        {i}: a = {aw}'h{s['start_val']:X} + "
                f"({aw}'($urandom) % {aw}'d{min(s['size_bytes'], (1 << aw) - 1)});\n"
                if s['size_bytes'] < (1 << aw) else
                f"        {i}: a = $urandom;\n")
    return out


def filelist_dir(output_dir):
    """Folder of the generated files as written in filelist.f: $APB_DEC_GEN_HOME/<path inside the
    repository>, or the absolute path when the folder is outside the repository."""
    out = os.path.abspath(output_dir)
    try:
        inside = os.path.commonpath([out, REPO]) == REPO
    except ValueError:
        inside = False
    if inside:
        rel = os.path.relpath(out, REPO).replace(os.sep, '/')
        return '$APB_DEC_GEN_HOME' + ('' if rel == '.' else '/' + rel)
    return out.replace(os.sep, '/')


def generate_filelist(output_dir, module_name):
    """filelist.f of the testbench flow: the decoder file, then the testbench."""
    base = os.path.join(output_dir, 'filelist.f')
    rtl = []
    if os.path.isfile(base):
        with open(base, encoding='utf-8') as f:
            rtl = [ln.strip() for ln in f if ln.strip() and not ln.strip().endswith('_tb.sv')]
    tb_line = f'{filelist_dir(output_dir)}/{module_name}_tb.sv'
    with open(base, 'w', encoding='utf-8', newline='\n') as f:
        for ln in rtl + [tb_line]:
            f.write(ln + "\n")
    _say(f"Generated: {base}")


def main(argv=None):
    argv = sys.argv if argv is None else argv
    json_path = os.path.join(REPO, 'output', 'm_vlsit_apbdec.json')
    output_dir = os.path.join(REPO, 'output')
    if len(argv) > 1:
        json_path = argv[1]
    if len(argv) > 2:
        output_dir = argv[2]

    print("=" * 60)
    print("APB Decoder Testbench Generator (revision 0.2)")
    print("=" * 60)

    try:
        config = load_json_config(json_path)
    except FileNotFoundError:
        print(f"\n[ERROR] '{json_path}' was not found. Run apb_dec_rtl_generator.py first "
              f"(for example 'make rtl').")
        return 1
    if config.get('json_version') != 2:
        print(f"\n[ERROR] '{json_path}' has json_version {config.get('json_version')}; "
              f"this generator needs json_version 2. Regenerate it with apb_dec_rtl_generator.py.")
        return 1
    if not config.get('slaves'):
        print(f"\n[ERROR] '{json_path}' has no slaves -- nothing to generate a testbench for.")
        return 1

    os.makedirs(output_dir, exist_ok=True)
    print(f"  Module Name:      {config['module_name']}")
    print(f"  Number of Slaves: {len(config['slaves'])}")
    tb_path = os.path.join(output_dir, f"{config['module_name']}_tb.sv")
    holes, total = generate_tb_sv(config, tb_path)
    print(f"  Unmapped addresses: {total} ({len(holes)} sampled)")
    generate_filelist(output_dir, config['module_name'])

    print("\n" + "=" * 60)
    print("TB Generation complete!")
    print("=" * 60)
    return 0


if __name__ == '__main__':
    sys.exit(main())
