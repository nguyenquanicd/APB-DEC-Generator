#!/usr/bin/env bash
set -euo pipefail

verilator --lint-only --sv -Wall \
  --top-module m_vlsit_apbdec \
  -f ${APB_DEC_GEN_HOME}/output/filelist.f \
  "$@"
