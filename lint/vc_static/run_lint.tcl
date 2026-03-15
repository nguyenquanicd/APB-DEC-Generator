#------------------------------------------------------------------------------
# Synopsys Lint Run Script
#------------------------------------------------------------------------------

# Project inputs
set FILELIST   ../../output/filelist.f
set DEFINES    ""
set TOP_DESIGN m_vlsit_apbdec

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
