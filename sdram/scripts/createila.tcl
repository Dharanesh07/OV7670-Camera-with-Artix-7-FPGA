# scripts/create_ila.tcl

# Set the project directory
set proj_dir [file dirname [info script]]/../

# Create IP directory if it doesn't exist
file mkdir ${proj_dir}/ip

# Create ILA IP
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_0 -dir ${proj_dir}/ip

# Configure ILA
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {16} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_TRIGIN_EN {false} \
    CONFIG.C_TRIGOUT_EN {false} \
    CONFIG.C_ADV_TRIGGER {false} \
    CONFIG.C_INPUT_PIPE_STAGES {0} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.ALL_PROBE_SAME_MU {true} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
] [get_ips ila_0]

# Generate IP
generate_target all [get_ips ila_0]
create_ip_run [get_ips ila_0]
launch_runs ila_0_synth_1
wait_on_run ila_0_synth_1

puts "ILA IP generated successfully!"
