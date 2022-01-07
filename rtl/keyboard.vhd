--//============================================================================
--//  MSX1
--//  Keyboard matrix maping
--//  Copyright (C) 2021 molekula
--//
--//  This program is free software; you can redistribute it and/or modify it
--//  under the terms of the GNU General Public License as published by the Free
--//  Software Foundation; either version 2 of the License, or (at your option)
--//  any later version.
--//
--//  This program is distributed in the hope that it will be useful, but WITHOUT
--//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
--//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
--//  more details.
--//
--//  You should have received a copy of the GNU General Public License along
--//  with this program; if not, write to the Free Software Foundation, Inc.,
--//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--//
--//============================================================================
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity keyboard is
	port (
		reset_n_i    : in  std_logic;
		clk_i        : in  std_logic;
		ps2_code_i   : in  std_logic_vector(10 downto 0);
		kb_addr_i		: in  std_logic_vector(3 downto 0);
		kb_data_o		: out std_logic_vector(7 downto 0)
	);
end keyboard;


architecture rtl of keyboard is
	type keyMatrixType is array(8 downto 0) of std_logic_vector(7 downto 0);
	signal keyMatrix : keyMatrixType := (others => (others => '1'));
	signal scancode : std_logic_vector(7 downto 0);
	signal changed : std_logic := '0';
	signal release : std_logic := '1';
  	
begin
	kb_data_o <= keyMatrix(to_integer(unsigned(kb_addr_i)))(7 downto 0) 
				 when to_integer(unsigned(kb_addr_i)) < 9 
				 else (others => '1');
	 
	change : process (clk_i)
	variable old_code : std_logic_vector(10 downto 0) := (others=>'0');  
	begin
		if clk_i'event and clk_i = '1' then	
			if old_code /= ps2_code_i then
				release <=  NOT ps2_code_i(9);
				scancode <= ps2_code_i(7 downto 0);
				changed <= '1';
			else
				changed <= '0';
			end if;
			old_code := ps2_code_i;
		end if;
	end process;
  
	decode : process (clk_i)
	begin
		if clk_i'event and clk_i = '1' then	
			if changed = '1' then
				if ps2_code_i(8) = '0' then
					case scancode is
						-- 0
						when x"45" => keyMatrix(0)(0) <= release; -- 0
						when x"16" => keyMatrix(0)(1) <= release; -- 1
						when x"1e" => keyMatrix(0)(2) <= release; -- 2
						when x"26" => keyMatrix(0)(3) <= release; -- 3
						when x"25" => keyMatrix(0)(4) <= release; -- 4        
						when x"2e" => keyMatrix(0)(5) <= release; -- 5
						when x"36" => keyMatrix(0)(6) <= release; -- 6
						when x"3d" => keyMatrix(0)(7) <= release; -- 7
						-- 1
						when x"3e" => keyMatrix(1)(0) <= release; -- 8
						when x"46" => keyMatrix(1)(1) <= release; -- 9
						when x"4e" => keyMatrix(1)(2) <= release; -- -
						when x"55" => keyMatrix(1)(3) <= release; -- =
						when x"5d" => keyMatrix(1)(4) <= release; -- \
						when x"54" => keyMatrix(1)(5) <= release; -- [
						when x"5b" => keyMatrix(1)(6) <= release; -- ]
						when x"4c" => keyMatrix(1)(7) <= release; -- ;
						-- 2
						when x"52" => keyMatrix(2)(0) <= release; -- '
						when x"0e" => keyMatrix(2)(1) <= release; -- `
						when x"41" => keyMatrix(2)(2) <= release; -- ,
						when x"49" => keyMatrix(2)(3) <= release; -- .
						when x"4a" => keyMatrix(2)(4) <= release; -- /				  
						when x"01" => keyMatrix(2)(5) <= release; -- F11 (DEAD KEY)
						when x"1c" => keyMatrix(2)(6) <= release; -- A
						when x"32" => keyMatrix(2)(7) <= release; -- B
						-- 3
						when x"21" => keyMatrix(3)(0) <= release; -- C
						when x"23" => keyMatrix(3)(1) <= release; -- D
						when x"24" => keyMatrix(3)(2) <= release; -- E
						when x"2b" => keyMatrix(3)(3) <= release; -- F
						when x"34" => keyMatrix(3)(4) <= release; -- G				  
						when x"33" => keyMatrix(3)(5) <= release; -- H
						when x"43" => keyMatrix(3)(6) <= release; -- I
						when x"3b" => keyMatrix(3)(7) <= release; -- J
						-- 4
						when x"42" => keyMatrix(4)(0) <= release; -- K
						when x"4b" => keyMatrix(4)(1) <= release; -- L
						when x"3a" => keyMatrix(4)(2) <= release; -- M
						when x"31" => keyMatrix(4)(3) <= release; -- N
						when x"44" => keyMatrix(4)(4) <= release; -- O				  
						when x"4d" => keyMatrix(4)(5) <= release; -- P
						when x"15" => keyMatrix(4)(6) <= release; -- Q
						when x"2d" => keyMatrix(4)(7) <= release; -- R
						-- 5
						when x"1b" => keyMatrix(5)(0) <= release; -- S
						when x"2c" => keyMatrix(5)(1) <= release; -- T
						when x"3c" => keyMatrix(5)(2) <= release; -- U
						when x"2a" => keyMatrix(5)(3) <= release; -- V
						when x"1d" => keyMatrix(5)(4) <= release; -- W				  
						when x"22" => keyMatrix(5)(5) <= release; -- X
						when x"35" => keyMatrix(5)(6) <= release; -- Y
						when x"1a" => keyMatrix(5)(7) <= release; -- Z
						-- 6
						when x"12" => keyMatrix(6)(0) <= release; -- LEFT SHIFT
						when x"14" => keyMatrix(6)(1) <= release; -- LEFT CTRL
						-- when x"11" => keyMatrix(6)(2) <= release; -- RIGHT ALT (GRAPH)
						when x"58" => keyMatrix(6)(3) <= release; -- CAPS LOCK
						when x"09" => keyMatrix(6)(4) <= release; -- F10 (CODE)
						when x"05" => keyMatrix(6)(5) <= release; -- F1
						when x"06" => keyMatrix(6)(6) <= release; -- F2
						when x"04" => keyMatrix(6)(7) <= release; -- F3
						-- 7
						when x"0c" => keyMatrix(7)(0) <= release; -- F4
						when x"03" => keyMatrix(7)(1) <= release; -- F5  
						when x"76" => keyMatrix(7)(2) <= release; -- ESC
						when x"0D" => keyMatrix(7)(3) <= release; -- TAB
						-- when x"7b" => keyMatrix(7)(4) <= release; -- pause/break (STOP)
						when x"66" => keyMatrix(7)(5) <= release; -- BACKSPACE
						when x"78" => keyMatrix(7)(6) <= release; -- F11 (SELECT)
						when x"5a" => keyMatrix(7)(7) <= release; -- ENTER
						-- 8
						when x"29" => keyMatrix(8)(0) <= release; -- SPACE
						-- when x"6c" => keyMatrix(8)(1) <= release; -- HOME
						-- when x"70" => keyMatrix(8)(2) <= release; -- INS
						-- when x"71" => keyMatrix(8)(3) <= release; -- DEL
						-- when x"6B" => keyMatrix(8)(4) <= release; -- LEFT ARROW
						-- when x"75" => keyMatrix(8)(5) <= release; -- UP ARROW
						-- when x"72" => keyMatrix(8)(6) <= release; -- DOWN ARROW
						-- when x"74" => keyMatrix(8)(7) <= release; -- RIGH ARROW
						when others =>null; 
					end case;
				else 
					case scancode is
					   when x"11" => keyMatrix(6)(2) <= release; -- RIGHT ALT (GRAPH)
					   when x"7b" => keyMatrix(7)(4) <= release; -- pause/break (STOP)
						when x"6c" => keyMatrix(8)(1) <= release; -- HOME
						when x"70" => keyMatrix(8)(2) <= release; -- INS
						when x"71" => keyMatrix(8)(3) <= release; -- DEL
						when x"6B" => keyMatrix(8)(4) <= release; -- LEFT ARROW
						when x"75" => keyMatrix(8)(5) <= release; -- UP ARROW
						when x"72" => keyMatrix(8)(6) <= release; -- DOWN ARROW
						when x"74" => keyMatrix(8)(7) <= release; -- RIGH ARROW
						when others =>null; 
					end case;
				end if;
			end if;
		end if;
	end process;
end; 
