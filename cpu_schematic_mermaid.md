# CPU Schematic

This schematic is based on the implementation in `assembler/isa.h`, `emulator/cpu.h`, `emulator/control.c`, `emulator/alu.c`, and `emulator/memory.c`.

```mermaid
flowchart LR
    PC["Program Counter (pc)"]
    MEM["Unified Memory\n64K words: 0x0000 - 0xFFFF"]
    IR["Instruction Register (ir)"]
    CTRL["Control Unit\nfetch / decode / execute"]
    REG["Register File\nR0 - R7\nR7 used as stack pointer"]
    SP["Stack Pointer\nsp mirrors R7\ninit = 0xFEFF"]
    ALU["ALU\nADD SUB AND OR XOR NOT SHL SHR CMP"]
    FLAGS["Flags Register\nZF NF CF OF"]
    MMIO["Memory-Mapped I/O\n0xFF00 STDOUT\n0xFF01 STDIN\n0xFF02 TIMER\n0xFF03 STATUS"]

    PC -->|"instruction address"| MEM
    MEM -->|"instruction word"| IR
    IR --> CTRL
    CTRL -->|"select op / branch / load / store"| REG
    CTRL -->|"ALU control"| ALU
    REG -->|"rs1 / rs2"| ALU
    ALU -->|"result"| REG
    ALU --> FLAGS
    FLAGS -->|"branch decisions"| CTRL
    REG -->|"base address + store data"| MEM
    MEM -->|"load data"| REG
    REG --- SP
    MEM --- MMIO
```

## Short Explanation

This CPU uses a simple fetch-decode-execute design. The program counter selects the next word in memory, that instruction is loaded into the instruction register, and the control unit decodes it. The register file provides operands to the ALU, the ALU computes results and updates the flags, and load or store instructions access the same unified memory space. Memory-mapped I/O is part of that memory space, so writing to `0xFF00` prints a character, reading from `0xFF01` gets input, reading from `0xFF02` returns the timer value, and `0xFF03` is defined as `IO_STATUS` in the ISA map. The stack pointer starts at `0xFEFF`, and in the implementation `R7` is used as the stack pointer register.
