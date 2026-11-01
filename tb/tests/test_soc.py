import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import sys

CLKS_PER_BIT = 16

async def uart_rx_monitor(dut, captured_chars):
    """Oversampling UART receiver monitor."""
    while True:
        # 1. Wait for line to be stable HIGH (idle)
        while True:
            await RisingEdge(dut.clk)
            try:
                if int(dut.tx_out.value) == 1:
                    break
            except ValueError:
                pass

        # 2. Wait for falling edge of Start Bit (transition to 0)
        while True:
            await RisingEdge(dut.clk)
            try:
                if int(dut.tx_out.value) == 0:
                    break
            except ValueError:
                pass

        # 3. Wait to middle of start bit (8 cycles) to verify valid start
        for _ in range(CLKS_PER_BIT // 2):
            await RisingEdge(dut.clk)
        if int(dut.tx_out.value) != 0:
            continue

        # 4. Sample 8 data bits at bit midpoints (every 16 cycles)
        char_val = 0
        for i in range(8):
            for _ in range(CLKS_PER_BIT):
                await RisingEdge(dut.clk)
            bit = int(dut.tx_out.value)
            char_val |= (bit << i)

        # 5. Wait for stop bit center (16 cycles)
        for _ in range(CLKS_PER_BIT):
            await RisingEdge(dut.clk)

        char = chr(char_val)
        captured_chars.append(char)
        sys.stdout.write(char)
        sys.stdout.flush()


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

    for _ in range(250000):
        await RisingEdge(dut.clk)
        output_str = "".join(captured_chars)
        if "Interactive UART terminal active." in output_str:
            for _ in range(2000):
                await RisingEdge(dut.clk)
            break

    full_output = "".join(captured_chars)
    cocotb.log.info(f"\nFinal captured terminal buffer:\n{full_output}")

    assert "RV32I TITAN CORE" in full_output, "Target banner not printed."
    assert "Arithmetic checks confirmed." in full_output, "Arithmetic test failed."
    cocotb.log.info("FLAGSHIP DEMO COMPLETE: Bare-Metal C Running on 5-Stage RV32I Core!")
