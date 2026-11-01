library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port (
        alu_op : in  std_logic_vector(3 downto 0);
        a      : in  std_logic_vector(31 downto 0);
        b      : in  std_logic_vector(31 downto 0);
        result : out std_logic_vector(31 downto 0);
        zero   : out std_logic
    );
end entity alu;

architecture rtl of alu is
    signal s_result : std_logic_vector(31 downto 0);
    signal shamt    : integer range 0 to 31;
begin
    shamt <= to_integer(unsigned(b(4 downto 0)));

    process(alu_op, a, b, shamt)
    begin
        case alu_op is
            when "0000" => -- ADD
                s_result <= std_logic_vector(unsigned(a) + unsigned(b));

            when "0001" => -- SUB
                s_result <= std_logic_vector(unsigned(a) - unsigned(b));

            when "0010" => -- SLL (Shift Left Logical)
                s_result <= std_logic_vector(shift_left(unsigned(a), shamt));

            when "0011" => -- SLT (Set Less Than - Signed)
                if signed(a) < signed(b) then
                    s_result <= x"00000001";
                else
                    s_result <= (others => '0');
                end if;

            when "0100" => -- SLTU (Set Less Than - Unsigned)
                if unsigned(a) < unsigned(b) then
                    s_result <= x"00000001";
                else
                    s_result <= (others => '0');
                end if;

            when "0101" => -- XOR
                s_result <= a xor b;

            when "0110" => -- SRL (Shift Right Logical)
                s_result <= std_logic_vector(shift_right(unsigned(a), shamt));

            when "0111" => -- SRA (Shift Right Arithmetic)
                s_result <= std_logic_vector(shift_right(signed(a), shamt));

            when "1000" => -- OR
                s_result <= a or b;

            when "1001" => -- AND
                s_result <= a and b;

            when "1010" => -- LUI (Pass operand B)
                s_result <= b;

            when others =>
                s_result <= (others => '0');
        end case;
    end process;

    result <= s_result;
    zero   <= '1' when unsigned(s_result) = 0 else '0';

end architecture rtl;
