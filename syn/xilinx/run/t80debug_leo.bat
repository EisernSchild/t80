cd ..\out

hex2rom -b ..\..\..\sw\sine.bin MonZ80 11b8s > ..\src\MonZ80_Sine_leo.vhd

spectrum -file ..\bin\t80debug.tcl
move exemplar.log ..\log\t80debug_leo.srp

cd ..\run

t80debug t80debug_leo.edf xc2s200-pq208-5
