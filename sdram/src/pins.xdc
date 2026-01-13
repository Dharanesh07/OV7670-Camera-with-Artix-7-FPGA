# Clock constraints
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {sys_clk_IBUF}]

# Configuration voltage (ADD THESE)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Pin constraints
set_property IOSTANDARD LVCMOS33 [get_ports led0]
set_property PACKAGE_PIN G20 [get_ports led0]

set_property IOSTANDARD LVCMOS33 [get_ports led1]
set_property PACKAGE_PIN G21 [get_ports led1]

set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property PACKAGE_PIN M21 [get_ports sys_clk]

#create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} [get_ports sys_clk]


set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PACKAGE_PIN H7 [get_ports sys_rst_n]


set_property PACKAGE_PIN F3 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN E3 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LEDs

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[0]}]
set_property PACKAGE_PIN AB24 [get_ports {debug_led[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[1]}]
set_property PACKAGE_PIN AA24 [get_ports {debug_led[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[2]}]
set_property PACKAGE_PIN V24 [get_ports {debug_led[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[3]}]
set_property PACKAGE_PIN AB26 [get_ports {debug_led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[4]}]
set_property PACKAGE_PIN Y25 [get_ports {debug_led[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[5]}]
set_property PACKAGE_PIN W25 [get_ports {debug_led[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[6]}]
set_property PACKAGE_PIN V26 [get_ports {debug_led[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[7]}]
set_property PACKAGE_PIN U25 [get_ports {debug_led[7]}]


# SDRAM signals

set_property PACKAGE_PIN G22 [get_ports sdram_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_clk]
set_property PACKAGE_PIN H22 [get_ports sdram_cke]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_cke]

set_property PACKAGE_PIN K23 [get_ports {sdram_dqm[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_dqm[1]}]
set_property PACKAGE_PIN J25 [get_ports {sdram_dqm[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_dqm[0]}]

set_property PACKAGE_PIN K25 [get_ports sdram_casn]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_casn]
set_property PACKAGE_PIN K26 [get_ports sdram_rasn]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_rasn]
set_property PACKAGE_PIN J26 [get_ports sdram_wen]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_wen]
set_property PACKAGE_PIN L25 [get_ports sdram_csn]
set_property IOSTANDARD LVCMOS33 [get_ports sdram_csn]

set_property PACKAGE_PIN M26 [get_ports {sdram_ba[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_ba[1]}]
set_property PACKAGE_PIN M25 [get_ports {sdram_ba[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_ba[0]}]

set_property PACKAGE_PIN J21 [get_ports {sdram_addr[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[12]}]
set_property PACKAGE_PIN K22 [get_ports {sdram_addr[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[11]}]
set_property PACKAGE_PIN R25 [get_ports {sdram_addr[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[10]}]
set_property PACKAGE_PIN K21 [get_ports {sdram_addr[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[9]}]
set_property PACKAGE_PIN L22 [get_ports {sdram_addr[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[8]}]
set_property PACKAGE_PIN L23 [get_ports {sdram_addr[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[7]}]
set_property PACKAGE_PIN L24 [get_ports {sdram_addr[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[6]}]
set_property PACKAGE_PIN M22 [get_ports {sdram_addr[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[5]}]
set_property PACKAGE_PIN M24 [get_ports {sdram_addr[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[4]}]
set_property PACKAGE_PIN N26 [get_ports {sdram_addr[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[3]}]
set_property PACKAGE_PIN P26 [get_ports {sdram_addr[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[2]}]
set_property PACKAGE_PIN P25 [get_ports {sdram_addr[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[1]}]
set_property PACKAGE_PIN R26 [get_ports {sdram_addr[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_addr[0]}]

set_property PACKAGE_PIN D25 [get_ports {sdram_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[0]}]
set_property PACKAGE_PIN D26 [get_ports {sdram_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[1]}]
set_property PACKAGE_PIN E25 [get_ports {sdram_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[2]}]
set_property PACKAGE_PIN E26 [get_ports {sdram_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[3]}]
set_property PACKAGE_PIN F25 [get_ports {sdram_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[4]}]
set_property PACKAGE_PIN G25 [get_ports {sdram_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[5]}]
set_property PACKAGE_PIN G26 [get_ports {sdram_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[6]}]
set_property PACKAGE_PIN H26 [get_ports {sdram_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[7]}]
set_property PACKAGE_PIN J24 [get_ports {sdram_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[8]}]
set_property PACKAGE_PIN J23 [get_ports {sdram_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[9]}]
set_property PACKAGE_PIN H24 [get_ports {sdram_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[10]}]
set_property PACKAGE_PIN H23 [get_ports {sdram_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[11]}]
set_property PACKAGE_PIN G24 [get_ports {sdram_data[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[12]}]
set_property PACKAGE_PIN F24 [get_ports {sdram_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[13]}]
set_property PACKAGE_PIN F23 [get_ports {sdram_data[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[14]}]
set_property PACKAGE_PIN E23 [get_ports {sdram_data[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sdram_data[15]}]
