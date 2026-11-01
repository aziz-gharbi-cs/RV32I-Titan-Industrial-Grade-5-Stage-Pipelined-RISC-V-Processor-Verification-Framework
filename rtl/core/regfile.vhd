library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        -- Read Port 1
        raddr1   : in  std_logic_vector(4 downto 0);
        rdata1   : out std_logic_vector(31 downto 0);
        -- Read Port 2
        raddr2   : in  std_logic_vector(4 downto 0);
        rdata2   : out std_logic_vector(31 downto 0);
        -- Write Port
        wen      : in  std_logic;
        waddr    : in  std_logic_vector(4 downto 0);
        wdata    : in  std_logic_vector(31 downto 0)
    );
end entity regfile;

architecture rtl of regfile is
    type reg_array_t is array (0 to 31) of std_logic_vector(31 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));
begin

    -- Synchronous Write with x0 Protection
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                regs <= (others => (others => '0'));
            elsif wen = '1' and to_integer(unsigned(waddr)) /= 0 then
                regs(to_integer(unsigned(waddr))) <= wdata;
            end if;
        end if;
    end process;

    -- Asynchronous Read (Zero register bypass)
    rdata1 <= (others => '0') when to_integer(unsigned(raddr1)) = 0 else regs(to_integer(unsigned(raddr1)));
    rdata2 <= (others => '0') when to_integer(unsigned(raddr2)) = 0 else regs(to_integer(unsigned(raddr2)));

end architecture rtl;
