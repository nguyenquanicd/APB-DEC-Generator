#------------------------------------------------------------------------------
# Synopsys Lint Run Script
#------------------------------------------------------------------------------

# Project inputs
set FILELIST   ../../output/filelist.f
set DEFINES    ""

# Bug #8 fix: TOP_DESIGN used to be hardcoded to the shipped example's
# module name (m_vlsit_apbdec), so lint silently elaborated the wrong (or a
# nonexistent) module for any other config. apb_dec_rtl_generator.py now
# writes output/.module_name with whatever Module Name the Excel config
# resolved to; fall back to the example's name only if that marker is
# missing (e.g. this script is run before `make rtl`).
set MODULE_NAME_FILE "../../output/.module_name"
if {[file exists $MODULE_NAME_FILE]} {
  set fp [open $MODULE_NAME_FILE r]
  set TOP_DESIGN [string trim [read $fp]]
  close $fp
} else {
  puts "\[WARN\] $MODULE_NAME_FILE not found (run 'make rtl' first) -- falling back to 'm_vlsit_apbdec'."
  set TOP_DESIGN m_vlsit_apbdec
}

# Lint setup
set enable_lint true
configure_lint_setup
configure_lint_tag_parameter \
  -tag W123 \
  -parameter HANDLE_LARGE_BUS \
  -value yes \
  -goal lint_rtl_enhanced

# Parse and elaborate
analyze \
  -format sverilog \
  -vcs "-f $FILELIST" \
  -define "$DEFINES -timescale=1ns/10ps +lint=TFIPC-L"
elaborate $TOP_DESIGN

# Run checks
check_lint

# Waive
waive_lint -add "NoFeedThrus-ML" -tag "NoFeedThrus-ML"

# Open GUI
start_gui
