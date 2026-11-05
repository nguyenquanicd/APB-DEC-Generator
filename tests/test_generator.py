"""Unit tests of the two generators (revision 0.2): validation, computed values, warnings, output
files, JSON, mutation tests that prove the generated testbench detects a faulty decoder, and a
simulation of every shipped example.

Run from the repository root:  python -m unittest discover -s tests -v
The simulation tests are skipped when iverilog is not found.
"""
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))
sys.path.insert(0, HERE)

import apb_dec_rtl_generator as rtlgen   # noqa: E402
import apb_dec_tb_generator as tbgen     # noqa: E402
import sim_flow                          # noqa: E402
from xlsx_builder import write_workbook  # noqa: E402

HAVE_IVERILOG = shutil.which('iverilog', path=sim_flow.tool_env()['PATH']) is not None

OK_SLAVES = [('UART', '0x0', '0xFF'), ('I2C', '0x100', '0x117'), ('SPI', '0x1000', '0x1FFF')]


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='apbdec_ut_')
        rtlgen.QUIET = tbgen.QUIET = True

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def xlsx(self, name='t.xlsx', **kw):
        kw.setdefault('slaves', OK_SLAVES)
        return write_workbook(os.path.join(self.tmp, name), **kw)

    def build(self, **kw):
        return rtlgen.build_config(self.xlsx(**kw))

    def assertError(self, text, **kw):
        _, errors, _ = self.build(**kw)
        self.assertTrue(any(text in e for e in errors), f"no error with '{text}' in {errors}")

    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = rtlgen.main(argv)
        return code, out.getvalue()


class TestComputedValues(Base):
    def test_clog2_and_width(self):
        self.assertEqual([rtlgen.clog2(n) for n in (1, 2, 3, 4, 5, 8, 9)], [0, 1, 2, 2, 3, 3, 4])
        cases = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 24: 5, 256: 8, 4096: 12, 6144: 13, 1 << 32: 32}
        for size, width in cases.items():
            self.assertEqual(rtlgen.slave_width(size), width, size)

    def test_window_values_in_config(self):
        cfg, errors, warnings = self.build(slaves=[('I2C', '0x100', '0x117'), ('ONE', '0x200', '0x200')])
        self.assertEqual(errors, [])
        i2c, one = cfg['slaves']
        self.assertEqual((i2c['size_bytes'], i2c['address_width'], i2c['size']), (24, 5, '24 B'))
        self.assertEqual((one['size_bytes'], one['address_width']), (1, 1))
        self.assertEqual(cfg['json_version'], 2)
        self.assertEqual(cfg['write_strobe'], 4)

    def test_size_text(self):
        self.assertEqual(rtlgen._format_size(24), '24 B')
        self.assertEqual(rtlgen._format_size(6144), '6 KB')
        self.assertEqual(rtlgen._format_size(1536), '1.5 KB')
        self.assertEqual(rtlgen._format_size(3 << 20), '3 MB')
        self.assertEqual(rtlgen._format_size(1 << 32), '4 GB')
        self.assertEqual(rtlgen._parse_size_text('1.5 KB'), 1536.0)
        self.assertIsNone(rtlgen._parse_size_text('about 3'))

    def test_formulas_without_cache_are_not_inputs(self):
        cfg, errors, warnings = self.build(formulas=True)
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_write_strobe_row_optional(self):
        cfg, errors, _ = self.build(dw=16, strobe=None)
        self.assertEqual((errors, cfg['write_strobe']), ([], 2))

    def test_rebase_default_is_on(self):
        cfg, errors, _ = rtlgen.extract_config(
            {'APB_DEC': [
                {'name': 'Table - Configuration', 'headers': ['Config', 'Value'],
                 'data': [{'Config': 'Module Name', 'Value': 'm_x'}]},
                {'name': 'Table - Master Configuration', 'headers': ['Config', 'Value'],
                 'data': [{'Config': 'Address Width', 'Value': 8}, {'Config': 'Data Width', 'Value': 32}]},
                {'name': 'Table - Slaves Information',
                 'headers': ['NAME', 'START ADDRESS', 'END ADDRESS'],
                 'data': [{'NAME': 'A', 'START ADDRESS': '0x0', 'END ADDRESS': '0xF'}]}]})
        self.assertEqual((errors, cfg['address_rebase']), ([], 1))


class TestValidation(Base):
    def test_start_greater_than_end(self):
        self.assertError('greater than END', slaves=[('A', '0x20', '0x10')])

    def test_end_outside_master_space(self):
        self.assertError('outside the 8-bit', aw=8, slaves=[('A', '0x0', '0x100')])

    def test_overlap(self):
        self.assertError('overlap', slaves=[('A', '0x0', '0x100'), ('B', '0x80', '0x1FF')])

    def test_overlap_by_one_byte(self):
        self.assertError('overlap', slaves=[('A', '0x0', '0x10'), ('B', '0x10', '0x20')])

    def test_adjacent_windows_are_legal(self):
        _, errors, _ = self.build(slaves=[('A', '0x0', '0x10'), ('B', '0x11', '0x20')])
        self.assertEqual(errors, [])

    def test_bad_names(self):
        self.assertError('not a legal identifier', slaves=[('BAD NAME', '0x0', '0xF')])
        self.assertError('not a legal identifier', slaves=[('1abc', '0x0', '0xF')])
        self.assertError('19 characters', slaves=[('A' * 19, '0x0', '0xF')])
        self.assertError('collides', slaves=[('Uart', '0x0', '0xF'), ('UART', '0x10', '0x1F')])

    def test_name_of_18_characters_is_legal(self):
        _, errors, _ = self.build(slaves=[('A' * 18, '0x0', '0xF')])
        self.assertEqual(errors, [])

    def test_no_slave(self):
        self.assertError('No slave', slaves=[])

    def test_too_many_slaves(self):
        slaves = [(f"S{i}", f"0x{i * 2:X}", f"0x{i * 2 + 1:X}") for i in range(65)]
        self.assertError('limit is 64', aw=16, slaves=slaves)

    def test_exactly_64_slaves_are_legal(self):
        slaves = [(f"S{i}", f"0x{i * 2:X}", f"0x{i * 2 + 1:X}") for i in range(64)]
        _, errors, _ = self.build(aw=16, slaves=slaves)
        self.assertEqual(errors, [])

    def test_bad_hex_and_missing_addresses(self):
        self.assertError('START ADDRESS is missing or not', slaves=[('A', '256', '0x1FF')])
        self.assertError('END ADDRESS is missing or not', slaves=[('A', '0x0', None)])
        self.assertError('START ADDRESS is missing or not', slaves=[('A', None, '0xF')])
        self.assertError('END ADDRESS is missing or not', slaves=[('A', '0x0', '0xZZ')])

    def test_widths_and_strobe(self):
        self.assertError('outside 1 to 32', aw=0)
        self.assertError('outside 1 to 32', aw=33)
        self.assertError('not an integer', aw='abc')
        self.assertError('not one of', dw=12)
        self.assertError('must equal Data Width / 8', dw=32, strobe=2)
        self.assertError('not one of', rebase=2)
        self.assertError('is not an integer', dw=16.5)

    def test_module_name(self):
        self.assertError('must be a legal identifier that starts with m_', module='apbdec')
        self.assertError('must be a legal identifier that starts with m_', module='m_' + 'x' * 29)
        _, errors, _ = self.build(module='m_' + 'x' * 28)
        self.assertEqual(errors, [])

    def test_missing_fields(self):
        parsed = {'APB_DEC': [{'name': 'Table - Slaves Information',
                               'headers': ['NAME', 'START ADDRESS', 'END ADDRESS'],
                               'data': [{'NAME': 'A', 'START ADDRESS': '0x0', 'END ADDRESS': '0xF'}]}]}
        _, errors, _ = rtlgen.extract_config(parsed)
        text = "\n".join(errors)
        for what in ('Module Name is missing', 'Address Width is missing', 'Data Width is missing'):
            self.assertIn(what, text)

    def test_no_slave_table(self):
        _, errors, _ = rtlgen.extract_config({'APB_DEC': []})
        self.assertTrue(any("Slaves Information' block is missing" in e for e in errors))

    def test_sheet_missing(self):
        path = self.xlsx(sheet='Sheet1')
        code, out = self.run_main(['x', path, 'APB_DEC', os.path.join(self.tmp, 'o')])
        self.assertEqual(code, 1)
        self.assertIn("Sheet 'APB_DEC' was not found", out)
        _, errors, _ = rtlgen.extract_config({})
        self.assertTrue(any("No sheet named 'APB_DEC'" in e for e in errors))

    def test_file_missing(self):
        code, out = self.run_main(['x', os.path.join(self.tmp, 'nope.xlsx')])
        self.assertEqual(code, 1)

    def test_old_schema_is_refused(self):
        path = self.xlsx(schema='old', slaves=[('UART', '0x0', '0xFF', 8)])
        config, errors, _ = rtlgen.build_config(path)
        self.assertEqual(len(errors), 1)
        self.assertIn('revision 0.1 columns', errors[0])

    def test_errors_write_no_file(self):
        out = os.path.join(self.tmp, 'o')
        path = self.xlsx(slaves=[('A', '0x20', '0x10')])
        code, text = self.run_main(['x', path, 'APB_DEC', out])
        self.assertEqual(code, 1)
        self.assertIn('No RTL was generated', text)
        self.assertFalse(os.path.exists(out))

    def test_all_problems_are_listed(self):
        path = self.xlsx(aw=8, slaves=[('A B', '0x0', '0xF'), ('C', '0x20', '0x10'), ('D', '0x0', '0x1FF')])
        code, text = self.run_main(['x', path, 'APB_DEC', os.path.join(self.tmp, 'o')])
        self.assertEqual(code, 1)
        self.assertIn('3 problem(s)', text)

    def test_non_integer_cells(self):
        _, errors, _ = self.build(aw=8.0, slaves=[('A', '0x0', '0xF')])
        self.assertEqual(errors, [])
        self.assertError('is not an integer', aw=True)


class TestWarnings(Base):
    def test_rebase_off_with_unaligned_start(self):
        _, errors, warnings = self.build(rebase=0, slaves=[('ROM', '0xE010', '0xE02F')], aw=16)
        self.assertEqual(errors, [])
        self.assertTrue(any('Address Rebase is 0' in w for w in warnings))

    def test_rebase_off_with_aligned_start_is_silent(self):
        _, _, warnings = self.build(rebase=0, slaves=[('ROM', '0xE000', '0xE01F')], aw=16)
        self.assertEqual(warnings, [])

    def test_rebase_on_never_warns_about_alignment(self):
        _, _, warnings = self.build(rebase=1, slaves=[('ROM', '0xE010', '0xE02F')], aw=16)
        self.assertEqual(warnings, [])

    def test_cached_values_that_differ(self):
        _, errors, warnings = self.build(formulas=False, cached={'SIZE': '99 B', 'ADDRESS WIDTH': 3},
                                         slaves=[('A', '0x0', '0xFF')])
        self.assertEqual(errors, [])
        self.assertTrue(any('ADDRESS WIDTH 3 differs' in w for w in warnings))
        self.assertTrue(any("SIZE '99 B' differs" in w for w in warnings))

    def test_cached_values_that_match(self):
        _, _, warnings = self.build(formulas=False, cached={'SIZE': '256 B', 'ADDRESS WIDTH': 8},
                                    slaves=[('A', '0x0', '0xFF')])
        self.assertEqual(warnings, [])

    def test_cached_value_not_understood(self):
        _, _, warnings = self.build(formulas=False, cached={'SIZE': 'big', 'ADDRESS WIDTH': 'wide'},
                                    slaves=[('A', '0x0', '0xFF')])
        self.assertEqual(warnings, [])

    def test_old_pslverr_row_is_ignored_with_a_warning(self):
        _, errors, warnings = self.build(
            extra_master=[('PSLVERR on Unmapped Access', 0, 'obsolete')])
        self.assertEqual(errors, [])
        self.assertTrue(any('i_unmapped_err_en' in w for w in warnings))


class TestOutputs(Base):
    def test_files_json_and_filelist(self):
        out = os.path.join(self.tmp, 'out')
        code, text = self.run_main(['x', self.xlsx(module='m_demo'), 'APB_DEC', out])
        self.assertEqual(code, 0, text)
        for f in ('m_demo.sv', 'm_demo.json', 'filelist.f', '.module_name'):
            self.assertTrue(os.path.isfile(os.path.join(out, f)), f)
        self.assertEqual(sorted(x for x in os.listdir(out) if x.endswith('.sv')), ['m_demo.sv'])
        with open(os.path.join(out, '.module_name')) as fh:
            self.assertEqual(fh.read(), 'm_demo')
        with open(os.path.join(out, 'm_demo.json')) as fh:
            cfg = json.load(fh)
        self.assertEqual(cfg['json_version'], 2)
        self.assertEqual([s['address_width'] for s in cfg['slaves']], [8, 5, 12])
        self.assertEqual(cfg['slaves'][1]['size_bytes'], 24)
        with open(os.path.join(out, 'filelist.f')) as fh:
            lines = fh.read().split()
        self.assertEqual([os.path.basename(x) for x in lines], ['m_demo.sv'])

    def test_rtl_content_rebase_on_and_off(self):
        for rebase in (1, 0):
            out = os.path.join(self.tmp, f'o{rebase}')
            cfg, _, _ = self.build(module='m_demo', rebase=rebase,
                                   slaves=[('A', '0x0', '0xFF'), ('B', '0x100', '0x117')])
            rtlgen.generate_all(cfg, out)
            with open(os.path.join(out, 'm_demo.sv')) as fh:
                rtl = fh.read()
            if rebase:
                self.assertIn('LPARA_B_START[LPARA_B_W-1:0]', rtl)
            else:
                self.assertNotIn('LPARA_B_START[LPARA_B_W', rtl)
                self.assertIn('assign o_paddr_b = i_paddr[LPARA_B_W-1:0];', rtl)
            self.assertNotIn('LPARA_A_START', rtl)               # START = 0: no lower compare
            self.assertIn('LPARA_A_END', rtl)
            self.assertEqual(rtl.count('module '), 1)             # one module, no instance of another

    def test_window_that_is_the_whole_space(self):
        cfg, _, _ = self.build(aw=8, slaves=[('ALL', '0x0', '0xFF')], module='m_all')
        out = os.path.join(self.tmp, 'o')
        rtlgen.generate_all(cfg, out)
        with open(os.path.join(out, 'm_all.sv')) as fh:
            sel = fh.read()
        self.assertIn("assign w_sel = 1'b1;", sel)
        self.assertNotIn('LPARA_ALL_START', sel)
        self.assertNotIn('LPARA_ALL_END', sel)

    def test_covers_whole_space(self):
        cfg, _, _ = self.build(aw=8, slaves=[('A', '0x0', '0x7F'), ('B', '0x80', '0xFF')])
        self.assertTrue(rtlgen.covers_whole_space(cfg))
        cfg, _, _ = self.build(aw=8, slaves=[('A', '0x0', '0x7F'), ('B', '0x81', '0xFF')])
        self.assertFalse(rtlgen.covers_whole_space(cfg))          # gap at 0x80
        cfg, _, _ = self.build(aw=8, slaves=[('A', '0x1', '0xFF')])
        self.assertFalse(rtlgen.covers_whole_space(cfg))          # 0 is free
        cfg, _, _ = self.build(aw=8, slaves=[('A', '0x0', '0xFE')])
        self.assertFalse(rtlgen.covers_whole_space(cfg))          # 0xFF is free

    def test_unreachable_default_is_excluded_from_coverage(self):
        for slaves, expect in (([('ALL', '0x0', '0xFF')], True), ([('A', '0x0', '0xFE')], False)):
            cfg, _, _ = self.build(aw=8, slaves=slaves, module='m_cv')
            out = os.path.join(self.tmp, 'o%d' % expect)
            rtlgen.generate_all(cfg, out)
            with open(os.path.join(out, 'm_cv.sv')) as fh:
                self.assertEqual('verilator coverage_off' in fh.read(), expect)

    def test_window_that_ends_at_the_top(self):
        cfg, _, _ = self.build(aw=8, slaves=[('TOP', '0xF0', '0xFF')], module='m_top')
        out = os.path.join(self.tmp, 'o')
        rtlgen.generate_all(cfg, out)
        with open(os.path.join(out, 'm_top.sv')) as fh:
            sel = fh.read()
        self.assertIn('assign w_sel = (i_paddr >= LPARA_TOP_START[7:0]);', sel)
        self.assertNotIn('LPARA_TOP_END', sel)

    def test_port_names_stay_within_30_characters(self):
        cfg, errors, _ = self.build(module='m_' + 'x' * 28, dw=32,
                                    slaves=[('N' * 18, '0x0', '0xFF')])
        self.assertEqual(errors, [])
        out = os.path.join(self.tmp, 'o')
        rtlgen.generate_all(cfg, out)
        import re
        for f in os.listdir(out):
            if f.endswith('.sv'):
                with open(os.path.join(out, f)) as fh:
                    for ident in set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', fh.read())):
                        self.assertLessEqual(len(ident), 30, f"{ident} in {f}")

    def test_header_fields(self):
        text = rtlgen.generate_header('demo')
        for key in ('Project', 'Author', 'AI Flow', 'AI Flow Page', 'Date', 'Description'):
            self.assertIn(key, text)

    def test_default_arguments_of_main(self):
        """Without arguments the generator reads examples/ex_default and writes the output folder of
        the repository; REPO is pointed at a temporary tree here."""
        old = rtlgen.REPO
        try:
            rtlgen.REPO = self.tmp
            os.makedirs(os.path.join(self.tmp, 'examples', 'ex_default'))
            self.xlsx(os.path.join('examples', 'ex_default', 'ex_default.xlsx'))
            code, _ = self.run_main(['x'])
            self.assertEqual(code, 0)
            self.assertTrue(os.path.isfile(os.path.join(self.tmp, 'output', 'm_vlsit_apbdec.sv')))
            with open(os.path.join(self.tmp, 'output', 'filelist.f')) as fh:
                self.assertEqual(fh.read().split(), ['$APB_DEC_GEN_HOME/output/m_vlsit_apbdec.sv'])
        finally:
            rtlgen.REPO = old

    def test_filelist_dir(self):
        old = rtlgen.REPO
        try:
            rtlgen.REPO = self.tmp
            self.assertEqual(rtlgen.filelist_dir(os.path.join(self.tmp, 'examples', 'x', 'output')),
                             '$APB_DEC_GEN_HOME/examples/x/output')
            self.assertEqual(rtlgen.filelist_dir(self.tmp), '$APB_DEC_GEN_HOME')
            other = tempfile.mkdtemp(prefix='apbdec_other_')
            try:
                self.assertEqual(rtlgen.filelist_dir(other), os.path.abspath(other).replace(os.sep, '/'))
            finally:
                shutil.rmtree(other, ignore_errors=True)
        finally:
            rtlgen.REPO = old

    def test_author_falls_back(self):
        import unittest.mock as mock
        with mock.patch('subprocess.check_output', side_effect=OSError):
            self.assertEqual(rtlgen.get_author(), 'unknown')
            self.assertEqual(tbgen.get_author(), 'unknown')


class TestTbGenerator(Base):
    def make_json(self, **kw):
        cfg, errors, _ = self.build(**kw)
        self.assertEqual(errors, [])
        path = os.path.join(self.tmp, 'cfg.json')
        with open(path, 'w') as fh:
            json.dump(cfg, fh)
        return path, cfg

    def test_find_holes(self):
        slaves = [{'start_val': 0x10, 'end_val': 0x1F}, {'start_val': 0x30, 'end_val': 0x3F}]
        holes, total = tbgen.find_holes(slaves, 8)
        self.assertEqual(total, 0x10 + 0x10 + 0xC0)
        self.assertIn(0, holes)
        self.assertIn(0xFF, holes)
        self.assertIn(0x20, holes)
        self.assertIn(0x2F, holes)

    def test_find_holes_none(self):
        self.assertEqual(tbgen.find_holes([{'start_val': 0, 'end_val': 255}], 8), ([], 0))

    def test_find_holes_is_limited(self):
        slaves = [{'start_val': i * 4 + 1, 'end_val': i * 4 + 2} for i in range(40)]
        holes, _ = tbgen.find_holes(slaves, 10)
        self.assertEqual(len(holes), tbgen.HOLE_SAMPLES_MAX)

    def test_slave_ram(self):
        self.assertEqual(tbgen.slave_ram(0, 8), (32, 0, 32))      # error injection on slave 0
        self.assertEqual(tbgen.slave_ram(0, 13), (1024, 1, None))
        self.assertEqual(tbgen.slave_ram(0, 3), (2, 1, None))
        self.assertEqual(tbgen.slave_ram(1, 8), (64, 1, None))

    def test_tb_main(self):
        path, cfg = self.make_json()
        out = os.path.join(self.tmp, 'tbout')
        os.makedirs(out)
        with open(os.path.join(out, 'filelist.f'), 'w') as fh:
            fh.write('$APB_DEC_GEN_HOME/output/a.sv\n')
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = tbgen.main(['x', path, out])
        self.assertEqual(code, 0)
        with open(os.path.join(out, 'filelist.f')) as fh:
            lines = fh.read().split()
        self.assertTrue(lines[-1].endswith('/m_vlsit_apbdec_tb.sv'))
        with open(os.path.join(out, 'm_vlsit_apbdec_tb.sv')) as fh:
            tb = fh.read()
        self.assertIn('$fatal(1', tb)
        self.assertIn('reference model', tb)
        self.assertIn('i_unmapped_err_en', tb)

    def test_tb_main_errors(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(tbgen.main(['x', os.path.join(self.tmp, 'none.json')]), 1)
            old = os.path.join(self.tmp, 'old.json')
            with open(old, 'w') as fh:
                json.dump({'module_name': 'm_x', 'slaves': [{}]}, fh)
            self.assertEqual(tbgen.main(['x', old, self.tmp]), 1)
            empty = os.path.join(self.tmp, 'empty.json')
            with open(empty, 'w') as fh:
                json.dump({'json_version': 2, 'slaves': []}, fh)
            self.assertEqual(tbgen.main(['x', empty, self.tmp]), 1)

    def test_tb_without_hole_has_a_note(self):
        _, cfg = self.make_json(aw=8, slaves=[('ALL', '0x0', '0xFF')])
        out = os.path.join(self.tmp, 'tb.sv')
        holes, total = tbgen.generate_tb_sv(cfg, out)
        self.assertEqual((holes, total), ([], 0))
        with open(out) as fh:
            self.assertIn('there is no unmapped address', fh.read())

    def test_tb_lane_test_only_for_wide_buses(self):
        for dw, expect in ((8, False), (16, True)):
            _, cfg = self.make_json(dw=dw)
            out = os.path.join(self.tmp, f'tb{dw}.sv')
            tbgen.generate_tb_sv(cfg, out)
            with open(out) as fh:
                self.assertEqual('Byte lanes' in fh.read(), expect)

    def test_tb_rebase_off_expression(self):
        _, cfg = self.make_json(rebase=0)
        out = os.path.join(self.tmp, 'tb.sv')
        tbgen.generate_tb_sv(cfg, out)
        with open(out) as fh:
            tb = fh.read()
        self.assertIn('exp_local = 32\'(a) & 32\'hFF;', tb)


def example_workbooks():
    found = [os.path.join(ROOT, 'templates', 'APB_DEC_Template.xlsx')]
    for dirpath, _, files in os.walk(os.path.join(ROOT, 'examples')):
        found += [os.path.join(dirpath, f) for f in files if f.endswith('.xlsx')]
    return found


class TestExcelStyle(Base):
    """The workbooks are purple, Arial 13, with bold table titles and headers and readable columns."""
    PALETTE = {'4B1D6B', '7030A0', 'E9DDF4', 'F7F2FB', 'FFFFFF'}

    def check_workbook(self, path):
        import openpyxl
        wb = openpyxl.load_workbook(path)
        ws = wb['APB_DEC']
        merged_rows = {rng.min_row for rng in ws.merged_cells.ranges}
        titles = headers = 0
        for row in ws.iter_rows():
            first = row[0].value
            is_title = isinstance(first, str) and first.startswith('Table -')
            is_header = first in ('Config', 'NO.')
            for c in row:
                if c.value is None:
                    continue
                self.assertEqual((c.font.name, c.font.size), ('Arial', 13), f"{path} {c.coordinate}")
                self.assertTrue(c.alignment.wrap_text or is_title, f"{path} {c.coordinate} not wrapped")
                if is_title:
                    self.assertTrue(c.font.bold)
                    self.assertEqual(c.fill.start_color.rgb[-6:], '4B1D6B')
                elif is_header:
                    self.assertTrue(c.font.bold, f"{path} header {c.coordinate} not bold")
                    self.assertEqual(c.fill.start_color.rgb[-6:], '7030A0')
                    self.assertEqual(c.font.color.rgb[-6:], 'FFFFFF')
                self.assertIn(c.fill.start_color.rgb[-6:], self.PALETTE, f"{path} {c.coordinate}")
                # a short value must fit on one line of its column (merged description cells excepted)
                if (c.row not in merged_rows and not is_title and isinstance(c.value, str)
                        and not c.value.startswith('=') and len(c.value) <= 14):
                    width = ws.column_dimensions[c.column_letter].width
                    self.assertGreaterEqual(width, len(c.value) * 1.1, f"{path} {c.coordinate} too narrow")
            if is_title:
                titles += 1
                self.assertGreaterEqual(ws.row_dimensions[row[0].row].height, 30)
            if is_header:
                headers += 1
        self.assertEqual((titles, headers), (3, 3), path)
        # wrapped rows are tall enough for their longest text
        for r, dim in ws.row_dimensions.items():
            self.assertTrue(dim.height is None or dim.height >= 30, f"{path} row {r}")

    def check_guideline(self, path):
        import openpyxl
        wb = openpyxl.load_workbook(path)
        self.assertEqual(wb.sheetnames, ['GUIDELINE', 'APB_DEC'], path)
        ws = wb['GUIDELINE']
        text = " ".join(str(c.value) for row in ws.iter_rows() for c in row if c.value is not None)
        for word in ('Register Inputs', 'Register Outputs', 'Address Rebase', 'START ADDRESS', 'END ADDRESS',
                     'i_unmapped_err_en', 'i_clk_apb', 'Field reference', 'How to use'):
            self.assertIn(word, text, f"{path} GUIDELINE lacks '{word}'")
        bands = headers = 0
        for row in ws.iter_rows():
            for c in row:
                if c.value is None:
                    continue
                self.assertEqual(c.font.name, 'Arial', f"{path} GUIDELINE {c.coordinate}")
                self.assertGreaterEqual(c.font.size, 13)
                if c.fill.start_color.rgb[-6:] == '4B1D6B':
                    bands += 1
                    self.assertTrue(c.font.bold)
                if c.fill.start_color.rgb[-6:] == '7030A0' and c.font.bold:
                    headers += 1
        self.assertGreaterEqual(bands, 5)
        self.assertGreaterEqual(headers, 6)
        for r, dim in ws.row_dimensions.items():
            self.assertTrue(dim.height is None or dim.height >= 30)

    def test_common_format_has_a_guideline_sheet(self):
        for path in example_workbooks():
            self.check_guideline(path)

    def test_shipped_workbooks(self):
        books = example_workbooks()
        self.assertGreaterEqual(len(books), 11)      # the template and ten examples
        for path in books:
            self.check_workbook(path)

    def test_styled_workbook_still_parses(self):
        cfg, errors, _ = self.build(formulas=True)
        self.assertEqual(errors, [])
        self.assertEqual(len(cfg['slaves']), 3)

    def test_unstyled_option(self):
        import openpyxl
        path = self.xlsx('plain.xlsx', style=False)
        ws = openpyxl.load_workbook(path)['APB_DEC']
        self.assertNotEqual(ws['A1'].font.name, 'Arial')


@unittest.skipUnless(HAVE_IVERILOG, 'iverilog not found')
class TestSimulation(Base):
    def test_examples_pass(self):
        examples = []
        for dirpath, _, files in os.walk(os.path.join(ROOT, 'examples')):
            examples += [os.path.join(dirpath, f) for f in files if f.endswith('.xlsx')]
        self.assertGreaterEqual(len(examples), 6)
        for x in examples:
            res = sim_flow.simulate(x, os.path.join(self.tmp, os.path.basename(x) + '_w'))
            self.assertEqual(res['status'], 'PASS', f"{x}\n{res['log'][-800:]}")
            self.assertGreater(res['checks'], 1000)

    def test_rebase_off_aligned_example_is_warning_free(self):
        x = os.path.join(ROOT, 'examples', 'ex_rebase_off_aligned', 'ex_rebase_off_aligned.xlsx')
        cfg, errors, warnings = rtlgen.build_config(x)
        self.assertEqual((errors, warnings, cfg['address_rebase']), ([], [], 0))
        res = sim_flow.simulate(x, os.path.join(self.tmp, 'noreb'))
        self.assertEqual(res['status'], 'PASS', res['log'][-500:])
        with open(os.path.join(self.tmp, 'noreb', 'm_apbdec_noreb.sv')) as fh:
            rtl = fh.read()
        self.assertNotIn(' - ', rtl.split('// Local address of every slave.')[1])   # no subtraction

    def test_failing_decoder_fails_the_testbench(self):
        """Every mutation of the generated RTL must be detected (REQ-VER-001, TEST-013)."""
        slaves = [('FIRST', '0x0', '0x2'), ('MID', '0x800', '0x8FF'), ('LAST', '0xFFD', '0xFFF')]
        xl = self.xlsx(aw=12, dw=32, rebase=1, slaves=slaves, module='m_mut')

        def edit(old, new, fname):
            def f(texts):
                self.assertIn(old, texts[fname], f"mutation anchor missing: {old}")
                texts[fname] = texts[fname].replace(old, new, 1)
            return f

        mutations = {
            'end compare off by one': edit('(i_paddr <= LPARA_MID_END[11:0])', '(i_paddr < LPARA_MID_END[11:0])', 'm_mut.sv'),
            'start compare off by one': edit('(i_paddr >= LPARA_MID_START[11:0])', '(i_paddr > LPARA_MID_START[11:0])', 'm_mut.sv'),
            'rebase subtracts the wrong value': edit('LPARA_MID_START[LPARA_MID_W-1:0];', '8\'h01;', 'm_mut.sv'),
            'pin ignored': edit('w_unmapped ? i_unmapped_err_en : w_pslverr_sel', "w_unmapped ? 1'b1 : w_pslverr_sel", 'm_mut.sv'),
            'pin inverted': edit('w_unmapped ? i_unmapped_err_en : w_pslverr_sel', 'w_unmapped ? ~i_unmapped_err_en : w_pslverr_sel', 'm_mut.sv'),
            'PSLVERR not gated': edit('assign o_pslverr = i_psel & i_penable & w_pready_sel &', 'assign o_pslverr = ', 'm_mut.sv'),
            'unmapped data not zero': edit("w_prdata_sel  = 32'd0;\n      end\n    endcase", "w_prdata_sel  = 32'd1;\n      end\n    endcase", 'm_mut.sv'),
            'unmapped not ready': edit("w_pready_sel  = 1'b1;\n        w_pslverr_sel = 1'b0;\n        w_prdata_sel  = 32'd0;\n      end\n    endcase", "w_pready_sel  = 1'b0;\n        w_pslverr_sel = 1'b0;\n        w_prdata_sel  = 32'd0;\n      end\n    endcase", 'm_mut.sv'),
            'wrong slave response': edit('w_prdata_sel  = i_prdata_mid;', 'w_prdata_sel  = i_prdata_first;', 'm_mut.sv'),
            'PPROT not forwarded': edit('assign o_pprot_mid = i_pprot;', "assign o_pprot_mid = 3'b000;", 'm_mut.sv'),
            'PSTRB not forwarded': edit('assign o_pstrb_last = i_pstrb;', "assign o_pstrb_last = {4{1'b1}};", 'm_mut.sv'),
            'select swapped': edit('assign o_psel_first = w_psel[0];', 'assign o_psel_first = w_psel[1];', 'm_mut.sv'),
            'select not gated by PSEL': edit('assign w_psel = w_sel & {3{i_psel}};', 'assign w_psel = w_sel;', 'm_mut.sv'),
        }
        base = sim_flow.simulate(xl, os.path.join(self.tmp, 'base'))
        self.assertEqual(base['status'], 'PASS', base['log'][-800:])
        for name, mut in mutations.items():
            res = sim_flow.simulate(xl, os.path.join(self.tmp, name.replace(' ', '_')), mutate=mut)
            self.assertEqual(res['status'], 'FAIL', f"mutation '{name}' was not detected")

    def test_rebase_off_mutation(self):
        xl = self.xlsx(aw=12, rebase=0, slaves=[('A', '0x100', '0x1FF')], module='m_mut')
        res = sim_flow.simulate(xl, os.path.join(self.tmp, 'a'))
        self.assertEqual(res['status'], 'PASS')

        def mut(texts):
            texts['m_mut.sv'] = texts['m_mut.sv'].replace(
                'i_paddr[LPARA_A_W-1:0];', 'i_paddr[LPARA_A_W-1:0] + 1\'b1;')
        res = sim_flow.simulate(xl, os.path.join(self.tmp, 'b'), mutate=mut)
        self.assertEqual(res['status'], 'FAIL')

    def test_compile_error_is_reported(self):
        xl = self.xlsx()

        def mut(texts):
            texts['m_vlsit_apbdec.sv'] += '\nthis is not verilog\n'
        res = sim_flow.simulate(xl, os.path.join(self.tmp, 'c'), mutate=mut)
        self.assertEqual(res['status'], 'COMPILE-FAIL')

    def test_invalid_workbook_is_an_error(self):
        res = sim_flow.simulate(self.xlsx(slaves=[('A', '0x5', '0x1')]), os.path.join(self.tmp, 'd'))
        self.assertEqual(res['status'], 'ERROR')


if __name__ == '__main__':
    unittest.main()
