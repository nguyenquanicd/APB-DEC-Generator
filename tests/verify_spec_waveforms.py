"""Simulate the write of WF-014..017 (ROMTAB 0xE014) and compare the per-cycle trace with the WaveJSON."""
import json
import os
import re
import subprocess
import sys

ROOT = r"C:\HQuan\102_MyGithub\APB-DEC-Generator"
sys.path.insert(0, os.path.join(ROOT, 'tests'))
sys.path.insert(0, os.path.join(ROOT, 'examples'))
sys.path.insert(0, os.path.join(ROOT, 'src'))
import sim_flow                      # noqa: E402
import apb_dec_rtl_generator as rtlgen   # noqa: E402
from xlsx_builder import write_workbook  # noqa: E402
from make_examples import SHIPPED        # noqa: E402

WORK = os.path.join(ROOT, 'tests', 'cov_work', 'wfsim')
FIG = os.path.join(ROOT, 'docs', 'figures')
CASES = [("wf_014_rebase_option_none", 0, 0), ("wf_015_rebase_option_reg_out", 0, 1),
         ("wf_016_rebase_option_reg_in", 1, 0), ("wf_017_rebase_option_reg_in_out", 1, 1)]


def tb(piped, mod, slaves):
    ports = []
    decl = []
    for n in slaves:
        n = n.lower()
        decl.append(f"logic o_psel_{n}, o_penable_{n}, o_pwrite_{n}; logic [31:0] o_pwdata_{n}; "
                    f"logic [3:0] o_pstrb_{n}; logic [2:0] o_pprot_{n}; logic [31:0] i_prdata_{n};")
        ports.append(f".o_psel_{n}(o_psel_{n}), .o_penable_{n}(o_penable_{n}), .o_pwrite_{n}(o_pwrite_{n}), "
                     f".o_paddr_{n}(o_paddr_{n}), .o_pwdata_{n}(o_pwdata_{n}), .o_pstrb_{n}(o_pstrb_{n}), "
                     f".o_pprot_{n}(o_pprot_{n}), .i_pready_{n}(i_pready_{n}), .i_pslverr_{n}(1'b0), "
                     f".i_prdata_{n}(i_prdata_{n})")
        decl.append(f"logic i_pready_{n}; assign i_prdata_{n} = 32'h0; "
                    f"assign i_pready_{n} = o_psel_{n} & o_penable_{n};")
    widths = {'uart': 8, 'i2c': 5, 'spi': 12, 'can': 15, 'pwm': 8, 'gyro': 10, 'sramcsr': 13, 'romtab': 5}
    for n, w in widths.items():
        decl.append(f"logic [{w-1}:0] o_paddr_{n};")
    clk = ".i_clk_apb(clk), .i_rst_n_apb(rst_n), " if piped else ""
    return f"""`timescale 1ns/1ps
module wf_tb;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  logic [23:0] i_paddr; logic [2:0] i_pprot = 0; logic i_psel, i_penable, i_pwrite;
  logic [31:0] i_pwdata; logic [3:0] i_pstrb = 4'hF; logic o_pready, o_pslverr; logic [31:0] o_prdata;
  logic i_unmapped_err_en = 1;
  {chr(10).join('  ' + d for d in decl)}
  {mod} dut ({clk}.i_paddr(i_paddr), .i_pprot(i_pprot), .i_psel(i_psel), .i_penable(i_penable),
    .i_pwrite(i_pwrite), .i_pwdata(i_pwdata), .i_pstrb(i_pstrb), .o_pready(o_pready),
    .o_prdata(o_prdata), .o_pslverr(o_pslverr), .i_unmapped_err_en(i_unmapped_err_en),
    {(','+chr(10)+'    ').join(ports)});
  integer cyc = 0;
  always @(negedge clk) if (rst_n) begin
    $display("TR %0d %b %b %h %b %b %b %h %b", cyc, i_psel, i_penable, i_paddr, o_pready,
             o_psel_romtab, o_penable_romtab, o_paddr_romtab, i_pready_romtab);
    cyc = cyc + 1;
  end
  initial begin
    i_psel = 0; i_penable = 0; i_pwrite = 0; i_paddr = 0; i_pwdata = 0;
    repeat (3) @(posedge clk); #1 rst_n = 1;
    @(posedge clk); #1;  // cyc 0 is idle, setup in cyc 1 (as in the figures)
    i_psel = 1; i_pwrite = 1; i_paddr = 24'hE014; i_pwdata = 32'hD0;
    @(posedge clk); #1 i_penable = 1; #1;
    while (!o_pready) begin @(posedge clk); #1; end
    @(posedge clk); #1 i_psel = 0; i_penable = 0;
    repeat (4) @(posedge clk);
    $finish;
  end
endmodule
"""


def expand(w, data=None):
    out, last = [], None
    d = iter(data or [])
    for ch in w:
        if ch == '.':
            out.append(last)
            continue
        if ch == '=':
            last = next(d)
        elif ch == 'x':
            last = 'x'
        else:
            last = ch
        out.append(last)
    return out


def sigs(j):
    flat = {}

    def walk(items):
        for it in items:
            if isinstance(it, list):
                walk(it[1:])
            else:
                flat.setdefault(it['name'], []).append(it)
    walk(j['signal'])
    return flat


bad = 0
for name, rin, rout in CASES:
    for reb in (1, 0):
        d = os.path.join(WORK, f"{name}_rb{reb}")
        os.makedirs(d, exist_ok=True)
        x = os.path.join(d, 'c.xlsx')
        write_workbook(x, module='m_wfdec', aw=24, dw=32, rebase=reb, slaves=SHIPPED, formulas=False,
                       reg_in=rin, reg_out=rout)
        cfg, w, files = sim_flow.generate(x, d)
        open(os.path.join(d, 'wf_tb.sv'), 'w').write(tb(rin or rout, 'm_wfdec', [s[0] for s in SHIPPED]))
        env = sim_flow.tool_env()
        r = subprocess.run([sim_flow.shutil.which('iverilog', path=env['PATH']), '-g2012', '-o', 'w.vvp', os.path.join(d, 'm_wfdec.sv'),
                            os.path.join(d, 'wf_tb.sv')], cwd=d, capture_output=True, text=True, env=env)
        if r.returncode:
            print(r.stdout, r.stderr)
            sys.exit(1)
        r = subprocess.run([sim_flow.shutil.which('vvp', path=env['PATH']), 'w.vvp'], cwd=d, capture_output=True, text=True, env=env)
        rows = [l.split() for l in r.stdout.splitlines() if l.startswith('TR')]
        rows = [x for x in rows if int(x[1]) < 8]
        j = json.load(open(os.path.join(FIG, name + '.json')))
        f = sigs(j)
        exp = {}
        for sname, key in (("i_psel", 2), ("i_penable", 3), ("o_pready", 5), ("o_psel_romtab", 6),
                           ("o_penable_romtab", 7), ("i_pready_romtab", 9)):
            exp[sname] = expand(f[sname][0]['wave'])
        pa = f["o_paddr_romtab"][0 if reb else 1]
        exp_addr = expand(pa['wave'], pa['data'])
        exp_req = expand(f["i_paddr"][0]['wave'], f["i_paddr"][0]['data'])
        names = [("i_psel", 2), ("i_penable", 3), ("o_pready", 5), ("o_psel_romtab", 6),
                 ("o_penable_romtab", 7), ("i_pready_romtab", 9)]
        ok = True
        for sname, col in names:
            got = ''.join(r_[col] for r_ in rows)
            want = ''.join(exp[sname][:len(rows)])
            if got != want:
                ok = False
                print(f"  MISMATCH {sname}: sim {got} drawn {want}")
        for i, r_ in enumerate(rows):
            if r_[6] == '1':
                want = exp_addr[i]
                got = '0x' + r_[8].upper().lstrip('0').rjust(2, '0')
                if got != want:
                    ok = False
                    print(f"  MISMATCH o_paddr at {i}: sim {got} drawn {want}")
            drawn_req = exp_req[i]
            if (drawn_req == '0xE014') != (r_[2] == '1' and r_[4].upper() == '00E014'):
                ok = False
                print(f"  MISMATCH i_paddr at {i}")
        print(("OK   " if ok else "FAIL ") + f"{name} rebase={reb}: rows={len(rows)}")
        bad += (not ok)
sys.exit(1 if bad else 0)
