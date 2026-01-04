# Get the directory where this script is located
set script_dir [file dirname [file normalize [info script]]]
puts "Script directory: $script_dir"

# Change to script directory
cd $script_dir
puts "Working directory: [pwd]"

# Close any open designs
puts "Closing any designs that are currently open..."
catch {close_sim -quiet}
catch {close_design -quiet}
puts "Continuing..."

set design_files "../src/i2c.v "
set tb_files "../tb/i2c_tb.v"
set top_module "i2c_tb"
set snapshot_name "sim_snapshot"

# Compile design files (analysis)
exec xvlog -work work $design_files

# Compile testbench
exec xvlog -work work $tb_files

# Elaborate design (create snapshot)
exec xelab -debug typical -top $top_module -snapshot $snapshot_name

# Run simulation
exec xsim $snapshot_name -runall

# Or run with TCL commands
exec xsim $snapshot_name -tclbatch sim_commands.tcl
