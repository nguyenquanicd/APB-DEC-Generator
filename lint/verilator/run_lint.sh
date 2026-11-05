#!/usr/bin/env bash
set -euo pipefail

# Bug #8 fix: the top module name used to be hardcoded to the shipped
# example's name (m_vlsit_apbdec), so lint silently targeted the wrong (or a
# nonexistent) module for any other config. apb_dec_rtl_generator.py now
# writes output/.module_name with whatever Module Name the Excel config
# resolved to; fall back to the example's name only if that marker is
# missing (e.g. this script is run before `make rtl`).
MODULE_NAME_FILE="${APB_DEC_GEN_HOME}/output/.module_name"
if [ -f "${MODULE_NAME_FILE}" ]; then
  TOP_MODULE="$(cat "${MODULE_NAME_FILE}")"
else
  echo "[WARN] ${MODULE_NAME_FILE} not found (run 'make rtl' first) -- " \
       "falling back to the example module name 'm_vlsit_apbdec'." >&2
  TOP_MODULE="m_vlsit_apbdec"
fi

verilator --lint-only --sv -Wall \
  --top-module "${TOP_MODULE}" \
  -f "${APB_DEC_GEN_HOME}/output/filelist.f" \
  "$@"
