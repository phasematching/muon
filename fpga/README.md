# FPGA Coincidence Detector

This directory contains the FPGA implementation of hardware-accelerated coincidence detection for the Red Pitaya.

## Overview

The FPGA implementation provides:
- **8 ns timing resolution** (125 MHz clock)
- **Real-time coincidence detection** with no dead time
- **Programmable thresholds** for both channels
- **Configurable coincidence window** (10 ns to 34 ms)
- **AXI-Lite interface** for software control
- **Event counters** with 32-bit resolution

## Directory Structure

```
fpga/
├── rtl/                           # RTL source files
│   ├── coincidence_detector.v     # Top-level module
│   ├── threshold_detector.v       # Threshold comparator
│   ├── coincidence_logic.v        # Coincidence window logic
│   └── axi_lite_regs.v           # AXI-Lite register interface
├── sim/                           # Simulation files
│   └── tb_coincidence_detector.v  # Testbench
├── scripts/                       # Build scripts
│   └── vivado_synth.tcl          # Vivado synthesis script
├── constraints/                   # Timing/pin constraints (user-provided)
├── build/                         # Build output (generated)
├── Makefile                       # Build system
└── README.md                      # This file
```

## Hardware Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Coincidence Detector                       │
│                                                              │
│  ADC A (14-bit)  ──┐                                        │
│                    │                                        │
│                    ├──► Threshold  ──┐                      │
│                    │    Detector A    │                     │
│                                       │                     │
│                                       ├──► Coincidence  ──► │
│                                       │    Logic            │
│  ADC B (14-bit)  ──┐                  │                     │
│                    │                  │                     │
│                    ├──► Threshold  ──┘                      │
│                    │    Detector B                          │
│                                                              │
│  AXI-Lite  ◄──────► AXI Register Interface                  │
│                     (Control, Status, Counters)             │
└─────────────────────────────────────────────────────────────┘
```

## Register Map

Software accesses the FPGA via memory-mapped registers:

| Address | Name              | Access | Description                           |
|---------|-------------------|--------|---------------------------------------|
| 0x000   | CONTROL           | R/W    | Control register                      |
|         |                   |        | [0]: Enable detection                 |
|         |                   |        | [1]: Reset counters                   |
| 0x004   | STATUS            | R/O    | Status register                       |
| 0x008   | THRESHOLD_A       | R/W    | Threshold for channel A (signed)      |
| 0x00C   | THRESHOLD_B       | R/W    | Threshold for channel B (signed)      |
| 0x010   | COINC_WINDOW      | R/W    | Coincidence window (clock cycles)     |
| 0x014   | COUNT_A           | R/O    | Event counter for channel A           |
| 0x018   | COUNT_B           | R/O    | Event counter for channel B           |
| 0x01C   | COUNT_COINC       | R/O    | Coincidence counter                   |
| 0x020   | VERSION           | R/O    | Version/ID (0x00010000 = v1.0)        |

## Building the FPGA Bitstream

### Prerequisites

**For Simulation:**
- Icarus Verilog (`iverilog`) - Free, open-source
- GTKWave (optional, for waveform viewing)

**For Synthesis:**
- Xilinx Vivado (2019.1 or later)
- Red Pitaya development environment

### Quick Start - Simulation

Test the design without FPGA hardware:

```bash
cd fpga
make sim
```

This will:
1. Compile the RTL with Icarus Verilog
2. Run the testbench
3. Generate waveform file: `build/tb_coincidence_detector.vcd`

View the waveform:
```bash
gtkwave build/tb_coincidence_detector.vcd
```

### Synthesis for Red Pitaya

#### Step 1: Install Vivado

Download and install Xilinx Vivado from:
https://www.xilinx.com/support/download.html

Source the settings:
```bash
source /tools/Xilinx/Vivado/2020.1/settings64.sh
```

#### Step 2: Run Synthesis

```bash
cd fpga
make synth
```

This creates a Vivado project and runs synthesis. Check the reports:
- `build/utilization_synth.rpt` - Resource usage
- `build/timing_synth.rpt` - Timing analysis

#### Step 3: Implementation and Bitstream Generation

Option A - Vivado GUI (recommended for first-time users):
```bash
vivado build/coincidence_detector.xpr
```

Then in Vivado:
1. Click "Run Implementation"
2. Wait for completion
3. Click "Generate Bitstream"
4. Bitstream saved to: `build/coincidence_detector.runs/impl_1/coincidence_detector.bit`

Option B - Command line (advanced):
```bash
cd fpga/build
vivado -mode batch -source ../scripts/vivado_impl.tcl
```

### Integrating with Red Pitaya System

The coincidence detector needs to be integrated into the Red Pitaya FPGA design. This involves:

1. **Adding to Red Pitaya project**:
   - Clone Red Pitaya FPGA repository
   - Add coincidence detector as a module
   - Connect to ADC inputs and PS (ARM processor)

2. **Memory mapping**:
   - Assign AXI base address in the address map
   - Update device tree for Linux driver

3. **Building complete system**:
   - Use Red Pitaya build system
   - Generate complete bitstream with OS integration

Detailed instructions: See Red Pitaya documentation at
https://redpitaya.readthedocs.io/en/latest/developerGuide/fpga.html

## Loading Bitstream to Red Pitaya

Once you have the bitstream:

```bash
# Copy to Red Pitaya
scp coincidence_detector.bit root@<red-pitaya-ip>:/root/

# SSH to Red Pitaya
ssh root@<red-pitaya-ip>

# Load bitstream
cat /root/coincidence_detector.bit > /dev/xdevcfg
```

## Software Interface

The Python software (`src/fpga_coincidence.py`) interfaces with the FPGA via:

1. Memory-mapped I/O using `/dev/mem`
2. Reading/writing registers at the base address
3. Polling event counters

Example register access (in C or Python with mmap):
```c
// Enable detector
*((uint32_t*)(base_addr + 0x000)) = 0x00000001;

// Set threshold A to 819 (0.1V)
*((int32_t*)(base_addr + 0x008)) = 819;

// Read coincidence count
uint32_t coinc = *((uint32_t*)(base_addr + 0x01C));
```

## Customization

### Changing Timing Resolution

The timing resolution is set by the FPGA clock frequency. The Red Pitaya uses 125 MHz (8 ns period) by default.

To use a different clock:
1. Modify the clock frequency in your design
2. Update the `window_cycles` calculation in `src/fpga_coincidence.py`

### Adding Features

Possible enhancements:
- **Timestamp capture**: Record exact time of each coincidence
- **Pulse height measurement**: Capture ADC peak value
- **Multiple channels**: Extend to 3+ detectors
- **Time-of-flight**: Measure delay between channels
- **Trigger output**: Generate external trigger signal

## Resource Utilization

Typical resource usage on Zynq-7010 (Red Pitaya STEMlab 125-10):

| Resource       | Used | Available | Utilization |
|----------------|------|-----------|-------------|
| LUTs           | ~150 | 17,600    | <1%         |
| Flip-Flops     | ~200 | 35,200    | <1%         |
| DSP Slices     | 0    | 80        | 0%          |
| Block RAM      | 0    | 60        | 0%          |

Very small footprint - plenty of room for expansion!

## Verification

The testbench (`sim/tb_coincidence_detector.v`) verifies:
1. ✓ Threshold detection on both channels
2. ✓ Coincidence detection within window
3. ✓ Rejection of non-coincident events
4. ✓ Event counter functionality
5. ✓ AXI register read/write

Run tests: `make sim`

## Troubleshooting

**Simulation fails:**
- Check that Icarus Verilog is installed: `iverilog -v`
- Install on Ubuntu: `sudo apt-get install iverilog gtkwave`

**Synthesis fails:**
- Ensure Vivado is in PATH: `which vivado`
- Source settings: `source /tools/Xilinx/Vivado/*/settings64.sh`
- Check Vivado version compatibility

**Bitstream doesn't load:**
- Verify file permissions on `/dev/xdevcfg`
- Check bitstream file isn't corrupted
- Ensure Red Pitaya is not running conflicting FPGA applications

**No events detected:**
- Verify bitstream is loaded: Check version register reads 0x00010000
- Check enable bit is set in control register
- Verify thresholds are appropriate for your signals
- Check ADC inputs are connected correctly

## References

- [Red Pitaya FPGA Guide](https://redpitaya.readthedocs.io/en/latest/developerGuide/fpga.html)
- [Xilinx Zynq-7000 Documentation](https://www.xilinx.com/products/silicon-devices/soc/zynq-7000.html)
- [AXI4-Lite Specification](https://developer.arm.com/documentation/ihi0022/e/)

## License

MIT License - See main project LICENSE file
