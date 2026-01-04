# Close any open projects
catch {close_project}
catch {close_design}

set proj_name "led_blink_proj"
set top_module "led_top"
set xdc_file "led_top"
set fpga_part "xc7a100tfgg676-1"


# Clean up
file delete -force ./$proj_name

# Create project
create_project $proj_name ./$proj_name -part $fpga_part -force

# Add source files
if {[glob -nocomplain *.v] != ""} {
    add_files -fileset sources_1 [glob *.v]
}
if {[glob -nocomplain *.sv] != ""} {
    add_files -fileset sources_1 [glob *.sv]
}
if {[glob -nocomplain *.vhd] != ""} {
    add_files -fileset sources_1 [glob *.vhd]
}

# Add constraints
add_files -fileset constrs_1 $xdc_file.xdc

# Set top module
set_property top $top_module [current_fileset]

# Update compile order
update_compile_order -fileset sources_1


# Run synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    puts [get_property STATUS [get_runs synth_1]]
    exit 1
}

puts "Synthesis completed successfully"

# Run implementation
puts "Running implementation..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    puts [get_property STATUS [get_runs impl_1]]
    exit 1
}

puts "Implementation completed successfully"

puts "\nBuild completed successfully!"
