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

## Measurement Parameters

### Key Settings

- **Coincidence window**: Time window for considering events coincident (typical: 10-100 ns)
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
│   ├── coincidence_detector.py  # Main detection script
│   └── config.yaml              # Configuration parameters
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

- [x] Python-based coincidence detection using SCPI
- [x] Dual-channel threshold-based pulse detection
- [x] Configurable coincidence time window
- [x] Real-time event counting and rate display
- [x] YAML-based configuration
- [x] Automated upload scripts
- [x] Comprehensive documentation

## Future Development

Potential enhancements for advanced users:

- [ ] FPGA-based coincidence logic (for <10 ns timing resolution)
- [ ] Data logging to CSV files with timestamps
- [ ] Pulse height distribution histograms
- [ ] Web-based monitoring interface
- [ ] Pulse shape analysis and discrimination
- [ ] Angular distribution measurements (3+ detectors)
- [ ] Time-over-threshold measurement
- [ ] Event waveform capture and storage

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
