#
# Uses GNU make for pattern substitution
#
FIRMWARE_END=0x3FF

default:	clock.rom

# assemble with as8048
%.hex:		%.asm
		as8048 -l -o $<
		aslink -i -o $(<:.asm=.rel)

# convert to bin, no longer needed in chain but available for testing
%.bin:		%.hex
		hex2bin -e bin $<

# generate rom from hex by filling with 0xFF then adding checksum at end
%.rom:		%.hex
		srec_cat $< -intel -crop 0 $(FIRMWARE_END) -fill 0xFF 0 $(FIRMWARE_END) -checksum-neg-b-e $(FIRMWARE_END) 1 1 -o $(<:.hex=.rom) -binary

clean:
		rm -f *.sym *.lst *.rel *.hlr *.hex
