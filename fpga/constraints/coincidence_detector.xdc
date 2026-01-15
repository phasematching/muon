# coincidence_detector.xdc
#
# Timing and pin constraints for Red Pitaya coincidence detector
#
# This is a template. Actual pin assignments depend on integration
# into the Red Pitaya system design.
#
# When integrating into Red Pitaya FPGA design, the ADC signals
# are connected internally, not via external pins.

# Clock constraint
# Red Pitaya system clock is 125 MHz (8 ns period)
create_clock -period 8.000 -name adc_clk [get_ports clk]

# Input delay constraints for ADC data
# ADC data is synchronous to adc_clk with minimal delay
set_input_delay -clock adc_clk -min 0.5 [get_ports {adc_a[*]}]
set_input_delay -clock adc_clk -max 1.5 [get_ports {adc_a[*]}]
set_input_delay -clock adc_clk -min 0.5 [get_ports {adc_b[*]}]
set_input_delay -clock adc_clk -max 1.5 [get_ports {adc_b[*]}]

# AXI-Lite interface timing
# AXI signals are in the PS (Processing System) clock domain
# Typically 100 MHz or 125 MHz depending on Red Pitaya configuration

# False paths for asynchronous reset
set_false_path -from [get_ports rst_n]

# Maximum delay constraints for counter readout
# Ensure counters are stable when read via AXI
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ *count_a*}] \
              -to [get_cells -hierarchical -filter {NAME =~ *axi_regs*}] 8.0

set_max_delay -from [get_cells -hierarchical -filter {NAME =~ *count_b*}] \
              -to [get_cells -hierarchical -filter {NAME =~ *axi_regs*}] 8.0

set_max_delay -from [get_cells -hierarchical -filter {NAME =~ *count_coinc*}] \
              -to [get_cells -hierarchical -filter {NAME =~ *axi_regs*}] 8.0

# NOTE: When integrating into Red Pitaya system design:
# 1. Remove port-based constraints (ADC signals are internal)
# 2. Add clock domain crossing constraints for PS-PL interface
# 3. Verify AXI timing with Red Pitaya system constraints
# 4. Add any project-specific pin assignments for debug signals
