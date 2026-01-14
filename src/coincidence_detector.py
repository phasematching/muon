#!/usr/bin/env python3
"""
Red Pitaya Coincidence Detector
================================
Detects coincident pulses on channels IN1 (A) and IN2 (B) for cosmic ray muon detection.

This script uses SCPI commands to acquire data from Red Pitaya and implements
threshold-based coincidence detection in software.

Author: Muon Detection Project
License: MIT
"""

import socket
import time
import struct
import numpy as np
import yaml
import os
import sys
from datetime import datetime


class RedPitayaSCPI:
    """
    Simple SCPI communication class for Red Pitaya.
    """

    def __init__(self, host, port=5000, timeout=5.0):
        """
        Initialize connection to Red Pitaya.

        Args:
            host: IP address or hostname of Red Pitaya
            port: SCPI port (default 5000)
            timeout: Socket timeout in seconds
        """
        self.host = host
        self.port = port
        self.timeout = timeout
        self.socket = None

    def connect(self):
        """Establish connection to Red Pitaya."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(self.timeout)
            self.socket.connect((self.host, self.port))
            print(f"Connected to Red Pitaya at {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"Failed to connect to Red Pitaya: {e}")
            return False

    def disconnect(self):
        """Close connection to Red Pitaya."""
        if self.socket:
            self.socket.close()
            self.socket = None
            print("Disconnected from Red Pitaya")

    def send_command(self, command):
        """
        Send SCPI command without expecting a response.

        Args:
            command: SCPI command string
        """
        if not self.socket:
            raise RuntimeError("Not connected to Red Pitaya")

        command = command.strip()
        if not command.endswith('\n'):
            command += '\n'

        self.socket.sendall(command.encode('utf-8'))

    def query(self, command):
        """
        Send SCPI query and receive response.

        Args:
            command: SCPI query string

        Returns:
            Response string from Red Pitaya
        """
        if not self.socket:
            raise RuntimeError("Not connected to Red Pitaya")

        command = command.strip()
        if not command.endswith('\n'):
            command += '\n'

        self.socket.sendall(command.encode('utf-8'))
        return self.socket.recv(4096).decode('utf-8').strip()

    def query_binary(self, command, dtype=np.float32):
        """
        Send SCPI query and receive binary data response.

        Args:
            command: SCPI query string
            dtype: numpy dtype for binary data

        Returns:
            numpy array of data
        """
        if not self.socket:
            raise RuntimeError("Not connected to Red Pitaya")

        command = command.strip()
        if not command.endswith('\n'):
            command += '\n'

        self.socket.sendall(command.encode('utf-8'))

        # Red Pitaya sends binary data with header
        # Format: #{num_digits}{num_bytes}{binary_data}
        header = self.socket.recv(2).decode('utf-8')
        if header[0] != '#':
            raise ValueError(f"Invalid binary header: {header}")

        num_digits = int(header[1])
        num_bytes_str = self.socket.recv(num_digits).decode('utf-8')
        num_bytes = int(num_bytes_str)

        # Receive binary data
        data = b''
        while len(data) < num_bytes:
            chunk = self.socket.recv(min(4096, num_bytes - len(data)))
            if not chunk:
                break
            data += chunk

        # Convert to numpy array
        return np.frombuffer(data, dtype=dtype)


class CoincidenceDetector:
    """
    Coincidence detector for dual-channel pulse detection.
    """

    def __init__(self, config_file='config.yaml'):
        """
        Initialize coincidence detector.

        Args:
            config_file: Path to configuration YAML file
        """
        # Load configuration
        self.config = self.load_config(config_file)

        # Initialize Red Pitaya connection
        self.rp = RedPitayaSCPI(
            host=self.config['red_pitaya']['ip_address'],
            port=self.config['red_pitaya']['port'],
            timeout=self.config['red_pitaya']['timeout']
        )

        # Statistics
        self.total_coincidences = 0
        self.total_counts_a = 0
        self.total_counts_b = 0
        self.start_time = None

    def load_config(self, config_file):
        """Load configuration from YAML file."""
        if not os.path.exists(config_file):
            print(f"Warning: Config file {config_file} not found, using defaults")
            return self.default_config()

        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        return config

    def default_config(self):
        """Return default configuration."""
        return {
            'red_pitaya': {
                'ip_address': '192.168.1.100',
                'port': 5000,
                'timeout': 5.0
            },
            'acquisition': {
                'decimation': 8,
                'buffer_size': 16384,
                'voltage_range': 1.0
            },
            'detection': {
                'threshold_a': 0.1,
                'threshold_b': 0.1,
                'coincidence_window_us': 2.0
            },
            'display': {
                'update_interval': 1.0
            }
        }

    def initialize(self):
        """Initialize Red Pitaya and configure acquisition."""
        print("Initializing Red Pitaya...")

        if not self.rp.connect():
            return False

        # Reset and configure
        self.rp.send_command('ACQ:RST')
        time.sleep(0.1)

        # Set decimation (affects sampling rate)
        decimation = self.config['acquisition']['decimation']
        self.rp.send_command(f'ACQ:DEC {decimation}')

        # Calculate sampling rate
        base_rate = 125e6  # 125 MS/s
        self.sampling_rate = base_rate / decimation
        self.dt = 1.0 / self.sampling_rate

        print(f"Sampling rate: {self.sampling_rate/1e6:.2f} MS/s")
        print(f"Time resolution: {self.dt*1e9:.2f} ns")

        # Set trigger delay (capture entire buffer)
        buffer_size = self.config['acquisition']['buffer_size']
        self.rp.send_command(f'ACQ:TRIG:DLY {buffer_size}')

        # Start acquisition
        self.rp.send_command('ACQ:START')
        time.sleep(0.1)

        print("Red Pitaya initialized successfully")
        return True

    def acquire_channel(self, channel):
        """
        Acquire data from specified channel.

        Args:
            channel: 1 for IN1 (A) or 2 for IN2 (B)

        Returns:
            numpy array of voltage values
        """
        # Trigger acquisition
        self.rp.send_command('ACQ:TRIG NOW')

        # Wait for trigger
        while True:
            status = self.rp.query('ACQ:TRIG:STAT?')
            if status == 'TD':  # Trigger detected
                break
            time.sleep(0.001)

        # Read data from specified channel
        buffer_size = self.config['acquisition']['buffer_size']
        data = self.rp.query_binary(f'ACQ:SOUR{channel}:DATA:LAT:N? {buffer_size}')

        return data

    def detect_threshold_crossings(self, data, threshold):
        """
        Detect rising edge threshold crossings in data.

        Args:
            data: numpy array of voltage values
            threshold: threshold voltage

        Returns:
            numpy array of sample indices where crossings occur
        """
        # Find where signal crosses threshold (rising edge)
        above_threshold = data > threshold
        crossings = np.where(np.diff(above_threshold.astype(int)) > 0)[0]

        return crossings

    def find_coincidences(self, timestamps_a, timestamps_b, window_samples):
        """
        Find coincidences between two sets of timestamps.

        Args:
            timestamps_a: array of sample indices for channel A events
            timestamps_b: array of sample indices for channel B events
            window_samples: coincidence window in samples

        Returns:
            number of coincident events
        """
        coincidences = 0

        for t_a in timestamps_a:
            # Check if any B event is within window of this A event
            time_diffs = np.abs(timestamps_b - t_a)
            if np.any(time_diffs <= window_samples):
                coincidences += 1

        return coincidences

    def run(self):
        """Main acquisition and detection loop."""
        print("\n" + "="*60)
        print("Red Pitaya Coincidence Detector")
        print("="*60)
        print(f"Channel A threshold: {self.config['detection']['threshold_a']:.3f} V")
        print(f"Channel B threshold: {self.config['detection']['threshold_b']:.3f} V")
        print(f"Coincidence window: {self.config['detection']['coincidence_window_us']:.1f} µs")
        print("="*60)
        print("\nPress Ctrl+C to stop\n")

        # Initialize
        if not self.initialize():
            print("Failed to initialize Red Pitaya")
            return

        # Convert coincidence window to samples
        window_us = self.config['detection']['coincidence_window_us']
        window_samples = int(window_us * 1e-6 * self.sampling_rate)

        print(f"Coincidence window: {window_samples} samples\n")

        self.start_time = time.time()
        last_display_time = self.start_time
        update_interval = self.config['display']['update_interval']

        try:
            while True:
                # Acquire data from both channels
                # Note: We acquire sequentially, which adds some dead time
                # For true simultaneous acquisition, use triggered mode
                data_a = self.acquire_channel(1)
                data_b = self.acquire_channel(2)

                # Detect threshold crossings
                crossings_a = self.detect_threshold_crossings(
                    data_a,
                    self.config['detection']['threshold_a']
                )
                crossings_b = self.detect_threshold_crossings(
                    data_b,
                    self.config['detection']['threshold_b']
                )

                # Find coincidences
                coincidences = self.find_coincidences(
                    crossings_a,
                    crossings_b,
                    window_samples
                )

                # Update statistics
                self.total_counts_a += len(crossings_a)
                self.total_counts_b += len(crossings_b)
                self.total_coincidences += coincidences

                # Display update
                current_time = time.time()
                if current_time - last_display_time >= update_interval:
                    self.display_status()
                    last_display_time = current_time

                # Brief sleep to avoid overwhelming the system
                time.sleep(0.01)

        except KeyboardInterrupt:
            print("\n\nStopping detector...")
            self.display_status()
            print("\nShutdown complete")

        finally:
            self.rp.disconnect()

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


def main():
    """Main entry point."""
    # Check for config file argument
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    else:
        # Look for config.yaml in same directory as script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(script_dir, 'config.yaml')

    # Create and run detector
    detector = CoincidenceDetector(config_file)
    detector.run()


if __name__ == '__main__':
    main()
