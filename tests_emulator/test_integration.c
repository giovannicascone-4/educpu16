#include <stdio.h>
#include <stdlib.h>

#include "../assembler/isa.h"
#include "../emulator/alu.h"
#include "../emulator/control.h"
#include "../emulator/cpu.h"
#include "../emulator/memory.h"

static int failures = 0;

#define CHECK(cond, msg)                                                         \
    do {                                                                         \
        if (!(cond)) {                                                           \
            fprintf(stderr, "FAIL: %s (%s:%d)\n", (msg), __FILE__, __LINE__);   \
            failures++;                                                          \
        }                                                                        \
    } while (0)

static void test_forward_and_conditional_jumps(void) {
    /* From bug report live proof listing. */
    const uint16_t program[] = {
        0x6000u, /* MOV R0, 0 */
        0x6100u, /* MOV R1, 0 */
        0x6804u, /* CMP R0, R1 (ZF = 1) */
        0x7801u, /* JEQ SKIP */
        0xF800u, /* HALT_BAD (must be skipped) */
        0x7001u, /* JMP DONE */
        0xF800u, /* HALT_ALSO_BAD (must be skipped) */
        0x6207u, /* MOV R2, 7 (canary) */
        0xF800u  /* HALT */
    };
    CPU cpu;

    cpu_init(&cpu);
    cpu_reset(&cpu);
    mem_load(program, (uint16_t)(sizeof(program) / sizeof(program[0])), 0u);

    cpu_run(&cpu);

    CHECK(cpu.halted, "CPU halts at end of program");
    CHECK(cpu.regs[2] == 7u, "R2 canary is set to 7 after jumps");
    CHECK(cpu.pc == 0x0009u, "PC points just past final HALT");
    CHECK(cpu.cycle_count == 7u, "Only executed instructions are counted");
}

int main(void) {
    test_forward_and_conditional_jumps();

    if (failures != 0) {
        fprintf(stderr, "%d integration test(s) failed\n", failures);
        return EXIT_FAILURE;
    }

    puts("all emulator integration tests passed");
    return EXIT_SUCCESS;
}
