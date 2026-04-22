/*
 * test_encoder.c --- Round-trip tests for the low-level encoders.
 *
 * Each test builds a 16-bit word via encode_X and checks that the
 * ISA decode macros extract the same fields back out.
 *
 * Run with: make test
 */
#include "encoder.h"
#include "errors.h"
#include "isa.h"

#include <stdio.h>
#include <stdint.h>

static int failures = 0;

#define CHECK(cond, msg) do {                                         \
    if (!(cond)) {                                                    \
        fprintf(stderr, "FAIL: %s  (%s:%d)\n", msg, __FILE__, __LINE__); \
        failures++;                                                   \
    }                                                                 \
} while (0)

static void test_R(void) {
    uint16_t w = 0;
    int rc = encode_R(OP_ADD, 1, 2, 3, &w);
    CHECK(rc == ERR_OK,                  "encode_R returns OK");
    CHECK(INSTR_OPCODE(w) == OP_ADD,     "R opcode round-trip");
    CHECK(INSTR_RD(w)     == 1,          "R rd round-trip");
    CHECK(INSTR_RS1(w)    == 2,          "R rs1 round-trip");
    CHECK(INSTR_RS2(w)    == 3,          "R rs2 round-trip");

    rc = encode_R(OP_HALT, 0, 0, 0, &w);
    CHECK(rc == ERR_OK,                  "HALT encodes");
    CHECK(INSTR_OPCODE(w) == OP_HALT,    "HALT opcode");
}

static void test_I(void) {
    uint16_t w = 0;
    int rc = encode_I(OP_ADDI, 4, 5, -3, &w);
    CHECK(rc == ERR_OK,                  "encode_I returns OK");
    CHECK(INSTR_OPCODE(w) == OP_ADDI,    "I opcode round-trip");
    CHECK(INSTR_RD(w)     == 4,          "I rd round-trip");
    CHECK(INSTR_RS1(w)    == 5,          "I rs1 round-trip");
    CHECK(INSTR_IMM5(w)   == -3,         "I imm5 round-trip (negative)");

    rc = encode_I(OP_ADDI, 0, 0, 15, &w);
    CHECK(rc == ERR_OK,                  "I imm5=15 OK");
    CHECK(INSTR_IMM5(w)   == 15,         "I imm5=15 round-trip");

    rc = encode_I(OP_ADDI, 0, 0, 16, &w);
    CHECK(rc == ERR_IMM_OVERFLOW,        "I imm5=16 overflows");

    rc = encode_I(OP_ADDI, 0, 0, -16, &w);
    CHECK(rc == ERR_OK,                  "I imm5=-16 OK");
    CHECK(INSTR_IMM5(w)   == -16,        "I imm5=-16 round-trip");

    rc = encode_I(OP_ADDI, 0, 0, -17, &w);
    CHECK(rc == ERR_IMM_OVERFLOW,        "I imm5=-17 overflows");
}

static void test_J(void) {
    uint16_t w = 0;
    int rc = encode_J(OP_JMP, 5, &w);
    CHECK(rc == ERR_OK,                  "encode_J returns OK");
    CHECK(INSTR_OPCODE(w) == OP_JMP,     "J opcode round-trip");
    CHECK(INSTR_OFFSET(w) == 5,          "J offset=5 round-trip");

    rc = encode_J(OP_JMP, -7, &w);
    CHECK(rc == ERR_OK,                  "J negative OK");
    CHECK(INSTR_OFFSET(w) == -7,         "J offset=-7 round-trip");

    rc = encode_J(OP_JMP, 1023, &w);
    CHECK(rc == ERR_OK,                  "J offset=1023 OK");
    CHECK(INSTR_OFFSET(w) == 1023,       "J offset=1023 round-trip");

    rc = encode_J(OP_JMP, -1024, &w);
    CHECK(rc == ERR_OK,                  "J offset=-1024 OK");
    CHECK(INSTR_OFFSET(w) == -1024,      "J offset=-1024 round-trip");

    rc = encode_J(OP_JMP, 1024, &w);
    CHECK(rc == ERR_JUMP_OVERFLOW,       "J offset=1024 overflows");

    rc = encode_J(OP_JMP, -1025, &w);
    CHECK(rc == ERR_JUMP_OVERFLOW,       "J offset=-1025 overflows");
}

static void test_register_bounds(void) {
    uint16_t w = 0;
    int rc = encode_R(OP_ADD, 8, 0, 0, &w);
    CHECK(rc == ERR_INVALID_REGISTER,    "R8 as rd is invalid");
    rc = encode_I(OP_ADDI, 0, 8, 0, &w);
    CHECK(rc == ERR_INVALID_REGISTER,    "R8 as rs1 is invalid");
}

int main(void) {
    test_R();
    test_I();
    test_J();
    test_register_bounds();

    if (failures == 0) {
        printf("all encoder round-trip tests passed\n");
        return 0;
    }
    fprintf(stderr, "%d test(s) failed\n", failures);
    return 1;
}
