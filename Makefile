# APB Decoder Generator Makefile (revision 0.2)

# Windows PowerShell: use uv to run Python with the dependencies in requirements.txt.
PYTHON := uv run --with-requirements requirements.txt python
# Linux: comment out the Windows line above and uncomment this line.
# PYTHON := uv run --with-requirements requirements.txt python3
RTL_GEN := src/apb_dec_rtl_generator.py
TB_GEN := src/apb_dec_tb_generator.py

EXCEL := examples/ex_default/ex_default.xlsx
SHEET := APB_DEC
OUTPUT_DIR := output

# apb_dec_rtl_generator.py writes output/.module_name with the resolved module name; it is read
# back here (the example name is only the fallback before the first `make rtl`).
MODULE_NAME = $(shell cat $(OUTPUT_DIR)/.module_name 2>/dev/null || echo m_vlsit_apbdec)
JSON_CONFIG = $(OUTPUT_DIR)/$(MODULE_NAME).json

.PHONY: all rtl tb examples test matrix coverage clean help

all: rtl tb

rtl:
	@$(PYTHON) $(RTL_GEN) $(EXCEL) $(SHEET) $(OUTPUT_DIR)

tb: rtl
	@$(PYTHON) $(TB_GEN) $(JSON_CONFIG) $(OUTPUT_DIR)

# Rewrite the example workbooks and generate RTL, JSON and testbench of each one.
examples:
	@$(PYTHON) examples/make_examples.py
	@$(PYTHON) examples/run_examples.py

# Unit tests of both generators, mutation tests of the testbench, simulation of every example.
test:
	@$(PYTHON) -m unittest discover -s tests

# Every option combination: scenario x data width (8, 16, 32) x address rebase (0, 1).
matrix:
	@$(PYTHON) tests/run_matrix.py --jobs 4

# Coverage: line coverage of the generator scripts, line/toggle coverage of the generated RTL.
coverage:
	@$(PYTHON) tests/cov_python.py --min 80
	@$(PYTHON) tests/cov_matrix.py --min 80

clean:
	# `output/*` alone does not match dotfiles (e.g. .module_name) in a plain
	# shell glob, which used to leave a stale module name behind after
	# `make clean`; remove the whole directory instead (it is recreated
	# automatically by the generator scripts).
	rm -rf $(OUTPUT_DIR)

help:
	@echo "APB Decoder Generator Targets:"
	@echo "  make all      - Generate both RTL and TB"
	@echo "  make rtl      - Generate RTL only (one RTL file + JSON config + filelist)"
	@echo "  make tb       - Generate TB only (testbench + filelist)"
	@echo "  make examples - Rewrite the example workbooks and generate every example"
	@echo "  make test     - Unit, mutation and example simulation tests"
	@echo "  make matrix   - Simulate every option combination"
	@echo "  make coverage - Generator line coverage and RTL line/toggle coverage (minimum 80%)"
	@echo "  make clean    - Remove all generated files"
	@echo ""
	@echo "Variables:"
	@echo "  EXCEL=<file>  - Specify Excel file (default: examples/ex_default/ex_default.xlsx)"
	@echo "  SHEET=<name>  - Specify sheet name (default: APB_DEC, required by the schema)"
	@echo ""
	@echo "Examples:"
	@echo "  make rtl EXCEL=my_config.xlsx"
	@echo "  make all EXCEL=examples/ex_reg_in_out/ex_reg_in_out.xlsx SHEET=APB_DEC"
