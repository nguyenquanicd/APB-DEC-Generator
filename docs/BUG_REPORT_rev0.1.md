# Bug Report — APB-DEC-Generator

> **Revision 0.2 note (2026-11-05).** The fix of finding 4 below generated `(i_paddr - OFFSET)[W-1:0]`, a
> part-select of an expression, which is illegal SystemVerilog (Verilator and iverilog stop with a syntax
> error); it was never compiled. Revision 0.2 replaces the whole slave table (START/END windows, computed
> widths, pin-selected unmapped response; see `docs/APB_DEC_Design_Specification.md`), generates the local
> address with a legal expression, and checks every generated decoder by simulation and lint
> (`tests/`). The findings below describe revision 0.1.

## Fix status (update)

All 12 findings below, plus one additional issue found while implementing the
fixes (PSTRB hardcoded to `[3:0]` in both simulation BFMs regardless of the
configured Write Strobe), have been fixed in this working tree. Every fix was
verified by actually re-running the affected script(s), not just re-read —
see the commit/diff for exact changes. Summary:

| # | Status | Fixed by |
|---|---|---|
| 1 | **Fixed** | `apb_dec_rtl_generator.py`: `parse_excel`/`main` now require the `APB_DEC` sheet to exist and validate every required field before generating anything; missing/invalid config is a hard error (exit 1), never a silent default. |
| 2 | **Fixed** | `apb_dec_rtl_generator.py`: `extract_config` computes `end_address`/`size` from `OFFSET + 2^ADDRESS_WIDTH-1` in Python; a mismatching cached Excel formula is now only a warning, never the source of truth. |
| 3 | **Fixed** | Every `open(..., 'w')` in both generator scripts now passes `encoding='utf-8'`; the ✓/✗ characters in `$display` strings were also replaced with plain ASCII for portability. |
| 4 | **Fixed (configurable)** | `generate_sv` emits `o_paddr_<slave> = (i_paddr - OFFSET)[width-1:0]` by default. Made configurable via a new **"Address Rebase"** option (Master Configuration table, default 1) after discussion: some system architectures perform base-address translation for a slave upstream of this decoder already, and doing it a second time here would be wrong for them. Setting it to 0 restores the original `o_paddr_<slave> = i_paddr[width-1:0]` truncation. `o_psel_<slave>` (block selection) is unaffected either way -- it always decodes the full, un-rebased `i_paddr` against `[OFFSET, END]`. See "New feature" section below. |
| 5 | **Fixed** | `extract_config` now rejects a slave whose range exceeds the master's address width, and rejects any two overlapping slave ranges. |
| 6 | **Fixed** | `apb_slave_bfm.sv`: new `PARA_MEM_WORDS` parameter separates "implemented depth" from "port width" so the out-of-range check is reachable; default preserves prior behaviour. |
| 7 | **Fixed** | `apb_dec_tb_generator.py`: `PSLVERR_VAL = 1'b{value}` (value in the bit position). |
| 8 | **Fixed** | `$dumpvars`/`$fsdbDumpvars` use the real `{module_name}_tb`; the RTL generator now writes `output/.module_name`, which the Makefile and both lint scripts read back automatically. |
| 9 | **Fixed** | `sim/vcs/Makefile` and `sim/verilator/Makefile` rewritten: stale header removed, `TB_LOCAL`/`OBJ_DIR`/`TEST_DIR` no longer dangle undefined. |
| 10 | **Fixed** | `extract_config` validates every slave `NAME` as a legal, case-insensitively-unique SV identifier. |
| 11 | **Fixed** | Replaced with a helper (`_cell`) that treats "key absent" and "key present but blank" the same way. |
| 12 | **Fixed** | `apb_dec_tb_generator.py`: new `find_unmapped_address()` picks a genuinely unmapped address (preferring the gap right after the last slave) instead of a hardcoded `0xFFFF`. |
| bonus | **Fixed** | Both `sim/lib/*.sv` BFMs gained a `PARA_STRB_WIDTH` parameter (default `PARA_DATA_WIDTH/8`); the slave BFM's byte-lane write loop was generalized from a hardcoded 4 lanes to `PARA_STRB_WIDTH` lanes; `apb_dec_tb_generator.py` now wires `.PARA_STRB_WIDTH(write_strobe)` on both BFM instantiations. |

`output/m_vlsit_apbdec.{sv,json}` and `output/m_vlsit_apbdec_tb.sv` (the
shipped example's checked-in output) have been regenerated with the fixed
scripts so the repository doesn't ship stale, pre-fix artifacts.

No SystemVerilog compiler was available on this machine to do a real
compile/lint pass (see `BUG_REPORT.md`'s own note on this); verification
instead re-ran both generator scripts against the shipped example **and**
an independent 18-bit/14-slave real-world config, and specifically
re-reproduced every scenario that previously crashed or silently
misbehaved, confirming each now fails loudly with a clear message (for
genuine input errors) or produces correct output (for the address-map /
waveform-name / literal-syntax bugs).

## New feature: "Address Rebase" option

Added after a design discussion about Finding #4: `psel` (block select) and
`paddr` (in-block register address) are decoded independently, so a
correctly-asserted `psel` says nothing about whether `paddr` is a correct
*local* address for the peripheral. Whether the peripheral needs a local
(base-relative) address at all depends on the system architecture:

- If the peripheral IP itself decodes its registers starting at address 0
  (the normal case for reusable/relocatable IP, and the case this
  decoder's own default assumes), the base address **must** be subtracted
  somewhere -- Finding #4's fix does that here.
- If another stage upstream of this decoder (e.g. a bridge) already performs
  that translation before `i_paddr` reaches this module, subtracting again
  here would double-translate the address and break it.

Rather than picking one behaviour and hardcoding it, this is now a Master
Configuration option:

| Config | Values | Default | Effect |
|---|---|---|---|
| `Address Rebase` | 0 / 1 | 1 | 1: `o_paddr_<slave> = (i_paddr - OFFSET)[width-1:0]`. 0: `o_paddr_<slave> = i_paddr[width-1:0]` (no subtraction -- the tool's original, pre-fix behaviour, for use only when base-address translation for this slave already happens upstream of this decoder). |

Added to `APB_DEC_Example.xlsx` (row 12 of `Table - Master Configuration`)
and to both generator scripts. Verified both settings end-to-end: with the
default (`=1`), `o_paddr_can = (i_paddr - 24'h2000)[14:0]`; with `=0`,
`o_paddr_can = i_paddr[14:0]` (identical to the original tool). `o_psel_*`
is byte-for-byte identical in both RTL outputs, confirming the option only
changes register-local addressing, never block selection.

---

## Original findings (diagnostic detail, kept for reference)

**Repository reviewed:** `C:\HQuan\102_MyGithub\APB-DEC-Generator` (local clone of
`nguyenquanicd/APB-DEC-Generator`, branch `master`, commit `90bd54d` "Always compare
both start and end address. Change && to &")

**Scope:** `apb_dec_rtl_generator.py`, `apb_dec_tb_generator.py`, `sim/lib/*.sv`,
`lint/*`, `Makefile`, `sim/*/Makefile`, `APB_DEC_Example.xlsx`.

**Method:** static read of every file, plus live reproduction of the most important
findings by actually running the two generator scripts (via `python3.14` + `openpyxl`)
against the shipped example and against an independent 14-slave/18-bit real-world
config, on this machine (Windows, default cp1252 locale). Findings below are marked
**Confirmed (reproduced)** or **Confirmed (static)** accordingly — none are guesses.

---

## Summary table

| # | Severity | Area | One-line summary |
|---|---|---|---|
| 1 | High | `apb_dec_rtl_generator.py` | Wrong/missing sheet name silently yields a degenerate, non-compiling 0-slave module — exit code 0, no warning |
| 2 | High | `APB_DEC_Example.xlsx` + `apb_dec_rtl_generator.py` | SIZE/END ADDRESS/Max Address are **live Excel formulas**; the parser only trusts the last cached value (`data_only=True`) and never recomputes them — any non-Excel resave silently corrupts or crashes generation |
| 3 | High | `apb_dec_tb_generator.py` | Crashes with `UnicodeEncodeError` on stock Windows Python — the generated testbench text contains ✓/✗ and `open()` has no explicit encoding |
| 4 | High | `apb_dec_rtl_generator.py` (`generate_sv`) | `o_paddr_<slave>` is a raw bit-truncation of `i_paddr`, **not** `i_paddr − OFFSET`; wrong for any slave whose OFFSET isn't aligned to `2^ADDRESS_WIDTH` — reproducible with the tool's *own* shipped example (`CAN`) |
| 5 | Medium | `apb_dec_rtl_generator.py` | No validation that `END_ADDRESS − OFFSET + 1 ≤ 2^ADDRESS_WIDTH` → silent address aliasing at the slave port on a typo |
| 6 | Medium | `sim/lib/apb_slave_bfm.sv` | The BFM's own out-of-range/`PSLVERR` check is dead code — mathematically always false — so it can never catch the class of bug in #4/#5 during simulation |
| 7 | Medium | `apb_dec_tb_generator.py` | `PSLVERR_VAL = {pslverr_on_unmapped}'b1` swaps *value* and *width*; produces the illegal literal `0'b1` whenever a user sets the documented option `PSLVERR on Unmapped Access = 0` |
| 8 | Medium | `apb_dec_tb_generator.py`, `lint/*`, root `Makefile` | Module name `m_vlsit_apbdec` is hardcoded in `$dumpvars`/`$fsdbDumpvars`, both lint scripts' top-module, and the Makefile's `tb` target — none of it follows a renamed module |
| 9 | Low | `sim/vcs/Makefile`, `sim/verilator/Makefile` | Leftover template artifacts: stale header comments from an unrelated project, and undefined make variables (`TB_LOCAL`, `OBJ_DIR`, `TEST_DIR`) — as shipped, neither Makefile can build a runnable sim |
| 10 | Low | `apb_dec_rtl_generator.py` | Slave `NAME` is never sanitized into a legal/unique SV identifier (spaces, case-collisions) |
| 11 | Low | `apb_dec_rtl_generator.py` (`extract_config`) | `row.get('OFFSET', '0x0000')`-style fallbacks never trigger (root cause feeding #2/#3's crash mode) — inconsistent with the correct `if/else` pattern used for `ADDRESS WIDTH` |
| 12 | Low | `apb_dec_tb_generator.py` | Auto-generated "unmapped address" test hardcodes `0xFFFF`; for any address map extending past `0xFFFF` this can land **inside** a real slave, turning a self-check into a false failure — reproduced with an 18-bit config |

---

## Finding 1 — Wrong/missing sheet name silently produces a garbage, non-compiling module

**Severity: High — Confirmed (reproduced)**
**File:** `apb_dec_rtl_generator.py:49-104` (`parse_excel`), `:107-150` (`extract_config`)

`main()` calls `parse_excel(excel_path, sheet_name=None)`. With no `sheet_name`,
`parse_excel` reads **only the first sheet by position** (`sheet_names =
[wb.sheetnames[0]]`, line 57) and returns `{ <that sheet's real name>: [...tables] }`.
`extract_config` then does `parsed_data.get('APB_DEC', [])` (line 118) — a hardcoded
literal key. **If the first sheet isn't literally named `APB_DEC`, this lookup
silently returns `[]`**, and every config field falls back to its default
(`module_name=None → 'apb_decoder'`, `address_width=None → 16`, 0 slaves) with
**zero warning and exit code 0**.

Reproduced by renaming the shipped example's sheet from `APB_DEC` to `Sheet1` and
running unmodified:

```
[2/3] Extracting configuration...
  Module Name:     None
  Address Width:   None
  Data Width:      None
  Write Strobe:    None
  Number of Slaves: 0
...
Generated: repro_out_F\None.json
Generated: repro_out_F\None.sv
RTL Generation complete!
```

The output files are literally named `None.json` / `None.sv`. Worse, the degenerate
`.sv` itself is **not valid SystemVerilog**:

```systemverilog
module apb_decoder (
  ...
  output logic [31:0]   o_prdata,

  // APB Slave Interfaces
);                                    // <-- dangling comma before this line (illegal)
  ...
  always_comb begin
    casez ({
    })                                // <-- empty concatenation (illegal)
```

Root cause of the dangling comma: `sv.rstrip(',\n')` (line 217) only strips
characters from the *very end* of the accumulated string; when the slave loop
contributes nothing (0 slaves), the trailing `,` after `o_prdata,` is followed by a
comment and is never reached by `rstrip`.

**Suggested fix:** validate the sheet name / table presence explicitly and `sys.exit(1)`
with a clear message if `module_name`, `address_width`, `data_width` or the slave list
come back empty; never let a config with 0 slaves reach `generate_sv` unchanged.

---

## Finding 2 — SIZE / END ADDRESS / Max Address are Excel formulas the parser never recomputes

**Severity: High — Confirmed (reproduced + root-caused)**
**File:** `APB_DEC_Example.xlsx` cells `B8`, `E16:E21`, `F16:F21`; `apb_dec_rtl_generator.py:51`

Inspecting the shipped template with `data_only=False` shows the "auto-calculated"
columns are **live formulas**, e.g.:

```
B8  = "0x" & DEC2HEX(2^$B$7-1)
F16 = "0x" & DEC2HEX(HEX2DEC(SUBSTITUTE(D16,"0x",""))+2^C16-1, $B$7/4)
```

But `parse_excel` loads with `openpyxl.load_workbook(excel_path, data_only=True)`
(line 51) — this reads **only whatever value Excel last cached** for those cells. It
is never recomputed by the Python side. Any tool in the chain that is not real Excel
(`openpyxl`-based automation, LibreOffice headless conversion, a CI regeneration
step, some git diff/merge tools) can save the file **without** recalculating,
either dropping the cached value (→ `None`) or leaving a **stale** one after
`OFFSET`/`ADDRESS WIDTH` was edited.

Reproduced concretely: opening the shipped example with `openpyxl`, making one
trivial edit, and re-saving (a completely ordinary automation step) causes every
`END ADDRESS` in the file to read back as `None`, and the generator crashes:

```
TypeError: 'NoneType' object is not subscriptable
  ...generate_sv... i_paddr <= {addr_width}'h{end_addr[2:]}
```

The **silent** variant (stale-but-present cached value after an edit) is strictly
worse: the generator would produce a fully "successful", compilable decoder with a
**wrong address map** and no indication anything is off.

**Suggested fix:** compute `end_address` (and `size`) in Python from `OFFSET` +
`ADDRESS WIDTH` instead of trusting a cached spreadsheet formula; keep the Excel
formulas only as a human-readable convenience/cross-check, not as the source of
truth the generator consumes.

---

## Finding 3 — `apb_dec_tb_generator.py` crashes on Windows due to Unicode in `$display` strings

**Severity: High — Confirmed (reproduced on this machine)**
**File:** `apb_dec_tb_generator.py:504-506`

```python
with open(output_path, 'w') as f:
    f.write(tb)
```

No `encoding=` is given. The generated `tb` string embeds `✓` (U+2713) / `✗`
(U+2717) inside `$display(...)` calls (e.g. line 287, 313, 332...). On a Windows
Python process whose default text encoding is `cp1252` (the common case — this is
the exact environment used for this review), the write raises:

```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2713' in position 21161
```

Reproduced end-to-end against an independent 18-bit/14-slave config using this
repo's own two scripts: `apb_dec_rtl_generator.py` succeeds, `apb_dec_tb_generator.py`
**crashes**, leaving a **0-byte** `_tb.sv` file behind (the file is created by `open()`
before the crash, so the failure is easy to miss in a script that doesn't check exit
codes).

**Suggested fix:** `open(output_path, 'w', encoding='utf-8')` (do this in both
generator scripts, and in `generate_json`/`generate_sv` too, for the same reason —
the RTL header/description strings are user-supplied and could contain non-ASCII).

---

## Finding 4 — Forwarded slave address is a truncation, not a subtraction — wrong for unaligned OFFSETs

**Severity: High — Confirmed (static, demonstrated on the shipped example itself)**
**File:** `apb_dec_rtl_generator.py:288`

```python
sv += f'''...
  assign o_paddr_{slave_lower}   = i_paddr[{slave_addr_width-1}:0];
```

The local address handed to every slave is simply the low `ADDRESS_WIDTH` bits of
`i_paddr` — **never `i_paddr − OFFSET`**. This is only correct when `OFFSET` is an
exact multiple of `2^ADDRESS_WIDTH` (i.e. the slave's window is naturally aligned).

The tool's **own shipped example already violates this**: slave `CAN` has
`OFFSET = 0x2000`, `ADDRESS WIDTH = 15` (`2^15 = 0x8000`). `0x2000` is **not** a
multiple of `0x8000`. Walking the generated RTL
(`output/m_vlsit_apbdec.sv:107`, `:...`):

```systemverilog
assign w_slave_can_sel = (i_paddr >= 24'h2000 & i_paddr <= 24'h009FFF);
...
assign o_paddr_can   = i_paddr[14:0];
```

For `i_paddr = 24'h2005` (5 bytes into CAN's region), `w_slave_can_sel` correctly
fires, but `o_paddr_can = i_paddr[14:0] = 15'h2005` — **not** `15'h0005`
(`0x2005 − 0x2000`) as the CAN peripheral should see. Every register inside CAN is
addressed 0x2000 higher than intended; only the bottom `0x2000` bytes of CAN's own
address space are ever reachable, and they are reached from **system address
`0x2000+0x2000=0x4000`**, which the decoder maps to a *different* slave (`PWM`/`GYRO`
depending on the exact map) — i.e. two different slave-select regions collide inside
the CAN instance's own visible register space.

This is silent: nothing detects or flags it (see also Finding 6 — the simulation
BFM that should catch this is dead code).

**Suggested fix:** `assign o_paddr_{slave_lower} = i_paddr - {addr_width}'h{offset[2:]};`
(truncated/sliced to `slave_addr_width` afterward), or require/validate that every
`OFFSET` is a multiple of its own `2^ADDRESS_WIDTH` and reject the config otherwise.

---

## Finding 5 — No check that a slave's mapped range fits inside `2^ADDRESS_WIDTH`

**Severity: Medium — Confirmed (static)**
**File:** `apb_dec_rtl_generator.py:107-150` (`extract_config`)

`ADDRESS WIDTH` (used for `o_paddr_<slave>` sizing) and `OFFSET`/`END ADDRESS` (used
for the `w_slave_<x>_sel` compare) are read independently, with **no cross-check**
that `END_ADDRESS − OFFSET + 1 ≤ 2^ADDRESS_WIDTH`. Combined with Finding 4, a
too-small `ADDRESS WIDTH` for a given `[OFFSET, END_ADDRESS]` silently aliases
multiple distinct system addresses onto the same local address inside the slave,
with no error, warning, or lint check anywhere in the flow.

**Suggested fix:** assert this inequality in `extract_config` (or a dedicated
validation pass) and abort with a clear message naming the offending slave.

---

## Finding 6 — `apb_slave_bfm`'s own PSLVERR/out-of-range check is dead code

**Severity: Medium — Confirmed (static, derivable from the RTL alone)**
**File:** `sim/lib/apb_slave_bfm.sv:28-51`

```systemverilog
localparam integer PARA_MEM_DEPTH   = (2 ** PARA_ADDR_WIDTH);
...
localparam logic [PARA_ADDR_WIDTH:0] PARA_MEM_DEPTH_U = {1'b1, {PARA_ADDR_WIDTH{1'b0}}};
assign apb_req_word_addr  = (apb_req_addr >> 2);
assign apb_addr_in_range  = ({1'b0, apb_req_word_addr} < PARA_MEM_DEPTH_U);
...
o_pslverr <= ~apb_addr_in_range;
```

`apb_req_addr` is declared `[PARA_ADDR_WIDTH-1:0]`, so its maximum value is
`2**PARA_ADDR_WIDTH − 1`. Right-shifting by 2 (`apb_req_word_addr`) can only
*decrease* the value, so `apb_req_word_addr ≤ 2**PARA_ADDR_WIDTH − 1 <
PARA_MEM_DEPTH_U (= 2**PARA_ADDR_WIDTH)` **for every possible input**. `apb_addr_in_range`
is therefore always `1`, and `o_pslverr` out of this BFM is architecturally
**always `0`**, regardless of the actual address driven. The module's own header
comment ("Returns 0 and asserts PSLVERR on out-of-range accesses") is describing
behavior the RTL cannot exhibit.

Consequence: the auto-generated testbench's self-checks rely on this BFM as the
"real peripheral" behind each slave port; it can never surface an address-routing
bug at the slave boundary (e.g. Finding 4/5) via simulation, giving false confidence
that a passing regression proves the address map is correctly wired end-to-end.

Secondary, related observation: the declared `dmem` array (`2**PARA_ADDR_WIDTH`
entries) is 4× larger than needed, since only word-addresses up to
`2**PARA_ADDR_WIDTH/4 − 1` are ever indexed (75% of the array is dead storage) —
harmless for small per-slave widths, but wasteful and a sign the `>>2`
word-addressing was not accounted for when `PARA_MEM_DEPTH` was sized.

**Suggested fix:** size `PARA_MEM_DEPTH` off the *word* address width
(`PARA_ADDR_WIDTH-2`, guarding `PARA_ADDR_WIDTH ≥ 2`) and compare
`apb_req_word_addr` against that, so an actually-out-of-range access is reachable.

---

## Finding 7 — `PSLVERR_VAL` literal swaps *value* and *width*; illegal for the documented `= 0` case

**Severity: Medium — Confirmed (reproduced expression, static SV rule)**
**File:** `apb_dec_tb_generator.py:235`

```python
localparam logic PSLVERR_VAL = {pslverr_on_unmapped}'b1;
```

`pslverr_on_unmapped` (0 or 1, per the tool's own documented "PSLVERR on Unmapped
Access" config field) is substituted where a **literal size** belongs, with the
**value** hardcoded to `1`. For the shipped example (`= 1`) this happens to produce
the coincidentally-legal `1'b1`. Evaluating the same template line for the *other*
documented value:

```
pslverr_on_unmapped = 0  →  "localparam logic PSLVERR_VAL = 0'b1;"
```

`0'b1` is a **sized literal with size 0**, illegal per IEEE 1800-2017 §5.7.1 (size
must be `> 0`). Any project that legitimately configures "OKAY on unmapped access"
(`PSLVERR on Unmapped Access = 0`) gets a testbench that **fails to compile**.

**Suggested fix:** `localparam logic PSLVERR_VAL = 1'b{pslverr_on_unmapped};`
(matching the convention already used correctly elsewhere in
`apb_dec_rtl_generator.py`, e.g. `o_pslverr = 1'b{pslverr_on_unmapped};`).

---

## Finding 8 — Module name hardcoded as `m_vlsit_apbdec` in multiple places outside the generator

**Severity: Medium — Confirmed (static)**
**Files:**
- `apb_dec_tb_generator.py:225,228` — `$fsdbDumpvars(0, m_vlsit_apbdec_tb, ...)` /
  `$dumpvars(0, m_vlsit_apbdec_tb);` are **literal text inside the f-string**, not
  `{module_name}_tb`. Confirmed against the committed
  `output/m_vlsit_apbdec_tb.sv:337,340` — both lines hardcode the example's name.
  Any config with a different `Module Name` gets a waveform-dump call pointing at a
  scope that doesn't exist.
- `lint/verilator/run_lint.sh:5` — `--top-module m_vlsit_apbdec`
- `lint/vc_static/run_lint.tcl:8` — `set TOP_DESIGN m_vlsit_apbdec`
- `Makefile:13` — `MODULE_NAME := m_vlsit_apbdec` (default), used by the `tb` target
  (`Makefile:24`) to locate `$(OUTPUT_DIR)/$(MODULE_NAME).json`. Overriding only
  `EXCEL=` on the command line (as the Makefile's own `help` target recommends,
  `Makefile:41`) does **not** update `MODULE_NAME`, so `make tb`/lint silently
  operate on the wrong/nonexistent JSON/top-module unless the user *also*
  separately passes `MODULE_NAME=<name>`, undocumented in `help`.

**Suggested fix:** parameterize `$dumpvars`/`$fsdbDumpvars` from `module_name`
(one-line fix); have the root `Makefile`'s `rtl` target write the resolved module
name to a small generated file (e.g. `output/.module_name`) that `tb`/lint targets
`include`/read, instead of a static default that must be kept in sync by hand.

---

## Finding 9 — `sim/vcs/Makefile` and `sim/verilator/Makefile` are unfinished template leftovers

**Severity: Low — Confirmed (static)**
**Files:** `sim/vcs/Makefile:1-2`, `sim/verilator/Makefile:1`

Both files open with a header comment copy-pasted from an unrelated project:

```makefile
# Makefile for RISC-V RV32I Single-Cycle CPU Testbench and Reference Model
```

Both reference `$(TB_LOCAL)` (`sim/vcs/Makefile:16`, `sim/verilator/Makefile:15`) and
`$(TEST_DIR)` (`sim/vcs/Makefile:48`, `sim/verilator/Makefile:40`) — neither variable
is ever defined anywhere in this repository. `sim/verilator/Makefile:22` also passes
`--Mdir $(OBJ_DIR)` with `OBJ_DIR` likewise undefined. As shipped, `make -C sim/vcs`
/ `make -C sim/verilator` builds with an empty `TB_LOCAL`, i.e. **no testbench
top-level is ever added to the compile**, and `verilator --Mdir` with an empty
argument is likely to misbehave.

**Suggested fix:** finish adapting these two Makefiles to this project (define
`TB_LOCAL := $(RTL_DIR)/$(MODULE_NAME)_tb.sv`, `OBJ_DIR := obj_dir`, drop the stale
header, drop the dangling `TEST_DIR` clean rules) or remove them until they're ready.

---

## Finding 10 — Slave `NAME` is never sanitized into a legal/unique identifier

**Severity: Low — Confirmed (static)**
**File:** `apb_dec_rtl_generator.py:201` (`slave_lower = slave['name'].lower()`), used
throughout for every generated signal/port name.

Nothing rejects or escapes a `NAME` containing spaces or other characters illegal in
a SystemVerilog identifier (e.g. `"SPI Wrapper"` → `o_paddr_spi wrapper`, a syntax
error), and nothing detects a case-insensitive collision (`"UART"` and `"uart"` as
two different rows both lower to `uart`, producing duplicate port/signal
declarations — a compile error with a confusing "already declared" message far from
the actual (spreadsheet) root cause).

**Suggested fix:** validate `NAME` against `^[A-Za-z_][A-Za-z0-9_]*$` and check
uniqueness (case-insensitive) at parse time, aborting with the offending row number.

---

## Finding 11 — `.get(key, default)` fallbacks never actually fire

**Severity: Low — Confirmed (static; this is the mechanism behind Finding 1/2's crash)**
**File:** `apb_dec_rtl_generator.py:142-145`

```python
'offset': row.get('OFFSET', '0x0000'),
'size': row.get('SIZE', ''),
'end_address': row.get('END ADDRESS', ''),
```

`parse_excel`'s row-building loop (lines 92-95) inserts `row_dict[header] = cell` for
**every** header column present, *including when `cell is None`*. `dict.get(key,
default)` only returns `default` when `key` is **absent**, not when its value is
`None`. So a blank `OFFSET`/`SIZE`/`END ADDRESS` cell always yields `None`, never the
written-down fallback — silently defeating the developer's own intent. Contrast with
`ADDRESS WIDTH`, two lines above, correctly written as
`int(row['ADDRESS WIDTH']) if row.get('ADDRESS WIDTH') else 0` (a truthy check, not
`.get(...,default)`), which *does* fall back as intended.

**Suggested fix:** `row.get('OFFSET') or '0x0000'` (or an explicit `if/else`,
matching the `ADDRESS WIDTH` pattern already in the same function).

---

## Finding 12 — Hardcoded "unmapped" test address (`0xFFFF`) can land inside a real slave

**Severity: Low/Medium — Confirmed (reproduced with an 18-bit config)**
**File:** `apb_dec_tb_generator.py:401` (and the `24'hFFFF` instance in the
already-committed `output/m_vlsit_apbdec_tb.sv:639`)

```python
u_master_bfm.read({addr_width}'hFFFF, v_rdata);
...
if (m_pslverr === PSLVERR_VAL) begin
  $display("...✓ PASS: PSLVERR correct for unmapped access!");
```

The generator assumes `0xFFFF` is always outside every configured slave's range.
True for the shipped 24-bit/6-slave example (max mapped address `0x00B3FF`), but
**not** guaranteed for any wider or denser map. Reproduced with an independent
18-bit, 14-slave config (contiguous 16 KiB windows) generated and run through this
repo's own two scripts: the 5th slave (`GPIO0`) is decoded as
`i_paddr >= 18'h0C000 & i_paddr <= 18'h0FFFF` — i.e. `0xFFFF` sits **exactly on
GPIO0's own inclusive upper boundary** and is fully mapped. The auto-generated
"unmapped address" self-check would therefore report a **false failure**
(`PSLVERR` correctly *not* asserted, because the address is legitimately mapped),
with nothing about the message pointing at the real cause.

The companion "gap" test (`apb_dec_tb_generator.py:429-463`) only probes gaps
**between two adjacent listed slaves**; it never probes the region *after the last
slave* up to `2**address_width - 1` — precisely where a real "reserved / returns
PSLVERR" region (e.g. spare/unused slots at the top of the map) would live.

**Suggested fix:** pick the unmapped-test address programmatically — e.g. the first
free address after the last slave's `END ADDRESS` (falling back to a real gap, or to
`2**address_width-1`, only if that address is confirmed to lie outside every
slave's `[OFFSET, END_ADDRESS]`) — instead of a hardcoded `0xFFFF`.

---

## Reproduction environment

- OS: Windows (this session), Python 3.14.7 (`uv run --with openpyxl`), `openpyxl`
  3.1.5.
- All findings above were checked against this exact clone at commit `90bd54d`; no
  files in the reviewed repository were modified — all reproduction was done in a
  scratch subdirectory that was removed afterward (`git status` is clean).
