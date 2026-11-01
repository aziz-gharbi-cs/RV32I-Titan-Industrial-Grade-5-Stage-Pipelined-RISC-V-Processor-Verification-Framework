#include "uart.h"

void uart_putc(char c) {
    /* Wait while UART TX is busy (bit 0 = 1) */
    while (UART_STATUS_REG & 0x01);
    UART_DATA_REG = (uint32_t)c;
}

void uart_print(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

void uart_print_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_print("0x");
    for (int i = 7; i >= 0; i--) {
        uint8_t nibble = (val >> (i * 4)) & 0x0F;
        uart_putc(hex_chars[nibble]);
    }
}
