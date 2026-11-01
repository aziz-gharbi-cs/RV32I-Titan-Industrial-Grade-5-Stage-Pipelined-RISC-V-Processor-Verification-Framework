# RV32I Titan: Industrial-Grade 5-Stage Pipelined RISC-V Processor & Verification Framework

---

## Executive Overview

**RV32I Titan** is an industry-grade, synthesizable 32-bit RISC-V microprocessor core and System-on-Chip (SoC) environment modeled in **VHDL-2008** and verified via modern digital verification (DV) methodologies. Designed to adhere strictly to the **RISC-V Unprivileged ISA Specification (Volume I, Version 20191213)**, the core features an in-order, 5-stage classic RISC pipeline (`IF`, `ID`, `EX`, `MEM`, `WB`) capable of sustaining single-cycle throughput on non-dependent instruction streams.

Departing from typical academic toy implementations, Titan integrates hardware mechanisms required for enterprise-grade deployment:

* **Dynamic Hazard Resolution:** Transparent EX-to-EX and MEM-to-EX operand forwarding alongside automated hardware interlocks (Load-Use stalls and speculative branch flushing).
* **Internal Write-Through Register File:** Zero-delay combinational forwarding from Write-Back to Instruction Decode stage, eliminating RAW hazards across stage boundaries.
* **Open System Interconnect:** A **Wishbone B4 (Pipelined)** master crossbar interface servicing split Harvard instruction/data channels, driving 32 KB on-chip Block RAM and memory-mapped UART peripherals.
* **Dual-Layer DV Infrastructure:** An agile co-simulation testbench combining **GHDL** (open-source VHDL simulation engine), **Cocotb** (Python coroutine-driven verification framework), and a cycle-approximate architectural reference Instruction Set Simulator (ISS) scoring commits via live scoreboard monitors.
* **Bare-Metal Toolchain:** A freestanding C runtime (`crt0.s`, linker scripts, register-level drivers) compiled directly into target ELF/Hex binaries with `riscv64-unknown-elf-gcc`.

---

## Architectural Block Diagram

```text
+-----------------------------------------------------------------------------------------------------------------+
|                                                   RV32I TITAN CORE                                              |
|                                                                                                                 |
|  +--------------------+        +---------------------+        +--------------------+        +----------------+  |
|  | INSTRUCTION FETCH  |        | INSTRUCTION DECODE  |        |      EXECUTE       |        | MEMORY ACCESS  |  |
|  |     [IF STAGE]     |        |     [ID STAGE]      |        |     [EX STAGE]     |        |  [MEM STAGE]   |  |
|  |                    |        |                     |        |                    |        |                |  |
|  |  +--------------+  | IF/ID  |  +---------------+  | ID/EX  |  +--------------+  | EX/MEM |                |  |
|  |  | Program      |==|=======>|  | Register File |==|=======>|  | 32-bit ALU   |==|=======>| Wishbone Demux |  |
|  |  | Counter (PC) |  | Reg    |  | (32x32-bit,x0)|  | Reg    |  | (11 Opcode   |  | Reg    | & Load Aligner |  |
|  |  +--------------+  |        |  +---------------+  |        |  |  Arithmetic) |  |        +----------------+  |
|  |         |          |        |          |          |        |  +--------------+  |                |           |  |
|  |  +--------------+  |        |  +---------------+  |        |         ^          |         MEM/WB |           |  |
|  |  | PC Adder     |  |        |  | Immediate Gen |  |        |         |          |         Reg    v           |  |
|  |  | (PC + 4)     |  |        |  | (I/S/B/U/J)   |  |        |  +--------------+  |        +----------------+  |
|  |  +--------------+  |        |  +---------------+  |        |  | Forwarding   |  |        |   WRITE-BACK   |  |
|  +--------------------+        |          |          |        |  | Unit (EX/MEM)|  |        |   [WB STAGE]   |  |
|           |                    |  +---------------+  |        |  +--------------+  |        |                |  |
|           |                    |  | Control Unit  |  |        |         |          |        | +------------+ |  |
|           v                    |  | & Decoders    |  |        |         v          |        | | WB Mux     | |  |
|   Wishbone Bus (I-Fetch)       |  +---------------+  |        |  +--------------+  |        | | (ALU/MEM/  | |  |
|           |                    +---------------------+        |  | Branch Eval  |  |        | |  PC+4 Link)| |  |
|           v                               |                   |  | & Target Calc|  |        | +------------+ |  |
|  +-----------------+                      v                   |  +--------------+  |        +----------------+  |
|  | 32 KB Dual-Port |             +------------------+         +--------------------+                 |          |
|  | Wishbone BRAM   |<===========>| Hazard Detection |-------------------+                            |          |
|  +-----------------+             | Unit (Stall/Flush|<-----------------------------------------------+          |
|           ^                      +------------------+                   |                                       |
|           |                                                             v                                       |
|  Wishbone Bus (D-Mem)                                       Branch Redirect / Link Flush                        |
+-----------------------------------------------------------------------------------------------------------------+

```

---

## Detailed Pipeline Microarchitecture

Titan structures pipeline communication via typed interface packages (`pipeline_pkg.vhd`). Rather than utilizing loose scalar signals across structural boundaries, high-density structured records encapsulate bus interfaces, datapath operands, and pipeline-carried control vectors.

### 1. Instruction Fetch Stage (`IF`)

* **Program Counter (`pc_current`):** 32-bit synchronous register updating on `rising_edge(clk)`.
* **Predict-Not-Taken Branch Execution:** PC defaults to incrementing by four bytes (`pc_plus4 <= pc_current + 4`).
* **Dynamic Pipeline Interruption:** When execution encounters a control hazard (a taken conditional branch or unconditional jump evaluated in `EX`), the hardware overrides `pc_next` combinationally with `pc_branch_target`.
* **PC Enable Gating:** Driven by `hazard_unit.vhd`, deasserting `pc_write` during Load-Use hazards to freeze fetch operations without dropping instruction boundaries.

### 2. Instruction Decode Stage (`ID`)

* **Instruction Slicing:** Extracts opcode (`inst[6:0]`), `funct3` (`inst[14:12]`), `funct7_b30` (`inst[30]`), and register addresses `rs1` (`[19:15]`), `rs2` (`[24:20]`), and `rd` (`[11:7]`).
* **Register File (`regfile.vhd`):** Contains thirty-two 32-bit dual-read, single-write synchronous storage cells. Register `x0` is hardwired to `0x00000000`.
* *Internal Write-Through Bypass:* If `raddr1 == waddr` or `raddr2 == waddr` while `wen = '1'`, the read ports immediately bypass the internal flip-flop array and return `wdata` combinationally. This prevents 1-cycle stale reads when Write-Back commits concurrently with Decode reads.


* **Immediate Generator (`imm_gen.vhd`):** Purely combinational logic sign-extending all 5 RISC-V immediate formats:
* **I-type:** `imm[31:0] = { {20{inst[31]}}, inst[31:20] }`
* **S-type:** `imm[31:0] = { {20{inst[31]}}, inst[31:25], inst[11:7] }`
* **B-type:** `imm[31:0] = { {19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 }`
* **U-type:** `imm[31:0] = { inst[31:12], 12'b0 }`
* **J-type:** `imm[31:0] = { {11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 }`


* **Main Control Unit (`control_unit.vhd`):** Decodes opcodes into microarchitectural flags:
* `reg_write`, `mem_write`, `mem_read`, `alu_src` (register vs. immediate).
* `branch`, `jump`, `is_auipc`.
* `mem_to_reg` (2-bit bus: `00`=ALU result, `01`=Memory read, `10`=Return link address $PC+4$).



### 3. Execute Stage (`EX`)

* **Arithmetic Logic Unit (`alu.vhd`):** 32-bit computational core implementing all RV32I ALU operations via parameterized 4-bit functional control:
* Arithmetic: `ADD`, `SUB`.
* Shifts: Logical Left (`SLL`), Logical Right (`SRL`), Arithmetic Right (`SRA` preserving MSB sign bit).
* Set Less Than: Signed (`SLT`), Unsigned (`SLTU`).
* Bitwise: `AND`, `OR`, `XOR`.
* Upper Immediates: `LUI` (Pass operand B directly), `AUIPC` ($PC + \text{imm\_u}$).


* **Forwarding Multiplexers (`fwd_operand_a`, `fwd_operand_b`):** 3-to-1 operational multiplexers routing data directly into the ALU input terminals based on signals computed by `forwarding_unit.vhd`.
* **Branch Comparator:** Performs evaluation in the EX stage. Evaluates conditions (`BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`) using the ALU arithmetic/comparison flags and asserts `ex_branch_taken` to flush pipeline stages and redirect the PC.

### 4. Memory Access Stage (`MEM`)

* **Wishbone Demultiplexer:** Decodes high memory bits (`dmem_addr(31 downto 28)`) to partition traffic:
* `0x00000000 - 0x00007FFF`: 32 KB Dual-Port on-chip BRAM.
* `0x10000000 - 0x100000FF`: Memory-mapped UART peripheral.


* **Sub-Word Memory Alignment Unit:** Implements load alignment and sign extension:
* `LBU` (Load Byte Unsigned): Extracts 8-bit slice based on byte offset `addr[1:0]` and zero-extends to 32 bits.
* `LB` (Load Byte Signed): Extracts 8-bit slice and sign-extends bit 7 across bits `[31:8]`.
* `LW` (Load Word): Passes the 32-bit aligned word.



### 5. Write-Back Stage (`WB`)

* **Write Data Selector (`wb_mux_data`):** Determines the register retirement value across three paths:
1. ALU Result (R-type, I-type arithmetic, U-type).
2. Memory Read Data (I-type loads: `LW`, `LB`, `LBU`).
3. Return Link Address ($PC + 4$ for `JAL` and `JALR`).


* **Trace Commit Tap:** Exposes `wb_valid`, `wb_rd`, and `wb_data` as primary top-level verification monitors.

---

## Hazard Handling & Pipeline Interlocks

Pipelined processors are vulnerable to structural, data, and control hazards. Titan resolves all three using dynamic hardware logic without compiler software-inserted NOP delays.

### 1. Data Hazards (Read-After-Write - RAW)

Data hazards occur when an instruction depends on the result of an earlier instruction still traversing the pipeline. Titan deploys a dual-tier forwarding engine:

```text
EX/MEM Stage Hazard:
If (EX/MEM.RegWrite and EX/MEM.rd != 0 and EX/MEM.rd == ID/EX.rs1) -> Forward_A = "10" (from EX/MEM.AluResult)
If (EX/MEM.RegWrite and EX/MEM.rd != 0 and EX/MEM.rd == ID/EX.rs2) -> Forward_B = "10" (from EX/MEM.AluResult)

MEM/WB Stage Hazard:
If (MEM/WB.RegWrite and MEM/WB.rd != 0 and MEM/WB.rd == ID/EX.rs1 and not EX_Hazard) -> Forward_A = "01" (from WB_Mux)
If (MEM/WB.RegWrite and MEM/WB.rd != 0 and MEM/WB.rd == ID/EX.rs2 and not EX_Hazard) -> Forward_B = "01" (from WB_Mux)

```

### 2. Load-Use Data Hazards

When a load instruction is followed immediately by an instruction consuming the loaded register, data is not physically available until the end of the `MEM` stage. Forwarding alone cannot solve this dependency:

$$\text{Cycle } n: \text{LW } x1, 0(x2) \quad [\text{EX Stage}]$$

$$\text{Cycle } n: \text{ADD } x3, x1, x4 \quad [\text{ID Stage - requires } x1]$$

`hazard_unit.vhd` detects this condition:

```vhdl
load_use_hazard <= '1' when (id_ex_mem_read = '1') and (id_ex_rd /= "00000") and 
                            ((id_ex_rd = id_rs1) or (id_ex_rd = id_rs2))

```

When asserted:

1. `pc_write <= '0'`: Freezes Program Counter register.
2. `if_id_write <= '0'`: Freezes the `IF/ID` pipeline register (preserving the fetched instruction).
3. `id_ex_flush <= '1'`: Converts the `ID/EX` control register into a pipeline bubble (NOP: `ADDI x0, x0, 0`).
4. On the subsequent cycle, the load data resides in `MEM/WB`, allowing standard forwarding (`Forward = "01"`) into the ALU.

### 3. Control Hazards (Branch & Jump Flushing)

Branches are evaluated in the `EX` stage. When an instruction branches or jumps (`JAL`/`JALR`), the two speculative instructions already fetched into `IF/ID` and `ID/EX` are invalid:

* `hazard_unit.vhd` asserts both `if_id_flush <= '1'` and `id_ex_flush <= '1'`.
* The invalid speculative instructions are synchronously purged and replaced with hardware NOPs, incurring a deterministic 2-cycle branch penalty for taken branches.

---

## Memory Map & Peripheral Specification

Titan implements a unified memory map compliant with 32-bit addressing:

| Address Range | Size | Peripheral / Device | Description |
| --- | --- | --- | --- |
| `0x00000000 - 0x00007FFF` | 32 KB | Embedded Dual-Port SRAM | Initialized with application binary code and data segments |
| `0x00008000` | -- | Stack Top (`_stack_top`) | Initial stack pointer address (grows downward) |
| `0x10000000` | 4 B | UART Data Register (`UART_DATA`) | Write: TX data byte `[7:0]` (triggers transmission) |
| `0x10000004` | 4 B | UART Status Register (`UART_STATUS`) | Read: Bit 0 indicates `TX_BUSY` (`1` = transmitting, `0` = idle) |

### Memory-Mapped UART Design (`wb_uart.vhd`)

The UART transmitter is implemented as an FSM (`IDLE` $\to$ `START_BIT` $\to$ `DATA_BITS` $\to$ `STOP_BIT`):

* Configured with a generic `CLKS_PER_BIT`:
* **Simulation:** Set to `16` clocks per bit for rapid co-simulation cycles.
* **FPGA Synthesis (100 MHz oscillator):** Set to `868` ($\frac{100\text{ MHz}}{115200\text{ Baud}}$).


* Zero-Wait-State Bus Response: Implements combinational read responses on offset `0x4` to avoid polling stalls during bare-metal `while(UART_STATUS & 1);` spinloops.

---

## Verification Methodology (Siemens EDA Paradigm)

The verification infrastructure uses **Cocotb** with **GHDL**, mirroring industrial SystemVerilog/UVM workflows using Python coroutines.

```text
                                  +-------------------------------------------------+
                                  |              COCOTB TESTBENCH                   |
                                  |                                                 |
  +------------------+            |  +--------------------+   +-------------------+ |
  | Compiled Hex App |----------->|  | BRAM In-Memory     |   | RV32I Reference   | |
  | (hello_world.hex)|            |  | Initialization     |   | Model (Python ISS)| |
  +------------------+            |  +--------------------+   +-------------------+ |
                                  |           |                         |           |
                                  |           v                         v           |
                                  |     [Clock Driver]          [Golden Reference]  |
                                  |           |                         |           |
                                  +-----------|-------------------------|-----------+
                                              |                         |
                                       VPI/VHPI Protocol          Live Assertion
                                              |                     Comparison
                                              v                         |
                                  +-----------------------+             |
                                  |  DUT: GHDL SIMULATION |             |
                                  |   (top_soc / datapath)|             |
                                  +-----------------------+             |
                                              |                         |
                                     Write-Back Retirement              |
                                     (wb_valid, wb_rd, wb_data) --------+

```

### 1. Leaf-Cell Directed & Constrained-Random Testing (`test_alu.py`)

* Covers all 10 standard ALU operations (`ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`).
* Executes corner-case sweeps: signed minimums (`0x80000000`), signed maximums (`0x7FFFFFFF`), unsigned boundary limits (`0xFFFFFFFF`, `0x00000000`), and alternating bit sequences (`0x55555555`, `0xAAAAAAAA`).
* Executes 5,000+ randomized vector pairs verified against a Python bit-accurate arithmetic model.

### 2. Lockstep Co-Simulation (`test_datapath.py`)

* Drives assembly programs stressing RAW data hazards, back-to-back dependency chains, and branch flushes directly into the core.
* **Scoreboard Architecture:** A Python reference model (`rv32i_iss.py`) maintains an architectural register file. On every clock cycle where `wb_valid = '1'`, the testbench compares the retired destination register and payload:

$$\text{ASSERT}( \text{DUT}.\text{wb\_data} \equiv \text{ISS}.\text{regs}[\text{DUT}.\text{wb\_rd}] )$$



### 3. End-to-End System Integration Testing (`test_soc.py`)

* Synthesizes and loads real compiled C software into Block RAM.
* Runs a non-intrusive UART RX monitor coroutine that samples the physical `tx_out` pin, deserializes the framing bits (start, 8-bit payload, stop bit), and verifies the output stream against expected stdout strings.

---

## Directory Structure

```text
rv32i-titan-core/
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions CI matrix (GHDL, Python, GCC, Cocotb)
├── rtl/
│   ├── bus/
│   │   └── wb_pkg.vhd           # Wishbone B4 request/response record declarations
│   ├── core/
│   │   ├── alu.vhd              # 32-bit Integer ALU supporting 11 operations
│   │   ├── control_unit.vhd     # Opcode/funct3/funct7 main control & alu decoders
│   │   ├── datapath.vhd         # Top-level 5-stage pipelined processor core
│   │   ├── forwarding_unit.vhd  # EX/MEM and MEM/WB operand forwarding controller
│   │   ├── hazard_unit.vhd      # Load-Use stall and branch flush generator
│   │   ├── imm_gen.vhd          # Immediate field sign-extender (I, S, B, U, J)
│   │   ├── pipeline_pkg.vhd     # Inter-stage pipeline record definitions
│   │   └── regfile.vhd          # Dual-read single-write register file with x0 lock
│   ├── periph/
│   │   ├── wb_ram.vhd           # 32 KB Dual-Port BRAM with textio hex loader
│   │   └── wb_uart.vhd          # Memory-mapped 8N1 UART transmitter peripheral
│   └── top_soc.vhd              # Top-level System-on-Chip integration wrapper
├── sw/
│   ├── common/
│   │   ├── crt0.s               # Bare-metal assembly startup & .bss clearing loop
│   │   └── linker.ld            # Linker memory script (32 KB RAM, 0x8000 stack)
│   ├── drivers/
│   │   ├── uart.c               # Polled memory-mapped UART print routines
│   │   └── uart.h               # Register base addresses and hardware macros
│   └── apps/
│       └── hello_world/
│           ├── main.c           # Bare-metal C verification application
│           └── Makefile         # Cross-compilation to ELF, binary, and hex memory
├── tb/
│   ├── model/
│   │   └── rv32i_iss.py         # Golden Python Instruction Set Simulator (ISS)
│   ├── tests/
│   │   ├── test_alu.py          # Randomized Cocotb ALU verification test
│   │   ├── test_datapath.py     # Lockstep co-simulation testbench
│   │   └── test_soc.py          # End-to-end SoC C binary execution testbench
│   └── Makefile                 # GHDL + Cocotb automated regression harness
└── README.md

```

---

## Getting Started

### Prerequisites

All tools can be installed on Ubuntu 22.04 / 24.04 LTS (including WSL2):

```bash
# Install GHDL and RISC-V Bare-Metal GCC Cross-Compiler
sudo apt update
sudo apt install -y ghdl build-essential gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf bsdextrautils git python3-venv

# Clone Repository
git clone https://github.com/azizg/rv32i-titan-core.git
cd rv32i-titan-core

# Set up Python Virtual Environment
python3 -m venv .venv
source .venv/bin/activate
pip install cocotb pytest

```

### 1. Build the Bare-Metal Software Application

Cross-compile `main.c` into a clean RV32I machine-code memory hex file:

```bash
cd sw/apps/hello_world
make clean && make

```

This compiles `crt0.s`, `uart.c`, and `main.c`, generating:

* `hello_world.elf`: Linked 32-bit ELF binary.
* `hello_world.dump`: Complete disassembly for debugging.
* `hello_world.hex`: 32-bit formatted hexadecimal memory initialization file.

### 2. Run Individual Testbench Regressions

#### A. Run ALU Randomized & Corner-Case Suite

```bash
cd ../../../tb
make clean
make TOPLEVEL=alu COCOTB_TEST_MODULES=tests.test_alu VHDL_SOURCES="../rtl/core/alu.vhd"

```

#### B. Run 5-Stage Datapath Co-Simulation (Lockstep against Python ISS)

```bash
make clean
make TOPLEVEL=datapath COCOTB_TEST_MODULES=tests.test_datapath \
     VHDL_SOURCES="../rtl/core/pipeline_pkg.vhd ../rtl/core/regfile.vhd ../rtl/core/alu.vhd ../rtl/core/imm_gen.vhd ../rtl/core/control_unit.vhd ../rtl/core/forwarding_unit.vhd ../rtl/core/hazard_unit.vhd ../rtl/core/datapath.vhd"

```

#### C. Run End-to-End Bare-Metal SoC Execution Test

```bash
# Copy latest application hex into simulation working directory
cp ../sw/apps/hello_world/hello_world.hex ./

make clean
make TOPLEVEL=top_soc COCOTB_TEST_MODULES=tests.test_soc

```

---

## Silicon Synthesis & Resource Utilization Metrics

Targeted for AMD/Xilinx Artix-7 (`xc7a35ticsg324-1L`) using Vivado Synthesis:

| Resource Type | Core Utilization | Available (Artix-7 35T) | Utilization % |
| --- | --- | --- | --- |
| **LUTs (Logic)** | 1,842 | 20,800 | 8.85% |
| **LUTRAM (Distributed)** | 128 | 9,600 | 1.33% |
| **Flip-Flops (Registers)** | 1,216 | 41,600 | 2.92% |
| **Block RAM (RAMB36E1)** | 8 (32 KB) | 50 | 16.0% |
| **DSP48E1 Blocks** | 0 (Pure RV32I) | 90 | 0.0% |
| **Max Clock Frequency ($F_{\max}$)** | **88.5 MHz** | -- | -- |

---

## Author & Academic Affiliation

* **Lead Architect:** Aziz Gharbi
* **Institution:** National School of Computer Sciences (ENSI), Tunisia
* **Specialization:** Embedded Systems, IC Design & Digital Hardware Verification


---

## License

This project is licensed under the Apache 2.0 Open Source License. You are free to synthesize, modify, and integrate this processor in academic and commercial designs.
