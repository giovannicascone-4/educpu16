#!/usr/bin/env bash
# =============================================================================
# tests_programs/test_programs.sh
#
# End-to-end test suite for the three educpu16 assembly programs.
# Each test assembles a .asm source file and verifies the emulator output.
#
# Usage (from repo root):
#   bash tests_programs/test_programs.sh
# Via Makefile:
#   make test_programs
#
# Exit code: 0 if all tests pass, 1 if any test fails.
# =============================================================================

PASS=0
FAIL=0

# Resolve paths relative to this script so it works from any directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASM="$ROOT/assembler_bin"
EMU="$ROOT/emulator_bin"
PROGS="$ROOT/programs"

# Temporary directory for assembled .bin files; cleaned up on exit.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

pass() { printf "  PASS  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL  %s\n" "$1"; FAIL=$((FAIL + 1)); }

# assert_exit_ok <label> <command...>
# Runs a command and passes if it exits with code 0.
assert_exit_ok() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

# assert_output_contains <label> <pattern> <command...>
# Runs a command and passes if its combined stdout+stderr contains pattern.
assert_output_contains() {
    local label="$1"
    local pattern="$2"
    shift 2
    local output
    output="$("$@" 2>&1)"
    if echo "$output" | grep -qF "$pattern"; then
        pass "$label"
    else
        fail "$label (output: $(echo "$output" | head -3))"
    fi
}

# assert_stdout_eq <label> <expected> <command...>
# Runs a command and passes if its stdout matches expected exactly (trimmed).
assert_stdout_eq() {
    local label="$1"
    local expected="$2"
    shift 2
    local actual
    actual="$("$@" 2>/dev/null | tr -d '\r')"
    if [ "$actual" = "$expected" ]; then
        pass "$label"
    else
        fail "$label"
        printf "         expected: %s\n" "$expected"
        printf "           actual: %s\n" "$actual"
    fi
}

# -----------------------------------------------------------------------------
# Pre-flight: verify binaries exist
# -----------------------------------------------------------------------------

echo "educpu16 — end-to-end program tests"
echo "======================================"

if [ ! -x "$ASM" ]; then
    echo "ERROR: assembler_bin not found. Run: make -f Makefile_assembler all"
    exit 1
fi
if [ ! -x "$EMU" ]; then
    echo "ERROR: emulator_bin not found. Run: make all"
    exit 1
fi

# =============================================================================
# Test 1: timer_example.asm
#
# Reads IO_TIMER (0xFF02), adds 42, stores result at 0x0200.
# The timer value is live so we cannot check an exact result; instead we
# verify the program assembles cleanly, runs to HALT, and writes a non-zero
# word to 0x0200 (timer + 42 is zero only on the astronomically unlikely
# wrap case where clock() & 0xFFFF == 0xFFD6).
# =============================================================================

echo ""
echo "[ timer_example ]"

assert_exit_ok \
    "assembles without error" \
    "$ASM" "$PROGS/timer_example.asm" -o "$TMP/timer_example.bin"

assert_exit_ok \
    "emulator exits cleanly" \
    "$EMU" "$TMP/timer_example.bin"

# Extract the first word from the dump at 0x0200 and convert to decimal.
TIMER_DUMP="$("$EMU" "$TMP/timer_example.bin" --dump --addr 0200 2>/dev/null | head -1)"
TIMER_WORD="$(echo "$TIMER_DUMP" | awk '{print $2}')"
TIMER_VALUE="$((16#${TIMER_WORD:-0}))"

if [ "$TIMER_VALUE" -ne 0 ]; then
    pass "result written to 0x0200 (value = 0x$(printf '%04X' "$TIMER_VALUE"), decimal $TIMER_VALUE)"
else
    fail "result at 0x0200 is zero — store may not have executed"
fi

# =============================================================================
# Test 2: fibonacci.asm
#
# Computes F(0)..F(9) and stores them starting at 0x0300.
# Expected dump first line: 0300: 0000 0001 0001 0002 0003 0005 0008 000D
# Expected dump second word on second line: 0015 0022 (F(8)=21, F(9)=34)
# =============================================================================

echo ""
echo "[ fibonacci ]"

assert_exit_ok \
    "assembles without error" \
    "$ASM" "$PROGS/fibonacci.asm" -o "$TMP/fibonacci.bin"

assert_exit_ok \
    "emulator exits cleanly" \
    "$EMU" "$TMP/fibonacci.bin"

assert_output_contains \
    "first 8 terms correct at 0x0300 (0,1,1,2,3,5,8,13)" \
    "0300: 0000 0001 0001 0002 0003 0005 0008 000D" \
    "$EMU" "$TMP/fibonacci.bin" --dump --addr 0300

assert_output_contains \
    "last 2 terms correct at 0x0308 (21,34)" \
    "0308: 0015 0022" \
    "$EMU" "$TMP/fibonacci.bin" --dump --addr 0300

# =============================================================================
# Test 3: hello.asm
#
# Prints "Hello, World!\n" to stdout via memory-mapped IO_STDOUT (0xFF00).
# =============================================================================

echo ""
echo "[ hello ]"

assert_exit_ok \
    "assembles without error" \
    "$ASM" "$PROGS/hello.asm" -o "$TMP/hello.bin"

assert_exit_ok \
    "emulator exits cleanly" \
    "$EMU" "$TMP/hello.bin"

assert_stdout_eq \
    "stdout is exactly 'Hello, World!'" \
    "Hello, World!" \
    "$EMU" "$TMP/hello.bin"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "======================================"
TOTAL=$((PASS + FAIL))
printf "%d / %d tests passed\n" "$PASS" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
    printf "%d test(s) failed\n" "$FAIL"
    exit 1
fi

echo "all program tests passed"
exit 0
