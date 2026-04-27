# CPU Design FA25: Software CPU Project
## Technical Specification

**Team Members:** Kunal · Nikhil · Gio · Dhruv  
**Course:** CPU Design FA25  
**Document Type:** Technical Specification  
**Assigned To:** Nikhil  
**Primary Role:** Emulator Engineer  

---

## 1. Role Overview
Nikhil is responsible for implementing the software CPU emulator in C/C++.
The emulator faithfully simulates all hardware components: registers, ALU, control unit, bus, memory, memory-mapped I/O, and the fetch/decode/execute cycle.
It must load binary programs, run them, and provide a memory dump on exit.

## 2. File Structure

| File | Description |
| :--- | :--- |
| `emulator/main.c` | Entry point: parse CLI args, load binary, run, dump memory |
| `emulator/cpu.h` | CPU state struct, register definitions, flag bit masks |
| `emulator/cpu.c` | CPU init, reset, single-step, run-to-halt |
| `emulator/alu.h/.c` | All ALU operations, flag updates |
| `emulator/memory.h/.c` | 64 KB memory array, read/write, memory-mapped I/O hooks |
| `emulator/bus.h/.c` | Address bus / data bus abstraction layer |
| `emulator/control.h/.c` | Decode opcode, dispatch to execute handlers |
| `Makefile` | Build rules: cc -Wall -Wextra -std=c11 |

## 3. CPU State (cpu.h)
```c
// cpu.h
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "../isa/isa.h"

/* Flag bit positions in FLAGS register */
#define FLAG_ZF  (1 << 0)   /* Zero      */
#define FLAG_NF  (1 << 1)   /* Negative  */
#define FLAG_CF  (1 << 2)   /* Carry     */
#define FLAG_OF  (1 << 3)   /* Overflow  */

typedef struct {
    uint16_t regs[8];       /* R0 – R7                     */
    uint16_t pc;            /* Program Counter             */
    uint16_t ir;            /* Instruction Register        */
    uint16_t sp;            /* Stack Pointer (R7 alias)    */
    uint8_t  flags;         /* ZF | NF | CF | OF           */
    uint64_t cycle_count;   /* total cycles executed       */
    bool     halted;        /* true after HALT             */
} CPU;

void cpu_init(CPU *cpu);
void cpu_reset(CPU *cpu);
void cpu_step(CPU *cpu);          /* single fetch-decode-execute */
void cpu_run(CPU *cpu);           /* run until HALT              */
void cpu_dump(const CPU *cpu);    /* print register state        */

## 4. ALU Module (alu.c) [cite: 43]
[cite_start]The ALU module exposes a single function `alu_execute()` that takes an operation code and two operands, updates the CPU flags, and returns the result[cite: 44]. [cite_start]Flag update rules must match Kunal's ISA specification exactly[cite: 45].

```c
// alu.c  (selected excerpt)
uint16_t alu_execute(CPU *cpu, uint8_t op, uint16_t a, uint16_t b) {
    uint32_t result32 = 0;
    uint16_t result   = 0;

    switch (op) {
        case OP_ADD: result32 = (uint32_t)a + b; break;
        case OP_SUB: result32 = (uint32_t)a - b; break;
        case OP_AND: result   = a & b; goto no_carry;
        case OP_OR:  result   = a | b; goto no_carry;
        case OP_XOR: result   = a ^ b; goto no_carry;
        case OP_NOT: result   = ~a;    goto no_carry;
        case OP_SHL: result32 = (uint32_t)a << (b & 0xF); break;
        case OP_SHR: result   = a >> (b & 0xF); goto no_carry;
    }
    result = (uint16_t)result32;
    
    /* Carry flag */
    if (result32 > 0xFFFF) cpu->flags |=  FLAG_CF;
    else                   cpu->flags &= ~FLAG_CF;
    
    /* Overflow flag (signed) */
    bool sign_a = (a >> 15) & 1;
    bool sign_b = (b >> 15) & 1;
    bool sign_r = (result >> 15) & 1;
    if ((op==OP_ADD) && (sign_a==sign_b) && (sign_r!=sign_a))
        cpu->flags |= FLAG_OF;
    else cpu->flags &= ~FLAG_OF;
        
no_carry:
    /* Zero and Negative flags */
    if (result == 0)       cpu->flags |=  FLAG_ZF;
    else                   cpu->flags &= ~FLAG_ZF;
    if ((result >> 15)&1)  cpu->flags |=  FLAG_NF;
    else                   cpu->flags &= ~FLAG_NF;
    
    return result;
}

## 5. Memory and Memory-Mapped I/O (memory.c)
Memory is a flat 65536-element `uint16_t` array. [cite_start]Reads and writes above `0xFF00` are intercepted for I/O[cite: 80].

```c
// memory.c (key functions)
static uint16_t mem[MEM_SIZE];

uint16_t mem_read(uint16_t addr) {
    if (addr == IO_STDIN)  return (uint16_t)getchar();
    if (addr == IO_TIMER)  return (uint16_t)(clock() & 0xFFFF);
    return mem[addr];
}

void mem_write(uint16_t addr, uint16_t val) {
    if (addr == IO_STDOUT) { putchar((char)val); return; }
    if (addr >= IO_BASE)   return;  /* other I/O: ignore */
    mem[addr] = val;
}

void mem_load(const uint16_t *program, uint16_t len, uint16_t base) {
    for (uint16_t i = 0; i < len; i++)
        mem[base + i] = program[i];
}

void mem_dump(uint16_t start, uint16_t end) {
    for (uint16_t a = start; a < end; a += 8) {
        printf("%04X: ", a);
        for (int i = 0; i < 8 && a+i < end; i++)
            printf("%04X ", mem[a+i]);
        printf("\n");
    }
}

## 6. Control Unit & Fetch-Decode-Execute (control.c)
```c
// control.c — cpu_step() implements one complete FDE cycle
void cpu_step(CPU *cpu) {
    /* ── FETCH ── */
    cpu->ir = mem_read(cpu->pc++);
    cpu->cycle_count++;

    /* ── DECODE ── */
    uint8_t  op  = INSTR_OPCODE(cpu->ir);
    uint8_t  rd  = INSTR_RD(cpu->ir);
    uint8_t  rs1 = INSTR_RS1(cpu->ir);
    uint8_t  rs2 = INSTR_RS2(cpu->ir);
    int16_t  imm = INSTR_IMM5(cpu->ir);
    int16_t  off = INSTR_IMM15(cpu->ir);

    /* ── EXECUTE ── */
    switch (op) {
        case OP_ADD: cpu->regs[rd] = alu_execute(cpu,op,cpu->regs[rs1],cpu->regs[rs2]); break;
        case OP_LW:  cpu->regs[rd] = mem_read(cpu->regs[rs1] + imm); break;
        case OP_SW:  mem_write(cpu->regs[rs1] + imm, cpu->regs[rd]); break;
        case OP_JMP: cpu->pc += off - 1; break;  /* -1: PC already advanced */
        case OP_JEQ: if (cpu->flags & FLAG_ZF) cpu->pc += off - 1; break;
        case OP_HALT: cpu->halted = true; break;
        /* ... remaining cases ... */
    }
}

## 7. Command-Line Interface (main.c)
The emulator accepts the following command-line arguments:

| Command | Description |
| :--- | :--- |
| `emulator <file.bin>` | Load binary and run to HALT |
| `emulator <file.bin> --dump` | Run then dump full memory to stdout |
| `emulator <file.bin> --step` | Interactive single-step mode |
| `emulator <file.bin> --trace` | Print each instruction as it executes |
| `emulator <file.bin> --addr X` | Memory dump starting at hex address X |