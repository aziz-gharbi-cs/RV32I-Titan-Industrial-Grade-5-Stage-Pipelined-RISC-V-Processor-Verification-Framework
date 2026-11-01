library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port (
        opcode       : in  std_logic_vector(6 downto 0);
        funct3       : in  std_logic_vector(2 downto 0);
        funct7_bit30 : in  std_logic;
        -- Control outputs
        reg_write    : out std_logic;
        mem_write    : out std_logic;
        mem_read     : out std_logic;
        alu_src      : out std_logic;
        branch       : out std_logic;
        jump         : out std_logic;
        is_auipc     : out std_logic;
        mem_to_reg   : out std_logic_vector(1 downto 0); -- "00"=ALU, "01"=MEM, "10"=PC+4
        alu_op       : out std_logic_vector(3 downto 0)
    );
end entity control_unit;

architecture rtl of control_unit is
begin
    process(opcode, funct3, funct7_bit30)
    begin
        -- Default inactive states
        reg_write  <= '0';
        mem_write  <= '0';
        mem_read   <= '0';
        alu_src    <= '0';
        branch     <= '0';
        jump       <= '0';
        is_auipc   <= '0';
        mem_to_reg <= "00";
        alu_op     <= "0000";

        case opcode is
            -- R-type
            when "0110011" =>
                reg_write  <= '1';
                alu_src    <= '0';
                mem_to_reg <= "00";
                case funct3 is
                    when "000" =>
                        if funct7_bit30 = '1' then
                            alu_op <= "0001"; -- SUB
                        else
                            alu_op <= "0000"; -- ADD
                        end if;
                    when "001" => alu_op <= "0010"; -- SLL
                    when "010" => alu_op <= "0011"; -- SLT
                    when "011" => alu_op <= "0100"; -- SLTU
                    when "100" => alu_op <= "0101"; -- XOR
                    when "101" =>
                        if funct7_bit30 = '1' then
                            alu_op <= "0111"; -- SRA
                        else
                            alu_op <= "0110"; -- SRL
                        end if;
                    when "110" => alu_op <= "1000"; -- OR
                    when "111" => alu_op <= "1001"; -- AND
                    when others => null;
                end case;

            -- I-type Arithmetic
            when "0010011" =>
                reg_write  <= '1';
                alu_src    <= '1';
                mem_to_reg <= "00";
                case funct3 is
                    when "000" => alu_op <= "0000"; -- ADDI
                    when "001" => alu_op <= "0010"; -- SLLI
                    when "010" => alu_op <= "0011"; -- SLTI
                    when "011" => alu_op <= "0100"; -- SLTIU
                    when "100" => alu_op <= "0101"; -- XORI
                    when "101" =>
                        if funct7_bit30 = '1' then
                            alu_op <= "0111"; -- SRAI
                        else
                            alu_op <= "0110"; -- SRLI
                        end if;
                    when "110" => alu_op <= "1000"; -- ORI
                    when "111" => alu_op <= "1001"; -- ANDI
                    when others => null;
                end case;

            -- U-type: LUI
            when "0110111" =>
                reg_write  <= '1';
                alu_src    <= '1';
                mem_to_reg <= "00";
                alu_op     <= "1010"; -- Pass operand B (imm_u)

            -- U-type: AUIPC (Add Upper Immediate to PC)
            when "0010111" =>
                reg_write  <= '1';
                alu_src    <= '1';
                is_auipc   <= '1';
                mem_to_reg <= "00";
                alu_op     <= "0000"; -- ADD (PC + imm_u)

            -- I-type Load: LW
            when "0000011" =>
                reg_write  <= '1';
                mem_read   <= '1';
                alu_src    <= '1';
                mem_to_reg <= "01";
                alu_op     <= "0000";

            -- S-type Store: SW
            when "0100011" =>
                mem_write  <= '1';
                alu_src    <= '1';
                alu_op     <= "0000";

            -- B-type Branch
            when "1100011" =>
                branch  <= '1';
                alu_src <= '0';
                case funct3 is
                    when "000" | "001" => alu_op <= "0001"; -- SUB
                    when "100" | "101" => alu_op <= "0011"; -- SLT
                    when "110" | "111" => alu_op <= "0100"; -- SLTU
                    when others => null;
                end case;

            -- J-type Jump: JAL
            when "1101111" =>
                reg_write  <= '1';
                jump       <= '1';
                mem_to_reg <= "10"; -- Save PC + 4 to rd

            -- I-type Jump: JALR
            when "1100111" =>
                reg_write  <= '1';
                jump       <= '1';
                alu_src    <= '1';
                mem_to_reg <= "10"; -- Save PC + 4 to rd
                alu_op     <= "0000";

            when others => null;
        end case;
    end process;
end architecture rtl;
