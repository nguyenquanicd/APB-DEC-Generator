"""Generates RTL, JSON, file list and testbench of every example workbook into its own folder.

The example workbooks are written by make_examples.py. Each example folder gets an `output/`
folder; the main example (APB_DEC_Example.xlsx) is generated into the repository `output/` folder.
Run from anywhere: python examples/run_examples.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))
sys.path.insert(0, os.path.join(ROOT, 'tests'))

import apb_dec_rtl_generator as rtlgen   # noqa: E402
import apb_dec_tb_generator as tbgen     # noqa: E402
from make_examples import EXAMPLES       # noqa: E402


def main():
    status = 0
    for key, (rel, _) in EXAMPLES.items():
        xlsx = os.path.join(ROOT, rel)
        out = os.path.join(os.path.dirname(xlsx), 'output')
        config, errors, warnings = rtlgen.build_config(xlsx)
        if errors:
            print(f"{rel}: ERROR {errors}")
            status = 1
            continue
        for w in warnings:
            print(f"{rel}: WARN {w}")
        rtlgen.QUIET = tbgen.QUIET = True
        rtlgen.generate_all(config, out)
        tbgen.generate_tb_sv(config, os.path.join(out, f"{config['module_name']}_tb.sv"))
        tbgen.generate_filelist(out, config['module_name'])
        print(f"{rel}: {len(config['slaves'])} slave(s) -> {os.path.relpath(out, ROOT)}")
    return status


if __name__ == '__main__':
    sys.exit(main())
