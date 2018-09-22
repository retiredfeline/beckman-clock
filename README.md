# Beckman neon display clock firmware

Firmware for 8048 microcontroller driving a Beckman neon display clock. (https://hackaday.io/project/160958-restoring-a-beckman-neon-display-clock)

## Getting Started

You can clone a copy of the assembler code, Makefile and these instructions from GitHub.

### Prerequisites

You will need a copy of asm48 (http://asm48.sourceforge.net/) or asxxxx (http://shop-pdp.net/ashtml/asxxxx.htm). My development environment was Linux. Those tools may work under other operating systems.

If your EPROM programmer doesn't take Intel hex files, you will need the hex2bin utility (https://sourceforge.net/projects/hex2bin). This is also used if you use two assemblers like me to compare the outputs.

The S48 8048 simulator is useful to simulate the system under FreeDOS. There isn't a canonical site for S48, but it is in many Internet archives, do a search.

### Installing

If you have only one assembler, edit the Makefile to specify the appropriate default target, then run "make" to generate the binary firmware.

## Running the tests

### Break down into end to end tests

### And coding style tests

## Deployment

Burn the firmware to an (E)EPROM and insert in system. Actually, unless you have the exact hardware I have, this isn't so useful to you. But please feel free to reuse the code and concepts anyhow you like for your projects. Acknowledgement would be nice.

## Built With

## Contributing

## Versioning

First release October 2018

## Authors

* **Ken Yap** - heavily modified code from https://www.wraith.sf.ca.us/8048/

## License

I hereby place this code in the public domain. 

## Acknowledgments

* Steven Bjork (8048 code for clock)
* Alan Baldwin (asxxxx cross assemblers)
* Dave Ho (asm48 cross assembler)
* William Luitje (S48 8048 simulator)
* Arnim Läuger (MCS-48 datasheets) https://devsaurus.github.io/mcs-48/mcs-48.pdf
