# CPU Design FA25 - ISA Overview

This project currently focuses on the Instruction Set Architecture (ISA) contract and the assembler pipeline.

## What Is an ISA?

An ISA (Instruction Set Architecture) is the agreement between software and CPU hardware (or emulator).  
It defines:

- What instructions exist (for example `ADD`, `LW`, `JMP`)
- How each instruction is encoded in bits
- How registers and memory are addressed
- What behavior each instruction must produce

In this project, the ISA is the shared interface used by both sides:

- **Assembler side (Gio):** converts assembly mnemonics into 16-bit machine words
- **Emulator side (Nikhil):** decodes those words and executes the defined behavior

Because both components depend on the same instruction definitions, the ISA header must remain stable.

## Kunal's ISA Contract in This Repo

Kunal's contribution is represented by `assembler/isa.h`, which provides:

- Opcode constants (`OP_ADD` through `OP_HALT`)
- Register and memory constants (`NUM_REGS`, `MEM_SIZE`, I/O addresses, stack base)
- Field extraction helpers (`INSTR_OPCODE`, `INSTR_RD`, `INSTR_RS1`, `INSTR_RS2`)
- Signed decode helpers for immediates/offsets (`INSTR_IMM5`, `INSTR_OFFSET`, `INSTR_IMM15`)

These definitions let every component interpret instruction words the same way.

## Instruction Formats

All instructions are 16-bit words. The core formats are:

- **R-format:** opcode + destination/source register fields (register-register operations)
- **I-format:** opcode + registers + small immediate (`imm5`)
- **J-format:** opcode + signed PC-relative jump offset

The assembler encodes these formats in `assembler/encoder.c`, and tests verify round-trip correctness in `tests_assembler/test_encoder.c`.

## Why This Matters

If assembler encoding and emulator decoding disagree by even one bit, programs break.  
A single shared ISA header prevents that mismatch and keeps the project modular:

- Kunal defines the contract
- Gio assembles to that contract
- Nikhil executes that contract
- Dhruv's assembly programs rely on the same contract

## Current Project Scope

At this stage, the repository is aligned to:

- Completed: ISA contract + assembler components + emulator runtime
- Not implemented yet: final assembly program deliverables

This keeps the work split consistent with team roles and avoids premature cross-component coupling.

## Quick Start

Use the assembler makefile at project root.

### Build Assembler

```bash
make -f Makefile_assembler all
```

This produces the assembler binary:

- `./assembler_bin`

### Run Encoder Tests

```bash
make -f Makefile_assembler test
```

Expected success line:

```text
all encoder round-trip tests passed
```

### Clean Build Artifacts

```bash
make -f Makefile_assembler clean
```

### Assemble a Program (Example)

After you create an assembly source file (for example `program.asm`), run:

```bash
./assembler_bin program.asm -o program.bin --listing
```

This generates `program.bin` and prints a listing with address, encoded word, and source line.

## Emulator

### Build Emulator

Use the root makefile:

```bash
make
```

This builds:

- `./emulator_bin`

### Emulator CLI Usage

```bash
./emulator_bin <file.bin>
./emulator_bin <file.bin> --dump
./emulator_bin <file.bin> --step
./emulator_bin <file.bin> --trace
./emulator_bin <file.bin> --dump --addr 0x0100
```

One-liner: run `make test` to build and execute the emulator ALU unit tests.

Supported flags:

- `--dump`: dump memory after execution
- `--step`: interactive single-step mode (press Enter between steps)
- `--trace`: print CPU state every step until halt
- `--addr X`: hex dump start address (accepts `0x0100` or `0100`), used with `--dump`

Default dump window:

- without `--addr`: `0x0000` to `0x0100`
- with `--addr X`: starts at `X` and dumps the next 256 bytes
