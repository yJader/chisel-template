include $(NVBOARD_HOME)/scripts/nvboard.mk

# 工程描述
# 子工程对应文件夹
PROJECT_DIR = 
# package名
MILL_MODULE_NAME = 

# 顶层模块名, 默认为Top
TOPNAME = Top
NXDC_FILES = src/main/verilog/$(TOPNAME).nxdc


# 依赖的库
VERILATOR = verilator
NVBOARD_CFLAGS = -I$(NVBOARD_HOME)/usr/include
MILL = mill
# RUN_MILL = cd .. && $(MILL)
RUN_MILL = $(MILL)

# 生成文件
# TODO: 为什么定义在SRC_AUTO_BIND之后, 会找不到target, 但test_echo可以打印出值
BUILD_DIR = $(PROJECT_DIR)/build
$(BUILD_DIR): check_vars
	$(shell mkdir -p $(BUILD_DIR))

OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

# constraint file
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)

# project source files
CHISEL_SRC_DIR = $(PROJECT_DIR)/src/main/scala/$(MILL_MODULE_NAME)
CPP_DIR = $(PROJECT_DIR)/src/main/cpp
VERILOG_DIR = $(PROJECT_DIR)/src/main/verilog
$(VERILOG_DIR): check_vars
	$(shell mkdir -p $(VERILOG_DIR))
VSRCS = $(abspath $(VERILOG_DIR)/*.sv)
CSRCS = $(abspath $(CPP_DIR))/*.cpp
CSRCS += $(SRC_AUTO_BIND)
# 必须用绝对路径 否则verilator在指定输出目录后会找不到文件
# SOURCE_FILES += top.v sim_main.cpp

# SRC_AUTO_BIND = /home/jader/ysyx/ysyx-workbench/preLearning/verilator/test_top/build/auto_bind.cpp
$(SRC_AUTO_BIND): $(NXDC_FILES)
	@echo "Generating auto bind file"
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

$(VSRCS): $(CHISEL_SRC_DIR)/*.scala
	$(RUN_MILL) $(MILL_MODULE_NAME).runMain --mainClass $(MILL_MODULE_NAME).Main -o=$(abspath $(VERILOG_DIR))

$(BIN): $(VSRCS) $(CSRCS)
	@echo "Building $(BIN) ..."
	$(VERILATOR) --cc --exe --trace --build -j 0 -Wall -Wno-UNUSEDSIGNAL $^ verilated_vcd_c.cpp $(NVBOARD_ARCHIVE) \
		--top-module $(TOPNAME) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) $(addprefix -CFLAGS , $(NVBOARD_CFLAGS)) \
		--Mdir $(OBJ_DIR) -o $(abspath $(BIN)) 
	@echo "Building $(BIN) done"

# makefile调试
test_echo:
	@echo PWD: $(PWD)
	@echo VERILOG_FILES: $(VSRCS)
	@echo $(NXDC_FILES) $(SRC_AUTO_BIND)
	@echo CHISEL_SRC_DIR=$(CHISEL_SRC_DIR)
	@echo $(addprefix -LDFLAGS , $(LDFLAGS)) $(addprefix -CFLAGS , $(NVBOARD_CFLAGS))

# 运行chisel测试
TEST_MODULE = all
test_chisel:
ifeq ($(TEST_MODULE), all)
	@echo "run test all"
	$(RUN_MILL) $(MILL_MODULE_NAME).test -oF
else
	$(RUN_MILL) $(MILL_MODULE_NAME).test.testOnly $(MILL_MODULE_NAME).$(TEST_MODULE) -oF
endif

# 手动编译出verilog文件
sv: $(VSRCS)

cc: $(VSRCS)
	$(VERILATOR) --cc --build -j 0 $^ --Mdir $(OBJ_DIR) --top-module $(TOPNAME)

bind: $(SRC_AUTO_BIND)

sim: $(BIN)

run: $(BIN)
	export export DISPLAY=:0.0 && $(BIN)

clean:
	rm -rf $(BUILD_DIR) 
	rm -rf $(VERILOG_DIR)/*.sv $(VERILOG_DIR)/filelist.f
	rm -rf out

check_vars:
ifndef PROJECT_DIR
    $(error PROJECT_DIR is not defined)
else 
	$(info PROJECT_DIR: $(PROJECT_DIR))
endif
ifndef MILL_MODULE_NAME
    $(error MILL_MODULE_NAME is not defined)
else
	$(info MILL_MODULE_NAME: $(MILL_MODULE_NAME))
endif

.PHONY: clean sim run cc sv test_chisel test_echo bind check_vars