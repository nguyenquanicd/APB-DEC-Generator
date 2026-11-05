"""Coverage summary of Verilator coverage databases (coverage.dat) of the generated decoder.

Usage: python cov_report.py [--min PERCENT] [--detail] db1.dat [db2.dat ...]

Every database is one configuration (the generated RTL differs between configurations), so each
one gets its own table. A point is covered when its count is at least 1. Points are grouped by
generated source file and by type: line (statements), branch (if and case arms) and toggle (every
bit, rising and falling). The design set is the generated decoder modules (files m_*.sv except the
testbench); BFMs and the testbench are listed apart with --detail. Exit code 0 when every type of
the design set reaches the minimum in every database, 1 otherwise.
"""
import re
import sys
from collections import defaultdict

KEY = re.compile(r"^C '(.*)' (\d+)\s*$")
TYPES = ('line', 'branch', 'toggle')


def fields(key):
    d = {}
    for part in key.split('\x01'):
        if '\x02' in part:
            k, v = part.split('\x02', 1)
            d[k] = v
    return d


def read_db(path):
    stat = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    with open(path, encoding='latin-1') as fh:
        for ln in fh:
            m = KEY.match(ln)
            if not m:
                continue
            f = fields(m.group(1))
            typ = f.get('t', '?')
            if typ not in TYPES:
                continue
            name = f.get('f', '?').replace('\\', '/').split('/')[-1]
            s = stat[name][typ]
            s[1] += 1
            if int(m.group(2)) > 0:
                s[0] += 1
    return stat


def is_design(name):
    return name.startswith('m_') and not name.endswith('_tb.sv')


def pct(s):
    return 100.0 * s[0] / s[1] if s[1] else float('nan')


def cell(s):
    return '%5d/%-5d %5.1f%%' % (s[0], s[1], pct(s)) if s[1] else '        -        '


def report(path, minimum, detail):
    stat = read_db(path)
    print(f"\n== {path}")
    print('%-30s %18s %18s %18s' % ('file', 'line', 'branch', 'toggle'))
    tot = {t: [0, 0] for t in TYPES}
    for name in sorted(n for n in stat if is_design(n)):
        for t in TYPES:
            tot[t][0] += stat[name][t][0]
            tot[t][1] += stat[name][t][1]
        print('%-30s %18s %18s %18s' % (name, *(cell(stat[name][t]) for t in TYPES)))
    print('%-30s %18s %18s %18s' % ('TOTAL decoder RTL', *(cell(tot[t]) for t in TYPES)))
    if detail:
        for name in sorted(n for n in stat if not is_design(n)):
            print('%-30s %18s %18s %18s' % (name, *(cell(stat[name][t]) for t in TYPES)))
    return all(tot[t][1] == 0 or pct(tot[t]) >= minimum for t in TYPES), tot


def main(argv):
    minimum, detail, dbs = 80.0, False, []
    i = 0
    while i < len(argv):
        if argv[i] == '--min':
            minimum = float(argv[i + 1])
            i += 2
        elif argv[i] == '--detail':
            detail = True
            i += 1
        else:
            dbs.append(argv[i])
            i += 1
    if not dbs:
        print(__doc__)
        return 2
    ok = True
    grand = {t: [0, 0] for t in TYPES}
    for db in dbs:
        good, tot = report(db, minimum, detail)
        ok = ok and good
        for t in TYPES:
            grand[t][0] += tot[t][0]
            grand[t][1] += tot[t][1]
    print('\nall databases together: ' + '   '.join(f"{t} {pct(grand[t]):.1f}%" for t in TYPES))
    print('minimum %.0f%% on every type in every database: %s' % (minimum, 'PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
