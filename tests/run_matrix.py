#!/usr/bin/env python3
"""Runs every combination of the options of the decoder through generate -> simulate.

Dimensions: memory-map scenario (windows, address width) x Data Width (8, 16, 32) x Address
Rebase (0, 1). The input pin i_unmapped_err_en (1 and 0) is exercised inside every simulation by
the generated testbench. Usage: python tests/run_matrix.py [--jobs N] [--only NAME] [--keep DIR]
Exit code 0 when every case passes.
"""
import argparse
import os
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim_flow import simulate        # noqa: E402
from xlsx_builder import write_workbook  # noqa: E402


def _contiguous(start, sizes, gap=0):
    out, a = [], start
    for i, sz in enumerate(sizes):
        out.append((f"W{i}", f"0x{a:X}", f"0x{a + sz - 1:X}"))
        a += sz + gap
    return out


def _many(n, stride, base=0x100):
    """n slaves with sizes that vary (1 .. stride-1 bytes), all inside 16 bits."""
    out = []
    for i in range(n):
        size = 1 + (i * 7) % (stride - 1)
        a = base + i * stride
        out.append((f"S{i}", f"0x{a:X}", f"0x{a + size - 1:X}"))
    return out


SCENARIOS = {
    # name: (address width, slaves)
    'shipped': (24, [('UART', '0x0', '0xFF'), ('I2C', '0x100', '0x117'), ('SPI', '0x1000', '0x1FFF'),
                     ('CAN', '0x2000', '0x9FFF'), ('PWM', '0xA000', '0xA0FF'),
                     ('GYRO', '0xB000', '0xB3FF'), ('SRAMCSR', '0xC000', '0xD7FF'),
                     ('ROMTAB', '0xE010', '0xE02F')]),
    'one_byte_hole': (1, [('A', '0x0', '0x0')]),
    'two_bytes_full': (1, [('A', '0x0', '0x0'), ('B', '0x1', '0x1')]),
    'full_space_8': (8, [('ALL', '0x0', '0xFF')]),
    'wide_32': (32, [('LOWMEM', '0x0', '0xFFFF'), ('MIDDLE', '0x12345678', '0x123456FF'),
                     ('TOPREG', '0xFFFFFF00', '0xFFFFFFFF')]),
    'whole_32': (32, [('EVERYTHING', '0x0', '0xFFFFFFFF')]),
    'adjacent_odd': (16, _contiguous(0x100, [3, 5, 7, 9, 11, 13])),
    'gaps_odd': (16, _contiguous(0x21, [3, 5, 7, 9, 11, 13], gap=2)),
    'top_and_bottom': (12, [('FIRST', '0x0', '0x2'), ('LAST', '0xFFD', '0xFFF'),
                            ('MID', '0x800', '0x8FF')]),
    'non_pow2_20': (20, [('N3', '0x10', '0x12'), ('N24', '0x100', '0x117'), ('N100', '0x400', '0x463'),
                         ('N6K', '0x1000', '0x27FF'), ('N65K', '0x10000', '0x20000'),
                         ('ALIGNED', '0x40000', '0x7FFFF')]),
    'many_64': (16, _many(64, 0x3C0)),
    'start_zero_unaligned_end': (10, [('ONE', '0x0', '0x6'), ('TWO', '0x8', '0x1B')]),
}


def case_list(only=None):
    cases = []
    for name, (aw, slaves) in SCENARIOS.items():
        if only and only not in name:
            continue
        for dw in (8, 16, 32):
            for rebase in (0, 1):
                for rin in (0, 1):
                    for rout in (0, 1):
                        cases.append((name, aw, dw, rebase, slaves, rin, rout))
    return cases


def run_case(case, workroot):
    name, aw, dw, rebase, slaves, rin, rout = case
    tag = f"{name}_dw{dw}_rb{rebase}_i{rin}o{rout}"
    work = os.path.join(workroot, tag)
    os.makedirs(work, exist_ok=True)
    xlsx = os.path.join(work, tag + '.xlsx')
    write_workbook(xlsx, module='m_apbdec_tst', aw=aw, dw=dw, rebase=rebase, slaves=slaves,
                   formulas=False, reg_in=rin, reg_out=rout)
    res = simulate(xlsx, os.path.join(work, 'out'))
    res['tag'] = tag
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--only', default=None, help='substring of the scenario name')
    ap.add_argument('--keep', default=None, help='work directory (default: a temporary one)')
    a = ap.parse_args()
    root = a.keep or tempfile.mkdtemp(prefix='apbdec_matrix_')
    cases = case_list(a.only)
    print(f"{len(cases)} cases, work directory {root}")
    fails = 0
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for res in ex.map(lambda c: run_case(c, root), cases):
            print(f"{res['status']:<12} {res['tag']:<36} checks={res['checks']:<7} "
                  f"failed={res['failed']}")
            if res['status'] != 'PASS':
                fails += 1
                print(res['log'][-1500:])
    print(f"\n{len(cases) - fails} of {len(cases)} cases PASS")
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
