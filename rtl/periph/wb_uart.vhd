library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_pkg.all;

entity wb_uart is
    generic (
        CLKS_PER_BIT : integer := 16
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        req    : in  wb_req_t;
        resp   : out wb_resp_t;
        tx_out : out std_logic
    );
end entity wb_uart;

architecture rtl of wb_uart is
    type tx_state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state      : tx_state_t := IDLE;
    signal clk_cnt    : integer range 0 to CLKS_PER_BIT := 0;
    signal bit_idx    : integer range 0 to 7 := 0;
    signal tx_shift   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy    : std_logic;
begin

    -- Busy whenever not in IDLE
    tx_busy <= '0' when state = IDLE else '1';

    -- Combinational bus response
    resp.ack <= req.cyc and req.stb;
    resp.err <= '0';
    resp.dat <= (0 => tx_busy, others => '0') when req.adr(2) = '1' else (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= IDLE;
                tx_out  <= '1';
                clk_cnt <= 0;
                bit_idx <= 0;
            else
                case state is
                    when IDLE =>
                        tx_out  <= '1';
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        if (req.cyc = '1' and req.stb = '1' and req.we = '1' and req.adr(2) = '0') then
                            tx_shift <= req.dat(7 downto 0);
                            state    <= START_BIT;
                        end if;

                    when START_BIT =>
                        tx_out <= '0';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            state   <= DATA_BITS;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA_BITS =>
                        tx_out <= tx_shift(bit_idx);
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            if bit_idx = 7 then
                                state <= STOP_BIT;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when STOP_BIT =>
                        tx_out <= '1';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            state   <= IDLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
