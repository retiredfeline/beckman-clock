;
; If debug == 1 then time constants are lowered for faster simulation
; Also port 2 low nybble is virtually used to simulate buttons because
; s48 simulator has no commands to change interrupt and test input "pins"
;
.equ	debug,		0

; 804[1289] 6/7 segment clock

; This code is under MIT license. Ken Yap

;;;;;;;;;;;;;;;;;;;;;;;;;;

.ifdef	.__.CPU.		; if we are using as8048 this is defined
.8048
.area	CODE	(ABS)
.endif	; .__.CPU.

; if 1 a blink program will be executed instead
.equ	blinktest,	0

; timing source, define only one
;.equ	intxtal,	1	; MCU clock
.equ	mains,		1	; mains
;.equ	rtcsqw,		1	; for mains, use DS1287 RTC SQW output only as "mains"
;.equ	rtc,		1	; use DS1287 RTC to keep time

.ifdef	rtc
.equ	ds1287used,	1
.endif	; rtc

.ifdef	rtcsqw
.equ	ds1287used,	1
.endif	; rtcsqw

; UI style, define only one
;.equ	hmui,		1	; increment H and M buttons
.equ	modeui,		1	; mode button and increment button

; display, define only one
.equ	muxdisp,	1	; multiplex display
.equ	beckman,	1	; Beckman display, g least significant bit, digits reversed
;.equ	tm1637,		1	; external TM1637 display
;.equ	hc595,		1	; 74HC595 7 segment display
;.equ	srdisp,		1	; 74HC595 16 LED display

; 0 = no brightness control, 1 = both buttons = cycle brightness
.equ	brightcontrol,	0

; 0 = 7 segment, 1 = 6 segment
.equ	sixseg,		0
.equ	raisedzero,	1

; 0 = 0 bit turns on, 1 = 1 bit turns on segment
.equ	highison,	1

; for muxdisp, 0 = 0 bit turns on, 1 = 1 bit turns on digit
.equ	highdigiton,	0

; if defined, display is 12 hour
;.equ	twelvehour,	1

; timing information.
; clk / 5 -- ale (osc / 15). "provided continuously" (pin 11)
; ale / 32 -- "normal" timer rate (osc / 480).
; set timer count, tick = period x timerdiv

.if	debug == 1
.if	blinktest == 1
.else				; but only if not blink program
.equ	timerdiv,	3	; speed up simulation
.endif	; blink
.else
;.equ	timerdiv,	100	; 200 Hz with 9.600 MHz crystal
;.equ	timerdiv,	64	; 200 Hz with 6.144 MHz crystal
;.equ	timerdiv,	50	; 250 Hz with 6.000 MHz crystal
;.equ	timerdiv,	44	; 240 Hz with 5.0688 MHz crystal
;.equ	timerdiv,	40	; 256 Hz with 4.9152 MHz crystal
;.equ	timerdiv,	32	; 240 Hz with 3.6864 MHz crystal
.equ	timerdiv,	31	; 240 Hz with 3.595295 MHz crystal
.endif	; debug
.equ	tcount,		-timerdiv

.equ	scanfreq,	256	; resulting scan frequency, see above

; these are in 1/100ths of second, multiply by scanfreq to get counts
.equ	depmin,		scanfreq*5/100	; down 1/20th s to register
.equ	relmin,		scanfreq*10/100	; down 1/10th s to register
.equ	rptthresh,	scanfreq*50/100	; repeat kicks in at 1/2 s
.equ	rptperiod,	scanfreq*25/100	; repeat 4 times / second

; number of digits to scan, always 4 for this clock
; note: we always store 6 digits of time
.equ	scancnt,	4

; p1.0 thru p1.7 drive segments when driving with edge triggered latch
; p2.0 thru p2.3 are used in debug mode in simulator, not physically
; p2.4 thru p2.7 drive digits when driving directly. or TM1637
; t0 button1
; t1 button2
; both change brightness
.equ	p21,		0x02
.equ	p22,		0x04
.equ	p22rmask,	~p22
.equ	p23,		0x08
.equ	p23rmask,	~p23
.equ	swmask,		p23|p22
; swap the next assignments to swap buttons
.equ	t0rmask,	p22rmask
.equ	t1rmask,	p23rmask

.ifdef	tm1637
;
; for driving TM1637 based display with 2 lines
;
.equ	data1mask,	0x80	; p2.7
.equ	data0mask,	~data1mask&0xff
.equ	clk1mask,	0x40	; p2.6
.equ	clk0mask,	~clk1mask&0xff
.equ	colon1mask,	0x80	; colon is top bit

; 0 = no blink on p2.5, 1 = blink, used for verification when TM1637 used
.equ	blinkp25,	1
.equ	blink1mask,	0x20	; p2.5
.equ	blink0mask,	~blink1mask
.equ	brightcontrol,	1	; turn on brightness control
.equ	highison,	1
.equ	minbright,	0x88	; 1/16th brightness
.equ	maxbright,	0x8f	; 14/16 brightness (why not full?)
.equ	defbright,	(maxbright+minbright)/2
.else
.equ	minbright,	0x0	; min brightness
.equ	maxbright,	0x7	; full brightness
.equ	defbright,	(maxbright+minbright)/2
.endif	; tm1637

.ifdef	hc595
;
; for driving segment displays with 74HC595
;
.equ	data1mask,	0x80	; p2.7
.equ	data0mask,	~data1mask&0xff
.equ	clk1mask,	0x40	; p2.6
.equ	clk0mask,	~clk1mask&0xff
.equ	load1mask,	0x20	; p2.5
.equ	load0mask,	~load1mask&0xff
.equ	colon1mask,	0x80	; colon is top bit
.equ	pwm1mask,	0x10	; p2.4
.equ	pwm0mask,	~pwm1mask&0xff
.equ	highison,	1
;.equ	msdfirst	1	; shift most significant digit first
.endif	; hc595

.ifdef	srdisp
;
; for driving raw display with 74HC595
;
.equ	data1mask,	0x80	; p2.7
.equ	data0mask,	~data1mask&0xff
.equ	clk1mask,	0x40	; p2.6
.equ	clk0mask,	~clk1mask&0xff
.equ	load1mask,	0x20	; p2.5
.equ	load0mask,	~load1mask&0xff
.equ	blinkp24,	1
.equ	blink1mask,	0x10	; p2.4
.equ	blink0mask,	~blink1mask
.equ	highison,	0
; zero or one of the three options should be chosen
;.equ	srbcd,		1	; if set, display BCD instead of binary
;.equ	srter,		1	; if set, display ternary instead of binary
;.equ	srtcd,		1	; if set, display TCD instead of binary
.endif	; srdisp

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
.equ	currbright,	0x27

.if	scancnt == 4
.equ	scanbase,	sdm1
.else
.equ	scanbase,	sds1
.endif	; scancnt

.equ	swstate,	0x28	; previous state of switches
.equ	swtent,		0x29	; tentative state of switches
.equ	swmin,		0x2a	; count of how long state has been stable
.equ	uimode,		0x2b	; mode ui is in
.equ	mode0,		0x00	; normal mode
.equ	mode1,		0x01	; set hours
.equ	mode2,		0x02	; set minutes
				; and more later
.equ	modeend,	0x03
.equ	mrepeat,	0x2c	; repeat counter for minutes up
.equ	modetimeout,	0x2c	; doubles as mode timeout counter, comment out to disable
.equ	timeoutsecs,	64	; seconds before reverting to normal mode
.equ	hrepeat,	0x2d	; repeat counter for hours up
.equ	b2repeat,	0x2d	; also for button2 repeat
.equ	brightthresh,	0x2e	; store point at which display turns off

; saved PSW for checking previous F0
.equ	savepsw,	0x2f

.ifdef	ds1287used
.ifdef	rtc
.equ	ctroff,		0	; RTC is addressed as external RAM
.equ	ctloff,	0
.endif	; rtc
.ifdef	rtcsqw
.equ	ctroff,		0x30	; put clock values at top of internal RAM
.equ	ctloff,		0	; but RTC is addressed as external RAM
.endif	; rtcsqw
.else
.equ	ctroff,		0x30	; put clock values at top of internal RAM
.equ	ctloff,		0x30
.endif	; ds1287used

.equ	sr,		0+ctroff
.equ	sra,		1+ctroff
.equ	mr,		2+ctroff
.equ	mra,		3+ctroff
.equ	hr,		4+ctroff
.equ	hra,		5+ctroff
.equ	crga,		10+ctloff
.equ	crgb,		11+ctloff
.equ	crgc,		12+ctloff
.equ	crgd,		13+ctloff

.equ	oscon,		0x2b	; turn oscillator on, 32 Hz SQW
.equ	disrtc,		0x8e	; disable RTC, SQW, binary, 24H
.equ	enrtc,		0x0e	; enable RTC, SQW, binary, 24H
.equ	uipbit,		0x80	; update in progress

; even with RTC, these are used to implement the seconds blink so should be
; roughly correct but a small discrepancy won't be noticed
;
; a future version could use the periodic flag to drive the blink if desired

.equ	tickcounter,	0x3e

.if	debug == 1
.equ	counthz,	2	; speed up simulation
.else
.ifdef	mains
.ifdef	rtcsqw
.equ	counthz,	32	; RTC SQW frequency
.else
.equ	counthz,	50	; mains frequency
.endif	; rtcsqw
.else
.equ	counthz,	64	; virtual mains frequency, must suit scanfreq
.endif	; mains
.endif	; debug

; if mains is the timing source, ticks are only used for scanning
; divide tick to get virtual mains frequency
.if	debug == 1
.equ	counttick,	2	; speed up simulation
.else
.equ	counttick,	scanfreq/counthz	; should be integer
.endif	; debug

; location doubles as powerfail indicator
.equ	powerfail,	0x3e

.equ	hzcounter,	0x3f

.equ	colonplace,	2	; hours serves colon

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; reset vector 
	.org	0
.if	blinktest == 1
	jmp	blink
.else
	jmp	ticktock
.endif	; blinktest

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; external interrupt vector (pin 6) not used
	.org	3
	dis	i
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
	mov	a, #tcount	; restart timer
	mov	t, a
	strt	t
.ifdef	muxdisp
.if	highison == 1
	mov	a, #0x00
.else
	mov	a, #0xff
.endif	; highison
	outl	p1, a		; turn off all segments
; work out if we need to turn on colon
	mov	r0, #hzcounter
	mov	a, @r0
	add	a, #256-(counthz/2)
.ifdef	mains
	jc	firsthalf	; in first half of second
	mov	r0, #powerfail	; make colon 3/4 second on before buttons used
	add	a, @r0
firsthalf:
.endif	; mains
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
.endif	; scancnt
	mov	r6, a		; save digit index
	xrl	a, #colonplace
	jz	colonhere
	clr	c		; colon not on this digit
colonhere:
	clr	a
	rrc	a		; a7 <- C
.if	highison == 1
.else
	cpl	a
.endif	; highison
	mov	r4, a		; save colon
.if	debug == 1
	in	a, p2		; get p2 state
	anl	a, #0x0f	; low nybble
	orl	a, #0xf0
	mov	r5, a		; save
.endif	; debug
	mov	a, r6		; retrieve digit index
	add	a, #digit2mask-page3
	movp3	a, @a
.if	debug == 1
	anl	a, r5		; preserve low nybble
.endif	; debug
	outl	p2, a
	mov	a, r6		; retrieve digit index
	add	a, #scanbase	; index into the 7 segment storage
	mov	r0, a
	mov	a, @r0
.if	highison == 1
	orl	a, r4		; r4 contains 0x0 or 0x80
.else
	anl	a, r4		; r4 contains 0xff or 0x7f
.endif	; highison
	outl	p1, a		; output digit
.endif	; muxdisp
	mov	a, r7		; restore a
	retr

; switch handling
; t0 low is change mode / set minutes, hold to start, then hold to repeat
; t1 low is advance counter / set hours, hold to start, then hold to repeat
; convert to bitmask to easily detect change
; use p2.2 and p2.3 to emulate for debugging
switch:
.if	debug == 1
	in	a, p2
.else
	mov	a, #0xff
	jt0	not0
	anl	a, #t0rmask
not0:
	jt1	not1
	anl	a, #t1rmask
not1:
.endif	; debug
	anl	a, #swmask	; isolate switch bits
	mov	r7, a		; save a copy
	mov	r0, #swtent
	xrl	a, @r0		; compare against last state
	mov	r0, #swmin
	jz	swnochange
	mov	r1, #swstate	; check current state
	mov	a, @r1
	xrl	a, #swmask	; were switches up before?
	mov	r1, #swmin
	jz	isdep		; depress or release
	mov	@r1, #relmin	; was release
	jmp	savestate
isdep:
	mov	@r1, #depmin	; was depress
savestate:
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
.if	brightcontrol == 1
	call	button1and2
	jc	swactioned	; both buttons were down, just brightness
.endif	; brightcontrol
	call	button1
	call	button2
swactioned:
.ifdef	mains
	mov	r0, #powerfail	; button was clicked
	mov	@r0, #0
.endif	; mains
	mov	r0, #swtent
	mov	a, @r0
	mov	r0, #swstate
	mov	@r0, a
	ret

.ifdef	rtc
waitforrtc:
	mov	r1, #crga
	movx	a, @r1
	anl	a, #uipbit
	jnz	waitforrtc
	ret
.endif	; rtc

.ifdef	hmui
button1:
.ifdef	rtc
	call	waitforrtc
.endif	; rtc
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
.ifdef	rtc
	movx	a, @r0
	inc	a
	movx	@r0, a
.else
	mov	a, @r0
	inc	a
	mov	@r0, a
.endif	; rtc
	add 	a, #196		; test for 60 minute overflow
	jnc 	mindone
.ifdef	rtc
	clr	a
	movx	@r0, a
.else
	mov	@r0, #0		; yep overflow, reset to zero and update display
.endif	; rtc
mindone:
	mov	r0, #sr
.ifdef	rtc
	clr	a
	movx	@r0, a
.else
	mov	@r0, #0
.endif	; rtc
	call 	updatedisplay
	ret
noincmin:
	mov	r0, #mrepeat
	mov	@r0, #rptthresh
	ret
.endif	; hmui

.ifdef	modeui
button1:
	mov	r0, #swtent
	mov	a, @r0
	jb2	noincmode	; first time through?
	mov	r0, #swstate
	mov	a, @r0
	jb2	inc1mode
noincmode:
	ret
inc1mode:
	mov	r0, #uimode
	mov	a, @r0
	inc	a
	mov	@r0, a
	add 	a, #-modeend	; test for mode wraparound
	jnc 	modedone
	mov	@r0, #mode0	; yep overflow, reset to mode0
modedone:
	call	updatedisplay
.ifdef	modetimeout
	jmp	checktimeout
.else
	ret
.endif	; modetimeout
.endif	; modeui

.ifdef	hmui
button2:
.ifdef	rtc
	call	waitforrtc
.endif	; rtc
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
.ifdef	rtc
	movx	a, @r0
	inc	a
	movx	@r0, a
.else
	mov	a, @r0
	inc	a
	mov	@r0, a
.endif	; rtc
	add 	a, #232
	jnc 	hourdone
.ifdef	rtc
	clr	a
	movx	@r0, a
.else
	mov	@r0, #0		; yep overflow, reset to zero and update display
.endif	; rtc
hourdone:
	call 	updatedisplay
	ret
noinchour:
	mov	r0, #hrepeat
	mov	@r0, #rptthresh
	ret
.endif	; hmui

.ifdef	modeui
button2:
.ifdef	rtc
	call	waitforrtc
.endif	; rtc
	mov	r0, #uimode
	mov	a, @r0
	jz	noinc
	xrl	a, #mode1
	jnz	notmode1
	mov	r2, #hr		; increment hours
	mov	r3, #232
	jmp	doinc
notmode1:
	mov	a, @r0
	xrl	a, #mode2
	jnz	noinc
	mov	r2, #mr		; increment minutes
	mov	r3, #196
doinc:
	mov	r0, #swtent
	mov	a, @r0
	jb3	noincctr	; first time through?
	mov	r0, #swstate
	mov	a, @r0
	jb3	inc1ctr
	mov	r0, #b2repeat
	mov	a, @r0
	jz	ctrwaitover
	dec	a
	mov	@r0, a
noinc:
	ret
ctrwaitover:
	mov	r0, #b2repeat
	mov	@r0, #rptperiod
inc1ctr:
	mov	a, r2
	mov	r0, a
.ifdef	rtc
	movx	a, @r0
	inc	a
	movx	@r0, a
.else
	mov	a, @r0
	inc	a
	mov	@r0, a
.endif	; rtc
	add 	a, r3
	jnc 	ctrdone
.ifdef	rtc
	clr	a
	movx	@r0, a
.else
	mov	@r0, #0		; yep overflow, reset to zero and update display
.endif	; rtc
ctrdone:
	mov	r0, #uimode
	mov	a, @r0
	xrl	a, #mode2
	jnz	nozero
	mov	r0, #sr		; zero seconds
.ifdef	rtc
	clr	a
	movx	@r0, a
.else
	mov	@r0, #0
.endif	; rtc
nozero:
	call 	updatedisplay
.ifdef	modetimeout
checktimeout:
	mov	r0, #uimode
	mov	a, @r0
	xrl	a, #mode0
	mov	r0, #modetimeout
	jnz	restarttimeout
	mov	@r0, #0
	jmp	timeoutset
restarttimeout:
	mov	@r0, #timeoutsecs
timeoutset:
.endif	; modetimeout
	ret
noincctr:
	mov	r0, #b2repeat
	mov	@r0, #rptthresh
	ret
.endif	; modeui

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.org	0x100
ticktock:
	clr	f0		; zero some registers and other cold boot stuff
	sel	rb0
.ifdef	muxdisp
	mov 	r0, #scand	; set up digit scan parameters
	mov 	@r0, #scancnt
.endif	; muxdisp
	mov	a, #0xff
	outl	p2, a		; p2 is all input
	anl	a, #swmask	; isolate switch bits
	mov	r0, #swstate
	mov	@r0, a
	mov	r0, #swtent
	mov	@r0, a
	mov	r0, #swmin	; preset switch depression counts
	mov	@r0, #depmin
.ifdef	modetimeout
	mov	r0, #modetimeout
	mov	@r0, #0
	mov	r0, #b2repeat
	mov	@r0, #rptthresh
.else
	mov	r0, #mrepeat	; and repeat thresholds
	mov	@r0, #rptthresh
	mov	r0, #hrepeat
	mov	@r0, #rptthresh
.endif	; modetimeout
.ifdef	modeui
	mov	r0, #uimode
	mov	@r0, #mode0
.endif	; modeui
.ifdef	ds1287used
.ifdef	rtc
; delay 2s to allow RTC to settle
	mov	r0, #250
another8ms:
	mov	a, #-(timerdiv*2)	; restart timer
	mov	t, a
	strt	t
busy8ms:
	jtf	done8ms
	jmp	busy8ms
done8ms:
	stop	tcnt
	djnz	r0, another8ms
.endif	; rtc
; don't preset RTC each power up, just setup RTC access, correct invalid values
; pause internal functions
	mov	r0, #crgb
	mov	a, #disrtc
	movx	@r0, a
; initialise alarm to 0xc0 = don't care
	mov	r0, #sra
	mov	a, #0xc0
	movx	@r0, a
	mov	r0, #mra
	movx	@r0, a
	mov	r0, #hra
	movx	@r0, a
.ifdef	rtcsqw
; counters in RAM, not RTC
; set 12:34:56 as initial data
	mov	r0, #sr
	mov	@r0, #56
	mov	r0, #mr
	mov	@r0, #34
	mov	r0, #hr
	mov	@r0, #12
.else
; correct invalid register values
	mov	r0, #mr
	movx	a, @r0
	inc	a
	movx	@r0, a
	add 	a, #196		; >= 60?
	jnc 	minvalid
	clr	a
	movx	@r0, a
;
minvalid:
	mov	r0, #hr
	movx	a, @r0
	inc	a
	movx	@r0, a
	add 	a, #232		; >= 24?
	jnc 	hourvalid
	clr	a
	movx	@r0, a
hourvalid:
.endif	; rtcsqw
; enable oscillator
	mov	r0, #crga
	mov	a, #oscon
	movx	@r0, a
; reenable internal functions
	mov	r0, #crgb
	mov	a, #enrtc
	movx	@r0, a
.else
; set 12:34:56 as initial data
	mov	r0, #sr
	mov	@r0, #56
	mov	r0, #mr
	mov	@r0, #34
	mov	r0, #hr
	mov	@r0, #12
.endif	; ds1287used
.if	brightcontrol == 1
	mov	r0, #currbright
	mov	a, #defbright
	mov	@r0, a
	call	setbright
.endif	; brightcontrol
	call	updatedisplay
.ifdef	mains
	mov	r0, #powerfail
	mov	@r0, #counthz/4	; so colon blink is asymmetric on power up
	mov	a, psw		; initialise saved psw
	mov	r0, #savepsw
	mov	@r0, a
.endif	; mains
	mov	r0, #tickcounter
	mov	@r0, #counttick
	mov	r0, #hzcounter
	mov	@r0, #counthz
	mov	a, #tcount	; setup timer and enable its interrupt
	mov	t, a
	strt	t
	en	tcnti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; main loop
workloop:
	jtf	ticked

.ifdef	muxdisp
.if	brightcontrol == 1	; PWM method
	mov	r0, #brightthresh
	mov	a, t
	add	a, @r0
	jb7	leaveon
.if	highison == 1
	clr	a
.else
	mov	a, #0xff
.endif	; highison
	outl	p1, a
leaveon:
.endif	; brightcontrol
.endif	; muxdisp

.ifdef	hc595
.if	brightcontrol == 1	; PWM method
	mov	r0, #brightthresh
	mov	a, t
	add	a, @r0
	jb7	leaveon
	orl	p2, #pwm1mask	; take high to turn off
	jmp	pwmdone
leaveon:
	anl	p2, #pwm0mask	; take low to turn on
pwmdone:
.endif	; brightcontrol
.endif	; hc595

	jmp	workloop	; wait until tick is up
ticked:
	call	tickhandler
	jnc	noadv
	call	incsec
	call	updatedisplay

.ifdef	tm1637
.if	blinkp25 == 1
	orl	p2, #blink1mask	; turn off blink
.endif	; blinkp25
.endif	; tm1637

.ifdef	srdisp
.if	blinkp24 == 1
	orl	p2, #blink1mask	; turn off blink
.endif	; blinkp24
.endif	; srdisp

noadv:
	call	switch
	jmp	workloop

; called once per tick
tickhandler:			; handle blink first
.ifdef	mains			; don't divide tick using mains
.else				; divide for seconds blink
	mov	r0, #tickcounter
	mov	a, @r0
	dec	a
	mov	@r0, a
	jnz	igntick		; ignore this tick
	mov	@r0, #counttick
.endif	; mains
.ifdef	tm1637
	mov	r0, #hzcounter
	mov	a, @r0
	xrl	a, #counthz/2	; halfway through second?
	jnz	blinkoff
	mov	r0, #sdm1+colonplace
	mov	a, @r0
	orl	a, #colon1mask
	mov	@r0, a		; modify digit register but will only last 1/2 s
	call	updatetm1637
.if	blinkp25 == 1
	anl	p2, #blink0mask	; pull low to turn on
.endif	; blinkp25
.endif	; tm1637

.ifdef	hc595
	mov	r0, #hzcounter
	mov	a, @r0
	xrl	a, #counthz/2	; halfway through second?
	jnz	blinkoff
	mov	r0, #sdm1+colonplace
	mov	a, @r0
.if	highison == 1
	orl	a, #colon1mask
.else
	anl	a, #~colon1mask
.endif	; highison
	mov	@r0, a		; modify digit register but will only last 1/2 s
	call	updatehc595
.endif	; hc595

.ifdef	srdisp
.if	blinkp24 == 1
	mov	r0, #hzcounter
	mov	a, @r0
	xrl	a, #counthz/2	; halfway through second?
	jnz	blinkoff
	anl	p2, #blink0mask	; pull low to turn on
.endif	; blinkp24
.endif	; srdisp
blinkoff:			; now handle hz
	clr	c
	clr	f0
.ifdef	mains
.if	debug == 1
	in	a, p2		; simulate mains frequency with p21 on simulator
	anl	a, #p21
	jz	intlow
.else
.if	.__.CPU. == 0		; 8048/9
	jni	intlow
.endif
.if	.__.CPU. == 1		; 8041/2
;	in	a, p2
;	jb3	intlow		; use p2.3 as mains sampling pin
.endif
.endif	; debug
	mov	r0, #savepsw
	mov	a, psw		; save f0 state
	mov	@r0, a		; f0 is !I
	ret
intlow:
	cpl	f0		; f0 is !I
	mov	r0, #savepsw	; was f0 previously 0?
	mov	a, @r0
	jb5	ignint		; transition already seen
	mov	a, psw		; save f0 state to turn on
	mov	@r0, a
.endif	; mains
	mov	r0, #hzcounter
	mov	a, @r0
	dec	a
	mov	@r0, a
	jnz	ignint
	mov	@r0, #counthz	; reinitialise Hz counter
	cpl	c		; set carry if second up
igntick:
ignint:
	ret

; increment second and carry to minute and hour on overflow
incsec:
.ifdef	rtc
; RTC will increment by itself
.else
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
.endif	; rtc
.ifdef	modetimeout
	mov	r0, #modetimeout
	mov	a, @r0
	jnz	dectimeout
	mov	r0, #uimode
	mov	@r0, #mode0
	jmp	timeoutdone
dectimeout:
	dec	a
	mov	@r0, a
timeoutdone:
.endif	; modetimeout
	ret

	.org	0x200

page2:
; convert binary values to segment patterns
updatedisplay:
.ifdef	rtc
.if	debug == 1
	mov	r1, #sr
	mov	a, #56
	movx	@r1, a
	mov	r1, #mr
	mov	a, #34
	movx	@r1, a
	mov	r1, #hr
	mov	a, #12
	movx	@r1, a
.else
; if RTC busy come back later
	mov	r1, #crga
	movx	a, @r1
	anl	a, #uipbit
	jz	rtcready
	ret
rtcready:
.endif	; debug
.endif	; rtc
	mov 	r1, #sr
.ifdef	rtc
	movx	a, @r1
.else
	mov	a, @r1
.endif	; rtc
	mov 	r1, #sds1
	call	byte2segment
	mov	r1, #mr
.ifdef	rtc
	movx	a, @r1
.else
	mov 	a, @r1
.endif	; rtc
	mov 	r1, #sdm1
	call	byte2segment
	mov	r1, #hr
.ifdef	rtc
	movx	a, @r1
.else
	mov 	a, @r1
.endif	; rtc
	mov 	r1, #sdh1
.ifdef	twelvehour
	call	byte2segment12
.else
	call	byte2segment
.endif	; twelvehour
.ifdef	modeui			; blank digits not being incremented
	mov	r1, #uimode
	mov	a, @r1
	xrl	a, #mode2
	jnz	showh
.if	highison == 1
	clr	a
.else
	mov	a, #0xff
.endif	; highison
	mov	r0, #sdh1
	mov	@r0, a
	mov	r0, #sdh2
	mov	@r0, a
showh:
	mov	a, @r1
	xrl	a, #mode1
	jnz	showm
.if	highison == 1
	clr	a
.else
	mov	a, #0xff
.endif	; highison
	mov	r0, #sdm1
	mov	@r0, a
	mov	r0, #sdm2
	mov	@r0, a
showm:
.endif	; modeui
.ifdef	muxdisp
	ret
.endif	; muxdisp
.ifdef	tm1637
	jmp	updatetm1637
.endif	; tm1637
.ifdef	hc595
	jmp	updatehc595
.endif	; hc595
.ifdef	srdisp
	jmp	updatesrdisp
.endif	; srdisp

;
; TM1637 handling routines translated from C code at
; https://blog.3d-logic.com/2015/01/21/arduino-and-the-tm1637-4-digit-seven-segment-display/
;
.ifdef	tm1637
updatetm1637:
	call	startxfer
	mov	a, #0x40
	call	writebyte
	call	stopxfer
	call	startxfer
	mov	a, #0xc0
	call	writebyte
	mov	r0, #sdh2
	mov	a, @r0
	call	writebyte
	mov	r0, #sdh1
	mov	a, @r0
	call	writebyte
	mov	r0, #sdm2
	mov	a, @r0
	call	writebyte
	mov	r0, #sdm1
	mov	a, @r0
	call	writebyte
	call	stopxfer
	ret

;
; Byte to write in A, destructive
;
writebyte:
.if	debug == 1		; don't actually write anything
.else
	mov	r6, #8
writebit:
	anl	p2, #clk0mask
	call	fiveus
	rrc	a
	jc	useor
	anl	p2, #data0mask	; turn bit off
	jmp	wrotebit
useor:
	orl	p2, #data1mask	; turn bit on
wrotebit:
	call	fiveus
	orl	p2, #clk1mask
	call	fiveus
	djnz	r6, writebit

	anl	p2, #clk0mask
	call	fiveus
	orl	p2, #data1mask
	orl	p2, #clk1mask
	call	fiveus
	in	a, p2
.endif	; debug
	ret			; ack in A

startxfer:
	orl	p2, #clk1mask
	orl	p2, #data1mask
	call	fiveus
	anl	p2, #data0mask
	anl	p2, #clk0mask
	call	fiveus
	ret

stopxfer:
	anl	p2, #clk0mask
	anl	p2, #data0mask
	call	fiveus
	orl	p2, #clk1mask
	orl	p2, #data1mask
	call	fiveus
	ret

; The call and return should take at least 5 us

fiveus:
	ret

setbright:
	call	startxfer	; desired brightness in a
	call	writebyte
	call	stopxfer
	ret
.endif	; tm1637

.ifdef	hc595
updatehc595:
	anl	p2, #data0mask & #clk0mask & #load0mask	; clear to 0
.ifdef	msdfirst	; shift MSD first
	mov	r0, #sdh2
	mov	a, @r0
	call	srbyte
	mov	r0, #sdh1
	mov	a, @r0
	call	srbyte
	mov	r0, #sdm2
	mov	a, @r0
	call	srbyte
	mov	r0, #sdm1
	mov	a, @r0
	call	srbyte
.else			; shift LSD first
	mov	r0, #sdm1
	mov	a, @r0
	call	srbyte
	mov	r0, #sdm2
	mov	a, @r0
	call	srbyte
	mov	r0, #sdh1
	mov	a, @r0
	call	srbyte
	mov	r0, #sdh2
	mov	a, @r0
	call	srbyte
.endif
	orl	p2, #load1mask	; pulse load
	nop
	anl	p2, #load0mask
	ret

setbright:
.if	brightcontrol == 1
	mov	r0, #currbright
	mov	a, @r0
	add	a, #brighttable-page2
	movp	a, @a
	mov	r0, #brightthresh
	mov	@r0, a
.endif	; brightcontrol
	ret

;
; left shift 8 bits of A into data pin
;
srbyte:
	mov	r0, #8
srbit:
	rlc	a
	jc	srbit1
	anl	p2, #data0mask
	jmp	srbit2
srbit1:
	orl	p2, #data1mask
srbit2:				; pulse clock
	orl	p2, #clk1mask	; need a delay?
	nop
	anl	p2, #clk0mask
	djnz	r0, srbit
	ret
.endif	; hc595

.ifdef	muxdisp

.if	brightcontrol == 1
setbright:
	mov	r0, #currbright
	mov	a, @r0
	add	a, #brighttable-page2
	movp	a, @a
	mov	r0, #brightthresh
	mov	@r0, a
	ret
.endif	; brightcontrol

.endif	; muxdisp

.ifdef	srdisp
;
; code to shift binary hours and minutes to shift register, then load
;
updatesrdisp:
	anl	p2, #data0mask & #clk0mask & #load0mask	; clear to 0
.ifdef	modeui
	mov	r0, #uimode
	mov	a, @r0
	xrl	a, #mode1
	jnz	dispm
	clr	a
	jmp	nodispm
dispm:
	mov	r0, #mr		; minutes are MSB in SR
	mov	a, @r0
nodispm:
.endif	; modeui
.ifdef	srbcd
	movp3	a, @a
.endif	; srbcd
.ifdef	srter
	add	a, #tertab-page3
	movp3	a, @a
.endif	; srter
.ifdef	srtcd
	add	a, #tcdtab-page3
	movp3	a, @a
.endif	; srtcd
	call	srbyte
.ifdef	modeui
	mov	r0, #uimode
	mov	a, @r0
	xrl	a, #mode2
	jnz	disph
	clr	a
	jmp	nodisph
disph:
	mov	r0, #hr
	mov	a, @r0
nodisph:
.endif	; modeui
.ifdef	srbcd
	movp3	a, @a
.endif	; srbcd
.ifdef	srter
	add	a, #tertab-page3
	movp3	a, @a
.endif	; srter
.ifdef	srtcd
	add	a, #tcdtab-page3
	movp3	a, @a
.endif	; srtcd
	call	srbyte
	orl	p2, #load1mask	; pulse load
	nop
	anl	p2, #load0mask
	ret

;
; left shift 8 bits of A into data pin
;
srbyte:
	mov	r0, #8
srbit:
	rlc	a
.if	highison == 1
	jc	srbit1
.else
	jnc	srbit1
.endif	; highison
	anl	p2, #data0mask
	jmp	srbit2
srbit1:
	orl	p2, #data1mask
srbit2:				; pulse clock
	orl	p2, #clk1mask	; need a delay?
	nop
	anl	p2, #clk0mask
	djnz	r0, srbit
	ret

.endif	; srdisp

.if	brightcontrol == 1
button1and2:
	clr	c
	mov	r0, #swtent
	mov	a, @r0
	jnz	noincbright	; both buttons down?
	mov	r0, #swstate
	mov	a, @r0
	jz	nosingle	; buttons still down?
	mov	r0, #currbright	; one or both were up so first time
	mov	a, @r0
	xrl	a, #maxbright	; wrap around to minimum
	jnz	incbright1
	mov	a, #minbright
	mov	@r0, a
	jmp	setbright1
incbright1:
	mov	a, @r0
	inc	a
	mov	@r0, a
setbright1:
	call	setbright
nosingle:			; don't trigger any single actions
	clr	c
	cpl	c
noincbright:
	ret

brighttable:
	.db	timerdiv-timerdiv/16
	.db	timerdiv-(timerdiv*2)/16
	.db	timerdiv-(timerdiv*4)/16
	.db	timerdiv-(timerdiv*11)/16
	.db	timerdiv-(timerdiv*12)/16
	.db	timerdiv-(timerdiv*13)/16
	.db	timerdiv-(timerdiv*14)/16
	.db	timerdiv-timerdiv
.endif	; brightcontrol

.if	blinktest == 1
;
; short program to check chip works
;
.equ	p25on,		0xdf
.equ	p25off,		0xff
.equ	delaycount,	scanfreq/2

blink:
	mov	a, #p25on
	outl	p2, a
	call	delay500ms
	mov	a, #p25off
	outl	p2, a
	call	delay500ms
	jmp	blink

delay500ms:
	mov	r0, #delaycount
another4ms:
	mov	a, #tcount	; restart timer
	mov	t, a
	strt	t
busy4ms:
	jtf	done4ms
	jmp	busy4ms
done4ms:
	stop	tcnt
	djnz	r0, another4ms
	ret
.endif	; blinktest

;
; Tables and lookup routines
;
	.org	0x300

page3:

; BCD lookup table
; movp3 a, @a reads this table entry into accumulator.
; Must org this at "page 3" (1 "page" is 256 bytes)
; We could use the double-dabble algorithm
; but we are not short of ROM storage, we can spare 61 bytes
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

.ifdef	srter
tertab:
	.db	0x00
	.db	0x01
	.db	0x02
	.db	0x04
	.db	0x05
	.db	0x06
	.db	0x08
	.db	0x09
	.db	0x0a
	.db	0x10
	.db	0x11
	.db	0x12
	.db	0x14
	.db	0x15
	.db	0x16
	.db	0x18
	.db	0x19
	.db	0x1a
	.db	0x20
	.db	0x21
	.db	0x22
	.db	0x24
	.db	0x25
	.db	0x26
	.db	0x28
	.db	0x29
	.db	0x2a
	.db	0x40
	.db	0x41
	.db	0x42
	.db	0x44
	.db	0x45
	.db	0x46
	.db	0x48
	.db	0x49
	.db	0x4a
	.db	0x50
	.db	0x51
	.db	0x52
	.db	0x54
	.db	0x55
	.db	0x56
	.db	0x58
	.db	0x59
	.db	0x5a
	.db	0x60
	.db	0x61
	.db	0x62
	.db	0x64
	.db	0x65
	.db	0x66
	.db	0x68
	.db	0x69
	.db	0x6a
	.db	0x80
	.db	0x81
	.db	0x82
	.db	0x84
	.db	0x85
	.db	0x86
.endif	; srter

.ifdef	srtcd
tcdtab:
	.db	0x00
	.db	0x01
	.db	0x02
	.db	0x04
	.db	0x05
	.db	0x06
	.db	0x08
	.db	0x09
	.db	0x0a
	.db	0x10
	.db	0x20
	.db	0x21
	.db	0x22
	.db	0x24
	.db	0x25
	.db	0x26
	.db	0x28
	.db	0x29
	.db	0x2a
	.db	0x30
	.db	0x40
	.db	0x41
	.db	0x42
	.db	0x44
	.db	0x45
	.db	0x46
	.db	0x48
	.db	0x49
	.db	0x4a
	.db	0x50
	.db	0x80
	.db	0x81
	.db	0x82
	.db	0x84
	.db	0x85
	.db	0x86
	.db	0x88
	.db	0x89
	.db	0x8a
	.db	0x90
	.db	0xa0
	.db	0xa1
	.db	0xa2
	.db	0xa4
	.db	0xa5
	.db	0xa6
	.db	0xa8
	.db	0xa9
	.db	0xaa
	.db	0xb0
	.db	0xc0
	.db	0xc1
	.db	0xc2
	.db	0xc4
	.db	0xc5
	.db	0xc6
	.db	0xc8
	.db	0xc9
	.db	0xca
	.db	0xd0
.endif	; srtcd

; font table. (beware of 8048 movp "page" limitation)
; 1's for lit segment since this turns on cathodes
; MSB=colon LSB=a
; entries for 10-15 are for blanking
; second half of each table is for 6 segments, add 16 to get there

dfont:
.if	sixseg == 1
.if	highison == 1
.if	raisedzero == 1
	.db	0x23	; top 0
.else
	.db	0x1c	; bottom 0
.endif	; raisedzero
	.db	0x12	; 1
	.db	0x1b
	.db	0x0f
	.db	0x32
	.db	0x2d
	.db	0x1e
	.db	0x13
	.db	0x3f
	.db	0x33
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
.else
.if	raisedzero == 1
	.db	~0x23	; top 0
.else
	.db	~0x1c	; bottom 0
.endif	; raisedzero
	.db	~0x12	; 1
	.db	~0x1b
	.db	~0x0f
	.db	~0x32
	.db	~0x2d
	.db	~0x1e
	.db	~0x13
	.db	~0x3f
	.db	~0x33
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
.endif	; highison
.else
.if	highison == 1
.ifdef	beckman
	.db	0x7e	; 0
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
.else
	.db	0x3f	; 0
	.db	0x06	; 1
	.db	0x5b
	.db	0x4f
	.db	0x66
	.db	0x6d
	.db	0x7d
	.db	0x07
	.db	0x7f
	.db	0x6f
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
	.db	0x00
.endif	; beckman
.else
	.db	~0x3f	; 0
	.db	~0x06	; 1
	.db	~0x5b
	.db	~0x4f
	.db	~0x66
	.db	~0x6d
	.db	~0x7d
	.db	~0x07
	.db	~0x7f
	.db	~0x6f
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
	.db	~0x00
.endif	; highison
.endif	; sixseg

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

.ifdef	twelvehour
; convert byte to 7 segment, 12 hour version for hours only
; a - input, r1 -> 2 byte storage

byte2segment12:
	mov	r7, a		; save a
	add	a, #-12		; >= 12?
	jc	zerotoeleven	; normalised to 0..11
	mov	a, r7		; use original value
; set an AM/PM indicator?
zerotoeleven:			; now always 0..11
	jnz	nottwelve
	mov	a, #12		; 0 is changed to 12
nottwelve:
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
	jnz	ge10		; 10H >= 1
	mov	a, #10		; if zero blank by using tenth entry
ge10:
	add 	a, #dfont-page3	; index into font table
	movp3 	a, @a		; grab font for this digit
	mov 	@r1, a		; save it
	ret
.endif	; twelvehour

.ifdef	muxdisp
; convert digit number 0-3 to for port 2 high nybble
digit2mask:
.if	highdigiton == 1
	.db	0x10		; p2.4 is min
	.db	0x20		; p2.5 is 10 min
	.db	0x40		; p2.6 is hour
	.db	0x80		; p2.7 is 10 hour
	.db	0x00		; just in case scancnt == 6 in future
	.db	0x00
	.db	0x00
	.db	0x00
.else
.ifdef	beckman
	.db	~0x80		; p2.7 is min
	.db	~0x40		; p2.6 is 10 min
	.db	~0x20		; p2.5 is hour
	.db	~0x10		; p2.4 is 10 hour
.else
	.db	~0x10		; p2.4 is min
	.db	~0x20		; p2.5 is 10 min
	.db	~0x40		; p2.6 is hour
	.db	~0x80		; p2.7 is 10 hour
.endif	; beckman
	.db	~0x00		; just in case scancnt == 6 in future
	.db	~0x00
	.db	~0x00
	.db	~0x00
.endif	; highdigiton
.endif	; muxdisp

ident:
	.db	0x0
	.db	0x4b, 0x65, 0x6e
	.db	0x20
	.db	0x59, 0x61, 0x70
	.db	0x20
	.db	0x32, 0x30	; 20
	.db	0x32, 0x34	; 24
	.db	0x0

.ifdef	.__.CPU.		; if we are using as8048 this is defined
; embed some option strings to identify ROM
.ifdef	intxtal
	.asciz	"intxtal"
.endif	; intxtal
.ifdef	mains
	.asciz	"mains"
.endif	; mains
.ifdef	rtcsqw
	.asciz	"rtcsqw"
.endif	; rtcsqw
.ifdef	rtc
	.asciz	"rtc"
.endif	; rtc
.ifdef	muxdisp
	.asciz	"muxdisp"
.endif	; muxdisp
.ifdef	tm1637
	.asciz	"tm1637"
.endif	; tm1637
.ifdef	hc595
	.asciz	"hc595"
.endif	; hc595
.ifdef	srdisp
	.asciz	"srdisp"
.endif	; srdisp
.ifdef	twelvehour
	.asciz	"12 hour"
.endif	; twelvehour
.ifdef	hmui
	.asciz	"hmui"
.endif	; hmui
.endif	; .__.CPU.

; end
