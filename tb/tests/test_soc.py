import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import os

CLKS_PER_BIT = 16

async def uart_rx_monitor(dut, captured_chars):
    """Monitors tx_out pin and deserializes UART characters."""
    half_bit_time = (CLKS_PER_BIT * 10) // 2  # ns (at 100MHz / 10ns clock)
    bit_time = CLKS_PER_BIT * 10

    while True:
        # Wait for start bit (0 on TX line)
        val_str = str(dut.tx_out.value)
        if val_str != '0':
            await RisingEdge(dut.clk)
            continue

        # Found start bit: center on it
        await Timer(half_bit_time, unit="ns")
        if str(dut.tx_out.value) != '0':
            continue

        # Sample 8 data bits (LSB first)
        char_val = 0
        for i in range(8):
            await Timer(bit_time, unit="ns")
            try:
                bit = int(dut.tx_out.value)
            except ValueError:
                bit = 0
            char_val |= (bit << i)

        # Wait for stop bit
        await Timer(bit_time, unit="ns")
        char = chr(char_val)
        captured_chars.append(char)
        print(char, end="", flush=True)


@cocotb.test()
async def test_baremetal_hello_world(dut):
    """Executes compiled bare-metal C binary on SoC and captures UART output."""
    clock = Clock(dut.clk, 10, unit="ns") # 100 MHz clock
    cocotb.start_soon(clock.start())

    hex_path = os.path.abspath("../sw/apps/hello_world/hello_world.hex")
    assert os.path.exists(hex_path), f"Cannot find {hex_path}. Run make in sw/apps/hello_world first."

    # Load compiled hex into BRAM
    with open(hex_path, "r") as f:
        hex_words = [int(line.strip(), 16) for line in f if line.strip()]

    cocotb.log.info(f"Loading {len(hex_words)} instruction words from {hex_path} into BRAM...")
    for addr, word in enumerate(hex_words):
        dut.u_ram.ram_block[addr].value = word

    # Initialize inputs and assert reset
    dut.rst.value = 1
    captured_chars = []
    cocotb.start_soon(uart_rx_monitor(dut, captured_chars))

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    cocotb.log.info("Reset deasserted: RV32I Titan SoC is booting compiled C binary...")

    # Run for 250,000 clock cycles to allow UART characters to stream out
    for cycle in range(250000):
        await RisingEdge(dut.clk)
        output_str = "".join(captured_chars)
        if "[PASS] Arithmetic checks confirmed." in output_str:
            # Let remaining banner text flush out
            for _ in range(2000):
                await RisingEdge(dut.clk)
            break

    full_output = "".join(captured_chars)
    cocotb.log.info(f"\nFinal captured terminal buffer:\n{full_output}")

    assert "RV32I TITAN CORE" in full_output, "Target banner not printed."
    assert "[PASS] Arithmetic checks confirmed." in full_output, "Bare-metal arithmetic self-test failed."
    cocotb.log.info("END-TO-END SOC DEMO PASSED: Bare-Metal C running on 5-Stage RISC-V RTL!")
