# Makefile for RISC-V RV32I Single-Cycle CPU Testbench
# Uses VCS for simulation and FSDB for waveform dumping

# Directories
RTL_DIR    := $(APB_DEC_GEN_HOME)/output
SIM_ROOT   := $(APB_DEC_GEN_HOME)/sim
SIM_DIR    := $(shell pwd)

# Compiler
VCS = vcs

# Source file lists
RTL_FILELIST  = $(RTL_DIR)/filelist.f
TB_LIB_SRCS   = $(SIM_ROOT)/lib/apb_slave_bfm.sv \
                $(SIM_ROOT)/lib/apb_master_bfm.sv 
TB_BUILD_SRCS = $(TB_LIB_SRCS) $(TB_LOCAL)

# VCS flags
VCS_FLAGS = -full64 \
            -sverilog \
            +v2k \
            -debug_access+all \
            -timescale=1ns/1ps \
            -kdb \
						+define+VCS

# Build targets
.PHONY: all clean run simv

all: simv

simv: $(RTL_FILELIST) $(TB_LIB_SRCS)
	@mkdir -p $(SIM_DIR)
	APB_DEC_GEN_HOME=$(APB_DEC_GEN_HOME) $(VCS) $(VCS_FLAGS) -f $(RTL_FILELIST) $(TB_BUILD_SRCS) -o $(SIM_DIR)/simv

# Run simulation
run: simv
	cd $(SIM_DIR) && ./simv +fsdb+file=$(SIM_DIR)/wave.fsdb

# Run with GUI (Verdi)
verdi: simv
	cd $(SIM_DIR) && ./simv +fsdb+file=$(SIM_DIR)/wave.fsdb
	verdi -ssf $(SIM_DIR)/wave.fsdb &

# Clean build artifacts
clean:
	rm -rf csrc simv DVEfiles AN.DB *.fsdb *.vcd *.log tb.sv simv.daidir
	rm -f $(TEST_DIR)/*.elf $(TEST_DIR)/*.bin $(TEST_DIR)/*.dump
