"""Tests of the options Register Inputs and Register Outputs (flip-flops on the inputs and on the
outputs of the decoder): ports, flop placement, protocol correctness in every combination (the
generated testbench contains a scoreboard and an APB protocol checker on every bus), the documented
latency, and mutations of the registered decoder that must be detected.

Run from the repository root:  python -m unittest discover -s tests -v
"""
import json
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))
sys.path.insert(0, HERE)

import apb_dec_rtl_generator as rtlgen   # noqa: E402
import apb_dec_tb_generator as tbgen     # noqa: E402
import sim_flow                          # noqa: E402
from test_generator import Base, HAVE_IVERILOG  # noqa: E402


class TestRegisterOptions(Base):
    SLAVES = [('UART', '0x0', '0xFF'), ('I2C', '0x100', '0x117'), ('SPI', '0x1000', '0x1FFF')]

    def rtl(self, rin, rout, **kw):
        cfg, errors, _ = self.build(module='m_ro', reg_in=rin, reg_out=rout, slaves=self.SLAVES, aw=16, **kw)
        self.assertEqual(errors, [])
        out = os.path.join(self.tmp, f'o{rin}{rout}')
        rtlgen.generate_all(cfg, out)
        with open(os.path.join(out, 'm_ro.sv')) as fh:
            return cfg, fh.read()

    def test_options_are_read(self):
        for rin in (0, 1):
            for rout in (0, 1):
                cfg, _ = self.rtl(rin, rout)
                self.assertEqual((cfg['register_inputs'], cfg['register_outputs']), (rin, rout))

    def test_option_values_are_checked(self):
        self.assertError('Register Inputs 2 is not one of', reg_in=2)
        self.assertError('Register Outputs 5 is not one of', reg_out=5)
        self.assertError('is not an integer', reg_in='yes')

    def test_default_is_combinational(self):
        cfg, errors, _ = self.build()
        self.assertEqual((errors, cfg['register_inputs'], cfg['register_outputs']), ([], 0, 0))

    def test_clock_and_reset_ports_only_with_an_option(self):
        for rin, rout, clocked in ((0, 0, False), (1, 0, True), (0, 1, True), (1, 1, True)):
            _, rtl = self.rtl(rin, rout)
            self.assertEqual('i_clk_apb' in rtl, clocked, (rin, rout))
            self.assertEqual('i_rst_n_apb' in rtl, clocked, (rin, rout))
            self.assertEqual('always_ff' in rtl, clocked, (rin, rout))

    def test_flop_placement(self):
        _, none = self.rtl(0, 0)
        _, rin = self.rtl(1, 0)
        _, rout = self.rtl(0, 1)
        _, both = self.rtl(1, 1)
        self.assertNotIn('reg_', none)
        self.assertIn('reg_req_paddr', rin)
        self.assertIn('reg_prdata_uart', rin)
        self.assertNotIn('reg_psel_uart', rin)
        self.assertIn('reg_psel_uart', rout)
        self.assertIn('reg_o_pready', rout)
        self.assertNotIn('reg_req_paddr', rout)
        self.assertIn('reg_req_paddr', both)
        self.assertIn('reg_o_pready', both)
        self.assertIn('reg_pulse', both)

    def test_slave_pready_pin_is_not_registered(self):
        for rin, rout in ((1, 0), (0, 1), (1, 1)):
            _, rtl = self.rtl(rin, rout)
            self.assertNotIn('reg_pready', rtl)
            self.assertIn('i_pready_uart;', rtl)

    def test_penable_is_gated_with_the_select(self):
        for rin, rout in ((0, 0), (1, 0), (0, 1), (1, 1)):
            _, rtl = self.rtl(rin, rout)
            self.assertNotIn('assign o_penable_uart = i_penable;', rtl)

    def test_json_keeps_the_options(self):
        self.rtl(1, 1)
        with open(os.path.join(self.tmp, 'o11', 'm_ro.json')) as fh:
            data = json.load(fh)
        self.assertEqual((data['register_inputs'], data['register_outputs']), (1, 1))

    def test_names_stay_within_30_characters_with_options(self):
        name = 'm_' + 'x' * 28
        cfg, errors, _ = self.build(module=name, reg_in=1, reg_out=1, slaves=[('N' * 18, '0x0', '0xFF')])
        self.assertEqual(errors, [])
        out = os.path.join(self.tmp, 'long')
        rtlgen.generate_all(cfg, out)
        with open(os.path.join(out, name + '.sv')) as fh:
            for ident in set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', fh.read())):
                self.assertLessEqual(len(ident), 30, ident)

    def test_testbench_expects_the_documented_latency(self):
        for rin, rout, cycles in ((0, 0, 1), (1, 0, 3), (0, 1, 3), (1, 1, 5)):
            cfg, _ = self.rtl(rin, rout)
            out = os.path.join(self.tmp, f'tb{rin}{rout}.sv')
            tbgen.generate_tb_sv(cfg, out)
            with open(out) as fh:
                self.assertIn(f'sb_age == {cycles}', fh.read())

    def test_single_slave_and_one_bit_bus_with_options(self):
        for rin, rout in ((1, 0), (0, 1), (1, 1)):
            cfg, errors, _ = self.build(aw=1, dw=8, reg_in=rin, reg_out=rout,
                                        slaves=[('A', '0x0', '0x0')], module='m_one')
            self.assertEqual(errors, [])
            rtlgen.generate_all(cfg, os.path.join(self.tmp, f'one{rin}{rout}'))


@unittest.skipUnless(HAVE_IVERILOG, 'iverilog not found')
class TestRegisterOptionSimulation(Base):
    SLAVES = [('FIRST', '0x0', '0x2F'), ('MID', '0x800', '0x8FF'), ('LAST', '0xFFD', '0xFFF')]

    def xl(self, rin, rout, **kw):
        kw.setdefault('aw', 12)
        kw.setdefault('dw', 32)
        return self.xlsx(f't{rin}{rout}.xlsx', module='m_mut', slaves=self.SLAVES, reg_in=rin, reg_out=rout, **kw)

    def edit(self, old, new):
        def f(texts):
            self.assertIn(old, texts['m_mut.sv'], f"anchor missing: {old}")
            texts['m_mut.sv'] = texts['m_mut.sv'].replace(old, new, 1)
        return f

    def test_every_combination_passes(self):
        for rin in (0, 1):
            for rout in (0, 1):
                for dw in (8, 32):
                    res = sim_flow.simulate(self.xl(rin, rout, dw=dw), os.path.join(self.tmp, f'p{rin}{rout}{dw}'))
                    self.assertEqual(res['status'], 'PASS', f"in={rin} out={rout} dw={dw}\n{res['log'][-600:]}")
                    self.assertIn('Transactions', res['log'])

    def test_faults_of_the_registered_decoder_are_detected(self):
        e = self.edit
        mutations = {
            'slave PSEL held one cycle too long': e('assign w_bus_nxt = w_trigger | w_acc_nxt;',
                                                    'assign w_bus_nxt = w_trigger | w_acc_nxt | reg_acc;'),
            'response pulse not aligned with the data': e('assign w_pulse = reg_pulse;', 'assign w_pulse = w_done;'),
            'PSLVERR without PREADY': e('reg_o_pslverr <= w_pulse & w_rerr;', 'reg_o_pslverr <= w_rerr;'),
            'requester sees PREADY one cycle early': e('reg_o_pready  <= w_pulse;', 'reg_o_pready  <= w_done;'),
            'setup phase skipped': e('reg_setup <= w_trigger;', "reg_setup <= 1'b0;"),
            'the access phase never ends': e('reg_acc   <= reg_setup | (reg_acc & ~w_slv_ready);',
                                             'reg_acc   <= reg_setup | reg_acc;'),
            'write data not forwarded': e('reg_pwdata_mid  <= w_req_pwdata;', "reg_pwdata_mid  <= 32'd0;"),
            'read data lost in the input stage': e('reg_prdata_mid <= i_prdata_mid;', "reg_prdata_mid <= 32'd0;"),
        }
        xl = self.xl(1, 1)
        base = sim_flow.simulate(xl, os.path.join(self.tmp, 'base'))
        self.assertEqual(base['status'], 'PASS', base['log'][-600:])
        for name, mut in mutations.items():
            res = sim_flow.simulate(xl, os.path.join(self.tmp, name.replace(' ', '_')), mutate=mut)
            self.assertEqual(res['status'], 'FAIL', f"mutation '{name}' was not detected")

    def test_input_only_and_output_only_faults(self):
        res = sim_flow.simulate(self.xl(1, 0), os.path.join(self.tmp, 'in'),
                                mutate=self.edit('reg_pslverr_first <= i_pslverr_first;', "reg_pslverr_first <= 1'b0;"))
        self.assertEqual(res['status'], 'FAIL')
        res = sim_flow.simulate(self.xl(0, 1), os.path.join(self.tmp, 'out'),
                                mutate=self.edit('reg_pstrb_mid   <= w_req_pstrb;', "reg_pstrb_mid   <= 4'd0;"))
        self.assertEqual(res['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
