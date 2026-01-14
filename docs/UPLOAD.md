# Uploading to Red Pitaya - Complete Guide

This guide explains how to upload and run the coincidence detector code on your Red Pitaya board.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Finding Your Red Pitaya's IP Address](#finding-your-red-pitayas-ip-address)
3. [Quick Start (Automated Upload)](#quick-start-automated-upload)
4. [Manual Upload (Step-by-Step)](#manual-upload-step-by-step)
5. [Configuration](#configuration)
6. [Running the Detector](#running-the-detector)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### On Your Computer

- **SSH client** (Linux/Mac: built-in, Windows: use Git Bash, WSL, or PuTTY)
- **SCP client** for file transfer (usually included with SSH)
- This repository cloned to your computer

### On Red Pitaya

- **Red Pitaya board** (STEMlab 125-14 or similar) with latest OS
- **Network connection** (Ethernet cable connected to your router)
- **Default credentials**:
  - Username: `root`
  - Password: `root`

**Important**: Red Pitaya should be running the official Red Pitaya OS. Most functionality is included, but you may need to install PyYAML.

## Finding Your Red Pitaya's IP Address

### Method 1: Using Hostname (Easiest)

Red Pitaya broadcasts its hostname on the network. Try:

```bash
ping rp-xxxxxx.local
```

The `xxxxxx` is the last 6 characters of your Red Pitaya's MAC address, printed on the Ethernet port label.

### Method 2: Check Your Router

1. Log into your router's admin interface (usually 192.168.1.1 or 192.168.0.1)
2. Look for "DHCP Leases" or "Connected Devices"
3. Find device named "rp-" or "Red Pitaya"
4. Note its IP address

### Method 3: Use Network Scanner

Linux/Mac:
```bash
# Scan your local network
nmap -sn 192.168.1.0/24
# Look for Red Pitaya in the list
```

Windows: Use [Advanced IP Scanner](https://www.advanced-ip-scanner.com/)

### Method 4: Connect Direct Display

If you have a monitor and keyboard:
1. Connect HDMI monitor to Red Pitaya
2. Connect USB keyboard
3. Power on Red Pitaya
4. Login (username: root, password: root)
5. Run: `ip addr show`
6. Look for IP address on eth0 interface

## Quick Start (Automated Upload)

The easiest way to upload is using the provided script:

```bash
# Navigate to project directory
cd muon

# Run upload script with your Red Pitaya's IP
./scripts/upload.sh 192.168.1.100
```

Replace `192.168.1.100` with your Red Pitaya's actual IP address.

The script will:
1. Test connection to Red Pitaya
2. Create necessary directories
3. Upload Python script and configuration
4. Set proper permissions
5. Check for required Python packages

When prompted for password, enter: `root`

## Manual Upload (Step-by-Step)

If you prefer to upload manually or the script doesn't work:

### Step 1: Test Connection

```bash
ping 192.168.1.100
```

You should see replies. Press Ctrl+C to stop.

### Step 2: Create Directory on Red Pitaya

```bash
ssh root@192.168.1.100 "mkdir -p /root/muon"
```

Password: `root`

### Step 3: Upload Files

```bash
# Upload main script
scp src/coincidence_detector.py root@192.168.1.100:/root/muon/

# Upload configuration
scp src/config.yaml root@192.168.1.100:/root/muon/
```

### Step 4: Set Permissions

```bash
ssh root@192.168.1.100 "chmod +x /root/muon/coincidence_detector.py"
```

### Step 5: Install Python Dependencies

```bash
ssh root@192.168.1.100
# You're now on Red Pitaya

# Install PyYAML if not present
pip3 install PyYAML

# NumPy is usually pre-installed, but if needed:
# pip3 install numpy

exit
```

## Configuration

Before running the detector, you must edit the configuration file to set your Red Pitaya's IP address.

### Edit config.yaml on Red Pitaya

```bash
# SSH to Red Pitaya
ssh root@192.168.1.100

# Edit configuration
cd /root/muon
nano config.yaml
```

**Critical change**: Update the IP address:

```yaml
red_pitaya:
  ip_address: "192.168.1.100"  # Change to your Red Pitaya's actual IP
```

Other parameters to adjust based on your setup:

```yaml
detection:
  threshold_a: 0.1      # Channel A threshold (Volts)
  threshold_b: 0.1      # Channel B threshold (Volts)
  coincidence_window_us: 2.0  # Coincidence window (microseconds)
```

Save and exit (Ctrl+X, then Y, then Enter in nano).

## Running the Detector

### Method 1: Direct SSH

```bash
# SSH to Red Pitaya
ssh root@192.168.1.100

# Navigate to directory
cd /root/muon

# Run detector
python3 coincidence_detector.py
```

You should see output like:
```
Connected to Red Pitaya at 192.168.1.100:5000
Initializing Red Pitaya...
Sampling rate: 15.62 MS/s
Time resolution: 64.00 ns
Red Pitaya initialized successfully

========================================================
Red Pitaya Coincidence Detector
========================================================
Channel A threshold: 0.100 V
Channel B threshold: 0.100 V
Coincidence window: 2.0 µs
========================================================

Press Ctrl+C to stop

[    10.2s] A:    523 ( 51.27 Hz) | B:    489 ( 47.94 Hz) | Coinc:    12 ( 1.18 Hz)
```

Press Ctrl+C to stop the detector.

### Method 2: Run Script (from your computer)

```bash
# From your computer, in the muon directory
./scripts/run_detector.sh 192.168.1.100
```

This connects via SSH and runs the detector. Press Ctrl+C to stop.

## Troubleshooting

### Cannot Connect to Red Pitaya

**Problem**: `ssh: connect to host 192.168.1.100 port 22: Connection refused`

**Solutions**:
- Verify Red Pitaya is powered on (green LED should be lit)
- Check Ethernet cable is connected
- Verify IP address is correct
- Try using hostname: `ssh root@rp-xxxxxx.local`
- Check Red Pitaya is on same network as your computer

### SCPI Connection Failed

**Problem**: `Failed to connect to Red Pitaya: [Errno 111] Connection refused`

**Solutions**:
- Ensure the IP address in `config.yaml` matches your Red Pitaya
- Check if SCPI server is running:
  ```bash
  ssh root@192.168.1.100
  systemctl status redpitaya_scpi
  ```
- Restart SCPI service:
  ```bash
  systemctl restart redpitaya_scpi
  ```

### PyYAML Not Found

**Problem**: `ModuleNotFoundError: No module named 'yaml'`

**Solution**:
```bash
ssh root@192.168.1.100
pip3 install PyYAML
```

### No Pulses Detected

**Problem**: All channels show 0 Hz

**Solutions**:
1. **Check connections**: Verify detectors are connected to IN1 and IN2
2. **Check thresholds**: May be too high
   - Reduce threshold in config.yaml (try 0.05V or 0.02V)
   - Check actual detector output with oscilloscope if available
3. **Check detector power**: Ensure PMTs are powered and HV is on
4. **Test with signal generator**: Use function generator to inject test pulses

### High Count Rates (>1000 Hz)

**Problem**: Much higher rates than expected for cosmic rays

**Solutions**:
- **Threshold too low**: Increase threshold to reduce noise triggers
- **EMI/RFI pickup**: Ensure proper grounding and shielding
- **PMT dark current**: May need to reduce PMT voltage

### No Coincidences

**Problem**: Channels A and B show counts but no coincidences

**Solutions**:
1. **Window too narrow**: Increase `coincidence_window_us` to 5-10 µs
2. **Detectors misaligned**: Ensure detectors are properly aligned for muon path
3. **Test with splitter**: Use signal splitter to feed same signal to both channels
   - Should get nearly 100% coincidence rate
   - Proves coincidence logic is working

### Permission Denied

**Problem**: `Permission denied (publickey,password)`

**Solution**:
- Password is `root` (all lowercase)
- Try: `ssh -o PubkeyAuthentication=no root@192.168.1.100`

## Testing Your Setup

### Test 1: Single Channel Detection

Edit config.yaml and set very low threshold (0.01V) on channel A. You should see many counts even from noise. This confirms basic acquisition works.

### Test 2: Signal Generator Test

If you have a function generator:
1. Generate 100mV pulses at 10 Hz
2. Split signal to both IN1 and IN2
3. Run detector
4. Should see ~10 Hz on both channels and ~10 Hz coincidences

### Test 3: Cosmic Ray Detection

With properly configured scintillator detectors:
- Single channel rates: 50-500 Hz (depends on detector size)
- Coincidence rate: 0.1-10 Hz (depends on geometry)
- Cosmic ray flux at sea level: ~1 muon/cm²/minute

## Next Steps

Once you have the detector running:

1. **Optimize thresholds**: Adjust to get good signal-to-noise ratio
2. **Tune coincidence window**: Balance between efficiency and random coincidences
3. **Long-term measurement**: Run for hours to get good statistics
4. **Data logging**: Modify code to save events to file
5. **Visualization**: Add plotting capabilities

## Additional Resources

- [Red Pitaya Documentation](https://redpitaya.readthedocs.io/)
- [Red Pitaya SCPI Commands](https://redpitaya.readthedocs.io/en/latest/appsFeatures/remoteControl/remoteControl.html)
- [Red Pitaya Forum](https://forum.redpitaya.com/)

## Need Help?

If you encounter issues not covered here:
1. Check Red Pitaya logs: `ssh root@<ip> dmesg`
2. Test SCPI manually: `telnet <ip> 5000` then send `ACQ:RST`
3. Consult Red Pitaya documentation
4. Post on Red Pitaya forum with error messages
