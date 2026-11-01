library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity forwarding_unit is
    port (
        id_ex_rs1       : in  std_logic_vector(4 downto 0);
        id_ex_rs2       : in  std_logic_vector(4 downto 0);
        ex_mem_rd       : in  std_logic_vector(4 downto 0);
        ex_mem_regwrite : in  std_logic;
        mem_wb_rd       : in  std_logic_vector(4 downto 0);
        mem_wb_regwrite : in  std_logic;
        
        forward_a       : out std_logic_vector(1 downto 0);
        forward_b       : out std_logic_vector(1 downto 0)
    );
end entity forwarding_unit;

architecture rtl of forwarding_unit is
begin
    -- Forwarding Logic for ALU Operand A (rs1)
    process(id_ex_rs1, ex_mem_rd, ex_mem_regwrite, mem_wb_rd, mem_wb_regwrite)
    begin
        -- Default: Use original register value from ID/EX
        forward_a <= "00";

        -- EX Hazard: Prioritize forwarding from EX/MEM stage
        if ex_mem_regwrite = '1' and ex_mem_rd /= "00000" and ex_mem_rd = id_ex_rs1 then
            forward_a <= "10";
        -- MEM Hazard: Forward from MEM/WB stage if not already forwarded from EX/MEM
        elsif mem_wb_regwrite = '1' and mem_wb_rd /= "00000" and mem_wb_rd = id_ex_rs1 then
            forward_a <= "01";
        end if;
    end process;

    -- Forwarding Logic for ALU Operand B (rs2)
    process(id_ex_rs2, ex_mem_rd, ex_mem_regwrite, mem_wb_rd, mem_wb_regwrite)
    begin
        -- Default: Use original register value from ID/EX
        forward_b <= "00";

        -- EX Hazard: Prioritize forwarding from EX/MEM stage
        if ex_mem_regwrite = '1' and ex_mem_rd /= "00000" and ex_mem_rd = id_ex_rs2 then
            forward_b <= "10";
        -- MEM Hazard: Forward from MEM/WB stage if not already forwarded from EX/MEM
        elsif mem_wb_regwrite = '1' and mem_wb_rd /= "00000" and mem_wb_rd = id_ex_rs2 then
            forward_b <= "01";
        end if;
    end process;

end architecture rtl;
