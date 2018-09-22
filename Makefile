#
# The primary target will use both assemblers and compare the results
# but if you just use one assembler change the target to
# either clock.bin or clock.ihx
#

default:	compare

compare:	clock.bin clock.ibn clock.zbn
		cmp clock.bin clock.zbn

clock.bin:	clock.asm
		asm48 -t -s clock.sym clock.asm

clock.hex:	clock.asm
		asm48 -f hex clock.asm

clock.ihx:	clock.asm
		as8048 -l -o clock.asm
		aslink -i -o clock.rel

clock.zbn:	clock.ihx
		hex2bin -e zbn -p 00 clock.ihx

clock.ibn:	clock.ihx
		hex2bin -e ibn clock.ihx

clean:
		rm -f clock.sym clock.lst clock.rel clock.hlr clock.bin clock.ihx clock.ibn clock.fbn
