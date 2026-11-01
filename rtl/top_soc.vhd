library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_pkg.all;

entity top_soc is
    generic (
        CLKS_PER_BIT : integer := 16 -- Fast rate for simulation, 868 for 100MHz@115200 FPGA
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        tx_out : out std_logic
    );
end entity top_soc;

architecture rtl of top_soc is
    -- Core interface signals
    signal imem_addr  : std_logic_vector(31 downto 0);
    signal imem_rdata : std_logic_vector(31 downto 0);
    signal dmem_addr  : std_logic_vector(31 downto 0);
    signal dmem_wdata : std_logic_vector(31 downto 0);
    signal dmem_rdata : std_logic_vector(31 downto 0);
    signal dmem_we    : std_logic;
    signal dmem_re    : std_logic;

    -- Wishbone Channels
    signal imem_wb_req  : wb_req_t;
    signal imem_wb_resp : wb_resp_t;
    signal dmem_wb_req  : wb_req_t;
    signal dmem_wb_resp : wb_resp_t;

    signal uart_wb_req  : wb_req_t;
    signal uart_wb_resp : wb_resp_t;
    signal ram_d_req    : wb_req_t;
    signal ram_d_resp   : wb_resp_t;

    signal is_uart_access : boolean;
begin

    -- Core Datapath Instance
    u_core: entity work.datapath
        port map (
            clk        => clk,
            rst        => rst,
            imem_addr  => imem_addr,
            imem_rdata => imem_rdata,
            dmem_addr  => dmem_addr,
            dmem_wdata => dmem_wdata,
            dmem_rdata => dmem_rdata,
            dmem_we    => dmem_we,
            dmem_re    => dmem_re,
            wb_valid   => open,
            wb_rd      => open,
            wb_data    => open
        );

    -- Instruction Fetch -> Wishbone Bus Adapter
    imem_wb_req.cyc <= '1';
    imem_wb_req.stb <= '1';
    imem_wb_req.we  <= '0';
    imem_wb_req.adr <= imem_addr;
    imem_wb_req.dat <= (others => '0');
    imem_wb_req.sel <= "1111";
    imem_rdata      <= imem_wb_resp.dat;

    -- Data Memory -> Wishbone Demux:
    -- 0x00000000 - 0x00007FFF : 32 KB RAM
    -- 0x10000000 - 0x100000FF : UART Peripheral
    is_uart_access <= (unsigned(dmem_addr(31 downto 28)) = x"1");

    -- Wishbone Routing to RAM
    ram_d_req.cyc <= (dmem_re or dmem_we) when not is_uart_access else '0';
    ram_d_req.stb <= (dmem_re or dmem_we) when not is_uart_access else '0';
    ram_d_req.we  <= dmem_we;
    ram_d_req.adr <= dmem_addr;
    ram_d_req.dat <= dmem_wdata;
    ram_d_req.sel <= "1111";

    -- Wishbone Routing to UART
    uart_wb_req.cyc <= (dmem_re or dmem_we) when is_uart_access else '0';
    uart_wb_req.stb <= (dmem_re or dmem_we) when is_uart_access else '0';
    uart_wb_req.we  <= dmem_we;
    uart_wb_req.adr <= dmem_addr;
    uart_wb_req.dat <= dmem_wdata;
    uart_wb_req.sel <= "1111";

    -- Read data return mux
    dmem_rdata <= uart_wb_resp.dat when is_uart_access else ram_d_resp.dat;

    -- 32 KB Dual-Port BRAM
    u_ram: entity work.wb_ram
        generic map (
            DEPTH_WORDS => 8192
        )
        port map (
            clk    => clk,
            rst    => rst,
            i_req  => imem_wb_req,
            i_resp => imem_wb_resp,
            d_req  => ram_d_req,
            d_resp => ram_d_resp
        );

    -- Memory-Mapped UART
    u_uart: entity work.wb_uart
        generic map (
            CLKS_PER_BIT => CLKS_PER_BIT
        )
        port map (
            clk    => clk,
            rst    => rst,
            req    => uart_wb_req,
            resp   => uart_wb_resp,
            tx_out => tx_out
        );

end architecture rtl;
