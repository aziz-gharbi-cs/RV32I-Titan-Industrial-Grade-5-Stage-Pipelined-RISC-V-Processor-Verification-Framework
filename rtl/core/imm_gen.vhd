library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity imm_gen is
    port (
        instruction : in  std_logic_vector(31 downto 0);
        imm_i       : out std_logic_vector(31 downto 0);
        imm_s       : out std_logic_vector(31 downto 0);
        imm_b       : out std_logic_vector(31 downto 0);
        imm_u       : out std_logic_vector(31 downto 0);
        imm_j       : out std_logic_vector(31 downto 0)
    );
end entity imm_gen;

architecture rtl of imm_gen is
    signal sign : std_logic;
begin
    sign <= instruction(31);

    -- I-type: inst[31:20]
    imm_i(11 downto 0)  <= instruction(31 downto 20);
    imm_i(31 downto 12) <= (others => sign);

    -- S-type: inst[31:25] & inst[11:7]
    imm_s(4 downto 0)   <= instruction(11 downto 7);
    imm_s(11 downto 5)  <= instruction(31 downto 25);
    imm_s(31 downto 12) <= (others => sign);

    -- B-type: inst[31] & inst[7] & inst[30:25] & inst[11:8] & '0'
    imm_b(0)            <= '0';
    imm_b(4 downto 1)   <= instruction(11 downto 8);
    imm_b(10 downto 5)  <= instruction(30 downto 25);
    imm_b(11)           <= instruction(7);
    imm_b(31 downto 12) <= (others => sign);

    -- U-type: inst[31:12] & 12'b0
    imm_u(11 downto 0)  <= (others => '0');
    imm_u(31 downto 12) <= instruction(31 downto 12);

    -- J-type: inst[31] & inst[19:12] & inst[20] & inst[30:21] & '0'
    imm_j(0)            <= '0';
    imm_j(10 downto 1)  <= instruction(30 downto 21);
    imm_j(11)           <= instruction(20);
    imm_j(19 downto 12) <= instruction(19 downto 12);
    imm_j(31 downto 20) <= (others => sign);

end architecture rtl;
