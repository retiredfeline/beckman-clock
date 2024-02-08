#
# The primary target will use both assemblers and compare the results
# but if you just use one assembler change the target to
# either clock.bin or clock.hex
#

clock.hex:	clock.asm
		as8048 -l -o clock.asm
		aslink -i -o clock.rel

clock.bin:	clock.hex
		hex2bin -e bin clock.hex

clean:
		rm -f clock.sym clock.lst clock.rel clock.hlr clock.hex clock.bin
