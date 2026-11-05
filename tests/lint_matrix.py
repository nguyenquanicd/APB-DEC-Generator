#!/usr/bin/env python3
"""Lint of the generated RTL for every option combination of run_matrix.py.

Verilator `--lint-only -Wall` must give no error (a lint error is a syntax or elaboration problem)
and no latch, width or multiple-driver warning; the remaining warnings (unused bits of the address
and of the vectors) are counted. When the rule checker of the VLSIT RTL generator skill is found
(environment variable VLSIT_RTL_CHECK, or ~/.claude/skills/vlsit-rtl-generator/scripts/
vlsit_rtl_check.py) it runs on each generated folder as well and must report RESULT: PASS.
Usage: python tests/lint_matrix.py [--only NAME]. Exit code 0 when every case is clean.
"""
import argparse
import collections
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim_flow                        # noqa: E402
from run_matrix import case_list       # noqa: E402
from xlsx_builder import write_workbook  # noqa: E402

FORBIDDEN = ('LATCH', 'WIDTH', 'MULTIDRIVEN', 'COMBDLY', 'BLKSEQ', 'CASEINCOMPLETE', 'CASEOVERLAP',
             'IMPLICIT', 'UNOPTFLAT')


def find_checker():
    path = os.environ.get('VLSIT_RTL_CHECK') or os.path.join(
        os.path.expanduser('~'), '.claude', 'skills', 'vlsit-rtl-generator', 'scripts', 'vlsit_rtl_check.py')
    return path if os.path.isfile(path) else None


def lint_case(case, root, checker):
    name, aw, dw, rebase, slaves, rin, rout = case
    tag = f"{name}_dw{dw}_rb{rebase}_i{rin}o{rout}"
    out = os.path.join(root, tag)
    os.makedirs(out, exist_ok=True)
    x = write_workbook(os.path.join(out, tag + '.xlsx'), module='m_apbdec_tst', aw=aw, dw=dw,
                       rebase=rebase, slaves=slaves, formulas=False, reg_in=rin, reg_out=rout)
    cfg, _, files = sim_flow.generate(x, os.path.join(out, 'all'))
    gen = os.path.join(out, 'rtl')            # the RTL files only: the testbench is not design RTL
    os.makedirs(gen, exist_ok=True)
    for f in files:
        shutil.copy(os.path.join(out, 'all', f), os.path.join(gen, f))
    env = sim_flow.tool_env()
    verilator = shutil.which('verilator_bin', path=env['PATH']) or shutil.which('verilator', path=env['PATH'])
    env.setdefault('VERILATOR_ROOT', r'C:\Tools\oss-cad-suite\share\verilator')
    cmd = [verilator, '--lint-only', '--sv', '-Wall', '-Wno-fatal', '--top-module', cfg['module_name']]
    cmd += [os.path.join(gen, f) for f in files]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    text = r.stdout + r.stderr
    kinds = collections.Counter(re.findall(r'%Warning-([A-Z0-9_]+)', text))
    problems = []
    if re.search(r'^%Error', text, re.M):
        problems.append('verilator error')
    problems += [f"warning {k}" for k in kinds if k in FORBIDDEN]
    if checker:
        c = subprocess.run([sys.executable, checker, 'check', gen], capture_output=True, text=True)
        if 'RESULT: PASS' not in c.stdout:
            problems.append('rule check: ' + (re.findall(r'^(?:ERROR).*$', c.stdout, re.M) or ['FAIL'])[0])
    return tag, problems, kinds


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', default=None)
    a = ap.parse_args()
    checker = find_checker()
    root = tempfile.mkdtemp(prefix='apbdec_lint_')
    print(f"rule checker: {checker or 'not found (skipped)'}")
    total = collections.Counter()
    bad = 0
    cases = case_list(a.only)
    for case in cases:
        tag, problems, kinds = lint_case(case, root, checker)
        total.update(kinds)
        if problems:
            bad += 1
            print(f"FAIL {tag}: {problems}")
    print(f"{len(cases) - bad} of {len(cases)} cases clean; warnings seen: {dict(total)}")
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
