#!/usr/bin/env python3
"""Line coverage of the two generator scripts while the unit tests run (standard library only).

Usage: python tests/cov_python.py [--min PERCENT] [--missing]
Exit code 0 when every generator script reaches the minimum (default 80).
"""
import argparse
import os
import sys
import threading
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGETS = [os.path.join(ROOT, 'src', 'apb_dec_rtl_generator.py'),
           os.path.join(ROOT, 'src', 'apb_dec_tb_generator.py')]


def executable_lines(path):
    """Line numbers that hold code (from the compiled code objects, docstrings excluded)."""
    with open(path, encoding='utf-8') as fh:
        code = compile(fh.read(), path, 'exec')
    lines, stack = set(), [code]
    while stack:
        co = stack.pop()
        for _, _, ln in co.co_lines():
            if ln:
                lines.add(ln)
        stack.extend(c for c in co.co_consts if hasattr(c, 'co_lines'))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--min', type=float, default=80.0)
    ap.add_argument('--missing', action='store_true')
    args = ap.parse_args()

    real = {os.path.normcase(os.path.abspath(p)): p for p in TARGETS}
    hit = {p: set() for p in TARGETS}

    def tracer(frame, event, arg):
        key = os.path.normcase(os.path.abspath(frame.f_code.co_filename))
        if key not in real:
            return None
        bucket = hit[real[key]]

        def local(frame, event, arg):
            if event == 'line':
                bucket.add(frame.f_lineno)
            return local
        bucket.add(frame.f_lineno)
        return local

    sys.path.insert(0, os.path.join(ROOT, 'src'))
    sys.path.insert(0, HERE)
    sys.settrace(tracer)
    threading.settrace(tracer)
    suite = unittest.defaultTestLoader.discover(HERE)
    result = unittest.TextTestRunner(verbosity=0).run(suite)
    sys.settrace(None)
    threading.settrace(None)

    ok = result.wasSuccessful()
    print()
    print('%-30s %10s %10s %8s' % ('file', 'lines', 'executed', 'percent'))
    for p in TARGETS:
        want = executable_lines(p)
        got = hit[p] & want
        pct = 100.0 * len(got) / len(want)
        print('%-30s %10d %10d %7.1f%%' % (os.path.basename(p), len(want), len(got), pct))
        if args.missing:
            print('   not executed:', sorted(want - got))
        ok = ok and pct >= args.min
    print('minimum %.0f%% and all tests pass: %s' % (args.min, 'PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
