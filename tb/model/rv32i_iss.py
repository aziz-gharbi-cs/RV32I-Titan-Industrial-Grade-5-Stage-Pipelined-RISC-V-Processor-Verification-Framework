def to_signed(val, bits=32):
    val = val & ((1 << bits) - 1)
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

class RV32I_ReferenceModel:
    """Cycle-approximate architectural register model for RV32I."""
    def __init__(self):
        self.regs = [0] * 32
        self.pc = 0

    def get_reg(self, idx: int) -> int:
        if idx == 0:
            return 0
        return self.regs[idx] & 0xFFFFFFFF

    def set_reg(self, idx: int, val: int):
        if idx != 0:
            self.regs[idx] = val & 0xFFFFFFFF

    def step_instruction(self, inst: int):
        """Executes a single instruction against architectural state."""
        opcode = inst & 0x7F
        rd = (inst >> 7) & 0x1F
        funct3 = (inst >> 12) & 0x07
        rs1 = (inst >> 15) & 0x1F
        rs2 = (inst >> 20) & 0x1F
        funct7 = (inst >> 25) & 0x7F

        op1 = self.get_reg(rs1)
        op2 = self.get_reg(rs2)

        # I-type Immediate
        imm_i = to_signed((inst >> 20) & 0xFFF, 12)
        # U-type Immediate
        imm_u = inst & 0xFFFFF000

        # R-type instructions
        if opcode == 0x33:
            if funct3 == 0x0 and funct7 == 0x00:    # ADD
                self.set_reg(rd, op1 + op2)
            elif funct3 == 0x0 and funct7 == 0x20:  # SUB
                self.set_reg(rd, op1 - op2)
            elif funct3 == 0x1:                     # SLL
                self.set_reg(rd, op1 << (op2 & 0x1F))
            elif funct3 == 0x2:                     # SLT
                self.set_reg(rd, 1 if to_signed(op1) < to_signed(op2) else 0)
            elif funct3 == 0x3:                     # SLTU
                self.set_reg(rd, 1 if (op1 & 0xFFFFFFFF) < (op2 & 0xFFFFFFFF) else 0)
            elif funct3 == 0x4:                     # XOR
                self.set_reg(rd, op1 ^ op2)
            elif funct3 == 0x5 and funct7 == 0x00:  # SRL
                self.set_reg(rd, (op1 & 0xFFFFFFFF) >> (op2 & 0x1F))
            elif funct3 == 0x5 and funct7 == 0x20:  # SRA
                self.set_reg(rd, to_signed(op1) >> (op2 & 0x1F))
            elif funct3 == 0x6:                     # OR
                self.set_reg(rd, op1 | op2)
            elif funct3 == 0x7:                     # AND
                self.set_reg(rd, op1 & op2)

        # I-type Arithmetic
        elif opcode == 0x13:
            shamt = (inst >> 20) & 0x1F
            if funct3 == 0x0:                       # ADDI
                self.set_reg(rd, op1 + imm_i)
            elif funct3 == 0x2:                     # SLTI
                self.set_reg(rd, 1 if to_signed(op1) < imm_i else 0)
            elif funct3 == 0x3:                     # SLTIU
                self.set_reg(rd, 1 if (op1 & 0xFFFFFFFF) < (imm_i & 0xFFFFFFFF) else 0)
            elif funct3 == 0x4:                     # XORI
                self.set_reg(rd, op1 ^ imm_i)
            elif funct3 == 0x6:                     # ORI
                self.set_reg(rd, op1 | imm_i)
            elif funct3 == 0x7:                     # ANDI
                self.set_reg(rd, op1 & imm_i)
            elif funct3 == 0x1:                     # SLLI
                self.set_reg(rd, op1 << shamt)
            elif funct3 == 0x5 and funct7 == 0x00:  # SRLI
                self.set_reg(rd, (op1 & 0xFFFFFFFF) >> shamt)
            elif funct3 == 0x5 and funct7 == 0x20:  # SRAI
                self.set_reg(rd, to_signed(op1) >> shamt)

        # U-type
        elif opcode == 0x37:                        # LUI
            self.set_reg(rd, imm_u)
