# Makefile for RISC-V RV32I Single-Cycle CPU Testbench (Verilator)

# Directories
RTL_DIR    := $(APB_DEC_GEN_HOME)/output
SIM_ROOT   := $(APB_DEC_GEN_HOME)/sim
SIM_DIR    := $(shell pwd)

# Tool
VERILATOR ?= verilator

# Source file lists
RTL_FILELIST  = $(RTL_DIR)/filelist.f
TB_LIB_SRCS   = $(SIM_ROOT)/lib/apb_slave_bfm.sv \
                $(SIM_ROOT)/lib/apb_master_bfm.sv 
TB_BUILD_SRCS = $(TB_LIB_SRCS) $(TB_LOCAL)

# Verilator flags
VL_FLAGS = --binary \
           --sv \
           --timing \
           --trace \
           --Mdir $(OBJ_DIR) \
           -Wno-fatal

# Build targets
.PHONY: all clean run simv

all: simv

simv: $(RTL_FILELIST) $(TB_LIB_SRCS)
	@mkdir -p $(SIM_DIR)
	APB_DEC_GEN_HOME=$(APB_DEC_GEN_HOME) $(VERILATOR) $(VL_FLAGS) -f $(RTL_FILELIST) $(TB_BUILD_SRCS) -o $(SIM_DIR)/simv
	#
# Run simulation
run: simv
	cd $(SIM_DIR) && ./simv

clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)/simv $(SIM_DIR)/simv.d $(SIM_DIR)/*.vcd $(SIM_DIR)/*.log
	rm -f $(TEST_DIR)/*.elf $(TEST_DIR)/*.bin $(TEST_DIR)/*.dump
