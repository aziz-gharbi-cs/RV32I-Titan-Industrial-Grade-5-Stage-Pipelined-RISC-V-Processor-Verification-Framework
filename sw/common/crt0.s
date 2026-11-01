.section .boot, "ax"
.global _start

_start:
    /* 1. Initialize Stack Pointer to top of 32 KB RAM (0x00008000) */
    la sp, _stack_top

    /* 2. Zero-out the .bss section */
    la a0, _sbss
    la a1, _ebss
bss_clear_loop:
    bge a0, a1, bss_clear_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j bss_clear_loop

bss_clear_done:
    /* 3. Call C main() */
    call main

    /* 4. Infinite loop if main returns */
hang:
    j hang
