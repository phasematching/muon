# Makefile for FPGA Coincidence Detector
#
# Supports both simulation (Icarus Verilog) and synthesis (Vivado)
#
# Targets:
#   make sim      - Run simulation with Icarus Verilog
#   make synth    - Synthesize with Vivado
#   make clean    - Clean build artifacts
#
# Requirements:
#   - Icarus Verilog (iverilog) for simulation
#   - Vivado for synthesis

# Directories
RTL_DIR = rtl
SIM_DIR = sim
SCRIPTS_DIR = scripts
BUILD_DIR = build

# RTL source files
RTL_SOURCES = \
	$(RTL_DIR)/threshold_detector.v \
	$(RTL_DIR)/coincidence_logic.v \
	$(RTL_DIR)/axi_lite_regs.v \
	$(RTL_DIR)/coincidence_detector.v

# Testbench files
TB_SOURCES = \
	$(SIM_DIR)/tb_coincidence_detector.v

# Simulation executable
SIM_EXE = $(BUILD_DIR)/sim_coincidence

# Vivado project
VIVADO_PROJECT = coincidence_detector

.PHONY: all sim synth clean help

all: sim

help:
	@echo "FPGA Coincidence Detector Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make sim      - Run simulation with Icarus Verilog"
	@echo "  make synth    - Synthesize with Vivado (requires Vivado)"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  Simulation: Icarus Verilog (iverilog)"
	@echo "  Synthesis: Xilinx Vivado"

# Simulation with Icarus Verilog
sim: $(BUILD_DIR) $(RTL_SOURCES) $(TB_SOURCES)
	@echo "Compiling with Icarus Verilog..."
	iverilog -g2012 -o $(SIM_EXE) \
		-I$(RTL_DIR) \
		$(RTL_SOURCES) \
		$(TB_SOURCES)
	@echo "Running simulation..."
	cd $(BUILD_DIR) && ./sim_coincidence
	@echo ""
	@echo "Simulation complete. Waveform saved to $(BUILD_DIR)/tb_coincidence_detector.vcd"
	@echo "View with: gtkwave $(BUILD_DIR)/tb_coincidence_detector.vcd"

# Synthesis with Vivado
synth: $(BUILD_DIR)
	@echo "Starting Vivado synthesis..."
	@if ! command -v vivado &> /dev/null; then \
		echo "ERROR: Vivado not found in PATH"; \
		echo "Please source Vivado settings: source /tools/Xilinx/Vivado/*/settings64.sh"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && vivado -mode batch -source ../$(SCRIPTS_DIR)/vivado_synth.tcl
	@echo ""
	@echo "Synthesis complete. Check $(BUILD_DIR) for results."

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "Build artifacts cleaned"

# Syntax check only (no simulation)
check: $(RTL_SOURCES)
	@echo "Checking RTL syntax..."
	iverilog -g2012 -t null $(RTL_SOURCES)
	@echo "Syntax check passed"
