# APB-DEC-Generator

Generates the RTL of an AMBA APB4 address decoder (one requester, up to 64 slaves) and a
self-checking testbench from an Excel workbook. The behavior is specified in
[docs/APB_DEC_Design_Specification.md](docs/APB_DEC_Design_Specification.md) (revision 0.3).

## What the decoder does

- Every slave owns an **arbitrary byte window** `START ADDRESS` .. `END ADDRESS` (both inclusive).
  The size need not be a power of two and the start need not be aligned to the size.
- The width of every slave address port is **computed**: `max(1, clog2(END - START + 1))`. You never
  enter an address width.
- **Address Rebase** (default 1): the slave sees the offset inside its window (`i_paddr - START`);
  with 0 it sees the raw low address bits.
- An address that belongs to no slave is answered by the decoder itself. The input pin
  **`i_unmapped_err_en`** selects the response at run time: `1` = error (`PSLVERR`), `0` = ready only.
- **Register Inputs / Register Outputs** (default 0 / 0): flip-flops on all inputs and/or on all
  outputs of the decoder. The APB protocol stays correct in every combination (the decoder inserts
  wait states for the requester and regenerates the setup and access phases for the slaves). With an
  option on, the decoder has the ports `i_clk_apb` and `i_rst_n_apb`.

| Register Inputs | Register Outputs | Cycles added to a transfer | Ports |
|---|---|---|---|
| 0 | 0 | 0 (combinational) | no clock, no reset |
| 1 | 0 | 2 | `i_clk_apb`, `i_rst_n_apb` |
| 0 | 1 | 2 | `i_clk_apb`, `i_rst_n_apb` |
| 1 | 1 | 4 | `i_clk_apb`, `i_rst_n_apb` |

## Quick start

```bash
pip install openpyxl            # or use `make ...` (uses uv, see the Makefile)
python src/apb_dec_rtl_generator.py templates/APB_DEC_Template.xlsx APB_DEC output
python src/apb_dec_tb_generator.py output/m_vlsit_apbdec.json output
```

Generated files: `<module>.sv` (the whole decoder: **one module in one file**), `<module>.json`
(resolved configuration, `json_version` 2), `<module>_tb.sv`, `filelist.f`, `.module_name`.
Without arguments the generator reads `examples/ex_default/ex_default.xlsx` and writes `output/`.

## The workbook (common format)

Start from [templates/APB_DEC_Template.xlsx](templates/APB_DEC_Template.xlsx). Every workbook has two
sheets: **GUIDELINE** (how to fill it, field reference, rules, the register options) and **APB_DEC**
(the input; the generator reads only this sheet). The format is purple, Arial 13, bold table titles
and headers, with columns and rows sized to read every text.

| Table of `APB_DEC` | Row / column | Meaning |
|---|---|---|
| Configuration | Module Name | `m_` prefix, at most 30 characters |
| Master Configuration | Address Width | 1 to 32 |
| | Data Width | 8, 16 or 32 |
| | Write Strobe | optional, must be Data Width / 8 |
| | Address Rebase | 0 or 1 (default 1) |
| | Register Inputs, Register Outputs | 0 or 1 (default 0) |
| Slaves Information | NAME | legal identifier, at most 18 characters, unique ignoring case |
| | START ADDRESS, END ADDRESS | `0x...` text, inclusive |
| | SIZE, ADDRESS WIDTH | computed (a spreadsheet value that differs only gives a warning) |

Any error (overlap, START > END, window outside the bus, bad name, an option that is not 0 or 1, the
revision 0.1 columns `OFFSET`/`ADDRESS WIDTH`, ...) stops the generator with exit code 1, lists every
problem and writes no file.

## Layout

| Path | Content |
|---|---|
| `src/` | the generators: `apb_dec_rtl_generator.py`, `apb_dec_tb_generator.py` |
| `templates/` | `APB_DEC_Template.xlsx`, the workbook to copy |
| `examples/` | **all examples**, one folder each (workbook + generated files); see `examples/README.md` |
| `sim/lib` | APB master and slave BFMs, the APB protocol checker |
| `sim/vcs`, `sim/verilator`, `lint/` | simulator and lint flows (`RTL_DIR=` selects the folder of an example) |
| `tests/` | unit, mutation, matrix, lint and coverage scripts |
| `docs/` | specification, block diagram, waveforms; `BUG_REPORT_rev0.1.md` is the review of revision 0.1 |
| `output/` | working folder of `make rtl` (not tracked) |

## Verification

| Command | What it does |
|---|---|
| `make test` | unit tests of both generators; mutations of the combinational and of the registered decoder that the testbench must detect; simulation of the template and of every example; workbook format checks |
| `make matrix` | every combination: 12 memory maps x Data Width 8/16/32 x Address Rebase 0/1 x Register Inputs 0/1 x Register Outputs 0/1 (288 simulations, both pin values in each) |
| `python tests/lint_matrix.py` | Verilator `-Wall` and the VLSIT rule check on the RTL of all 288 combinations |
| `make coverage` | line coverage of the generator scripts; Verilator line and toggle coverage of the generated RTL |

The generated testbench holds a reference model of the memory map, a **transaction scoreboard**
(one slave access per mapped transfer, none for a hole, attributes, local address, response, number
of cycles), an **APB protocol checker on the requester bus and on every slave bus**
(`sim/lib/apb_protocol_checker.sv`), directed checks (edges, neighbors, holes with the pin at 1 and at
0, byte lanes), a slave error, slave wait states and random traffic. A failing check ends the run
through `$fatal`.

Needs Icarus Verilog for the simulations; Verilator, MinGW g++ and (Windows) the
`C:\yosyshq\share\verilator` junction for the RTL coverage (see `tests/run_cov.sh`).
