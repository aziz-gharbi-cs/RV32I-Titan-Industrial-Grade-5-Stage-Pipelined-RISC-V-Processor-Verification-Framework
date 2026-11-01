import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import sys

CLKS_PER_BIT = 16

async def uart_rx_monitor(dut, captured_chars):
    """Accurately deserializes 8N1 UART serial stream at 16 clocks/bit."""
    while True:
        # Wait for falling edge of Start Bit (transition from 1 to 0)
        await FallingEdge(dut.tx_out)

        # Wait 1.5 bit periods to reach center of bit 0
        for _ in range(int(CLKS_PER_BIT * 1.5)):
            await RisingEdge(dut.clk)

        # Sample 8 data bits (LSB first) at the midpoint of each bit time
        char_val = 0
        for i in range(8):
            try:
                bit = int(dut.tx_out.value)
            except ValueError:
                bit = 0
            char_val |= (bit << i)
            # Advance 1 full bit period to next bit center
            for _ in range(CLKS_PER_BIT):
                await RisingEdge(dut.clk)

        char = chr(char_val)
        captured_chars.append(char)
        sys.stdout.write(char)
        sys.stdout.flush()

        # Wait through stop bit to ensure line is back to idle HIGH
        for _ in range(CLKS_PER_BIT):
            await RisingEdge(dut.clk)


@cocotb.test()
async def test_baremetal_hello_world(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    captured_chars = []
    cocotb.start_soon(uart_rx_monitor(dut, captured_chars))

    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    cocotb.log.info("Reset deasserted: Executing bare-metal C binary on RV32I...")

    for _ in range(150000):
        await RisingEdge(dut.clk)
        output_str = "".join(captured_chars)
        if "[PASS] Arithmetic checks confirmed." in output_str:
            for _ in range(3000):
                await RisingEdge(dut.clk)
            break

    full_output = "".join(captured_chars)
    cocotb.log.info(f"\nFinal captured terminal buffer:\n{full_output}")

    assert "RV32I TITAN CORE" in full_output, "Target banner not printed."
    assert "[PASS] Arithmetic checks confirmed." in full_output, "Arithmetic test failed."
    cocotb.log.info("END-TO-END DEMO SUCCESS: Bare-Metal C executed cleanly on RISC-V SoC!")
