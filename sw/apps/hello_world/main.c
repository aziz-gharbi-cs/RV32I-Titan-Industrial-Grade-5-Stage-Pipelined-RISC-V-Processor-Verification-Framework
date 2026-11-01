#include "uart.h"

int main(void) {
    uart_print("\n========================================\n");
    uart_print("  RV32I TITAN CORE - 5-STAGE PIPELINE\n");
    uart_print("  Designed at ENSI | Targeting Siemens R&D\n");
    uart_print("========================================\n\n");

    uart_print("[BOOT] Core clocked and stable.\n");
    uart_print("[TEST] Running integer arithmetic sanity check...\n");

    volatile uint32_t a = 42;
    volatile uint32_t b = 58;
    volatile uint32_t sum = a + b;

    uart_print("       Computed sum (42 + 58) = ");
    uart_print_hex(sum);
    uart_print("\n");

    if (sum == 100) {
        uart_print("[PASS] Arithmetic checks confirmed.\n");
    } else {
        uart_print("[FAIL] Computation error detected!\n");
    }

    uart_print("\n[READY] Interactive UART terminal active.\n");

    while (1) {
        /* Heartbeat */
    }

    return 0;
}
