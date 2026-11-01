#ifndef UART_H
#define UART_H

#include <stdint.h>

#define UART_BASE 0x10000000UL
#define UART_DATA_REG   (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_STATUS_REG (*(volatile uint32_t *)(UART_BASE + 0x04))

void uart_putc(char c);
void uart_print(const char *str);
void uart_print_hex(uint32_t val);

#endif
