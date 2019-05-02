
# T80(c) core.
v0208 - v0247 Copyright (c) 2002 Daniel Wallner (jesus@opencores.org) www.opencores.org

v0300 - v0303 Copyright (c) 2005 MikeJ, Sean Riddle www.fpgaarcade.com

v0350 Copyright (c) 2018 Sorgelig https://github.com/MiSTer-devel
			  
 Redistribution and use in source and synthezised forms, with or without
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 Redistributions in synthesized form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 Neither the name of the author nor the names of other contributors may
 be used to endorse or promote products derived from this software without
 specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Please report bugs to the author, but before you do so, please
 make sure that this is not a derivative work and that
 you have the latest version of this file.

# Description
Configurable cpu core that supports Z80, 8080 and gameboy instruction sets. Z80 and 8080 compability have been proven by numerous implementations of old computer and arcade systems. It is used in the zxgate project, a zx81, zx spectrum, trs80 and Jupiter ACE clone project. And also in the FPGA Arcade project. A Z80 SoC debug system with ROM, RAM and two 16450 UARTs is included in the distribution. It is possible to run the NoICE debugger on this system. Batch files for runnning XST and Leonardo synthesis can be found in syn/xilinx/run/. Check these scripts to see how to use the included VHDL ROM generators. Before you can run the scripts you need to compile hex2rom and xrom or download binaries from here. You must also replace one of the hex files in sw/ or change the batch files to use another hex file. The z88dk C compiler can be used with T80. The "embedded" configuration can be used with the debug system without modifications. Browse source code here. Download latest tarball here. 

Thanks to MikeJ for some serious debugging and to the zxgate project members for invaluable Z80 information.

Latest version of this core (by Sorgelig) is used in various cores in the MiSTer project. 

# Features
- Technology independent
- Up to 35MHz clock in Spartan2 -5 using XST synthesis
- 10k gates and up to 100MHz in 0.18 CMOS
- Supports all undocumented Z80 instructions
- Supports all Z80 interrupt modes
- Correct R register behaviour
- Correct Z80 instruction timing
- Almost 100% correct behavior of the undocumented Z80 flags
- Both a synchronous (for implementation) and an asynchronous (for board level simulations) Z80 top level
- Only a synchronous 8080 top level

# Status

Version 0350 : Attempt to finish all undocumented features and provide accurate timings.

Copyright (c) 2018 Sorgelig

Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
(*) Currently only SCF and CCF instructions aren't passed X/Y flags check as correct implementation is still unclear.

# File history

- 0208 : First complete release
- 0210 : Fixed wait and halt
- 0211 : Fixed Refresh addition and IM 1
- 0214 : Fixed mostly flags, only the block instructions now fail the zex regression test
- 0232 : Removed refresh address output for Mode > 1 and added DJNZ M1_n fix by Mike Johnson
- 0235 : Added clock enable and IM 2 fix by Mike Johnson
- 0237 : Changed 8080 I/O address output, added IntE output
- 0238 : Fixed (IX/IY+d) timing and 16 bit ADC and SBC zero flag
- 0240 : Added interrupt ack fix by Mike Johnson, changed (IX/IY+d) timing and changed flags in GB mode
- 0242 : Added I/O wait, fixed refresh address, moved some registers to RAM
- 0247 : Fixed bus req/ack cycle
- 0300 : started tidyup.
- 0301 : parity flag is just parity for 8080, also overflow for Z80, by Sean Riddle
- 0303 : add undocumented DDCB and FDCB opcodes by TobiFlex 20.04.2010
- 0350 : Attempt to finish all undocumented features and provide accurate timings.

