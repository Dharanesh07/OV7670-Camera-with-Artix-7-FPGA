# Project setup
PROJ       = top
TOP_MODULE = top 
DEVICE     = xc7a100tfgg676-1

# Source directories
SRC_DIR   	 	= src
TB_DIR    	 	= tb
BUILD 	  	 	= build
TCL_SCRIPT	 	= syn.tcl
TCL_REP_SCRIPT	= syn_report.tcl
LOG_DIR	  	 	= logs
IP_DIR  		= ip

## SIMULATION
SIM				= top
SIM_SNAPSHOT	= sim_snapshot
SIM_DIR 		= sim_output
STATE_FILE      = waveform.surf.ron
SIM_FILES      	= $(TB_DIR)/top_tb.v \
				  $(TB_DIR)/mt48lc16m16a2.v \
				  $(TB_DIR)/ov7670_vcd.v \
				  $(TB_DIR)/clock.v \
				  $(SRC_DIR)/top.v \
				  $(SRC_DIR)/fifo.v \
				  $(SRC_DIR)/ov7670.v \
				  $(SRC_DIR)/ov7670_frame_grabber.v \
				  $(SRC_DIR)/dual_port_bram.v \
				  $(SRC_DIR)/i2c.v \
				  $(SRC_DIR)/sdram.v \
				  $(SRC_DIR)/sdram_controller.v \
				  $(SRC_DIR)/vga.v \
				  $(SRC_DIR)/vga_controller.v \
				  $(SRC_DIR)/async_fifo/write_ptr.v \
				  $(SRC_DIR)/async_fifo/read_ptr.v \
				  $(SRC_DIR)/async_fifo/synchronizer.v \
				  $(SRC_DIR)/async_fifo/fifo_mem.v \
				  $(SRC_DIR)/async_fifo/async_fifo.v \
				  $(SRC_DIR)/reset.v \
				  $(SRC_DIR)/bram.v
				  

SIM_EXEC		= $(SIM_DIR)/$(SIM)_tb.vvp
VCD_FILE		= $(SIM_DIR)/$(SIM)_tb.vcd

# VERILATOR_TOP   = top
# VERILATOR_SRC   = $(SRC_DIR)/*.v

VERILATOR_TOP   = top

VERILATOR_SRC   = $(TB_DIR)/top_tb.v \
				  $(TB_DIR)/mt48lc16m16a2.v \
				  $(TB_DIR)/ov7670_vcd.v \
				  $(SRC_DIR)/top.v \
				  $(SRC_DIR)/fifo.v \
				  $(SRC_DIR)/ov7670.v \
				  $(SRC_DIR)/ov7670_frame_grabber.v \
				  $(SRC_DIR)/dual_port_bram.v \
				  $(SRC_DIR)/i2c.v \
				  $(SRC_DIR)/sdram.v \
				  $(SRC_DIR)/sdram_controller.v \
				  $(SRC_DIR)/vga.v \
				  $(SRC_DIR)/vga_controller.v \
				  $(SRC_DIR)/async_fifo/write_ptr.v \
				  $(SRC_DIR)/async_fifo/read_ptr.v \
				  $(SRC_DIR)/async_fifo/synchronizer.v \
				  $(SRC_DIR)/async_fifo/fifo_mem.v \
				  $(SRC_DIR)/async_fifo/async_fifo.v \
				  $(TB_DIR)/clock.v \
				  $(SRC_DIR)/reset.v \
				  $(SRC_DIR)/bram.v


TIMESTAMP = $(shell date +%Y%m%d_%H%M%S)

.PHONY: all clean prog timing verify sim


all: build prog
	
build: build_folder | log_folder
	vivado -mode tcl \
		-journal $(LOG_DIR)/$(PROJ)_build_$(TIMESTAMP).jou \
		-log $(LOG_DIR)/$(PROJ)_build_$(TIMESTAMP).log \
		-source $(TCL_SCRIPT) \
		-tclargs $(TOP_MODULE) $(SRC_DIR) $(BUILD) $(DEVICE)

build_report: build_folder | log_folder
	vivado -mode batch \
		-journal $(LOG_DIR)/$(PROJ)_build_$(TIMESTAMP).jou \
		-log $(LOG_DIR)/$(PROJ)_build_$(TIMESTAMP).log \
		-source $(TCL_REP_SCRIPT) \
		-tclargs $(TOP_MODULE) $(SRC_DIR) $(BUILD) $(DEVICE)

prog: $(BUILD)/$(PROJ).bit
	@echo 'Programming in RAM Mode'
	openFPGALoader -c xvc-client --port 2542 $(BUILD)/$(PROJ).bit

lint:
	@echo "Running Verilator lint..."
	verilator --lint-only \
		-Wall \
		-Wno-fatal \
		--top-module $(VERILATOR_TOP) \
		$(VERILATOR_SRC)

sim: $(SIM_FILES)
	#xvlog $(SRC_DIR)/$(SIM_NAME).v
	#xvlog $(TB_DIR)/$(SIM_NAME)_tb.v
	#xelab -debug typical $(SIM_NAME)_tb -snapshot $(SIM_SNAPSHOT)
	#xsim $(SIM_SNAPSHOT) -gui -tclbatch sim_cmd.tcl
	mkdir -p $(SIM_DIR)
	iverilog -g2012 \
		-s $(SIM)_tb \
		-o $(SIM_EXEC) $(SIM_FILES)
	vvp $(SIM_EXEC)
	surfer $(VCD_FILE) -s $(STATE_FILE) &

sim_clean:
	#rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.str
	rm -rf $(SIM_DIR)/*

build_folder:
	mkdir -p $(BUILD)

log_folder:
	mkdir -p $(LOG_DIR)

clean:
	rm $(BUILD)/*
	rm $(LOG_DIR)/*
