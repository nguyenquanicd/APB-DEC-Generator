# Examples

All examples are in this folder. Each one is a folder `ex_<name>/` with the workbook `ex_<name>.xlsx`
(common format: sheets `GUIDELINE` and `APB_DEC`, see `templates/APB_DEC_Template.xlsx`) and the
generated files in `ex_<name>/output/` (decoder `.sv`, `.json`, testbench `_tb.sv`, `filelist.f`).

`make examples` (or `python examples/make_examples.py` and `python examples/run_examples.py`)
rewrites the workbooks and regenerates every `output/` folder. To simulate one example:

```bash
make -C sim/verilator run RTL_DIR=$PWD/examples/ex_reg_in_out/output
```

| Example | Bus | Address Rebase | Register Inputs | Register Outputs | What it shows |
|---|---|---|---|---|---|
| `ex_default` | 24-bit address, 32-bit data | 1 | 0 | 0 | 8 slaves: power-of-two, 24-byte and 6 KB windows, an unaligned ROM table |
| `ex_rebase_off` | 24 / 32 | 0 | 0 | 0 | the same map without rebase: two warnings (CAN and ROMTAB are not aligned) |
| `ex_rebase_off_aligned` | 24 / 32 | 0 | 0 | 0 | every window aligned to its size: no warning, `o_paddr` is the raw low address bits |
| `ex_reg_out` | 16 / 32 | 1 | 0 | 1 | flip-flops on every output, +2 cycles per transfer, ports `i_clk_apb`, `i_rst_n_apb` |
| `ex_reg_in` | 16 / 32 | 1 | 1 | 0 | flip-flops on every input, +2 cycles per transfer |
| `ex_reg_in_out` | 16 / 32 | 1 | 1 | 1 | both, +4 cycles per transfer |
| `ex_byte_bus` | 16 / 8 | 1 | 0 | 0 | 8-bit data bus, 3-byte and 1-byte windows |
| `ex_halfword_bus` | 12 / 16 | 1 | 0 | 0 | 16-bit data bus, odd start and size |
| `ex_full_space` | 8 / 32 | 1 | 0 | 0 | one slave owns the whole space: no unmapped address |
| `ex_wide_bus` | 32 / 32 | 1 | 0 | 0 | windows at the bottom, the middle and the very top of a 32-bit space |

The register options keep the APB protocol correct on the requester bus and on every slave bus; the
generated testbench checks it with an APB protocol checker on every bus and a transaction scoreboard.
