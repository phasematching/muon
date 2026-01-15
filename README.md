# Muon

A data acquisition and signal processing project for educational physics experiments on cosmic rays using Red Pitaya for coincidence measurements.

## Overview

This project uses the Red Pitaya platform to detect and measure cosmic ray muons through coincidence detection. By correlating signals from multiple detectors, we can identify genuine muon events and filter out random background noise.

## What is Red Pitaya?

Red Pitaya is an open-source electronics platform that combines:
- Fast analog inputs (125 MS/s, 14-bit ADC)
- Configurable digital I/O
- FPGA-based signal processing
- Linux-based control system
- Network connectivity

This makes it ideal for physics experiments requiring precise timing and signal correlation.

## Coincidence Measurements

### Principle

Coincidence detection identifies events where multiple detectors register signals within a narrow time window (typically nanoseconds to microseconds). For cosmic ray muons:

1. A muon particle passes through multiple scintillator detectors
2. Each detector produces a signal pulse
3. The Red Pitaya identifies when pulses arrive simultaneously (within the coincidence window)
4. True muon events show coincidence; random background events do not

### Why Coincidence Detection?

- **Noise reduction**: Random detector noise is uncorrelated, so it's rejected
- **Directional information**: Multiple detectors allow track reconstruction
- **Energy measurements**: Pulse height analysis of coincident events
- **Timing resolution**: Red Pitaya's fast sampling enables precise event timing

## Hardware Setup

### Required Components

1. Red Pitaya board (STEMlab 125-14 or similar)
2. Two or more scintillator detectors with PMTs
3. Signal conditioning electronics (amplifiers, discriminators)
4. Power supplies
5. Network connection for Red Pitaya

### Typical Configuration

```
Detector 1 → Amplifier → Red Pitaya IN1
Detector 2 → Amplifier → Red Pitaya IN2
```

The Red Pitaya processes both channels simultaneously, looking for temporal correlations.

## Software Architecture

### Detection Modes

This project supports two detection modes:

#### Software Mode (Default)
- **Timing Resolution**: ~64 ns (depends on decimation setting)
- **Implementation**: Python-based coincidence detection using SCPI
- **Advantages**: Easy to configure, no FPGA programming required
- **Use Case**: General cosmic ray detection, educational experiments
- **Typical Coincidence Window**: 1-10 µs

#### FPGA Mode (Advanced)
- **Timing Resolution**: ~8 ns (125 MHz FPGA clock)
- **Implementation**: Hardware-accelerated coincidence logic in FPGA
- **Advantages**: Ultra-precise timing, real-time processing, no dead time
- **Use Case**: High-precision measurements, fast event rates
- **Typical Coincidence Window**: 10-1000 ns
- **Requirements**: Custom FPGA bitstream (see [FPGA Setup](#fpga-mode-setup))

### Signal Processing Pipeline

1. **Acquisition**: Continuous sampling of analog inputs
2. **Triggering**: Detect pulses exceeding threshold
3. **Coincidence logic**: Compare timing of events across channels
4. **Event recording**: Store coincident events with timestamps
5. **Analysis**: Calculate rates, distributions, and correlations

### Red Pitaya Programming

The Red Pitaya can be programmed using:
- **FPGA logic** (Verilog/VHDL) for real-time coincidence detection
- **SCPI commands** for remote control
- **Python/C** applications running on the ARM processor
- **Web interface** for monitoring and control

## Getting Started

### Prerequisites

- Red Pitaya board (STEMlab 125-14 or similar) with latest OS image
- Red Pitaya connected to your network via Ethernet
- SSH client on your computer (Linux/Mac: built-in, Windows: Git Bash or WSL)
- Two scintillator detectors with PMT outputs connected to Red Pitaya IN1 and IN2
- Basic understanding of electronics and signal processing

### Installation

#### Step 1: Clone Repository

```bash
git clone <repository-url>
cd muon
```

#### Step 2: Find Your Red Pitaya's IP Address

Try one of these methods:

```bash
# Method 1: Using hostname (replace xxxxxx with your board's ID)
ping rp-xxxxxx.local

# Method 2: Check your router's DHCP leases
# Look for device named "rp-" or "Red Pitaya"

# Method 3: Network scan
nmap -sn 192.168.1.0/24
```

#### Step 3: Upload Code to Red Pitaya

Use the automated upload script:

```bash
./scripts/upload.sh 192.168.1.100  # Replace with your Red Pitaya's IP
```

Enter password: `root` when prompted.

For detailed upload instructions, see [docs/UPLOAD.md](docs/UPLOAD.md).

#### Step 4: Configure Parameters

SSH to your Red Pitaya and edit the configuration:

```bash
ssh root@192.168.1.100  # Replace with your IP
cd /root/muon
nano config.yaml
```

Important settings to configure:

- **mode**: Detection mode - `"software"` (default) or `"fpga"` (requires FPGA bitstream)
- **ip_address**: Your Red Pitaya's IP address
- **threshold_a, threshold_b**: Voltage thresholds for pulse detection (typically 0.1V)
- **coincidence_window_us**: Time window for coincidences (typically 1-10 µs)

### Basic Usage

#### Running the Detector

**Option 1: Run remotely from your computer**

```bash
./scripts/run_detector.sh 192.168.1.100  # Replace with your IP
```

**Option 2: Run directly on Red Pitaya**

```bash
ssh root@192.168.1.100
cd /root/muon
python3 coincidence_detector.py
```

#### Expected Output

```
Connected to Red Pitaya at 192.168.1.100:5000
Initializing Red Pitaya...
Sampling rate: 15.62 MS/s
Time resolution: 64.00 ns

============================================================
Red Pitaya Coincidence Detector
============================================================
Channel A threshold: 0.100 V
Channel B threshold: 0.100 V
Coincidence window: 2.0 µs
============================================================

Press Ctrl+C to stop

[   15.3s] A:   234 ( 15.29 Hz) | B:   198 ( 12.94 Hz) | Coinc:    8 ( 0.52 Hz)
```

The display shows:
- **A**: Total counts and rate on channel A (IN1)
- **B**: Total counts and rate on channel B (IN2)
- **Coinc**: Total coincidence events and rate

Press Ctrl+C to stop the detector.

#### Adjusting Parameters

If you see issues:

- **No counts detected**: Lower thresholds (try 0.05V or 0.02V)
- **Very high rates (>1000 Hz)**: Raise thresholds or check for noise
- **Counts but no coincidences**: Increase coincidence window to 5-10 µs
- **Too many coincidences**: Narrow coincidence window or check detector alignment

### Quick Start Example

Complete workflow from scratch:

```bash
# 1. Clone and enter directory
git clone <repository-url>
cd muon

# 2. Find Red Pitaya (example output: 192.168.1.100)
ping rp-f2456a.local

# 3. Upload code
./scripts/upload.sh 192.168.1.100

# 4. Edit configuration (set IP address and thresholds)
ssh root@192.168.1.100
cd /root/muon
nano config.yaml
# Update ip_address to 192.168.1.100
# Save with Ctrl+X, Y, Enter
exit

# 5. Run detector
./scripts/run_detector.sh 192.168.1.100

# 6. Stop with Ctrl+C when done
```

## FPGA Mode Setup

For advanced users requiring high-precision timing (<10 ns resolution), you can enable FPGA-based coincidence detection.

### Complete FPGA Implementation Available

This project now includes a complete FPGA implementation in the `fpga/` directory with:
- ✓ Verilog RTL modules for coincidence detection
- ✓ AXI-Lite register interface for software control
- ✓ Simulation testbench with verification
- ✓ Build scripts for Icarus Verilog and Vivado
- ✓ Comprehensive documentation

See [`fpga/README.md`](fpga/README.md) for complete FPGA documentation.

### Requirements

1. **For Simulation** (testing without hardware):
   - Icarus Verilog (`iverilog`) - Free, open-source
   - GTKWave (optional, for waveform viewing)

2. **For Synthesis** (building bitstream):
   - Xilinx Vivado (2019.1 or later)
   - Red Pitaya development environment

3. **For Deployment**:
   - Red Pitaya board with network access
   - Knowledge of FPGA programming (Verilog/VHDL)

### Quick Start - Test in Simulation

Verify the FPGA logic without hardware:

```bash
cd fpga
make sim
```

This runs a complete testbench that verifies threshold detection, coincidence logic, and register interface.

View the waveform:
```bash
gtkwave build/tb_coincidence_detector.vcd
```

### Configuration

To enable FPGA mode, edit `src/config.yaml`:

```yaml
detection:
  mode: "fpga"  # Change from "software" to "fpga"
  threshold_a: 0.1
  threshold_b: 0.1
  coincidence_window_us: 0.1  # Can use much smaller windows in FPGA mode (100 ns)
```

### Building the Bitstream

#### Step 1: Run Synthesis

```bash
cd fpga
make synth
```

This creates a Vivado project and runs synthesis. Check resource usage and timing in the generated reports.

#### Step 2: Implementation and Bitstream Generation

Open the Vivado GUI:
```bash
cd fpga/build
vivado coincidence_detector.xpr
```

Then:
1. Click "Run Implementation"
2. Wait for completion
3. Click "Generate Bitstream"

#### Step 3: Integration with Red Pitaya

The coincidence detector must be integrated into the complete Red Pitaya FPGA design:

1. Clone the Red Pitaya FPGA repository
2. Add the coincidence detector module to the design
3. Connect to ADC inputs and ARM processor interface
4. Assign AXI base address in the memory map
5. Build the complete Red Pitaya bitstream

Detailed instructions: See [`fpga/README.md`](fpga/README.md)

#### Step 4: Load Bitstream

```bash
# Copy to Red Pitaya
scp coincidence_detector.bit root@<red-pitaya-ip>:/root/

# SSH and load
ssh root@<red-pitaya-ip>
cat /root/coincidence_detector.bit > /dev/xdevcfg
```

#### Step 5: Run with FPGA Mode

```bash
cd /root/muon
python3 coincidence_detector.py  # Will use FPGA mode if configured
```

### Advantages of FPGA Mode

- **Ultra-precise timing**: 8 ns resolution vs. 64+ ns in software mode
- **Real-time processing**: No acquisition dead time
- **Higher event rates**: Can handle much faster event rates
- **Lower coincidence windows**: Enables better noise rejection
- **Deterministic latency**: Hardware-based processing

### When to Use FPGA Mode

Use FPGA mode when you need:
- Timing resolution better than 10 ns
- High event rates (>10 kHz per channel)
- Narrow coincidence windows (<1 µs)
- Deterministic, real-time processing
- Maximum noise rejection

For most educational applications, software mode is sufficient and much easier to set up.

## Measurement Parameters

### Key Settings

- **Coincidence window**: Time window for considering events coincident
  - Software mode: typical 1-10 µs
  - FPGA mode: typical 10-1000 ns
- **Trigger threshold**: Voltage level to identify valid pulses
- **Sampling rate**: Red Pitaya sampling frequency (125 MS/s max)
- **Buffer size**: Memory allocated for event storage

### Typical Muon Rates

- Sea level, horizontal detectors: ~1 muon/cm²/min
- Actual coincidence rate depends on detector geometry and separation

## Project Structure

```
muon/
├── src/
│   ├── coincidence_detector.py  # Main detection script (software mode)
│   ├── fpga_coincidence.py      # FPGA-based detection implementation
│   └── config.yaml              # Configuration parameters
├── fpga/
│   ├── rtl/                     # Verilog RTL source files
│   │   ├── coincidence_detector.v   # Top-level FPGA module
│   │   ├── threshold_detector.v     # Threshold comparators
│   │   ├── coincidence_logic.v      # Coincidence window logic
│   │   └── axi_lite_regs.v         # AXI register interface
│   ├── sim/                     # Simulation testbenches
│   │   └── tb_coincidence_detector.v
│   ├── scripts/                 # Build scripts
│   │   └── vivado_synth.tcl    # Vivado synthesis script
│   ├── constraints/             # Timing constraints
│   ├── Makefile                # Build system
│   └── README.md               # FPGA documentation
├── scripts/
│   ├── upload.sh                # Upload code to Red Pitaya
│   └── run_detector.sh          # Run detector remotely
├── docs/
│   └── UPLOAD.md                # Detailed upload guide
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

## Project Status

This is an educational project for learning about:
- Cosmic ray physics
- Coincidence detection techniques
- Data acquisition systems
- Real-time signal processing
- Statistical analysis of particle events

### Current Features

- [x] Python-based coincidence detection using SCPI (software mode)
- [x] FPGA-based coincidence detection framework (hardware mode)
- [x] Complete FPGA RTL implementation in Verilog
- [x] FPGA simulation testbench with verification
- [x] Build system for FPGA synthesis (Vivado and Icarus Verilog)
- [x] Dual-channel threshold-based pulse detection
- [x] Configurable coincidence time window
- [x] Real-time event counting and rate display
- [x] YAML-based configuration with mode selection
- [x] Automated upload scripts
- [x] Comprehensive documentation for both software and FPGA

## Future Development

Potential enhancements for advanced users:

- [ ] Red Pitaya system integration guide for FPGA bitstream
- [ ] Python memory-mapped I/O interface for FPGA registers
- [ ] Data logging to CSV files with timestamps
- [ ] Pulse height distribution histograms
- [ ] Web-based monitoring interface
- [ ] Pulse shape analysis and discrimination
- [ ] Angular distribution measurements (3+ detectors)
- [ ] Time-over-threshold measurement in FPGA
- [ ] Event waveform capture and storage
- [ ] Timestamp capture with high-resolution counters

## Resources

### Red Pitaya Documentation
- [Red Pitaya Official Site](https://www.redpitaya.com/)
- [Red Pitaya GitHub](https://github.com/RedPitaya/RedPitaya)

### Cosmic Ray Physics
- Introduction to cosmic ray muon detection
- Coincidence measurement techniques
- Educational particle physics experiments

## Contributing

Contributions welcome. This project is designed for educational purposes and experimentation.

## License

(License information to be added)

## Acknowledgments

Built on the Red Pitaya open-source platform for educational physics experiments.
