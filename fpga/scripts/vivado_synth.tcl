# vivado_synth.tcl
#
# Vivado synthesis script for Red Pitaya coincidence detector
#
# This script creates a Vivado project, adds source files, and runs
# synthesis to generate a bitstream for the Red Pitaya FPGA.
#
# Usage:
#   vivado -mode batch -source vivado_synth.tcl
#
# Red Pitaya uses Xilinx Zynq-7010 or Zynq-7020 (depending on model)

set project_name "coincidence_detector"
set rtl_dir "../rtl"
set ip_dir "../ip"
set constraints_dir "../constraints"

# Red Pitaya FPGA part number
# STEMlab 125-10: xc7z010clg400-1
# STEMlab 125-14: xc7z020clg400-1
set fpga_part "xc7z010clg400-1"

puts "=========================================="
puts "Vivado Synthesis for Coincidence Detector"
puts "=========================================="
puts "Project: $project_name"
puts "FPGA Part: $fpga_part"
puts ""

# Create project
puts "Creating Vivado project..."
create_project $project_name . -part $fpga_part -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Add RTL source files
puts "Adding RTL source files..."
add_files [glob $rtl_dir/*.v]

# Add constraints (if any exist)
if {[file exists $constraints_dir]} {
    puts "Adding constraint files..."
    add_files -fileset constrs_1 [glob -nocomplain $constraints_dir/*.xdc]
}

# Set top module
puts "Setting top module..."
set_property top coincidence_detector [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

puts ""
puts "=========================================="
puts "Running Synthesis"
puts "=========================================="

# Run synthesis
launch_runs synth_1
wait_on_run synth_1

# Check synthesis status
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

puts ""
puts "Synthesis Status: $synth_status"
puts "Synthesis Progress: $synth_progress"

if {$synth_status == "synth_design Complete!"} {
    puts ""
    puts "=========================================="
    puts "Synthesis SUCCESSFUL"
    puts "=========================================="

    # Open synthesized design
    open_run synth_1

    # Generate reports
    puts "Generating reports..."
    report_utilization -file utilization_synth.rpt
    report_timing_summary -file timing_synth.rpt

    puts ""
    puts "Reports generated:"
    puts "  - utilization_synth.rpt"
    puts "  - timing_synth.rpt"

    # Optionally run implementation
    puts ""
    puts "To run implementation and generate bitstream:"
    puts "  1. Open Vivado GUI: vivado $project_name.xpr"
    puts "  2. Run Implementation"
    puts "  3. Generate Bitstream"
    puts ""
    puts "Or run in batch mode:"
    puts "  vivado -mode batch -source vivado_impl.tcl"

} else {
    puts ""
    puts "=========================================="
    puts "Synthesis FAILED"
    puts "=========================================="
    puts "Check the log files for errors"
    exit 1
}

puts ""
puts "Done!"
