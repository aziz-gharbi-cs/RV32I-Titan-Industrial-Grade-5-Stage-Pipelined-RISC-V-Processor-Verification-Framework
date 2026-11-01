library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pipeline_pkg is

    type if_id_reg_t is record
        pc          : std_logic_vector(31 downto 0);
        instruction : std_logic_vector(31 downto 0);
    end record;

    type id_ex_reg_t is record
        pc          : std_logic_vector(31 downto 0);
        rdata1      : std_logic_vector(31 downto 0);
        rdata2      : std_logic_vector(31 downto 0);
        imm         : std_logic_vector(31 downto 0);
        rs1         : std_logic_vector(4 downto 0);
        rs2         : std_logic_vector(4 downto 0);
        rd          : std_logic_vector(4 downto 0);
        funct3      : std_logic_vector(2 downto 0);
        reg_write   : std_logic;
        mem_to_reg  : std_logic_vector(1 downto 0);
        mem_write   : std_logic;
        mem_read    : std_logic;
        alu_src     : std_logic;
        branch      : std_logic;
        jump        : std_logic;
        is_auipc    : std_logic;
        alu_op      : std_logic_vector(3 downto 0);
    end record;

    type ex_mem_reg_t is record
        pc_plus4    : std_logic_vector(31 downto 0);
        alu_result  : std_logic_vector(31 downto 0);
        write_data  : std_logic_vector(31 downto 0);
        rd          : std_logic_vector(4 downto 0);
        funct3      : std_logic_vector(2 downto 0);
        reg_write   : std_logic;
        mem_to_reg  : std_logic_vector(1 downto 0);
        mem_write   : std_logic;
        mem_read    : std_logic;
    end record;

    type mem_wb_reg_t is record
        pc_plus4    : std_logic_vector(31 downto 0);
        alu_result  : std_logic_vector(31 downto 0);
        read_data   : std_logic_vector(31 downto 0);
        rd          : std_logic_vector(4 downto 0);
        reg_write   : std_logic;
        mem_to_reg  : std_logic_vector(1 downto 0);
    end record;

    constant IF_ID_RESET : if_id_reg_t := (
        pc => (others => '0'),
        instruction => x"00000013"
    );

    constant ID_EX_RESET : id_ex_reg_t := (
        pc => (others => '0'),
        rdata1 => (others => '0'),
        rdata2 => (others => '0'),
        imm => (others => '0'),
        rs1 => (others => '0'),
        rs2 => (others => '0'),
        rd => (others => '0'),
        funct3 => (others => '0'),
        reg_write => '0',
        mem_to_reg => "00",
        mem_write => '0',
        mem_read => '0',
        alu_src => '0',
        branch => '0',
        jump => '0',
        is_auipc => '0',
        alu_op => (others => '0')
    );

    constant EX_MEM_RESET : ex_mem_reg_t := (
        pc_plus4 => (others => '0'),
        alu_result => (others => '0'),
        write_data => (others => '0'),
        rd => (others => '0'),
        funct3 => (others => '0'),
        reg_write => '0',
        mem_to_reg => "00",
        mem_write => '0',
        mem_read => '0'
    );

    constant MEM_WB_RESET : mem_wb_reg_t := (
        pc_plus4 => (others => '0'),
        alu_result => (others => '0'),
        read_data => (others => '0'),
        rd => (others => '0'),
        reg_write => '0',
        mem_to_reg => "00"
    );

end package pipeline_pkg;
