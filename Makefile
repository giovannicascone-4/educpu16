CC := cc
CFLAGS := -Wall -Wextra -std=c11

BUILD := build
EMULATOR_SRCS := $(wildcard emulator/*.c)
EMULATOR_BIN := emulator_bin
TEST_ALU_BIN := $(BUILD)/test_alu

.PHONY: all clean test test_emulator

all: $(EMULATOR_BIN)

$(EMULATOR_BIN): $(EMULATOR_SRCS)
	$(CC) $(CFLAGS) $^ -o $@

$(BUILD):
	mkdir -p $(BUILD)

test: test_emulator

test_emulator: | $(BUILD)
	$(CC) $(CFLAGS) tests_emulator/test_alu.c emulator/alu.c emulator/cpu.c emulator/control.c emulator/memory.c -o $(TEST_ALU_BIN)
	./$(TEST_ALU_BIN)

clean:
	rm -rf $(BUILD) $(EMULATOR_BIN)
