import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from model.rv32i_iss import RV32I_ReferenceModel

# Assembly instruction encoders for automated program generation
def encode_addi(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0x0 << 12) | (rd << 7) | 0x13

def encode_add(rd, rs1, rs2):
    return (0x00 << 25) | (rs2 << 20) | (rs1 << 15) | (0x0 << 12) | (rd << 7) | 0x33

def encode_sub(rd, rs1, rs2):
    return (0x20 << 25) | (rs2 << 20) | (rs1 << 15) | (0x0 << 12) | (rd << 7) | 0x33

def encode_sll(rd, rs1, rs2):
    return (0x00 << 25) | (rs2 << 20) | (rs1 << 15) | (0x1 << 12) | (rd << 7) | 0x33

def encode_xor(rd, rs1, rs2):
    return (0x00 << 25) | (rs2 << 20) | (rs1 << 15) | (0x4 << 12) | (rd << 7) | 0x33

def encode_lui(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37

@cocotb.test()
async def test_datapath_co_simulation(dut):
    """Verifies datapath pipeline execution and hazard forwarding against Python ISS."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    ref_model = RV32I_ReferenceModel()

    # Preload instruction program memory
    program = [
        encode_addi(1, 0, 15),          # x1 = 15
        encode_addi(2, 0, 25),          # x2 = 25
        encode_add(3, 1, 2),            # x3 = x1 + x2 = 40 (EX-to-EX Forwarding test)
        encode_sub(4, 3, 1),            # x4 = x3 - x1 = 25 (Back-to-back dependency)
        encode_sll(5, 4, 1),            # x5 = 25 << 15 = 819200
        encode_xor(6, 5, 2),            # x6 = x5 ^ x2
        encode_lui(7, 0x12345),         # x7 = 0x12345000
        encode_add(8, 7, 3),            # x8 = x7 + x3
        0x00000013,                     # NOP (ADDI x0, x0, 0)
        0x00000013,                     # NOP
        0x00000013,                     # NOP
        0x00000013                      # NOP
    ]

    imem = {i * 4: inst for i, inst in enumerate(program)}

    # Step reference model through the program instructions that write to registers
    for inst in program:
        ref_model.step_instruction(inst)

    # Initialize inputs
    dut.rst.value = 1
    dut.imem_rdata.value = 0x00000013
    dut.dmem_rdata.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    retired_commits = 0
    expected_commits = 8  # 8 arithmetic instructions commit to register file

    for cycle in range(60):
        # Asynchronously feed instruction memory based on current PC
        try:
            pc_val = int(dut.imem_addr.value)
            dut.imem_rdata.value = imem.get(pc_val, 0x00000013)
        except ValueError:
            dut.imem_rdata.value = 0x00000013

        await RisingEdge(dut.clk)

        # Check commit on Write-Back stage
        if dut.wb_valid.value == 1 and int(dut.wb_rd.value) != 0:
            rd = int(dut.wb_rd.value)
            actual_data = int(dut.wb_data.value)
            expected_data = ref_model.get_reg(rd)

            cocotb.log.info(f"Cycle {cycle:02d} | Commit x{rd:02d} = 0x{actual_data:08X} (Expected: 0x{expected_data:08X})")

            assert actual_data == expected_data, (
                f"MISMATCH at cycle {cycle} for reg x{rd}: "
                f"DUT=0x{actual_data:08X}, REF=0x{expected_data:08X}"
            )
            retired_commits += 1

    assert retired_commits >= expected_commits, (
        f"Only {retired_commits}/{expected_commits} instructions committed to WB stage."
    )
    cocotb.log.info("Co-Simulation Verification Successful: Pipeline & Hazard Forwarding Match ISS.")
