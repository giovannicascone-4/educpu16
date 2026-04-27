#include <stdio.h>
#include <stdlib.h>

#include "../assembler/isa.h"
#include "../emulator/alu.h"
#include "../emulator/cpu.h"

static int failures = 0;

#define CHECK(cond, msg)                                                         \
    do {                                                                         \
        if (!(cond)) {                                                           \
            fprintf(stderr, "FAIL: %s (%s:%d)\n", (msg), __FILE__, __LINE__);   \
            failures++;                                                          \
        }                                                                        \
    } while (0)

static void reset_cpu(CPU *cpu) {
    cpu_init(cpu);
    cpu_reset(cpu);
}

static void test_add_signed_overflow(void) {
    CPU cpu;
    uint16_t r;

    reset_cpu(&cpu);
    r = alu_execute(&cpu, OP_ADD, 0x7FFFu, 0x0001u);
    CHECK(r == 0x8000u, "ADD overflow result");
    CHECK((cpu.flags & FLAG_OF) != 0u, "ADD sets OF on signed overflow");
    CHECK((cpu.flags & FLAG_CF) == 0u, "ADD overflow case does not set CF");
    CHECK((cpu.flags & FLAG_NF) != 0u, "ADD overflow sets NF for negative result");
    CHECK((cpu.flags & FLAG_ZF) == 0u, "ADD overflow keeps ZF clear");
}

static void test_add_unsigned_carry(void) {
    CPU cpu;
    uint16_t r;

    reset_cpu(&cpu);
    r = alu_execute(&cpu, OP_ADD, 0xFFFFu, 0x0001u);
    CHECK(r == 0x0000u, "ADD carry wraps to zero");
    CHECK((cpu.flags & FLAG_CF) != 0u, "ADD sets CF on unsigned carry");
    CHECK((cpu.flags & FLAG_OF) == 0u, "ADD carry case keeps OF clear");
    CHECK((cpu.flags & FLAG_ZF) != 0u, "ADD carry sets ZF for zero result");
    CHECK((cpu.flags & FLAG_NF) == 0u, "ADD carry keeps NF clear");
}

static void test_sub_borrow(void) {
    CPU cpu;
    uint16_t r;

    reset_cpu(&cpu);
    r = alu_execute(&cpu, OP_SUB, 0x0000u, 0x0001u);
    CHECK(r == 0xFFFFu, "SUB borrow result");
    CHECK((cpu.flags & FLAG_CF) != 0u, "SUB sets CF when borrow occurs");
    CHECK((cpu.flags & FLAG_OF) == 0u, "SUB borrow case keeps OF clear");
    CHECK((cpu.flags & FLAG_NF) != 0u, "SUB borrow sets NF");
    CHECK((cpu.flags & FLAG_ZF) == 0u, "SUB borrow keeps ZF clear");
}

static void test_cmp_flags(void) {
    CPU cpu;

    reset_cpu(&cpu);
    (void)alu_execute(&cpu, OP_CMP, 0x0005u, 0x0005u);
    CHECK((cpu.flags & FLAG_ZF) != 0u, "CMP equal sets ZF");
    CHECK((cpu.flags & FLAG_NF) == 0u, "CMP equal clears NF");
    CHECK((cpu.flags & FLAG_CF) == 0u, "CMP equal clears CF");
}

static void test_bitwise_preserves_cf_of(void) {
    CPU cpu;
    uint16_t r;
    uint8_t before;

    reset_cpu(&cpu);
    cpu.flags = FLAG_CF | FLAG_OF;
    before = cpu.flags & (FLAG_CF | FLAG_OF);
    r = alu_execute(&cpu, OP_AND, 0x00F0u, 0x0FF0u);
    CHECK(r == 0x00F0u, "AND result");
    CHECK((cpu.flags & (FLAG_CF | FLAG_OF)) == before, "AND preserves CF and OF");

    before = cpu.flags & (FLAG_CF | FLAG_OF);
    r = alu_execute(&cpu, OP_OR, 0x000Fu, 0x00F0u);
    CHECK(r == 0x00FFu, "OR result");
    CHECK((cpu.flags & (FLAG_CF | FLAG_OF)) == before, "OR preserves CF and OF");

    before = cpu.flags & (FLAG_CF | FLAG_OF);
    r = alu_execute(&cpu, OP_XOR, 0x00FFu, 0x0F0Fu);
    CHECK(r == 0x0FF0u, "XOR result");
    CHECK((cpu.flags & (FLAG_CF | FLAG_OF)) == before, "XOR preserves CF and OF");

    before = cpu.flags & (FLAG_CF | FLAG_OF);
    r = alu_execute(&cpu, OP_NOT, 0x0000u, 0u);
    CHECK(r == 0xFFFFu, "NOT result");
    CHECK((cpu.flags & (FLAG_CF | FLAG_OF)) == before, "NOT preserves CF and OF");
}

static void test_shift_and_addi(void) {
    CPU cpu;
    uint16_t r;

    reset_cpu(&cpu);
    r = alu_execute(&cpu, OP_SHL, 0x8000u, 1u);
    CHECK(r == 0x0000u, "SHL result");
    CHECK((cpu.flags & FLAG_CF) != 0u, "SHL sets CF when high bit shifts out");
    CHECK((cpu.flags & FLAG_ZF) != 0u, "SHL zero result sets ZF");

    cpu.flags = FLAG_CF | FLAG_OF;
    r = alu_execute(&cpu, OP_SHR, 0x0001u, 1u);
    CHECK(r == 0x0000u, "SHR result");
    CHECK((cpu.flags & FLAG_CF) != 0u, "SHR preserves incoming CF");
    CHECK((cpu.flags & FLAG_OF) != 0u, "SHR preserves incoming OF");
    CHECK((cpu.flags & FLAG_ZF) != 0u, "SHR zero result sets ZF");

    reset_cpu(&cpu);
    r = alu_execute(&cpu, OP_ADDI, 0x0002u, 0x0003u);
    CHECK(r == 0x0005u, "ADDI basic result");
    CHECK((cpu.flags & FLAG_ZF) == 0u, "ADDI nonzero clears ZF");
    CHECK((cpu.flags & FLAG_NF) == 0u, "ADDI positive clears NF");
}

int main(void) {
    test_add_signed_overflow();
    test_add_unsigned_carry();
    test_sub_borrow();
    test_cmp_flags();
    test_bitwise_preserves_cf_of();
    test_shift_and_addi();

    if (failures != 0) {
        fprintf(stderr, "%d ALU test(s) failed\n", failures);
        return EXIT_FAILURE;
    }

    puts("all emulator ALU tests passed");
    return EXIT_SUCCESS;
}
