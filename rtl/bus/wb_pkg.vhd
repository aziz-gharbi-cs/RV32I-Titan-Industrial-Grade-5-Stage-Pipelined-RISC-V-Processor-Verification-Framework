library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wb_pkg is

    -- Wishbone Master Output (Slave Input)
    type wb_req_t is record
        cyc : std_logic;                     -- Bus cycle active
        stb : std_logic;                     -- Strobe (transfer request)
        we  : std_logic;                     -- Write enable ('1' = write, '0' = read)
        adr : std_logic_vector(31 downto 0); -- Byte address
        dat : std_logic_vector(31 downto 0); -- Data to slave
        sel : std_logic_vector(3 downto 0);  -- Byte select lanes
    end record;

    -- Wishbone Slave Output (Master Input)
    type wb_resp_t is record
        ack : std_logic;                     -- Transfer acknowledge
        dat : std_logic_vector(31 downto 0); -- Data from slave
        err : std_logic;                     -- Error termination
    end record;

    constant WB_REQ_IDLE : wb_req_t := (
        cyc => '0',
        stb => '0',
        we  => '0',
        adr => (others => '0'),
        dat => (others => '0'),
        sel => (others => '0')
    );

    constant WB_RESP_IDLE : wb_resp_t := (
        ack => '0',
        dat => (others => '0'),
        err => '0'
    );

end package wb_pkg;
