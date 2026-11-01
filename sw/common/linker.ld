OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* 32 KB on-chip Block RAM starting at address 0 */
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS
{
    /* Boot code & instructions */
    .text : {
        . = ALIGN(4);
        *(.boot)
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
        _etext = .;
    } > RAM

    /* Initialized data */
    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    /* Zero-initialized data (.bss) */
    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack pointer starts at the very top of 32 KB RAM and grows down */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
