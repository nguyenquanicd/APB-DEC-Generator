"""The GUIDELINE sheet of the common workbook format (purple, Arial 13).

Every workbook of the repository (the template and all examples) has two sheets: GUIDELINE (this
sheet: how to fill the workbook, field reference, rules, options) and APB_DEC (the input that the
generator reads). add_guideline_sheet(wb) inserts the GUIDELINE sheet as the first sheet.
"""
import math

from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

from xlsx_style import (BORDER_COLOR, CHAR_PER_WIDTH, FONT, LINE_HEIGHT, PURPLE, PURPLE_DARK,
                        PURPLE_LIGHT, PURPLE_PALE, SIZE)

WIDTHS = {1: 30, 2: 34, 3: 30, 4: 22, 5: 80}

STEPS = [
    ("1", "Copy this workbook. Keep both sheets: GUIDELINE (this page) and APB_DEC (the input)."),
    ("2", "Edit only the three tables of the sheet APB_DEC: Configuration, Master Configuration and "
          "Slaves Information. Keep every table title and header row as it is."),
    ("3", "Generate the decoder: python src/apb_dec_rtl_generator.py <file>.xlsx APB_DEC <output folder>. "
          "Any error stops the run with exit code 1 and writes no file."),
    ("4", "Generate the testbench: python src/apb_dec_tb_generator.py <output folder>/<module>.json "
          "<output folder>."),
    ("5", "Simulate with sim/verilator or sim/vcs, lint with lint/, or run `make test` and `make matrix`."),
]

FIELDS = [
    ("Module Name", "Configuration", "m_ + letters, digits, _ ; at most 30 characters", "m_vlsit_apbdec",
     "Name of the generated module and of its file <Module Name>.sv."),
    ("Address Width", "Master Configuration", "1 to 32", "24",
     "Width of the master address bus i_paddr, in bits."),
    ("Data Width", "Master Configuration", "8, 16 or 32", "32",
     "Width of i_pwdata, o_prdata and every slave data bus, in bits."),
    ("Write Strobe", "Master Configuration", "Data Width / 8", "Data Width / 8",
     "Width of i_pstrb. The row may be left out; a different value is an error."),
    ("Address Rebase", "Master Configuration", "0 or 1", "1",
     "1: every slave sees the offset inside its window (i_paddr - START). 0: every slave sees the raw "
     "low address bits (use only when an upstream stage already rebases the address; the generator "
     "warns when a START is not a multiple of 2^width)."),
    ("Register Inputs", "Master Configuration", "0 or 1", "0",
     "1: flip-flops on the inputs of the decoder (requester signals and slave read data and error). "
     "Adds the ports i_clk_apb and i_rst_n_apb. The APB protocol stays correct; see the options table."),
    ("Register Outputs", "Master Configuration", "0 or 1", "0",
     "1: flip-flops on the outputs of the decoder (slave side signals and the response to the "
     "requester). Adds the ports i_clk_apb and i_rst_n_apb. The APB protocol stays correct."),
    ("NAME", "Slaves Information", "letters, digits, _ ; not starting with a digit; at most 18 characters; "
     "unique ignoring case", "-",
     "Name of the slave. It ends every port name of the slave (lower case) and every constant (upper case)."),
    ("START ADDRESS", "Slaves Information", "0x hexadecimal text", "-",
     "First byte address of the window (inclusive). Any byte address."),
    ("END ADDRESS", "Slaves Information", "0x hexadecimal text, not below START", "-",
     "Last byte address of the window (inclusive), at most 2^Address Width - 1. Any byte address."),
    ("SIZE", "Slaves Information", "computed", "-",
     "END - START + 1 bytes. A spreadsheet value that differs from the computed one only gives a warning."),
    ("ADDRESS WIDTH", "Slaves Information", "computed", "-",
     "Width of the address port of the slave: max(1, clog2(SIZE)). Never enter it by hand."),
    ("DESCRIPTION", "Slaves Information", "free text", "-", "Comment written into the port list."),
]

RULES = [
    ("Windows", "Each window is a closed byte range START..END of any size and any alignment."),
    ("No overlap", "Two windows must not share an address. Windows that touch (END + 1 = next START) are legal."),
    ("Inside the bus", "END must not exceed 2^Address Width - 1."),
    ("Unmapped addresses", "An address in no window gets PREADY = 1, PRDATA = 0 and no slave select. The input pin "
                           "i_unmapped_err_en chooses the response at run time: 1 = PSLVERR (error), 0 = ready only."),
    ("Limits", "1 to 64 slaves; slave name up to 18 characters; module name up to 30 characters."),
    ("Old format", "A slave table with OFFSET / ADDRESS WIDTH columns (revision 0.1) is refused with a message."),
]

OPTIONS = [
    ("0", "0", "none", "0", "Pure combinational decoder: no clock, no reset, no added wait state."),
    ("1", "0", "i_clk_apb, i_rst_n_apb", "2",
     "Flip-flops on the requester inputs (i_paddr, i_pprot, i_psel, i_penable, i_pwrite, i_pwdata, i_pstrb) and on "
     "the slave read data and error inputs (i_prdata_*, i_pslverr_*)."),
    ("0", "1", "i_clk_apb, i_rst_n_apb", "2",
     "Flip-flops on every output: o_psel_*, o_penable_*, o_pwrite_*, o_paddr_*, o_pwdata_*, o_pstrb_*, o_pprot_*, "
     "o_pready, o_prdata, o_pslverr."),
    ("1", "1", "i_clk_apb, i_rst_n_apb", "4", "Both of the above."),
]

OPTION_NOTES = [
    ("Protocol", "In every combination the requester bus and every slave bus follow the APB4 protocol: one setup "
                 "cycle, then access cycles until PREADY, PENABLE only with PSEL, stable attributes, PSLVERR only in "
                 "the last cycle, one response per transfer. The decoder inserts wait states (PREADY low) for the "
                 "requester; a slave sees exactly one transfer."),
    ("Cycles added", "Counted on an unmapped transfer, which takes 2 cycles (setup and access) without options. A "
                     "mapped transfer takes the same number of extra cycles on top of what the slave needs."),
    ("Slave PREADY", "The slave PREADY pins are not registered for the end of the access: the slave must see its "
                     "transfer end in the cycle after it asserts PREADY, so the decoder uses the pin in that cycle."),
    ("Static pin", "i_unmapped_err_en is not registered; keep it constant while i_psel is high."),
    ("Area", "Register Inputs adds about (slaves x (data width + 1)) flip-flops for the slave read data and error."),
]

FILES = [
    ("<Module Name>.sv", "The decoder: one module in one file."),
    ("<Module Name>.json", "Resolved configuration (json_version 2): widths, windows, options."),
    ("<Module Name>_tb.sv", "Self-checking testbench (reference model, scoreboard, APB protocol checkers)."),
    ("filelist.f", "Files to compile, with $APB_DEC_GEN_HOME. The simulators also need sim/lib/*.sv."),
]


def _lines(text, width_chars):
    n = 0
    for part in str(text).split('\n'):
        n += max(1, math.ceil(len(part) / max(width_chars, 1)))
    return n


def add_guideline_sheet(wb):
    ws = wb.create_sheet('GUIDELINE', 0)
    thin = Side(style='thin', color=BORDER_COLOR)
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    ncols = 5
    for c, w in WIDTHS.items():
        ws.column_dimensions[chr(64 + c)].width = w

    def band(text, color, size=SIZE, height=34):
        ws.append([text])
        r = ws.max_row
        for c in range(1, ncols + 1):
            cell = ws.cell(r, c)
            cell.fill = PatternFill('solid', start_color=color, end_color=color)
            cell.font = Font(name=FONT, size=size, bold=True, color='FFFFFF')
            cell.alignment = Alignment(vertical='center', horizontal='left')
        ws.row_dimensions[r].height = height

    def table(headers, rows, spans):
        """headers: list of header texts; spans: the column index each header starts at (1 based)."""
        def put(values, header, index):
            ws.append([None] * ncols)
            r = ws.max_row
            nlines = 1
            for k, v in enumerate(values):
                c0 = spans[k]
                c1 = (spans[k + 1] - 1) if k + 1 < len(spans) else ncols
                if c1 > c0:
                    ws.merge_cells(start_row=r, start_column=c0, end_row=r, end_column=c1)
                ws.cell(r, c0).value = v
                width = sum(WIDTHS[c] for c in range(c0, c1 + 1))
                nlines = max(nlines, _lines(v, int((width - 1) * CHAR_PER_WIDTH)))
            for c in range(1, ncols + 1):
                cell = ws.cell(r, c)
                cell.border = border
                cell.alignment = Alignment(wrap_text=True, vertical='center',
                                           horizontal='center' if header else 'left')
                if header:
                    cell.fill = PatternFill('solid', start_color=PURPLE, end_color=PURPLE)
                    cell.font = Font(name=FONT, size=SIZE, bold=True, color='FFFFFF')
                else:
                    color = PURPLE_PALE if index % 2 else 'FFFFFF'
                    cell.fill = PatternFill('solid', start_color=color, end_color=color)
                    cell.font = Font(name=FONT, size=SIZE, color='000000')
            ws.row_dimensions[r].height = max(30, nlines * LINE_HEIGHT + 8)
        put(headers, True, 0)
        for i, row in enumerate(rows):
            put(row, False, i)
        ws.append([])

    band("APB-DEC-Generator workbook format (common to the template and every example)", PURPLE_DARK, 16, 40)
    ws.append(["This sheet explains how to fill the sheet APB_DEC. The generator reads only the sheet APB_DEC; "
               "this sheet is documentation."])
    ws.merge_cells(start_row=ws.max_row, start_column=1, end_row=ws.max_row, end_column=ncols)
    cell = ws.cell(ws.max_row, 1)
    cell.font = Font(name=FONT, size=SIZE, italic=True, color='3B1F5C')
    cell.fill = PatternFill('solid', start_color=PURPLE_LIGHT, end_color=PURPLE_LIGHT)
    cell.alignment = Alignment(wrap_text=True, vertical='center')
    ws.row_dimensions[ws.max_row].height = 56
    ws.append([])

    band("1. How to use this workbook", PURPLE_DARK)
    table(["Step", "Action"], STEPS, [1, 2])
    band("2. Field reference of the sheet APB_DEC", PURPLE_DARK)
    table(["Field", "Table", "Allowed values", "Default", "Meaning"], FIELDS, [1, 2, 3, 4, 5])
    band("3. Rules and limits", PURPLE_DARK)
    table(["Topic", "Rule"], RULES, [1, 2])
    band("4. Register options: flip-flops on the inputs and on the outputs", PURPLE_DARK)
    table(["Register Inputs", "Register Outputs", "Extra ports", "Cycles added", "Flip-flops on"], OPTIONS,
          [1, 2, 3, 4, 5])
    table(["Topic", "Note"], OPTION_NOTES, [1, 2])
    band("5. Generated files", PURPLE_DARK)
    table(["File", "Content"], FILES, [1, 2])
    band("Revision 0.3: START/END windows, computed port widths, pin-selected unmapped response, register options",
         PURPLE, SIZE, 34)
    ws.sheet_view.showGridLines = False
    ws.sheet_properties.tabColor = PURPLE
    return ws
