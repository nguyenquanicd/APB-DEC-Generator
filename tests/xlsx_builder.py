"""Builds APB_DEC workbooks (revision 0.2 schema, and the revision 0.1 schema for negative tests).

Used by the examples (examples/make_examples.py) and by the tests.
"""
import openpyxl

from xlsx_guideline import add_guideline_sheet
from xlsx_style import apply_style


def _size_formula(r):
    n = f"$H{r}"
    return (f'=IF({n}<1024,{n}&" B",IF({n}<1048576,{n}/1024&" KB",'
            f'IF({n}<1073741824,{n}/1048576&" MB",{n}/1073741824&" GB")))')


def write_workbook(path, module='m_vlsit_apbdec', aw=24, dw=32, rebase=1, slaves=(),
                   strobe='auto', formulas=True, schema='new', sheet='APB_DEC',
                   extra_master=(), cached=None, style=True, reg_in=None, reg_out=None, guideline=False):
    """Write one workbook.

    slaves: list of (name, start, end[, description]) with start/end as '0x..' text.
    strobe: 'auto' = dw/8, None = row omitted, or an integer.
    formulas: write SIZE and ADDRESS WIDTH as Excel formulas (new schema).
    schema: 'new' (START/END) or 'old' (OFFSET, ADDRESS WIDTH, revision 0.1).
    extra_master: additional (Config, Value, Description) rows.
    style: apply the purple Arial 13 style (xlsx_style.apply_style).
    cached: dict {'SIZE': text, 'ADDRESS WIDTH': int} written as plain values instead of formulas.
    """
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet
    ws.append(['Table - Configuration'])
    ws.append(['Config', 'Value', 'Description'])
    ws.append(['Module Name', module, 'Name of the generated top module (m_ prefix, at most 30 characters).'])
    ws.append([])
    ws.append(['Table - Master Configuration'])
    ws.append(['Config', 'Value', 'Description'])
    ws.append(['Address Width', aw, 'Bit width of the master APB address bus (1 to 32).'])
    r_aw = ws.max_row
    ws.append(['Max Address', f'="0x" & DEC2HEX(2^$B${r_aw}-1)' if formulas else None,
               'Highest address of the master bus (informative, not read by the generator).'])
    ws.append(['Data Width', dw, 'Bit width of the APB data buses: 8, 16 or 32.'])
    if strobe == 'auto':
        ws.append(['Write Strobe', dw // 8, 'Byte strobes (PSTRB): Data Width / 8.'])
    elif strobe is not None:
        ws.append(['Write Strobe', strobe, 'Byte strobes (PSTRB): Data Width / 8.'])
    ws.append(['Address Rebase', rebase,
               '1: every slave sees the offset inside its window (o_paddr = i_paddr - START). '
               '0: every slave sees the raw low address bits (use only when an upstream stage '
               'already rebases the address).'])
    if reg_in is not None:
        ws.append(['Register Inputs', reg_in, 'Flip-flops on the inputs of the decoder (0 or 1).'])
    if reg_out is not None:
        ws.append(['Register Outputs', reg_out, 'Flip-flops on the outputs of the decoder (0 or 1).'])
    for row in extra_master:
        ws.append(list(row))
    ws.append([])
    ws.append(['Table - Slaves Information'])
    if schema == 'new':
        ws.append(['NO.', 'NAME', 'START ADDRESS', 'END ADDRESS', 'SIZE', 'ADDRESS WIDTH',
                   'DESCRIPTION', 'SIZE BYTES'])
        ws.append([None, None, 'First byte of the window (0x hex, inclusive)',
                   'Last byte of the window (0x hex, inclusive)',
                   'Window size (computed)', 'Address port width of the slave (computed)',
                   None, 'Window size in bytes (computed)'])
        for i, sl in enumerate(slaves, start=1):
            name, start, end = sl[0], sl[1], sl[2]
            desc = sl[3] if len(sl) > 3 else None
            r = ws.max_row + 1
            if formulas:
                bytes_f = (f'=HEX2DEC(SUBSTITUTE(D{r},"0x",""))-'
                           f'HEX2DEC(SUBSTITUTE(C{r},"0x",""))+1')
                size_v = _size_formula(r)
                width_v = f'=MAX(1,ROUNDUP(LOG(H{r},2)-1E-9,0))'
            else:
                bytes_f, size_v, width_v = None, None, None
            if cached:
                size_v = cached.get('SIZE', size_v)
                width_v = cached.get('ADDRESS WIDTH', width_v)
            ws.append([i, name, start, end, size_v, width_v, desc, bytes_f])
    else:
        ws.append(['NO.', 'NAME', 'ADDRESS WIDTH', 'OFFSET', 'SIZE', 'END ADDRESS', 'DESCRIPTION'])
        for i, sl in enumerate(slaves, start=1):
            ws.append([i, sl[0], sl[3], sl[1], None, sl[2], None])
    if style:
        apply_style(ws)
    if guideline:
        add_guideline_sheet(wb)
    wb.save(path)
    return path
