library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_pkg.all;

entity wb_ram is
    generic (
        DEPTH_WORDS : integer := 8192 -- 32 KB
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Port A: Instruction Fetch (Combinational read)
        i_req    : in  wb_req_t;
        i_resp   : out wb_resp_t;
        
        -- Port B: Data Memory
        d_req    : in  wb_req_t;
        d_resp   : out wb_resp_t
    );
end entity wb_ram;

architecture rtl of wb_ram is
    type ram_array_t is array (0 to DEPTH_WORDS - 1) of std_logic_vector(31 downto 0);
    signal ram_block : ram_array_t := (others => (others => '0'));
    
    signal i_idx, d_idx : integer range 0 to DEPTH_WORDS - 1;
begin

    i_idx <= to_integer(unsigned(i_req.adr(14 downto 2))) mod DEPTH_WORDS;
    d_idx <= to_integer(unsigned(d_req.adr(14 downto 2))) mod DEPTH_WORDS;

    -- Port A: Combinational read so IF stage receives instruction in same cycle
    i_resp.ack <= i_req.cyc and i_req.stb;
    i_resp.err <= '0';
    i_resp.dat <= ram_block(i_idx) when (i_req.cyc = '1' and i_req.stb = '1') else (others => '0');

    -- Port B: Data read/write (synchronous write, combinational read)
    d_resp.ack <= d_req.cyc and d_req.stb;
    d_resp.err <= '0';
    d_resp.dat <= ram_block(d_idx);

    process(clk)
        variable current_word : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            if d_req.cyc = '1' and d_req.stb = '1' and d_req.we = '1' then
                current_word := ram_block(d_idx);
                if d_req.sel(0) = '1' then current_word(7 downto 0)   := d_req.dat(7 downto 0);   end if;
                if d_req.sel(1) = '1' then current_word(15 downto 8)  := d_req.dat(15 downto 8);  end if;
                if d_req.sel(2) = '1' then current_word(23 downto 16) := d_req.dat(23 downto 16); end if;
                if d_req.sel(3) = '1' then current_word(31 downto 24) := d_req.dat(31 downto 24); end if;
                ram_block(d_idx) <= current_word;
            end if;
        end if;
    end process;

end architecture rtl;
