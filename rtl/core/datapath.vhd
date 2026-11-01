library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pipeline_pkg.all;

entity datapath is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- Instruction Memory Interface (IF stage)
        imem_addr   : out std_logic_vector(31 downto 0);
        imem_rdata  : in  std_logic_vector(31 downto 0);
        -- Data Memory Interface (MEM stage)
        dmem_addr   : out std_logic_vector(31 downto 0);
        dmem_wdata  : out std_logic_vector(31 downto 0);
        dmem_rdata  : in  std_logic_vector(31 downto 0);
        dmem_we     : out std_logic;
        dmem_re     : out std_logic;
        -- Commit monitor (for testbench verification & retirement)
        wb_valid    : out std_logic;
        wb_rd       : out std_logic_vector(4 downto 0);
        wb_data     : out std_logic_vector(31 downto 0)
    );
end entity datapath;

architecture rtl of datapath is
    -- Pipeline Registers
    signal r_if_id   : if_id_reg_t   := IF_ID_RESET;
    signal r_id_ex   : id_ex_reg_t   := ID_EX_RESET;
    signal r_ex_mem  : ex_mem_reg_t  := EX_MEM_RESET;
    signal r_mem_wb  : mem_wb_reg_t  := MEM_WB_RESET;

    -- IF Signals
    signal pc_current, pc_next, pc_plus4 : std_logic_vector(31 downto 0);
    signal pc_branch_target              : std_logic_vector(31 downto 0);

    -- ID Signals
    signal id_instruction                : std_logic_vector(31 downto 0);
    signal id_opcode                     : std_logic_vector(6 downto 0);
    signal id_funct3                     : std_logic_vector(2 downto 0);
    signal id_funct7_b30                 : std_logic;
    signal id_rs1, id_rs2, id_rd         : std_logic_vector(4 downto 0);
    signal id_rdata1, id_rdata2          : std_logic_vector(31 downto 0);
    signal id_imm_i, id_imm_s, id_imm_b  : std_logic_vector(31 downto 0);
    signal id_imm_u, id_imm_j, id_imm_sel: std_logic_vector(31 downto 0);
    
    -- Control Signals in ID
    signal ctrl_reg_write, ctrl_mem_to_reg : std_logic;
    signal ctrl_mem_write, ctrl_mem_read   : std_logic;
    signal ctrl_alu_src, ctrl_branch       : std_logic;
    signal ctrl_jump                       : std_logic;
    signal ctrl_alu_op                     : std_logic_vector(3 downto 0);

    -- EX Signals
    signal alu_in_a, alu_in_b              : std_logic_vector(31 downto 0);
    signal fwd_operand_a, fwd_operand_b    : std_logic_vector(31 downto 0);
    signal alu_out                         : std_logic_vector(31 downto 0);
    signal alu_zero                        : std_logic;
    signal ex_branch_taken                 : std_logic;
    signal forward_a, forward_b            : std_logic_vector(1 downto 0);

    -- Hazard Control Signals
    signal pc_write, if_id_write           : std_logic;
    signal if_id_flush, id_ex_flush        : std_logic;

    -- WB Signals
    signal wb_mux_data                     : std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- Stage 1: INSTRUCTION FETCH (IF)
    -- =========================================================================
    pc_plus4  <= std_logic_vector(unsigned(pc_current) + 4);
    imem_addr <= pc_current;

    -- Next PC Selection (Branch target evaluated in EX stage takes priority)
    pc_next <= pc_branch_target when (ex_branch_taken = '1' or r_id_ex.jump = '1') else pc_plus4;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pc_current <= (others => '0');
            elsif pc_write = '1' then
                pc_current <= pc_next;
            end if;
        end if;
    end process;

    -- IF/ID Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or if_id_flush = '1' then
                r_if_id <= IF_ID_RESET;
            elsif if_id_write = '1' then
                r_if_id.pc          <= pc_current;
                r_if_id.instruction <= imem_rdata;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Stage 2: INSTRUCTION DECODE (ID)
    -- =========================================================================
    id_instruction <= r_if_id.instruction;
    id_opcode      <= id_instruction(6 downto 0);
    id_funct3      <= id_instruction(14 downto 12);
    id_funct7_b30  <= id_instruction(30);
    id_rs1         <= id_instruction(19 downto 15);
    id_rs2         <= id_instruction(24 downto 20);
    id_rd          <= id_instruction(11 downto 7);

    u_regfile: entity work.regfile
        port map (
            clk    => clk,
            rst    => rst,
            raddr1 => id_rs1,
            rdata1 => id_rdata1,
            raddr2 => id_rs2,
            rdata2 => id_rdata2,
            wen    => r_mem_wb.reg_write,
            waddr  => r_mem_wb.rd,
            wdata  => wb_mux_data
        );

    u_imm_gen: entity work.imm_gen
        port map (
            instruction => id_instruction,
            imm_i       => id_imm_i,
            imm_s       => id_imm_s,
            imm_b       => id_imm_b,
            imm_u       => id_imm_u,
            imm_j       => id_imm_j
        );

    -- Immediate selector based on opcode
    id_imm_sel <= id_imm_s when id_opcode = "0100011" else
                  id_imm_b when id_opcode = "1100011" else
                  id_imm_u when id_opcode = "0110111" or id_opcode = "0010111" else
                  id_imm_j when id_opcode = "1101111" else
                  id_imm_i;

    u_control: entity work.control_unit
        port map (
            opcode       => id_opcode,
            funct3       => id_funct3,
            funct7_bit30 => id_funct7_b30,
            reg_write    => ctrl_reg_write,
            mem_write    => ctrl_mem_write,
            mem_read     => ctrl_mem_read,
            alu_src      => ctrl_alu_src,
            branch       => ctrl_branch,
            jump         => ctrl_jump,
            mem_to_reg   => ctrl_mem_to_reg,
            alu_op       => ctrl_alu_op
        );

    u_hazard: entity work.hazard_unit
        port map (
            id_rs1         => id_rs1,
            id_rs2         => id_rs2,
            id_ex_rd       => r_id_ex.rd,
            id_ex_mem_read => r_id_ex.mem_read,
            branch_taken   => ex_branch_taken,
            jump_taken     => r_id_ex.jump,
            pc_write       => pc_write,
            if_id_write    => if_id_write,
            if_id_flush    => if_id_flush,
            id_ex_flush    => id_ex_flush
        );

    -- ID/EX Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or id_ex_flush = '1' then
                r_id_ex <= ID_EX_RESET;
            else
                r_id_ex.pc         <= r_if_id.pc;
                r_id_ex.rdata1     <= id_rdata1;
                r_id_ex.rdata2     <= id_rdata2;
                r_id_ex.imm        <= id_imm_sel;
                r_id_ex.rs1        <= id_rs1;
                r_id_ex.rs2        <= id_rs2;
                r_id_ex.rd         <= id_rd;
                r_id_ex.funct3     <= id_funct3;
                r_id_ex.reg_write  <= ctrl_reg_write;
                r_id_ex.mem_to_reg <= ctrl_mem_to_reg;
                r_id_ex.mem_write  <= ctrl_mem_write;
                r_id_ex.mem_read   <= ctrl_mem_read;
                r_id_ex.alu_src    <= ctrl_alu_src;
                r_id_ex.branch     <= ctrl_branch;
                r_id_ex.jump       <= ctrl_jump;
                r_id_ex.alu_op     <= ctrl_alu_op;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Stage 3: EXECUTE (EX)
    -- =========================================================================
    u_forwarding: entity work.forwarding_unit
        port map (
            id_ex_rs1       => r_id_ex.rs1,
            id_ex_rs2       => r_id_ex.rs2,
            ex_mem_rd       => r_ex_mem.rd,
            ex_mem_regwrite => r_ex_mem.reg_write,
            mem_wb_rd       => r_mem_wb.rd,
            mem_wb_regwrite => r_mem_wb.reg_write,
            forward_a       => forward_a,
            forward_b       => forward_b
        );

    -- Forwarding Multiplexers
    fwd_operand_a <= r_ex_mem.alu_result when forward_a = "10" else
                     wb_mux_data         when forward_a = "01" else
                     r_id_ex.rdata1;

    fwd_operand_b <= r_ex_mem.alu_result when forward_b = "10" else
                     wb_mux_data         when forward_b = "01" else
                     r_id_ex.rdata2;

    alu_in_a <= fwd_operand_a;
    alu_in_b <= r_id_ex.imm when r_id_ex.alu_src = '1' else fwd_operand_b;

    u_alu: entity work.alu
        port map (
            alu_op => r_id_ex.alu_op,
            a      => alu_in_a,
            b      => alu_in_b,
            result => alu_out,
            zero   => alu_zero
        );

    -- Branch Target & Resolution
    pc_branch_target <= std_logic_vector(unsigned(r_id_ex.pc) + unsigned(r_id_ex.imm));

    process(r_id_ex.branch, r_id_ex.funct3, alu_zero, alu_out)
    begin
        ex_branch_taken <= '0';
        if r_id_ex.branch = '1' then
            case r_id_ex.funct3 is
                when "000" => -- BEQ
                    ex_branch_taken <= alu_zero;
                when "001" => -- BNE
                    ex_branch_taken <= not alu_zero;
                when "100" | "110" => -- BLT, BLTU
                    ex_branch_taken <= alu_out(0);
                when "101" | "111" => -- BGE, BGEU
                    ex_branch_taken <= not alu_out(0);
                when others =>
                    ex_branch_taken <= '0';
            end case;
        end if;
    end process;

    -- EX/MEM Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_ex_mem <= EX_MEM_RESET;
            else
                r_ex_mem.pc         <= r_id_ex.pc;
                r_ex_mem.alu_result <= alu_out;
                r_ex_mem.write_data <= fwd_operand_b;
                r_ex_mem.rd         <= r_id_ex.rd;
                r_ex_mem.funct3     <= r_id_ex.funct3;
                r_ex_mem.reg_write  <= r_id_ex.reg_write;
                r_ex_mem.mem_to_reg <= r_id_ex.mem_to_reg;
                r_ex_mem.mem_write  <= r_id_ex.mem_write;
                r_ex_mem.mem_read   <= r_id_ex.mem_read;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Stage 4: MEMORY ACCESS (MEM)
    -- =========================================================================
    dmem_addr  <= r_ex_mem.alu_result;
    dmem_wdata <= r_ex_mem.write_data;
    dmem_we    <= r_ex_mem.mem_write;
    dmem_re    <= r_ex_mem.mem_read;

    -- MEM/WB Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_mem_wb <= MEM_WB_RESET;
            else
                r_mem_wb.alu_result <= r_ex_mem.alu_result;
                r_mem_wb.read_data  <= dmem_rdata;
                r_mem_wb.rd         <= r_ex_mem.rd;
                r_mem_wb.reg_write  <= r_ex_mem.reg_write;
                r_mem_wb.mem_to_reg <= r_ex_mem.mem_to_reg;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Stage 5: WRITE-BACK (WB)
    -- =========================================================================
    wb_mux_data <= r_mem_wb.read_data when r_mem_wb.mem_to_reg = '1' else r_mem_wb.alu_result;

    -- Exposed monitoring signals for verification
    wb_valid <= r_mem_wb.reg_write;
    wb_rd    <= r_mem_wb.rd;
    wb_data  <= wb_mux_data;

end architecture rtl;
