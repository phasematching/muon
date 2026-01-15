#!/usr/bin/env python3
"""
FPGA-based Coincidence Detector for Red Pitaya
================================================
Implements hardware-accelerated coincidence detection using Red Pitaya's FPGA
for high-precision timing (<10 ns resolution).

This module interfaces with custom FPGA logic programmed into the Red Pitaya
to perform real-time coincidence detection at the hardware level.

Author: Muon Detection Project
License: MIT
"""

import time
import numpy as np
from datetime import datetime


class FPGACoincidenceDetector:
    """
    FPGA-based coincidence detector for high-precision timing.

    This class interfaces with custom FPGA logic on the Red Pitaya to perform
    hardware-based coincidence detection. The FPGA processes signals in real-time
    with nanosecond-level timing resolution.

    Requirements:
        - Red Pitaya with custom FPGA bitstream loaded
        - FPGA logic implementing coincidence detection
        - Memory-mapped register interface for configuration and readout
    """

    # Register addresses for FPGA interface (these are examples)
    # In actual implementation, these would match your FPGA design
    REG_CONTROL = 0x40000000
    REG_STATUS = 0x40000004
    REG_THRESHOLD_A = 0x40000008
    REG_THRESHOLD_B = 0x4000000C
    REG_COINC_WINDOW = 0x40000010
    REG_COUNT_A = 0x40000014
    REG_COUNT_B = 0x40000018
    REG_COUNT_COINC = 0x4000001C

    def __init__(self, rp_connection, config):
        """
        Initialize FPGA coincidence detector.

        Args:
            rp_connection: Connection object to Red Pitaya
            config: Configuration dictionary with detection parameters
        """
        self.rp = rp_connection
        self.config = config

        # Statistics
        self.total_coincidences = 0
        self.total_counts_a = 0
        self.total_counts_b = 0
        self.start_time = None

    def initialize(self):
        """
        Initialize FPGA coincidence detection logic.

        This method:
        1. Verifies FPGA bitstream is loaded
        2. Configures detection thresholds
        3. Sets coincidence window
        4. Resets counters
        5. Starts continuous acquisition

        Returns:
            bool: True if initialization successful, False otherwise
        """
        print("Initializing FPGA coincidence detector...")

        try:
            # Check if FPGA bitstream is loaded
            if not self._verify_fpga_bitstream():
                print("ERROR: FPGA coincidence bitstream not loaded!")
                print("Please load the coincidence detection bitstream to the Red Pitaya FPGA.")
                print("See docs/FPGA_SETUP.md for instructions.")
                return False

            # Configure thresholds
            threshold_a = self.config['detection']['threshold_a']
            threshold_b = self.config['detection']['threshold_b']
            self._set_threshold_a(threshold_a)
            self._set_threshold_b(threshold_b)

            # Configure coincidence window (convert µs to FPGA clock cycles)
            # Red Pitaya FPGA clock is typically 125 MHz (8 ns period)
            window_us = self.config['detection']['coincidence_window_us']
            window_cycles = int(window_us * 125)  # Convert µs to 125 MHz clock cycles
            self._set_coincidence_window(window_cycles)

            # Reset counters
            self._reset_counters()

            # Start acquisition
            self._start_acquisition()

            print(f"FPGA mode initialized:")
            print(f"  Threshold A: {threshold_a:.3f} V")
            print(f"  Threshold B: {threshold_b:.3f} V")
            print(f"  Coincidence window: {window_us:.3f} µs ({window_cycles} cycles)")
            print(f"  Timing resolution: ~8 ns (125 MHz FPGA clock)")

            return True

        except Exception as e:
            print(f"FPGA initialization failed: {e}")
            return False

    def _verify_fpga_bitstream(self):
        """
        Verify that the correct FPGA bitstream is loaded.

        This checks for a specific signature or version register in the FPGA
        to confirm the coincidence detection logic is present.

        Returns:
            bool: True if correct bitstream detected
        """
        # NOTE: This is a placeholder implementation
        # In actual usage, you would read a version/ID register from the FPGA
        # that uniquely identifies the coincidence detection bitstream

        print("WARNING: FPGA bitstream verification not yet implemented")
        print("Assuming correct bitstream is loaded...")

        # For now, return False to indicate FPGA mode is not ready
        # Set to True when you have actual FPGA bitstream
        return False

    def _set_threshold_a(self, voltage):
        """
        Set detection threshold for channel A in FPGA.

        Args:
            voltage: Threshold voltage (V)
        """
        # Convert voltage to ADC counts (14-bit ADC, ±1V range)
        # ADC value = (voltage / 1.0) * 2^13
        adc_value = int((voltage / 1.0) * 8192)

        # Write to FPGA register
        # NOTE: Actual implementation would use memory-mapped I/O or SCPI
        print(f"Setting FPGA threshold A: {voltage}V (ADC: {adc_value})")

    def _set_threshold_b(self, voltage):
        """
        Set detection threshold for channel B in FPGA.

        Args:
            voltage: Threshold voltage (V)
        """
        # Convert voltage to ADC counts (14-bit ADC, ±1V range)
        adc_value = int((voltage / 1.0) * 8192)

        # Write to FPGA register
        print(f"Setting FPGA threshold B: {voltage}V (ADC: {adc_value})")

    def _set_coincidence_window(self, cycles):
        """
        Set coincidence window in FPGA clock cycles.

        Args:
            cycles: Number of FPGA clock cycles (125 MHz clock, 8 ns period)
        """
        # Write to FPGA register
        print(f"Setting FPGA coincidence window: {cycles} cycles ({cycles*8:.1f} ns)")

    def _reset_counters(self):
        """Reset FPGA event counters."""
        print("Resetting FPGA counters")
        # Write reset bit to control register
        pass

    def _start_acquisition(self):
        """Start FPGA continuous acquisition and coincidence detection."""
        print("Starting FPGA acquisition")
        # Write start bit to control register
        pass

    def read_counters(self):
        """
        Read current event counters from FPGA.

        Returns:
            tuple: (counts_a, counts_b, coincidences)
        """
        # Read counter registers from FPGA
        # NOTE: Placeholder implementation
        counts_a = 0
        counts_b = 0
        coincidences = 0

        return counts_a, counts_b, coincidences

    def run(self):
        """
        Main acquisition loop for FPGA mode.

        Continuously reads counters from FPGA and displays statistics.
        """
        print("\n" + "="*60)
        print("FPGA-Based Coincidence Detector")
        print("="*60)
        print(f"Channel A threshold: {self.config['detection']['threshold_a']:.3f} V")
        print(f"Channel B threshold: {self.config['detection']['threshold_b']:.3f} V")
        print(f"Coincidence window: {self.config['detection']['coincidence_window_us']:.1f} µs")
        print("="*60)
        print("\nPress Ctrl+C to stop\n")

        # Initialize
        if not self.initialize():
            print("\nFailed to initialize FPGA mode")
            print("\nFalling back to software mode would require restarting with mode='software'")
            return

        self.start_time = time.time()
        last_display_time = self.start_time
        update_interval = self.config['display']['update_interval']

        # Previous counter values for rate calculation
        prev_counts_a = 0
        prev_counts_b = 0
        prev_coincidences = 0

        try:
            while True:
                # Read current counters from FPGA
                counts_a, counts_b, coincidences = self.read_counters()

                # Update totals
                self.total_counts_a = counts_a
                self.total_counts_b = counts_b
                self.total_coincidences = coincidences

                # Display update
                current_time = time.time()
                if current_time - last_display_time >= update_interval:
                    self.display_status()
                    last_display_time = current_time

                # Sleep briefly
                time.sleep(0.1)

        except KeyboardInterrupt:
            print("\n\nStopping FPGA detector...")
            self.display_status()
            print("\nShutdown complete")

    def display_status(self):
        """Display current detection statistics."""
        elapsed = time.time() - self.start_time

        # Calculate rates (events per second)
        rate_a = self.total_counts_a / elapsed if elapsed > 0 else 0
        rate_b = self.total_counts_b / elapsed if elapsed > 0 else 0
        rate_coinc = self.total_coincidences / elapsed if elapsed > 0 else 0

        # Display
        print(f"\r[{elapsed:7.1f}s] "
              f"A: {self.total_counts_a:6d} ({rate_a:6.2f} Hz) | "
              f"B: {self.total_counts_b:6d} ({rate_b:6.2f} Hz) | "
              f"Coinc: {self.total_coincidences:5d} ({rate_coinc:5.2f} Hz)",
              end='', flush=True)


def create_fpga_bitstream_guide():
    """
    Returns a guide for creating and loading FPGA bitstream for coincidence detection.

    This is a helper function that provides documentation for implementing
    the FPGA coincidence logic.
    """
    guide = """
    FPGA Bitstream Implementation Guide
    ===================================

    To enable FPGA-based coincidence detection, you need to:

    1. Create FPGA Logic (Verilog/VHDL):
       - Dual-channel ADC interface (14-bit, 125 MS/s)
       - Threshold comparators for each channel
       - Coincidence detection logic with programmable window
       - Event counters (32-bit or larger)
       - AXI/memory-mapped register interface

    2. Required Registers:
       - Control register (start/stop, reset)
       - Status register
       - Threshold A register (ADC counts)
       - Threshold B register (ADC counts)
       - Coincidence window register (clock cycles)
       - Counter A register (read-only)
       - Counter B register (read-only)
       - Coincidence counter register (read-only)

    3. Timing Specifications:
       - FPGA clock: 125 MHz (8 ns period)
       - Timing resolution: 8 ns minimum
       - Typical coincidence window: 10-1000 ns

    4. Build and Load:
       - Compile using Vivado or Red Pitaya build system
       - Generate bitstream (.bit file)
       - Load to Red Pitaya using FPGA manager

    5. Testing:
       - Verify register read/write
       - Test threshold detection
       - Validate coincidence logic with test pulses
       - Measure timing resolution

    Reference:
    - Red Pitaya FPGA documentation: https://redpitaya.readthedocs.io/
    - Red Pitaya GitHub: https://github.com/RedPitaya/RedPitaya
    """
    return guide
