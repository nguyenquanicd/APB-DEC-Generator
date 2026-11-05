#!/usr/bin/env python3
"""
APB Decoder RTL Generator (revision 0.2)

Reads the configuration from an Excel workbook and writes the RTL of an APB4 decoder:
the decoder as one module in one file <name>.sv, a JSON
description of the resolved configuration (json_version 2), the file list and the module-name
marker. The behavior is defined by docs/APB_DEC_Design_Specification.md.

Slave table (sheet APB_DEC, 'Table - Slaves Information'):
  NAME, START ADDRESS, END ADDRESS   inputs; both addresses inclusive, hexadecimal text '0x...'
  SIZE, ADDRESS WIDTH, DESCRIPTION   SIZE and ADDRESS WIDTH are computed here
                                     (SIZE = END - START + 1, ADDRESS WIDTH = max(1, clog2(SIZE)));
                                     a cached spreadsheet value that differs only gives a warning

Exit code 0 on success. Any configuration error gives exit code 1, a list of every problem and no
output file.
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime

import openpyxl

MAX_SLAVES = 64
MAX_SLAVE_NAME = 18      # o_penable_<name> and LPARA_<NAME>_START stay at most 30 characters
MAX_MODULE_NAME = 30     # NAM-07
JSON_VERSION = 2
_IDENT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
_HEX_RE = re.compile(r'^0[xX][0-9A-Fa-f]+$')
_UNITS = {'B': 1, 'KB': 1024, 'MB': 1024 ** 2, 'GB': 1024 ** 3, 'TB': 1024 ** 4}


REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUIET = False   # set True by the tests to silence the 'Generated:' lines


def _say(msg):
    if not QUIET:
        print(msg)


def get_author():
    """Get current system username."""
    try:
        return subprocess.check_output(['whoami'], text=True).strip()
    except Exception:
        return 'unknown'


def generate_header(description):
    """File header of the VLSIT RTL rules (Project, Author, AI Flow, Date, Description)."""
    return (
        "/*\n"
        " * Project      : APB Decoder Generator\n"
        f" * Author       : {get_author()} (user)\n"
        " * AI Flow      : VLSIT RTL Generator AI Automation Flow\n"
        " * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model\n"
        f" * Date         : {datetime.now().strftime('%Y-%m-%d')}\n"
        f" * Description  : {description}\n"
        " */\n"
        "`timescale 1ns/1ps\n"
    )


def parse_excel(excel_path, sheet_name=None):
    """Parse the workbook into {sheet: [table, ...]}; a requested sheet must exist."""
    wb = openpyxl.load_workbook(excel_path, data_only=True)

    if sheet_name:
        if sheet_name not in wb.sheetnames:
            raise ValueError(
                f"Sheet '{sheet_name}' was not found in '{excel_path}'. "
                f"Sheets present: {wb.sheetnames}"
            )
        sheet_names = [sheet_name]
    else:
        sheet_names = [wb.sheetnames[0]] if wb.sheetnames else []

    result = {}
    for sn in sheet_names:
        ws = wb[sn]
        tables = []
        current_table = None
        header_row = None

        for row in ws.iter_rows(values_only=True):
            if all(cell is None for cell in row):
                if current_table is not None and current_table['name']:
                    tables.append(current_table)
                    current_table = None
                    header_row = None
                continue

            first_cell = row[0]
            if first_cell and isinstance(first_cell, str) and first_cell.startswith('Table -'):
                if current_table is not None and current_table['name']:
                    tables.append(current_table)
                current_table = {'name': first_cell, 'headers': None, 'data': []}
                header_row = None
                continue

            if current_table is not None:
                if header_row is None:
                    header_row = row
                    current_table['headers'] = [h for h in row if h is not None]
                else:
                    row_dict = {}
                    for i, cell in enumerate(row):
                        if i < len(header_row) and header_row[i] is not None:
                            row_dict[header_row[i]] = cell
                    if any(v is not None for v in row_dict.values()):
                        current_table['data'].append(row_dict)

        if current_table is not None and current_table['name']:
            tables.append(current_table)
        result[sn] = tables

    return result


def _cell(row, key):
    """Cell value, with 'key absent' and 'blank cell' treated the same way."""
    val = row.get(key)
    return val if val not in (None, '') else None


def clog2(n):
    """Smallest m with 2**m >= n (clog2(1) = 0)."""
    return (n - 1).bit_length()


def slave_width(size):
    """Address port width of a slave window of `size` bytes: at least one bit."""
    return max(1, clog2(size))


def _format_size(n):
    """Human-readable size, for example '24 B', '6 KB', '1.5 KB'."""
    for unit in ('TB', 'GB', 'MB', 'KB'):
        div = _UNITS[unit]
        if n >= div:
            q = n / div
            return f"{int(q)} {unit}" if n % div == 0 else f"{q:g} {unit}"
    return f"{n} B"


def _parse_size_text(text):
    """Bytes of a cached SIZE text such as '24 B' or '1.5 KB'; None when not understood."""
    m = re.fullmatch(r'\s*([0-9.]+)\s*([KMGT]?B)\s*', str(text), re.I)
    if not m:
        return None
    try:
        return float(m.group(1)) * _UNITS[m.group(2).upper()]
    except ValueError:
        return None


def _to_int(value, label, errors, lo=None, hi=None, allowed=None):
    """Integer from an Excel cell (int, whole float or digit text), or None with an error."""
    try:
        if isinstance(value, bool):
            raise ValueError
        if isinstance(value, float):
            if value != int(value):
                raise ValueError
            val = int(value)
        else:
            val = int(str(value).strip(), 10)
    except ValueError:
        errors.append(f"{label} '{value}' is not an integer.")
        return None
    if allowed is not None and val not in allowed:
        errors.append(f"{label} {val} is not one of {sorted(allowed)}.")
        return None
    if (lo is not None and val < lo) or (hi is not None and val > hi):
        errors.append(f"{label} {val} is outside {lo} to {hi}.")
        return None
    return val


def _hex_value(value):
    """Integer of a '0x...' hexadecimal text, or None."""
    if not isinstance(value, str) or not _HEX_RE.match(value.strip()):
        return None
    return int(value.strip()[2:], 16)


def extract_config(parsed_data):
    """Validate the parsed workbook. Returns (config, errors, warnings)."""
    config = {
        'json_version': JSON_VERSION,
        'module_name': None,
        'address_width': None,
        'data_width': None,
        'write_strobe': None,
        'address_rebase': 1,
        'register_inputs': 0,
        'register_outputs': 0,
        'slaves': [],
    }
    errors = []
    warnings = []

    tables = parsed_data.get('APB_DEC')
    if tables is None:
        errors.append(
            "No sheet named 'APB_DEC' was found. The APB-DEC-Generator schema "
            "requires the workbook to contain a sheet literally named 'APB_DEC' "
            "(see templates/APB_DEC_Template.xlsx)."
        )
        return config, errors, warnings

    slave_rows = None
    slave_headers = []
    for table in tables:
        name = table['name']
        if 'Master Configuration' in name:
            for row in table['data']:
                cfg_name = row.get('Config')
                value = _cell(row, 'Value')
                if cfg_name == 'PSLVERR on Unmapped Access':
                    warnings.append(
                        "The row 'PSLVERR on Unmapped Access' is ignored: the input pin "
                        "i_unmapped_err_en selects the response of an unmapped access.")
                    continue
                if value is None:
                    continue
                if cfg_name == 'Address Width':
                    config['address_width'] = _to_int(value, 'Address Width', errors, 1, 32)
                elif cfg_name == 'Data Width':
                    config['data_width'] = _to_int(value, 'Data Width', errors, allowed={8, 16, 32})
                elif cfg_name == 'Write Strobe':
                    config['write_strobe'] = _to_int(value, 'Write Strobe', errors, 1, 4)
                elif cfg_name == 'Address Rebase':
                    config['address_rebase'] = _to_int(value, 'Address Rebase', errors, allowed={0, 1})
                elif cfg_name == 'Register Inputs':
                    config['register_inputs'] = _to_int(value, 'Register Inputs', errors, allowed={0, 1})
                elif cfg_name == 'Register Outputs':
                    config['register_outputs'] = _to_int(value, 'Register Outputs', errors, allowed={0, 1})
        elif 'Slaves' in name:
            slave_rows = table['data']
            slave_headers = table['headers'] or []
        elif 'Configuration' in name:
            for row in table['data']:
                if row.get('Config') == 'Module Name':
                    mn = _cell(row, 'Value')
                    config['module_name'] = str(mn).strip() if mn is not None else None

    mod = config['module_name']
    if mod is None:
        errors.append("Module Name is missing from the 'Table - Configuration' block.")
    elif not _IDENT_RE.match(mod) or not mod.startswith('m_') or len(mod) > MAX_MODULE_NAME:
        errors.append(
            f"Module Name '{mod}' must be a legal identifier that starts with m_ and has at most "
            f"{MAX_MODULE_NAME} characters.")
    if config['address_width'] is None and not any('Address Width' in e for e in errors):
        errors.append("Address Width is missing from the 'Table - Master Configuration' block.")
    if config['data_width'] is None and not any('Data Width' in e for e in errors):
        errors.append("Data Width is missing from the 'Table - Master Configuration' block.")
    if config['data_width'] is not None:
        if config['write_strobe'] is None:
            config['write_strobe'] = config['data_width'] // 8
        elif config['write_strobe'] != config['data_width'] // 8:
            errors.append(
                f"Write Strobe {config['write_strobe']} must equal Data Width / 8 = "
                f"{config['data_width'] // 8}.")

    if slave_rows is None:
        errors.append("The 'Table - Slaves Information' block is missing.")
        return config, errors, warnings

    if 'START ADDRESS' not in slave_headers and (
            'OFFSET' in slave_headers or 'ADDRESS WIDTH' in slave_headers):
        errors.append(
            "The slave table uses the revision 0.1 columns OFFSET / ADDRESS WIDTH. Revision 0.2 "
            "reads NAME, START ADDRESS and END ADDRESS (both inclusive, '0x...' text): rename "
            "OFFSET to START ADDRESS, add END ADDRESS = OFFSET + 2^ADDRESS WIDTH - 1 in "
            "hexadecimal, and keep SIZE and ADDRESS WIDTH only as computed columns.")
        return config, errors, warnings

    aw = config['address_width']
    seen = {}
    for row_num, row in enumerate(slave_rows, start=1):
        slave_name = _cell(row, 'NAME')
        if slave_name is None:
            continue
        slave_name = str(slave_name).strip()
        where = f"Slaves row {row_num} ('{slave_name}')"

        bad = False
        if not _IDENT_RE.match(slave_name):
            errors.append(f"{where}: NAME is not a legal identifier "
                          f"([A-Za-z_][A-Za-z0-9_]*, no spaces or hyphens).")
            bad = True
        if len(slave_name) > MAX_SLAVE_NAME:
            errors.append(f"{where}: NAME has {len(slave_name)} characters; the limit is "
                          f"{MAX_SLAVE_NAME} so that every generated name stays at most 30.")
            bad = True
        key = slave_name.lower()
        if key in seen:
            errors.append(f"{where}: NAME collides with '{seen[key][0]}' (row {seen[key][1]}) "
                          f"after conversion to lower case.")
            bad = True

        start = _hex_value(_cell(row, 'START ADDRESS'))
        end = _hex_value(_cell(row, 'END ADDRESS'))
        if start is None:
            errors.append(f"{where}: START ADDRESS is missing or not a '0x...' hexadecimal text.")
            bad = True
        if end is None:
            errors.append(f"{where}: END ADDRESS is missing or not a '0x...' hexadecimal text.")
            bad = True
        if start is not None and end is not None and start > end:
            errors.append(f"{where}: START ADDRESS 0x{start:X} is greater than END ADDRESS 0x{end:X}.")
            bad = True
        if end is not None and aw is not None and end > (1 << aw) - 1:
            errors.append(f"{where}: END ADDRESS 0x{end:X} is outside the {aw}-bit master "
                          f"address space (max 0x{(1 << aw) - 1:X}).")
            bad = True
        if bad:
            continue

        size = end - start + 1
        width = slave_width(size)

        given_w = _cell(row, 'ADDRESS WIDTH')
        if given_w is not None:
            try:
                if int(float(given_w)) != width:
                    warnings.append(f"{where}: spreadsheet ADDRESS WIDTH {given_w} differs from "
                                    f"the computed {width}; the computed value is used.")
            except ValueError:
                pass
        given_s = _cell(row, 'SIZE')
        if given_s is not None:
            gb = _parse_size_text(given_s)
            if gb is not None and abs(gb - size) > 1e-6 * size:
                warnings.append(f"{where}: spreadsheet SIZE '{given_s}' differs from the computed "
                                f"{_format_size(size)}; the computed value is used.")

        if config['address_rebase'] == 0 and start % (1 << width) != 0:
            warnings.append(
                f"{where}: Address Rebase is 0 and START ADDRESS 0x{start:X} is not a multiple of "
                f"2^{width}; the raw low address bits of this slave do not start at 0.")

        seen[key] = (slave_name, row_num)
        config['slaves'].append({
            'name': slave_name,
            'start': f"0x{start:X}",
            'end': f"0x{end:X}",
            'start_val': start,
            'end_val': end,
            'size_bytes': size,
            'size': _format_size(size),
            'address_width': width,
            'description': row.get('DESCRIPTION'),
        })

    if not config['slaves'] and not any(e.startswith('Slaves row') for e in errors):
        errors.append("No slave is defined in the 'Table - Slaves Information' block.")
    if len(config['slaves']) > MAX_SLAVES:
        errors.append(f"{len(config['slaves'])} slaves are defined; the limit is {MAX_SLAVES}.")

    ordered = sorted(config['slaves'], key=lambda s: s['start_val'])
    for a, b in zip(ordered, ordered[1:]):
        if a['end_val'] >= b['start_val']:
            errors.append(
                f"Slave '{a['name']}' (0x{a['start_val']:X}-0x{a['end_val']:X}) and slave "
                f"'{b['name']}' (0x{b['start_val']:X}-0x{b['end_val']:X}) overlap.")

    return config, errors, warnings


def build_config(excel_path, sheet_name='APB_DEC'):
    """Parse and validate one workbook. Returns (config, errors, warnings)."""
    parsed = parse_excel(excel_path, sheet_name)
    return extract_config(parsed)


def generate_json(config, output_path):
    """Write the resolved configuration (json_version 2)."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2)
    _say(f"Generated: {output_path}")


def _write(path, text):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    _say(f"Generated: {path}")


def render_ports(items):
    """Port list text with the columns aligned (direction, type, width, name; rule FIL-05).

    items: ('c', text) for a comment line (text '' = blank line) or
           ('p', direction, type, width, name) for a port; width is '' or '[7:0]'.
    A comma follows every port except the last one.
    """
    ports = [it for it in items if it[0] == 'p']
    dw = max(len(p[1]) for p in ports)
    tw = max(len(p[2]) for p in ports)
    ww = max(len(p[3]) for p in ports)
    last = ports[-1]
    out = []
    for it in items:
        if it[0] == 'c':
            out.append(f"  {it[1]}".rstrip() if it[1] else "")
            continue
        _, d, t, w, n = it
        comma = "" if it is last else ","
        wcol = f" {w:<{ww}}" if ww else ""      # no width column when every port is one bit
        out.append(f"  {d:<{dw}} {t:<{tw}}{wcol} {n}{comma}")
    return "\n".join(out)


def _w(width):
    """Packed range text of a bus of `width` bits; '' for a one-bit signal (rule R-035: a one-bit
    signal has no [0:0] range)."""
    return "" if width == 1 else f"[{width - 1}:0]"


def _bit(name, width, i):
    """Bit i of a signal declared with _w(width): the name itself when it is a one-bit signal."""
    return name if width == 1 else f"{name}[{i}]"


def _const_bits(name, aw):
    """The low `aw` bits of a 32-bit localparam, as a bit select when aw is 1."""
    return f"{name}[0]" if aw == 1 else f"{name}[{aw - 1}:0]"


def _paddr_low(width_name, aw, w):
    """The low W bits of i_paddr; the bare name when i_paddr itself has one bit."""
    return "i_paddr" if aw == 1 else f"i_paddr[{width_name}-1:0]"


def covers_whole_space(config):
    """True when the windows leave no unmapped address (they tile 0 .. 2^AW - 1 without a gap)."""
    nxt = 0
    for s in sorted(config['slaves'], key=lambda x: x['start_val']):
        if s['start_val'] != nxt:
            return False
        nxt = s['end_val'] + 1
    return nxt == (1 << config['address_width'])


def is_piped(config):
    """True when a register option is on: the decoder is then clocked (i_clk_apb, i_rst_n_apb)."""
    return bool(config.get('register_inputs') or config.get('register_outputs'))


def _port_items(config, clocked):
    """Port list items of the decoder (requester side, pin, one group per slave)."""
    aw, dw, st = config['address_width'], config['data_width'], config['write_strobe']
    items = []
    if clocked:
        items += [('c', "// Clock and reset (the register options of the generator are on)"),
                  ('p', 'input', 'wire', '', 'i_clk_apb'),
                  ('p', 'input', 'wire', '', 'i_rst_n_apb'),
                  ('c', "")]
    items += [
        ('c', "// APB4 requester side"),
        ('p', 'input', 'wire', _w(aw), 'i_paddr'),
        ('p', 'input', 'wire', '[2:0]', 'i_pprot'),
        ('p', 'input', 'wire', '', 'i_psel'),
        ('p', 'input', 'wire', '', 'i_penable'),
        ('p', 'input', 'wire', '', 'i_pwrite'),
        ('p', 'input', 'wire', _w(dw), 'i_pwdata'),
        ('p', 'input', 'wire', _w(st), 'i_pstrb'),
        ('p', 'output', 'logic', '', 'o_pready'),
        ('p', 'output', 'logic', _w(dw), 'o_prdata'),
        ('p', 'output', 'logic', '', 'o_pslverr'),
        ('c', ""),
        ('c', "// Response to an address that belongs to no slave: 1 = error, 0 = ready only"),
        ('p', 'input', 'wire', '', 'i_unmapped_err_en'),
    ]
    for i, s in enumerate(config['slaves']):
        low = s['name'].lower()
        desc = f" ({s['description']})" if s.get('description') else ""
        items += [
            ('c', ""),
            ('c', f"// Slave {i}: {s['name']} 0x{s['start_val']:X} to 0x{s['end_val']:X}{desc}"[:96]),
            ('p', 'output', 'logic', '', f"o_psel_{low}"),
            ('p', 'output', 'logic', '', f"o_penable_{low}"),
            ('p', 'output', 'logic', '', f"o_pwrite_{low}"),
            ('p', 'output', 'logic', _w(s['address_width']), f"o_paddr_{low}"),
            ('p', 'output', 'logic', _w(dw), f"o_pwdata_{low}"),
            ('p', 'output', 'logic', _w(st), f"o_pstrb_{low}"),
            ('p', 'output', 'logic', '[2:0]', f"o_pprot_{low}"),
            ('p', 'input', 'wire', '', f"i_pready_{low}"),
            ('p', 'input', 'wire', '', f"i_pslverr_{low}"),
            ('p', 'input', 'wire', _w(dw), f"i_prdata_{low}"),
        ]
    return items


def _param_list(config):
    """Derived localparams of the windows and port widths, only those that the logic uses."""
    aw = config['address_width']
    max_addr = (1 << aw) - 1
    params = []
    for s in config['slaves']:
        up = s['name'].upper()
        if s['start_val'] > 0:
            params.append(f"  localparam logic [31:0] LPARA_{up}_START = 32'h{s['start_val']:08X}")
        if s['end_val'] < max_addr:
            params.append(f"  localparam logic [31:0] LPARA_{up}_END = 32'h{s['end_val']:08X}")
        if aw > 1:
            params.append(f"  localparam logic [31:0] LPARA_{up}_W = {s['address_width']}")
    return params


def _module_head(config, description, clocked):
    params = _param_list(config)
    ports = render_ports(_port_items(config, clocked))
    sv = generate_header(description)
    mod = config['module_name']
    if params:
        sv += (f"\nmodule {mod} #(\n  // Window of every slave (first and last byte, inclusive) and port width\n"
               + ",\n".join(params) + f"\n) (\n{ports}\n);\n\n")
    else:
        sv += f"\nmodule {mod} (\n{ports}\n);\n\n"
    return sv


def _sel_assigns(config, addr):
    """Window match assigns of w_sel from the address signal `addr`."""
    aw = config['address_width']
    n = len(config['slaves'])
    max_addr = (1 << aw) - 1
    sv = ""
    for i, s in enumerate(config['slaves']):
        up = s['name'].upper()
        lo_cmp = f"({addr} >= {_const_bits(f'LPARA_{up}_START', aw)})"
        hi_cmp = f"({addr} <= {_const_bits(f'LPARA_{up}_END', aw)})"
        sel_i = _bit('w_sel', n, i)
        if s['start_val'] == 0 and s['end_val'] == max_addr:
            sv += f"  assign {sel_i} = 1'b1;\n"
        elif s['start_val'] == 0:
            sv += f"  assign {sel_i} = {hi_cmp};\n"
        elif s['end_val'] == max_addr:
            sv += f"  assign {sel_i} = {lo_cmp};\n"
        else:
            sv += (f"  assign {sel_i} = {lo_cmp} &\n"
                   f"{' ' * (len(sel_i) + 10)}{hi_cmp};\n")
    return sv


def _local_addr_expr(config, s, addr):
    """Local address expression of slave s from the address signal `addr`."""
    aw = config['address_width']
    up = s['name'].upper()
    low = f"{addr}[LPARA_{up}_W-1:0]" if aw > 1 else addr
    if config['address_rebase'] and s['start_val'] > 0:
        start_low = f"LPARA_{up}_START[0]" if aw == 1 else f"LPARA_{up}_START[LPARA_{up}_W-1:0]"
        return f"{low} - {start_low}"
    return low


def _case_default_off(config):
    if covers_whole_space(config):
        return ("      // The windows cover the whole address space: this branch cannot be reached and\n"
                "      // stays only to give the case a default (excluded from the coverage count).\n"
                "      // verilator coverage_off\n"), "      // verilator coverage_on\n"
    return "", ""


def gen_piped_sv(config):
    """The decoder with the register options: input flops, output flops, or both.

    The downstream (slave side) phases and the PREADY of the requester are produced by a small
    state machine, so that the APB protocol holds on every bus in every combination:
      * the slave sees one setup cycle, then access cycles until its PREADY, then idle: the end of
        the access is decided from the PREADY pin of the selected slave in the cycle where the
        slave asserts it (that pin is not delayed, whatever the options are);
      * the requester sees PREADY low until the response is ready, then one PREADY cycle.
    Latency (cycles added to a zero-wait transfer): Register Inputs 2 on the response, 1 on the
    request; Register Outputs likewise; see docs/APB_DEC_Design_Specification.md section 10.
    """
    mod = config['module_name']
    aw = config['address_width']
    dw = config['data_width']
    st = config['write_strobe']
    slaves = config['slaves']
    n = len(slaves)
    rin = bool(config.get('register_inputs'))
    rout = bool(config.get('register_outputs'))
    names = [s['name'].lower() for s in slaves]
    opt = ("input and output flops" if rin and rout else "input flops" if rin else "output flops")
    sv = _module_head(config, f"APB4 decoder with {n} slave(s) and {opt}.", True)

    # ------------------------------------------------------------ declarations
    sv += f"""  // Requester signals seen by the decoder: {'registered' if rin else 'the input pins'}.
  logic {_w(aw)} w_req_paddr;
  logic [2:0] w_req_pprot;
  logic w_req_psel;
  logic w_req_penable;
  logic w_req_pwrite;
  logic {_w(dw)} w_req_pwdata;
  logic {_w(st)} w_req_pstrb;

  logic {_w(n)} w_sel;
  logic w_unmapped;
  logic w_slv_ready;
  logic w_trigger;
  logic w_done;
  logic w_pulse;
  logic w_pslverr_sel;
  logic {_w(dw)} w_prdata_sel;
  logic w_rerr;
  logic reg_acc;
"""
    if rout:
        sv += "  logic reg_setup;\n"
        sv += "  logic reg_o_pready;\n  logic reg_o_pslverr;\n"
        sv += f"  logic {_w(dw)} reg_o_prdata;\n"
        for s, nm in zip(slaves, names):
            sv += (f"  logic reg_psel_{nm};\n  logic reg_penable_{nm};\n  logic reg_pwrite_{nm};\n"
                   f"  logic {_w(s['address_width'])} reg_paddr_{nm};\n  logic {_w(dw)} reg_pwdata_{nm};\n"
                   f"  logic {_w(st)} reg_pstrb_{nm};\n  logic [2:0] reg_pprot_{nm};\n")
    if rin:
        sv += "  logic reg_pulse;\n"
        sv += f"  logic reg_req_psel;\n  logic reg_req_penable;\n  logic reg_req_pwrite;\n"
        sv += (f"  logic {_w(aw)} reg_req_paddr;\n  logic [2:0] reg_req_pprot;\n"
               f"  logic {_w(dw)} reg_req_pwdata;\n  logic {_w(st)} reg_req_pstrb;\n")
        for nm in names:
            sv += (f"  logic reg_pslverr_{nm};\n  logic {_w(dw)} reg_prdata_{nm};\n")
    sv += "\n"

    # ------------------------------------------------------------ input stage
    if rin:
        sv += f"""  // Input stage: every input of the decoder except the slave PREADY pins and the static pin
  // is registered. The slave PREADY pins also reach the end-of-access logic directly: the slave
  // must see its transfer end in the cycle after it asserts PREADY.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_input
    if (!i_rst_n_apb) begin
      reg_req_psel    <= 1'b0;
      reg_req_penable <= 1'b0;
      reg_req_pwrite  <= 1'b0;
      reg_req_paddr   <= {aw}'d0;
      reg_req_pprot   <= 3'd0;
      reg_req_pwdata  <= {dw}'d0;
      reg_req_pstrb   <= {st}'d0;
      reg_pulse       <= 1'b0;
"""
        for nm in names:
            sv += (f"      reg_pslverr_{nm} <= 1'b0;\n      reg_prdata_{nm} <= {dw}'d0;\n")
        sv += """    end else begin
      reg_req_psel    <= i_psel;
      reg_req_penable <= i_penable;
      reg_req_pwrite  <= i_pwrite;
      reg_req_paddr   <= i_paddr;
      reg_req_pprot   <= i_pprot;
      reg_req_pwdata  <= i_pwdata;
      reg_req_pstrb   <= i_pstrb;
      reg_pulse       <= w_done;
"""
        for nm in names:
            sv += (f"      reg_pslverr_{nm} <= i_pslverr_{nm};\n      reg_prdata_{nm} <= i_prdata_{nm};\n")
        sv += "    end\n  end\n\n"
        for sig in ('psel', 'penable', 'pwrite', 'paddr', 'pprot', 'pwdata', 'pstrb'):
            sv += f"  assign w_req_{sig} = reg_req_{sig};\n"
    else:
        for sig in ('psel', 'penable', 'pwrite', 'paddr', 'pprot', 'pwdata', 'pstrb'):
            sv += f"  assign w_req_{sig} = i_{sig};\n"

    # ------------------------------------------------------------ window match
    sv += "\n  // Window match: the address is inside [START, END] of the slave, all address bits compared.\n"
    sv += _sel_assigns(config, 'w_req_paddr')
    sv += """
  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

"""
    cov_off, cov_on = _case_default_off(config)
    # ------------------------------------------------------------ end of access
    sv += f"""  // PREADY of the selected slave, taken from the pins. An address that no slave owns is ready
  // at once.
  always_comb begin : p_com_slv_ready
    w_slv_ready = 1'b1;
    casez (w_sel)
"""
    for i, nm in enumerate(names):
        pat = '?' * (n - 1 - i) + '1' + '0' * i
        sv += f"      {n}'b{pat}: w_slv_ready = i_pready_{nm};\n"
    sv += f"""{cov_off}      default: w_slv_ready = 1'b1;
{cov_on}    endcase
  end

  // A new transfer starts when the requester setup phase is seen and the decoder is idle.
  assign w_trigger = w_req_psel & ~w_req_penable & ~reg_acc{' & ~reg_setup' if rout else ''};

  // The access phase of the slave side ends in the cycle where the slave asserts PREADY.
  assign w_done = reg_acc & w_slv_ready;

"""
    # ------------------------------------------------------------ phase state
    if rout:
        sv += """  // Phase state (registered outputs): setup, then access until the slave PREADY.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_phase
    if (!i_rst_n_apb) begin
      reg_setup <= 1'b0;
      reg_acc   <= 1'b0;
    end else begin
      reg_setup <= w_trigger;
      reg_acc   <= reg_setup | (reg_acc & ~w_slv_ready);
    end
  end

"""
    else:
        sv += """  // Phase state: the setup phase is the trigger cycle itself, then access until PREADY.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_phase
    if (!i_rst_n_apb) begin
      reg_acc <= 1'b0;
    end else begin
      reg_acc <= w_trigger | (reg_acc & ~w_slv_ready);
    end
  end

"""
    # ------------------------------------------------------------ slave side outputs
    if rout:
        sv += "  // Output stage: every output of the decoder is registered.\n"
        sv += "  // The select of a slave is high in the setup and access cycles.\n"
        sv += ("  logic w_bus_nxt;\n  logic w_acc_nxt;\n"
               "  assign w_acc_nxt = reg_setup | (reg_acc & ~w_slv_ready);\n"
               "  assign w_bus_nxt = w_trigger | w_acc_nxt;\n\n")
        sv += "  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_slave_out\n"
        sv += "    if (!i_rst_n_apb) begin\n"
        for s, nm in zip(slaves, names):
            sv += (f"      reg_psel_{nm}    <= 1'b0;\n      reg_penable_{nm} <= 1'b0;\n"
                   f"      reg_pwrite_{nm}  <= 1'b0;\n"
                   f"      reg_paddr_{nm}   <= {s['address_width']}'d0;\n      reg_pwdata_{nm}  <= {dw}'d0;\n"
                   f"      reg_pstrb_{nm}   <= {st}'d0;\n      reg_pprot_{nm}   <= 3'd0;\n")
        sv += "    end else begin\n"
        for i, (s, nm) in enumerate(zip(slaves, names)):
            sv += (f"      reg_psel_{nm}    <= w_bus_nxt & {_bit('w_sel', n, i)};\n"
                   f"      reg_penable_{nm} <= w_acc_nxt & {_bit('w_sel', n, i)};\n"
                   f"      reg_pwrite_{nm}  <= w_req_pwrite;\n"
                   f"      reg_paddr_{nm}   <= {_local_addr_expr(config, s, 'w_req_paddr')};\n"
                   f"      reg_pwdata_{nm}  <= w_req_pwdata;\n"
                   f"      reg_pstrb_{nm}   <= w_req_pstrb;\n"
                   f"      reg_pprot_{nm}   <= w_req_pprot;\n")
        sv += "    end\n  end\n\n"
        for nm in names:
            sv += (f"  assign o_psel_{nm} = reg_psel_{nm};\n  assign o_penable_{nm} = reg_penable_{nm};\n"
                   f"  assign o_pwrite_{nm} = reg_pwrite_{nm};\n  assign o_paddr_{nm} = reg_paddr_{nm};\n"
                   f"  assign o_pwdata_{nm} = reg_pwdata_{nm};\n  assign o_pstrb_{nm} = reg_pstrb_{nm};\n"
                   f"  assign o_pprot_{nm} = reg_pprot_{nm};\n")
    else:
        sv += "  // Slave side: select in the setup (trigger) and access cycles, attributes unchanged.\n"
        for i, (s, nm) in enumerate(zip(slaves, names)):
            sv += (f"  assign o_psel_{nm} = (w_trigger | reg_acc) & {_bit('w_sel', n, i)};\n"
                   f"  assign o_penable_{nm} = reg_acc & {_bit('w_sel', n, i)};\n"
                   f"  assign o_pwrite_{nm} = w_req_pwrite;\n"
                   f"  assign o_paddr_{nm} = {_local_addr_expr(config, s, 'w_req_paddr')};\n"
                   f"  assign o_pwdata_{nm} = w_req_pwdata;\n"
                   f"  assign o_pstrb_{nm} = w_req_pstrb;\n"
                   f"  assign o_pprot_{nm} = w_req_pprot;\n")
    # ------------------------------------------------------------ response
    sv += f"""
  // Response data and error of the selected slave ({'input-stage registers' if rin else 'pins'}).
  always_comb begin : p_com_resp_sel
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = {dw}'d0;
    casez (w_sel)
"""
    pre = 'reg' if rin else 'i'
    for i, nm in enumerate(names):
        pat = '?' * (n - 1 - i) + '1' + '0' * i
        sv += (f"      {n}'b{pat}: begin\n"
               f"        w_pslverr_sel = {pre}_pslverr_{nm};\n"
               f"        w_prdata_sel  = {pre}_prdata_{nm};\n"
               f"      end\n")
    sv += f"""{cov_off}      default: begin
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = {dw}'d0;
      end
{cov_on}    endcase
  end

  // An unmapped address takes the value of the pin; a mapped address takes the slave error.
  assign w_rerr = w_unmapped ? i_unmapped_err_en : w_pslverr_sel;

  // One response pulse per transfer: the cycle of the end of the access{', one cycle later' if rin else ''}.
  assign w_pulse = {'reg_pulse' if rin else 'w_done'};

"""
    if rout:
        sv += f"""  // Output stage of the requester side: PREADY is the registered pulse, PSLVERR is valid only
  // together with it.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_resp_out
    if (!i_rst_n_apb) begin
      reg_o_pready  <= 1'b0;
      reg_o_prdata  <= {dw}'d0;
      reg_o_pslverr <= 1'b0;
    end else begin
      reg_o_pready  <= w_pulse;
      reg_o_prdata  <= w_prdata_sel;
      reg_o_pslverr <= w_pulse & w_rerr;
    end
  end

  assign o_pready  = reg_o_pready;
  assign o_prdata  = reg_o_prdata;
  assign o_pslverr = reg_o_pslverr;
"""
    else:
        sv += """  // Requester side: PREADY is the pulse, PSLVERR is valid only together with it.
  assign o_pready  = w_pulse;
  assign o_prdata  = w_prdata_sel;
  assign o_pslverr = w_pulse & w_rerr;
"""
    sv += "\nendmodule\n"
    return mod, sv


def gen_sv(config):
    """The decoder: one module in one file (window match, local addresses, response selection)."""
    if is_piped(config):
        return gen_piped_sv(config)
    mod = config['module_name']
    aw = config['address_width']
    dw = config['data_width']
    st = config['write_strobe']
    rebase = config['address_rebase']
    slaves = config['slaves']
    n = len(slaves)
    max_addr = (1 << aw) - 1

    # ---- constants: window edges and port widths, only those that the logic uses
    params = []
    for s in slaves:
        up = s['name'].upper()
        if s['start_val'] > 0:          # START: lower compare, and the rebase subtraction
            params.append(f"  localparam logic [31:0] LPARA_{up}_START = 32'h{s['start_val']:08X}")
        if s['end_val'] < max_addr:     # END: upper compare, needed only when an address lies above
            params.append(f"  localparam logic [31:0] LPARA_{up}_END = 32'h{s['end_val']:08X}")
        if aw > 1:                      # with a one-bit address bus every port has one bit
            params.append(f"  localparam logic [31:0] LPARA_{up}_W = {s['address_width']}")

    # ---- ports
    items = [
        ('c', "// APB4 requester side"),
        ('p', 'input', 'wire', _w(aw), 'i_paddr'),
        ('p', 'input', 'wire', '[2:0]', 'i_pprot'),
        ('p', 'input', 'wire', '', 'i_psel'),
        ('p', 'input', 'wire', '', 'i_penable'),
        ('p', 'input', 'wire', '', 'i_pwrite'),
        ('p', 'input', 'wire', _w(dw), 'i_pwdata'),
        ('p', 'input', 'wire', _w(st), 'i_pstrb'),
        ('p', 'output', 'logic', '', 'o_pready'),
        ('p', 'output', 'logic', _w(dw), 'o_prdata'),
        ('p', 'output', 'logic', '', 'o_pslverr'),
        ('c', ""),
        ('c', "// Response to an address that belongs to no slave: 1 = error, 0 = ready only"),
        ('p', 'input', 'wire', '', 'i_unmapped_err_en'),
    ]
    for i, s in enumerate(slaves):
        low = s['name'].lower()
        desc = f" ({s['description']})" if s.get('description') else ""
        items += [
            ('c', ""),
            ('c', f"// Slave {i}: {s['name']} 0x{s['start_val']:X} to 0x{s['end_val']:X}{desc}"[:96]),
            ('p', 'output', 'logic', '', f"o_psel_{low}"),
            ('p', 'output', 'logic', '', f"o_penable_{low}"),
            ('p', 'output', 'logic', '', f"o_pwrite_{low}"),
            ('p', 'output', 'logic', _w(s['address_width']), f"o_paddr_{low}"),
            ('p', 'output', 'logic', _w(dw), f"o_pwdata_{low}"),
            ('p', 'output', 'logic', _w(st), f"o_pstrb_{low}"),
            ('p', 'output', 'logic', '[2:0]', f"o_pprot_{low}"),
            ('p', 'input', 'wire', '', f"i_pready_{low}"),
            ('p', 'input', 'wire', '', f"i_pslverr_{low}"),
            ('p', 'input', 'wire', _w(dw), f"i_prdata_{low}"),
        ]

    sv = generate_header(f"APB4 decoder with {n} slave(s): window match, local address, response.")
    if params:
        sv += (f"\nmodule {mod} #(\n  // Window of every slave (first and last byte, inclusive) and port width\n"
               + ",\n".join(params) + f"\n) (\n{render_ports(items)}\n);\n\n")
    else:
        sv += f"\nmodule {mod} (\n{render_ports(items)}\n);\n\n"

    # ---- window match
    sv += f"""  logic {_w(n)} w_sel;
  logic {_w(n)} w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic {_w(dw)} w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
"""
    for i, s in enumerate(slaves):
        up = s['name'].upper()
        lo_cmp = f"(i_paddr >= {_const_bits(f'LPARA_{up}_START', aw)})"
        hi_cmp = f"(i_paddr <= {_const_bits(f'LPARA_{up}_END', aw)})"
        sel_i = _bit('w_sel', n, i)
        if s['start_val'] == 0 and s['end_val'] == max_addr:
            sv += f"  assign {sel_i} = 1'b1;\n"        # the window is the whole address space
        elif s['start_val'] == 0:
            sv += f"  assign {sel_i} = {hi_cmp};\n"     # no address is below START
        elif s['end_val'] == max_addr:
            sv += f"  assign {sel_i} = {lo_cmp};\n"     # no address is above END
        else:
            sv += (f"  assign {sel_i} = {lo_cmp} &\n"
                   f"{' ' * (len(sel_i) + 10)}{hi_cmp};\n")
    sv += f"""
  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {{{n}{{i_psel}}}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = {dw}'d0;
    casez (w_sel)
"""
    for i, s in enumerate(slaves):
        low = s['name'].lower()
        pat = '?' * (n - 1 - i) + '1' + '0' * i
        sv += (f"      {n}'b{pat}: begin\n"
               f"        w_pready_sel  = i_pready_{low};\n"
               f"        w_pslverr_sel = i_pslverr_{low};\n"
               f"        w_prdata_sel  = i_prdata_{low};\n"
               f"      end\n")
    if covers_whole_space(config):
        cov_off = ("      // The windows cover the whole address space: this branch cannot be reached and\n"
                   "      // stays only to give the case a default (excluded from the coverage count).\n"
                   "      // verilator coverage_off\n")
        cov_on = "      // verilator coverage_on\n"
    else:
        cov_off = cov_on = ""
    sv += f"""{cov_off}      default: begin
        w_pready_sel  = 1'b1;
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = {dw}'d0;
      end
{cov_on}    endcase
  end

  // Ready and read data of the requester side are those of the selected slave.
  assign o_pready = w_pready_sel;
  assign o_prdata = w_prdata_sel;

  // PSLVERR is valid only in the last cycle of a transfer (PSEL, PENABLE and PREADY high). An
  // unmapped address takes the value of the pin; a mapped address takes the slave error.
  assign o_pslverr = i_psel & i_penable & w_pready_sel &
                     (w_unmapped ? i_unmapped_err_en : w_pslverr_sel);

  // Local address of every slave.
"""
    if rebase:
        sv += ("  // Address Rebase = 1: the slave sees the offset inside its window. The subtraction is\n"
               "  // done modulo 2^W, which gives the low W bits of (i_paddr - START).\n")
    else:
        sv += "  // Address Rebase = 0: the slave sees the raw low address bits.\n"
    for s in slaves:
        low = s['name'].lower()
        up = s['name'].upper()
        pa = _paddr_low(f"LPARA_{up}_W", aw, s['address_width'])
        if rebase and s['start_val'] > 0:
            start_low = (f"LPARA_{up}_START[0]" if aw == 1
                         else f"LPARA_{up}_START[LPARA_{up}_W-1:0]")
            sv += (f"  assign o_paddr_{low} = {pa} -\n"
                   f"                         {start_low};\n")
        else:                                 # no subtraction: rebase off, or START is 0
            sv += f"  assign o_paddr_{low} = {pa};\n"

    # ---- selects and forwarded attributes
    sv += "\n  // Select of every slave; the other attributes reach every slave unchanged.\n"
    for i, s in enumerate(slaves):
        low = s['name'].lower()
        sv += (f"  assign o_psel_{low} = {_bit('w_psel', n, i)};\n"
               f"  assign o_penable_{low} = i_penable & {_bit('w_psel', n, i)};\n"
               f"  assign o_pwrite_{low} = i_pwrite;\n"
               f"  assign o_pwdata_{low} = i_pwdata;\n"
               f"  assign o_pstrb_{low} = i_pstrb;\n"
               f"  assign o_pprot_{low} = i_pprot;\n")
    sv += "\nendmodule\n"
    return mod, sv


def generate_sv(config, output_dir):
    """Write the RTL: one module in one file. Returns the list with that file name."""
    name, text = gen_sv(config)
    _write(os.path.join(output_dir, f"{name}.sv"), text)
    return [f"{name}.sv"]


def filelist_dir(output_dir):
    """Folder of the generated files as written in filelist.f: $APB_DEC_GEN_HOME/<path inside the
    repository>, or the absolute path when the folder is outside the repository."""
    out = os.path.abspath(output_dir)
    try:
        inside = os.path.commonpath([out, REPO]) == REPO
    except ValueError:
        inside = False
    if inside:
        rel = os.path.relpath(out, REPO).replace(os.sep, '/')
        return '$APB_DEC_GEN_HOME' + ('' if rel == '.' else '/' + rel)
    return out.replace(os.sep, '/')


def generate_filelist(output_dir, files, tb_file=None):
    """filelist.f of the generated files (see filelist_dir for the path form)."""
    base = filelist_dir(output_dir)
    lines = [f'{base}/{f}' for f in files]
    if tb_file:
        lines.append(f'{base}/{tb_file}')
    _write(os.path.join(output_dir, 'filelist.f'), "\n".join(lines) + "\n")


def generate_module_name_marker(output_dir, module_name):
    """output/.module_name for the Makefile and the lint scripts."""
    _write(os.path.join(output_dir, '.module_name'), module_name)


def generate_all(config, output_dir):
    """Write every output file of one validated configuration."""
    os.makedirs(output_dir, exist_ok=True)
    generate_json(config, os.path.join(output_dir, f"{config['module_name']}.json"))
    files = generate_sv(config, output_dir)
    generate_filelist(output_dir, files)
    generate_module_name_marker(output_dir, config['module_name'])
    return files


def main(argv=None):
    argv = sys.argv if argv is None else argv
    excel_path = os.path.join(REPO, 'examples', 'ex_default', 'ex_default.xlsx')
    sheet_name = 'APB_DEC'
    output_dir = os.path.join(REPO, 'output')
    if len(argv) > 1:
        excel_path = argv[1]
    if len(argv) > 2:
        sheet_name = argv[2] if argv[2] else 'APB_DEC'
    if len(argv) > 3:
        output_dir = argv[3]

    print("=" * 60)
    print("APB Decoder RTL Generator (revision 0.2)")
    print("=" * 60)

    print("\n[1/3] Parsing Excel file...")
    try:
        parsed = parse_excel(excel_path, sheet_name)
    except (ValueError, FileNotFoundError) as e:
        print(f"\n[ERROR] {e}")
        return 1

    print("[2/3] Validating configuration...")
    config, errors, warnings = extract_config(parsed)
    for w in warnings:
        print(f"  [WARN] {w}")
    if errors:
        print(f"\n[ERROR] Configuration is invalid -- {len(errors)} problem(s) found:")
        for e in errors:
            print(f"  - {e}")
        print("\nNo RTL was generated.")
        return 1

    print(f"  Module Name:      {config['module_name']}")
    print(f"  Address Width:    {config['address_width']}")
    print(f"  Data Width:       {config['data_width']}")
    print(f"  Write Strobe:     {config['write_strobe']}")
    print(f"  Address Rebase:   {'Enabled' if config['address_rebase'] else 'Disabled'}")
    print(f"  Register Inputs:  {'Enabled' if config['register_inputs'] else 'Disabled'}")
    print(f"  Register Outputs: {'Enabled' if config['register_outputs'] else 'Disabled'}")
    print(f"  Number of Slaves: {len(config['slaves'])}")
    for s in config['slaves']:
        print(f"    - {s['name']}: {s['start']} - {s['end']} "
              f"({s['size']}, {s['address_width']}-bit port)")

    print("\n[3/3] Generating output files...")
    generate_all(config, output_dir)

    print("\n" + "=" * 60)
    print("RTL Generation complete!")
    print("=" * 60)
    return 0


if __name__ == '__main__':
    sys.exit(main())
