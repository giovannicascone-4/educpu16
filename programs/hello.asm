; =============================================================================
; hello.asm
;
; PURPOSE
;   Prints the greeting "Hello, World!\n" to the console by writing each
;   character individually to the memory-mapped STDOUT port (0xFF00).
;
;   The emulator's memory.c calls putchar(val & 0xFF) whenever any word is
;   stored to address 0xFF00 via SW, so each SW to that address outputs one
;   character.
;
; VERIFY
;   Run with:
;       ./emulator_bin hello.bin
;   Expected console output:
;       Hello, World!
;
; DESIGN
;   The string is stored as a table of 16-bit words in a data section placed
;   at address 0x0100, with one character per word (ASCII value in the low
;   byte, high byte zero).  A NUL sentinel word (0x0000) marks the end.
;
;   The code section at 0x0000 walks a pointer through the table, loads each
;   word, compares it to zero, and either writes it to IO_STDOUT or exits.
;
;   One word per character (rather than two characters packed per word) keeps
;   the loop body simple: one LW, one CMP, one conditional branch, one SW.
;   Packing would require an extra SHR and an additional pass per word pair.
;
; MEMORY LAYOUT
;   0x0000 - 0x0012   Code  (19 instructions)
;   0x0013 - 0x00FF   Unused (zero-filled by assembler)
;   0x0100 - 0x010E   String data (14 character words + NUL sentinel)
;
; REGISTER MAP
;   R0   permanent zero constant  (NUL comparison target; never overwritten)
;   R1   current character word loaded from the string table
;   R2   scratch: shift counts during IO and data address setup
;   R3   IO_STDOUT address (0xFF00), fixed for the entire loop
;   R4   data pointer, walks from 0x0100 toward the NUL sentinel
; =============================================================================

        .org 0x0000


; --- Initialise ---------------------------------------------------------------

        MOV  R0, 0           ; R0 = 0  (permanent zero / NUL comparison value)


; --- Build IO_STDOUT address: R3 = 0xFF00 -------------------------------------
;
; 0xFF cannot be loaded with a single MOV (imm5 max = 15), so we build it:
;   R3 = 15  ->  R3 << 4 = 0x00F0  ->  R3 + 15 = 0x00FF  ->  R3 << 8 = 0xFF00

        MOV  R3, 15          ; R3 = 0x000F
        MOV  R2, 4           ; R2 = 4  (first shift amount)
        SHL  R3, R3, R2      ; R3 = 0x00F0
        MOV  R2, 15          ; R2 = 0x000F
        ADD  R3, R3, R2      ; R3 = 0x00FF
        MOV  R2, 8           ; R2 = 8  (second shift amount)
        SHL  R3, R3, R2      ; R3 = 0xFF00  (IO_STDOUT)


; --- Build data pointer: R4 = 0x0100 ------------------------------------------
;
; 0x0100 = 1 << 8

        MOV  R4, 1           ; R4 = 1
        MOV  R2, 8           ; R2 = 8  (shift amount)
        SHL  R4, R4, R2      ; R4 = 0x0100  (start of string table)


; --- Print loop ---------------------------------------------------------------
;
; Each iteration loads one character word, exits on NUL, otherwise prints
; the character and advances the pointer.

NEXT:
        LW   R1, R4, 0       ; R1 = mem[R4]  (load next character word)
        CMP  R1, R0          ; compare character to zero (sets ZF if NUL)
        JEQ  DONE            ; if NUL sentinel reached, exit loop
        SW   R1, R3, 0       ; putchar(R1 & 0xFF) via mem-mapped IO_STDOUT
        ADDI R4, R4, 1       ; advance pointer to next character word
        JMP  NEXT            ; fetch next character

DONE:
        HALT


; =============================================================================
; String data table
;
; Each .word holds one ASCII code value.  The loop reads words sequentially
; and stops at the NUL sentinel (0x0000).
;
; Only the low byte of each word reaches putchar(); the high byte is always
; zero and is masked off by the emulator.
; =============================================================================

        .org 0x0100
        .word 72             ; 'H'
        .word 101            ; 'e'
        .word 108            ; 'l'
        .word 108            ; 'l'
        .word 111            ; 'o'
        .word 44             ; ','
        .word 32             ; ' '
        .word 87             ; 'W'
        .word 111            ; 'o'
        .word 114            ; 'r'
        .word 108            ; 'l'
        .word 100            ; 'd'
        .word 33             ; '!'
        .word 10             ; newline  '\n'
        .word 0              ; NUL sentinel — marks end of string
