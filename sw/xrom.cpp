//
// Xilinx VHDL ROM generator
//
// Version : 0220
//
// Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
//
// All rights reserved
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author, but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
// The latest version of this file can be found at:
//	http://www.opencores.org/cvsweb.shtml/t51/
//
// Limitations :
//	Requires stl to compile
//
// File history :
//
// 0220 : Initial release
//

#include <stdio.h>
#include <string>
#include <vector>
#include <iostream>

using namespace std;

#if !(defined(max)) && _MSC_VER
	// VC fix
	#define max __max
#endif

class File
{
public:
	explicit File(const char *fileName, const char *mode)
	{
		m_file = fopen(fileName, mode);
		if (m_file != NULL)
		{
			return;
		}
		string errorStr = "Error opening ";
		errorStr += fileName;
		errorStr += "\n";
		throw errorStr;
	}

	~File()
	{
		fclose(m_file);
	}

	FILE *Handle() { return m_file; };
private:
	FILE				*m_file;
};

int main (int argc, char *argv[])
{
	cerr << "Xilinx VHDL ROM generator by Daniel Wallner. Version 0220\n";

	try
	{
		unsigned long aWidth;
		unsigned long dWidth;
		unsigned long select = 0;
		char z = 0;

		if (argc < 4)
		{
			cerr << "\nUsage: xrom <entity name> <address bits> <data bits> <options>\n";
			cerr << "\nThe options can be:\n";
			cerr << "  -[deciamal number] = SelectRAM usage in 1/16 parts\n";
			cerr << "  -z = use tri-state buses\n";
			cerr << "\nExample:\n";
			cerr << "  xrom Test_ROM 13 8 -6\n\n";
			return -1;
		}

		int result;

		result = sscanf(argv[2], "%lu", &aWidth);
		if (result < 1)
		{
			throw "Error in address bits argument!\n";
		}

		result = sscanf(argv[3], "%lu", &dWidth);
		if (result < 1)
		{
			throw "Error in data bits argument!\n";
		}

		if (argc > 4)
		{
			result = sscanf(argv[4], "%c%lu", &z, &select);
			if (result < 1 || z != '-')
			{
				throw "Error in options!\n";
			}
			if (result < 2)
			{
				sscanf(argv[4], "%c%c", &z, &z);
				if (z != 'z')
				{
					throw "Error in options!\n";
				}
			}
		}

		if (argc > 5)
		{
			result = sscanf(argv[5], "%c%lu", &z, &select);
			if (result < 1 || z != '-')
			{
				throw "Error in options!\n";
			}
			if (result < 2)
			{
				sscanf(argv[5], "%c%c", &z, &z);
				if (z != 'z')
				{
					throw "Error in options!\n";
				}
			}
		}

		string	outFileName = argv[1];
		outFileName = outFileName + ".vhd";

		File	outFile(outFileName.c_str(), "wt");

		unsigned long selectIter = 0;
		unsigned long blockIter = 0;
		unsigned long bytes = (dWidth + 7) / 8;

		if (!select)
		{
			blockIter = ((1UL << aWidth) + 511) / 512;
		}
		else if (select == 16)
		{
			selectIter = ((1UL << aWidth) + 15) / 16;
		}
		else
		{
			blockIter = ((1UL << aWidth) * (16 - select) / 16 + 511) / 512;
			selectIter = ((1UL << aWidth) - blockIter * 512 + 15) / 16;
		}

		fprintf(outFile.Handle(), "-- This file was generated with xrom written by Daniel Wallner\n");
		fprintf(outFile.Handle(), "\nlibrary IEEE;");
		fprintf(outFile.Handle(), "\nuse IEEE.std_logic_1164.all;");
		fprintf(outFile.Handle(), "\nuse IEEE.numeric_std.all;");
		fprintf(outFile.Handle(), "\nlibrary UNISIM;");
		fprintf(outFile.Handle(), "\nuse UNISIM.vcomponents.all;");
		fprintf(outFile.Handle(), "\n\nentity %s is", argv[1]);
		fprintf(outFile.Handle(), "\n\tport(");
		fprintf(outFile.Handle(), "\n\t\tClk\t: in std_logic;");
		fprintf(outFile.Handle(), "\n\t\tA\t: in std_logic_vector(%d downto 0);", aWidth - 1);
		fprintf(outFile.Handle(), "\n\t\tD\t: out std_logic_vector(%d downto 0)", dWidth - 1);
		fprintf(outFile.Handle(), "\n\t);");
		fprintf(outFile.Handle(), "\nend %s;", outFileName.c_str());
		fprintf(outFile.Handle(), "\n\narchitecture rtl of %s is", argv[1]);

		fprintf(outFile.Handle(), "\n\tsignal zero : std_logic := '0';");
		fprintf(outFile.Handle(), "\n\tsignal DI : std_logic_vector(7 downto 0) := \"-------\";");
		if (selectIter > 0)
		{
			fprintf(outFile.Handle(), "\n\tsignal A_r: unsigned(A'range);");
		}
		if (selectIter > 1)
		{
			fprintf(outFile.Handle(), "\n\tsignal sEN : unsigned(%d downto 0);", selectIter - 1);
			fprintf(outFile.Handle(), "\n\ttype sRAMOut is array (0 to %d) of UNSIGNED(D'range);", selectIter - 1);
			fprintf(outFile.Handle(), "\n\tsignal sRAMOut : sRAMOut_a;");
			fprintf(outFile.Handle(), "\n\tsignal siA, siA2 : integer;");
		}
		if (blockIter > 1)
		{
			fprintf(outFile.Handle(), "\n\tsignal bEN : unsigned(%d downto 0);", blockIter - 1);
			fprintf(outFile.Handle(), "\n\ttype bRAMOut_a is array (0 to %d) of UNSIGNED(D'range);", blockIter - 1);
			fprintf(outFile.Handle(), "\n\tsignal bRAMOut : bRAMOut_a;");
			fprintf(outFile.Handle(), "\n\tsignal biA, biA_r : integer;");
			if (!selectIter)
			{
				fprintf(outFile.Handle(), "\n\tsignal A_r: UNSIGNED(A'left downto 9);");
			}
		}

		fprintf(outFile.Handle(), "\nbegin");

		if (selectIter > 0 || blockIter > 1)
		{
			fprintf(outFile.Handle(), "\n\tprocess (Clk)");
			fprintf(outFile.Handle(), "\n\tbegin");
			fprintf(outFile.Handle(), "\n\t\tif Clk'event and Clk = '1' then");
			if (!selectIter)
			{
				fprintf(outFile.Handle(), "\n\t\t\tA_r <= A(A'left downto 9);");
			}
			else
			{
				fprintf(outFile.Handle(), "\n\t\t\tA_r <= A;");
			}
			fprintf(outFile.Handle(), "\n\t\tend if;");
			fprintf(outFile.Handle(), "\n\tend process;");
		}

		if (selectIter == 1)
		{
			fprintf(outFile.Handle(), "\n\tU_ROM: RAMB4_S8\n\t\tport map (Zero, Zero, Clk, A(0), A(1), A(2), A(3), D(0));");
		}
		if (selectIter > 1)
		{
			fprintf(outFile.Handle(), "\n\n\tsiA <= to_integer(A(A'left downto 4));");
			fprintf(outFile.Handle(), "\n\tsiA_r <= TO_INTEGER(A_r(A'left downto 4));");
			fprintf(outFile.Handle(), "\n\n\tprocess (siA)\n\t\tvariable S:UNSIGNED(%d downto 0);", selectIter - 1);
			fprintf(outFile.Handle(), "\n\tbegin\n\t\tS := TO_UNSIGNED(1,%d);", selectIter);
			fprintf(outFile.Handle(), "\n\t\tfor I in 0 to %d loop", selectIter - 1);
			fprintf(outFile.Handle(), "\n\t\t\tif I < iA then\n\t\t\t\tS := SHL(S,\"1\");\n\t\t\tend if;\n\t\tend loop;");
			fprintf(outFile.Handle(), "\n\t\tbEN <= to_unsigned(S,%d);\n\tend process;", selectIter);
			fprintf(outFile.Handle(), "\n\n\tsG1_1: for I in 0 to %d generate", selectIter - 1);
			fprintf(outFile.Handle(), "\n\t\tU_ROM: RAMB4_S8\n\t\t\tport map (DI, sEN(I), Zero, Zero, Clk, A(3 downto 0), bRAMOut(I));");
			if (z)
			{
				fprintf(outFile.Handle(), "\n\t\tD <= bRAMOut(I) when iA2=I else (others=>'Z');");
			}
			fprintf(outFile.Handle(), "\n\tend generate;");
			if (!z)
			{
				fprintf(outFile.Handle(), "\n\n\tprocess (biA_r,RAMOut)\n\tbegin");
				fprintf(outFile.Handle(), "\n\t\tD <= sRAMOut(0);");
				fprintf(outFile.Handle(), "\n\t\tfor I in 1 to %d loop", selectIter - 1);
				fprintf(outFile.Handle(), "\n\t\t\tif siA_r=I then\n\t\t\t\tD <= sRAMOut(I);\n\t\t\tend if;");
				fprintf(outFile.Handle(), "\n\t\tend loop;\n\tend process;");
			}
		}
		if (blockIter == 1)
		{
			fprintf(outFile.Handle(), "\n\tU_ROM: RAMB4_S8\n\t\tport map (DI, One, Zero, Zero, Clk, A, D);");
		}
		if (blockIter > 1)
		{
			fprintf(outFile.Handle(), "\n\n\tbiA <= to_integer(A(A'left downto 9));");
			fprintf(outFile.Handle(), "\n\tbiA_r <= TO_INTEGER(A_r(A'left downto 9));");
			fprintf(outFile.Handle(), "\n\n\tprocess (biA)\n\t\tvariable S:UNSIGNED(%d downto 0);", blockIter - 1);
			fprintf(outFile.Handle(), "\n\tbegin\n\t\tS := TO_UNSIGNED(1,%d);", blockIter);
			fprintf(outFile.Handle(), "\n\t\tfor I in 0 to %d loop", blockIter - 1);
			fprintf(outFile.Handle(), "\n\t\t\tif I < iA then\n\t\t\t\tS := SHL(S,\"1\");\n\t\t\tend if;\n\t\tend loop;");
			fprintf(outFile.Handle(), "\n\t\tbEN <= to_unsigned(S,%d);\n\tend process;", blockIter);
			fprintf(outFile.Handle(), "\n\n\tbG1_1: for I in 0 to %d generate", blockIter - 1);
			fprintf(outFile.Handle(), "\n\t\tU_ROM: RAMB4_S8\n\t\t\tport map (DI, bEN(I), Zero, Zero, Clk, A(8 downto 0), bRAMOut(I));");
			if (z)
			{
				fprintf(outFile.Handle(), "\n\t\tD <= bRAMOut(I) when iA2=I else (others=>'Z');");
			}
			fprintf(outFile.Handle(), "\n\tend generate;");
			if (!z)
			{
				fprintf(outFile.Handle(), "\n\n\tprocess (biA_r,RAMOut)\n\tbegin");
				fprintf(outFile.Handle(), "\n\t\tD <= bRAMOut(0);");
				fprintf(outFile.Handle(), "\n\t\tfor I in 1 to %d loop", blockIter - 1);
				fprintf(outFile.Handle(), "\n\t\t\tif biA_r=I then\n\t\t\t\tD <= bRAMOut(I);\n\t\t\tend if;");
				fprintf(outFile.Handle(), "\n\t\tend loop;\n\tend process;");
			}
		}

		fprintf(outFile.Handle(), "\nend;\n");

		return 0;
	}
	catch (string error)
	{
		cerr << "Fatal: " << error;
	}
	catch (const char *error)
	{
		cerr << "Fatal: " << error;
	}
	return -1;
}
