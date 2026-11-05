"""Purple style of the APB_DEC workbooks: Arial 13, bold table titles and headers, columns wide
enough to read every text, wrapped text, thin purple borders.

apply_style(ws) works on the layout written by xlsx_builder (title row 'Table - ...', header row,
optional hint row, data rows, blank row between tables). The Config / Value / Description tables
merge the description over the columns C to G so that the long text does not widen column C.
"""
import math

from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

FONT = 'Arial'
SIZE = 13
PURPLE_DARK = '4B1D6B'      # table titles
PURPLE = '7030A0'           # column headers
PURPLE_LIGHT = 'E9DDF4'     # hint row
PURPLE_PALE = 'F7F2FB'      # every second data row
BORDER_COLOR = '7030A0'
MERGE_FROM, MERGE_TO = 3, 7
MAX_PLAIN_WIDTH = 34        # columns wider than this wrap their text
MIN_WIDTH = 18              # narrowest column
CHAR_PER_WIDTH = 0.85       # characters of Arial 13 per column-width unit
LINE_HEIGHT = 19.5          # points of one text line at 13 pt


def _fill(color):
    return PatternFill('solid', start_color=color, end_color=color)


def _lines(text, width_chars):
    n = 0
    for part in str(text).split('\n'):
        n += max(1, math.ceil(len(part) / max(width_chars, 1)))
    return n


def apply_style(ws):
    thin = Side(style='thin', color=BORDER_COLOR)
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    last_col = ws.max_column
    # ---- classify the rows
    kinds, state, header_cols = {}, None, None
    for r in range(1, ws.max_row + 1):
        cells = [ws.cell(r, c).value for c in range(1, last_col + 1)]
        if all(v is None for v in cells):
            state = None
            continue
        first = cells[0]
        if isinstance(first, str) and first.startswith('Table -'):
            kinds[r] = 'title'
            state = 'after_title'
            continue
        if state == 'after_title':
            kinds[r] = 'header'
            header_cols = [v for v in cells if v is not None]
            state = 'data'
            continue
        if state == 'data' and cells[0] is None and cells[1] is None and 'NO.' in (header_cols or []):
            kinds[r] = 'hint'
            state = 'rows'
            continue
        kinds[r] = 'data'
        state = 'rows'
    # ---- merge the description columns of the two-column tables
    merged = set()
    table_is_cvd = False
    for r in range(1, ws.max_row + 1):
        k = kinds.get(r)
        if k == 'title':
            table_is_cvd = False
        elif k == 'header':
            table_is_cvd = ws.cell(r, 1).value == 'Config'
        if k in ('header', 'data') and table_is_cvd:
            ws.merge_cells(start_row=r, start_column=MERGE_FROM, end_row=r, end_column=MERGE_TO)
            merged.add(r)
    # ---- column widths from the cells that are not merged
    widths = {}
    for c in range(1, last_col + 1):
        longest = 6
        for r in range(1, ws.max_row + 1):
            if kinds.get(r) in ('title', 'hint'):          # hint texts wrap; titles overflow
                continue
            if r in merged and MERGE_FROM <= c <= MERGE_TO:
                continue
            v = ws.cell(r, c).value
            if v is None:
                continue
            if isinstance(v, str) and v.startswith('='):   # a formula shows a short result
                longest = max(longest, 14)
                continue
            longest = max(longest, max(len(p) for p in str(v).split('\n')))
        widths[c] = max(min(round(longest * 1.22 + 3), MAX_PLAIN_WIDTH + 3), MIN_WIDTH)
    for c, w in widths.items():
        ws.column_dimensions[get_column_letter(c)].width = w
    merged_width = sum(widths.get(c, 12) for c in range(MERGE_FROM, MERGE_TO + 1))
    # ---- cell styles and row heights
    data_index = 0
    for r in range(1, ws.max_row + 1):
        k = kinds.get(r)
        if k is None:
            continue
        if k == 'title':
            data_index = 0
        nlines = 1
        for c in range(1, last_col + 1):
            cell = ws.cell(r, c)
            if k == 'title':
                bold, color, fill, ital = True, 'FFFFFF', PURPLE_DARK, False
            elif k == 'header':
                bold, color, fill, ital = True, 'FFFFFF', PURPLE, False
            elif k == 'hint':
                bold, color, fill, ital = False, '3B1F5C', PURPLE_LIGHT, True
            else:
                bold, color, ital = False, '000000', False
                fill = PURPLE_PALE if data_index % 2 else 'FFFFFF'
            cell.font = Font(name=FONT, size=SIZE, bold=bold, italic=ital, color=color)
            if k == 'title':
                # the whole title row is one purple band
                cell.fill = _fill(fill)
                cell.alignment = Alignment(vertical='center', horizontal='left')
                continue
            has_text = cell.value is not None or (r in merged and MERGE_FROM <= c <= MERGE_TO)
            cell.fill = _fill(fill)
            cell.border = border
            cell.alignment = Alignment(wrap_text=True, vertical='center',
                                       horizontal='center' if k == 'header' else 'left')
            if cell.value is not None and not (isinstance(cell.value, str) and cell.value.startswith('=')):
                w = merged_width if (r in merged and c == MERGE_FROM) else widths.get(c, 12)
                nlines = max(nlines, _lines(cell.value, int((w - 1) * CHAR_PER_WIDTH)))
        if k != 'title':
            data_index += 1
        ws.row_dimensions[r].height = max(30, nlines * LINE_HEIGHT + 8)
        if k == 'title':
            ws.row_dimensions[r].height = 30
    ws.sheet_view.showGridLines = False
    ws.sheet_properties.tabColor = PURPLE
