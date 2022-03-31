#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

RM = rm -f
RMDIR = rm -rf
CP = cp -rf
ECHO := @echo
VPP := v++
VIVADO := vivado

############################## Help Section ##############################
.PHONY: help

help::
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw>"
	$(ECHO) "      Command to generate the design for specified Target."
	$(ECHO) ""
	$(ECHO) "  make clean"
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<sw_emu/hw_emu/hw> "
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<sw_emu/hw_emu/hw>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make host"
	$(ECHO) "      Command to build host application."
	$(ECHO) ""

############################## Configure Project Variables ##############################

PKGDIR := package
include $(PKGDIR)/config.mk

DUMMY := $(shell mkdir -p build)
DUMMY := $(shell mkdir -p run)
DUMMY := $(shell mkdir -p $(RUN_DIR))
DUMMY := $(shell mkdir -p $(TMP_DIR))
DUMMY := $(shell mkdir -p $(LOG_DIR))
DUMMY := $(shell mkdir -p $(REP_DIR))

############################## Setting up Host Variables ##############################

XRT_INCLUDE:= $(XILINX_XRT)/include
VIVADO_INCLUDE:= $(XILINX_VIVADO)/include
VITIS_INCLUDE:= $(XILINX_VITIS)/include
XRT_LIB:= $(XILINX_XRT)/lib

CXXFLAGS += -I$(XRT_INCLUDE) -I$(VIVADO_INCLUDE) -I$(VITIS_INCLUDE) -Wall -O0 -g -std=c++1y
LDFLAGS  += -L$(XRT_LIB) -lOpenCL -pthread

#Include Required Host Source Files
CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 
LDFLAGS += -luuid -lxrt_coreutil
LDFLAGS += -pthread

############################## Setting up Kernel Variables ##############################

CONFIG_FILES := $(patsubst %,--config %, $(wildcard $(PKGDIR)/cfg/*.cfg))

# Kernel compiler global settings
VPP_FLAGS += --target $(TARGET) --platform $(PLATFORM) $(CONFIG_FILES) --save-temps 
VPP_FLAGS += --temp_dir $(TMP_DIR) --log_dir $(LOG_DIR) --report_dir $(REP_DIR)
ifneq ($(TARGET), hw)
	VPP_FLAGS += -g
endif

############################## Setting Targets ##############################

BINARY_CONTAINER := $(BUILD_DIR)/$(PROJECT).xclbin
EXECUTABLE := $(RUN_DIR)/$(PROJECT)
EMCONFIG := $(EM_DIR)/emconfig.json

.PHONY: host
host: $(EXECUTABLE)

.PHONY: build
build: $(BINARY_CONTAINER)

# Building kernel
$(BINARY_CONTAINER): $(KERNELS)
	mkdir -p $(BUILD_DIR)
	$(VPP) $(VPP_FLAGS) --link $(VPP_LDFLAGS) -o $@ $^

############################## Setting Rules for Host (Building Host Executable) ##############################

$(EXECUTABLE): $(HOST_SRCS) 
		$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

$(EMCONFIG):
	emconfigutil --platform $(PLATFORM) --od $(EM_DIR)

############################## Setting Essential Checks and Running Rules ##############################

.PHONY: run
run: build host $(EMCONFIG)
	$(CP) $(BINARY_CONTAINER) $(RUN_DIR)
	$(CP) xrt.ini $(RUN_DIR)
	$(CP) xsim.tcl $(RUN_DIR)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	$(CP) $(EMCONFIG) $(RUN_DIR)
	cd $(RUN_DIR) && XCL_EMULATION_MODE=$(TARGET) ./$(PROJECT) --xclbin_file $(PROJECT).xclbin --device_id 0
else
	cd $(RUN_DIR) && ./$(PROJECT) --xclbin_file $(PROJECT).xclbin --device_id 0
endif

############################## Utility ##############################

.PHONY: platforminfo
platforminfo: $(PLATFORM).pinfo

$(PLATFORM).pinfo:
	platforminfo --force --platform $(PLATFORM) -o $@

.PHONY: vitis_analyzer
vitis_analyzer: 
	vitis_analyzer .

############################## Cleaning Rules ##############################

.PHONY: clean
clean:
	-$(RM) *.jou *.log *.str

.PHONY: cleanrun
cleanrun: clean
	-$(RMDIR) run/*

.PHONY: cleanbuild
cleanbuild: cleanrun
	-$(RMDIR) build/*

.PHONY: cleanall
cleanall: cleanrun cleanbuild
	-$(RMDIR) .Xil .run .ipcache