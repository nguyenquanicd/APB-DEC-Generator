"""Generate -> compile -> simulate flow of one workbook (used by the matrix and the coverage runs).

The simulator is Icarus Verilog (iverilog + vvp). Paths are taken from the PATH; on Windows the
OSS CAD Suite folder (OSS_CAD_SUITE or C:/Tools/oss-cad-suite) is added when it exists.
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))

import apb_dec_rtl_generator as rtlgen  # noqa: E402
import apb_dec_tb_generator as tbgen    # noqa: E402

BFMS = [os.path.join(ROOT, 'sim', 'lib', 'apb_protocol_checker.sv'),
        os.path.join(ROOT, 'sim', 'lib', 'apb_master_bfm.sv'),
        os.path.join(ROOT, 'sim', 'lib', 'apb_slave_bfm.sv')]


def tool_env():
    env = dict(os.environ)
    suite = os.environ.get('OSS_CAD_SUITE', r'C:\Tools\oss-cad-suite')
    if os.path.isdir(suite):
        env['PATH'] = os.pathsep.join([os.path.join(suite, 'bin'), os.path.join(suite, 'lib'),
                                       env.get('PATH', '')])
    return env


def generate(xlsx, outdir):
    """Run both generators in-process. Returns (config, warnings) or raises ValueError."""
    config, errors, warnings = rtlgen.build_config(xlsx)
    if errors:
        raise ValueError("; ".join(errors))
    os.makedirs(outdir, exist_ok=True)
    rtlgen.QUIET = tbgen.QUIET = True
    files = rtlgen.generate_all(config, outdir)
    tbgen.generate_tb_sv(config, os.path.join(outdir, f"{config['module_name']}_tb.sv"))
    return config, warnings, files


def simulate(xlsx, workdir, timeout=900, mutate=None):
    """Generate and simulate one workbook. Returns a dict with status, checks, failed, log.

    mutate: optional callable(dict file name -> text) that edits the generated RTL before the
    compile (used by the mutation tests to prove that the testbench detects a fault).
    """
    res = {'xlsx': xlsx, 'status': 'ERROR', 'checks': 0, 'failed': -1, 'log': '', 'warnings': []}
    try:
        config, warnings, files = generate(xlsx, workdir)
    except ValueError as e:
        res['log'] = str(e)
        return res
    res['warnings'] = warnings
    mod = config['module_name']
    if mutate is not None:
        texts = {}
        for f in files:
            with open(os.path.join(workdir, f), encoding='utf-8') as fh:
                texts[f] = fh.read()
        mutate(texts)
        for f, t in texts.items():
            with open(os.path.join(workdir, f), 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(t)
    env = tool_env()
    srcs = [os.path.join(workdir, f) for f in files] + [os.path.join(workdir, f"{mod}_tb.sv")] + BFMS
    vvp = os.path.join(workdir, 'sim.vvp')
    iverilog = shutil.which('iverilog', path=env['PATH']) or 'iverilog'
    vvp_exe = shutil.which('vvp', path=env['PATH']) or 'vvp'
    comp = subprocess.run([iverilog, '-g2012', '-o', vvp] + srcs, capture_output=True, text=True,
                          env=env, cwd=workdir)
    if comp.returncode != 0:
        res['log'] = comp.stdout + comp.stderr
        res['status'] = 'COMPILE-FAIL'
        return res
    try:
        run = subprocess.run([vvp_exe, vvp], capture_output=True, text=True, env=env, cwd=workdir,
                             timeout=timeout)
    except subprocess.TimeoutExpired:
        res['status'] = 'TIMEOUT'
        return res
    out = run.stdout + run.stderr
    res['log'] = out
    m_chk = re.search(r'\[TB\] Checks:\s+(\d+)', out)
    m_fail = re.search(r'\[TB\] Failed:\s+(\d+)', out)
    if m_chk:
        res['checks'] = int(m_chk.group(1))
    if m_fail:
        res['failed'] = int(m_fail.group(1))
    ok = 'OVERALL RESULT: PASS' in out and res['failed'] == 0 and res['checks'] > 0
    res['status'] = 'PASS' if ok else 'FAIL'
    return res
