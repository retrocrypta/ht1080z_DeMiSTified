library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

-------------------------------------------------------------------------

entity neptuno_top is
	port (
		CLOCK_50_I : in std_logic;
		KEY        : in std_logic_vector(1 downto 0);  -- KEY(0) SW1, KEY(1) SW2
		LED        : out std_logic;
		-- SDRAM
		DRAM_CLK   : out std_logic;
		DRAM_CKE   : out std_logic;
		DRAM_ADDR  : out std_logic_vector(12 downto 0);
		DRAM_BA    : out std_logic_vector(1 downto 0);
		DRAM_DQ    : inout std_logic_vector(15 downto 0);
		DRAM_LDQM  : out std_logic;
		DRAM_UDQM  : out std_logic;
		DRAM_CS_N  : out std_logic;
		DRAM_WE_N  : out std_logic;
		DRAM_CAS_N : out std_logic;
		DRAM_RAS_N : out std_logic;
        -- -- SRAM
        -- SRAM_A      : out   std_logic_vector(20 downto 0)   := (others => '0');
        -- SRAM_Q      : inout std_logic_vector(15 downto 0)    := (others => 'Z');
		-- SRAM_WE     : out   std_logic                               := '1';
        -- SRAM_OE     : out   std_logic                               := '0';
		-- SRAM_UB     : out   std_logic                               := '0';
        -- SRAM_LB     : out   std_logic                               := '0';
		-- VGA
		VGA_HS     : out std_logic;
		VGA_VS     : out std_logic;
		VGA_R      : out std_logic_vector(5 downto 0);
		VGA_G      : out std_logic_vector(5 downto 0);
		VGA_B      : out std_logic_vector(5 downto 0);
		-- AUDIO
		SIGMA_R    : out std_logic;
		SIGMA_L    : out std_logic;
		-- I2S audio		
		I2S_BCLK   : out std_logic := '0';
		I2S_LRCLK  : out std_logic := '0';
		I2S_DATA   : out std_logic := '0';
		-- EAR 
		AUDIO_INPUT : in std_logic;
		-- PS2
		PS2_KEYBOARD_CLK : inout std_logic;
		PS2_KEYBOARD_DAT : inout std_logic;
		PS2_MOUSE_CLK    : inout std_logic;
		PS2_MOUSE_DAT    : inout std_logic;
		-- UART
--		PMOD4_D4 : in std_logic;		--UART_RXD
--		PMOD4_D5 : out std_logic;		--UART_TXD
--		PMOD4_D6 : in std_logic;		--UART_CTS
--		PMOD4_D7 : out std_logic;		--UART_RTS
		-- JOYSTICK 
		JOY_CLK  : out std_logic;
		JOY_LOAD : out std_logic;
		JOY_DATA : in std_logic;
		JOYP7_O  : out std_logic := '1';
		-- SD Card
		SD_CS_N_O : out std_logic := '1';
		SD_SCLK_O : out std_logic := '0';
		SD_MOSI_O : out std_logic := '0';
		SD_MISO_I : in std_logic;
		-- STM32
		STM_RX_O  : out std_logic := 'Z'; -- stm RX pin, so, is OUT on the slave
		STM_TX_I  : in std_logic  := 'Z'; -- stm TX pin, so, is IN on the slave
		STM_RST_O : out std_logic := 'Z' -- '0' to hold the microcontroller reset line, to free the SD card
	);
END entity;

architecture RTL of neptuno_top is

	-- System clocks
	signal locked  : std_logic;
	signal reset_n : std_logic;

	-- SPI signals
	signal sd_clk  : std_logic;
	signal sd_cs   : std_logic;
	signal sd_mosi : std_logic;
	signal sd_miso : std_logic;

	-- internal SPI signals
	signal spi_do 	     : std_logic;
	signal spi_toguest   : std_logic;
	signal spi_fromguest : std_logic;
	signal spi_ss2       : std_logic;
	signal spi_ss3       : std_logic;
	signal spi_ss4       : std_logic;
	signal conf_data0    : std_logic;
	signal spi_clk_int   : std_logic;

	-- PS/2 Keyboard socket - used for second mouse
	signal ps2_keyboard_clk_in  : std_logic;
	signal ps2_keyboard_dat_in  : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

	-- PS/2 Mouse
	signal ps2_mouse_clk_in  : std_logic;
	signal ps2_mouse_dat_in  : std_logic;
	signal ps2_mouse_clk_out : std_logic;
	signal ps2_mouse_dat_out : std_logic;

	signal intercept : std_logic;

	-- Video
	signal vga_red   : std_logic_vector(7 downto 0);
	signal vga_green : std_logic_vector(7 downto 0);
	signal vga_blue  : std_logic_vector(7 downto 0);
	signal vga_hsync : std_logic;
	signal vga_vsync : std_logic;

	-- RS232 serial
	signal rs232_rxd : std_logic;
	signal rs232_txd : std_logic;

	-- IO
	signal joya : std_logic_vector(7 downto 0);
	signal joyb : std_logic_vector(7 downto 0);
	signal joyc : std_logic_vector(7 downto 0);
	signal joyd : std_logic_vector(7 downto 0);

	-- DAC AUDIO
	signal dac_l : signed(15 downto 0);
	signal dac_r : signed(15 downto 0);
	--signal dac_l: std_logic_vector(15 downto 0);
	--signal dac_r: std_logic_vector(15 downto 0);
	--signal dac_l_s: signed(15 downto 0);
	--signal dac_r_s: signed(15 downto 0);

	-- I2S 
	signal i2s_mclk : std_logic;

	component audio_top is
		port (
			clk_50MHz : in std_logic;  -- system clock
			dac_MCLK  : out std_logic; -- outputs to I2S DAC
			dac_LRCK  : out std_logic;
			dac_SCLK  : out std_logic;
			dac_SDIN  : out std_logic;
			L_data    : in std_logic_vector(15 downto 0); -- LEFT data (15-bit signed)
			R_data    : in std_logic_vector(15 downto 0)  -- RIGHT data (15-bit signed) 
		);
	end component;

	component joydecoder is
		port (
			clk        : in std_logic;
			joy_data   : in std_logic;
			joy_clk    : out std_logic;
			joy_load_n : out std_logic;
			joy1up     : out std_logic;
			joy1down   : out std_logic;
			joy1left   : out std_logic;
			joy1right  : out std_logic;
			joy1fire1  : out std_logic;
			joy1fire2  : out std_logic;
			joy2up     : out std_logic;
			joy2down   : out std_logic;
			joy2left   : out std_logic;
			joy2right  : out std_logic;
			joy2fire1  : out std_logic;
			joy2fire2  : out std_logic
		);
	end component;

	-- JOYSTICKS
	signal joy1up      : std_logic := '1';
	signal joy1down    : std_logic := '1';
	signal joy1left    : std_logic := '1';
	signal joy1right   : std_logic := '1';
	signal joy1fire1   : std_logic := '1';
	signal joy1fire2   : std_logic := '1';
	signal joy2up      : std_logic := '1';
	signal joy2down    : std_logic := '1';
	signal joy2left    : std_logic := '1';
	signal joy2right   : std_logic := '1';
	signal joy2fire1   : std_logic := '1';
	signal joy2fire2   : std_logic := '1';
	signal clk_sys_out : std_logic;

	signal sram_we_x : std_logic;

	signal act_led : std_logic;

	-- NeptUNO target guest_top template signals
	alias clock_input 	: std_logic is CLOCK_50_I;
--	alias uart_txd 		: std_logic is PMOD4_D5;
--	alias uart_rxd 		: std_logic is PMOD4_D4;
	
begin

	-- -- SRAM
	-- SRAM_OE <= '0';
	-- SRAM_WE <= sram_we_x;
	-- --SRAM_OE <= not sram_we_x;
	-- SRAM_UB <= '1';
	-- SRAM_LB <= '0';

	-- SPI
	SD_CS_N_O <= sd_cs;
	SD_MOSI_O <= sd_mosi;
	sd_miso   <= SD_MISO_I;
	SD_SCLK_O <= sd_clk;

	-- External devices tied to GPIOs
	ps2_mouse_dat_in <= PS2_MOUSE_DAT;
	PS2_MOUSE_DAT    <= '0' when ps2_mouse_dat_out = '0' else 'Z';
	ps2_mouse_clk_in <= PS2_MOUSE_CLK;
	PS2_MOUSE_CLK    <= '0' when ps2_mouse_clk_out = '0' else 'Z';

	ps2_keyboard_dat_in <= PS2_KEYBOARD_DAT;
	PS2_KEYBOARD_DAT    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
	ps2_keyboard_clk_in <= PS2_KEYBOARD_CLK;
	PS2_KEYBOARD_CLK    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';

	-- JOYSTICKS
	joya <= "11" & joy1fire2 & joy1fire1 & joy1right & joy1left & joy1down & joy1up;
	joyb <= "11" & joy2fire2 & joy2fire1 & joy2right & joy2left & joy2down & joy2up;

	joy : joydecoder
	port map(
		clk        => CLOCK_50_I,
		joy_clk    => JOY_CLK,
		joy_load_n => JOY_LOAD,
		joy_data   => JOY_DATA,
		joy1up     => joy1up,
		joy1down   => joy1down,
		joy1left   => joy1left,
		joy1right  => joy1right,
		joy1fire1  => joy1fire1,
		joy1fire2  => joy1fire2,
		joy2up     => joy2up,
		joy2down   => joy2down,
		joy2left   => joy2left,
		joy2right  => joy2right,
		joy2fire1  => joy2fire1,
		joy2fire2  => joy2fire2
	);

	STM_RST_O <= '0';

	VGA_R     <= vga_red(7 downto 2);
	VGA_G     <= vga_green(7 downto 2);
	VGA_B     <= vga_blue(7 downto 2);
	VGA_HS    <= vga_hsync;
	VGA_VS    <= vga_vsync;

	-- I2S audio
	audio_i2s : entity work.audio_top
		port map (
			clk_50MHz => CLOCK_50_I,
			dac_MCLK  => I2S_MCLK,
			dac_SCLK  => I2S_BCLK,
			dac_SDIN  => I2S_DATA,
			dac_LRCK  => I2S_LRCLK,
			L_data    => std_logic_vector(dac_l),
			R_data    => std_logic_vector(dac_r)
		--	L_data    => std_logic_vector(dac_l_s),
		--	R_data    => std_logic_vector(dac_r_s)
		);

	--dac_l_s <= ('0' & dac_l(14 downto 0));
	--dac_r_s <= ('0' & dac_r(14 downto 0));



	guest : component HT1080Z
		port map
		(
--			CLOCK_27   => clock_input&clock_input, -- Comment out one of these lines to match the guest core.
			CLOCK_27   => clock_input,
--			RESET_N    => reset_n,
--			LED 	   => act_led,

			--SDRAM
			SDRAM_DQ   => DRAM_DQ,
			SDRAM_A    => DRAM_ADDR,
			SDRAM_DQML => DRAM_LDQM,
			SDRAM_DQMH => DRAM_UDQM,
			SDRAM_nWE  => DRAM_WE_N,
			SDRAM_nCAS => DRAM_CAS_N,
			SDRAM_nRAS => DRAM_RAS_N,
			SDRAM_nCS  => DRAM_CS_N,
			SDRAM_BA   => DRAM_BA,
			SDRAM_CLK  => DRAM_CLK,
			SDRAM_CKE  => DRAM_CKE,

			-- --SRAM
			-- SRAM_A		=> SRAM_A,
			-- SRAM_Q		=> SRAM_Q,
			-- SRAM_WE		=> sram_we_x,

			--UART
			-- UART_TX    => uart_txd,
			-- UART_RX    => uart_rxd,
			--EAR 
			-- UART_TX    => open,
			-- UART_RX    => AUDIO_INPUT,

			--SPI
			SPI_DO     => spi_do,
			SPI_DI     => spi_toguest,
			SPI_SCK    => spi_clk_int,
			SPI_SS2    => spi_ss2,
			SPI_SS3    => spi_ss3,
			SPI_SS4    => spi_ss4,
			CONF_DATA0 => conf_data0,

			--VGA
			VGA_HS     => vga_hsync,
			VGA_VS     => vga_vsync,
			VGA_R      => vga_red(7 downto 2),
			VGA_G      => vga_green(7 downto 2),
			VGA_B      => vga_blue(7 downto 2),

			--AUDIO
			-- DAC_L   => dac_l,
			-- DAC_R   => dac_r,
			AUDIO_L => SIGMA_L,
			AUDIO_R => SIGMA_R

			--PS2
			-- PS2K_CLK => ps2_keyboard_clk_in or intercept, -- Block keyboard when OSD is active
			-- PS2K_DAT => ps2_keyboard_dat_in,
			-- PS2M_CLK => ps2_mouse_clk_in,
			-- PS2M_DAT => ps2_mouse_dat_in
		);


	-- Pass internal signals to external SPI interface
	sd_clk <= spi_clk_int;
	spi_do <= sd_miso when spi_ss4='0' else 'Z'; -- to guest
	spi_fromguest <= spi_do;  -- to control CPU

	controller : entity work.substitute_mcu
		generic map (
			sysclk_frequency => 500,
	--		SPI_FASTBIT=>3,
	--		SPI_INTERNALBIT=>2,		--needed if OSD hungs
			debug     => false,
			jtag_uart => false
		)
		port map (
			clk       => CLOCK_50_I,
			reset_in  => KEY(0),		--reset_in  when 0
			reset_out => reset_n,		--reset_out when 0

			-- SPI signals
			spi_miso      => sd_miso,
			spi_mosi      => sd_mosi,
			spi_clk       => spi_clk_int,
			spi_cs        => sd_cs,
			spi_fromguest => spi_fromguest,
			spi_toguest   => spi_toguest,
			spi_ss2       => spi_ss2,
			spi_ss3       => spi_ss3,
			spi_ss4       => spi_ss4,
			conf_data0    => conf_data0,

			-- PS/2 signals
			ps2k_clk_in  => ps2_keyboard_clk_in,
			ps2k_dat_in  => ps2_keyboard_dat_in,
			ps2k_clk_out => ps2_keyboard_clk_out,
			ps2k_dat_out => ps2_keyboard_dat_out,
			ps2m_clk_in  => ps2_mouse_clk_in,
			ps2m_dat_in  => ps2_mouse_dat_in,
			ps2m_clk_out => ps2_mouse_clk_out,
			ps2m_dat_out => ps2_mouse_dat_out,

			-- Buttons
			buttons => (0 => KEY(1), others => '1'),	-- 0 => OSD_button

			-- Joysticks
			joy1 => joya,
			joy2 => joyb,

			-- UART
			rxd  => rs232_rxd,
			txd  => rs232_txd,
			--
			intercept => intercept
		);

	LED <= not act_led;

end rtl;
