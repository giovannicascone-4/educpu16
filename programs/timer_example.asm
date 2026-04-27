; =============================================================================
; timer_example.asm
;
; PURPOSE
;   Demonstrates a single Fetch / Compute / Store data-processing cycle using
;   real hardware I/O:
;
;     FETCH   - read the hardware timer counter from the memory-mapped I/O port
;               IO_TIMER (0xFF02) into a CPU register
;     COMPUTE - add the constant 42 to the timer value
;     STORE   - write the result back to RAM at address 0x0200
;
; VERIFY
;   After running, use:
;       ./emulator_bin timer_example.bin --dump --addr 0200
;   The first word at 0x0200 will contain (timer_value + 42).
;   Because the timer is live, the exact value varies each run, but the
;   low 6 bits of the result will always equal (timer_low_6 + 42) mod 64.
;
; ISA CONSTRAINTS VISIBLE IN THIS PROGRAM
;   - MOV accepts only a 5-bit signed immediate (-16 to 15), so 0xFF00
;     cannot be loaded in a single instruction.  It is built in four steps
;     using SHL (which requires the shift amount in a register, not as an
;     immediate) and ADD.
;   - 42 exceeds the 5-bit immediate limit, so it is added as 15 + 15 + 12
;     using three ADDI instructions.
;
; REGISTER MAP
;   R0   timer reading, then final result  (written once, never reused)
;   R1   IO base address (0xFF00)          (built during setup, fixed after)
;   R2   scratch: shift counts and ADDI step values
;   R3   result store address (0x0200)
; =============================================================================


; --- Build IO base address: R1 = 0xFF00 --------------------------------------
;
; 0xFF = 255 cannot be loaded with MOV (max 15), so we build it in pieces:
;   step 1: R1 = 15              (0x000F)
;   step 2: R1 = R1 << 4         (0x00F0)   shift count must be in R2
;   step 3: R1 = R1 + 15         (0x00FF)
;   step 4: R1 = R1 << 8         (0xFF00)   shift count must be in R2

        MOV  R1, 15          ; R1 = 0x000F
        MOV  R2, 4           ; R2 = 4  (first shift amount)
        SHL  R1, R1, R2      ; R1 = 0x00F0
        MOV  R2, 15          ; R2 = 0x000F
        ADD  R1, R1, R2      ; R1 = 0x00FF
        MOV  R2, 8           ; R2 = 8  (second shift amount)
        SHL  R1, R1, R2      ; R1 = 0xFF00  (IO_BASE / IO_STDOUT)


; --- FETCH: read timer tick from IO_TIMER (IO_BASE + 2 = 0xFF02) -------------
;
; LW Rd, Rs, imm  loads mem[Rs + imm].  Offset 2 from the IO base reaches
; IO_TIMER.  The emulator returns clock() & 0xFFFF for reads from 0xFF02.

        LW   R0, R1, 2       ; R0 = mem[0xFF02]  =  current timer tick


; --- COMPUTE: R0 = R0 + 42 ---------------------------------------------------
;
; 42 > 15 so we cannot use a single ADDI.  Split as 15 + 15 + 12 = 42.

        ADDI R0, R0, 15      ; R0 += 15  (running total: +15)
        ADDI R0, R0, 15      ; R0 += 15  (running total: +30)
        ADDI R0, R0, 12      ; R0 += 12  (running total: +42)


; --- Build result address: R3 = 0x0200 ----------------------------------------
;
; 0x0200 = 2 << 8

        MOV  R3, 2           ; R3 = 2
        MOV  R2, 8           ; R2 = 8  (shift amount)
        SHL  R3, R3, R2      ; R3 = 0x0200


; --- STORE: write result to RAM at 0x0200 -------------------------------------
;
; SW Rd, Rs, imm  writes Rd to mem[Rs + imm].

        SW   R0, R3, 0       ; mem[0x0200] = timer_value + 42

        HALT
