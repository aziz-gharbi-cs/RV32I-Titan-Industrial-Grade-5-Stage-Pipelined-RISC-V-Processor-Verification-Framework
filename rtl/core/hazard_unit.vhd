library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hazard_unit is
    port (
        -- Decode stage register specifiers
        id_rs1          : in  std_logic_vector(4 downto 0);
        id_rs2          : in  std_logic_vector(4 downto 0);
        
        -- Execute stage state
        id_ex_rd        : in  std_logic_vector(4 downto 0);
        id_ex_mem_read  : in  std_logic;
        
        -- Branch / Jump decision from EX stage
        branch_taken    : in  std_logic;
        jump_taken      : in  std_logic;
        
        -- Pipeline stage control outputs
        pc_write        : out std_logic;
        if_id_write     : out std_logic;
        if_id_flush     : out std_logic;
        id_ex_flush     : out std_logic
    );
end entity hazard_unit;

architecture rtl of hazard_unit is
    signal load_use_hazard : std_logic;
begin

    -- Load-Use Hazard Condition:
    -- Instruction in EX is a LOAD (mem_read = '1') AND its target rd matches rs1 or rs2 of instruction in ID
    load_use_hazard <= '1' when (id_ex_mem_read = '1') and 
                                (id_ex_rd /= "00000") and 
                                ((id_ex_rd = id_rs1) or (id_ex_rd = id_rs2))
                       else '0';

    process(load_use_hazard, branch_taken, jump_taken)
    begin
        -- Default: Normal pipeline progression
        pc_write    <= '1';
        if_id_write <= '1';
        if_id_flush <= '0';
        id_ex_flush <= '0';

        -- Control Hazard (Branch Taken or Jump)
        -- Highest priority: flush the speculative instructions in flight
        if branch_taken = '1' or jump_taken = '1' then
            if_id_flush <= '1';
            id_ex_flush <= '1';

        -- Load-Use Hazard
        -- Stall PC and IF/ID, inject a bubble into ID/EX
        elsif load_use_hazard = '1' then
            pc_write    <= '0'; -- freeze PC counter
            if_id_write <= '0'; -- freeze IF/ID register
            id_ex_flush <= '1'; -- bubble into ID/EX
        end if;
    end process;

end architecture rtl;
