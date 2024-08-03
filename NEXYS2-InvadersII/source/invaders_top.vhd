-- Space Invaders top level for
-- ps/2 keyboard interface with sound and scan doubler MikeJ
--
-- Version : 0300
--
-- Copyright (c) 2002 Daniel Wallner (jesus@opencores.org)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.fpgaarcade.com
--
-- Limitations :
--
-- File history :
--
--      0241 : First release
--
--      0242 : Moved the PS/2 interface to ps2kbd.vhd, added the ROM from mw8080.vhd
--
--      0300 : MikeJ tidy up for audio release

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity invaders_top is
	port(
	--	STRATAFLASH_OE    : out   std_logic;
	--	STRATAFLASH_CE    : out   std_logic;
	--	STRATAFLASH_WE    : out   std_logic;
		--
		I_PS2_CLK         : in    std_logic;
		I_PS2_DATA        : in    std_logic;
		
	 SW_COIN                : in    std_logic;
	 SW_START               : in    std_logic;
	 SW_SHOOT               : in    std_logic;
--	 SW_BOMB                : in    std_logic;
	 SW_LEFT                : in    std_logic;
	 SW_RIGHT               : in    std_logic;
--	 SW_UP                  : in    std_logic;
--	 SW_DOWN                : in    std_logic;
		--
    O_VIDEO_R             : out   std_logic_vector(2 downto 0);
    O_VIDEO_G             : out   std_logic_vector(2 downto 0);
    O_VIDEO_B             : out   std_logic_vector(1 downto 0);
    O_HSYNC               : out   std_logic;
    O_VSYNC               : out   std_logic;
		--
	--	O_AUDIO_L         : out   std_logic;
	--	O_AUDIO_R         : out   std_logic;
		O_AUDIO           : out   std_logic;
		--
		I_RESET           : in    std_logic;
		I_CLK_REF         : in    std_logic
		);
end invaders_top;

architecture rtl of invaders_top is

	signal I_RESET_L       : std_logic;
	signal Clk             : std_logic;
	signal Clk_x2          : std_logic;
	signal Rst_n_s         : std_logic;

	signal DIP             : std_logic_vector(8 downto 1);
	signal RWE_n           : std_logic;
	signal Video           : std_logic;
	signal VideoRGB        : std_logic_vector(2 downto 0);
	signal VideoRGB_X2     : std_logic_vector(7 downto 0);
	signal HSync           : std_logic;
	signal VSync           : std_logic;
	signal HSync_X2        : std_logic;
	signal VSync_X2        : std_logic;
---------------------------------------------------------------
	signal AD              : std_logic_vector(15 downto 0);
	signal RAB             : std_logic_vector(12 downto 0);
	signal RDB             : std_logic_vector(7 downto 0);
	signal RWD             : std_logic_vector(7 downto 0);
	signal IB              : std_logic_vector(7 downto 0);
	signal SoundCtrl3      : std_logic_vector(5 downto 0);
	signal SoundCtrl5      : std_logic_vector(5 downto 0);

	signal Buttons         : std_logic_vector(5 downto 0);
	signal Buttons_n       : std_logic_vector(5 downto 1);

	signal Tick1us         : std_logic;

	signal PS2_Sample      : std_logic;
	signal PS2_Data_s      : std_logic;
	signal ScanCode        : std_logic_vector(7 downto 0);
	signal Press           : std_logic;
	signal Release         : std_logic;
	signal Reset           : std_logic;

	signal rom_data_0      : std_logic_vector(7 downto 0);
	signal rom_data_1      : std_logic_vector(7 downto 0);
	signal rom_data_2      : std_logic_vector(7 downto 0);
	signal rom_data_3      : std_logic_vector(7 downto 0);
	signal rom_data_4      : std_logic_vector(7 downto 0);
	signal rom_data_5      : std_logic_vector(7 downto 0);
	signal rom_data_6      : std_logic_vector(7 downto 0);
	signal ram_we          : std_logic;
	--
	signal HCnt            : std_logic_vector(11 downto 0);
	signal VCnt            : std_logic_vector(11 downto 0);
	signal HSync_t1        : std_logic;
	signal Overlay_G1      : boolean;
	signal Overlay_G2      : boolean;
	signal Overlay_R1      : boolean;
	signal Overlay_G1_VCnt : boolean;
	--
	signal Audio           : std_logic_vector(7 downto 0);
	signal AudioPWM        : std_logic;
	

begin
  ----------------------------------------------------------------------------------------------------------------------------------
  -- Disable unused components
  ----------------------------------------------------------------------------------------------------------------------------------
  --
  --StrataFLASH must be disabled to prevent it conflicting with the LCD display
  --
 -- STRATAFLASH_OE <= '1';
 -- STRATAFLASH_CE <= '1';
 -- STRATAFLASH_WE <= '1';
  --
  I_RESET_L <= not I_RESET;
  --
  u_clocks : entity work.INVADERS_CLOCKS
	port map (
	   I_CLK_REF  => I_CLK_REF,
	   I_RESET_L  => I_RESET_L,
	   --
	   O_CLK      => Clk,
	   O_CLK_X2   => Clk_x2
	 );

	Buttons_n <= not Buttons(5 downto 1);
	DIP <= "00000000";

	core : entity work.invaderst
		port map(
			Rst_n      => I_RESET_L,
			Clk        => Clk,
			Coin       => not SW_COIN, -- Buttons(0),
			Sel1Player => not SW_START, -- Buttons_n(1),
			Sel2Player => '1',
			FireA      => not SW_SHOOT, -- Buttons_n(3),
			MoveLeftA  => not SW_LEFT, -- Buttons_n(4),
			MoveRightA => not SW_RIGHT, -- Buttons_n(5),
			FireB      => '1',
			MoveLeftB  => '1',
			MoveRightB => '1',
			DIP        => DIP,
			RDB        => RDB,
			IB         => IB,
			RWD        => RWD,
			RAB        => RAB,
			AD         => AD,
			SoundCtrl3 => SoundCtrl3,
			SoundCtrl5 => SoundCtrl5,
			Rst_n_s    => Rst_n_s,
			RWE_n      => RWE_n,
			Video      => Video,
			HSync      => HSync,
			VSync      => VSync
			);
	--
	-- ROM
	--
	u_rom_h : entity work.INVADERS_ROM_H
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_0
		);
	--
	u_rom_g : entity work.INVADERS_ROM_G
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_1
		);
	--
	u_rom_f : entity work.INVADERS_ROM_F
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_2
		);
	--
	u_rom_e : entity work.INVADERS_ROM_E
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_3
		);
		
	u_rom_b : entity work.INVADERS_ROM_B
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_4
		);
		
	u_rom_a : entity work.INVADERS_ROM_A
	  port map (
		CLK         => Clk,
	--	ENA         => '1',
		ADDR        => AD(10 downto 0),
		DATA        => rom_data_5
		);
		
	--
	p_rom_data : process(AD, rom_data_0, rom_data_1, rom_data_2, rom_data_3, rom_data_4, rom_data_5)
	begin
	  IB <= (others => '0');
	  case AD(15 downto 11) is
		when "00000" => IB <= rom_data_0;
		when "00001" => IB <= rom_data_1;
		when "00010" => IB <= rom_data_2;
		when "00011" => IB <= rom_data_3;
		when "01000" => IB <= rom_data_4;
   	when "01010" => IB <= rom_data_4;
		when "01011" => IB <= rom_data_5;
		when others => null;
	  end case;
	end process;
	--
	-- SRAM
	--
	ram_we <= not RWE_n;

	rams : for i in 0 to 3 generate
	  u_ram : component RAMB16_S2
	  port map (
		do   => RDB((i*2)+1 downto (i*2)),
		addr => RAB,
		clk  => Clk,
		di   => RWD((i*2)+1 downto (i*2)),
		en   => '1',
		ssr  => '0',
		we   => ram_we
		);
	end generate;
	--
	-- Glue
	--
	process (Rst_n_s, Clk)
		variable cnt : unsigned(3 downto 0);
	begin
		if Rst_n_s = '0' then
			cnt := "0000";
			Tick1us <= '0';
		elsif Clk'event and Clk = '1' then
			Tick1us <= '0';
			if cnt = 9 then
				Tick1us <= '1';
				cnt := "0000";
			else
				cnt := cnt + 1;
			end if;
		end if;
	end process;
----------------------------------------------------------------
	-- Keyboard decoder
	--
--	kbd : entity work.ps2kbd
--		port map(
--			Rst_n => Rst_n_s,
--			Clk => Clk,
--			Tick1us => Tick1us,
--			PS2_Clk => I_PS2_CLK,
--			PS2_Data => I_PS2_DATA,
--			Press => Press,
--			Release => Release,
--			Reset => Reset,
--			ScanCode => ScanCode);

--	process (Clk, Rst_n_s)
--	begin
--		if Rst_n_s = '0' then
--			Buttons <= (others => '0');
--		elsif Clk'event and Clk = '1' then
--			if (Press or Release) = '1' then
--				if ScanCode = x"21" then        -- c
--					Buttons(0) <= Press;
--				end if;
--				if ScanCode = x"16" or ScanCode = x"69" then    -- 1
--					Buttons(1) <= Press;
--				end if;
--				if ScanCode = x"1e" or ScanCode = x"72" then    -- 2
--					Buttons(2) <= Press;
--				end if;
--				if ScanCode = x"29" then        -- Space
--					Buttons(3) <= Press;
--				end if;
--				if ScanCode = x"6b" then        -- Left
--					Buttons(4) <= Press;
--				end if;
--				if ScanCode = x"74" then        -- Right
--					Buttons(5) <= Press;
--				end if;
--			end if;
--			if Reset = '1' then
--				Buttons <= (others => '0');
--			end if;
--		end if;
--	end process;
----------------------------------------------------------------------------
  -- Video Output
  --
  p_overlay : process(Rst_n_s, Clk)
	variable HStart : boolean;
  begin
	if Rst_n_s = '0' then
	  HCnt <= (others => '0');
	  VCnt <= (others => '0');
	  HSync_t1 <= '0';
	  Overlay_G1_VCnt <= false;
	  Overlay_G1 <= false;
	  Overlay_G2 <= false;
	  Overlay_R1 <= false;
	elsif Clk'event and Clk = '1' then
	  HSync_t1 <= HSync;
	  HStart := (HSync_t1 = '0') and (HSync = '1');-- rising

	  if HStart then
		HCnt <= (others => '0');
	  else
		HCnt <= HCnt + "1";
	  end if;

	  if (VSync = '0') then
		VCnt <= (others => '0');
	  elsif HStart then
		VCnt <= VCnt + "1";
	  end if;

	  if HStart then
		if (Vcnt = x"1F") then
		  Overlay_G1_VCnt <= true;
		elsif (Vcnt = x"95") then
		  Overlay_G1_VCnt <= false;
		end if;
	  end if;

	  if (HCnt = x"027") and Overlay_G1_VCnt then
		Overlay_G1 <= true;
	  elsif (HCnt = x"046") then
		Overlay_G1 <= false;
	  end if;

	  if (HCnt = x"046") then
		Overlay_G2 <= true;
	  elsif (HCnt = x"0B6") then
		Overlay_G2 <= false;
	  end if;

	  if (HCnt = x"1A6") then
		Overlay_R1 <= true;
	  elsif (HCnt = x"1E6") then
		Overlay_R1 <= false;
	  end if;

	end if;
  end process;

  p_video_out_comb : process(Video, Overlay_G1, Overlay_G2, Overlay_R1)
  begin
	if (Video = '0') then
	  VideoRGB  <= "000"; --black
	else
	  if Overlay_G1 or Overlay_G2 then --green
		VideoRGB  <= "010";
	  elsif Overlay_R1 then --red
		VideoRGB  <= "100";
	  else
		VideoRGB  <= "111"; --edit test blue --111 white
	  end if;
	end if;
  end process;
------------------------------------------------------------------
  u_dblscan : entity work.DBLSCAN
	port map (
	  RGB_IN(7 downto 3) => "00000",
	  RGB_IN(2 downto 0) => VideoRGB,
	  HSYNC_IN           => HSync,
	  VSYNC_IN           => VSync,

	  RGB_OUT            => VideoRGB_X2,
	  HSYNC_OUT          => HSync_X2,
	  VSYNC_OUT          => VSync_X2,
	  --  NOTE CLOCKS MUST BE PHASE LOCKED !!
	  CLK                => Clk,
	  CLK_X2             => Clk_x2
	);

  O_VIDEO_R <= VideoRGB_X2(2)&VideoRGB_X2(2)&VideoRGB_X2(2);
  O_VIDEO_G <= VideoRGB_X2(1)&VideoRGB_X2(1)&VideoRGB_X2(1);
  O_VIDEO_B <= VideoRGB_X2(0)&VideoRGB_X2(0);
  O_HSYNC   <= not HSync_X2;
  O_VSYNC   <= not VSync_X2;
---------------------------------------------------------------------
  -- Audio
  --
  u_audio : entity work.invaders_audio
	port map (
	  Clk => Clk,
	  S1  => SoundCtrl3,
	  S2  => SoundCtrl5,
	  Aud => Audio
	  );
-----------------------------------------------------------------------
  u_dac : entity work.dac
	generic map(
	  msbi_g => 7
	)
	port  map(
	  clk_i   => Clk,
	  res_n_i => Rst_n_s,
	  dac_i   => Audio,
	  dac_o   => AudioPWM
	);

    O_AUDIO <= AudioPWM;
--  O_AUDIO_L <= AudioPWM;
--  O_AUDIO_R <= AudioPWM;
-------------------------------------------------------------------------
end;
