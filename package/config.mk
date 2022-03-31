PROJECT := CN

# PLATFORM setting
PLATFORM := xilinx_u55n_gen3x4_xdma_1_202110_1

# TARGET {sw_emu|hw_emu|hw}
TARGET := hw_emu

HLS_KERNELS := krnl_mm2s.xo krnl_s2mm.xo
RTL_KERNELS := cryptonight.xo

PACKAGE_SCRIPT = $(PKGDIR)/scripts/package.tcl

HOST_SRCS  = src/host/host.cpp
HOST_SRCS += common/includes/cmdparser/cmdlineparser.cpp 
HOST_SRCS += common/includes/logger/logger.cpp

CXXFLAGS  += -Icommon/includes/cmdparser
CXXFLAGS  += -Icommon/includes/logger
CXXFLAGS  += -Isrc/hls
CXXFLAGS  += -Wno-int-in-bool-context
LDFLAGS   += 

EM_DIR    := ./build/$(PLATFORM)/emconfig
BUILD_DIR := ./build/$(PLATFORM)/$(TARGET)
RUN_DIR   := ./run/$(PLATFORM)/$(TARGET)

TMP_DIR   := $(BUILD_DIR)/tmp
LOG_DIR   := $(BUILD_DIR)/logs
REP_DIR   := $(BUILD_DIR)/reports

############################## Setting Targets ##############################

## hls 
HLS_KERNELS := $(patsubst %, $(BUILD_DIR)/%, $(HLS_KERNELS))
$(HLS_KERNELS) : $(BUILD_DIR)/%.xo : src/hls/%.cpp
	$(VPP) $(VPP_FLAGS) --compile --kernel $* -o $@ $^

## rtl
RTL_KERNELS := $(patsubst %, $(BUILD_DIR)/%, $(RTL_KERNELS))
$(RTL_KERNELS) : $(BUILD_DIR)/%.xo : 
	$(VIVADO) -mode batch -source $(PACKAGE_SCRIPT) -nojournal -log $(LOG_DIR)/vivado_$*.log -tclargs $* $(TARGET) $(PLATFORM) $(BUILD_DIR) $(TMP_DIR)

# KERNELS := $(HLS_KERNELS) $(RTL_KERNELS)
KERNELS := $(RTL_KERNELS)
