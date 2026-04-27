; test.asm - Simple Addition Test
MOV R1, 5      ; Load 5 into R1
MOV R2, 10     ; Load 10 into R2
ADD R3, R1, R2 ; R3 = R1 + R2 (Should be 15, or 0x000F)
HALT           ; Stop the CPU