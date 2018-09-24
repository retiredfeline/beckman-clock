;
; If debug == 1 then time constants are lowered for faster simulation
; Also port 2 low nybble is used to simulate buttons because
; s48 simulator has no commands to change interrupt and test input "pins"
;
.equ	debug,		0

; 8035/8748 7 segment scan output display clock

; 8035/8039/8048/8049/8748/8749 cpu design target

; 18 aug 2006 rev .0 7 segment scan output version
; 21 aug 2006 rev .1 4 or 6 digit scan select
; 06 sep 2006 rev .2 mess with mb0, mb1 
; 27 jun 2007 rev .3 set time code added
; 30 jun 2007        needed orl/anl in digit scan loop for buttons.
; 06 jul 2007 this code is public domain. gnu@wraith.sf.ca.us
;
; 2018 adapted code for my Beckman plasma clock containing 8035
; My modifications are in the public domain too, Ken Yap

;;;;;;;;;;;;;;;;;;;;;;;;;;

.ifdef	.__.CPU.		; if we are using as8048 this is defined
.8048
.area		CODE	(ABS)
.endif

; 0 = mains frequency input on I pin, 1 = free running, no mains input
.equ	freerun,	0

; 0 = time setting buttons on T0 and T1, 1 = ignore for testing
.equ	noset,		0

; timing information.
; osc / 3 -- available on t0 (pin 1) via "ent0 clk"
; clk / 5 -- ale (osc / 15). "provided continuously" (ale is pin 11)
; ale / 32 -- "normal" timer rate (osc / 480).
; full 0-ff timer count would be 34 milliseconds with 
; 3.579545MHz xtal timer tick of 134.1 us (7457 Hz)
; ie, osc / (3 * 5 * 32) = 7457

; set timer (scan) negated count, period is 134.1 x scanf us
.if	debug == 1
.equ	scanf,		-3	; speed up simulation
.else
.equ	scanf,		-25	; 3.35 ms
.endif

; number of digits to scan, always 4 for this clock
; note: we always store 6 digits of time
.equ	scancnt,	4

; these depend on the timer period chosen
.equ	depmin,		30	; switch must be down 100 ms to register
.equ	rptthresh,	150	; repeat kicks in at 500 ms
.equ	rptperiod,	75	; repeat 4 times / second

; delay counter value
.equ	delcval,	0x27	; for display test

; p1.0 thru p1.7 drive segments
; p2.0 thru p2.3 are used in debug mode
; p2.4 thru p2.7 drive digits
; t0 set minutes
; t1 set hours
; i mains frequency input
.equ	p23,		0x08
.equ	p23rmask,	~p23
.equ	p22,		0x04
.equ	p22rmask,	~p22
.equ	swmask,		p23|p22	; jbN instructions later must match
.equ	p21,		0x02

; scan digit storage (6 digits)
; sds1 seconds 1's digit
; sds2 seconds 10's digit
; sdm1 minutes 1's digit
; sdm2 minutes 10's digit
; sdh1 hours 1's digit
; sdh2 hours 10's digit

.equ	sds1,		0x20
.equ	sds2,		0x21
.equ	sdm1,		0x22
.equ	sdm2,		0x23
.equ	sdh1,		0x24
.equ	sdh2,		0x25

; current display digit storage
.equ	scand,		0x26

.if	scancnt == 4
.equ	scanbase,	sdm1
.else
.equ	scanbase,	sds1
.endif

.equ	swstate,	0x28	; previous state of switches
.equ	swtent,		0x29	; tentative state of switches
.equ	swmin,		0x2a	; count of how long state has been stable
.equ	mrepeat,	0x2c	; repeat counter for minutes up
.equ	hrepeat,	0x2d	; repeat counter for hours up

; saved PSW for checking previous F0
.equ	savepsw,	0x2f

; clock digit equates, follow MC146818 layout from original program
.equ	clockoff,	0x30	; put clock values at top of RAM

; the MC146818 has 14 bytes of control register
; and 50 bytes of cmos/nv ram storage
; seconds minutes hour and associated alarm registers
.equ	sr,		0+clockoff
.equ	mr,		2+clockoff
.equ	hr,		4+clockoff
; other registers not used so not named

; pseudo registers when not using RTC

.equ	tickcounter,	14+clockoff

; divide tick to get roughly mains frequency
.if	debug == 1
.equ	counttick,	2	; speed up simulation
.else
.equ	counttick,	6
.endif

; location doubles as powerfail indicator
.equ	powerfail,	14+clockoff

.equ	hzcounter,	15+clockoff

.if	debug == 1
.equ	counthz,	2	; speed up simulation
.else
.equ	counthz,	50	; mains frequency
.endif

.equ	colonplace,	2	; hours serves colon

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; reset vector 
	.org	0
	jmp	ticktock

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; external interrupt vector (pin 6) not used
	.org	3
	retr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; timer interrupt vector
; scan order is from msd to lsd
; scancnt == 6 -- hours minutes seconds
; scancnt == 4 -- hours minutes
; r7 saved a to restore on retr
; r6 digit index 0-3
; r5 saved low nybble of p2
; r4 colon state in high bit
	.org	7
	sel	rb1
	mov	r7, a		; save a
	mov	a, #scanf	; restart timer
	mov	t, a
	strt	t
	anl	p1, #0x00	; turn off all segments
; work out if we need to turn on colon
	mov	r0, #hzcounter
	mov	a, @r0
	add	a, #256-(counthz/2)
.if	freerun == 1
.else
	jc	firsthalf	; in first half of second
	mov	r0, #powerfail	; make colon 3/4 second on before buttons used
	add	a, @r0
firsthalf:
.endif
; C means in first half of second or first 3/4 if buttons not used yet
	mov	r0, #scand
	mov	a, @r0
	dec	a
	mov	@r0, a
	jnz	nextdigit	; if zero, restore our count
	mov	@r0, #scancnt
nextdigit:
.if	scancnt == 4
	anl	a, #0x03	; restrict to 0-3
.else
	anl	a, #0x07	; restrict to 0-7
.endif
	mov	r6, a		; save digit index
	xrl	a, #colonplace
	jz	colonhere
	clr	c		; colon not on this digit
colonhere:
	clr	a
	rrc	a		; a7 <- C
	mov	r4,a		; save colon
	in	a, p2		; get p2 state
	anl	a, #0x0f	; low nybble
	orl	a, #0xf0
	mov	r5, a		; save
	mov	a, r6		; retrieve digit index
	add	a, #digit2mask-page3
	movp3	a, @a
	anl	a, r5		; preserve low nybble
	outl	p2, a
	mov	a, r6		; retrieve digit index
	add	a, #scanbase	; index into the 7 segment storage
	mov	r0, a
	mov	a, @r0
	orl	a, r4		; r4 contains 0x0 or 0x80
	outl	p1, a		; output digit
	mov	a, r7		; restore a
	retr

; switch handling
; t0 low is set minutes, hold to start, then hold to repeat
; t1 low is set hours, hold to start, then hold to repeat
; convert to bitmask to easily detect change
; use p2.3 and p2.4 to emulate for debugging
switch:
.if	debug == 1
	in	a, p2
.else
	mov	a, #0xff
	jt0	not0
	anl	a, #p22rmask
not0:
	jt1	not1
	anl	a, #p23rmask
not1:
.endif
	anl	a, #swmask	; isolate switch bits
	mov	r7, a		; save a copy
	mov	r0, #swtent
	xrl	a, @r0		; compare against last state
	mov	r0, #swmin
	jz	swnochange
	mov	@r0, #depmin	; reload timer
	mov	r0, #swtent
	mov	a, r7
	mov	@r0, a		; save current switch state
	ret
swnochange:
	mov	a, @r0		; check timer
	jz	swaction
	dec	a
	mov	@r0, a
	ret
swaction:
	call	incmin
	call	inchour
.if	freerun == 1
.else
	mov	r0, #powerfail	; button was clicked
	mov	@r0, #0
.endif
	mov	r0, #swtent
	mov	a, @r0
	mov	r0, #swstate
	mov	@r0, a
	call 	updatedisplay
	ret

incmin:
	mov	r0, #swtent
	mov	a, @r0
	jb2	noincmin	; first time through?
	mov	r0, #swstate
	mov	a, @r0
	jb2	inc1min
	mov	r0, #mrepeat
	mov	a, @r0
	jz	minwaitover
	dec	a
	mov	@r0, a
	ret
minwaitover:
	mov	r0, #mrepeat
	mov	@r0, #rptperiod
inc1min:
	mov	r0, #mr
	mov	a, @r0
	inc	a
	mov	@r0, a
	add 	a, #196		; test for 60 minute overflow
	jnc 	mindone
	mov	@r0, #0		; yep overflow, reset to zero and update display
mindone:
	mov	r0, #sr
	mov	@r0, #0
	ret
noincmin:
	mov	r0, #mrepeat
	mov	@r0, #rptthresh
	ret

inchour:
	mov	r0, #swtent
	mov	a, @r0
	jb3	noinchour	; first time through?
	mov	r0, #swstate
	mov	a, @r0
	jb3	inc1hour
	mov	r0, #hrepeat
	mov	a, @r0
	jz	hourwaitover
	dec	a
	mov	@r0, a
	ret
hourwaitover:
	mov	r0, #hrepeat
	mov	@r0, #rptperiod
inc1hour:
	mov	r0, #hr
	mov	a, @r0
	inc	a
	mov	@r0, a
	add 	a, #232
	jnc 	hourdone
	mov	@r0, #0		; yep overflow, reset to zero and update display
hourdone:
	ret
noinchour:
	mov	r0, #hrepeat
	mov	@r0, #rptthresh
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.org	0x100
ticktock:
	clr 	f0		; zero some registers and other cold boot stuff
	sel 	rb0
.if	debug == 1
	sel 	mb0		; isn't actually needed
.endif
	mov 	r0, #scand	; set up digit scan parameters
	mov 	@r0, #scancnt
	mov	a, #0xff
	outl	p2, a
	in	a, p2		; get state of switch
	anl	a, #swmask	; isolate switch bits
	mov	r0, #swstate
	mov	@r0, a
	mov	r0, #swtent
	mov	@r0, a
	mov	r0, #swmin	; preset switch depression counts
	mov	@r0, #depmin
	mov	r0, #mrepeat	; and repeat thresholds
	mov	@r0, #rptthresh
	mov	r0, #hrepeat
	mov	@r0, #rptthresh
	mov 	a, #0xae
; set 12:34:56 as initial data
	mov	r0, #sr
	mov	@r0, #56
	mov	r0, #mr
	mov	@r0, #34
	mov	r0, #hr
	mov	@r0, #12
	call	updatedisplay
.if	freerun == 1
	mov	r0, #tickcounter
	mov	@r0, #counttick
.else
	mov	r0, #powerfail
	mov	@r0, #counthz/4	; so colon blink is asymmetric on power up
	mov	a, psw		; initialise saved psw
	mov	r0, #savepsw
	mov	@r0, a
.endif
	mov	r0, #hzcounter
	mov	@r0, #counthz
	mov	a, #scanf	; setup timer and enable its interrupt
	mov 	t, a
	strt 	t
	en 	tcnti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; main loop
workloop:
	jtf	ticked
	jmp	workloop	; wait until tick is up
ticked:
	call	tickhandler
	jnc	noadv
	call	incsec
	call	updatedisplay
noadv:
.if	noset == 1
.else
	call	switch
.endif
	jmp	workloop

; wait for a while. not used
delay:	mov	r0, #delcval
	clr	a
	mov	@r0, a
waitl:	mov	a, @r0
	inc	a
	mov	@r0, a
	jnz	waitl
	djnz	r6, delay
	ret

; called once per tick
tickhandler:
	clr	c
	clr	f0
.if	freerun == 1
	mov	r0, #tickcounter
	mov	a, @r0
	dec	a
	mov	@r0, a
	jnz	igntick		; tick to 1/Hz-th
	mov	@r0, #counttick
.else
.if	debug == 1
	in	a, p2		; simulate mains frequency with p21 on simulator
	anl	a, #p21
	jz	intlow
.else
	jni	intlow
.endif
	mov	r0, #savepsw
	mov	a, psw		; save f0 state
	mov	@r0, a		; f0 is !I
	ret
intlow:
	cpl	f0		; f0 is !I
	mov	r0, #savepsw	; was f0 previously 0?
	mov	a, @r0
	jb5	igntick		; transition already seen
	mov	a, psw		; save f0 state
	mov	@r0, a
.endif
	mov	r0, #hzcounter
	mov	a, @r0
	dec	a
	mov	@r0, a
	jnz	igntick
	mov	@r0, #counthz	; reinitialise Hz counter
	cpl	c		; set carry if second up
igntick:
	ret

; increment second and carry to minute and hour on overflow
incsec:
	mov 	r0, #sr
	mov	a, @r0
	inc	a
	mov	@r0, a
	add 	a, #196
	jnc 	noover
	mov	@r0, #0		; reset secs to 0
	mov	r0, #mr
	mov	a, @r0
	inc	a
	mov	@r0, a
	add	a, #196
	jnc	noover
	mov	@r0, #0		; reset mins to 0
	mov	r0, #hr
	mov	a, @r0
	inc	a
	mov	@r0, a
	add	a, #232
	jnc	noover
	mov	@r0, #0		; reset hours to 0
noover:
	ret

; convert binary values to 7-segment patterns
updatedisplay:
	mov 	r1, #sr
	mov	a, @r1
	mov 	r1, #sds1
	call	byte2segment
	mov	r1, #mr
	mov 	a, @r1
	mov 	r1, #sdm1
	call	byte2segment
	mov	r1, #hr
	mov 	a, @r1
	mov 	r1, #sdh1
	call	byte2segment
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; BCD lookup table
; movp3 a, @a reads this table entry into accumulator.
; Must org this at "page 3" (1 "page" is 256 bytes)
; We could use the double-dabble algorithm
; but we are not short of ROM storage, we can spare 61 bytes

	.org	0x300
page3:
	.db	0
	.db 	1
	.db	2
	.db	3
	.db	4
	.db	5
	.db	6
	.db	7
	.db	8
	.db	9
	.db	0x10	; bcd ten.
	.db	0x11
	.db	0x12
	.db	0x13
	.db	0x14
	.db	0x15
	.db	0x16
	.db	0x17
	.db	0x18
	.db	0x19
	.db	0x20	; bcd twenty. etc...
	.db	0x21
	.db	0x22
	.db	0x23
	.db	0x24
	.db	0x25
	.db	0x26
	.db	0x27
	.db	0x28
	.db	0x29
	.db	0x30
	.db	0x31
	.db	0x32
	.db	0x33
	.db	0x34
	.db	0x35
	.db	0x36
	.db	0x37
	.db	0x38
	.db	0x39
	.db	0x40
	.db	0x41
	.db	0x42
	.db	0x43
	.db	0x44
	.db	0x45
	.db	0x46
	.db	0x47
	.db	0x48
	.db	0x49
	.db	0x50
	.db	0x51
	.db	0x52
	.db	0x53
	.db	0x54
	.db	0x55
	.db	0x56
	.db	0x57
	.db	0x58
	.db	0x59
	.db	0x60	; for leap seconds

; font table. (beware of 8048 movp3 "page" limitation)
; 1's for lit segment since this turns on cathodes
; MSB=colon LSB=g
; entries for 10-15 are for blanking

dfont:	.db	0x7e	; 0
	.db	0x30	; 1
	.db	0x6d
	.db	0x79
	.db	0x33
	.db	0x5b
	.db	0x5f
	.db	0x70
	.db	0x7f
	.db	0x73
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00

; convert byte to 7 segment
; a - input, r1 -> 2 byte storage

byte2segment:
	movp3 	a, @a		; convert from binary to bcd
	mov 	r7, a		; save converted bcd digits
	anl 	a, #0xf		; get units
	add 	a, #dfont-page3	; index into font table
	movp3 	a, @a		; grab font for this digit
	mov 	@r1, a		; save it
	inc	r1
	mov 	a, r7		; restore bcd digits
	swap 	a
	anl 	a, #0xf
	add 	a, #dfont-page3	; index into font table
	movp3 	a, @a		; grab font for this digit
	mov 	@r1, a		; save it
	ret

; convert digit number 0-3 to for port 2 high nybble
digit2mask:
	.db	~0x80		; p2.7 is min
	.db	~0x40		; p2.6 is 10 min
	.db	~0x20		; p2.5 is hour
	.db	~0x10		; p2.4 is 10 hour
	.db	~0x00		; just in case scancnt == 6 in future
	.db	~0x00
	.db	~0x00
	.db	~0x00

ident:
	.db	0x0
	.db	0x4b, 0x65, 0x6e
	.db	0x20
	.db	0x59, 0x61, 0x70
	.db	0x20
	.db	0x32, 0x30	; 20
	.db	0x31, 0x38	; 18
	.db	0x0

; end
