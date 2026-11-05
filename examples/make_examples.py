"""Writes the template and the example workbooks (common format: sheets GUIDELINE and APB_DEC).

Run from anywhere: python examples/make_examples.py
All examples live in this folder: examples/<name>/<name>.xlsx, and their generated files in
examples/<name>/output (python examples/run_examples.py). The template is
templates/APB_DEC_Template.xlsx.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tests'))
sys.path.insert(0, os.path.join(ROOT, 'src'))
from xlsx_builder import write_workbook  # noqa: E402

SHIPPED = [
    ('UART', '0x000000', '0x0000FF', 'UART, 256 B, power of two'),
    ('I2C', '0x000100', '0x000117', 'I2C, 24 B, not a power of two'),
    ('SPI', '0x001000', '0x001FFF', 'SPI, 4 KB'),
    ('CAN', '0x002000', '0x009FFF', 'CAN, 32 KB'),
    ('PWM', '0x00A000', '0x00A0FF', 'PWM, 256 B'),
    ('GYRO', '0x00B000', '0x00B3FF', 'GYRO, 1 KB'),
    ('SRAMCSR', '0x00C000', '0x00D7FF', 'SRAM-like window, 6 KB'),
    ('ROMTAB', '0x00E010', '0x00E02F', 'ROM table, 32 B, start not aligned to its size'),
]

ALIGNED = [
    ('UART', '0x000000', '0x0000FF', '256 B at 0x0000'),
    ('I2C', '0x000100', '0x00011F', '32 B at a multiple of 32'),
    ('SPI', '0x001000', '0x001FFF', '4 KB at a multiple of 4 KB'),
    ('CAN', '0x008000', '0x00FFFF', '32 KB at a multiple of 32 KB'),
    ('PWM', '0x010000', '0x0100FF', '256 B'),
    ('GYRO', '0x011000', '0x0113FF', '1 KB'),
    ('SRAMCSR', '0x014000', '0x015FFF', '8 KB'),
    ('ROMTAB', '0x020000', '0x02001F', '32 B'),
]

SMALL = [
    ('UART', '0x0000', '0x00FF', 'UART, 256 B'),
    ('I2C', '0x0100', '0x0117', 'I2C, 24 B'),
    ('SPI', '0x1000', '0x1FFF', 'SPI, 4 KB'),
]

# name -> (workbook path relative to the repository, write_workbook arguments)
EXAMPLES = {
    'default': ('examples/ex_default/ex_default.xlsx',
                dict(module='m_vlsit_apbdec', aw=24, dw=32, rebase=1, slaves=SHIPPED)),
    'rebase_off': ('examples/ex_rebase_off/ex_rebase_off.xlsx',
                   dict(module='m_vlsit_apbdec_raw', aw=24, dw=32, rebase=0, slaves=SHIPPED)),
    'rebase_off_aligned': ('examples/ex_rebase_off_aligned/ex_rebase_off_aligned.xlsx',
                           dict(module='m_apbdec_noreb', aw=24, dw=32, rebase=0, slaves=ALIGNED)),
    'reg_out': ('examples/ex_reg_out/ex_reg_out.xlsx',
                dict(module='m_apbdec_regout', aw=16, dw=32, rebase=1, slaves=SMALL, reg_in=0, reg_out=1)),
    'reg_in': ('examples/ex_reg_in/ex_reg_in.xlsx',
               dict(module='m_apbdec_regin', aw=16, dw=32, rebase=1, slaves=SMALL, reg_in=1, reg_out=0)),
    'reg_in_out': ('examples/ex_reg_in_out/ex_reg_in_out.xlsx',
                   dict(module='m_apbdec_regio', aw=16, dw=32, rebase=1, slaves=SMALL, reg_in=1, reg_out=1)),
    'byte_bus': ('examples/ex_byte_bus/ex_byte_bus.xlsx',
                 dict(module='m_apbdec_byte', aw=16, dw=8, rebase=1,
                      slaves=[('REGA', '0x0000', '0x0002', 'three bytes'),
                              ('REGB', '0x0003', '0x0003', 'one byte'),
                              ('REGC', '0x0010', '0x001F', '16 bytes'),
                              ('REGD', '0x8000', '0xBFFF', '16 KB')])),
    'halfword_bus': ('examples/ex_halfword_bus/ex_halfword_bus.xlsx',
                     dict(module='m_apbdec_half', aw=12, dw=16, rebase=1,
                          slaves=[('TIMER', '0x010', '0x05F', 'odd start and size'),
                                  ('GPIO', '0x100', '0x1FF', '256 B'),
                                  ('WDOG', '0x300', '0x30B', '12 B')])),
    'full_space': ('examples/ex_full_space/ex_full_space.xlsx',
                   dict(module='m_apbdec_full', aw=8, dw=32, rebase=1,
                        slaves=[('ALL', '0x00', '0xFF', 'one slave owns the whole 8-bit space: no hole')])),
    'wide_bus': ('examples/ex_wide_bus/ex_wide_bus.xlsx',
                 dict(module='m_apbdec_wide', aw=32, dw=32, rebase=1,
                      slaves=[('LOWMEM', '0x00000000', '0x0000FFFF', '64 KB at the bottom'),
                              ('MIDDLE', '0x12345678', '0x123456FF', 'unaligned 136 B'),
                              ('TOPREG', '0xFFFFFF00', '0xFFFFFFFF', 'last 256 bytes of the space')])),
}

TEMPLATE = ('templates/APB_DEC_Template.xlsx',
            dict(module='m_vlsit_apbdec', aw=16, dw=32, rebase=1, slaves=SMALL, reg_in=0, reg_out=0))


def main():
    for rel, kw in [TEMPLATE] + list(EXAMPLES.values()):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_workbook(path, guideline=True, **kw)
        print('wrote', rel)


if __name__ == '__main__':
    main()
