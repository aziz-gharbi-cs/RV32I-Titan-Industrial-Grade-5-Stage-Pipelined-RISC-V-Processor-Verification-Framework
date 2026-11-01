import cocotb
from cocotb.triggers import Timer
import random

def to_signed(val, bits=32):
    val = val & ((1 << bits) - 1)
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def alu_reference(alu_op: int, a: int, b: int):
    """Software reference model for 32-bit RV32I ALU operations."""
    a &= 0xFFFFFFFF
    b &= 0xFFFFFFFF
    shamt = b & 0x1F

    if alu_op == 0:    # ADD
        res = (a + b) & 0xFFFFFFFF
    elif alu_op == 1:  # SUB
        res = (a - b) & 0xFFFFFFFF
    elif alu_op == 2:  # SLL
        res = (a << shamt) & 0xFFFFFFFF
    elif alu_op == 3:  # SLT (Signed)
        res = 1 if to_signed(a) < to_signed(b) else 0
    elif alu_op == 4:  # SLTU (Unsigned)
        res = 1 if a < b else 0
    elif alu_op == 5:  # XOR
        res = a ^ b
    elif alu_op == 6:  # SRL
        res = (a >> shamt) & 0xFFFFFFFF
    elif alu_op == 7:  # SRA
        res = (to_signed(a) >> shamt) & 0xFFFFFFFF
    elif alu_op == 8:  # OR
        res = a | b
    elif alu_op == 9:  # AND
        res = a & b
    else:
        res = 0

    zero = 1 if res == 0 else 0
    return res, zero


@cocotb.test()
async def test_alu_randomized(dut):
    """Stress test ALU with corner cases and randomized inputs."""
    cocotb.log.info("Starting RV32I ALU Verification with Cocotb...")

    # Edge cases: 0x00000000, 0xFFFFFFFF, 0x80000000 (min signed), 0x7FFFFFFF (max signed)
    corner_values = [0x00000000, 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF, 0x00000001, 0x55555555, 0xAAAAAAAA]

    for op in range(10):
        # 1. Corner case sweeps
        for a in corner_values:
            for b in corner_values:
                dut.alu_op.value = op
                dut.a.value = a
                dut.b.value = b
                await Timer(1, units="ns")

                expected_res, expected_zero = alu_reference(op, a, b)
                actual_res = int(dut.result.value)
                actual_zero = int(dut.zero.value)

                assert actual_res == expected_res, (
                    f"Op {op} Corner FAIL: a=0x{a:08X}, b=0x{b:08X} | "
                    f"Expected=0x{expected_res:08X}, Got=0x{actual_res:08X}"
                )
                assert actual_zero == expected_zero, (
                    f"Op {op} Zero Flag FAIL: Expected {expected_zero}, Got {actual_zero}"
                )

        # 2. 500 Randomized iterations per operation
        for _ in range(500):
            a = random.randint(0, 0xFFFFFFFF)
            b = random.randint(0, 0xFFFFFFFF)

            dut.alu_op.value = op
            dut.a.value = a
            dut.b.value = b
            await Timer(1, units="ns")

            expected_res, expected_zero = alu_reference(op, a, b)
            actual_res = int(dut.result.value)
            actual_zero = int(dut.zero.value)

            assert actual_res == expected_res, (
                f"Op {op} Random FAIL: a=0x{a:08X}, b=0x{b:08X} | "
                f"Expected=0x{expected_res:08X}, Got=0x{actual_res:08X}"
            )
            assert actual_zero == expected_zero, (
                f"Op {op} Zero Flag FAIL: Expected {expected_zero}, Got {actual_zero}"
            )

    cocotb.log.info("ALU verification complete: 5,000+ random and corner checks passed.")
