--
-- Z80 compatible microprocessor core
--
-- Version : 0232
--
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
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
--	http://www.opencores.org/cvsweb.shtml/t80/
--
-- Limitations :
--	No extra I/O waitstate
--	GB instruction set is incomplete
--	Not all instruction timing are correct
--
-- File history :
--
--	0208 : First complete release
--
--	0210 : Fixed wait and halt
--
--	0211 : Fixed Refresh addition and IM 1
--
--	0214 : Fixed mostly flags, only the block instructions now fail the zex regression test
--
--	0232 : Removed refresh address output for Mode > 1 and added DJNZ M1_n fix by Mike Johnson

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.T80_Pack.all;

entity T80 is
	generic(
		Mode : integer := 0	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
	);
	port(
		RESET_n		: in std_logic;
		CLK_n		: in std_logic;
		WAIT_n		: in std_logic;
		INT_n		: in std_logic;
		NMI_n		: in std_logic;
		BUSRQ_n		: in std_logic;
		M1_n		: out std_logic;
		IORQ		: out std_logic;
		Write		: out std_logic;
		RFSH_n		: out std_logic;
		HALT_n		: out std_logic;
		BUSAK_n		: out std_logic;
		A			: out std_logic_vector(15 downto 0);
		DInst		: in std_logic_vector(7 downto 0);
		DI			: in std_logic_vector(7 downto 0);
		DO			: out std_logic_vector(7 downto 0);
		MC			: out std_logic_vector(2 downto 0);
		TS			: out std_logic_vector(2 downto 0);
		False_M1	: out std_logic;
		IntCycle_n	: out std_logic
	);
end T80;

architecture rtl of T80 is

	constant Flag_C : integer := 0;
	constant Flag_N : integer := 1;
	constant Flag_P : integer := 2;
	constant Flag_X : integer := 3;
	constant Flag_H : integer := 4;
	constant Flag_Y : integer := 5;
	constant Flag_Z : integer := 6;
	constant Flag_S : integer := 7;

	-- Registers
	signal ACC, F, B, C, D, E, H, L : std_logic_vector(7 downto 0);
	signal Ap, Fp, Bp, Cp, Dp, Ep, Hp, Lp : std_logic_vector(7 downto 0);
	signal I				: std_logic_vector(7 downto 0);
	signal R				: unsigned(7 downto 0);
	signal IX, IY			: std_logic_vector(15 downto 0);
	signal SP, PC			: unsigned(15 downto 0);

	-- Help Registers
	signal TmpAddr			: std_logic_vector(15 downto 0);	-- Temporary address register
	signal IR				: std_logic_vector(7 downto 0);		-- Instruction register
	signal ISet				: std_logic_vector(1 downto 0);		-- Instruction set selector

	signal TState			: unsigned(2 downto 0);
	signal MCycle			: std_logic_vector(2 downto 0);
	signal BReq_FF			: std_logic;
	signal IntE_FF1			: std_logic;
	signal IntE_FF2			: std_logic;
	signal Halt_FF			: std_logic;
	signal NMI_s			: std_logic;
	signal INT_s			: std_logic;
	signal IStatus			: std_logic_vector(1 downto 0);

	signal DI_Reg			: std_logic_vector(7 downto 0);
	signal T_Res			: std_logic;
	signal XY_State			: std_logic_vector(1 downto 0);
	signal XY_Fetch			: std_logic;
	signal NextIs_XY_Fetch	: std_logic;
	signal XY_Ind			: std_logic;

	-- ALU signals
	signal BusB				: std_logic_vector(7 downto 0);
	signal BusA				: std_logic_vector(7 downto 0);
	signal ALU_Q			: std_logic_vector(7 downto 0);
	signal F_Out			: std_logic_vector(7 downto 0);
	signal F_Save			: std_logic_vector(7 downto 0);

	-- Registered micro code outputs
	signal Read_To_Reg_r	: std_logic_vector(4 downto 0);
	signal Arith16_r		: std_logic;
	signal ALU_Op_r			: std_logic_vector(3 downto 0);
	signal AALU_OP_r		: std_logic_vector(2 downto 0);
	signal Rot_Op_r			: std_logic;
	signal Bit_Op_r			: std_logic_vector(1 downto 0);
	signal Save_ALU_r		: std_logic;
	signal PreserveC_r		: std_logic;
	signal MCycles			: std_logic_vector(2 downto 0);

	-- Micro code outputs
	signal MCycles_d		: std_logic_vector(2 downto 0);
	signal TStates			: std_logic_vector(2 downto 0);
	signal IntCycle			: std_logic;
	signal NMICycle			: std_logic;
	signal Inc_PC			: std_logic;
	signal Inc_WZ			: std_logic;
	signal IncDec_16		: std_logic_vector(3 downto 0);
	signal Prefix			: std_logic_vector(1 downto 0);
	signal Read_To_Acc		: std_logic;
	signal Read_To_Reg		: std_logic;
	signal Set_BusB_To		: std_logic_vector(3 downto 0);
	signal Set_BusA_To		: std_logic_vector(3 downto 0);
	signal ALU_Op			: std_logic_vector(3 downto 0);
	signal Rot_Op			: std_logic;
	signal Bit_Op			: std_logic_vector(1 downto 0);
	signal Save_ALU			: std_logic;
	signal PreserveC		: std_logic;
	signal Arith16			: std_logic;
	signal Set_Addr_To		: AddressOutput;
	signal Jump				: std_logic;
	signal JumpE			: std_logic;
	signal JumpXY			: std_logic;
	signal Call				: std_logic;
	signal RstP				: std_logic;
	signal LDZ				: std_logic;
	signal LDW				: std_logic;
	signal LDSPHL			: std_logic;
	signal Special_LD		: std_logic_vector(2 downto 0);
	signal ExchangeDH		: std_logic;
	signal ExchangeRp		: std_logic;
	signal ExchangeAF		: std_logic;
	signal ExchangeRS		: std_logic;
	signal I_DJNZ			: std_logic;
	signal I_CPL			: std_logic;
	signal I_CCF			: std_logic;
	signal I_SCF			: std_logic;
	signal I_RETN			: std_logic;
	signal I_BT				: std_logic;
	signal I_BC				: std_logic;
	signal I_BTR			: std_logic;
	signal I_RLD			: std_logic;
	signal I_RRD			: std_logic;
	signal I_INRC			: std_logic;
	signal SetDI			: std_logic;
	signal SetEI			: std_logic;
	signal IMode			: std_logic_vector(1 downto 0);
	signal Halt				: std_logic;

begin

	mcode : T80_MCode
		generic map(
			Mode => Mode)
		port map(
			IR => IR,
			ISet => ISet,
			MCycle => MCycle,
			F => F,
			NMICycle => NMICycle,
			IntCycle => IntCycle,
			MCycles => MCycles_d,
			TStates => TStates,
			Prefix => Prefix,
			Inc_PC => Inc_PC,
			Inc_WZ => Inc_WZ,
			IncDec_16 => IncDec_16,
			Read_To_Acc => Read_To_Acc,
			Read_To_Reg => Read_To_Reg,
			Set_BusB_To => Set_BusB_To,
			Set_BusA_To => Set_BusA_To,
			ALU_Op => ALU_Op,
			Rot_Op => Rot_Op,
			Bit_Op => Bit_Op,
			Save_ALU => Save_ALU,
			PreserveC => PreserveC,
			Arith16 => Arith16,
			Set_Addr_To => Set_Addr_To,
			IORQ => IORQ,
			Jump => Jump,
			JumpE => JumpE,
			JumpXY => JumpXY,
			Call => Call,
			RstP => RstP,
			LDZ => LDZ,
			LDW => LDW,
			LDSPHL => LDSPHL,
			Special_LD => Special_LD,
			ExchangeDH => ExchangeDH,
			ExchangeRp => ExchangeRp,
			ExchangeAF => ExchangeAF,
			ExchangeRS => ExchangeRS,
			I_DJNZ => I_DJNZ,
			I_CPL => I_CPL,
			I_CCF => I_CCF,
			I_SCF => I_SCF,
			I_RETN => I_RETN,
			I_BT => I_BT,
			I_BC => I_BC,
			I_BTR => I_BTR,
			I_RLD => I_RLD,
			I_RRD => I_RRD,
			I_INRC => I_INRC,
			SetDI => SetDI,
			SetEI => SetEI,
			IMode => IMode,
			Halt => Halt,
			Write => Write);

	alu : T80_ALU
		port map(
			Arith16 => Arith16_r,
			ALU_Op => ALU_Op_r,
			Rot_Op => Rot_Op_r,
			Bit_Op => Bit_Op_r,
			IR => IR,
			ISet => ISet,
			BusA => BusA,
			BusB => BusB,
			F_In => F,
			Q => ALU_Q,
			F_Out => F_Out,
			F_Save => F_Save);

	T_Res <= '1' when (TState = unsigned(TStates) and XY_Fetch = '0') or
					(XY_Fetch = '1' and TState = 4) else '0'; -- Incorrect, should be 8 !!!!!!!!!!!!!!!!

	NextIs_XY_Fetch <= '1' when XY_State /= "00" and XY_Ind = '0' and ((Set_Addr_To = aXY and IR /= "11001011") or
							(MCycle = "001" and IR = "11001011") or
							(MCycle = "001" and IR = "00110110")) else '0';

	process (RESET_n, CLK_n)

		variable ID16		: signed(15 downto 0);
		variable Save_Mux	: std_logic_vector(7 downto 0);

	begin
		if RESET_n = '0' then
			PC <= (others => '0');  -- Program Counter
			A <= (others => '0');
			IR <= "00000000";
			ISet <= "00";
			XY_State <= "00";
			IStatus <= "00";

			ACC <= (others => '1');
			F <= (others => '1');
			I <= (others => '0');
			R <= (others => '0');
			SP <= (others => '1');

			Read_To_Reg_r <= "00000";
			Arith16_r <= '0';
			ALU_Op_r <= "0000";
			Rot_Op_r <= '0';
			Bit_Op_r <= "00";
			Save_ALU_r <= '0';
			PreserveC_r <= '0';
			AALU_OP_r <= "000";
			XY_Ind <= '0';

		elsif CLK_n'event and CLK_n = '1' then

			Arith16_r <= '0';
			ALU_Op_r <= "0000";
			Rot_Op_r <= '0';
			Bit_Op_r <= "00";
			Save_ALU_r <= '0';
			PreserveC_r <= '0';
			AALU_OP_r <= "000";
			Read_To_Reg_r <= "00000";

			MCycles <= MCycles_d;

			if IMode /= "11" then
				IStatus <= IMode;
			end if;

			if MCycle  = "001" and TState(2) = '0' and XY_Fetch = '0' then
			-- MCycle = 1 and TState = 1, 2, or 3

				if TState = 2 and Wait_n = '1' then
					if Mode < 2 then
						A(7 downto 0) <= std_logic_vector(R);
						A(15 downto 8) <= I;
						R(6 downto 0) <= R(6 downto 0) + 1;
					end if;

					if Jump = '0' and Call = '0' and NMICycle = '0' and IntCycle = '0' and not (Halt_FF = '1' or Halt = '1') then
						PC <= PC + 1;
					end if;

					if IntCycle = '1' and IStatus = "01" then
						IR <= "11111111";
					elsif Halt_FF = '1' or (IntCycle = '1' and IStatus = "10") or NMICycle = '1' then
						IR <= "00000000";
					else
						IR <= DInst;
					end if;

					ISet <= "00";
					if Prefix /= "00" then
						if Prefix = "11" then
							if IR(5) = '1' then
								XY_State <= "10";
							else
								XY_State <= "01";
							end if;
						else
							if Prefix = "10" then
								XY_State <= "00";
								XY_Ind <= '0';
							end if;
							ISet <= Prefix;
						end if;
					else
						XY_State <= "00";
						XY_Ind <= '0';
					end if;
				end if;

			else
			-- either (MCycle > 1) OR (MCycle = 1 AND TState > 3)

				if XY_Fetch = '1' then
					XY_Ind <= '1';
				end if;

				if T_Res = '1' then
					if Jump = '1' then
						A(15 downto 8) <= DI_Reg;
						A(7 downto 0) <= TmpAddr(7 downto 0);
						PC(15 downto 8) <= unsigned(DI_Reg);
						PC(7 downto 0) <= unsigned(TmpAddr(7 downto 0));
					elsif JumpXY = '1' then
						case XY_State is
						when "01" =>
							A <= IX;
							PC <= unsigned(IX);
						when "10" =>
							A <= IY;
							PC <= unsigned(IY);
						when others =>
							A(15 downto 8) <= H;
							A(7 downto 0) <= L;
							PC(15 downto 8) <= unsigned(H);
							PC(7 downto 0) <= unsigned(L);
						end case;
					elsif Call = '1' or RstP = '1' then
						A <= TmpAddr;
						PC <= unsigned(TmpAddr);
					elsif MCycle = MCycles and NMICycle = '1' then
						A <= "0000000001100110";
						PC <= "0000000001100110";
					elsif MCycle = MCycles and IntCycle = '1' and IStatus = "10" then
						A(15 downto 8) <= I;
						A(7 downto 1) <= TmpAddr(7 downto 1);
						A(0) <= '0';
						PC(15 downto 8) <= unsigned(I);
						PC(7 downto 0) <= unsigned(TmpAddr(7 downto 0));
					else
						case Set_Addr_To is
						when aXY =>
							if XY_State = "00" then
								A(15 downto 8) <= H;
								A(7 downto 0) <= L;
							else
								if NextIs_XY_Fetch = '1' then
									A <= std_logic_vector(PC);
								else
									A <= TmpAddr;
								end if;
							end if;
						when aIOA =>
							A(15 downto 8) <= ACC;
							A(7 downto 0) <= DI_Reg;
						when aSP =>
							A <= std_logic_vector(SP);
						when aBC =>
							A(15 downto 8) <= B;
							A(7 downto 0) <= C;
						when aDE =>
							A(15 downto 8) <= D;
							A(7 downto 0) <= E;
						when aZI =>
							if Inc_WZ = '1' then
								A <= std_logic_vector(unsigned(TmpAddr) + 1);
							else
								A(15 downto 8) <= DI_Reg;
								A(7 downto 0) <= TmpAddr(7 downto 0);
							end if;
						when aNone =>
							A <= std_logic_vector(PC);
						end case;
					end if;

					Arith16_r <= Arith16;
					ALU_Op_r <= ALU_Op;
					Rot_Op_r <= Rot_Op;
					Bit_Op_r <= Bit_Op;
					Save_ALU_r <= Save_ALU;
					PreserveC_r <= PreserveC;
					if Save_ALU = '1' then
						if Rot_Op = '0' and Bit_Op = "00" then
							if ALU_Op(3) = '1' then
								AALU_OP_r <= ALU_Op(2 downto 0);
							else
								AALU_OP_r <= IR(5 downto 3);
							end if;
						end if;
					end if;

					if I_CPL = '1' then
						-- CPL
						ACC <= not ACC;
						F(Flag_Y) <= not ACC(5);
						F(Flag_H) <= '1';
						F(Flag_X) <= not ACC(3);
						F(Flag_N) <= '1';
					end if;
					if I_CCF = '1' then
						-- CCF
						F(Flag_C) <= not F(Flag_C);
						F(Flag_Y) <= ACC(5);
						F(Flag_H) <= F(Flag_C);
						F(Flag_X) <= ACC(3);
						F(Flag_N) <= '0';
					end if;
					if I_SCF = '1' then
						-- SCF
						F(Flag_C) <= '1';
						F(Flag_Y) <= ACC(5);
						F(Flag_H) <= '0';
						F(Flag_X) <= ACC(3);
						F(Flag_N) <= '0';
					end if;
				end if;

				if TState = 2 and Wait_n = '1' then
					if JumpE = '1' then
						PC <= unsigned(signed(PC) + signed(DI_Reg));
					elsif Inc_PC = '1' or XY_Fetch = '1' then
						PC <= PC + 1;
					end if;
					if I_BTR = '1' then
						PC <= PC - 2;
					end if;
					if RstP = '1' then
						TmpAddr <= (others =>'0');
						TmpAddr(5 downto 3) <= IR(5 downto 3);
					end if;
				end if;
				if TState = 3 and XY_Fetch = '1' then
					if XY_State = "01" then
						TmpAddr <= std_logic_vector(signed(IX) + signed(DI_Reg));
					end if;
					if XY_State = "10" then
						TmpAddr <= std_logic_vector(signed(IY) + signed(DI_Reg));
					end if;
				end if;

				if (TState = 2 and Wait_n = '1') or (TState = 4 and MCycle = "001") then
					if IncDec_16 = "1100" then
						ID16(15 downto 8) := signed(B);
						ID16(7 downto 0) := signed(C);
						ID16 := ID16 - 1;
						B <= std_logic_vector(ID16(15 downto 8));
						C <= std_logic_vector(ID16(7 downto 0));
					end if;
					if IncDec_16 = "1101" then
						ID16(15 downto 8) := signed(D);
						ID16(7 downto 0) := signed(E);
						ID16 := ID16 - 1;
						D <= std_logic_vector(ID16(15 downto 8));
						E <= std_logic_vector(ID16(7 downto 0));
					end if;
					if IncDec_16 = "1110" then
						case XY_State is
						when "01" =>
							IX <= std_logic_vector(unsigned(IX) - 1);
						when "10" =>
							IY <= std_logic_vector(unsigned(IY) - 1);
						when others =>
							ID16(15 downto 8) := signed(H);
							ID16(7 downto 0) := signed(L);
							ID16 := ID16 - 1;
							H <= std_logic_vector(ID16(15 downto 8));
							L <= std_logic_vector(ID16(7 downto 0));
						end case;
					end if;
					if IncDec_16 = "1111" then
						SP <= SP - 1;
					end if;
					if IncDec_16 = "0100" then
						ID16(15 downto 8) := signed(B);
						ID16(7 downto 0) := signed(C);
						ID16 := ID16 + 1;
						B <= std_logic_vector(ID16(15 downto 8));
						C <= std_logic_vector(ID16(7 downto 0));
					end if;
					if IncDec_16 = "0101" then
						ID16(15 downto 8) := signed(D);
						ID16(7 downto 0) := signed(E);
						ID16 := ID16 + 1;
						D <= std_logic_vector(ID16(15 downto 8));
						E <= std_logic_vector(ID16(7 downto 0));
					end if;
					if IncDec_16 = "0110" then
						case XY_State is
						when "01" =>
							IX <= std_logic_vector(unsigned(IX) + 1);
						when "10" =>
							IY <= std_logic_vector(unsigned(IY) + 1);
						when others =>
							ID16(15 downto 8) := signed(H);
							ID16(7 downto 0) := signed(L);
							ID16 := ID16 + 1;
							H <= std_logic_vector(ID16(15 downto 8));
							L <= std_logic_vector(ID16(7 downto 0));
						end case;
					end if;
					if IncDec_16 = "0111" then
						SP <= SP + 1;
					end if;
				end if;

				if LDSPHL = '1' then
					case XY_State is
					when "01" =>
						SP <= unsigned(IX);
					when "10" =>
						SP <= unsigned(IY);
					when others =>
						SP(15 downto 8) <= unsigned(H);
						SP(7 downto 0) <= unsigned(L);
					end case;
				end if;
				if ExchangeDH = '1' then
					D <= H;
					E <= L;
					H <= D;
					L <= E;
				end if;
				if ExchangeAF = '1' then
					Ap <= ACC;
					ACC <= Ap;
					Fp <= F;
					F <= Fp;
				end if;
				if ExchangeRS = '1' then
					Bp <= B;
					B <= Bp;
					Cp <= C;
					C <= Cp;
					Dp <= D;
					D <= Dp;
					Ep <= E;
					E <= Ep;
					Lp <= L;
					L <= Lp;
					Hp <= H;
					H <= Hp;
				end if;
			end if;

			if TState = 3 then
				if LDZ = '1' then
					TmpAddr(7 downto 0) <= DI_Reg;
				end if;
				if LDW = '1' then
					TmpAddr(15 downto 8) <= DI_Reg;
				end if;

				if Special_LD(2) = '1' then
					case Special_LD(1 downto 0) is
					when "00" =>
						ACC <= I;
						F(Flag_P) <= IntE_FF2;
					when "01" =>
						ACC <= std_logic_vector(R);
						F(Flag_P) <= IntE_FF2;
					when "10" =>
						I <= ACC;
					when others =>
						R <= unsigned(ACC);
					end case;
				end if;
			end if;

			if (I_DJNZ = '0' and Save_ALU_r = '1') or Bit_Op_r = "01" then
				F(7 downto 1) <= (F(7 downto 1) and not F_Save(7 downto 1)) or
					(F_Out(7 downto 1) and F_Save(7 downto 1));
				if PreserveC_r = '0' and F_Save(0) = '1' then
					F(Flag_C) <= F_Out(0);
				end if;
			end if;
			if T_Res = '1' and I_INRC = '1' then
				F(Flag_H) <= '0';
				F(Flag_N) <= '0';
				if DI_Reg(7 downto 0) = "00000000" then
					F(Flag_Z) <= '1';
				else
					F(Flag_Z) <= '0';
				end if;
				F(Flag_S) <= DI_Reg(7);
				F(Flag_P) <= not (DI_Reg(0) xor DI_Reg(1) xor DI_Reg(2) xor DI_Reg(3) xor
					DI_Reg(4) xor DI_Reg(5) xor DI_Reg(6) xor DI_Reg(7));
			end if;

			if TState = 1 then
				DO <= BusB;
				if I_RLD = '1' then
					DO(3 downto 0) <= BusA(3 downto 0);
					DO(7 downto 4) <= BusB(3 downto 0);
				end if;
				if I_RRD = '1' then
					DO(3 downto 0) <= BusB(7 downto 4);
					DO(7 downto 4) <= BusA(3 downto 0);
				end if;
			end if;

			if T_Res = '1' then
				Read_To_Reg_r(3 downto 0) <= Set_BusA_To;
				Read_To_Reg_r(4) <= Read_To_Reg;
				if Read_To_Acc = '1' then
					Read_To_Reg_r(3 downto 0) <= "0111";
					Read_To_Reg_r(4) <= '1';
				end if;
			end if;

			if TState = 1 and I_BT = '1' then
				F(Flag_X) <= ALU_Q(3);
				F(Flag_Y) <= ALU_Q(1);
				F(Flag_H) <= '0';
				F(Flag_N) <= '0';
			end if;
			if I_BC = '1' or I_BT = '1' then
				if B = "00000000" and C = "00000000" then
					F(Flag_P) <= '0';
				else
					F(Flag_P) <= '1';
				end if;
			end if;

			if (TState = 1 and Save_ALU_r = '0') or
				(Save_ALU_r = '1' and AALU_OP_r /= "111") then
				if ExchangeRp = '1' then
					Save_Mux := BusB;
				elsif Save_ALU_r = '0' then
					Save_Mux := DI_Reg;
				else
					Save_Mux := ALU_Q;
				end if;

				case Read_To_Reg_r is
				when "10111" =>
					ACC <= Save_Mux;
				when "10000" =>
					B <= Save_Mux;
				when "10001" =>
					C <= Save_Mux;
				when "10010" =>
					D <= Save_Mux;
				when "10011" =>
					E <= Save_Mux;
				when "10100" =>
					if XY_Ind = '1' then
						H <= Save_Mux;
					else
						case XY_State is
						when "01" =>
							IX(15 downto 8) <= Save_Mux;
						when "10" =>
							IY(15 downto 8) <= Save_Mux;
						when others =>
							H <= Save_Mux;
						end case;
					end if;
				when "10101" =>
					if XY_Ind = '1' then
						L <= Save_Mux;
					else
						case XY_State is
						when "01" =>
							IX(7 downto 0) <= Save_Mux;
						when "10" =>
							IY(7 downto 0) <= Save_Mux;
						when others =>
							L <= Save_Mux;
						end case;
					end if;
				when "10110" =>
					DO <= Save_Mux;
				when "11000" =>
					SP(7 downto 0) <= unsigned(Save_Mux);
				when "11001" =>
					SP(15 downto 8) <= unsigned(Save_Mux);
				when "11011" =>
					F <= Save_Mux;
				when others =>
				end case;
			end if;

		end if;

	end process;

---------------------------------------------------------------------------
--
-- Buses
--
---------------------------------------------------------------------------
	process (CLK_n)
	begin
		if CLK_n'event and CLK_n = '1' then
			case Set_BusB_To is
			when "0111" =>
				BusB <= ACC;
			when "0000" =>
				BusB <= B;
			when "0001" =>
				BusB <= C;
			when "0010" =>
				BusB <= D;
			when "0011" =>
				BusB <= E;
			when "0100" =>
				if XY_Ind = '1' then
					BusB <= H;
				else
					case XY_State is
					when "01" =>
						BusB <= IX(15 downto 8);
					when "10" =>
						BusB <= IY(15 downto 8);
					when others =>
						BusB <= H;
					end case;
				end if;
			when "0101" =>
				if XY_Ind = '1' then
					BusB <= L;
				else
					case XY_State is
					when "01" =>
						BusB <= IX(7 downto 0);
					when "10" =>
						BusB <= IY(7 downto 0);
					when others =>
						BusB <= L;
					end case;
				end if;
			when "0110" =>
				BusB <= DI_Reg;
			when "1000" =>
				BusB <= std_logic_vector(SP(7 downto 0));
			when "1001" =>
				BusB <= std_logic_vector(SP(15 downto 8));
			when "1010" =>
				BusB <= "00000001";
			when "1011" =>
				BusB <= F;
			when "1100" =>
				BusB <= std_logic_vector(PC(7 downto 0));
			when "1101" =>
				BusB <= std_logic_vector(PC(15 downto 8));
			when "1110" =>
				BusB <= "00000000";
			when others =>
				BusB <= "--------";
			end case;

			case Set_BusA_To is
			when "0111" =>
				BusA <= ACC;
			when "0000" =>
				BusA <= B;
			when "0001" =>
				BusA <= C;
			when "0010" =>
				BusA <= D;
			when "0011" =>
				BusA <= E;
			when "0100" =>
				if XY_Ind = '1' then
					BusA <= H;
				else
					case XY_State is
					when "01" =>
						BusA <= IX(15 downto 8);
					when "10" =>
						BusA <= IY(15 downto 8);
					when others =>
						BusA <= H;
					end case;
				end if;
			when "0101" =>
				if XY_Ind = '1' then
					BusA <= L;
				else
					case XY_State is
					when "01" =>
						BusA <= IX(7 downto 0);
					when "10" =>
						BusA <= IY(7 downto 0);
					when others =>
						BusA <= L;
					end case;
				end if;
			when "0110" =>
				BusA <= DI_Reg;
			when "1000" =>
				BusA <= std_logic_vector(SP(7 downto 0));
			when "1001" =>
				BusA <= std_logic_vector(SP(15 downto 8));
			when "1010" =>
				BusA <= "00000000";
			when others =>
				BusB <= "--------";
			end case;

		end if;
	end process;

---------------------------------------------------------------------------
--
-- Generate external control signals
--
---------------------------------------------------------------------------

	process (RESET_n,CLK_n)
	begin
		if RESET_n = '0' then
			RFSH_n <= '1';
		elsif CLK_n'event and CLK_n = '1' then
			if MCycle = "001" and ((TState = 2  and Wait_n = '1') or TState = 3) then
				RFSH_n <= '0';
			else
				RFSH_n <= '1';
			end if;
		end if;
	end process;

	MC <= std_logic_vector(MCycle);
	TS <= std_logic_vector(TState);
	DI_Reg <= DI;
	HALT_n <= not Halt_FF;
	False_M1 <= XY_Fetch;
	IntCycle_n <= not IntCycle;

	process (RESET_n,CLK_n)
	begin
		if RESET_n = '0' then
			M1_n <= '0';
		elsif CLK_n'event and CLK_n = '1' then
			if T_Res = '1' and (MCycle = MCycles or (MCycle = "010" and I_DJNZ = '1' and B = "00000000")) then
				M1_n <= '0';
			end if;
			if MCycle = "001" and TState = 2 and Wait_n = '1' then
				M1_n <= '1';
			end if;
		end if;
	end process;

-------------------------------------------------------------------------
--
-- Syncronise inputs
--
-------------------------------------------------------------------------
	process (RESET_n, CLK_n)
		variable OldNMI_n : std_logic;
	begin
		if RESET_n = '0' then
			INT_s <= '0';
			NMI_s <= '0';
			OldNMI_n := '0';
		elsif CLK_n'event and CLK_n = '1' then
			INT_s <= not INT_n;
			if NMICycle = '1' then
				NMI_s <= '0';
			elsif NMI_n = '0' and OldNMI_n = '1' then
				NMI_s <= '1';
			end if;
			OldNMI_n := NMI_n;
		end if;
	end process;

-------------------------------------------------------------------------
--
-- Main state machine
--
-------------------------------------------------------------------------
	process (RESET_n, CLK_n)
	begin
		if RESET_n = '0' then
			MCycle <= "001";
			TState <= "000";
			BReq_FF <= '0';
			Halt_FF <= '0';
			BUSAK_n <= '1';
			NMICycle <= '0';
			IntCycle <= '0';
			XY_Fetch <= '0';
			IntE_FF1 <= '0';
			IntE_FF2 <= '0';
		elsif CLK_n'event and CLK_n = '1' then   -- CLK_n is the clock signal
			if TState = 2 then
				if SetEI = '1' then
					IntE_FF1 <= '1';
					IntE_FF2 <= '1';
				end if;
				if I_RETN = '1' then
					IntE_FF1 <= IntE_FF2;
				end if;
			end if;
			if TState = 3 then
				if SetDI = '1' then
					IntE_FF1 <= '0';
					IntE_FF2 <= '0';
				end if;
			end if;
			if IntCycle = '1' or NMICycle = '1' then
				Halt_FF <= '0';
			end if;
			if BReq_FF = '1' then
				if BUSRQ_n = '1' then
					BReq_FF <= '0';
					BUSAK_n <= '1';
				end if;
			else
				if TState = 2 and Wait_n = '0' then
				elsif T_Res = '1' then
					if Halt = '1' then
						Halt_FF <= '1';
					end if;
					if BUSRQ_n = '0' then
						BReq_FF <= '1';
						BUSAK_n <= '0';
					else
						TState <= "001";
						XY_Fetch <= '0';
						if NextIs_XY_Fetch = '1' then
							XY_Fetch <= '1';
						elsif MCycle = MCycles or (MCycle = "010" and I_DJNZ = '1' and B = "00000000") then
							MCycle <= "001";
							IntCycle <= '0';
							NMICycle <= '0';
							if NMI_s = '1' and Prefix = "00" then
								NMICycle <= '1';
								IntE_FF1 <= '0';
							elsif (IntE_FF1 = '1' and INT_s = '1') and Prefix = "00" and SetEI = '0' then
								IntCycle <= '1';
								IntE_FF1 <= '0';
								IntE_FF2 <= '0';
							end if;
						else
							MCycle <= std_logic_vector(unsigned(MCycle) + 1);
						end if;
					end if;
				else
					TState <= TState + 1;
				end if;
			end if;
		end if;
	end process;

end;
