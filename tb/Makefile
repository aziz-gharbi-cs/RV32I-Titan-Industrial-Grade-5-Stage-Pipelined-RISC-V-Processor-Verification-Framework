TOPLEVEL_LANG ?= vhdl
SIM ?= ghdl

VHDL_SOURCES = $(shell pwd)/../rtl/bus/wb_pkg.vhd \
               $(shell pwd)/../rtl/core/pipeline_pkg.vhd \
               $(shell pwd)/../rtl/core/regfile.vhd \
               $(shell pwd)/../rtl/core/alu.vhd \
               $(shell pwd)/../rtl/core/imm_gen.vhd \
               $(shell pwd)/../rtl/core/control_unit.vhd \
               $(shell pwd)/../rtl/core/forwarding_unit.vhd \
               $(shell pwd)/../rtl/core/hazard_unit.vhd \
               $(shell pwd)/../rtl/core/datapath.vhd \
               $(shell pwd)/../rtl/periph/wb_ram.vhd \
               $(shell pwd)/../rtl/periph/wb_uart.vhd \
               $(shell pwd)/../rtl/top_soc.vhd

TOPLEVEL = top_soc
COCOTB_TEST_MODULES = tests.test_soc
GHDL_ARGS = --std=08

include $(shell cocotb-config --makefiles)/Makefile.sim
