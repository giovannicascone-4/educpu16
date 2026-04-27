; =============================================================================
; fibonacci.asm
;
; PURPOSE
;   Computes the first 10 Fibonacci numbers and stores each one sequentially
;   in RAM starting at address 0x0300.
;
;   The sequence begins at F(0) = 0, F(1) = 1 and each subsequent term is
;   the sum of the two preceding terms:
;       F(n) = F(n-1) + F(n-2)
;
; VERIFY
;   After running, use:
;       ./emulator_bin fibonacci.bin --dump --addr 0300
;   Expected output (hex words):
;       0300: 0000 0001 0001 0002 0003 0005 0008 000D
;       0308: 0015 0022
;   In decimal: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
;
; ALGORITHM
;   Maintain two live registers, F_prev and F_curr.  On each iteration:
;     1. Store F_prev to the output address, then advance the pointer.
;     2. Compute F_next = F_prev + F_curr.
;     3. Slide the window: F_prev <- F_curr, F_curr <- F_next.
;     4. Decrement the loop counter; repeat while it is non-zero.
;
;   Because this ISA has no register-to-register MOV, the slide in step 3
;   is done with ADD Rd, Rs, R0 where R0 is held permanently at zero.
;   ADD Rd, Rs, R0  is semantically identical to  MOV Rd, Rs.
;
; REGISTER MAP
;   R0   permanent zero constant  (enables register-to-register moves)
;   R1   F_prev  - Fibonacci(n-1), the value stored this iteration
;   R2   F_curr  - Fibonacci(n),   the value stored next iteration
;   R3   F_next  - scratch: sum computed before the window slides
;   R4   output pointer - walks from 0x0300 to 0x0309
;   R5   loop counter  - counts down from 10 to 0
;   R6   scratch for shift counts during address setup
; =============================================================================


; --- Initialise registers -----------------------------------------------------

        MOV  R0, 0           ; R0 = 0  (permanent zero; never overwritten)
        MOV  R1, 0           ; R1 = F_prev = F(0) = 0
        MOV  R2, 1           ; R2 = F_curr = F(1) = 1
        MOV  R5, 10          ; R5 = 10  (number of terms to emit)


; --- Build output base address: R4 = 0x0300 -----------------------------------
;
; 0x0300 = 3 << 8.  SHL requires the shift amount in a register.

        MOV  R4, 3           ; R4 = 3
        MOV  R6, 8           ; R6 = 8  (shift amount)
        SHL  R4, R4, R6      ; R4 = 0x0300


; --- Main loop: emit 10 Fibonacci numbers ------------------------------------
;
; Each pass through the loop stores F_prev, advances the output pointer,
; computes the next term, slides the window, then decrements the counter.
; The loop continues while R5 != 0.

LOOP:
        SW   R1, R4, 0       ; mem[R4] = F_prev  (store current term)
        ADDI R4, R4, 1       ; advance output pointer to next word slot

        ADD  R3, R1, R2      ; R3 = F_next = F_prev + F_curr

        ; Slide the Fibonacci window forward one step.
        ; ADD Rd, Rs, R0 copies Rs into Rd because R0 is always 0.
        ADD  R1, R2, R0      ; R1 (F_prev) <- R2 (F_curr)
        ADD  R2, R3, R0      ; R2 (F_curr) <- R3 (F_next)

        ADDI R5, R5, -1      ; decrement loop counter
        CMP  R5, R0          ; set ZF if counter has reached zero
        JNE  LOOP            ; branch back while counter is non-zero

        HALT
