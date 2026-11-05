#!/usr/bin/env python3
"""Verilator line/branch/toggle coverage of the generated RTL for a set of option combinations.

Usage: python tests/cov_matrix.py [--min 80] [--jobs 2]
Each combination is generated, simulated with the generated testbench under Verilator and reported
by cov_report.py. Needs the tools of run_cov.sh. Exit code 0 when every database reaches the minimum.
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from run_matrix import SCENARIOS          # noqa: E402
from xlsx_builder import write_workbook   # noqa: E402

# (scenario, data width, rebase): the selection covers every scenario, every data width and both
# rebase settings.
SELECTION = [
    ('shipped', 32, 1, 0, 0), ('shipped', 16, 0, 0, 0), ('one_byte_hole', 8, 1, 0, 0),
    ('two_bytes_full', 8, 0, 0, 0), ('full_space_8', 32, 1, 0, 0), ('wide_32', 8, 1, 0, 0),
    ('whole_32', 16, 0, 0, 0), ('adjacent_odd', 32, 0, 0, 0), ('gaps_odd', 16, 1, 0, 0),
    ('top_and_bottom', 8, 0, 0, 0), ('non_pow2_20', 32, 1, 0, 0), ('many_64', 16, 1, 0, 0),
    ('start_zero_unaligned_end', 32, 0, 0, 0),
    # the register options: every map, every data width and both rebase settings are covered above;
    # here the four option combinations meet the interesting maps
    ('shipped', 32, 1, 1, 0), ('shipped', 32, 1, 0, 1), ('shipped', 32, 1, 1, 1),
    ('shipped', 8, 0, 1, 1), ('top_and_bottom', 16, 1, 1, 1), ('full_space_8', 32, 1, 1, 1),
    ('whole_32', 16, 0, 0, 1), ('one_byte_hole', 8, 1, 1, 0), ('two_bytes_full', 8, 0, 1, 1),
    ('many_64', 16, 1, 1, 1), ('non_pow2_20', 32, 1, 1, 0), ('wide_32', 8, 1, 0, 1),
]


def run_one(item, work):
    name, dw, rebase, rin, rout = item
    tag = f"{name}_dw{dw}_rb{rebase}_i{rin}o{rout}"
    aw, slaves = SCENARIOS[name]
    d = os.path.join(work, tag)
    os.makedirs(d, exist_ok=True)
    xlsx = os.path.join(d, tag + '.xlsx')
    write_workbook(xlsx, module='m_apbdec_tst', aw=aw, dw=dw, rebase=rebase, slaves=slaves,
                   formulas=False, reg_in=rin, reg_out=rout)
    env = dict(os.environ, COV_WORK=os.path.join(work, 'cov'), PYTHON=sys.executable)
    r = subprocess.run(['sh', os.path.join(HERE, 'run_cov.sh'), xlsx, tag], env=env,
                       capture_output=True, text=True)
    return tag, r.returncode, os.path.join(work, 'cov', tag, 'coverage.dat')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--min', type=float, default=80.0)
    ap.add_argument('--jobs', type=int, default=2)
    ap.add_argument('--work', default=os.path.join(HERE, 'cov_work', 'matrix'))
    a = ap.parse_args()
    dbs, bad = [], 0
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for tag, code, db in ex.map(lambda i: run_one(i, a.work), SELECTION):
            print(f"{'ok' if code == 0 else 'SIM FAIL':<9} {tag}")
            if code == 0:
                dbs.append(db)
            else:
                bad += 1
    rep = subprocess.run([sys.executable, os.path.join(HERE, 'cov_report.py'), '--min', str(a.min)] + dbs)
    return 1 if (bad or rep.returncode) else 0


if __name__ == '__main__':
    sys.exit(main())
