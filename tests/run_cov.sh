#!/bin/sh
# Line, branch and toggle coverage of the generated decoder RTL with Verilator.
# Usage: sh tests/run_cov.sh <workbook.xlsx> <tag>
# Output: tests/cov_work/<tag>/coverage.dat; report with tests/cov_report.py
# Needs (Windows): OSS CAD Suite (verilator_bin.exe), MinGW g++ (MSYS2 ucrt64) and a junction
# C:\yosyshq\share\verilator -> <OSS CAD>\share\verilator (the suite looks for its library there).
# make is not used (its temporary files fail in this environment): g++ compiles the objects.
# Paths can be set with OSS_CAD_POSIX, MSYS_UCRT_POSIX, VERILATOR_ROOT_WIN and PYTHON.
XLSX=${1:?workbook}
TAG=${2:?tag}
OSS_P=${OSS_CAD_POSIX:-/c/Tools/oss-cad-suite}
GCC_P=${MSYS_UCRT_POSIX:-/c/Users/PC/Tools/msys64/ucrt64}
PY=${PYTHON:-python}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
WORK=${COV_WORK:-$HERE/cov_work}/$TAG
PATH="$GCC_P/bin:$OSS_P/bin:$PATH"
export PATH
VERILATOR_ROOT=${VERILATOR_ROOT_WIN:-'C:\Tools\oss-cad-suite\share\verilator'}
export VERILATOR_ROOT
INC=$OSS_P/share/verilator/include
mkdir -p "$WORK" || exit 1
HERE_W=$(cygpath -w "$HERE" 2>/dev/null || echo "$HERE")
XLSX_W=$(cygpath -w "$XLSX" 2>/dev/null || echo "$XLSX")
WORK_W=$(cygpath -w "$WORK" 2>/dev/null || echo "$WORK")
"$PY" -c "
import sys
sys.path.insert(0, r'$HERE_W')
import sim_flow
cfg, w, files = sim_flow.generate(r'$XLSX_W', r'$WORK_W\gen')
open(r'$WORK_W\gen\top.txt', 'w').write(cfg['module_name'])
open(r'$WORK_W\gen\files.txt', 'w').write(' '.join(files))
" || exit 1
MOD=$(cat "$WORK/gen/top.txt")
FILES=""
for f in $(cat "$WORK/gen/files.txt"); do FILES="$FILES $WORK/gen/$f"; done
rm -rf "$WORK/obj"
verilator_bin.exe --cc --exe --timing --coverage-line --coverage-toggle --Mdir "$WORK/obj" \
  -Wno-fatal -Wno-lint -Wno-style --top-module ${MOD}_tb \
  $FILES "$WORK/gen/${MOD}_tb.sv" "$ROOT/sim/lib/apb_protocol_checker.sv" "$ROOT/sim/lib/apb_master_bfm.sv" "$ROOT/sim/lib/apb_slave_bfm.sv" \
  --prefix Vcov > "$WORK/verilator.log" 2>&1 || { tail -20 "$WORK/verilator.log"; exit 1; }
cd "$WORK/obj" || exit 1
CXXFLAGS="-O1 -w -I. -I$INC -I$INC/vltstd -DVERILATOR=1 -DVM_COVERAGE=1 -DVM_SC=0 -DVM_TIMING=1 \
 -DVM_TRACE=0 -DVM_TRACE_FST=0 -DVM_TRACE_VCD=0 -DVM_TRACE_SAIF=0 -DVM_VPI=0 -faligned-new \
 -fcf-protection=none -std=gnu++20"
for f in Vcov*.cpp "$HERE/cov_main.cpp" "$INC/verilated.cpp" "$INC/verilated_cov.cpp" \
         "$INC/verilated_covergroup.cpp" "$INC/verilated_threads.cpp" "$INC/verilated_timing.cpp"; do
  echo "$f"
done > srcs.txt
xargs -P 6 -I SRC sh -c "g++ $CXXFLAGS -c SRC -o \$(basename SRC .cpp).o" < srcs.txt || exit 1
g++ -Wl,--stack,536870912 -o Vcov_bin.exe ./*.o || exit 1
cd "$WORK" || exit 1
./obj/Vcov_bin.exe +cov_out="$WORK/coverage.dat" | tee sim.log
grep -q "OVERALL RESULT: PASS" sim.log
