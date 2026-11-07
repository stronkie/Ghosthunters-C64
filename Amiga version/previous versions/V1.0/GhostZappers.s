;=====================================================================
;
;   G H O S T   Z A P P E R S        - Amiga 500 version -
;
;   Created By Mark Stronks (Stronkie)  -  port of the C64 original
;   Programming AI : Claude
;
;   Target: Amiga 500, OCS, Kickstart/Workbench 1.3, 512K chip + 512K
;   trapdoor.  68000 assembler, Devpac/vasm Motorola syntax:
;       vasmm68k_mot -Fhunkexe -kick1hunks -nosym -o GhostZappers main.s
;
;=====================================================================

; ---------------- custom chip registers (offsets from $dff000) -------
CUSTOM		equ	$dff000
DMACONR		equ	$002
VPOSR		equ	$004
VHPOSR		equ	$006
JOY0DAT		equ	$00a
JOY1DAT		equ	$00c
ADKCONR		equ	$010
POTGOR		equ	$016
INTENAR		equ	$01c
INTREQR		equ	$01e
BLTCON0		equ	$040
BLTCON1		equ	$042
BLTAFWM		equ	$044
BLTALWM		equ	$046
BLTCPT		equ	$048
BLTBPT		equ	$04c
BLTAPT		equ	$050
BLTDPT		equ	$054
BLTSIZE		equ	$058
BLTCMOD		equ	$060
BLTBMOD		equ	$062
BLTAMOD		equ	$064
BLTDMOD		equ	$066
BLTCDAT		equ	$070
BLTBDAT		equ	$072
BLTADAT		equ	$074
COP1LC		equ	$080
COPJMP1		equ	$088
DMACON		equ	$096
INTENA		equ	$09a
INTREQ		equ	$09c
ADKCON		equ	$09e
AUD0LC		equ	$0a0
AUD0VOL		equ	$0a8
AUD1VOL		equ	$0b8
AUD2VOL		equ	$0c8
AUD3LC		equ	$0d0
AUD3LEN		equ	$0d4
AUD3PER		equ	$0d6
AUD3VOL		equ	$0d8
CIAA_PRA	equ	$bfe001
CIAA_SDR	equ	$bfec01
CIAA_ICR	equ	$bfed01
CIAA_CRA	equ	$bfee01

; ---------------- raw key codes ----------------
KEY_ESC		equ	$45
KEY_SPACE	equ	$40
KEY_RETURN	equ	$44
KEY_BACK	equ	$41
KEY_DEL		equ	$46
KEY_UP		equ	$4c
KEY_DOWN	equ	$4d
KEY_RIGHT	equ	$4e
KEY_LEFT	equ	$4f
KEY_A		equ	$20
KEY_D		equ	$22
KEY_S		equ	$21
KEY_W		equ	$11
KEY_T		equ	$14
KEY_P		equ	$19
KEY_Q		equ	$10
KEY_M		equ	$37
KEY_Y		equ	$15
KEY_N		equ	$36
KEY_F1		equ	$50

; ---------------- screen layout ----------------
PF1W		equ	84		; bytes per plane row (672 px)
PF1ROW		equ	PF1W*3
PF2W		equ	48		; bytes per plane row (384 px)
PF2ROW		equ	PF2W*3
LOGO_Y		equ	22

; ---------------- colours (playfield 2) ----------------
C_WHITE		equ	1
C_GREEN		equ	2
C_YELLOW	equ	3
C_MAGENTA	equ	4
C_ORANGE	equ	5
C_BLUE		equ	6
C_DARK		equ	7

;=====================================================================
	section	code,code
;=====================================================================
Start:
	movem.l	d1-d7/a0-a6,-(sp)
	bsr	SysInit
	tst.l	d0
	bne.s	.fail
	lea	CUSTOM,a5
	bsr	InitAll
	bsr	MainMenuLoop
	bsr	SysExit
.fail:	movem.l	(sp)+,d1-d7/a0-a6
	moveq	#0,d0
	rts

InitAll:
	bsr	InitFadeTab
	bsr	InitDoubleTab
	bsr	InitWaitTab
	bsr	InitColFont
	move.l	#PF2BufA,FrontBuf
	move.l	#PF2BufB,BackBuf
	move.l	#CopListA,CopShown
	move.l	#CopListB,CopNext
	move.w	#16,ClipTop
	move.w	#248,ClipBottom
	move.b	#$ff,LastKey
	move.w	#1,MusicOn
	move.w	#16,BgFade
	move.w	HiData+HISIZE-4,Difficulty
	cmp.w	#3,Difficulty
	blo.s	.dok
	move.w	#1,Difficulty
.dok:
	move.l	#$2f6e2b1d,d0
	add.l	FrameCount,d0
	move.w	VHPOSR(a5),d1
	swap	d1
	eor.l	d1,d0
	bne.s	.s
	moveq	#1,d0
.s:	move.l	d0,RandSeed
	move.w	#3,d0
	bsr	SetScene
	bsr	ClearBoth
	clr.w	Fade
	rts

;---------------------------------------------------------------------
; file: system.s
;---------------------------------------------------------------------
;=====================================================================
; GHOST ZAPPERS - Amiga 500 version
; system.s : hardware takeover, frame loop, copper, input, disk I/O
;=====================================================================

;---------------------------------------------------------------------
; Startup: called once from Start (a6 = execbase)
;---------------------------------------------------------------------
SysInit:
	move.l	4.w,a6
	move.l	a6,ExecBase
	sub.l	a1,a1
	jsr	-294(a6)			; FindTask(0)
	move.l	d0,a4
	tst.l	172(a4)				; pr_CLI
	bne.s	.cli
	lea	92(a4),a0			; pr_MsgPort
	jsr	-384(a6)			; WaitPort
	lea	92(a4),a0
	jsr	-372(a6)			; GetMsg
	move.l	d0,WBMsg
.cli:
	lea	GfxName,a1
	jsr	-408(a6)			; OldOpenLibrary
	move.l	d0,GfxBase
	beq	.fail
	lea	DosName,a1
	jsr	-408(a6)
	move.l	d0,DosBase
	beq	.fail
	bsr	LoadHighscores
	bsr	TakeSystem
	moveq	#0,d0
	rts
.fail:	moveq	#-1,d0
	rts

SysExit:
	bsr	ReleaseSystem
	move.l	ExecBase,a6
	move.l	DosBase,d0
	beq.s	.nodos
	move.l	d0,a1
	jsr	-414(a6)			; CloseLibrary
.nodos:	move.l	GfxBase,d0
	beq.s	.nogfx
	move.l	d0,a1
	jsr	-414(a6)
.nogfx:	move.l	WBMsg,d0
	beq.s	.nowb
	jsr	-132(a6)			; Forbid
	move.l	d0,a1
	jsr	-378(a6)			; ReplyMsg
.nowb:	rts

;---------------------------------------------------------------------
; TakeSystem: switch off the OS display / interrupts and take over
;---------------------------------------------------------------------
TakeSystem:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	GfxBase,a6
	move.l	34(a6),OldView			; gb_ActiView
	sub.l	a1,a1
	jsr	-222(a6)			; LoadView(NULL)
	jsr	-270(a6)			; WaitTOF
	jsr	-270(a6)
	move.l	ExecBase,a6
	jsr	-132(a6)			; Forbid
	lea	CUSTOM,a5
	move.w	DMACONR(a5),OldDma
	move.w	INTENAR(a5),OldInt
	move.w	ADKCONR(a5),OldAdk
	bsr	WaitVBL
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)
	move.w	#$00ff,ADKCON(a5)
	move.w	#0,AUD0VOL(a5)
	move.w	#0,AUD1VOL(a5)
	move.w	#0,AUD2VOL(a5)
	move.w	#0,AUD3VOL(a5)
	; build both copper lists and start display
	bsr	BuildCopper
	move.l	CopNext,COP1LC(a5)
	move.w	d0,COPJMP1(a5)
	move.w	#$83e0,DMACON(a5)		; DMAEN|BPLEN|COPEN|BLTEN|SPREN (null sprites)
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---------------------------------------------------------------------
; ReleaseSystem: give the machine back to the OS
;---------------------------------------------------------------------
ReleaseSystem:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a5
	bsr	WaitBlit
	bsr	WaitVBL
	move.w	#$7fff,DMACON(a5)
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#0,AUD0VOL(a5)
	move.w	#0,AUD1VOL(a5)
	move.w	#0,AUD2VOL(a5)
	move.w	#0,AUD3VOL(a5)
	move.l	GfxBase,a6
	move.l	38(a6),COP1LC(a5)		; gb_copinit
	move.w	d0,COPJMP1(a5)
	move.w	OldAdk,d0
	or.w	#$8000,d0
	move.w	#$7fff,ADKCON(a5)
	move.w	d0,ADKCON(a5)
	move.w	OldDma,d0
	or.w	#$8000,d0
	move.w	d0,DMACON(a5)
	move.w	OldInt,d0
	or.w	#$c000,d0
	move.w	d0,INTENA(a5)
	move.l	OldView,a1
	jsr	-222(a6)			; LoadView(old)
	jsr	-270(a6)
	jsr	-270(a6)
	move.l	ExecBase,a6
	jsr	-138(a6)			; Permit
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---------------------------------------------------------------------
; Highscore file (uses dos.library - only while the OS is running)
;---------------------------------------------------------------------
LoadHighscores:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	HiDefault,a0
	lea	HiData,a1
	move.w	#HISIZE-1,d0
.def:	move.b	(a0)+,(a1)+
	dbf	d0,.def
	move.l	DosBase,a6
	move.l	#HiName,d1
	move.l	#1005,d2			; MODE_OLDFILE
	jsr	-30(a6)				; Open
	move.l	d0,d7
	beq.s	.none
	move.l	d7,d1
	move.l	#HiBuffer,d2
	move.l	#HISIZE,d3
	jsr	-42(a6)				; Read
	move.l	d0,d6
	move.l	d7,d1
	jsr	-36(a6)				; Close
	cmp.l	#HISIZE,d6
	bne.s	.none
	cmp.l	#HIMAGIC,HiBuffer
	bne.s	.none
	lea	HiBuffer,a0
	lea	HiData,a1
	move.w	#HISIZE-1,d0
.cp:	move.b	(a0)+,(a1)+
	dbf	d0,.cp
.none:	movem.l	(sp)+,d0-d7/a0-a6
	rts

SaveHighscores:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	ReleaseSystem
	move.l	DosBase,a6
	move.l	#HiName,d1
	move.l	#1006,d2			; MODE_NEWFILE
	jsr	-30(a6)
	move.l	d0,d7
	beq.s	.fail
	move.l	d7,d1
	move.l	#HiData,d2
	move.l	#HISIZE,d3
	jsr	-48(a6)				; Write
	move.l	d7,d1
	jsr	-36(a6)				; Close
.fail:	bsr	TakeSystem
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---------------------------------------------------------------------
; Wait for the vertical blank (raster line 300)
;---------------------------------------------------------------------
WaitVBL:
	move.l	d0,-(sp)
WaitVBL_loop1:
	move.l	VPOSR(a5),d0
	and.l	#$1ff00,d0
	cmp.l	#$12c00,d0
	bne.s	WaitVBL_loop1
WaitVBL_loop2:
	move.l	VPOSR(a5),d0
	and.l	#$1ff00,d0
	cmp.l	#$12c00,d0
	beq.s	WaitVBL_loop2
WaitVBL_end:
	move.l	(sp)+,d0
	rts

WaitBlit:
	tst.w	DMACONR(a5)
WaitBlit_loop:
	btst	#6,DMACONR(a5)
	bne.s	WaitBlit_loop
WaitBlit_end:
	rts

;---------------------------------------------------------------------
; Frame: finish drawing, show the back buffer, wait VBL, run audio/input
;---------------------------------------------------------------------
Frame:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	WaitBlit
	bsr	BuildCopper
	bsr	WaitVBL
	move.l	CopNext,COP1LC(a5)
	; swap PF2 buffers and copper lists
	move.l	FrontBuf,d0
	move.l	BackBuf,FrontBuf
	move.l	d0,BackBuf
	move.l	CopNext,d0
	move.l	CopShown,CopNext
	move.l	d0,CopShown
	addq.l	#1,FrameCount
	bsr	MusicTick
	bsr	SfxTick
	bsr	ReadInput
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---------------------------------------------------------------------
; BuildCopper: write the copper list CopNext for the BackBuf
;---------------------------------------------------------------------
BuildCopper:
	movem.l	d0-d7/a0-a4/a6,-(sp)
	bsr	UpdatePalCache
	move.l	CopNext,a0
	move.l	#$008e2c81,(a0)+		; DIWSTRT
	move.l	#$00902cc1,(a0)+		; DIWSTOP
	move.l	#$00920030,(a0)+		; DDFSTRT (one extra word for scrolling)
	move.l	#$009400d0,(a0)+		; DDFSTOP
	move.l	#$010800d2,(a0)+		; BPL1MOD = 252-42
	move.l	#$010a0066,(a0)+		; BPL2MOD = 144-42
	move.l	#$01040040,(a0)+		; BPLCON2: playfield 2 in front
	move.l	#$01006600,(a0)+		; BPLCON0: 6 planes, dual playfield, colour
	move.l	#$01020000,(a0)+		; BPLCON1
	; sprites -> null sprite
	move.l	#NullSprite,d0
	move.w	#$0120,d1
	moveq	#7,d2
.spr:	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	dbf	d2,.spr
	; playfield 2 pointers (planes 2,4,6)
	move.l	BackBuf,d0
	move.w	#$00e4,d1
	moveq	#2,d2
.pf2:	swap	d0
	move.w	d1,(a0)+
	move.w	d0,(a0)+
	addq.w	#2,d1
	swap	d0
	move.w	d1,(a0)+
	move.w	d0,(a0)+
	addq.w	#6,d1
	add.l	#PF2W,d0
	dbf	d2,.pf2
	; colours 9..15 and 1..7 from the cache
	lea	PalCache,a1
	move.w	#$0190,d3
	moveq	#7,d2
.c2:	move.w	d3,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d3
	dbf	d2,.c2
	move.w	#$0182,d3
	moveq	#6,d2
.c1:	move.w	d3,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d3
	dbf	d2,.c1
	move.l	#$01800000,(a0)+		; COLOR00 black for the top HUD
	moveq	#0,d4
	moveq	#0,d5
	bsr	CopBand
	lea	SkyCache,a1
	tst.w	FlashCol
	beq.s	.nf
	lea	FlashSky,a1
	move.w	FlashCol,d0
	moveq	#57,d1
.fl:	move.w	d0,(a1)+
	dbf	d1,.fl
	lea	FlashSky,a1
.nf:	lea	WaitTab,a3
	tst.w	LogoGrad
	bne	.logo
	moveq	#24-1,d6			; y 16..108
	bsr	CopSky
	move.w	ScrollFar,d5			; y 112
	bsr	CopBandStep
	moveq	#9-1,d6				; y 116..148
	bsr	CopSky
	move.w	ScrollNear,d5			; y 152
	bsr	CopBandStep
	moveq	#19-1,d6			; y 156..228
	bsr	CopSky
	move.w	ScrollStreet,d5			; y 232
	bsr	CopBandStep
	moveq	#3-1,d6				; y 236..244
	bsr	CopSky
	bra	.skyend
.logo:	; title screens: no parallax bands below 112 change, logo gradient on colour 14
	lea	LogoCache,a2
	moveq	#16,d6
.sky:	move.w	(a3)+,(a0)+
	move.w	#$fffe,(a0)+
	cmp.w	#112,d6
	bne.s	.nb1
	move.w	d6,d4
	move.w	ScrollFar,d5
	bsr	CopBand
.nb1:	cmp.w	#152,d6
	bne.s	.nb2
	move.w	d6,d4
	move.w	ScrollNear,d5
	bsr	CopBand
.nb2:	cmp.w	#232,d6
	bne.s	.nb3
	move.w	d6,d4
	move.w	ScrollStreet,d5
	bsr	CopBand
.nb3:	move.w	#$0180,(a0)+
	move.w	(a1)+,(a0)+
	cmp.w	#LOGO_Y,d6
	blt.s	.nologo
	cmp.w	#LOGO_Y+LOGO_H,d6
	bge.s	.nologo
	move.w	d6,d0
	sub.w	#LOGO_Y,d0
	add.w	LogoPhase,d0
	lsr.w	#1,d0
	and.w	#31,d0
	add.w	d0,d0
	move.w	#$019c,(a0)+
	move.w	(a2,d0.w),(a0)+
.nologo:
	addq.w	#4,d6
	cmp.w	#248,d6
	bne.s	.sky
.skyend:
	move.w	(a3)+,(a0)+			; wait for y = 248
	move.w	#$fffe,(a0)+
	move.l	#$01800000,(a0)+		; black bottom HUD
	move.w	#$019c,(a0)+			; restore colour 14
	move.w	PalCache+12,(a0)+
	move.l	#$fffffffe,(a0)+
	movem.l	(sp)+,d0-d7/a0-a4/a6
	rts

; CopBandStep: WAIT for the band line, band pointers (row d4 derived
; from the wait table position), then the sky colour.  d5 = scroll
CopBandStep:
	move.l	a3,d4
	sub.l	#WaitTab,d4
	add.w	d4,d4				; index*2 bytes -> y-16 = index*4
	add.w	#16,d4
	move.w	(a3)+,(a0)+
	move.w	#$fffe,(a0)+
	bsr	CopBand
	move.w	#$0180,(a0)+
	move.w	(a1)+,(a0)+
	rts

; CopSky: d6+1 steps of (WAIT, COLOR00) from a3 (waits) and a1 (colours)
CopSky:
	move.w	#$fffe,d1
	move.w	#$0180,d2
.l:	move.w	(a3)+,(a0)+
	move.w	d1,(a0)+
	move.w	d2,(a0)+
	move.w	(a1)+,(a0)+
	dbf	d6,.l
	rts

; InitWaitTab: WAIT words for y = 16,20,...,248 (line-1, h=$df)
InitWaitTab:
	lea	WaitTab,a0
	moveq	#16,d0
.l:	move.w	d0,d1
	add.w	#$2c-1,d1
	lsl.w	#8,d1
	or.w	#$df,d1
	move.w	d1,(a0)+
	addq.w	#4,d0
	cmp.w	#252,d0
	bne.s	.l
	rts

; UpdatePalCache: refresh faded colours when fade / scene changed
UpdatePalCache:
	move.w	Fade,d0
	swap	d0
	move.w	BgFade,d0
	cmp.l	PalKey,d0
	bne.s	.go
	move.l	ScenePal,d1
	cmp.l	PalKeyScene,d1
	bne.s	.go
	rts
.go:	move.l	d0,PalKey
	move.l	ScenePal,PalKeyScene
	lea	FadeTab,a3
	move.w	Fade,d0
	lsl.w	#4,d0
	add.w	d0,a3
	move.l	a3,a4				; playfield 2 fade
	lea	PalCache,a0
	lea	PF2Pal,a1
	moveq	#7,d2
.c2:	move.w	(a1)+,d0
	bsr	FadeCol
	move.w	d0,(a0)+
	dbf	d2,.c2
	lea	FadeTab,a3
	move.w	Fade,d0
	cmp.w	BgFade,d0
	ble.s	.bgf
	move.w	BgFade,d0
.bgf:	lsl.w	#4,d0
	add.w	d0,a3
	move.l	ScenePal,a1
	moveq	#6,d2
.c1:	move.w	(a1)+,d0
	bsr	FadeCol
	move.w	d0,(a0)+
	dbf	d2,.c1
	move.l	ScenePal,a1
	lea	16(a1),a1
	lea	SkyCache,a0
	moveq	#57,d2
.s:	move.w	(a1)+,d0
	bsr	FadeCol
	move.w	d0,(a0)+
	dbf	d2,.s
	move.l	a4,a3
	lea	LogoColours,a1
	lea	LogoCache,a0
	moveq	#31,d2
.l:	move.w	(a1)+,d0
	bsr	FadeCol
	move.w	d0,(a0)+
	dbf	d2,.l
	rts

; CopBand: d4 = first row, d5 = scroll position 0..319 -> PF1 pointers + BPLCON1
CopBand:
	move.w	d5,d0
	add.w	#15,d0
	lsr.w	#4,d0				; P = (s+15)>>4
	move.w	d0,d1
	lsl.w	#4,d1
	sub.w	d5,d1				; delay = P*16-s
	add.w	d0,d0
	ext.l	d0
	move.w	d4,d7
	mulu	#PF1ROW,d7
	add.l	d7,d0
	add.l	#PF1Buf,d0
	move.w	#$00e0,d7
	moveq	#2,d2
.bp:	swap	d0
	move.w	d7,(a0)+
	move.w	d0,(a0)+
	addq.w	#2,d7
	swap	d0
	move.w	d7,(a0)+
	move.w	d0,(a0)+
	addq.w	#6,d7
	add.l	#PF1W,d0
	dbf	d2,.bp
	move.w	#$0102,(a0)+
	move.w	d1,(a0)+
	rts

; FadeCol: d0 = $0RGB -> faded via a3 (FadeTab row)
FadeCol:
	movem.l	d1-d2,-(sp)
	move.w	d0,d1
	and.w	#$f,d1
	move.b	(a3,d1.w),d2			; blue
	move.w	d0,d1
	lsr.w	#4,d1
	and.w	#$f,d1
	move.b	(a3,d1.w),d1
	lsl.w	#4,d1
	or.b	d1,d2
	lsr.w	#8,d0
	and.w	#$f,d0
	move.b	(a3,d0.w),d0
	lsl.w	#8,d0
	and.w	#$00ff,d2
	or.w	d2,d0
	movem.l	(sp)+,d1-d2
	rts

InitFadeTab:
	lea	FadeTab,a0
	moveq	#0,d1				; level 0..16
.lv:	moveq	#0,d2				; component
.cp:	move.w	d2,d0
	mulu	d1,d0
	lsr.w	#4,d0
	move.b	d0,(a0)+
	addq.w	#1,d2
	cmp.w	#16,d2
	bne.s	.cp
	addq.w	#1,d1
	cmp.w	#17,d1
	bne.s	.lv
	rts

;---------------------------------------------------------------------
; Scenes: unpack background into PF1 and select palette
; d0 = scene (0 jfk,1 harbor,2 liberty,3 manhattan,4 harlem,5 map,6 flight)
;---------------------------------------------------------------------
SetScene:
	movem.l	d0-d2/a0-a1,-(sp)
	move.w	d0,Scene
	move.w	d0,d1
	mulu	#(8+58)*2,d1
	lea	PalTable,a0
	add.l	d1,a0
	move.l	a0,ScenePal
	lsl.w	#2,d0
	lea	BgTable,a0
	move.l	(a0,d0.w),a0
	lea	PF1Buf,a1
	bsr	UnpackBits
	clr.w	ScrollPos
	clr.w	ScrollFar
	clr.w	ScrollNear
	clr.w	ScrollStreet
	movem.l	(sp)+,d0-d2/a0-a1
	rts

; PackBits decoder a0 = src, a1 = dest
UnpackBits:
	moveq	#0,d0
.next:	move.b	(a0)+,d0
	cmp.b	#128,d0
	beq.s	.done
	bhi.s	.run
.lit:	move.b	(a0)+,(a1)+
	dbf	d0,.lit
	moveq	#0,d0
	bra.s	.next
.run:	neg.b	d0				; 257-n = -n+1 -> dbf count = -n
	move.b	(a0)+,d1
.rl:	move.b	d1,(a1)+
	dbf	d0,.rl
	moveq	#0,d0
	bra.s	.next
.done:	rts

; Scroll the city by d0 pixels (parallax: far 1/4, near 1/2, street 1/1)
; uses ScrollPos (fixed 4.4)
ScrollCity:
	movem.l	d0-d1,-(sp)
	add.w	ScrollPos,d0
	cmp.w	#320*4,d0
	blt.s	.ok
	sub.w	#320*4,d0
.ok:	move.w	d0,ScrollPos
	move.w	d0,d1
	lsr.w	#2,d1				; street: pos/4  (pos is in 1/4 px)
	move.w	d1,ScrollStreet
	move.w	d0,d1
	lsr.w	#3,d1				; near: half speed
	move.w	d1,ScrollNear
	lsr.w	#4,d0				; far: quarter speed
	move.w	d0,ScrollFar
	movem.l	(sp)+,d0-d1
	rts

;---------------------------------------------------------------------
; Fades
;---------------------------------------------------------------------
FadeOut:
	move.l	d0,-(sp)
.l:	tst.w	Fade
	beq.s	.d
	subq.w	#1,Fade
	bsr	Frame
	bra.s	.l
.d:	bsr	Frame
	move.l	(sp)+,d0
	rts
FadeIn:
	move.l	d0,-(sp)
.l:	cmp.w	#16,Fade
	beq.s	.d
	addq.w	#1,Fade
	bsr	Frame
	bra.s	.l
.d:	move.l	(sp)+,d0
	rts

;---------------------------------------------------------------------
; Input: joystick port 2 + keyboard -> Joy (bits) and JoyNew (edges)
;---------------------------------------------------------------------
J_LEFT	equ	0
J_RIGHT	equ	1
J_UP	equ	2
J_DOWN	equ	3
J_FIRE	equ	4

ReadInput:
	movem.l	d0-d3/a0,-(sp)
	bsr	ReadKeyboard
	moveq	#0,d1
	move.w	JOY1DAT(a5),d0
	btst	#1,d0
	beq.s	.nr
	bset	#J_RIGHT,d1
.nr:	btst	#9,d0
	beq.s	.nl
	bset	#J_LEFT,d1
.nl:	move.w	d0,d2
	lsr.w	#1,d2
	eor.w	d0,d2
	btst	#8,d2
	beq.s	.nu
	bset	#J_UP,d1
.nu:	btst	#0,d2
	beq.s	.nd
	bset	#J_DOWN,d1
.nd:	btst	#7,CIAA_PRA
	bne.s	.nf
	bset	#J_FIRE,d1
.nf:	lea	KeyMap,a0
	tst.b	KEY_A(a0)
	bne.s	.kl
	tst.b	KEY_LEFT(a0)
	beq.s	.nkl
.kl:	bset	#J_LEFT,d1
.nkl:	tst.b	KEY_D(a0)
	bne.s	.kr
	tst.b	KEY_RIGHT(a0)
	beq.s	.nkr
.kr:	bset	#J_RIGHT,d1
.nkr:	tst.b	KEY_T(a0)
	bne.s	.ku
	tst.b	KEY_UP(a0)
	bne.s	.ku
	tst.b	KEY_W(a0)
	beq.s	.nku
.ku:	bset	#J_UP,d1
.nku:	tst.b	KEY_DOWN(a0)
	bne.s	.kd
	tst.b	KEY_S(a0)
	beq.s	.nkd
.kd:	bset	#J_DOWN,d1
.nkd:	tst.b	KEY_SPACE(a0)
	beq.s	.nks
	bset	#J_FIRE,d1
.nks:	tst.b	KEY_RETURN(a0)
	beq.s	.nkt
	bset	#J_FIRE,d1
.nkt:	move.w	Joy,d0
	move.w	d1,Joy
	not.w	d0
	and.w	d1,d0
	move.w	d0,JoyNew
	movem.l	(sp)+,d0-d3/a0
	rts

; Keyboard: polled CIA-A serial port with manual handshake
ReadKeyboard:
	movem.l	d0-d1/a0,-(sp)
	move.b	CIAA_ICR,d0
	btst	#3,d0
	beq.s	.none
	move.b	CIAA_SDR,d0
	bset	#6,CIAA_CRA			; handshake (SP output low)
	move.b	VHPOSR(a5),d1
.w1:	cmp.b	VHPOSR(a5),d1
	beq.s	.w1
	move.b	VHPOSR(a5),d1
.w2:	cmp.b	VHPOSR(a5),d1
	beq.s	.w2
	move.b	VHPOSR(a5),d1
.w3:	cmp.b	VHPOSR(a5),d1
	beq.s	.w3
	bclr	#6,CIAA_CRA
	not.b	d0
	ror.b	#1,d0
	moveq	#0,d1
	move.b	d0,d1
	and.w	#$7f,d1
	lea	KeyMap,a0
	tst.b	d0
	bmi.s	.up
	st	(a0,d1.w)
	move.b	d1,LastKey
	bra.s	.none
.up:	clr.b	(a0,d1.w)
.none:	movem.l	(sp)+,d0-d1/a0
	rts

; GetKey: returns raw key code of last key press in d0 (or -1) and clears it
GetKey:
	moveq	#0,d0
	move.b	LastKey,d0
	move.b	#$ff,LastKey
	cmp.b	#$ff,d0
	bne.s	.r
	moveq	#-1,d0
.r:	rts

; RawToAscii: d0 raw -> d0 ascii (0 if none)
RawToAscii:
	cmp.w	#$40,d0
	bhs.s	.z
	lea	RawAscii,a0
	move.b	(a0,d0.w),d0
	ext.w	d0
	rts
.z:	moveq	#0,d0
	rts

;---------------------------------------------------------------------
; Random number (xorshift32) -> d0
;---------------------------------------------------------------------
Random:
	move.l	d1,-(sp)
	move.l	RandSeed,d0
	move.l	d0,d1
	lsl.l	#8,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,d1
	swap	d1
	lsr.w	#1,d1
	and.l	#$7fff,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,RandSeed
	move.l	(sp)+,d1
	rts

; RandRange: d0 = max (exclusive, < 32768) -> d0 = 0..max-1
RandRange:
	move.l	d1,-(sp)
	move.w	d0,d1
	bsr	Random
	and.l	#$7fff,d0
	divu	d1,d0
	swap	d0
	and.l	#$ffff,d0
	move.l	(sp)+,d1
	rts

;---------------------------------------------------------------------
; file: gfx.s
;---------------------------------------------------------------------
;=====================================================================
; gfx.s : playfield 2 drawing - blitter bobs, clears, text, numbers
; PF2 is interleaved: row = 3 planes x 48 bytes (PF2ROW = 144)
; bitmap x = screen x + 16 (16 hidden pixels left)
;=====================================================================

; ClearRows: d0 = first y, d1 = number of rows, a1 = buffer
ClearRows:
	movem.l	d0-d2/a1,-(sp)
	tst.w	d1
	ble.s	.x
	mulu	#PF2ROW,d0
	add.l	d0,a1
	bsr	WaitBlit
	move.l	#$01000000,BLTCON0(a5)		; D only, minterm 0
	move.w	#0,BLTDMOD(a5)
	move.l	a1,BLTDPT(a5)
	move.w	d1,d2
	mulu	#3,d2
	lsl.w	#6,d2
	or.w	#PF2W/2,d2
	move.w	d2,BLTSIZE(a5)
.x:	movem.l	(sp)+,d0-d2/a1
	rts

ClearBack:
	movem.l	d0-d1/a1,-(sp)
	moveq	#16,d0
	move.w	#232,d1
	move.l	BackBuf,a1
	bsr	ClearRows
	movem.l	(sp)+,d0-d1/a1
	rts

ClearBoth:
	movem.l	d0-d1/a1,-(sp)
	clr.w	DirtyCountA
	clr.w	DirtyCountB
	move.w	#-1,EnergyShownA
	move.w	#-1,EnergyShownB
	moveq	#0,d0
	move.w	#256,d1
	move.l	BackBuf,a1
	bsr	ClearRows
	move.l	FrontBuf,a1
	bsr	ClearRows
	bsr	WaitBlit
	movem.l	(sp)+,d0-d1/a1
	rts

; CopyBackToFront: make both buffers identical (after drawing static screens)
CopyBuffers:
	movem.l	d0-d2,-(sp)
	bsr	WaitBlit
	move.l	#$09f00000,BLTCON0(a5)		; A -> D
	move.l	#$ffffffff,BLTAFWM(a5)
	move.w	#0,BLTAMOD(a5)
	move.w	#0,BLTDMOD(a5)
	move.l	BackBuf,BLTAPT(a5)
	move.l	FrontBuf,BLTDPT(a5)
	move.w	#(768<<6)|(PF2W/2),BLTSIZE(a5)	; 256 rows x 3 planes
	bsr	WaitBlit
	movem.l	(sp)+,d0-d2
	rts

;---------------------------------------------------------------------
; Dirty rectangles: everything drawn into the back buffer is logged and
; erased (blitter, D only) the next time this buffer becomes the back
; buffer.  AddDirty: a2 = start address (even), d0 = BLTSIZE, d1 = modulo
;---------------------------------------------------------------------
AddDirty:
	movem.l	d2/a0-a1,-(sp)
	lea	DirtyA,a0
	lea	DirtyCountA,a1
	cmp.l	#PF2BufA,BackBuf
	beq.s	.a
	lea	DirtyB,a0
	lea	DirtyCountB,a1
.a:	move.w	(a1),d2
	cmp.w	#MAXDIRTY,d2
	bge.s	.x
	addq.w	#1,(a1)
	lsl.w	#3,d2
	add.w	d2,a0
	move.l	a2,(a0)+
	move.w	d0,(a0)+
	move.w	d1,(a0)+
.x:	movem.l	(sp)+,d2/a0-a1
	rts

ClearDirty:
	movem.l	d0-d2/a0-a1,-(sp)
	lea	DirtyA,a0
	lea	DirtyCountA,a1
	cmp.l	#PF2BufA,BackBuf
	beq.s	.a
	lea	DirtyB,a0
	lea	DirtyCountB,a1
.a:	move.w	(a1),d2
	clr.w	(a1)
	subq.w	#1,d2
	bmi.s	.x
	bsr	WaitBlit
	move.l	#$01000000,BLTCON0(a5)
.l:	bsr	WaitBlit
	move.l	(a0)+,BLTDPT(a5)
	move.w	(a0)+,d0
	move.w	(a0)+,BLTDMOD(a5)
	move.w	d0,BLTSIZE(a5)
	dbf	d2,.l
.x:	movem.l	(sp)+,d0-d2/a0-a1
	rts

;---------------------------------------------------------------------
; DrawBob: d0 = bob index, d1 = screen x, d2 = screen y (into BackBuf)
; clipped vertically to 16..247; skipped when off screen horizontally
;---------------------------------------------------------------------
DrawBob:
	movem.l	d0-d7/a0-a2,-(sp)
	move.l	BackBuf,a2
	st	BobDirty
	bsr.s	BobCore
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; DrawBobBoth: draw into both buffers (static screens, not logged)
DrawBobBoth:
	movem.l	d0-d7/a0-a2,-(sp)
	move.l	BackBuf,a2
	sf	BobDirty
	bsr.s	BobCore
	movem.l	(sp),d0-d7/a0-a2
	move.l	FrontBuf,a2
	sf	BobDirty
	bsr.s	BobCore
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; BobCore: a2 = buffer, d0 bob, d1 x, d2 y (clobbers registers)
BobCore:
	lea	BobTable,a0
	lsl.w	#4,d0
	add.w	d0,a0
	move.l	(a0)+,d6			; data
	move.l	(a0)+,d7			; mask
	move.w	(a0)+,d3			; words
	move.w	(a0)+,d4			; height
	; vertical clip
	move.w	ClipTop,d0
	cmp.w	d0,d2
	bge.s	.ct
	sub.w	d2,d0				; rows to skip
	cmp.w	d4,d0
	bge	.out
	sub.w	d0,d4
	move.w	d3,d5
	mulu	#6,d5				; bytes per bob row (3 planes)
	mulu	d0,d5
	add.l	d5,d6
	add.l	d5,d7
	move.w	ClipTop,d2
.ct:	move.w	d2,d0
	add.w	d4,d0
	cmp.w	ClipBottom,d0
	ble.s	.cb
	move.w	ClipBottom,d4
	sub.w	d2,d4
	ble	.out
.cb:	; horizontal
	add.w	#16,d1
	bmi	.out
	move.w	d3,d0
	addq.w	#1,d0
	lsl.w	#4,d0
	neg.w	d0
	add.w	#PF2W*8,d0
	cmp.w	d0,d1
	bgt	.out
	; dest
	move.w	d2,d0
	mulu	#PF2ROW,d0
	move.w	d1,d5
	lsr.w	#4,d5
	add.w	d5,d5
	add.w	d5,d0
	add.l	d0,a2
	and.w	#15,d1
	ror.w	#4,d1				; shift in bits 15-12
	bsr	WaitBlit
	move.w	d1,d0
	or.w	#$0fca,d0
	move.w	d0,BLTCON0(a5)
	move.w	d1,BLTCON1(a5)
	move.l	#$ffff0000,BLTAFWM(a5)
	move.w	#-2,BLTAMOD(a5)
	move.w	#-2,BLTBMOD(a5)
	move.w	d3,d0
	addq.w	#1,d0
	add.w	d0,d0
	neg.w	d0
	add.w	#PF2W,d0
	move.w	d0,BLTCMOD(a5)
	move.w	d0,BLTDMOD(a5)
	move.l	d7,BLTAPT(a5)
	move.l	d6,BLTBPT(a5)
	move.l	a2,BLTCPT(a5)
	move.l	a2,BLTDPT(a5)
	move.w	d4,d0
	mulu	#3,d0
	lsl.w	#6,d0
	addq.w	#1,d3
	or.w	d3,d0
	move.w	d0,BLTSIZE(a5)
	tst.b	BobDirty
	beq.s	.out
	move.w	d3,d1
	add.w	d1,d1
	neg.w	d1
	add.w	#PF2W,d1
	bsr	AddDirty
.out:	rts

; BobSize: d0 = bob -> d1 = width px, d2 = height
BobSize:
	move.l	a0,-(sp)
	lea	BobTable,a0
	lsl.w	#4,d0
	add.w	d0,a0
	move.w	10(a0),d2
	move.w	12(a0),d1
	lsr.w	#4,d0
	move.l	(sp)+,a0
	rts

;---------------------------------------------------------------------
; FillRect: d0 = x (multiple of 8), d1 = y, d2 = width (multiple of 8),
; d3 = height, d4 = colour (0..7), a1 = buffer.  CPU byte fill.
;---------------------------------------------------------------------
FillRect:
	movem.l	d0-d7/a0-a1,-(sp)
	bsr	WaitBlit
	mulu	#PF2ROW,d1
	add.l	d1,a1
	lsr.w	#3,d0
	addq.w	#2,d0
	add.w	d0,a1
	lsr.w	#3,d2
	subq.w	#1,d2
	subq.w	#1,d3
	bmi.s	.x
.row:	moveq	#0,d5				; plane
	move.l	a1,a0
.pl:	moveq	#0,d6
	btst	d5,d4
	beq.s	.z
	moveq	#-1,d6
.z:	move.w	d2,d7
	move.l	a0,-(sp)
.b:	move.b	d6,(a0)+
	dbf	d7,.b
	move.l	(sp)+,a0
	add.w	#PF2W,a0
	addq.w	#1,d5
	cmp.w	#3,d5
	bne.s	.pl
	add.w	#PF2ROW,a1
	dbf	d3,.row
.x:	movem.l	(sp)+,d0-d7/a0-a1
	rts

;---------------------------------------------------------------------
; Text.  Print: a0 = string (0 terminated), d0 = column (0..39),
; d1 = y (pixels), d2 = colour (0..7), a1 = buffer
; '\n' (10) moves to the next line (8 px) at the start column.
; Uses ColFont: per colour, per char 8 rows x 3 plane bytes.
;---------------------------------------------------------------------
InitColFont:
	lea	ColFont,a1
	moveq	#0,d2				; colour
.col:	lea	Font,a0
	move.w	#96*8-1,d3
.row:	move.b	(a0)+,d0
	moveq	#2,d4
	moveq	#0,d5
.pl:	moveq	#0,d1
	btst	d5,d2
	beq.s	.z
	move.b	d0,d1
.z:	move.b	d1,(a1)+
	addq.w	#1,d5
	dbf	d4,.pl
	dbf	d3,.row
	addq.w	#1,d2
	cmp.w	#8,d2
	bne.s	.col
	rts

Print:
	movem.l	d0-d7/a0-a3,-(sp)
	bsr	WaitBlit
	cmp.l	BackBuf,a1
	bne.s	.nod
	tst.b	NoDirty
	bne.s	.nod
	bsr	PrintDirty
.nod:	lea	ColFont,a3
	and.w	#7,d2
	mulu	#96*24,d2
	add.l	d2,a3
	move.l	a1,d2				; d2 = buffer
	move.w	d0,d7				; start column
.line:	move.w	d1,d3
	mulu	#PF2ROW,d3
	move.l	d2,a2
	add.l	d3,a2
	add.w	d0,a2
	addq.w	#2,a2				; a2 = destination of this column
.ch:	moveq	#0,d3
	move.b	(a0)+,d3
	beq.s	.done
	cmp.b	#10,d3
	beq.s	.nl
	cmp.w	#40,d0
	bge.s	.skip
	sub.w	#32,d3
	bmi.s	.skip
	mulu	#24,d3
	lea	(a3,d3.w),a1		; glyph rows
	move.l	a2,d6
	moveq	#7,d4
.r:	move.b	(a1)+,(a2)
	move.b	(a1)+,PF2W(a2)
	move.b	(a1)+,PF2W*2(a2)
	lea	PF2ROW(a2),a2
	dbf	d4,.r
	move.l	d6,a2
.skip:	addq.w	#1,d0
	addq.l	#1,a2
	bra.s	.ch
.nl:	move.w	d7,d0
	addq.w	#8,d1
	bra.s	.line
.done:	movem.l	(sp)+,d0-d7/a0-a3
	rts

; PrintDirty: log the area of string a0 at column d0, y d1 (single line;
; multi-line strings log 8 rows per line)
PrintDirty:
	movem.l	d0-d3/a0-a2,-(sp)
	cmp.w	#16,d1
	blt.s	.x
	cmp.w	#248,d1
	bge.s	.x
.line:	moveq	#0,d2
.len:	move.b	(a0)+,d3
	beq.s	.go
	cmp.b	#10,d3
	beq.s	.go
	addq.w	#1,d2
	bra.s	.len
.go:	tst.w	d2
	beq.s	.nxt
	move.w	d1,d3
	mulu	#PF2ROW,d3
	move.l	a1,a2
	add.l	d3,a2
	move.w	d0,d3
	addq.w	#2,d3
	and.w	#$fffe,d3
	add.w	d3,a2
	movem.l	d0-d1,-(sp)
	add.w	#3,d2
	lsr.w	#1,d2				; words
	move.w	#(24<<6),d0
	or.w	d2,d0
	add.w	d2,d2
	neg.w	d2
	add.w	#PF2W,d2
	move.w	d2,d1
	bsr	AddDirty
	movem.l	(sp)+,d0-d1
.nxt:	addq.w	#8,d1
	tst.b	-1(a0)
	bne.s	.line
.x:	movem.l	(sp)+,d0-d3/a0-a2
	rts

; PrintBoth: print into both buffers
PrintBoth:
	move.l	a1,-(sp)
	st	NoDirty
	move.l	BackBuf,a1
	bsr	Print
	move.l	FrontBuf,a1
	bsr	Print
	sf	NoDirty
	move.l	(sp)+,a1
	rts

; PrintBack: print into back buffer
PrintBack:
	move.l	a1,-(sp)
	move.l	BackBuf,a1
	bsr	Print
	move.l	(sp)+,a1
	rts

; PrintCentre*: centre string a0 on line d1, colour d2
StrLen:
	move.l	a0,-(sp)
	moveq	#-1,d0
.l:	addq.w	#1,d0
	tst.b	(a0)+
	bne.s	.l
	move.l	(sp)+,a0
	rts
CentreCol:
	bsr	StrLen
	neg.w	d0
	add.w	#40,d0
	asr.w	#1,d0
	rts
PrintCentreBoth:
	movem.l	d0,-(sp)
	bsr	CentreCol
	bsr	PrintBoth
	movem.l	(sp)+,d0
	rts
PrintCentreBack:
	movem.l	d0,-(sp)
	bsr	CentreCol
	bsr	PrintBack
	movem.l	(sp)+,d0
	rts

;---------------------------------------------------------------------
; PrintBig: double size text. a0 = string, d0 = x pixel (multiple of 8),
; d1 = y, d2 = colour, a1 = buffer
;---------------------------------------------------------------------
PrintBig:
	movem.l	d0-d7/a0-a4,-(sp)
	bsr	WaitBlit
	cmp.l	BackBuf,a1
	bne.s	.nod
	movem.l	d0-d3/a0/a2,-(sp)
	bsr	StrLen
	move.w	d0,d2
	add.w	d2,d2			; words (2 bytes per char)
	addq.w	#1,d2
	move.l	(sp),d0
	move.w	d1,d3
	mulu	#PF2ROW,d3
	move.l	a1,a2
	add.l	d3,a2
	lsr.w	#3,d0
	addq.w	#2,d0
	and.w	#$fffe,d0
	add.w	d0,a2
	move.w	#(48<<6),d0
	or.w	d2,d0
	add.w	d2,d2
	neg.w	d2
	add.w	#PF2W,d2
	move.w	d2,d1
	bsr	AddDirty
	movem.l	(sp)+,d0-d3/a0/a2
.nod:	lea	Font,a3
	lea	DoubleTab,a4
.ch:	moveq	#0,d3
	move.b	(a0)+,d3
	beq	.done
	sub.w	#32,d3
	bmi	.next
	lsl.w	#3,d3
	lea	(a3,d3.w),a2
	move.l	a1,-(sp)
	move.w	d1,d4
	mulu	#PF2ROW,d4
	add.l	d4,a1
	move.w	d0,d4
	lsr.w	#3,d4
	addq.w	#2,d4
	add.w	d4,a1
	moveq	#7,d4
.r:	moveq	#0,d5
	move.b	(a2)+,d5
	add.w	d5,d5
	move.w	(a4,d5.w),d5			; doubled bits
	moveq	#1,d7				; two rows
.rr:	moveq	#0,d6
	btst	#0,d2
	beq.s	.a0
	move.w	d5,d6
.a0:	ror.w	#8,d6
	move.b	d6,(a1)
	ror.w	#8,d6
	move.b	d6,1(a1)
	moveq	#0,d6
	btst	#1,d2
	beq.s	.a1
	move.w	d5,d6
.a1:	ror.w	#8,d6
	move.b	d6,PF2W(a1)
	ror.w	#8,d6
	move.b	d6,PF2W+1(a1)
	moveq	#0,d6
	btst	#2,d2
	beq.s	.a2
	move.w	d5,d6
.a2:	ror.w	#8,d6
	move.b	d6,PF2W*2(a1)
	ror.w	#8,d6
	move.b	d6,PF2W*2+1(a1)
	add.w	#PF2ROW,a1
	dbf	d7,.rr
	dbf	d4,.r
	move.l	(sp)+,a1
.next:	add.w	#16,d0
	bra	.ch
.done:	movem.l	(sp)+,d0-d7/a0-a4
	rts

; PrintBigCentre: a0 string, d1 y, d2 colour, a1 buffer
PrintBigCentre:
	movem.l	d0,-(sp)
	bsr	StrLen
	lsl.w	#4,d0
	neg.w	d0
	add.w	#320,d0
	asr.w	#1,d0
	and.w	#$fff8,d0
	bsr	PrintBig
	movem.l	(sp)+,d0
	rts

InitDoubleTab:
	lea	DoubleTab,a0
	moveq	#0,d0
.n:	moveq	#0,d1
	moveq	#7,d2
.b:	lsl.w	#2,d1
	btst	d2,d0
	beq.s	.z
	or.w	#3,d1
.z:	dbf	d2,.b
	move.w	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.n
	rts

;---------------------------------------------------------------------
; Numbers: NumStr d0 = value, d1 = digits, a0 = buffer -> zero padded
; string (0 terminated). value < 655360
;---------------------------------------------------------------------
NumStr:
	movem.l	d0-d2/a0,-(sp)
	and.l	#$000fffff,d0
	add.w	d1,a0
	clr.b	(a0)
	subq.w	#1,d1
.d:	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a0)
	clr.w	d0
	swap	d0
	dbf	d1,.d
	movem.l	(sp)+,d0-d2/a0
	rts

; PutNumW: like PutNum for a word value in d0
PutNumW:
	move.l	d0,-(sp)
	and.l	#$ffff,d0
	bsr.s	PutNum
	move.l	(sp)+,d0
	rts
; PutNum: write digits of d0 into string at a0 (no terminator), d1 digits
PutNum:
	movem.l	d0-d2/a0,-(sp)
	and.l	#$000fffff,d0
	add.w	d1,a0
	subq.w	#1,d1
.d:	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a0)
	clr.w	d0
	swap	d0
	dbf	d1,.d
	movem.l	(sp)+,d0-d2/a0
	rts

;---------------------------------------------------------------------
; DrawLogo: copy the title logo into both buffers at y = LOGO_Y
;---------------------------------------------------------------------
DrawLogo:
	movem.l	d0-d2/a0-a2,-(sp)
	move.l	BackBuf,a1
	bsr.s	.one
	move.l	FrontBuf,a1
	bsr.s	.one
	movem.l	(sp)+,d0-d2/a0-a2
	rts
.one:	bsr	WaitBlit
	move.l	#$09f00000,BLTCON0(a5)
	move.l	#$ffffffff,BLTAFWM(a5)
	move.w	#0,BLTAMOD(a5)
	move.w	#PF2W-40,BLTDMOD(a5)
	move.l	#LogoData,BLTAPT(a5)
	move.l	a1,d0
	add.l	#LOGO_Y*PF2ROW+2,d0
	move.l	d0,BLTDPT(a5)
	move.w	#((LOGO_H*3)<<6)|20,BLTSIZE(a5)
	bsr	WaitBlit
	rts

;---------------------------------------------------------------------
; HLine: CPU horizontal line in PF2 (for frames / bars), d0 x (mult 8),
; d1 y, d2 width (mult 8), d4 colour, a1 buffer   (1 pixel high)
;---------------------------------------------------------------------
HLine:
	movem.l	d3,-(sp)
	moveq	#1,d3
	bsr	FillRect
	movem.l	(sp)+,d3
	rts

; Bar: energy style bar. d0 x, d1 y, d2 total width(px mult 8), d3 filled px,
; d4 colour full, d5 colour empty, a1 buffer. height 6. Fills whole bytes.
Bar:
	movem.l	d0-d7/a0-a1,-(sp)
	move.w	d3,d6
	lsr.w	#3,d6				; full bytes
	move.w	d2,d7
	lsr.w	#3,d7
	sub.w	d6,d7				; empty bytes
	move.w	d4,-(sp)
	move.w	d6,d2
	lsl.w	#3,d2
	beq.s	.nofull
	moveq	#6,d3
	bsr	FillRect
.nofull:
	add.w	d2,d0
	move.w	(sp)+,d4
	move.w	d7,d2
	lsl.w	#3,d2
	beq.s	.noempty
	move.w	d5,d4
	moveq	#6,d3
	bsr	FillRect
.noempty:
	movem.l	(sp)+,d0-d7/a0-a1
	rts

;---------------------------------------------------------------------
; Drawing into playfield 1 (static scenes: map / flight). PF1 is
; interleaved 3 planes x 84 bytes; with scroll 0, column = screen x + 16
;---------------------------------------------------------------------
; PlotPF1: d0 x, d1 y, d2 colour (0..7)
PlotPF1:
	movem.l	d0-d4/a1,-(sp)
	tst.w	d0
	bmi.s	.x
	cmp.w	#320,d0
	bge.s	.x
	lea	PF1Buf,a1
	add.w	#16,d0
	mulu	#PF1ROW,d1
	add.l	d1,a1
	move.w	d0,d1
	lsr.w	#3,d1
	add.w	d1,a1
	not.w	d0
	and.w	#7,d0
	moveq	#2,d4
	moveq	#0,d3
.p:	btst	d3,d2
	beq.s	.cl
	bset	d0,(a1)
	bra.s	.n
.cl:	bclr	d0,(a1)
.n:	add.w	#PF1W,a1
	addq.w	#1,d3
	dbf	d4,.p
.x:	movem.l	(sp)+,d0-d4/a1
	rts

; MarkerPF1: d0 x, d1 y, d2 colour - 4x4 block
MarkerPF1:
	movem.l	d0-d4,-(sp)
	moveq	#3,d4
.r:	moveq	#3,d3
.c:	movem.l	d0-d1,-(sp)
	add.w	d3,d0
	add.w	d4,d1
	bsr	PlotPF1
	movem.l	(sp)+,d0-d1
	dbf	d3,.c
	dbf	d4,.r
	movem.l	(sp)+,d0-d4
	rts

; PrintPF1: a0 string, d0 column, d1 y, d2 colour (transparent: ORs glyph)
PrintPF1:
	movem.l	d0-d7/a0-a3,-(sp)
	lea	Font,a3
.ch:	moveq	#0,d3
	move.b	(a0)+,d3
	beq.s	.done
	sub.w	#32,d3
	bmi.s	.skip
	lsl.w	#3,d3
	lea	(a3,d3.w),a2
	lea	PF1Buf,a1
	move.w	d1,d4
	mulu	#PF1ROW,d4
	add.l	d4,a1
	add.w	d0,a1
	addq.w	#2,a1
	moveq	#7,d4
.r:	move.b	(a2)+,d5
	move.b	d5,d6
	not.b	d6
	moveq	#0,d7
.pl:	btst	d7,d2
	beq.s	.z
	or.b	d5,(a1)
	bra.s	.nx
.z:	and.b	d6,(a1)
.nx:	add.w	#PF1W,a1
	addq.w	#1,d7
	cmp.w	#3,d7
	bne.s	.pl
	add.w	#PF1ROW-PF1W*3,a1
	dbf	d4,.r
.skip:	addq.w	#1,d0
	bra.s	.ch
.done:	movem.l	(sp)+,d0-d7/a0-a3
	rts

;---------------------------------------------------------------------
; file: sound.s
;---------------------------------------------------------------------
;=====================================================================
; sound.s : tiny 3-channel music player + sound effects on channel 3
;=====================================================================
CH_VOL		equ	0
CH_DEC		equ	2
CH_FLOOR	equ	4
CH_NEEDLOOP	equ	6
CH_LOOP		equ	8
CH_LOOPLEN	equ	12
CHSIZE		equ	16
PATSIZE		equ	64*6

; PlaySong: a0 = order list
PlaySong:
	movem.l	d0-d1/a0,-(sp)
	bsr	StopMusic
	move.l	a0,SongStart
	move.l	a0,SongPos
	bsr	NextPattern
	clr.w	Row
	clr.w	Tick
	move.w	#1,SongActive
	movem.l	(sp)+,d0-d1/a0
	rts

StopMusic:
	clr.w	SongActive
	move.w	#$0007,DMACON(a5)
	move.w	#0,AUD0VOL(a5)
	move.w	#0,AUD1VOL(a5)
	move.w	#0,AUD2VOL(a5)
	clr.w	ChState+CH_VOL
	clr.w	ChState+CHSIZE+CH_VOL
	clr.w	ChState+CHSIZE*2+CH_VOL
	rts

NextPattern:
	movem.l	d0-d1/a0,-(sp)
	move.l	SongPos,a0
.again:	moveq	#0,d0
	move.b	(a0)+,d0
	cmp.b	#$fe,d0
	bne.s	.nostop
	clr.w	SongActive
	move.w	#$0007,DMACON(a5)
	bra.s	.x
.nostop:
	cmp.b	#$ff,d0
	bne.s	.pat
	moveq	#0,d1
	move.b	(a0),d1
	move.l	SongStart,a0
	add.w	d1,a0
	bra.s	.again
.pat:	mulu	#PATSIZE,d0
	add.l	#Patterns,d0
	move.l	d0,PatPtr
	move.l	a0,SongPos
.x:	movem.l	(sp)+,d0-d1/a0
	rts

; wait ~4 raster lines so Paula notices DMA switched off
DmaWait:
	movem.l	d0-d1,-(sp)
	moveq	#3,d1
.l:	move.b	VHPOSR(a5),d0
.w:	cmp.b	VHPOSR(a5),d0
	beq.s	.w
	dbf	d1,.l
	movem.l	(sp)+,d0-d1
	rts

MusicTick:
	movem.l	d0-d7/a0-a4,-(sp)
	tst.w	SongActive
	beq	.x
	subq.w	#1,Tick
	bpl	.env
	move.w	#5,Tick
	move.l	PatPtr,a0
	move.w	Row,d0
	mulu	#6,d0
	add.l	d0,a0
	lea	ChState,a1
	lea	AUD0LC(a5),a2
	moveq	#0,d7
	moveq	#0,d6
.ch:	moveq	#0,d0
	move.b	(a0)+,d0
	moveq	#0,d1
	move.b	(a0)+,d1
	tst.b	d0
	beq.s	.nextch
	cmp.b	#255,d0
	bne.s	.play
	clr.w	CH_VOL(a1)
	bra.s	.nextch
.play:	lea	InstTable,a3
	mulu	#20,d1
	add.w	d1,a3
	moveq	#1,d2
	lsl.w	d6,d2
	move.w	d2,DMACON(a5)
	or.w	d2,d7
	move.l	(a3),(a2)
	move.w	4(a3),4(a2)
	add.w	d0,d0
	lea	PeriodTable,a4
	move.w	(a4,d0.w),6(a2)
	move.l	6(a3),CH_LOOP(a1)
	move.w	10(a3),CH_LOOPLEN(a1)
	move.w	12(a3),CH_VOL(a1)
	move.w	14(a3),CH_DEC(a1)
	move.w	16(a3),CH_FLOOR(a1)
	move.w	#1,CH_NEEDLOOP(a1)
.nextch:
	lea	CHSIZE(a1),a1
	lea	16(a2),a2
	addq.w	#1,d6
	cmp.w	#3,d6
	bne.s	.ch
	tst.w	d7
	beq.s	.nodma
	bsr	DmaWait
	or.w	#$8000,d7
	move.w	d7,DMACON(a5)
.nodma:	addq.w	#1,Row
	cmp.w	#64,Row
	bne.s	.vols
	clr.w	Row
	bsr	NextPattern
	bra.s	.vols
.env:	lea	ChState,a1
	lea	AUD0LC(a5),a2
	moveq	#2,d6
.e:	tst.w	CH_NEEDLOOP(a1)
	beq.s	.nl
	clr.w	CH_NEEDLOOP(a1)
	move.l	CH_LOOP(a1),(a2)
	move.w	CH_LOOPLEN(a1),4(a2)
.nl:	move.w	CH_VOL(a1),d0
	sub.w	CH_DEC(a1),d0
	cmp.w	CH_FLOOR(a1),d0
	bge.s	.vf
	move.w	CH_FLOOR(a1),d0
	cmp.w	CH_VOL(a1),d0
	ble.s	.vf
	move.w	CH_VOL(a1),d0
.vf:	move.w	d0,CH_VOL(a1)
	lea	CHSIZE(a1),a1
	lea	16(a2),a2
	dbf	d6,.e
.vols:	lea	ChState,a1
	lea	AUD0LC(a5),a2
	moveq	#2,d6
.v:	move.w	CH_VOL(a1),d0
	tst.w	MusicOn
	bne.s	.von
	moveq	#0,d0
.von:	move.w	d0,8(a2)
	lea	CHSIZE(a1),a1
	lea	16(a2),a2
	dbf	d6,.v
.x:	movem.l	(sp)+,d0-d7/a0-a4
	rts

;---------------------------------------------------------------------
; Sound effects (channel 3).  PlaySfx d0 = effect number
;---------------------------------------------------------------------
PlaySfx:
	movem.l	d0-d1/a0,-(sp)
	lea	SfxTable,a0
	mulu	#18,d0
	add.w	d0,a0
	move.w	#$0008,DMACON(a5)
	move.l	(a0)+,AUD3LC(a5)
	move.w	(a0)+,AUD3LEN(a5)
	move.w	(a0),AUD3PER(a5)
	move.w	(a0)+,SfxPer
	move.w	(a0)+,SfxStep
	move.w	(a0),AUD3VOL(a5)
	move.w	(a0)+,SfxVol
	move.w	(a0)+,SfxVStep
	move.w	(a0)+,SfxTicks
	bsr	DmaWait
	move.w	#$8008,DMACON(a5)
	movem.l	(sp)+,d0-d1/a0
	rts

SfxTick:
	move.l	d0,-(sp)
	tst.w	SfxTicks
	beq.s	.x
	subq.w	#1,SfxTicks
	bne.s	.go
	move.w	#0,AUD3VOL(a5)
	move.w	#$0008,DMACON(a5)
	bra.s	.x
.go:	move.w	SfxPer,d0
	add.w	SfxStep,d0
	cmp.w	#113,d0
	bge.s	.p1
	move.w	#113,d0
.p1:	cmp.w	#1200,d0
	ble.s	.p2
	move.w	#1200,d0
.p2:	move.w	d0,SfxPer
	move.w	d0,AUD3PER(a5)
	move.w	SfxVol,d0
	add.w	SfxVStep,d0
	bpl.s	.v1
	moveq	#0,d0
.v1:	cmp.w	#64,d0
	ble.s	.v2
	moveq	#64,d0
.v2:	move.w	d0,SfxVol
	move.w	d0,AUD3VOL(a5)
.x:	move.l	(sp)+,d0
	rts

;---------------------------------------------------------------------
; file: screens.s
;---------------------------------------------------------------------
;=====================================================================
; screens.s : title / attract pages, menu, hall of fame, how to play,
;             story, flights, map, level clear, game over, victory,
;             credits, name entry
;=====================================================================

MainMenuLoop:
	lea	SongMain,a0
	bsr	PlaySong
.loop:	bsr	TitleScreen
	tst.w	d0
	bne.s	.n0
	bsr	PlayGame
	bra.s	.loop
.n0:	cmp.w	#1,d0
	bne.s	.n1
	bsr	BonusMenu
	bra.s	.loop
.n1:	cmp.w	#2,d0
	bne.s	.n2
	bsr	HowToPlay
	bra.s	.loop
.n2:	bsr	FadeOut
	bsr	StopMusic
	rts

; NewScreen: d0 = scene. fade out, set scene, clear playfield 2
NewScreen:
	bsr	FadeOut
	move.w	#16,BgFade
	clr.w	LogoGrad
	clr.w	FlashCol
	bsr	SetScene
	bsr	ClearBoth
	rts

; WaitFireOrKey: d0 = timeout frames (0 = none) - returns d0 = 1 if pressed
; scrolls city by d1 per frame
WaitFire:
	movem.l	d1-d2,-(sp)
	move.w	d0,d2
.l:	move.w	d1,d0
	bsr	ScrollCity
	bsr	Frame
	btst	#J_FIRE,JoyNew+1
	bne.s	.p
	bsr	GetKey
	cmp.w	#KEY_SPACE,d0
	beq.s	.p
	cmp.w	#KEY_RETURN,d0
	beq.s	.p
	cmp.w	#KEY_ESC,d0
	beq.s	.p
	tst.w	d2
	beq.s	.l
	subq.w	#1,d2
	bne.s	.l
	moveq	#0,d0
	bra.s	.x
.p:	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
	moveq	#1,d0
.x:	movem.l	(sp)+,d1-d2
	rts

;---------------------------------------------------------------------
; Title screen with attract pages. returns d0: 0 start, 1 bonus,
; 2 how to play, 3 quit
;---------------------------------------------------------------------
TitleScreen:
	movem.l	d1-d7/a0-a6,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	tst.w	SongActive
	bne.s	.mus
	lea	SongMain,a0
	bsr	PlaySong
.mus:	clr.w	Page
.page:	bsr	ClearBoth
	clr.w	LogoGrad
	move.w	#6,BgFade
	move.w	Page,d0
	bne.s	.p1
	move.w	#12,BgFade
	bsr	DrawMenuPage
	bra.s	.drawn
.p1:	cmp.w	#1,d0
	bne.s	.p2
	bsr	DrawHallOfFame
	bra.s	.drawn
.p2:	cmp.w	#2,d0
	bne.s	.p3
	bsr	DrawPowerPage
	bra.s	.drawn
.p3:	bsr	DrawBossPage
.drawn:	bsr	FadeIn
	clr.w	PageTimer
.loop:	; animated ghosts in the street band on the menu page
	tst.w	Page
	bne.s	.noanim
	move.w	#194,d0
	moveq	#36,d1
	move.l	BackBuf,a1
	bsr	ClearRows
	bsr	TitleGhosts
.noanim:
	moveq	#1,d0
	bsr	ScrollCity
	addq.w	#1,LogoPhase
	bsr	Frame
	addq.w	#1,PageTimer
	; keys
	bsr	GetKey
	move.w	d0,d7
	cmp.w	#KEY_M,d7
	bne.s	.nm
	eor.w	#1,MusicOn
	tst.w	Page
	bne.s	.nm
	bsr	DrawMusicLine
.nm:	cmp.w	#KEY_ESC,d7
	bne.s	.ne
	tst.w	Page
	bne.s	.tomenu
	move.w	#4,MenuSel
	moveq	#3,d0
	bra	.x
.ne:	move.w	JoyNew,d6
	tst.w	Page
	beq.s	.menu
	; any input on an info page -> back to the menu
	tst.w	d6
	bne.s	.tomenu
	tst.w	d7
	bpl.s	.tomenu
	bra	.timer
.tomenu:
	clr.w	Page
	bsr	FadeOut
	bra	.page
.menu:	btst	#J_UP,d6
	beq.s	.nu
	subq.w	#1,MenuSel
	bpl.s	.mv
	move.w	#4,MenuSel
	bra.s	.mv
.nu:	btst	#J_DOWN,d6
	beq.s	.nd
	addq.w	#1,MenuSel
	cmp.w	#5,MenuSel
	blt.s	.mv
	clr.w	MenuSel
.mv:	moveq	#SFX_MOVE,d0
	bsr	PlaySfx
	bsr	DrawMenuItems
	clr.w	PageTimer
	bra	.timer
.nd:	cmp.w	#3,MenuSel			; difficulty: left/right/fire toggles
	bne.s	.nodiff
	move.w	d6,d0
	and.w	#(1<<J_LEFT)|(1<<J_RIGHT)|(1<<J_FIRE),d0
	beq.s	.timer
	btst	#J_LEFT,d6
	beq.s	.dinc
	subq.w	#1,Difficulty
	bpl.s	.dset
	move.w	#2,Difficulty
	bra.s	.dset
.dinc:	addq.w	#1,Difficulty
	cmp.w	#3,Difficulty
	blt.s	.dset
	clr.w	Difficulty
.dset:	move.w	Difficulty,HiData+HISIZE-4
	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
	bsr	DrawMenuItems
	clr.w	PageTimer
	bra.s	.timer
.nodiff:
	btst	#J_FIRE,d6
	bne.s	.sel
	cmp.w	#KEY_RETURN,d7
	beq.s	.sel
	cmp.w	#KEY_SPACE,d7
	bne.s	.timer
.sel:	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
	move.w	MenuSel,d0
	cmp.w	#4,d0
	bne.s	.x
	moveq	#3,d0
	bra.s	.x
.timer:	cmp.w	#600,PageTimer
	blt	.loop
	addq.w	#1,Page
	and.w	#3,Page
	bsr	FadeOut
	bra	.page
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts

DrawMenuPage:
	bsr	DrawLogo
	move.w	#1,LogoGrad
	lea	TxtAmigaGame,a0
	move.w	#102,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreBoth
	bsr	MakeHiLine
	lea	TmpStr,a0
	move.w	#116,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	bsr	DrawMenuItems
	bsr	DrawMusicLine
	lea	TxtCreated,a0
	move.w	#240,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	rts

DrawMusicLine:
	lea	TxtMMusicOn,a0
	tst.w	MusicOn
	bne.s	.on
	lea	TxtMMusicOff,a0
.on:	moveq	#1,d0
	move.w	#230,d1
	moveq	#C_YELLOW,d2
	bsr	PrintBoth
	lea	TxtYear,a0
	moveq	#35,d0
	bsr	PrintBoth
	rts

; "HIGH SCORE STRONKIE 00600 LV 02"
MakeHiLine:
	movem.l	d0-d2/a0-a1,-(sp)
	lea	TmpStr,a1
	lea	TxtHighScore,a0
.c:	move.b	(a0)+,(a1)+
	bne.s	.c
	subq.l	#1,a1
	lea	HiData+4,a0
	moveq	#7,d0
.n:	move.b	(a0)+,(a1)+
	dbf	d0,.n
	move.b	#' ',(a1)+
	move.l	(a0)+,d0
	move.l	a1,a0
	moveq	#5,d1
	bsr	PutNum
	lea	5(a1),a1
	move.b	#' ',(a1)+
	move.b	#'L',(a1)+
	move.b	#'V',(a1)+
	move.b	#' ',(a1)+
	move.w	HiData+4+12,d0
	move.l	a1,a0
	moveq	#2,d1
	bsr	PutNumW
	clr.b	2(a1)
	movem.l	(sp)+,d0-d2/a0-a1
	rts

DrawMenuItems:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	MenuTexts,a2
	moveq	#0,d7
	move.w	#134,d6
.l:	; clear line
	moveq	#0,d0
	move.w	d6,d1
	move.w	#320,d2
	moveq	#8,d3
	moveq	#0,d4
	move.l	BackBuf,a1
	bsr	FillRect
	move.l	FrontBuf,a1
	bsr	FillRect
	move.l	(a2)+,a0
	cmp.w	#3,d7
	bne.s	.nd
	move.w	Difficulty,d0
	lsl.w	#2,d0
	lea	DiffTexts,a0
	move.l	(a0,d0.w),a0
.nd:	moveq	#C_WHITE,d2
	cmp.w	MenuSel,d7
	bne.s	.p
	moveq	#C_YELLOW,d2
	; selection markers
	movem.l	d0-d2/a0,-(sp)
	bsr	CentreCol
	subq.w	#3,d0
	lea	TxtMarkL,a0
	move.w	d6,d1
	bsr	PrintBoth
	movem.l	(sp)+,d0-d2/a0
	movem.l	d0-d2/a0,-(sp)
	bsr	CentreCol
	move.w	d0,d1
	bsr	StrLen
	add.w	d1,d0
	addq.w	#1,d0
	lea	TxtMarkR,a0
	move.w	d6,d1
	moveq	#C_YELLOW,d2
	bsr	PrintBoth
	movem.l	(sp)+,d0-d2/a0
.p:	move.w	d6,d1
	bsr	PrintCentreBoth
	add.w	#12,d6
	addq.w	#1,d7
	cmp.w	#5,d7
	bne	.l
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; three ghosts floating along the bottom of the menu page
TitleGhosts:
	movem.l	d0-d4/a0,-(sp)
	moveq	#2,d4
.g:	move.l	FrameCount,d1
	move.w	d4,d0
	mulu	#110,d0
	add.w	d0,d1
	and.w	#511,d1
	sub.w	#60,d1
	move.l	FrameCount,d2
	lsl.w	#2,d2
	move.w	d4,d0
	lsl.w	#6,d0
	add.w	d0,d2
	and.w	#255,d2
	lea	SinTab,a0
	move.b	(a0,d2.w),d2
	ext.w	d2
	asr.w	#4,d2
	add.w	#204,d2
	moveq	#BOB_GHOST0_0,d0
	move.w	d4,d3
	mulu	#5,d3
	add.w	d3,d0
	cmp.w	#2,d4
	bne.s	.d
	moveq	#BOB_BAT0,d0
	move.l	FrameCount,d3
	lsr.w	#3,d3
	and.w	#1,d3
	add.w	d3,d0
.d:	bsr	DrawBob
	dbf	d4,.g
	movem.l	(sp)+,d0-d4/a0
	rts

DrawHallOfFame:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	TxtHof,a0
	moveq	#24,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtTop10,a0
	moveq	#38,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreBoth
	lea	HiData+4,a2
	moveq	#0,d7
	moveq	#58,d6
.e:	lea	TmpStr,a1
	move.w	d7,d0
	addq.w	#1,d0
	cmp.w	#10,d0
	blt.s	.sp
	move.b	#'1',(a1)+
	moveq	#0,d0
	bra.s	.dg
.sp:	move.b	#' ',(a1)+
.dg:	add.b	#'0',d0
	move.b	d0,(a1)+
	move.b	#'.',(a1)+
	move.b	#' ',(a1)+
	move.b	#' ',(a1)+
	moveq	#7,d0
.nm:	move.b	(a2)+,(a1)+
	dbf	d0,.nm
	move.b	#' ',(a1)+
	move.b	#' ',(a1)+
	move.l	(a2)+,d0
	move.l	a1,a0
	moveq	#5,d1
	bsr	PutNum
	lea	5(a1),a1
	move.b	#' ',(a1)+
	move.b	#' ',(a1)+
	move.b	#'L',(a1)+
	move.b	#'V',(a1)+
	move.b	#' ',(a1)+
	move.w	(a2)+,d0
	move.l	a1,a0
	moveq	#2,d1
	bsr	PutNumW
	clr.b	2(a1)
	lea	TmpStr,a0
	move.w	d6,d1
	moveq	#C_WHITE,d2
	tst.w	d7
	bne.s	.c
	moveq	#C_YELLOW,d2
.c:	moveq	#6,d0
	bsr	PrintBoth
	add.w	#12,d6
	addq.w	#1,d7
	cmp.w	#10,d7
	bne	.e
	lea	TxtPressPlay,a0
	move.w	#186,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	movem.l	(sp)+,d0-d7/a0-a2
	rts

DrawPowerPage:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	TxtPowerUps,a0
	moveq	#28,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtCatchThem,a0
	moveq	#42,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	PowerTexts,a2
	moveq	#0,d7
	moveq	#70,d6
.l:	moveq	#BOB_PW_INV,d0
	add.w	d7,d0
	moveq	#56,d1
	move.w	d6,d2
	subq.w	#7,d2
	bsr	DrawBobBoth
	move.l	(a2)+,a0
	moveq	#12,d0
	move.w	d6,d1
	moveq	#C_GREEN,d2
	bsr	PrintBoth
	add.w	#28,d6
	addq.w	#1,d7
	cmp.w	#4,d7
	bne.s	.l
	movem.l	(sp)+,d0-d7/a0-a2
	rts

DrawBossPage:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	TxtBossAhead,a0
	moveq	#26,d1
	moveq	#C_MAGENTA,d2
	bsr	PrintCentreBoth
	moveq	#BOB_BOSS,d0
	move.w	#136,d1
	moveq	#44,d2
	bsr	DrawBobBoth
	lea	BossM,a0
	moveq	#96,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtBossInfo,a0
	moveq	#2,d0
	move.w	#116,d1
	moveq	#C_WHITE,d2
	bsr	PrintBoth
	lea	TxtPressFire,a0
	move.w	#180,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	movem.l	(sp)+,d0-d7/a0-a2
	rts

;---------------------------------------------------------------------
HowToPlay:
	movem.l	d0-d2/a0,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	move.w	#6,BgFade
	lea	TxtHowTitle,a0
	moveq	#22,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtHow,a0
	moveq	#1,d0
	moveq	#40,d1
	moveq	#C_WHITE,d2
	bsr	PrintBoth
	lea	TxtPressBack,a0
	move.w	#190,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	bsr	FadeIn
	moveq	#0,d0
	moveq	#1,d1
	bsr	WaitFire
	movem.l	(sp)+,d0-d2/a0
	rts

;---------------------------------------------------------------------
; Story: typed pages over the night city. Fire skips.
;---------------------------------------------------------------------
Story:
	movem.l	d0-d7/a0-a3,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	move.w	#8,BgFade
	bsr	FadeIn
	lea	StoryPages,a3
.page:	move.l	(a3)+,d0
	beq.s	.done
	move.l	d0,a2
	bsr	ClearBoth
	moveq	#20,d6				; y
.line:	move.b	(a2)+,d5			; colour code
	beq.s	.endpage
	ext.w	d5
	; type the line character by character
	move.l	a2,a0
	bsr	CentreCol
	move.w	d0,d4
.ch:	move.b	(a2)+,d0
	beq.s	.eol
	lea	TmpStr,a0
	move.b	d0,(a0)
	clr.b	1(a0)
	move.w	d4,d0
	move.w	d6,d1
	move.w	d5,d2
	bsr	PrintBoth
	addq.w	#1,d4
	moveq	#1,d0
	bsr	ScrollCity
	bsr	Frame
	btst	#J_FIRE,JoyNew+1
	bne.s	.skip
	bsr	GetKey
	cmp.w	#KEY_SPACE,d0
	beq.s	.skip
	cmp.w	#KEY_ESC,d0
	beq.s	.skip
	bra.s	.ch
.eol:	add.w	#11,d6
	bra.s	.line
.endpage:
	move.w	#250,d0
	moveq	#1,d1
	bsr	WaitFire
	bra.s	.page
.skip:	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
.done:	movem.l	(sp)+,d0-d7/a0-a3
	rts

;---------------------------------------------------------------------
; Flight: d0 = 0 Amsterdam -> New York, 1 = New York -> Amsterdam
;---------------------------------------------------------------------
AMS_X		equ	250
AMS_Y		equ	86
NY_X		equ	74
NY_Y		equ	104
Flight:
	movem.l	d0-d7/a0-a3,-(sp)
	move.w	d0,d7
	moveq	#6,d0
	bsr	NewScreen
	lea	TxtFlightTo,a0
	tst.w	d7
	beq.s	.t
	lea	TxtFlightHome,a0
.t:	moveq	#18,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtAmsNY,a0
	tst.w	d7
	beq.s	.t2
	lea	TxtNYAms,a0
.t2:	move.w	#232,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	; city labels and markers into the map (playfield 1)
	lea	TxtAmsterdam,a0
	moveq	#28,d0
	moveq	#96,d1
	moveq	#1,d2
	bsr	PrintPF1
	lea	TxtNewYork,a0
	moveq	#4,d0
	move.w	#114,d1
	bsr	PrintPF1
	move.w	#AMS_X,d0
	move.w	#AMS_Y,d1
	moveq	#7,d2
	bsr	MarkerPF1
	move.w	#NY_X,d0
	move.w	#NY_Y,d1
	bsr	MarkerPF1
	bsr	FadeIn
	moveq	#0,d6				; t = 0..255
.fly:	bsr	ClearDirty
	bsr	FlightPos			; d0,d1 = point on the arc
	move.w	d6,d3
	and.w	#5,d3
	bne.s	.nodot
	moveq	#2,d2
	bsr	PlotPF1
.nodot:	sub.w	#12,d0
	sub.w	#8,d1
	move.w	d1,d2
	move.w	d0,d1
	moveq	#BOB_PLANE_L,d0
	tst.w	d7
	beq.s	.pl
	moveq	#BOB_PLANE,d0
.pl:	bsr	DrawBob
	bsr	Frame
	btst	#J_FIRE,JoyNew+1
	bne.s	.land
	addq.w	#1,d6
	cmp.w	#256,d6
	bne.s	.fly
.land:	lea	TxtLandedNY,a0
	tst.w	d7
	beq.s	.l2
	lea	TxtWelcomeHome,a0
.l2:	move.w	#204,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	moveq	#SFX_LIFE,d0
	bsr	PlaySfx
	move.w	#200,d0
	moveq	#0,d1
	bsr	WaitFire
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; FlightPos: d6 = t (0..255), d7 = direction -> d0 x, d1 y
FlightPos:
	movem.l	d2-d3/a0,-(sp)
	move.w	d6,d2
	tst.w	d7
	beq.s	.d
	neg.w	d2
	add.w	#255,d2
.d:	move.w	#NY_X-AMS_X,d0
	muls	d2,d0
	asr.l	#8,d0
	add.w	#AMS_X,d0
	move.w	#NY_Y-AMS_Y,d1
	muls	d2,d1
	asr.l	#8,d1
	add.w	#AMS_Y,d1
	move.w	d2,d3
	lsr.w	#1,d3
	lea	SinTab,a0
	move.b	(a0,d3.w),d3
	ext.w	d3
	muls	#46,d3
	asr.l	#7,d3
	sub.w	d3,d1
	addq.w	#2,d0
	addq.w	#2,d1
	movem.l	(sp)+,d2-d3/a0
	rts

;---------------------------------------------------------------------
; MapScreen: d0 = from location, d1 = to location
;---------------------------------------------------------------------
MapScreen:
	movem.l	d0-d7/a0-a3,-(sp)
	move.w	d0,MapFrom
	move.w	d1,MapTo
	moveq	#5,d0
	bsr	NewScreen
	lea	TxtNextStop,a0
	moveq	#18,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	moveq	#0,d7
.m:	move.w	d7,d0
	bsr	MapXY
	moveq	#6,d2				; not yet visited
	cmp.w	MapTo,d7
	bgt.s	.mk
	moveq	#4,d2				; visited: green
	cmp.w	MapTo,d7
	bne.s	.mk
	moveq	#2,d2				; target: yellow
.mk:	cmp.w	MapTo,d7
	bgt.s	.mk2
	moveq	#7,d2
	cmp.w	MapTo,d7
	bne.s	.mk2
	moveq	#2,d2
.mk2:	bsr	MarkerPF1
	lea	LocNames,a0
	move.w	d7,d3
	lsl.w	#2,d3
	move.l	(a0,d3.w),a0
	lea	MapLabelPos,a1
	move.w	(a1,d3.w),d0
	move.w	2(a1,d3.w),d1
	moveq	#1,d2
	bsr	PrintPF1
	addq.w	#1,d7
	cmp.w	#NLEVELS,d7
	bne.s	.m
	lea	TxtHeading,a0
	move.w	#228,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	LocNames,a0
	move.w	MapTo,d0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	move.w	#238,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	bsr	FadeIn
	moveq	#0,d6				; t = 0..127
.drive:	bsr	ClearDirty
	move.w	MapFrom,d0
	bsr	MapXY
	move.w	d0,d4
	move.w	d1,d5
	move.w	MapTo,d0
	bsr	MapXY
	sub.w	d4,d0
	sub.w	d5,d1
	muls	d6,d0
	asr.l	#7,d0
	muls	d6,d1
	asr.l	#7,d1
	add.w	d4,d0
	add.w	d5,d1
	addq.w	#2,d0
	addq.w	#2,d1
	move.w	d6,d2
	and.w	#3,d2
	bne.s	.nt
	moveq	#2,d2
	bsr	PlotPF1
.nt:	sub.w	#9,d0
	subq.w	#5,d1
	move.w	d1,d2
	move.w	d0,d1
	moveq	#BOB_TAXI,d0
	bsr	DrawBob
	bsr	Frame
	addq.w	#1,d6
	cmp.w	#129,d6
	bne	.drive
	moveq	#SFX_LIFE,d0
	bsr	PlaySfx
	moveq	#50,d0
	moveq	#0,d1
	bsr	WaitFire
	bsr	FadeOut
	; "WELCOME TO ..."
	move.w	MapTo,d0
	lea	LevelScene,a0
	add.w	d0,d0
	move.w	(a0,d0.w),d0
	bsr	SetScene
	bsr	ClearBoth
	lea	TxtWelcomeTo,a0
	moveq	#80,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	LocNames,a0
	move.w	MapTo,d0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	moveq	#96,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	bsr	FadeIn
	move.w	#150,d0
	moveq	#2,d1
	bsr	WaitFire
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; MapXY: d0 = location -> d0 x, d1 y
MapXY:
	move.l	a0,-(sp)
	lea	MapPos,a0
	lsl.w	#2,d0
	move.w	2(a0,d0.w),d1
	move.w	(a0,d0.w),d0
	move.l	(sp)+,a0
	rts

;---------------------------------------------------------------------
; LevelClear
;---------------------------------------------------------------------
LevelClear:
	movem.l	d0-d7/a0-a2,-(sp)
	bsr	ClearBoth
	move.w	#7,BgFade
	lea	TxtLine,a0
	moveq	#40,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreBoth
	lea	TxtLevelCleared,a0
	move.w	Level,d0
	addq.w	#1,d0
	lea	6(a0),a0
	moveq	#2,d1
	bsr	PutNumW
	lea	TxtLevelCleared,a0
	moveq	#54,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtBusted,a0
	move.w	TotalCaught,d0
	lea	16(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtBusted,a0
	moveq	#9,d0
	moveq	#88,d1
	moveq	#C_WHITE,d2
	bsr	PrintBoth
	lea	TxtYourScore,a0
	move.l	Score,d0
	lea	16(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtYourScore,a0
	moveq	#9,d0
	move.w	#100,d1
	bsr	PrintBoth
	lea	TxtHighScoreL,a0
	move.l	HiData+4+8,d0
	cmp.l	Score,d0
	bge.s	.h
	move.l	Score,d0
.h:	lea	16(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtHighScoreL,a0
	moveq	#9,d0
	move.w	#112,d1
	bsr	PrintBoth
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#NLEVELS,d0
	beq.s	.last
	lea	TxtNextLevel,a0
	addq.w	#1,d0
	lea	12(a0),a0
	moveq	#2,d1
	bsr	PutNumW
	lea	TxtNextLevel,a0
	move.w	#132,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
.last:	lea	TxtPressGoOn,a0
	move.w	#152,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtLine,a0
	move.w	#166,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreBoth
	moveq	#0,d0
	moveq	#2,d1
	bsr	WaitFire
	move.w	#16,BgFade
	movem.l	(sp)+,d0-d7/a0-a2
	rts

GameOverScreen:
	movem.l	d0-d2/a0-a1,-(sp)
	bsr	ClearBoth
	move.w	#7,BgFade
	lea	TxtGameOver,a0
	moveq	#80,d1
	moveq	#C_MAGENTA,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtYourScore,a0
	move.l	Score,d0
	lea	16(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtYourScore,a0
	move.w	#120,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtPressFire,a0
	move.w	#150,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	move.w	#600,d0
	moveq	#0,d1
	bsr	WaitFire
	movem.l	(sp)+,d0-d2/a0-a1
	rts

;---------------------------------------------------------------------
; Victory: congratulations, flight home, mission complete, credits
;---------------------------------------------------------------------
Victory:
	movem.l	d0-d7/a0-a2,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	move.w	#8,BgFade
	lea	TxtCongrats,a0
	moveq	#2,d0
	moveq	#50,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreLines
	lea	SongWin,a0
	bsr	PlaySong
	bsr	FadeIn
	move.w	#300,d0
	moveq	#1,d1
	bsr	WaitFire
	moveq	#1,d0
	bsr	Flight
	; mission complete
	moveq	#3,d0
	bsr	NewScreen
	move.w	#6,BgFade
	; lives bonus
	move.w	Lives,d0
	mulu	#100,d0
	move.w	d0,LivesBonus
	ext.l	d0
	bsr	AddScore
	lea	TxtMission,a0
	moveq	#30,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtMBusted,a0
	move.w	TotalCaught,d0
	lea	16(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtMBusted,a0
	moveq	#10,d0
	moveq	#70,d1
	moveq	#C_WHITE,d2
	bsr	PrintBoth
	lea	TxtMBosses,a0
	move.w	BossesBeaten,d0
	lea	16(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtMBosses,a0
	moveq	#10,d0
	moveq	#82,d1
	bsr	PrintBoth
	lea	TxtMLives,a0
	move.w	LivesBonus,d0
	lea	16(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtMLives,a0
	moveq	#10,d0
	moveq	#94,d1
	bsr	PrintBoth
	lea	TxtMFinal,a0
	move.l	Score,d0
	lea	15(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtMFinal,a0
	moveq	#10,d0
	move.w	#110,d1
	moveq	#C_YELLOW,d2
	bsr	PrintBoth
	lea	TxtRank,a0
	move.w	#134,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtRookie,a0
	cmp.l	#1500,Score
	blt.s	.rk
	lea	TxtHunter,a0
	cmp.l	#3000,Score
	blt.s	.rk
	lea	TxtLegend,a0
.rk:	move.w	#148,d1
	moveq	#C_GREEN,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtPressFire,a0
	move.w	#186,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	SongMain,a0
	bsr	PlaySong
	bsr	FadeIn
	moveq	#0,d0
	moveq	#1,d1
	bsr	WaitFire
	bsr	Credits
	movem.l	(sp)+,d0-d7/a0-a2
	rts

Credits:
	movem.l	d0-d2/a0,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	move.w	#6,BgFade
	lea	TxtCredits,a0
	moveq	#0,d0
	moveq	#24,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreLines
	bsr	FadeIn
	move.w	#1000,d0
	moveq	#1,d1
	bsr	WaitFire
	movem.l	(sp)+,d0-d2/a0
	rts

; PrintCentreLines: a0 = lines separated by 10, ending 0; d1 = y;
; lines starting with '*' are yellow, '+' green, others colour d2
PrintCentreLines:
	movem.l	d0-d4/a0-a1,-(sp)
	move.w	d2,d4
.l:	tst.b	(a0)
	beq.s	.x
	lea	TmpStr,a1
	move.w	d4,d2
	cmp.b	#'*',(a0)
	bne.s	.n1
	moveq	#C_YELLOW,d2
	addq.l	#1,a0
.n1:	cmp.b	#'+',(a0)
	bne.s	.c
	moveq	#C_GREEN,d2
	addq.l	#1,a0
.c:	move.b	(a0)+,d0
	beq.s	.end
	cmp.b	#10,d0
	beq.s	.end
	move.b	d0,(a1)+
	bra.s	.c
.end:	clr.b	(a1)
	move.l	a0,-(sp)
	lea	TmpStr,a0
	bsr	PrintCentreBoth
	move.l	(sp)+,a0
	add.w	#10,d1
	tst.b	-1(a0)
	bne.s	.l
.x:	movem.l	(sp)+,d0-d4/a0-a1
	rts

;---------------------------------------------------------------------
; High score check / name entry
;---------------------------------------------------------------------
HighScoreCheck:
	movem.l	d0-d7/a0-a3,-(sp)
	; find rank
	lea	HiData+4,a0
	moveq	#0,d7
.f:	move.l	8(a0),d0
	cmp.l	Score,d0
	blt.s	.found
	lea	HI_ENTRY(a0),a0
	addq.w	#1,d7
	cmp.w	#10,d7
	bne.s	.f
	bra	.x
.found:	; shift entries down from the end
	lea	HiData+4+HI_ENTRY*9,a1		; last entry
	moveq	#9,d6
.sh:	cmp.w	d7,d6
	beq.s	.ins
	lea	-HI_ENTRY(a1),a2
	moveq	#HI_ENTRY-1,d0
.cp:	move.b	(a2,d0.w),(a1,d0.w)
	dbf	d0,.cp
	move.l	a2,a1
	subq.w	#1,d6
	bra.s	.sh
.ins:	move.l	a1,a3				; slot
	bsr	EnterName
	lea	NameBuf,a0
	moveq	#7,d0
.nm:	move.b	(a0)+,(a3)+
	dbf	d0,.nm
	move.l	Score,(a3)+
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#NLEVELS,d0
	ble.s	.lv
	moveq	#NLEVELS,d0
.lv:	move.w	d0,(a3)+
	; save
	lea	TxtSaving,a0
	move.w	#210,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	bsr	Frame
	bsr	Frame
	bsr	SaveHighscores
	; show the table
	moveq	#3,d0
	bsr	NewScreen
	move.w	#6,BgFade
	bsr	DrawHallOfFame
	bsr	FadeIn
	move.w	#500,d0
	moveq	#1,d1
	bsr	WaitFire
.x:	movem.l	(sp)+,d0-d7/a0-a3
	rts

EnterName:
	movem.l	d0-d7/a0-a3,-(sp)
	moveq	#3,d0
	bsr	NewScreen
	move.w	#7,BgFade
	lea	TxtNewHigh,a0
	moveq	#26,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtTop10List,a0
	moveq	#52,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtYourScore2,a0
	move.l	Score,d0
	lea	12(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtYourScore2,a0
	moveq	#66,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	lea	TxtLevelReached,a0
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#NLEVELS,d0
	ble.s	.l
	moveq	#NLEVELS,d0
.l:	lea	15(a0),a0
	moveq	#2,d1
	bsr	PutNumW
	lea	TxtLevelReached,a0
	moveq	#78,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	lea	TxtEnterName,a0
	moveq	#100,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtNameHelp,a0
	moveq	#0,d0
	move.w	#150,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreLines
	; name buffer: 8 spaces, start with 'A'
	lea	NameBuf,a0
	moveq	#7,d0
.cl:	move.b	#' ',(a0)+
	dbf	d0,.cl
	clr.b	(a0)
	move.b	#'A',NameBuf
	clr.w	NamePos
	bsr	FadeIn
.loop:	; draw name (big) with cursor
	move.w	#80,d0
	moveq	#118,d1
	move.w	#160,d2
	moveq	#16,d3
	moveq	#0,d4
	move.l	BackBuf,a1
	bsr	FillRect
	lea	NameBuf,a0
	move.w	#96,d0
	moveq	#118,d1
	moveq	#C_YELLOW,d2
	bsr	PrintBig
	; cursor underline
	move.l	FrameCount,d0
	and.w	#16,d0
	bne.s	.nc
	move.w	NamePos,d0
	lsl.w	#4,d0
	add.w	#96,d0
	move.w	#135,d1
	moveq	#16,d2
	moveq	#2,d3
	moveq	#C_WHITE,d4
	bsr	FillRect
.nc:	bsr	Frame
	; keyboard
	bsr	GetKey
	tst.w	d0
	bmi	.joy
	cmp.w	#KEY_RETURN,d0
	beq	.done
	cmp.w	#KEY_BACK,d0
	beq.s	.back
	cmp.w	#KEY_DEL,d0
	beq.s	.back
	cmp.w	#KEY_SPACE,d0
	bne.s	.ns
	moveq	#' ',d0
	bra.s	.put
.ns:	bsr	RawToAscii
	tst.w	d0
	beq.s	.joy
	cmp.b	#'A',d0
	blt.s	.dig
	cmp.b	#'Z',d0
	ble.s	.put
.dig:	cmp.b	#'0',d0
	blt.s	.joy
	cmp.b	#'9',d0
	bgt.s	.joy
.put:	move.w	NamePos,d1
	lea	NameBuf,a0
	move.b	d0,(a0,d1.w)
	cmp.w	#7,d1
	bge.s	.joy
	addq.w	#1,NamePos
	moveq	#SFX_MOVE,d0
	bsr	PlaySfx
	bra.s	.joy
.back:	move.w	NamePos,d1
	lea	NameBuf,a0
	move.b	#' ',(a0,d1.w)
	tst.w	d1
	beq.s	.joy
	subq.w	#1,NamePos
	move.w	NamePos,d1
	move.b	#' ',(a0,d1.w)
.joy:	move.w	JoyNew,d6
	move.w	NamePos,d1
	lea	NameBuf,a0
	move.b	(a0,d1.w),d0
	btst	#J_UP,d6
	beq.s	.nu
	bsr	NextChar
	move.b	d0,(a0,d1.w)
	moveq	#SFX_MOVE,d0
	bsr	PlaySfx
.nu:	btst	#J_DOWN,d6
	beq.s	.nd
	move.b	(a0,d1.w),d0
	bsr	PrevChar
	move.b	d0,(a0,d1.w)
	moveq	#SFX_MOVE,d0
	bsr	PlaySfx
.nd:	btst	#J_RIGHT,d6
	beq.s	.nr
	cmp.w	#7,d1
	bge.s	.nr
	addq.w	#1,NamePos
	move.w	NamePos,d1
	cmp.b	#' ',(a0,d1.w)
	bne.s	.nr
	move.b	#'A',(a0,d1.w)
.nr:	btst	#J_LEFT,d6
	beq.s	.nl
	tst.w	d1
	beq.s	.nl
	subq.w	#1,NamePos
.nl:	btst	#J_FIRE,d6
	beq	.loop
.done:	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
	; empty name -> "NO NAME"
	lea	NameBuf,a0
	moveq	#7,d0
.e:	cmp.b	#' ',(a0)+
	bne.s	.ok
	dbf	d0,.e
	lea	NameBuf,a0
	lea	TxtNoName,a1
	moveq	#7,d0
.nn:	move.b	(a1)+,(a0)+
	dbf	d0,.nn
.ok:	movem.l	(sp)+,d0-d7/a0-a3
	rts

; letter cycling: A..Z, space, 0..9
NextChar:
	cmp.b	#'Z',d0
	bne.s	.1
	moveq	#' ',d0
	rts
.1:	cmp.b	#' ',d0
	bne.s	.2
	moveq	#'0',d0
	rts
.2:	cmp.b	#'9',d0
	bne.s	.3
	moveq	#'A',d0
	rts
.3:	addq.b	#1,d0
	rts
PrevChar:
	cmp.b	#'A',d0
	bne.s	.1
	moveq	#'9',d0
	rts
.1:	cmp.b	#'0',d0
	bne.s	.2
	moveq	#' ',d0
	rts
.2:	cmp.b	#' ',d0
	bne.s	.3
	moveq	#'Z',d0
	rts
.3:	subq.b	#1,d0
	rts

;---------------------------------------------------------------------
	section	screendata,data
MenuTexts:	dc.l	TxtStart,TxtBonus,TxtHowItem,TxtNormal,TxtQuit
DiffTexts:	dc.l	TxtEasy,TxtNormal,TxtHard
PowerTexts:	dc.l	TxtPInv,TxtPEnergy,TxtPTwin,TxtPLife
MapLabelPos:	dc.w	28,196, 3,168, 1,190, 23,46, 21,108
TxtStart:	dc.b	'START GAME',0
TxtBonus:	dc.b	'BONUS GAMES',0
TxtHowItem:	dc.b	'HOW TO PLAY',0
TxtEasy:	dc.b	'EASY MODE',0
TxtNormal:	dc.b	'NORMAL MODE',0
TxtHard:	dc.b	'HARD MODE',0
TxtQuit:	dc.b	'QUIT TO WORKBENCH',0
TxtMarkL:	dc.b	'-',0
TxtMarkR:	dc.b	'-',0
TxtAmigaGame:	dc.b	'AN AMIGA 500 GAME',0
TxtCreated:	dc.b	'CREATED BY MARK STRONKS',0
TxtMMusicOn:	dc.b	'M:MUSIC ON ',0
TxtMMusicOff:	dc.b	'M:MUSIC OFF',0
TxtYear:	dc.b	'2026',0
TxtHighScore:	dc.b	'HIGH SCORE ',0
TxtHof:		dc.b	'- HALL OF FAME -',0
TxtTop10:	dc.b	'TOP 10 GHOST ZAPPERS',0
TxtPressPlay:	dc.b	'PRESS FIRE OR SPACE TO PLAY',0
TxtPowerUps:	dc.b	'POWER-UPS',0
TxtCatchThem:	dc.b	'CATCH THEM BEFORE THEY LAND!',0
TxtPInv:	dc.b	'INVINCIBLE FOR 10 SECONDS',0
TxtPEnergy:	dc.b	'FULL ENERGY AT ONCE',0
TxtPTwin:	dc.b	'TWO PROTON BEAMS FOR 15 SECONDS',0
TxtPLife:	dc.b	'EXTRA LIFE',0
TxtBossAhead:	dc.b	'WARNING - BOSS AHEAD!',0
TxtBossInfo:	dc.b	'   CATCH 20 GHOSTS AND HE ARRIVES',10
		dc.b	'     HIT HIM 3 TIMES TO STUN HIM',10
		dc.b	' THEN DEPLOY THE TRAP: STICK UP OR T',10
		dc.b	' ATTACKS: HOMING SPREAD SNIPER PINCER',0
TxtPressFire:	dc.b	'PRESS FIRE OR SPACE',0
TxtHowTitle:	dc.b	'HOW TO PLAY',0
TxtHow:		dc.b	'JOYSTICK IN PORT 2  OR  A / D + SPACE',10,10
		dc.b	'  LEFT / RIGHT   : MOVE',10
		dc.b	'  FIRE / SPACE   : PROTON BEAM',10
		dc.b	'  STICK UP / T   : GHOST TRAP',10
		dc.b	'  P OR ESC       : PAUSE MENU',10
		dc.b	'  M              : MUSIC ON / OFF',10,10
		dc.b	' CATCH 20 GHOSTS TO MEET THE BOSS.',10
		dc.b	' HOLD THE BEAM ON A GHOST TO CATCH IT.',10
		dc.b	' DODGE THE SLIME - WATCH YOUR LIVES.',10
		dc.b	' HIT GHOSTS FAST FOR A COMBO BONUS.',10
		dc.b	' CATCH POWER-UPS BEFORE THEY LAND.',10
		dc.b	' WATCH YOUR ENERGY - THE PACK OVERHEATS',0
TxtPressBack:	dc.b	'PRESS FIRE TO GO BACK',0
TxtFlightTo:	dc.b	'THE FLIGHT TO NEW YORK',0
TxtFlightHome:	dc.b	'THE FLIGHT HOME',0
TxtAmsNY:	dc.b	'AMSTERDAM - NEW YORK',0
TxtNYAms:	dc.b	'NEW YORK - AMSTERDAM',0
TxtAmsterdam:	dc.b	'AMSTERDAM',0
TxtNewYork:	dc.b	'NEW YORK',0
TxtLandedNY:	dc.b	'LANDED IN NEW YORK!',0
TxtWelcomeHome:	dc.b	'WELCOME HOME, AMSTERDAM!',0
TxtNextStop:	dc.b	'NEXT STOP:',0
TxtHeading:	dc.b	'HEADING FOR',0
TxtWelcomeTo:	dc.b	'WELCOME TO',0
TxtLine:	dc.b	'======================================',0
TxtLevelCleared: dc.b	'LEVEL 00 CLEARED!',0
TxtBusted:	dc.b	'GHOSTS BUSTED   0000',0
TxtYourScore:	dc.b	'YOUR SCORE      00000',0
TxtHighScoreL:	dc.b	'HIGH SCORE      00000',0
TxtNextLevel:	dc.b	'NEXT LEVEL: 00',0
TxtPressGoOn:	dc.b	'PRESS SPACE OR FIRE TO GO ON',0
TxtGameOver:	dc.b	'GAME OVER',0
TxtCongrats:	dc.b	'*CONGRATULATIONS,',10,10,'YOU HAVE CLEARED',10,10,'*NEW YORK CITY',10,10,10,'+THE CITY IS SAVED!',0
TxtMission:	dc.b	'MISSION COMPLETE',0
TxtMBusted:	dc.b	'GHOSTS BUSTED   0000',0
TxtMBosses:	dc.b	'BOSSES BEATEN   0000',0
TxtMLives:	dc.b	'LIVES BONUS     0000',0
TxtMFinal:	dc.b	'FINAL SCORE    00000',0
TxtRank:	dc.b	'YOUR RANK',0
TxtLegend:	dc.b	'GHOST LEGEND',0
TxtHunter:	dc.b	'GHOST HUNTER',0
TxtRookie:	dc.b	'ROOKIE ZAPPER',0
TxtCredits:	dc.b	'*CREDITS',10,10
		dc.b	'GHOST ZAPPERS - AMIGA 500 VERSION',10,10
		dc.b	'*CREATED BY MARK STRONKS',10,10
		dc.b	'PROGRAMMING AI : CLAUDE',10
		dc.b	'ORIGINAL MUSIC : CLAUDE',10
		dc.b	'GAMEPLAY : STRONKIE',10
		dc.b	'TESTING : STRONKIE',10,10
		dc.b	'+THERE IS NO COPY RIGHT',10
		dc.b	'+FEEL FREE TO SHARE THIS.',10,10
		dc.b	'THIS GAME IS BASED ON',10
		dc.b	'GHOSTBUSTERS GAME',10,10
		dc.b	'*THE END',10
		dc.b	'THANKS FOR PLAYING!',10
		dc.b	'STAY TUNED FOR MORE',0
TxtSaving:	dc.b	'SAVING HIGH SCORES...',0
TxtNewHigh:	dc.b	'NEW HIGH SCORE!',0
TxtTop10List:	dc.b	'YOU MADE THE TOP 10 LIST',0
TxtYourScore2:	dc.b	'YOUR SCORE: 00000',0
TxtLevelReached: dc.b	'LEVEL REACHED: 00',0
TxtEnterName:	dc.b	'ENTER YOUR NAME',0
TxtNameHelp:	dc.b	'TYPE YOUR NAME AND PRESS RETURN',10
		dc.b	'OR USE THE JOYSTICK:',10
		dc.b	'UP/DOWN:LETTER  RIGHT:NEXT  FIRE:OK',0
TxtNoName:	dc.b	'NO NAME '
; story pages: lines = colour byte + text + 0 ; page ends with 0 colour
StoryPage1:	dc.b	C_YELLOW,'THE NIGHT NEW YORK WENT QUIET',0
		dc.b	C_WHITE,' ',0
		dc.b	C_WHITE,'NEW YORK HAD NEVER BEEN QUIET.',0
		dc.b	C_WHITE,'BUT ON A COLD OCTOBER NIGHT A SILENCE',0
		dc.b	C_WHITE,'CREPT IN UNDER THE NOISE OF THE CITY.',0
		dc.b	C_WHITE,' ',0
		dc.b	C_WHITE,'PEOPLE STOPPED COMING HOME THE SAME.',0
		dc.b	C_WHITE,'THEY STARED AT NOTHING ALL NIGHT',0
		dc.b	C_WHITE,'WHILE SOMETHING WHISPERED THEIR NAMES.',0
		dc.b	0
StoryPage2:	dc.b	C_WHITE,'THE CITY CALLED FOR THE ONLY MAN',0
		dc.b	C_WHITE,'WHO COULD HELP...',0
		dc.b	C_WHITE,' ',0
		dc.b	C_YELLOW,'MARK STRONKS',0
		dc.b	C_GREEN,'GHOST ZAPPER',0
		dc.b	C_WHITE,' ',0
		dc.b	C_WHITE,'HE FLEW IN FROM AMSTERDAM WITH A PROTON',0
		dc.b	C_WHITE,'PACK, A TRAP, A CRACKED SCANNER AND A',0
		dc.b	C_WHITE,'THERMOS OF VERY STRONG COFFEE.',0
		dc.b	0
StoryPage3:	dc.b	C_WHITE,'HIS SCANNER MAPPED THE COLD SPOTS.',0
		dc.b	C_WHITE,'THEY FORMED A GIANT SPIRAL',0
		dc.b	C_WHITE,'WINDING IN TOWARD GRAND CENTRAL.',0
		dc.b	C_WHITE,' ',0
		dc.b	C_BLUE,'BELOW THE STATION WAITED THE CLOCKMAKER,',0
		dc.b	C_BLUE,'A GHOST OF BRASS AND PALE LIGHT,',0
		dc.b	C_BLUE,'STEALING THE TIME OF A WHOLE CITY.',0
		dc.b	C_WHITE,' ',0
		dc.b	C_YELLOW,'ONE MAN. ONE TRAP.',0
		dc.b	C_YELLOW,'ONE CHANCE TO MAKE NEW YORK',0
		dc.b	C_YELLOW,'RUN LATE AGAIN.',0
		dc.b	C_WHITE,' ',0
		dc.b	C_GREEN,'SHOOT THE GHOSTS. SAVE THE CITY.',0
		dc.b	0
	even
StoryPages:	dc.l	StoryPage1,StoryPage2,StoryPage3,0

	section	screenvars,bss
Page:		ds.w	1
PageTimer:	ds.w	1
MenuSel:	ds.w	1
MapFrom:	ds.w	1
MapTo:		ds.w	1
LivesBonus:	ds.w	1
NamePos:	ds.w	1
NameBuf:	ds.b	10

	section	code,code

;---------------------------------------------------------------------
; file: game.s
;---------------------------------------------------------------------
;=====================================================================
; game.s : the main game - player, proton beam, ghosts, slime,
;          power-ups, boss, trap, HUD, pause
;=====================================================================
NLEVELS		equ	5
CATCH_TARGET	equ	20
MAXGHOSTS	equ	8
MAXSLIME	equ	10
MAXPOP		equ	4
PLAYER_Y	equ	211
GUN_DX		equ	15		; beam x offset from player x
ENERGY_MAX	equ	640

; ghost structure
G_ACTIVE	equ	0	; 0 free, 1 alive, 2 sparkle
G_TYPE		equ	2	; 0-3 blob, 4 bat
G_X16		equ	4
G_Y16		equ	6
G_VX		equ	8
G_BASEY		equ	10	; *16
G_PHASE		equ	12
G_PSPEED	equ	14
G_AMP		equ	16
G_TIMER		equ	18
G_BOB		equ	20
G_HITS		equ	22
G_DIVE		equ	24
G_COOL		equ	26
G_W		equ	28
G_H		equ	30
GSIZE		equ	32

; slime / shot structure
S_ACTIVE	equ	0
S_KIND		equ	2	; 0 slime, 1 boss shot (homing), 2 boss shot (straight)
S_X16		equ	4
S_Y16		equ	6
S_VX		equ	8
S_VY		equ	10
SSIZE		equ	12

; popup structure
PO_TEXT		equ	0
PO_COL		equ	4
PO_Y		equ	6
PO_TIME		equ	8
PO_COLOUR	equ	10
POSIZE		equ	12

;---------------------------------------------------------------------
; PlayGame: full game from story to high score entry
;---------------------------------------------------------------------
PlayGame:
	movem.l	d0-d7/a0-a6,-(sp)
	clr.l	Score
	clr.w	Level
	clr.w	TotalCaught
	clr.w	BossesBeaten
	move.w	Difficulty,d0
	lea	StartLives,a0
	add.w	d0,d0
	move.w	(a0,d0.w),Lives
	bsr	Story
	moveq	#0,d0
	bsr	Flight
.level:	bsr	PlayLevel
	tst.w	d0
	bne.s	.notclear
	bsr	LevelClear
	addq.w	#1,Level
	cmp.w	#NLEVELS,Level
	beq.s	.won
	move.w	Level,d0
	subq.w	#1,d0
	move.w	Level,d1
	bsr	MapScreen
	bra.s	.level
.notclear:
	cmp.w	#2,d0
	beq.s	.quit
	bsr	GameOverScreen
	bra.s	.hi
.won:	bsr	Victory
.hi:	bsr	HighScoreCheck
.quit:	bsr	FadeOut
	lea	SongMain,a0
	bsr	PlaySong
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---------------------------------------------------------------------
; PlayLevel: returns d0 = 0 cleared, 1 game over, 2 quit
;---------------------------------------------------------------------
PlayLevel:
	movem.l	d1-d7/a0-a6,-(sp)
	bsr	FadeOut
	move.w	#16,BgFade
	move.w	Level,d0
	lea	LevelScene,a0
	add.w	d0,d0
	move.w	(a0,d0.w),d0
	bsr	SetScene
	bsr	ClearBoth
	bsr	ResetLevel
	move.w	#2,HudDirty
	bsr	DrawHud
	bsr	DrawHudBack2
	lea	SongMain,a0
	bsr	PlaySong
	bsr	FadeIn
	bsr	LevelIntro
	clr.w	LevelResult
.loop:	bsr	GameFrame
	tst.w	LevelDone
	beq.s	.loop
	move.w	LevelResult,d0
	movem.l	(sp)+,d1-d7/a0-a6
	rts

ResetLevel:
	movem.l	d0-d1/a0,-(sp)
	lea	Ghosts,a0
	move.w	#(GSIZE*MAXGHOSTS/2)-1,d0
.c1:	clr.w	(a0)+
	dbf	d0,.c1
	lea	Slimes,a0
	move.w	#(SSIZE*MAXSLIME/2)-1,d0
.c2:	clr.w	(a0)+
	dbf	d0,.c2
	lea	Popups,a0
	move.w	#(POSIZE*MAXPOP/2)-1,d0
.c3:	clr.w	(a0)+
	dbf	d0,.c3
	move.w	#148,PX
	clr.w	PAnim
	clr.w	PDead
	clr.w	PInv
	clr.w	PTwin
	move.w	#ENERGY_MAX,Energy
	clr.w	Overheat
	clr.w	Caught
	clr.w	Combo
	clr.w	ComboTimer
	clr.w	PowActive
	clr.w	BossState
	clr.w	TrapState
	clr.w	LevelDone
	clr.w	GameOverTimer
	clr.w	Firing
	clr.w	FlashCol
	clr.w	FlashTime
	move.w	#60,SpawnTimer
	; difficulty parameters
	move.w	Level,d0
	move.w	Difficulty,d1
	subq.w	#1,d1
	add.w	d1,d0				; effective level (-1..6)
	bpl.s	.ok
	moveq	#0,d0
.ok:	move.w	d0,EffLevel
	movem.l	(sp)+,d0-d1/a0
	rts

; LevelIntro: location name, 3-2-1-GO!
LevelIntro:
	movem.l	d0-d7/a0-a3,-(sp)
	move.w	Level,d0
	lsl.w	#2,d0
	lea	LocNames,a0
	move.l	(a0,d0.w),a0
	moveq	#70,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	moveq	#BOB_PLAYER_STAND,d0
	move.w	PX,d1
	move.w	#PLAYER_Y,d2
	bsr	DrawBobBoth
	moveq	#3,d6
.count:	move.w	#110,d0
	moveq	#16,d1
	move.l	BackBuf,a1
	bsr	ClearRows
	move.l	FrontBuf,a1
	bsr	ClearRows
	lea	CountStrs,a0
	move.w	d6,d0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	move.w	#110,d1
	moveq	#C_WHITE,d2
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	moveq	#SFX_TICK,d0
	tst.w	d6
	bne.s	.t
	moveq	#SFX_SELECT,d0
.t:	bsr	PlaySfx
	moveq	#49,d7
.f:	moveq	#2,d0
	bsr	ScrollCity
	bsr	DrawHud
	bsr	DrawEnergy
	bsr	Frame
	dbf	d7,.f
	dbf	d6,.count
	bsr	ClearBoth
	move.w	#2,HudDirty
	movem.l	(sp)+,d0-d7/a0-a3
	rts

;---------------------------------------------------------------------
; GameFrame: one frame of play
;---------------------------------------------------------------------
GameFrame:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	ClearDirty
	bsr	GameKeys
	tst.w	LevelDone
	bne	.x
	bsr	UpdatePlayer
	bsr	UpdateGhosts
	bsr	UpdateBoss
	bsr	UpdateSlimes
	bsr	UpdatePowerup
	bsr	UpdateTrap
	bsr	UpdatePopups
	moveq	#2,d0
	bsr	ScrollCity
	; flash colour handling
	tst.w	FlashTime
	beq.s	.nf
	subq.w	#1,FlashTime
	bne.s	.nf
	clr.w	FlashCol
.nf:	; draw everything (blitter clear runs meanwhile)
	bsr	DrawTrap
	bsr	DrawGhosts
	bsr	DrawBoss
	bsr	DrawPowerup
	bsr	DrawBeam
	bsr	DrawSlimes
	bsr	DrawPlayer
	bsr	DrawPopups
	bsr	DrawHud
	bsr	DrawEnergy
	bsr	Frame
	; game over delay
	tst.w	GameOverTimer
	beq.s	.x
	subq.w	#1,GameOverTimer
	bne.s	.x
	move.w	#1,LevelResult
	move.w	#1,LevelDone
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; GameKeys: pause / music
GameKeys:
	bsr	GetKey
	tst.w	d0
	bmi.s	.x
	cmp.w	#KEY_M,d0
	bne.s	.nm
	bsr	ToggleMusic
	bra.s	.x
.nm:	cmp.w	#KEY_P,d0
	beq.s	.p
	cmp.w	#KEY_ESC,d0
	bne.s	.x
.p:	bsr	PauseMenu
.x:	rts

ToggleMusic:
	eor.w	#1,MusicOn
	move.w	#2,HudDirty
	rts

;---------------------------------------------------------------------
; Player
;---------------------------------------------------------------------
UpdatePlayer:
	movem.l	d0-d7/a0-a2,-(sp)
	tst.w	PDead
	beq.s	.alive
	subq.w	#1,PDead
.alive:	tst.w	PInv
	beq.s	.ni
	subq.w	#1,PInv
.ni:	tst.w	PTwin
	beq.s	.nt
	subq.w	#1,PTwin
.nt:	tst.w	GameOverTimer
	bne	.nofire
	; movement
	move.w	Joy,d2
	moveq	#0,d3
	btst	#J_LEFT,d2
	beq.s	.nl
	moveq	#-3,d3
.nl:	btst	#J_RIGHT,d2
	beq.s	.nr
	moveq	#3,d3
.nr:	move.w	PX,d0
	add.w	d3,d0
	cmp.w	#-2,d0
	bge.s	.c1
	moveq	#-2,d0
.c1:	cmp.w	#298,d0
	ble.s	.c2
	move.w	#298,d0
.c2:	move.w	d0,PX
	tst.w	d3
	beq.s	.stand
	addq.w	#1,PWalkT
	move.w	PWalkT,d0
	lsr.w	#3,d0
	and.w	#1,d0
	addq.w	#1,d0
	move.w	d0,PAnim
	bra.s	.anim
.stand:	clr.w	PAnim
.anim:	; trap deploy
	btst	#J_UP,JoyNew+1
	beq.s	.notrap
	bsr	DeployTrap
.notrap:
	; fire
	clr.w	Firing
	btst	#J_FIRE,d2
	beq.s	.nofire
	tst.w	Overheat
	bne.s	.nofire
	cmp.w	#5,BossState			; no beam while trapping
	bge.s	.nofire
	move.w	#1,Firing
	move.w	Difficulty,d0
	add.w	d0,d0
	lea	DrainTab,a0
	move.w	(a0,d0.w),d0
	sub.w	d0,Energy
	bgt.s	.en
	clr.w	Energy
	move.w	#1,Overheat
	lea	TxtRecharging,a0
	moveq	#C_MAGENTA,d2
	bsr	AddMsg
.en:	; beam hum
	move.l	FrameCount,d0
	and.w	#3,d0
	bne.s	.done
	tst.w	SfxTicks
	bne.s	.done
	moveq	#SFX_ZAP,d0
	bsr	PlaySfx
	bra.s	.done
.nofire:
	move.w	Energy,d0
	addq.w	#2,d0
	cmp.w	#ENERGY_MAX,d0
	ble.s	.e1
	move.w	#ENERGY_MAX,d0
.e1:	move.w	d0,Energy
	tst.w	Overheat
	beq.s	.done
	cmp.w	#ENERGY_MAX/2,d0
	blt.s	.done
	clr.w	Overheat
.done:	; beam collision
	tst.w	Firing
	beq.s	.x
	move.w	PX,d0
	add.w	#GUN_DX,d0
	bsr	BeamHit
	move.w	d0,BeamTop
	tst.w	PTwin
	beq.s	.x
	move.w	PX,d0
	addq.w	#3,d0
	bsr	BeamHit
	move.w	d0,BeamTop2
.x:	movem.l	(sp)+,d0-d7/a0-a2
	rts

; BeamHit: d0 = beam centre x. Finds the lowest ghost (or boss) in the
; beam column, applies a hit and returns d0 = top y of the beam
BeamHit:
	movem.l	d1-d7/a0-a2,-(sp)
	move.w	d0,d7				; beam x
	moveq	#16,d6				; best bottom y (beam top)
	sub.l	a2,a2				; best ghost
	lea	Ghosts,a0
	moveq	#MAXGHOSTS-1,d5
.g:	cmp.w	#1,G_ACTIVE(a0)
	bne.s	.ng
	move.w	G_X16(a0),d0
	asr.w	#4,d0
	move.w	d7,d1
	sub.w	d0,d1
	cmp.w	#2,d1
	blt.s	.ng
	move.w	G_W(a0),d2
	subq.w	#2,d2
	cmp.w	d2,d1
	bgt.s	.ng
	move.w	G_Y16(a0),d0
	asr.w	#4,d0
	add.w	G_H(a0),d0			; bottom
	cmp.w	#PLAYER_Y,d0
	bge.s	.ng
	cmp.w	d6,d0
	ble.s	.ng
	move.w	d0,d6
	move.l	a0,a2
.ng:	lea	GSIZE(a0),a0
	dbf	d5,.g
	; boss
	cmp.w	#4,BossState
	bne.s	.noboss
	move.w	BX,d0
	addq.w	#6,d0
	cmp.w	d0,d7
	blt.s	.noboss
	add.w	#36,d0
	cmp.w	d0,d7
	bgt.s	.noboss
	move.w	BY,d0
	add.w	#40,d0
	cmp.w	d6,d0
	ble.s	.noboss
	; boss is the lowest target
	move.w	d0,d6
	sub.l	a2,a2
	bsr	BossBeamHit
	bra.s	.ret
.noboss:
	move.l	a2,d0
	beq.s	.ret
	; hit ghost: accumulate
	addq.w	#2,G_HITS(a2)
	move.w	Difficulty,d0
	add.w	d0,d0
	lea	CatchFrames,a0
	move.w	(a0,d0.w),d0
	cmp.w	G_HITS(a2),d0
	bgt.s	.ret
	move.l	a2,a0
	bsr	CatchGhost
.ret:	move.w	d6,d0
	movem.l	(sp)+,d1-d7/a0-a2
	rts

; CatchGhost: a0 = ghost
CatchGhost:
	movem.l	d0-d3/a0-a1,-(sp)
	move.w	#2,G_ACTIVE(a0)
	clr.w	G_TIMER(a0)
	addq.w	#1,Caught
	addq.w	#1,TotalCaught
	move.w	#2,HudDirty
	moveq	#SFX_CATCH,d0
	bsr	PlaySfx
	; combo
	tst.w	ComboTimer
	beq.s	.reset
	addq.w	#1,Combo
	cmp.w	#9,Combo
	ble.s	.cok
	move.w	#9,Combo
	bra.s	.cok
.reset:	move.w	#1,Combo
.cok:	move.w	#90,ComboTimer
	moveq	#10,d0
	mulu	Combo,d0
	bsr	AddScore
	; popup at ghost position
	move.w	Combo,d1
	cmp.w	#1,d1
	bgt.s	.combo
	lea	TxtPlus10,a1
	bra.s	.pop
.combo:	lea	ComboTxt,a1
	add.b	#'0',d1
	move.b	d1,7(a1)
.pop:	move.w	G_X16(a0),d0
	asr.w	#4,d0
	move.w	G_Y16(a0),d1
	asr.w	#4,d1
	bsr	AddPopup
	; maybe drop a power-up
	tst.w	PowActive
	bne.s	.x
	moveq	#7,d0
	bsr	RandRange
	tst.w	d0
	bne.s	.x
	move.w	G_X16(a0),d0
	asr.w	#4,d0
	move.w	G_Y16(a0),d1
	asr.w	#4,d1
	bsr	SpawnPowerup
.x:	; boss trigger
	cmp.w	#CATCH_TARGET,Caught
	blt.s	.nb
	tst.w	BossState
	bne.s	.nb
	move.w	#1,BossState
	move.w	#140,BossTimer
	lea	TxtApproach,a0
	moveq	#C_MAGENTA,d2
	bsr	AddMsg
.nb:	movem.l	(sp)+,d0-d3/a0-a1
	rts

; AddScore: d0 = points
AddScore:
	add.l	d0,Score
	cmp.l	#99999,Score
	ble.s	.ok
	move.l	#99999,Score
.ok:	move.w	#2,HudDirty
	rts

; HitPlayer: slime / shot hit the player
HitPlayer:
	tst.w	PDead
	bne.s	.x
	tst.w	PInv
	bne.s	.x
	tst.w	GameOverTimer
	bne.s	.x
	movem.l	d0/a0,-(sp)
	moveq	#SFX_SLIMED,d0
	bsr	PlaySfx
	move.w	#$0a4,FlashCol
	move.w	#6,FlashTime
	move.w	#110,PDead
	subq.w	#1,Lives
	move.w	#2,HudDirty
	lea	TxtSlimed,a0
	moveq	#C_GREEN,d2
	bsr	AddMsg
	tst.w	Lives
	bgt.s	.ok
	clr.w	Lives
	move.w	#120,GameOverTimer
	lea	SongLose,a0
	bsr	PlaySong
.ok:	movem.l	(sp)+,d0/a0
.x:	rts

DrawPlayer:
	movem.l	d0-d2,-(sp)
	tst.w	PDead
	beq.s	.v
	move.w	PDead,d0
	and.w	#4,d0
	bne.s	.x
.v:	tst.w	PInv
	beq.s	.v2
	move.w	PInv,d0
	cmp.w	#100,d0
	bgt.s	.v2
	and.w	#2,d0
	bne.s	.x
.v2:	moveq	#BOB_PLAYER_STAND,d0
	add.w	PAnim,d0
	tst.w	GameOverTimer
	beq.s	.d
	moveq	#BOB_PLAYER_STAND,d0
.d:	cmp.w	#7,BossState
	bne.s	.d2
	moveq	#BOB_PLAYER_CHEER,d0
.d2:	move.w	PX,d1
	move.w	#PLAYER_Y,d2
	bsr	DrawBob
.x:	movem.l	(sp)+,d0-d2
	rts

;---------------------------------------------------------------------
; Beam
;---------------------------------------------------------------------
DrawBeam:
	tst.w	Firing
	beq.s	.x
	movem.l	d0-d3,-(sp)
	move.w	PX,d0
	add.w	#GUN_DX-8,d0
	move.w	BeamTop,d3
	bsr	DrawBeamCol
	tst.w	PTwin
	beq.s	.n2
	move.w	PX,d0
	subq.w	#5,d0
	move.w	BeamTop2,d3
	bsr	DrawBeamCol
.n2:	movem.l	(sp)+,d0-d3
.x:	rts

; DrawBeamCol: d0 = left x of 16px beam, d3 = top y
DrawBeamCol:
	movem.l	d0-d4,-(sp)
	move.w	ClipTop,-(sp)
	move.w	d3,ClipTop
	move.w	d0,d1
	move.w	#PLAYER_Y+2-16,d2
	move.l	FrameCount,d4
	lsr.w	#1,d4
	and.w	#1,d4
.seg:	cmp.w	d3,d2
	blt.s	.last
	moveq	#BOB_BEAM0,d0
	add.w	d4,d0
	bsr	DrawBob
	sub.w	#16,d2
	bra.s	.seg
.last:	move.w	d2,d0
	add.w	#16,d0
	cmp.w	d3,d0
	ble.s	.done
	moveq	#BOB_BEAM0,d0
	add.w	d4,d0
	bsr	DrawBob
.done:	move.w	(sp)+,ClipTop
	; spark at the impact point
	cmp.w	#17,d3
	blt.s	.ns
	move.l	FrameCount,d0
	and.w	#1,d0
	add.w	#BOB_SPARK0,d0
	subq.w	#3,d1
	move.w	d3,d2
	sub.w	#11,d2
	bsr	DrawBob
.ns:	movem.l	(sp)+,d0-d4
	rts

DrawEnergy:
	movem.l	d0-d5/a0-a1,-(sp)
	move.w	Energy,d3
	ext.l	d3
	divu	#10,d3
	and.w	#$fff8,d3
	tst.w	Overheat
	beq.s	.no
	bset	#15,d3
.no:	lea	EnergyShownA,a0
	cmp.l	#PF2BufA,BackBuf
	beq.s	.a
	lea	EnergyShownB,a0
.a:	cmp.w	(a0),d3
	beq	.skip
	move.w	d3,(a0)
	bclr	#15,d3
	move.w	#248,d0
	moveq	#1,d1
	moveq	#64,d2
	moveq	#C_GREEN,d4
	tst.w	Overheat
	beq.s	.c
	moveq	#C_MAGENTA,d4
.c:	moveq	#C_DARK,d5
	move.l	BackBuf,a1
	bsr	Bar
.skip:	movem.l	(sp)+,d0-d5/a0-a1
	rts

;---------------------------------------------------------------------
; Ghosts
;---------------------------------------------------------------------
UpdateGhosts:
	movem.l	d0-d7/a0-a2,-(sp)
	tst.w	ComboTimer
	beq.s	.ct
	subq.w	#1,ComboTimer
.ct:	; spawning (only before the boss)
	tst.w	BossState
	bne.s	.nospawn
	subq.w	#1,SpawnTimer
	bgt.s	.nospawn
	move.w	EffLevel,d0
	mulu	#6,d0
	neg.w	d0
	add.w	#64,d0
	cmp.w	#22,d0
	bge.s	.st
	moveq	#22,d0
.st:	move.w	d0,SpawnTimer
	bsr	CountGhosts
	move.w	EffLevel,d1
	addq.w	#3,d1
	cmp.w	#7,d1
	ble.s	.mx
	moveq	#7,d1
.mx:	cmp.w	d1,d0
	bge.s	.nospawn
	bsr	SpawnGhost
.nospawn:
	lea	Ghosts,a2
	moveq	#MAXGHOSTS-1,d7
.g:	move.w	G_ACTIVE(a2),d0
	beq	.next
	cmp.w	#2,d0
	bne.s	.alive
	addq.w	#1,G_TIMER(a2)
	cmp.w	#16,G_TIMER(a2)
	blt	.next
	clr.w	G_ACTIVE(a2)
	bra	.next
.alive:	; hit decay
	tst.w	G_HITS(a2)
	beq.s	.nh
	subq.w	#1,G_HITS(a2)
.nh:	; horizontal
	move.w	G_X16(a2),d0
	add.w	G_VX(a2),d0
	move.w	d0,G_X16(a2)
	asr.w	#4,d0
	cmp.w	#1,BossState			; fleeing when the boss comes
	bge.s	.flee
	tst.w	G_VX(a2)
	bmi.s	.left
	cmp.w	#300,d0
	blt.s	.vert
	neg.w	G_VX(a2)
	bra.s	.vert
.left:	cmp.w	#-4,d0
	bgt.s	.vert
	neg.w	G_VX(a2)
	bra.s	.vert
.flee:	cmp.w	#-40,d0
	blt.s	.kill
	cmp.w	#340,d0
	bgt.s	.kill
	bra.s	.vert
.kill:	clr.w	G_ACTIVE(a2)
	bra	.next
.vert:	; dive behaviour for bats
	tst.w	G_DIVE(a2)
	beq.s	.nodive
	move.w	G_DIVE(a2),d0
	add.w	d0,G_BASEY(a2)
	cmp.w	#150*16,G_BASEY(a2)
	blt.s	.d1
	move.w	#-16,G_DIVE(a2)
.d1:	cmp.w	#50*16,G_BASEY(a2)
	bgt.s	.nodive
	tst.w	G_DIVE(a2)
	bpl.s	.nodive
	clr.w	G_DIVE(a2)
.nodive:
	cmp.w	#4,G_TYPE(a2)
	bne.s	.nobat
	tst.w	G_DIVE(a2)
	bne.s	.nobat
	move.w	#200,d0
	bsr	RandRange
	tst.w	d0
	bne.s	.nobat
	move.w	#20,G_DIVE(a2)
.nobat:	move.w	G_PHASE(a2),d0
	add.w	G_PSPEED(a2),d0
	move.w	d0,G_PHASE(a2)
	lsr.w	#4,d0
	and.w	#255,d0
	lea	SinTab,a0
	move.b	(a0,d0.w),d0
	ext.w	d0
	muls	G_AMP(a2),d0
	asr.l	#3,d0				; amp*16*sin/128
	add.w	G_BASEY(a2),d0
	move.w	d0,G_Y16(a2)
	; slime dropping
	tst.w	G_COOL(a2)
	beq.s	.cool
	subq.w	#1,G_COOL(a2)
	bra.s	.next
.cool:	tst.w	BossState
	bne.s	.next
	move.w	G_X16(a2),d0
	asr.w	#4,d0
	add.w	#12,d0
	move.w	PX,d1
	add.w	#12,d1
	sub.w	d1,d0
	bpl.s	.ab
	neg.w	d0
.ab:	cmp.w	#40,d0
	bgt.s	.next
	move.w	#100,d0
	bsr	RandRange
	move.w	EffLevel,d1
	add.w	d1,d1
	addq.w	#3,d1
	cmp.w	d1,d0
	bge.s	.next
	move.w	#80,G_COOL(a2)
	move.w	G_X16(a2),d0
	asr.w	#4,d0
	move.w	G_W(a2),d1
	lsr.w	#1,d1
	add.w	d1,d0
	subq.w	#4,d0
	move.w	G_Y16(a2),d1
	asr.w	#4,d1
	add.w	G_H(a2),d1
	moveq	#0,d2				; kind slime
	moveq	#0,d3				; vx
	move.w	EffLevel,d4
	lsl.w	#2,d4
	add.w	#28,d4				; vy
	bsr	SpawnSlime
.next:	lea	GSIZE(a2),a2
	dbf	d7,.g
	movem.l	(sp)+,d0-d7/a0-a2
	rts

CountGhosts:
	movem.l	d1/a0,-(sp)
	moveq	#0,d0
	lea	Ghosts,a0
	moveq	#MAXGHOSTS-1,d1
.l:	tst.w	G_ACTIVE(a0)
	beq.s	.n
	addq.w	#1,d0
.n:	lea	GSIZE(a0),a0
	dbf	d1,.l
	movem.l	(sp)+,d1/a0
	rts

SpawnGhost:
	movem.l	d0-d3/a0,-(sp)
	lea	Ghosts,a0
	moveq	#MAXGHOSTS-1,d1
.f:	tst.w	G_ACTIVE(a0)
	beq.s	.got
	lea	GSIZE(a0),a0
	dbf	d1,.f
	bra	.x
.got:	move.w	#1,G_ACTIVE(a0)
	clr.w	G_HITS(a0)
	clr.w	G_DIVE(a0)
	clr.w	G_TIMER(a0)
	move.w	#40,G_COOL(a0)
	; type: bats more likely on later levels
	moveq	#10,d0
	bsr	RandRange
	move.w	EffLevel,d1
	addq.w	#1,d1
	cmp.w	d1,d0
	bge.s	.blob
	move.w	#4,G_TYPE(a0)
	move.w	#BOB_BAT0,G_BOB(a0)
	move.w	EffLevel,d2
	add.w	d2,d2
	add.w	#18,d2				; speed
	move.w	#20,G_AMP(a0)
	move.w	#60,G_PSPEED(a0)
	bra.s	.pos
.blob:	moveq	#4,d0
	bsr	RandRange
	move.w	d0,G_TYPE(a0)
	lsl.w	#2,d0
	move.w	d0,d1
	moveq	#4,d0
	bsr	RandRange
	add.w	d1,d0
	add.w	#BOB_GHOST0_0,d0
	move.w	d0,G_BOB(a0)
	move.w	EffLevel,d2
	add.w	d2,d2
	add.w	#9,d2
	moveq	#8,d0
	bsr	RandRange
	add.w	d0,d2
	move.w	#10,G_AMP(a0)
	move.w	#40,G_PSPEED(a0)
.pos:	moveq	#2,d0
	bsr	RandRange
	tst.w	d0
	beq.s	.fromleft
	move.w	#320*16,G_X16(a0)
	neg.w	d2
	bra.s	.y
.fromleft:
	move.w	#-24*16,G_X16(a0)
.y:	move.w	d2,G_VX(a0)
	move.w	#110,d0
	bsr	RandRange
	add.w	#26,d0
	lsl.w	#4,d0
	move.w	d0,G_BASEY(a0)
	move.w	d0,G_Y16(a0)
	move.w	#4096,d0
	bsr	RandRange
	move.w	d0,G_PHASE(a0)
	move.w	G_BOB(a0),d0
	bsr	BobSize
	move.w	d1,G_W(a0)
	move.w	d2,G_H(a0)
.x:	movem.l	(sp)+,d0-d3/a0
	rts

DrawGhosts:
	movem.l	d0-d7/a2,-(sp)
	lea	Ghosts,a2
	moveq	#MAXGHOSTS-1,d7
.g:	move.w	G_ACTIVE(a2),d3
	beq.s	.next
	move.w	G_X16(a2),d1
	asr.w	#4,d1
	move.w	G_Y16(a2),d2
	asr.w	#4,d2
	cmp.w	#2,d3
	bne.s	.alive
	move.w	G_TIMER(a2),d0
	lsr.w	#2,d0
	add.w	#BOB_SPARK0,d0
	bsr	DrawBob
	bra.s	.next
.alive:	move.w	G_BOB(a2),d0
	cmp.w	#4,G_TYPE(a2)
	bne.s	.nb
	move.l	FrameCount,d4
	lsr.w	#3,d4
	and.w	#1,d4
	add.w	d4,d0
.nb:	tst.w	G_HITS(a2)
	beq.s	.dr
	; being zapped: shake
	move.l	FrameCount,d4
	and.w	#1,d4
	add.w	d4,d4
	subq.w	#1,d4
	add.w	d4,d1
.dr:	bsr	DrawBob
.next:	lea	GSIZE(a2),a2
	dbf	d7,.g
	movem.l	(sp)+,d0-d7/a2
	rts

;---------------------------------------------------------------------
; Slime and boss shots
; SpawnSlime: d0 = x, d1 = y, d2 = kind, d3 = vx (1/16), d4 = vy (1/16)
;---------------------------------------------------------------------
SpawnSlime:
	movem.l	d5/a0,-(sp)
	lea	Slimes,a0
	moveq	#MAXSLIME-1,d5
.f:	tst.w	S_ACTIVE(a0)
	beq.s	.got
	lea	SSIZE(a0),a0
	dbf	d5,.f
	bra.s	.x
.got:	move.w	#1,S_ACTIVE(a0)
	move.w	d2,S_KIND(a0)
	lsl.w	#4,d0
	move.w	d0,S_X16(a0)
	lsr.w	#4,d0
	lsl.w	#4,d1
	move.w	d1,S_Y16(a0)
	lsr.w	#4,d1
	move.w	d3,S_VX(a0)
	move.w	d4,S_VY(a0)
	move.l	d0,-(sp)
	moveq	#SFX_DROP,d0
	tst.w	d2
	beq.s	.s
	moveq	#SFX_SHOOT,d0
.s:	tst.w	Firing
	bne.s	.ns
	bsr	PlaySfx
.ns:	move.l	(sp)+,d0
.x:	movem.l	(sp)+,d5/a0
	rts

UpdateSlimes:
	movem.l	d0-d7/a0,-(sp)
	lea	Slimes,a0
	moveq	#MAXSLIME-1,d7
.s:	tst.w	S_ACTIVE(a0)
	beq	.next
	cmp.w	#1,S_KIND(a0)
	bne.s	.move
	; homing: steer towards the player
	move.w	PX,d0
	add.w	#12,d0
	lsl.w	#4,d0
	cmp.w	S_X16(a0),d0
	blt.s	.hl
	cmp.w	#20,S_VX(a0)
	bge.s	.move
	addq.w	#1,S_VX(a0)
	bra.s	.move
.hl:	cmp.w	#-20,S_VX(a0)
	ble.s	.move
	subq.w	#1,S_VX(a0)
.move:	move.w	S_X16(a0),d0
	add.w	S_VX(a0),d0
	move.w	d0,S_X16(a0)
	move.w	S_Y16(a0),d1
	add.w	S_VY(a0),d1
	move.w	d1,S_Y16(a0)
	asr.w	#4,d0
	asr.w	#4,d1
	cmp.w	#236,d1
	blt.s	.on
	clr.w	S_ACTIVE(a0)
	bra.s	.next
.on:	cmp.w	#-16,d0
	blt.s	.off
	cmp.w	#330,d0
	bgt.s	.off
	; collide with the player box (px+5 .. px+19, y 205..232)
	move.w	PX,d2
	addq.w	#1,d2
	cmp.w	d2,d0
	blt.s	.next
	add.w	#16,d2
	cmp.w	d2,d0
	bgt.s	.next
	cmp.w	#PLAYER_Y-6,d1
	blt.s	.next
	clr.w	S_ACTIVE(a0)
	bsr	HitPlayer
	bra.s	.next
.off:	clr.w	S_ACTIVE(a0)
.next:	lea	SSIZE(a0),a0
	dbf	d7,.s
	movem.l	(sp)+,d0-d7/a0
	rts

DrawSlimes:
	movem.l	d0-d7/a0,-(sp)
	lea	Slimes,a0
	moveq	#MAXSLIME-1,d7
.s:	tst.w	S_ACTIVE(a0)
	beq.s	.next
	move.w	S_X16(a0),d1
	asr.w	#4,d1
	move.w	S_Y16(a0),d2
	asr.w	#4,d2
	moveq	#BOB_SLIME,d0
	tst.w	S_KIND(a0)
	beq.s	.d
	moveq	#BOB_BSHOT,d0
.d:	bsr	DrawBob
.next:	lea	SSIZE(a0),a0
	dbf	d7,.s
	movem.l	(sp)+,d0-d7/a0
	rts

;---------------------------------------------------------------------
; Power-ups: d0 = x, d1 = y
;---------------------------------------------------------------------
SpawnPowerup:
	movem.l	d0-d2,-(sp)
	move.w	#1,PowActive
	move.w	d0,PowX
	lsl.w	#4,d1
	move.w	d1,PowY16
	moveq	#10,d0
	bsr	RandRange
	moveq	#3,d2				; star (extra life) 10%
	cmp.w	#9,d0
	beq.s	.s
	moveq	#3,d0
	bsr	RandRange
	move.w	d0,d2
.s:	move.w	d2,PowType
	movem.l	(sp)+,d0-d2
	rts

UpdatePowerup:
	movem.l	d0-d2/a0,-(sp)
	tst.w	PowActive
	beq	.x
	add.w	#20,PowY16
	move.w	PowY16,d1
	asr.w	#4,d1
	cmp.w	#222,d1
	blt.s	.fall
	clr.w	PowActive			; landed - lost
	bra	.x
.fall:	cmp.w	#PLAYER_Y-16,d1
	blt	.x
	move.w	PowX,d0
	sub.w	PX,d0
	cmp.w	#-18,d0
	blt	.x
	cmp.w	#18,d0
	bgt	.x
	; collected
	clr.w	PowActive
	move.w	PowType,d0
	bne.s	.n0
	move.w	#500,PInv
	lea	TxtInvincible,a0
	bra.s	.msg
.n0:	cmp.w	#1,d0
	bne.s	.n1
	move.w	#ENERGY_MAX,Energy
	clr.w	Overheat
	lea	TxtFullPower,a0
	bra.s	.msg
.n1:	cmp.w	#2,d0
	bne.s	.n2
	move.w	#750,PTwin
	lea	TxtTwin,a0
	bra.s	.msg
.n2:	cmp.w	#9,Lives
	bge.s	.n3
	addq.w	#1,Lives
.n3:	move.w	#2,HudDirty
	lea	TxtExtraLife,a0
	moveq	#SFX_LIFE,d0
	bsr	PlaySfx
	moveq	#C_YELLOW,d2
	bsr	AddMsg
	moveq	#50,d0
	bsr	AddScore
	bra.s	.x
.msg:	moveq	#C_YELLOW,d2
	bsr	AddMsg
	moveq	#SFX_POWER,d0
	bsr	PlaySfx
	moveq	#25,d0
	bsr	AddScore
.x:	movem.l	(sp)+,d0-d2/a0
	rts

DrawPowerup:
	tst.w	PowActive
	beq.s	.x
	movem.l	d0-d2,-(sp)
	moveq	#BOB_PW_INV,d0
	add.w	PowType,d0
	move.w	PowX,d1
	move.w	PowY16,d2
	asr.w	#4,d2
	bsr	DrawBob
	movem.l	(sp)+,d0-d2
.x:	rts

;---------------------------------------------------------------------
; Boss
; BossState: 0 none 1 approaching 2 warning 3 entering 4 fighting
;            5 stunned 6 being captured 7 captured
;---------------------------------------------------------------------
UpdateBoss:
	movem.l	d0-d7/a0-a2,-(sp)
	move.w	BossState,d0
	beq	.x
	cmp.w	#1,d0
	bne.s	.s2
	subq.w	#1,BossTimer
	bgt	.x
	move.w	#2,BossState
	move.w	#150,BossTimer
	moveq	#SFX_WARN,d0
	bsr	PlaySfx
	lea	SongBoss,a0
	bsr	PlaySong
	bra	.x
.s2:	cmp.w	#2,d0
	bne	.s3
	subq.w	#1,BossTimer
	move.w	BossTimer,d0
	and.w	#31,d0
	bne.s	.nw
	moveq	#SFX_WARN,d0
	bsr	PlaySfx
.nw:	tst.w	BossTimer
	bgt	.x
	move.w	#3,BossState
	move.w	#136,BX
	move.w	#-44,BY
	move.w	#2,BVX
	move.w	Level,d0
	add.w	d0,d0
	lea	BossHP,a0
	move.w	(a0,d0.w),BHP
	clr.w	BHitTimer
	move.w	#100,BAttackTimer
	clr.w	BAttack
	clr.w	BPhase
	move.w	#2,HudDirty
	moveq	#SFX_BOSSROAR,d0
	bsr	PlaySfx
	bra	.x
.s3:	cmp.w	#3,d0
	bne.s	.s4
	addq.w	#1,BY
	cmp.w	#40,BY
	blt	.x
	move.w	#4,BossState
	bra	.x
.s4:	cmp.w	#4,d0
	bne	.s5
	tst.w	BHitTimer
	beq.s	.nht
	subq.w	#1,BHitTimer
.nht:	bsr	BossMove
	; attacks
	subq.w	#1,BAttackTimer
	bgt	.x
	bsr	BossAttack
	moveq	#60,d0
	bsr	RandRange
	add.w	#90,d0
	move.w	EffLevel,d1
	lsl.w	#3,d1
	sub.w	d1,d0
	move.w	d0,BAttackTimer
	bra	.x
.s5:	cmp.w	#5,d0
	bne	.s6
	; stunned: sink slowly, drift
	cmp.w	#104,BY
	bge.s	.sunk
	addq.w	#1,BY
.sunk:	addq.w	#1,BPhase
	move.w	BPhase,d0
	and.w	#3,d0
	bne.s	.nd
	move.w	BVX,d0
	add.w	d0,BX
	cmp.w	#16,BX
	bgt.s	.b1
	move.w	#1,BVX
.b1:	cmp.w	#256,BX
	blt.s	.nd
	move.w	#-1,BVX
.nd:	subq.w	#1,BStun
	bgt	.x
	; recovered
	move.w	#1,BHP
	move.w	#4,BossState
	move.w	#2,HudDirty
	move.w	#40,BY
	lea	TxtRecovered,a0
	moveq	#C_MAGENTA,d2
	bsr	AddMsg
	bra	.x
.s6:	cmp.w	#6,d0
	bne.s	.s7
	; pulled into the trap
	move.w	TrapX,d0
	sub.w	#12,d0
	cmp.w	BX,d0
	beq.s	.cx
	blt.s	.cl
	addq.w	#1,BX
	bra.s	.cx
.cl:	subq.w	#1,BX
.cx:	addq.w	#2,BY
	cmp.w	#190,BY
	blt	.x
	move.w	#7,BossState
	move.w	#200,BossTimer
	move.w	#3,TrapState			; closed with boss inside
	moveq	#SFX_TRAP,d0
	bsr	PlaySfx
	addq.w	#1,BossesBeaten
	move.w	#100,d0
	bsr	AddScore
	lea	TxtCaptured,a0
	moveq	#C_YELLOW,d2
	bsr	AddMsg
	lea	SongWin,a0
	bsr	PlaySong
	bra.s	.x
.s7:	subq.w	#1,BossTimer
	bgt.s	.x
	clr.w	LevelResult
	move.w	#1,LevelDone
.x:	movem.l	(sp)+,d0-d7/a0-a2
	rts

BossMove:
	move.w	BVX,d0
	add.w	d0,BX
	cmp.w	#8,BX
	bgt.s	.l
	move.w	#2,BVX
	tst.w	EffLevel
	beq.s	.l
	move.w	#3,BVX
.l:	cmp.w	#264,BX
	blt.s	.r
	move.w	#-2,BVX
	tst.w	EffLevel
	beq.s	.r
	move.w	#-3,BVX
.r:	addq.w	#3,BPhase
	move.w	BPhase,d0
	and.w	#255,d0
	lea	SinTab,a0
	move.b	(a0,d0.w),d0
	ext.w	d0
	asr.w	#3,d0
	add.w	#40,d0
	move.w	d0,BY
	rts

; BossBeamHit: beam touches the boss this frame
BossBeamHit:
	tst.w	BHitTimer
	bne	.x
	addq.w	#2,BHitAcc
	cmp.w	#14,BHitAcc
	blt.s	.x
	clr.w	BHitAcc
	move.w	#50,BHitTimer
	moveq	#SFX_BOSSHIT,d0
	bsr	PlaySfx
	move.w	#$a6c,FlashCol
	move.w	#3,FlashTime
	moveq	#20,d0
	bsr	AddScore
	move.w	#2,HudDirty
	subq.w	#1,BHP
	bgt.s	.x
	clr.w	BHP
	move.w	#5,BossState
	move.w	#600,BStun
	move.w	#1,BVX
	lea	TxtStunned,a0
	moveq	#C_YELLOW,d2
	bsr	AddMsg
	lea	TxtStandUnder,a0
	moveq	#C_WHITE,d2
	bsr	AddMsg2
.x:	rts

; BossAttack: HOMING, SPREAD, SNIPER, PINCER in turn
BossAttack:
	movem.l	d0-d6,-(sp)
	move.w	BX,d0
	add.w	#20,d0
	move.w	BY,d1
	add.w	#38,d1
	move.w	BAttack,d6
	addq.w	#1,BAttack
	and.w	#3,BAttack
	tst.w	d6
	bne.s	.a1
	; homing
	moveq	#1,d2
	moveq	#0,d3
	moveq	#22,d4
	bsr	SpawnSlime
	bra	.x
.a1:	cmp.w	#1,d6
	bne.s	.a2
	moveq	#2,d2
	moveq	#28,d4
	moveq	#-18,d3
	bsr	SpawnSlime
	moveq	#0,d3
	bsr	SpawnSlime
	moveq	#18,d3
	bsr	SpawnSlime
	bra	.x
.a2:	cmp.w	#2,d6
	bne.s	.a3
	; sniper: fast, aimed at the player
	moveq	#2,d2
	moveq	#64,d4
	move.w	PX,d3
	add.w	#8,d3
	sub.w	d0,d3
	asl.w	#4,d3				; dx*16
	ext.l	d3
	divs	#40,d3				; ~40 frames to fall
	bsr	SpawnSlime
	bra.s	.x
.a3:	; pincer: two shots from the screen edges converging on the player
	moveq	#2,d2
	moveq	#30,d4
	move.w	BY,d1
	moveq	#0,d0
	move.w	PX,d3
	add.w	#8,d3
	asl.w	#4,d3
	ext.l	d3
	divs	#60,d3
	bsr	SpawnSlime
	move.w	#304,d0
	move.w	PX,d3
	add.w	#8,d3
	sub.w	#304,d3
	asl.w	#4,d3
	ext.l	d3
	divs	#60,d3
	bsr	SpawnSlime
.x:	movem.l	(sp)+,d0-d6
	rts

DrawBoss:
	movem.l	d0-d2,-(sp)
	move.w	BossState,d0
	cmp.w	#3,d0
	blt.s	.x
	cmp.w	#7,d0
	beq.s	.x
	moveq	#BOB_BOSS,d0
	cmp.w	#NLEVELS-1,Level		; the Clockmaker is brass coloured
	bne.s	.nc
	moveq	#BOB_BOSS_HIT,d0
.nc:	tst.w	BHitTimer
	beq.s	.nh
	move.w	BHitTimer,d1
	and.w	#4,d1
	beq.s	.nh
	moveq	#BOB_BOSS_STUN,d0
.nh:	cmp.w	#5,BossState
	blt.s	.d
	moveq	#BOB_BOSS_STUN,d0
	move.l	FrameCount,d1
	and.w	#8,d1
	beq.s	.d
	moveq	#BOB_BOSS,d0
.d:	move.w	BX,d1
	move.w	BY,d2
	bsr	DrawBob
.x:	movem.l	(sp)+,d0-d2
	rts

;---------------------------------------------------------------------
; Trap: TrapState 0 none, 1 open + beam, 2 closing, 3 closed (boss caught)
;---------------------------------------------------------------------
DeployTrap:
	cmp.w	#5,BossState
	bne.s	.x
	tst.w	TrapState
	bne.s	.x
	move.w	#1,TrapState
	move.w	#70,TrapTimer
	move.w	PX,TrapX
	moveq	#SFX_TRAP,d0
	bsr	PlaySfx
.x:	rts

UpdateTrap:
	movem.l	d0-d2,-(sp)
	move.w	TrapState,d0
	beq	.x
	cmp.w	#1,d0
	bne.s	.s2
	; capture check: boss centre above the trap
	cmp.w	#5,BossState
	bne.s	.nc
	cmp.w	#80,BY
	blt.s	.nc
	move.w	BX,d0
	add.w	#24,d0
	move.w	TrapX,d1
	add.w	#12,d1
	sub.w	d1,d0
	bpl.s	.ab
	neg.w	d0
.ab:	cmp.w	#26,d0
	bgt.s	.nc
	move.w	#6,BossState
	move.w	#2,HudDirty
	bra.s	.x
.nc:	cmp.w	#6,BossState
	beq.s	.x
	subq.w	#1,TrapTimer
	bgt.s	.x
	move.w	#2,TrapState
	move.w	#30,TrapTimer
	bra.s	.x
.s2:	cmp.w	#2,d0
	bne.s	.x
	subq.w	#1,TrapTimer
	bgt.s	.x
	clr.w	TrapState
.x:	movem.l	(sp)+,d0-d2
	rts

DrawTrap:
	movem.l	d0-d4,-(sp)
	move.w	TrapState,d4
	beq	.x
	move.w	TrapX,d1
	move.w	#224,d2
	moveq	#BOB_TRAP_CLOSED,d0
	cmp.w	#1,d4
	bne.s	.d
	moveq	#BOB_TRAP_OPEN,d0
	bsr	DrawBob
	; capture beam
	move.w	TrapX,d1
	subq.w	#4,d1
	move.w	ClipTop,-(sp)
	move.w	BY,d3
	add.w	#20,d3
	cmp.w	#6,BossState
	beq.s	.tb
	cmp.w	#5,BossState
	beq.s	.tb
	move.w	#120,d3
.tb:	move.w	d3,ClipTop
	move.w	#208,d2
	move.l	FrameCount,d4
	lsr.w	#2,d4
	and.w	#1,d4
.seg:	moveq	#BOB_TBEAM0,d0
	add.w	d4,d0
	bsr	DrawBob
	sub.w	#16,d2
	move.w	d2,d0
	add.w	#16,d0
	cmp.w	d3,d0
	bgt.s	.seg
	move.w	(sp)+,ClipTop
	bra.s	.x
.d:	bsr	DrawBob
.x:	movem.l	(sp)+,d0-d4
	rts

;---------------------------------------------------------------------
; Popups (floating text) and centre messages
; AddPopup: a1 = text, d0 = x, d1 = y ; AddMsg: a0 = text, d2 = colour
;---------------------------------------------------------------------
AddPopup:
	movem.l	d0-d3/a0,-(sp)
	lea	Popups+POSIZE*2,a0		; slots 2,3 for small popups
	moveq	#1,d3
.f:	tst.w	PO_TIME(a0)
	beq.s	.got
	lea	POSIZE(a0),a0
	dbf	d3,.f
	lea	Popups+POSIZE*2,a0
.got:	move.l	a1,PO_TEXT(a0)
	lsr.w	#3,d0
	bpl.s	.c0
	moveq	#0,d0
.c0:	cmp.w	#32,d0
	ble.s	.c1
	moveq	#32,d0
.c1:	move.w	d0,PO_COL(a0)
	cmp.w	#24,d1
	bge.s	.y
	moveq	#24,d1
.y:	move.w	d1,PO_Y(a0)
	move.w	#40,PO_TIME(a0)
	move.w	#C_YELLOW,PO_COLOUR(a0)
	movem.l	(sp)+,d0-d3/a0
	rts

AddMsg:	movem.l	d0-d1/a1,-(sp)
	lea	Popups,a1
	move.w	#84,d1
	bra.s	AddMsgC
AddMsg2:
	movem.l	d0-d1/a1,-(sp)
	lea	Popups+POSIZE,a1
	move.w	#98,d1
AddMsgC:
	move.l	a0,PO_TEXT(a1)
	bsr	CentreCol
	move.w	d0,PO_COL(a1)
	move.w	d1,PO_Y(a1)
	move.w	#150,PO_TIME(a1)
	move.w	d2,PO_COLOUR(a1)
	movem.l	(sp)+,d0-d1/a1
	rts

UpdatePopups:
	movem.l	d0-d1/a0,-(sp)
	lea	Popups,a0
	moveq	#MAXPOP-1,d0
.l:	tst.w	PO_TIME(a0)
	beq.s	.n
	subq.w	#1,PO_TIME(a0)
	cmp.l	#Popups+POSIZE*2,a0
	blt.s	.n
	move.l	FrameCount,d1
	and.w	#1,d1
	sub.w	d1,PO_Y(a0)
.n:	lea	POSIZE(a0),a0
	dbf	d0,.l
	movem.l	(sp)+,d0-d1/a0
	rts

DrawPopups:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	Popups,a2
	moveq	#MAXPOP-1,d3
.l:	tst.w	PO_TIME(a2)
	beq.s	.n
	; blinking warning message during the boss warning
	move.l	PO_TEXT(a2),a0
	move.w	PO_COL(a2),d0
	move.w	PO_Y(a2),d1
	move.w	PO_COLOUR(a2),d2
	move.l	BackBuf,a1
	bsr	Print
.n:	lea	POSIZE(a2),a2
	dbf	d3,.l
	; boss warning banner
	cmp.w	#2,BossState
	bne.s	.x
	move.l	FrameCount,d0
	and.w	#16,d0
	beq.s	.x
	lea	TxtWarning,a0
	moveq	#70,d1
	moveq	#C_MAGENTA,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	lea	TxtBossIncoming,a0
	move.w	#100,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBack
	move.w	Level,d0
	lea	BossNames,a0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	move.w	#114,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBack
.x:	movem.l	(sp)+,d0-d3/a0-a2
	rts

;---------------------------------------------------------------------
; HUD
;---------------------------------------------------------------------
DrawHudBack2:
	move.w	#2,HudDirty
	rts

DrawHud:
	tst.w	HudDirty
	beq	.x
	subq.w	#1,HudDirty
	movem.l	d0-d7/a0-a2,-(sp)
	move.l	BackBuf,a1
	; clear HUD rows
	moveq	#0,d0
	moveq	#0,d1
	move.w	#320,d2
	moveq	#16,d3
	moveq	#0,d4
	bsr	FillRect
	move.w	#248,d1
	moveq	#8,d3
	bsr	FillRect
	lea	EnergyShownA,a0
	cmp.l	#PF2BufA,BackBuf
	beq.s	.ea
	lea	EnergyShownB,a0
.ea:	move.w	#-1,(a0)
	; lives
	lea	TmpStr,a0
	move.w	Lives,d0
	cmp.w	#7,d0
	ble.s	.lv
	moveq	#7,d0
.lv:	subq.w	#1,d0
	bmi.s	.nolives
.hl:	move.b	#$7e,(a0)+
	dbf	d0,.hl
.nolives:
	clr.b	(a0)
	lea	TmpStr,a0
	moveq	#0,d0
	moveq	#0,d1
	moveq	#C_MAGENTA,d2
	bsr	Print
	lea	TxtHudTitle,a0
	moveq	#11,d0
	moveq	#C_WHITE,d2
	bsr	Print
	; caught
	lea	TxtCaught,a0
	move.w	Caught,d0
	cmp.w	#CATCH_TARGET,d0
	ble.s	.cc
	moveq	#CATCH_TARGET,d0
.cc:	lea	7(a0),a0
	moveq	#2,d1
	bsr	PutNumW
	lea	TxtCaught,a0
	moveq	#0,d0
	moveq	#8,d1
	moveq	#C_GREEN,d2
	bsr	Print
	; location or boss hp
	cmp.w	#4,BossState
	blt.s	.loc
	cmp.w	#6,BossState
	bge.s	.loc
	lea	TxtBossHP,a0
	move.w	BHP,d0
	add.b	#'0',d0
	move.b	d0,8(a0)
	moveq	#16,d0
	moveq	#8,d1
	moveq	#C_MAGENTA,d2
	bsr	Print
	bra.s	.mus
.loc:	move.w	Level,d0
	lsl.w	#2,d0
	lea	LocNames,a0
	move.l	(a0,d0.w),a0
	moveq	#16,d0
	moveq	#8,d1
	moveq	#C_BLUE,d2
	bsr	Print
.mus:	lea	TxtMusicOn,a0
	tst.w	MusicOn
	bne.s	.mo
	lea	TxtMusicOff,a0
.mo:	moveq	#30,d0
	moveq	#8,d1
	moveq	#C_BLUE,d2
	bsr	Print
	; bottom line
	lea	TxtBottom,a0
	move.l	Score,d0
	lea	6(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtBottom,a0
	move.l	HiData+4+8,d0			; best score
	cmp.l	Score,d0
	bge.s	.hs
	move.l	Score,d0
.hs:	lea	17(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtBottom,a0
	move.w	Level,d0
	addq.w	#1,d0
	lea	33(a0),a0
	moveq	#2,d1
	bsr	PutNumW
	lea	TxtBottom,a0
	moveq	#1,d0
	move.w	#248,d1
	moveq	#C_WHITE,d2
	bsr	Print
	movem.l	(sp)+,d0-d7/a0-a2
.x:	rts

;---------------------------------------------------------------------
; Pause menu
;---------------------------------------------------------------------
PauseMenu:
	movem.l	d0-d7/a0-a2,-(sp)
	move.w	#6,BgFade
	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
.redraw:
	bsr	ClearBoth
	move.w	#2,HudDirty
	bsr	DrawHud
	bsr	CopyBuffers
	lea	TxtPaused,a0
	moveq	#56,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	lea	TxtPScore,a0
	move.l	Score,d0
	lea	6(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtPScore,a0
	move.l	HiData+4+8,d0
	cmp.l	Score,d0
	bge.s	.b
	move.l	Score,d0
.b:	lea	18(a0),a0
	moveq	#5,d1
	bsr	PutNum
	lea	TxtPScore,a0
	moveq	#80,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtPLives,a0
	move.w	Lives,d0
	lea	6(a0),a0
	moveq	#1,d1
	bsr	PutNumW
	lea	TxtPLives,a0
	move.w	Level,d0
	addq.w	#1,d0
	lea	16(a0),a0
	moveq	#1,d1
	bsr	PutNumW
	lea	TxtPLives,a0
	moveq	#92,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtPCaught,a0
	move.w	TotalCaught,d0
	lea	14(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtPCaught,a0
	moveq	#104,d1
	moveq	#C_GREEN,d2
	bsr	PrintCentreBoth
	lea	TxtPHelp,a0
	moveq	#9,d0
	moveq	#124,d1
	moveq	#C_BLUE,d2
	bsr	PrintBoth
	lea	TxtPKeys,a0
	move.w	#166,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
.loop:	bsr	Frame
	bsr	GetKey
	tst.w	d0
	bmi.s	.loop
	cmp.w	#KEY_P,d0
	beq.s	.resume
	cmp.w	#KEY_ESC,d0
	beq.s	.resume
	cmp.w	#KEY_M,d0
	bne.s	.nm
	bsr	ToggleMusic
	bra	.redraw
.nm:	cmp.w	#KEY_Q,d0
	bne.s	.loop
	lea	TxtQuitQ,a0
	move.w	#184,d1
	moveq	#C_MAGENTA,d2
	bsr	PrintCentreBoth
.q:	bsr	Frame
	bsr	GetKey
	cmp.w	#KEY_Y,d0
	beq.s	.quit
	cmp.w	#KEY_N,d0
	beq	.redraw
	cmp.w	#KEY_ESC,d0
	beq	.redraw
	bra.s	.q
.quit:	move.w	#2,LevelResult
	move.w	#1,LevelDone
.resume:
	move.w	#16,BgFade
	bsr	ClearBoth
	move.w	#2,HudDirty
	clr.w	Joy
	movem.l	(sp)+,d0-d7/a0-a2
	rts

;---------------------------------------------------------------------
; strings / tables for the game
;---------------------------------------------------------------------
	section	gamedata,data
StartLives:	dc.w	5,3,2
DrainTab:	dc.w	3,4,5
CatchFrames:	dc.w	8,12,16
BossHP:		dc.w	3,3,3,4,5
LevelScene:	dc.w	0,1,2,4,3
LocNames:	dc.l	LocJFK,LocHarbor,LocLiberty,LocHarlem,LocManhattan
BossNames:	dc.l	BossM,BossM,BossM,BossM,BossC
LocJFK:		dc.b	'JFK AIRPORT',0
LocHarbor:	dc.b	'HARBOR',0
LocLiberty:	dc.b	'STATUE OF LIBERTY',0
LocHarlem:	dc.b	'HARLEM',0
LocManhattan:	dc.b	'MANHATTAN',0
BossM:		dc.b	'THE MARSHMALLOW MAULER',0
BossC:		dc.b	'THE CLOCKMAKER',0
CountStrs:	dc.l	TxtGo,Txt1,Txt2,Txt3
TxtGo:		dc.b	'GO!',0
Txt1:		dc.b	'1',0
Txt2:		dc.b	'2',0
Txt3:		dc.b	'3',0
TxtRecharging:	dc.b	'RECHARGING',0
TxtPlus10:	dc.b	'+10',0
ComboTxt:	dc.b	'COMBO X2',0
TxtApproach:	dc.b	'YOU HEAR THE BOSS APPROACHING...',0
TxtSlimed:	dc.b	'SLIMED!',0
TxtInvincible:	dc.b	'INVINCIBLE!',0
TxtFullPower:	dc.b	'FULL POWER!',0
TxtTwin:	dc.b	'TWIN BEAMS!',0
TxtExtraLife:	dc.b	'EXTRA LIFE!',0
TxtRecovered:	dc.b	'THE BOSS RECOVERED!',0
TxtCaptured:	dc.b	'BOSS CAPTURED!  +100',0
TxtStunned:	dc.b	'BOSS STUNNED! DEPLOY THE TRAP!',0
TxtStandUnder:	dc.b	'STAND UNDER IT - PRESS UP OR T',0
TxtWarning:	dc.b	'WARNING!',0
TxtBossIncoming: dc.b	'!!! BOSS INCOMING !!!',0
TxtHudTitle:	dc.b	"STRONKIE'S ZAPPERS",0
TxtCaught:	dc.b	'CAUGHT:00/20',0
TxtBossHP:	dc.b	'BOSS HP:3',0
TxtMusicOn:	dc.b	'MUSIC ON ',0
TxtMusicOff:	dc.b	'MUSIC OFF',0
TxtBottom:	dc.b	'SCORE:00000   HI:00000     LEVEL:01',0
TxtPaused:	dc.b	'** PAUSED **',0
TxtPScore:	dc.b	'SCORE 00000  BEST 00000',0
TxtPLives:	dc.b	'LIVES 0   LEVEL 0',0
TxtPCaught:	dc.b	'GHOSTS CAUGHT 0000',0
TxtPHelp:	dc.b	'A D OR STICK : MOVE',10
		dc.b	'SPACE OR FIRE: BEAM',10
		dc.b	'UP OR T      : GHOST TRAP',0
TxtPKeys:	dc.b	'P:RESUME  Q:QUIT  M:MUSIC',0
TxtQuitQ:	dc.b	'QUIT TO TITLE? Y OR N',0
	even

	section	gamevars,bss
Score:		ds.l	1
Level:		ds.w	1
EffLevel:	ds.w	1
Difficulty:	ds.w	1
Lives:		ds.w	1
TotalCaught:	ds.w	1
BossesBeaten:	ds.w	1
Caught:		ds.w	1
Combo:		ds.w	1
ComboTimer:	ds.w	1
PX:		ds.w	1
PAnim:		ds.w	1
PWalkT:		ds.w	1
PDead:		ds.w	1
PInv:		ds.w	1
PTwin:		ds.w	1
Energy:		ds.w	1
Overheat:	ds.w	1
Firing:		ds.w	1
BeamTop:	ds.w	1
BeamTop2:	ds.w	1
SpawnTimer:	ds.w	1
PowActive:	ds.w	1
PowType:	ds.w	1
PowX:		ds.w	1
PowY16:		ds.w	1
BossState:	ds.w	1
BossTimer:	ds.w	1
BX:		ds.w	1
BY:		ds.w	1
BVX:		ds.w	1
BHP:		ds.w	1
BHitTimer:	ds.w	1
BHitAcc:	ds.w	1
BAttackTimer:	ds.w	1
BAttack:	ds.w	1
BPhase:		ds.w	1
BStun:		ds.w	1
TrapState:	ds.w	1
TrapTimer:	ds.w	1
TrapX:		ds.w	1
LevelDone:	ds.w	1
LevelResult:	ds.w	1
GameOverTimer:	ds.w	1
HudDirty:	ds.w	1
FlashTime:	ds.w	1
Ghosts:		ds.b	GSIZE*MAXGHOSTS
Slimes:		ds.b	SSIZE*MAXSLIME
Popups:		ds.b	POSIZE*MAXPOP

	section	code,code

;---------------------------------------------------------------------
; file: bonus.s
;---------------------------------------------------------------------
;=====================================================================
; bonus.s : bonus games - Slime Dodge, Ghost Whack, Memory Ghosts,
;           Ghost Invaders
;=====================================================================
BEST_BASE	equ	HiData+4+HI_ENTRY*10	; 4 words

BonusMenu:
	movem.l	d0-d7/a0-a3,-(sp)
	clr.w	BonusSel
.redraw:
	moveq	#4,d0
	bsr	NewScreen
	move.w	#7,BgFade
	bsr	DrawBonusMenu
	bsr	FadeIn
.loop:	moveq	#1,d0
	bsr	ScrollCity
	bsr	Frame
	bsr	GetKey
	cmp.w	#KEY_ESC,d0
	beq	.back
	move.w	d0,d7
	move.w	JoyNew,d6
	btst	#J_UP,d6
	beq.s	.nu
	subq.w	#1,BonusSel
	bpl.s	.mv
	move.w	#4,BonusSel
	bra.s	.mv
.nu:	btst	#J_DOWN,d6
	beq.s	.nd
	addq.w	#1,BonusSel
	cmp.w	#5,BonusSel
	blt.s	.mv
	clr.w	BonusSel
.mv:	moveq	#SFX_MOVE,d0
	bsr	PlaySfx
	bsr	DrawBonusItems
	bra.s	.loop
.nd:	btst	#J_FIRE,d6
	bne.s	.sel
	cmp.w	#KEY_RETURN,d7
	beq.s	.sel
	cmp.w	#KEY_SPACE,d7
	bne.s	.loop
.sel:	moveq	#SFX_SELECT,d0
	bsr	PlaySfx
	move.w	BonusSel,d0
	cmp.w	#4,d0
	beq.s	.back
.again:	move.w	BonusSel,d0
	bsr	RunBonus			; d0 = score
	; best?
	lea	BEST_BASE,a0
	move.w	BonusSel,d1
	add.w	d1,d1
	cmp.w	(a0,d1.w),d0
	bls.s	.nobest
	move.w	d0,(a0,d1.w)
	move.w	#1,NewBest
	bra.s	.res
.nobest:
	clr.w	NewBest
.res:	bsr	BonusResult			; d0 = 1 again, 0 menu
	tst.w	NewBest
	beq.s	.ns
	bsr	SaveHighscores
.ns:	tst.w	d0
	bne.s	.again
	lea	SongMain,a0
	bsr	PlaySong
	bra	.redraw
.back:	movem.l	(sp)+,d0-d7/a0-a3
	rts

RunBonus:
	movem.l	d1-d7/a0-a6,-(sp)
	tst.w	d0
	bne.s	.1
	bsr	SlimeDodge
	bra.s	.x
.1:	cmp.w	#1,d0
	bne.s	.2
	bsr	GhostWhack
	bra.s	.x
.2:	cmp.w	#2,d0
	bne.s	.3
	bsr	MemoryGhosts
	bra.s	.x
.3:	bsr	GhostInvaders
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts

DrawBonusMenu:
	lea	TxtBonusTitle,a0
	moveq	#22,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtBonusKeys,a0
	move.w	#236,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	bsr	DrawBonusItems
	rts

DrawBonusItems:
	movem.l	d0-d7/a0-a2,-(sp)
	moveq	#0,d7
	moveq	#52,d6
	lea	BonusNames,a2
.l:	moveq	#0,d0
	move.w	d6,d1
	move.w	#320,d2
	moveq	#20,d3
	moveq	#0,d4
	move.l	BackBuf,a1
	bsr	FillRect
	move.l	FrontBuf,a1
	bsr	FillRect
	move.l	(a2)+,a0
	moveq	#C_WHITE,d2
	cmp.w	BonusSel,d7
	bne.s	.c
	moveq	#C_YELLOW,d2
.c:	move.w	d6,d1
	bsr	PrintCentreBoth
	cmp.w	#4,d7
	beq.s	.n
	move.l	(a2)+,a0			; description
	move.w	d6,d1
	add.w	#10,d1
	moveq	#C_BLUE,d2
	bsr	PrintCentreBoth
	; best
	lea	TxtBest,a0
	lea	BEST_BASE,a1
	move.w	d7,d0
	add.w	d0,d0
	move.w	(a1,d0.w),d0
	lea	5(a0),a0
	moveq	#4,d1
	bsr	PutNumW
	lea	TxtBest,a0
	moveq	#30,d0
	move.w	d6,d1
	moveq	#C_GREEN,d2
	bsr	PrintBoth
.n:	add.w	#34,d6
	addq.w	#1,d7
	cmp.w	#5,d7
	bne	.l
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; BonusResult: shows "FIRE: AGAIN   ESC: MENU" and waits. returns d0 = 1 again
BonusResult:
	movem.l	d1-d2/a0,-(sp)
	lea	TxtAgain,a0
	move.w	#184,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	tst.w	NewBest
	beq.s	.w
	lea	TxtNewBest,a0
	move.w	#170,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
.w:	clr.w	JoyNew
	moveq	#30,d0
.pause:	bsr	Frame
	dbf	d0,.pause
.l:	bsr	Frame
	btst	#J_FIRE,JoyNew+1
	bne.s	.again
	bsr	GetKey
	cmp.w	#KEY_SPACE,d0
	beq.s	.again
	cmp.w	#KEY_RETURN,d0
	beq.s	.again
	cmp.w	#KEY_ESC,d0
	bne.s	.l
	moveq	#0,d0
	bra.s	.x
.again:	moveq	#1,d0
.x:	movem.l	(sp)+,d1-d2/a0
	rts

; BonusHud: a0 = title, prints title on row 0 and TmpStr on row 8 (both buffers)
BonusHeader:
	movem.l	d0-d4/a0-a1,-(sp)
	moveq	#0,d0
	moveq	#0,d1
	move.w	#320,d2
	moveq	#16,d3
	moveq	#0,d4
	move.l	BackBuf,a1
	bsr	FillRect
	moveq	#0,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBack
	lea	TmpStr,a0
	moveq	#8,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBack
	movem.l	(sp)+,d0-d4/a0-a1
	rts

; CopyStr: a0 src -> TmpStr
CopyStr:
	movem.l	a0-a1,-(sp)
	lea	TmpStr,a1
.c:	move.b	(a0)+,(a1)+
	bne.s	.c
	movem.l	(sp)+,a0-a1
	rts

;---------------------------------------------------------------------
; 1. SLIME DODGE - survive the falling slime.  score = time in 1/10 s
;---------------------------------------------------------------------
SlimeDodge:
	moveq	#4,d0
	bsr	NewScreen
	bsr	ResetLevel
	move.w	#1,Lives
	move.w	#1,Overheat
	clr.w	Energy
	clr.w	BTime
	move.w	#40,BSpawn
	clr.w	BCount
	lea	SongMain,a0
	bsr	PlaySong
	bsr	FadeIn
.loop:	bsr	ClearDirty
	bsr	GetKey
	; spawn slime
	subq.w	#1,BSpawn
	bgt.s	.ns
	move.w	BTime,d0
	lsr.w	#4,d0
	neg.w	d0
	add.w	#34,d0
	cmp.w	#7,d0
	bge.s	.sp
	moveq	#7,d0
.sp:	move.w	d0,BSpawn
	move.w	#304,d0
	bsr	RandRange
	moveq	#16,d1
	moveq	#0,d2
	moveq	#0,d3
	move.w	BTime,d4
	lsr.w	#5,d4
	add.w	#24,d4
	cmp.w	#80,d4
	ble.s	.vy
	moveq	#80,d4
.vy:	bsr	SpawnSlime
.ns:	bsr	UpdatePlayer
	move.w	#1,Overheat
	bsr	UpdateSlimes
	bsr	UpdatePopups
	bsr	DrawSlimes
	bsr	DrawPlayer
	bsr	DrawPopups
	tst.w	GameOverTimer
	bne.s	.dead
	move.l	FrameCount,d0
	divu	#5,d0
	swap	d0
	tst.w	d0
	bne.s	.hud
	addq.w	#1,BTime
.hud:	lea	TxtSDHud,a0
	bsr	CopyStr
	lea	TmpStr+5,a0
	move.w	BTime,d0
	moveq	#4,d1
	bsr	PutNumW
	lea	TmpStr+18,a0
	move.w	BEST_BASE,d0
	bsr	PutNumW
	lea	TxtSlimeDodge,a0
	bsr	BonusHeader
	bsr	Frame
	bra	.loop
.dead:	; slimed
	clr.w	GameOverTimer
	clr.w	FlashCol
	clr.w	FlashTime
	bsr	ClearBoth
	lea	TxtGotSlimed,a0
	moveq	#80,d1
	moveq	#C_GREEN,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtSDHud,a0
	bsr	CopyStr
	lea	TmpStr+5,a0
	move.w	BTime,d0
	moveq	#4,d1
	bsr	PutNumW
	lea	TmpStr+18,a0
	move.w	BEST_BASE,d0
	cmp.w	BTime,d0
	bhs.s	.b
	move.w	BTime,d0
.b:	bsr	PutNumW
	lea	TmpStr,a0
	move.w	#120,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	move.w	BTime,d0
	rts

;---------------------------------------------------------------------
; 2. GHOST WHACK - zap ghosts in the windows. score = hits (of 30)
;---------------------------------------------------------------------
GW_X0	equ	40
GW_Y0	equ	48
GhostWhack:
	moveq	#3,d0
	bsr	NewScreen
	clr.w	BHits
	move.w	#30,BCount			; ghosts left
	clr.w	CurX
	clr.w	CurY
	move.w	#-1,GhostWin
	move.w	#30,BSpawn
	lea	SongMain,a0
	bsr	PlaySong
	bsr	FadeIn
.loop:	bsr	ClearDirty
	bsr	GetKey
	; cursor movement
	move.w	JoyNew,d6
	btst	#J_LEFT,d6
	beq.s	.nl
	tst.w	CurX
	beq.s	.nl
	subq.w	#1,CurX
.nl:	btst	#J_RIGHT,d6
	beq.s	.nr
	cmp.w	#3,CurX
	beq.s	.nr
	addq.w	#1,CurX
.nr:	btst	#J_UP,d6
	beq.s	.nu
	tst.w	CurY
	beq.s	.nu
	subq.w	#1,CurY
.nu:	btst	#J_DOWN,d6
	beq.s	.nd
	cmp.w	#2,CurY
	beq.s	.nd
	addq.w	#1,CurY
.nd:	; ghost timing
	tst.w	GhostWin
	bpl.s	.active
	subq.w	#1,BSpawn
	bgt.s	.fire
	tst.w	BCount
	beq	.end
	moveq	#12,d0
	bsr	RandRange
	move.w	d0,GhostWin
	moveq	#4,d0
	bsr	RandRange
	lsl.w	#2,d0
	add.w	#BOB_GHOST0_0,d0
	move.w	d0,GhostBob
	move.w	BCount,d0
	add.w	d0,d0
	add.w	#24,d0				; visible time shrinks
	move.w	d0,GhostTime
	clr.w	GhostHit
	subq.w	#1,BCount
	bra.s	.fire
.active:
	subq.w	#1,GhostTime
	bgt.s	.fire
	move.w	#-1,GhostWin
	move.w	#12,BSpawn
.fire:	btst	#J_FIRE,d6
	beq.s	.draw
	move.w	CurY,d0
	lsl.w	#2,d0
	add.w	CurX,d0
	cmp.w	GhostWin,d0
	bne.s	.miss
	tst.w	GhostHit
	bne.s	.draw
	move.w	#1,GhostHit
	move.w	#14,GhostTime
	addq.w	#1,BHits
	moveq	#SFX_CATCH,d0
	bsr	PlaySfx
	bra.s	.draw
.miss:	moveq	#SFX_BUZZ,d0
	bsr	PlaySfx
.draw:	; windows
	moveq	#11,d7
.w:	move.w	d7,d0
	bsr	WinXY
	moveq	#BOB_WINDOW,d0
	bsr	DrawBob
	dbf	d7,.w
	; ghost
	move.w	GhostWin,d0
	bmi.s	.nog
	bsr	WinXY
	addq.w	#8,d1
	addq.w	#6,d2
	move.w	GhostBob,d0
	tst.w	GhostHit
	beq.s	.g
	move.w	GhostTime,d0
	lsr.w	#2,d0
	neg.w	d0
	addq.w	#3,d0
	and.w	#3,d0
	add.w	#BOB_SPARK0,d0
.g:	bsr	DrawBob
.nog:	; cursor
	move.w	CurY,d0
	lsl.w	#2,d0
	add.w	CurX,d0
	bsr	WinXY
	addq.w	#8,d1
	addq.w	#4,d2
	moveq	#BOB_CROSS,d0
	bsr	DrawBob
	; header
	lea	TxtGWHud,a0
	bsr	CopyStr
	lea	TmpStr+5,a0
	move.w	BHits,d0
	moveq	#2,d1
	bsr	PutNumW
	lea	TmpStr+14,a0
	move.w	BCount,d0
	bsr	PutNumW
	lea	TmpStr+23,a0
	move.w	BEST_BASE+2,d0
	bsr	PutNumW
	lea	TxtGhostWhack,a0
	bsr	BonusHeader
	bsr	Frame
	bra	.loop
.end:	bsr	ClearBoth
	lea	TxtGWResult,a0
	bsr	CopyStr
	lea	TmpStr+7,a0
	move.w	BHits,d0
	moveq	#2,d1
	bsr	PutNumW
	lea	TmpStr+22,a0
	move.w	BEST_BASE+2,d0
	cmp.w	BHits,d0
	bhs.s	.b
	move.w	BHits,d0
.b:	bsr	PutNumW
	lea	TmpStr,a0
	moveq	#80,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	lea	TxtKeepPract,a0
	move.w	BHits,d0
	cmp.w	#12,d0
	blo.s	.r
	lea	TxtNotBad,a0
	cmp.w	#20,d0
	blo.s	.r
	lea	TxtGreatZap,a0
	cmp.w	#27,d0
	blo.s	.r
	lea	TxtGhostMaster,a0
.r:	moveq	#100,d1
	moveq	#C_YELLOW,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	move.w	BHits,d0
	rts

; WinXY: d0 = window 0..11 -> d1 x, d2 y
WinXY:
	move.w	d0,d1
	and.w	#3,d1
	mulu	#64,d1
	add.w	#GW_X0,d1
	move.w	d0,d2
	lsr.w	#2,d2
	mulu	#52,d2
	add.w	#GW_Y0,d2
	rts

;---------------------------------------------------------------------
; 3. MEMORY GHOSTS - repeat the sequence. score = rounds
;---------------------------------------------------------------------
MemoryGhosts:
	moveq	#3,d0
	bsr	NewScreen
	; random sequence of 24
	lea	MemSeq,a0
	moveq	#23,d7
.r:	moveq	#4,d0
	bsr	RandRange
	move.b	d0,(a0)+
	dbf	d7,.r
	clr.w	BRound
	move.w	#-1,MemLit
	bsr	StopMusic
	bsr	FadeIn
.round:	; WATCH...
	lea	TxtWatch,a0
	move.l	a0,MemMsg
	moveq	#40,d0
	bsr	MemFrames
	moveq	#0,d6
.show:	lea	MemSeq,a0
	move.b	(a0,d6.w),d0
	ext.w	d0
	move.w	d0,MemLit
	add.w	#SFX_NOTE0,d0
	bsr	PlaySfx
	move.w	BRound,d0
	neg.w	d0
	add.w	#30,d0
	cmp.w	#12,d0
	bge.s	.t
	moveq	#12,d0
.t:	bsr	MemFrames
	move.w	#-1,MemLit
	moveq	#8,d0
	bsr	MemFrames
	addq.w	#1,d6
	cmp.w	BRound,d6
	ble.s	.show
	; YOUR TURN
	lea	TxtYourTurn,a0
	move.l	a0,MemMsg
	moveq	#0,d6
.input:	moveq	#1,d0
	bsr	MemFrames
	bsr	GetKey
	move.w	JoyNew,d1
	moveq	#-1,d0
	btst	#J_UP,d1
	beq.s	.i1
	moveq	#0,d0
.i1:	btst	#J_RIGHT,d1
	beq.s	.i2
	moveq	#1,d0
.i2:	btst	#J_DOWN,d1
	beq.s	.i3
	moveq	#2,d0
.i3:	btst	#J_LEFT,d1
	beq.s	.i4
	moveq	#3,d0
.i4:	tst.w	d0
	bmi.s	.input
	move.w	d0,MemLit
	move.w	d0,d5
	add.w	#SFX_NOTE0,d0
	bsr	PlaySfx
	moveq	#12,d0
	bsr	MemFrames
	move.w	#-1,MemLit
	lea	MemSeq,a0
	move.b	(a0,d6.w),d0
	ext.w	d0
	cmp.w	d0,d5
	bne.s	.wrong
	addq.w	#1,d6
	cmp.w	BRound,d6
	ble.s	.input
	; round complete
	addq.w	#1,BRound
	cmp.w	#24,BRound
	beq.s	.perfect
	moveq	#20,d0
	bsr	MemFrames
	bra	.round
.wrong:	moveq	#SFX_BUZZ,d0
	bsr	PlaySfx
	bsr	ClearBoth
	lea	TxtWrong,a0
	bsr	CopyStr
	lea	TmpStr+16,a0
	move.w	BRound,d0
	moveq	#2,d1
	bsr	PutNumW
	bra.s	.res
.perfect:
	bsr	ClearBoth
	lea	TxtPerfect,a0
	bsr	CopyStr
.res:	lea	TmpStr,a0
	moveq	#90,d1
	moveq	#C_YELLOW,d2
	bsr	PrintCentreBoth
	move.w	BRound,d0
	rts

; MemFrames: run d0 frames of the memory screen
MemFrames:
	movem.l	d0-d7/a0-a2,-(sp)
	move.w	d0,d7
.f:	bsr	ClearDirty
	moveq	#3,d6
.g:	lea	MemPos,a0
	move.w	d6,d0
	lsl.w	#2,d0
	move.w	(a0,d0.w),d1
	move.w	2(a0,d0.w),d2
	lea	MemBobs,a0
	move.w	d6,d0
	add.w	d0,d0
	move.w	(a0,d0.w),d0
	cmp.w	MemLit,d6
	bne.s	.d
	; lit: sparkle ring and lifted ghost
	movem.l	d0-d2,-(sp)
	moveq	#BOB_SPARK3,d0
	subq.w	#1,d1
	subq.w	#2,d2
	bsr	DrawBob
	movem.l	(sp)+,d0-d2
	subq.w	#4,d2
.d:	bsr	DrawBob
	dbf	d6,.g
	lea	TxtMemHud,a0
	bsr	CopyStr
	lea	TmpStr+6,a0
	move.w	BRound,d0
	moveq	#2,d1
	bsr	PutNumW
	lea	TmpStr+15,a0
	move.w	BEST_BASE+4,d0
	bsr	PutNumW
	lea	TxtMemoryGhosts,a0
	bsr	BonusHeader
	move.l	MemMsg,a0
	move.w	#200,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBack
	bsr	Frame
	subq.w	#1,d7
	bgt	.f
	movem.l	(sp)+,d0-d7/a0-a2
	rts

;---------------------------------------------------------------------
; 4. GHOST INVADERS
;---------------------------------------------------------------------
INV_COLS	equ	6
INV_ROWS	equ	4
GhostInvaders:
	moveq	#3,d0
	bsr	NewScreen
	bsr	ResetLevel
	clr.w	BScore
	move.w	#1,BWave
	move.w	#3,BLives
	lea	SongBoss,a0
	bsr	PlaySong
	bsr	FadeIn
.wave:	; set up formation
	lea	InvAlive,a0
	moveq	#INV_COLS*INV_ROWS-1,d0
.a:	st	(a0)+
	dbf	d0,.a
	move.w	#INV_COLS*INV_ROWS,InvLeft
	move.w	#40,InvX
	move.w	#28,InvY
	move.w	#1,InvDir
	clr.w	BoltY
	clr.w	PDead
.loop:	bsr	ClearDirty
	bsr	GetKey
	; player
	move.w	Joy,d2
	btst	#J_LEFT,d2
	beq.s	.nl
	subq.w	#3,PX
	bpl.s	.nl
	clr.w	PX
.nl:	btst	#J_RIGHT,d2
	beq.s	.nr
	addq.w	#3,PX
	cmp.w	#296,PX
	ble.s	.nr
	move.w	#296,PX
.nr:	tst.w	PDead
	beq.s	.pd
	subq.w	#1,PDead
.pd:	; fire bolt
	btst	#J_FIRE,d2
	beq.s	.nf
	tst.w	BoltY
	bne.s	.nf
	move.w	PX,d0
	add.w	#GUN_DX-2,d0
	move.w	d0,BoltX
	move.w	#PLAYER_Y-4,BoltY
	moveq	#SFX_SHOOT,d0
	bsr	PlaySfx
.nf:	tst.w	BoltY
	beq.s	.nb
	subq.w	#6,BoltY
	cmp.w	#20,BoltY
	bgt.s	.nb
	clr.w	BoltY
.nb:	; formation movement
	move.w	InvLeft,d0
	lsr.w	#2,d0
	add.w	#2,d0				; frames per step (fewer ghosts = faster)
	sub.w	BWave,d0
	cmp.w	#1,d0
	bge.s	.sp
	moveq	#1,d0
.sp:	addq.w	#1,InvTick
	cmp.w	InvTick,d0
	bgt.s	.nomove
	clr.w	InvTick
	move.w	InvDir,d0
	add.w	d0,d0
	add.w	d0,InvX
	bsr	InvBounds			; d0 = min x, d1 = max x of live ghosts
	cmp.w	#4,d0
	blt.s	.turn
	cmp.w	#300,d1
	ble.s	.nomove
.turn:	neg.w	InvDir
	addq.w	#6,InvY
	move.w	InvDir,d0
	add.w	d0,d0
	add.w	d0,InvX
.nomove:
	; ghosts shoot slime
	moveq	#60,d0
	bsr	RandRange
	cmp.w	BWave,d0
	bge.s	.noshot
	moveq	#INV_COLS,d0
	bsr	RandRange
	bsr	InvBottom			; d0 col -> d1 = index or -1
	tst.w	d1
	bmi.s	.noshot
	move.w	d1,d0
	bsr	InvXY
	move.w	d1,d0
	addq.w	#8,d0
	move.w	d2,d1
	add.w	#18,d1
	moveq	#0,d2
	moveq	#0,d3
	moveq	#30,d4
	bsr	SpawnSlime
.noshot:
	; bolt vs ghosts
	tst.w	BoltY
	beq.s	.nohit
	lea	InvAlive,a0
	moveq	#INV_COLS*INV_ROWS-1,d7
.h:	tst.b	(a0,d7.w)
	beq.s	.hn
	move.w	d7,d0
	bsr	InvXY
	move.w	BoltX,d0
	sub.w	d1,d0
	cmp.w	#-2,d0
	blt.s	.hn
	cmp.w	#22,d0
	bgt.s	.hn
	move.w	BoltY,d0
	sub.w	d2,d0
	bmi.s	.hn
	cmp.w	#20,d0
	bgt.s	.hn
	clr.b	(a0,d7.w)
	subq.w	#1,InvLeft
	clr.w	BoltY
	moveq	#0,d0
	move.w	d7,d0
	divu	#INV_COLS,d0
	neg.w	d0
	addq.w	#4,d0
	mulu	#10,d0
	add.w	d0,BScore
	moveq	#SFX_CATCH,d0
	bsr	PlaySfx
	bra.s	.nohit
.hn:	dbf	d7,.h
.nohit:	; slime vs player (own check: uses BLives)
	lea	Slimes,a0
	moveq	#MAXSLIME-1,d7
.s:	tst.w	S_ACTIVE(a0)
	beq.s	.sn
	move.w	S_Y16(a0),d1
	add.w	S_VY(a0),d1
	move.w	d1,S_Y16(a0)
	asr.w	#4,d1
	cmp.w	#236,d1
	blt.s	.son
	clr.w	S_ACTIVE(a0)
	bra.s	.sn
.son:	cmp.w	#PLAYER_Y-6,d1
	blt.s	.sn
	move.w	S_X16(a0),d0
	asr.w	#4,d0
	move.w	PX,d2
	addq.w	#1,d2
	cmp.w	d2,d0
	blt.s	.sn
	add.w	#16,d2
	cmp.w	d2,d0
	bgt.s	.sn
	clr.w	S_ACTIVE(a0)
	tst.w	PDead
	bne.s	.sn
	move.w	#90,PDead
	subq.w	#1,BLives
	moveq	#SFX_SLIMED,d0
	bsr	PlaySfx
.sn:	lea	SSIZE(a0),a0
	dbf	d7,.s
	; draw formation
	lea	InvAlive,a2
	moveq	#INV_COLS*INV_ROWS-1,d7
.d:	tst.b	(a2,d7.w)
	beq.s	.dn
	move.w	d7,d0
	bsr	InvXY
	moveq	#0,d0
	move.w	d7,d0
	divu	#INV_COLS,d0
	and.w	#3,d0
	add.w	#BOB_INV0,d0
	bsr	DrawBob
.dn:	dbf	d7,.d
	tst.w	BoltY
	beq.s	.nob
	moveq	#BOB_BOLT,d0
	move.w	BoltX,d1
	move.w	BoltY,d2
	bsr	DrawBob
.nob:	bsr	DrawSlimes
	clr.w	PAnim
	bsr	DrawPlayer
	; header
	lea	TxtGIHud,a0
	bsr	CopyStr
	lea	TmpStr+6,a0
	move.w	BScore,d0
	moveq	#4,d1
	bsr	PutNumW
	lea	TmpStr+17,a0
	move.w	BWave,d0
	moveq	#1,d1
	bsr	PutNumW
	lea	TmpStr+26,a0
	move.w	BLives,d0
	bsr	PutNumW
	lea	TxtGhostInvaders,a0
	bsr	BonusHeader
	bsr	Frame
	; end conditions
	tst.w	BLives
	ble.s	.over
	tst.w	InvLeft
	beq.s	.next
	move.w	InvY,d0
	add.w	#INV_ROWS*22,d0
	cmp.w	#PLAYER_Y,d0
	bge.s	.over
	bra	.loop
.next:	addq.w	#1,BWave
	add.w	#100,BScore
	moveq	#SFX_LIFE,d0
	bsr	PlaySfx
	lea	Slimes,a0
	move.w	#(SSIZE*MAXSLIME/2)-1,d0
.cs:	clr.w	(a0)+
	dbf	d0,.cs
	bra	.wave
.over:	bsr	ClearBoth
	lea	TxtGameOver,a0
	moveq	#70,d1
	moveq	#C_MAGENTA,d2
	move.l	BackBuf,a1
	bsr	PrintBigCentre
	move.l	FrontBuf,a1
	bsr	PrintBigCentre
	lea	TxtGIHud,a0
	bsr	CopyStr
	lea	TmpStr+6,a0
	move.w	BScore,d0
	moveq	#4,d1
	bsr	PutNumW
	lea	TmpStr+17,a0
	move.w	BWave,d0
	moveq	#1,d1
	bsr	PutNumW
	lea	TmpStr+26,a0
	moveq	#0,d0
	bsr	PutNumW
	lea	TmpStr,a0
	move.w	#110,d1
	moveq	#C_WHITE,d2
	bsr	PrintCentreBoth
	move.w	BScore,d0
	rts

; InvXY: d0 = index -> d1 x, d2 y
InvXY:
	movem.l	d0,-(sp)
	and.l	#$ffff,d0
	divu	#INV_COLS,d0
	move.w	d0,d2				; row
	swap	d0				; col
	move.w	d0,d1
	mulu	#36,d1
	add.w	InvX,d1
	mulu	#22,d2
	add.w	InvY,d2
	movem.l	(sp)+,d0
	rts

; InvBounds -> d0 = leftmost x, d1 = rightmost x+24 of live ghosts
InvBounds:
	movem.l	d2-d5/a0,-(sp)
	move.w	#999,d4
	move.w	#-999,d5
	lea	InvAlive,a0
	moveq	#INV_COLS*INV_ROWS-1,d3
.l:	tst.b	(a0,d3.w)
	beq.s	.n
	move.w	d3,d0
	bsr	InvXY
	cmp.w	d4,d1
	bge.s	.a
	move.w	d1,d4
.a:	add.w	#24,d1
	cmp.w	d5,d1
	ble.s	.n
	move.w	d1,d5
.n:	dbf	d3,.l
	move.w	d4,d0
	move.w	d5,d1
	movem.l	(sp)+,d2-d5/a0
	rts

; InvBottom: d0 = column -> d1 = index of the lowest live ghost or -1
InvBottom:
	movem.l	d0/d2/a0,-(sp)
	lea	InvAlive,a0
	move.w	d0,d1
	add.w	#INV_COLS*(INV_ROWS-1),d1
	moveq	#INV_ROWS-1,d2
.l:	tst.b	(a0,d1.w)
	bne.s	.x
	sub.w	#INV_COLS,d1
	dbf	d2,.l
	moveq	#-1,d1
.x:	movem.l	(sp)+,d0/d2/a0
	rts

;---------------------------------------------------------------------
	section	bonusdata,data
BonusNames:	dc.l	TxtSlimeDodge,TxtSDDesc,TxtGhostWhack,TxtGWDesc
		dc.l	TxtMemoryGhosts,TxtMGDesc,TxtGhostInvaders,TxtGIDesc,TxtBackTitle
MemPos:		dc.w	148,60, 214,108, 148,156, 82,108
MemBobs:	dc.w	BOB_GHOST0_0,BOB_GHOST1_2,BOB_GHOST2_3,BOB_GHOST3_1
TxtBonusTitle:	dc.b	'BONUS GAMES',0
TxtBonusKeys:	dc.b	'FIRE: PLAY    ESC: BACK',0
TxtBackTitle:	dc.b	'BACK TO TITLE',0
TxtBest:	dc.b	'BEST 0000',0
TxtSlimeDodge:	dc.b	'SLIME DODGE',0
TxtSDDesc:	dc.b	'DODGE THE FALLING SLIME',0
TxtGhostWhack:	dc.b	'GHOST WHACK',0
TxtGWDesc:	dc.b	'ZAP GHOSTS IN THE WINDOWS',0
TxtMemoryGhosts: dc.b	'MEMORY GHOSTS',0
TxtMGDesc:	dc.b	'REPEAT THE GHOST NOTES',0
TxtGhostInvaders: dc.b	'GHOST INVADERS',0
TxtGIDesc:	dc.b	'STOP THE GHOST INVASION',0
TxtAgain:	dc.b	'FIRE: AGAIN   ESC: MENU',0
TxtNewBest:	dc.b	'NEW BEST SCORE!',0
TxtSDHud:	dc.b	'TIME:0000    BEST:0000',0
TxtGotSlimed:	dc.b	'YOU GOT SLIMED!',0
TxtGWHud:	dc.b	'HITS:00  LEFT:00  BEST:00',0
TxtGWResult:	dc.b	'ZAPPED 00 OF 30  BEST 00',0
TxtGhostMaster:	dc.b	'GHOST MASTER!',0
TxtGreatZap:	dc.b	'GREAT ZAPPER!',0
TxtNotBad:	dc.b	'NOT BAD AT ALL',0
TxtKeepPract:	dc.b	'KEEP PRACTISING',0
TxtMemHud:	dc.b	'ROUND:00  BEST:00',0
TxtWatch:	dc.b	'   WATCH...   ',0
TxtYourTurn:	dc.b	'  YOUR TURN!  ',0
TxtWrong:	dc.b	'WRONG!  YOU GOT 00 ROUNDS',0
TxtPerfect:	dc.b	'PERFECT MEMORY!  24 ROUNDS',0
TxtGIHud:	dc.b	'SCORE:0000  WAVE:1  LIVES:3',0
	even

	section	bonusvars,bss
BonusSel:	ds.w	1
NewBest:	ds.w	1
BTime:		ds.w	1
BSpawn:		ds.w	1
BCount:		ds.w	1
BHits:		ds.w	1
BRound:		ds.w	1
BScore:		ds.w	1
BWave:		ds.w	1
BLives:		ds.w	1
CurX:		ds.w	1
CurY:		ds.w	1
GhostWin:	ds.w	1
GhostBob:	ds.w	1
GhostTime:	ds.w	1
GhostHit:	ds.w	1
MemLit:		ds.w	1
MemMsg:		ds.l	1
MemSeq:		ds.b	24
InvAlive:	ds.b	INV_COLS*INV_ROWS
InvLeft:	ds.w	1
InvX:		ds.w	1
InvY:		ds.w	1
InvDir:		ds.w	1
InvTick:	ds.w	1
BoltX:		ds.w	1
BoltY:		ds.w	1

	section	code,code

;---------------------------------------------------------------------
; file: data.s
;---------------------------------------------------------------------
;=====================================================================
; data.s : constant data, strings, variables and chip buffers
;=====================================================================
	section	constdata,data
GfxName:	dc.b	'graphics.library',0
DosName:	dc.b	'dos.library',0
HiName:		dc.b	'GhostZappers.hi',0
	even

; raw key -> ascii (0 = none), codes $00-$3f
RawAscii:
	dc.b	'`1234567890-=',0,0,'0'		; 00-0f
	dc.b	'QWERTYUIOP[]',0,'123'		; 10-1f
	dc.b	"ASDFGHJKL;'",0,0,'456'	; 20-2f
	dc.b	0,'ZXCVBNM,./',0,0,'789'	; 30-3f
	even

LogoColours:	; 32 entry gradient for the logo colour (14)
	dc.w	$fff,$eff,$dff,$cef,$bef,$adf,$9cf,$8bf,$7af,$69f,$58f,$47e,$46d,$45c,$44b,$43a
	dc.w	$439,$43a,$44b,$45c,$46d,$47e,$58f,$69f,$7af,$8bf,$9cf,$adf,$bef,$cef,$dff,$eff

; default high score table (from the C64 HIGHSCORE file)
HIMAGIC		equ	'GZH1'
HI_ENTRY	equ	14		; name 8, score.l, level.w
HiDefault:
	dc.l	HIMAGIC
	dc.b	'STRONKIE'
	dc.l	600
	dc.w	2
	dc.b	'SPOOKY  '
	dc.l	450
	dc.w	2
	dc.b	'PHANTOM '
	dc.l	300
	dc.w	1
	dc.b	'WISPY   '
	dc.l	250
	dc.w	1
	dc.b	'SHADOW  '
	dc.l	200
	dc.w	1
	dc.b	'GLOOMY  '
	dc.l	150
	dc.w	1
	dc.b	'SPECTRE '
	dc.l	100
	dc.w	1
	dc.b	'BOOBOO  '
	dc.l	80
	dc.w	1
	dc.b	'HAUNTER '
	dc.l	50
	dc.w	1
	dc.b	'FLOATY  '
	dc.l	30
	dc.w	1
	dc.w	0,0,0,0			; bonus game bests
	dc.w	1			; difficulty (0 easy,1 normal,2 hard)
	dc.w	0			; pad
HiDefaultEnd:
HISIZE		equ	HiDefaultEnd-HiDefault

	section	vars,bss
;---------------------------------------------------------------------
; variables
;---------------------------------------------------------------------
ExecBase:	ds.l	1
GfxBase:	ds.l	1
DosBase:	ds.l	1
WBMsg:		ds.l	1
OldView:	ds.l	1
OldDma:		ds.w	1
OldInt:		ds.w	1
OldAdk:		ds.w	1
FrontBuf:	ds.l	1
BackBuf:	ds.l	1
CopShown:	ds.l	1
CopNext:	ds.l	1
FrameCount:	ds.l	1
RandSeed:	ds.l	1
ScenePal:	ds.l	1
Scene:		ds.w	1
Fade:		ds.w	1
BgFade:		ds.w	1
PalKey:		ds.l	1
PalKeyScene:	ds.l	1
PalCache:	ds.w	16
SkyCache:	ds.w	58
LogoCache:	ds.w	32
FlashSky:	ds.w	58
WaitTab:	ds.w	60
ColFont:	ds.b	8*96*24
EnergyShownA:	ds.w	1
EnergyShownB:	ds.w	1
FlashCol:	ds.w	1
LogoGrad:	ds.w	1
LogoPhase:	ds.w	1
ScrollPos:	ds.w	1
ScrollFar:	ds.w	1
ScrollNear:	ds.w	1
ScrollStreet:	ds.w	1
ClipTop:	ds.w	1
ClipBottom:	ds.w	1
Joy:		ds.w	1
JoyNew:		ds.w	1
LastKey:	ds.b	1
		ds.b	1
KeyMap:		ds.b	128
FadeTab:	ds.b	17*16
DoubleTab:	ds.w	256
; music
SongStart:	ds.l	1
SongPos:	ds.l	1
PatPtr:		ds.l	1
Row:		ds.w	1
Tick:		ds.w	1
SongActive:	ds.w	1
MusicOn:	ds.w	1
ChState:	ds.b	CHSIZE*3
SfxPer:		ds.w	1
SfxStep:	ds.w	1
SfxVol:		ds.w	1
SfxVStep:	ds.w	1
SfxTicks:	ds.w	1
; high scores (copy of file contents)
HiBuffer:	ds.b	HISIZE+16
HiData:		ds.b	HISIZE+16
TmpStr:		ds.b	64
MAXDIRTY	equ	96
DirtyCountA:	ds.w	1
DirtyCountB:	ds.w	1
DirtyA:		ds.b	8*MAXDIRTY
DirtyB:		ds.b	8*MAXDIRTY
BobDirty:	ds.b	1
NoDirty:	ds.b	1
TxtMask0:	ds.b	1
TxtMask1:	ds.b	1
TxtMask2:	ds.b	1
		ds.b	1

	section	chipbss,bss_c
PF1Buf:		ds.b	PF1ROW*256
PF2BufA:	ds.b	PF2ROW*256
PF2BufB:	ds.b	PF2ROW*256
CopListA:	ds.b	2048
CopListB:	ds.b	2048
NullSprite:	ds.l	4

	section	fontdata,data
Font:	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$18,$18,$00,$18,$18,$00,$66,$66,$66,$00,$00,$00,$00,$00,$66,$66,$ff,$66,$ff,$66,$66,$00
	dc.b	$3c,$66,$06,$0c,$18,$00,$18,$00,$63,$66,$0c,$18,$30,$66,$c6,$00,$3c,$66,$3c,$38,$67,$66,$3b,$00,$18,$18,$30,$00,$00,$00,$00,$00
	dc.b	$0c,$18,$30,$30,$30,$18,$0c,$00,$30,$18,$0c,$0c,$0c,$18,$30,$00,$00,$66,$3c,$ff,$3c,$66,$00,$00,$00,$18,$18,$7e,$18,$18,$00,$00
	dc.b	$00,$00,$00,$00,$18,$18,$30,$00,$00,$00,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$00,$03,$06,$0c,$18,$30,$60,$c0,$00
	dc.b	$3c,$66,$6e,$7e,$76,$66,$3c,$00,$18,$38,$18,$18,$18,$18,$7e,$00,$3c,$66,$06,$0c,$30,$60,$7e,$00,$3c,$66,$06,$1c,$06,$66,$3c,$00
	dc.b	$0c,$1c,$3c,$6c,$7e,$0c,$0c,$00,$7e,$60,$7c,$06,$06,$66,$3c,$00,$3c,$66,$60,$7c,$66,$66,$3c,$00,$7e,$66,$0c,$18,$18,$18,$18,$00
	dc.b	$3c,$66,$66,$3c,$66,$66,$3c,$00,$3c,$66,$66,$3e,$06,$66,$3c,$00,$00,$18,$18,$00,$18,$18,$00,$00,$00,$18,$18,$00,$18,$18,$30,$00
	dc.b	$0c,$18,$30,$60,$30,$18,$0c,$00,$00,$00,$7e,$00,$7e,$00,$00,$00,$30,$18,$0c,$06,$0c,$18,$30,$00,$3c,$66,$06,$0c,$18,$00,$18,$00
	dc.b	$3c,$66,$6e,$6e,$60,$62,$3c,$00,$3c,$66,$66,$7e,$66,$66,$66,$00,$7c,$66,$66,$7c,$66,$66,$7c,$00,$3c,$66,$60,$60,$60,$66,$3c,$00
	dc.b	$78,$6c,$66,$66,$66,$6c,$78,$00,$7e,$60,$60,$7c,$60,$60,$7e,$00,$7e,$60,$60,$7c,$60,$60,$60,$00,$3c,$66,$60,$6e,$66,$66,$3c,$00
	dc.b	$66,$66,$66,$7e,$66,$66,$66,$00,$3c,$18,$18,$18,$18,$18,$3c,$00,$1e,$0c,$0c,$0c,$6c,$6c,$38,$00,$66,$6c,$78,$70,$78,$6c,$66,$00
	dc.b	$60,$60,$60,$60,$60,$60,$7e,$00,$63,$77,$7f,$6b,$63,$63,$63,$00,$66,$76,$7e,$7e,$6e,$66,$66,$00,$3c,$66,$66,$66,$66,$66,$3c,$00
	dc.b	$7c,$66,$66,$7c,$60,$60,$60,$00,$3c,$66,$66,$66,$66,$3c,$0e,$00,$7c,$66,$66,$7c,$78,$6c,$66,$00,$3c,$66,$60,$3c,$06,$66,$3c,$00
	dc.b	$7e,$18,$18,$18,$18,$18,$18,$00,$66,$66,$66,$66,$66,$66,$3c,$00,$66,$66,$66,$66,$66,$3c,$18,$00,$63,$63,$63,$6b,$7f,$77,$63,$00
	dc.b	$66,$66,$3c,$18,$3c,$66,$66,$00,$66,$66,$66,$3c,$18,$18,$18,$00,$7e,$06,$0c,$18,$30,$60,$7e,$00,$3c,$30,$30,$30,$30,$30,$3c,$00
	dc.b	$3c,$66,$06,$0c,$18,$00,$18,$00,$3c,$0c,$0c,$0c,$0c,$0c,$3c,$00,$3c,$66,$06,$0c,$18,$00,$18,$00,$00,$00,$00,$00,$00,$00,$ff,$00
	dc.b	$3c,$66,$06,$0c,$18,$00,$18,$00,$3c,$66,$66,$7e,$66,$66,$66,$00,$7c,$66,$66,$7c,$66,$66,$7c,$00,$3c,$66,$60,$60,$60,$66,$3c,$00
	dc.b	$78,$6c,$66,$66,$66,$6c,$78,$00,$7e,$60,$60,$7c,$60,$60,$7e,$00,$7e,$60,$60,$7c,$60,$60,$60,$00,$3c,$66,$60,$6e,$66,$66,$3c,$00
	dc.b	$66,$66,$66,$7e,$66,$66,$66,$00,$3c,$18,$18,$18,$18,$18,$3c,$00,$1e,$0c,$0c,$0c,$6c,$6c,$38,$00,$66,$6c,$78,$70,$78,$6c,$66,$00
	dc.b	$60,$60,$60,$60,$60,$60,$7e,$00,$63,$77,$7f,$6b,$63,$63,$63,$00,$66,$76,$7e,$7e,$6e,$66,$66,$00,$3c,$66,$66,$66,$66,$66,$3c,$00
	dc.b	$7c,$66,$66,$7c,$60,$60,$60,$00,$3c,$66,$66,$66,$66,$3c,$0e,$00,$7c,$66,$66,$7c,$78,$6c,$66,$00,$3c,$66,$60,$3c,$06,$66,$3c,$00
	dc.b	$7e,$18,$18,$18,$18,$18,$18,$00,$66,$66,$66,$66,$66,$66,$3c,$00,$66,$66,$66,$66,$66,$3c,$18,$00,$63,$63,$63,$6b,$7f,$77,$63,$00
	dc.b	$66,$66,$3c,$18,$3c,$66,$66,$00,$66,$66,$66,$3c,$18,$18,$18,$00,$7e,$06,$0c,$18,$30,$60,$7e,$00,$18,$18,$18,$ff,$7e,$3c,$18,$00
	dc.b	$18,$3c,$7e,$ff,$18,$18,$18,$00,$3c,$7e,$db,$ff,$ff,$ff,$ab,$00,$66,$ff,$ff,$ff,$7e,$3c,$18,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00

;---------------------------------------------------------------------
; file: gen_assets.s
;---------------------------------------------------------------------
; generated by make_assets.py - do not edit
; ---- bobs (interleaved 3 planes + mask)
BOB_PLAYER_STAND	equ	0
BOB_PLAYER_WALK1	equ	1
BOB_PLAYER_WALK2	equ	2
BOB_PLAYER_CHEER	equ	3
BOB_GHOST0_0	equ	4
BOB_GHOST0_1	equ	5
BOB_GHOST0_2	equ	6
BOB_GHOST0_3	equ	7
BOB_GHOST1_0	equ	8
BOB_GHOST1_1	equ	9
BOB_GHOST1_2	equ	10
BOB_GHOST1_3	equ	11
BOB_GHOST2_0	equ	12
BOB_GHOST2_1	equ	13
BOB_GHOST2_2	equ	14
BOB_GHOST2_3	equ	15
BOB_GHOST3_0	equ	16
BOB_GHOST3_1	equ	17
BOB_GHOST3_2	equ	18
BOB_GHOST3_3	equ	19
BOB_BAT0	equ	20
BOB_BAT1	equ	21
BOB_SLIME	equ	22
BOB_BSHOT	equ	23
BOB_PW_INV	equ	24
BOB_PW_ENERGY	equ	25
BOB_PW_TWIN	equ	26
BOB_PW_LIFE	equ	27
BOB_TRAP_CLOSED	equ	28
BOB_TRAP_OPEN	equ	29
BOB_BOSS	equ	30
BOB_BOSS_HIT	equ	31
BOB_BOSS_STUN	equ	32
BOB_PLANE	equ	33
BOB_PLANE_L	equ	34
BOB_TAXI	equ	35
BOB_INV0	equ	36
BOB_INV1	equ	37
BOB_INV2	equ	38
BOB_INV3	equ	39
BOB_SPARK0	equ	40
BOB_SPARK1	equ	41
BOB_SPARK2	equ	42
BOB_SPARK3	equ	43
BOB_BEAM0	equ	44
BOB_BEAM1	equ	45
BOB_TBEAM0	equ	46
BOB_TBEAM1	equ	47
BOB_CROSS	equ	48
BOB_BOLT	equ	49
BOB_WINDOW	equ	50
BOBCOUNT	equ	51
	section	bobdata,data_c
bd_player_stand	dc.b	$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$40,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$40,$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00
	dc.b	$07,$ff,$80,$00,$07,$f3,$80,$00,$09,$ff,$c0,$00,$0e,$00,$40,$00,$0f,$ff,$c0,$00,$11,$ff,$e0,$00,$1e,$00,$20,$00,$1f,$ff,$e0,$00
	dc.b	$11,$ff,$f0,$00,$1e,$00,$10,$00,$1f,$ff,$f0,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00,$1f,$ff,$f8,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00
	dc.b	$1f,$ff,$f8,$00,$09,$ff,$f0,$00,$0e,$00,$10,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$80,$60,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00
	dc.b	$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$4c,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00
	dc.b	$01,$ff,$e0,$00,$01,$ff,$e0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e
	dc.b	$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff
	dc.b	$c0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff
	dc.b	$f0,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$00,$f3
	dc.b	$c0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$00
bd_player_walk1	dc.b	$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$40,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$40,$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00
	dc.b	$07,$ff,$80,$00,$07,$f3,$80,$00,$09,$ff,$c0,$00,$0e,$00,$40,$00,$0f,$ff,$c0,$00,$11,$ff,$e0,$00,$1e,$00,$20,$00,$1f,$ff,$e0,$00
	dc.b	$11,$ff,$f0,$00,$1e,$00,$10,$00,$1f,$ff,$f0,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00,$1f,$ff,$f8,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00
	dc.b	$1f,$ff,$f8,$00,$09,$ff,$f0,$00,$0e,$00,$10,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$80,$60,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00
	dc.b	$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00
	dc.b	$00,$f7,$80,$00,$00,$94,$80,$00,$00,$f7,$80,$00,$01,$e7,$80,$00,$01,$24,$80,$00,$01,$e7,$80,$00,$03,$c7,$80,$00,$02,$44,$80,$00
	dc.b	$03,$c7,$80,$00,$05,$c7,$c0,$00,$07,$c7,$c0,$00,$07,$c7,$c0,$00,$09,$c7,$e0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$09,$c7,$e0,$00
	dc.b	$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$07,$83,$c0,$00,$07,$83,$c0,$00,$07,$83,$c0,$00,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e
	dc.b	$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff
	dc.b	$c0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff
	dc.b	$f0,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$f7,$80,$00,$00,$f7,$80,$00,$00,$f7
	dc.b	$80,$00,$01,$e7,$80,$00,$01,$e7,$80,$00,$01,$e7,$80,$00,$03,$c7,$80,$00,$03,$c7,$80,$00,$03,$c7,$80,$00,$07,$c7,$c0,$00,$07,$c7
	dc.b	$c0,$00,$07,$c7,$c0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$0f,$c7,$e0,$00,$07,$83
	dc.b	$c0,$00,$07,$83,$c0,$00,$07,$83,$c0,$00,$00,$00
bd_player_walk2	dc.b	$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$40,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$40,$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$21,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00
	dc.b	$07,$ff,$80,$00,$07,$f3,$80,$00,$09,$ff,$c0,$00,$0e,$00,$40,$00,$0f,$ff,$c0,$00,$11,$ff,$e0,$00,$1e,$00,$20,$00,$1f,$ff,$e0,$00
	dc.b	$11,$ff,$f0,$00,$1e,$00,$10,$00,$1f,$ff,$f0,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00,$1f,$ff,$f8,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00
	dc.b	$1f,$ff,$f8,$00,$09,$ff,$f0,$00,$0e,$00,$10,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$80,$60,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00
	dc.b	$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00
	dc.b	$00,$7b,$c0,$00,$00,$4a,$40,$00,$00,$7b,$c0,$00,$00,$79,$e0,$00,$00,$49,$20,$00,$00,$79,$e0,$00,$00,$78,$f0,$00,$00,$48,$90,$00
	dc.b	$00,$78,$f0,$00,$00,$f8,$f8,$00,$00,$f8,$f8,$00,$00,$f8,$f8,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00
	dc.b	$01,$f8,$fc,$00,$01,$f8,$fc,$00,$00,$f0,$78,$00,$00,$f0,$78,$00,$00,$f0,$78,$00,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e
	dc.b	$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff
	dc.b	$c0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff
	dc.b	$f0,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7b,$c0,$00,$00,$7b,$c0,$00,$00,$7b
	dc.b	$c0,$00,$00,$79,$e0,$00,$00,$79,$e0,$00,$00,$79,$e0,$00,$00,$78,$f0,$00,$00,$78,$f0,$00,$00,$78,$f0,$00,$00,$f8,$f8,$00,$00,$f8
	dc.b	$f8,$00,$00,$f8,$f8,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$01,$f8,$fc,$00,$00,$f0
	dc.b	$78,$00,$00,$f0,$78,$00,$00,$f0,$78,$00,$00,$00
bd_player_cheer	dc.b	$03,$1e,$30,$00,$03,$1e,$30,$00,$03,$1e,$30,$00,$07,$bf,$78,$00,$04,$a1,$48,$00,$07,$bf,$78,$00,$07,$ff,$f8,$00,$04,$c0,$c8,$00
	dc.b	$07,$ff,$f8,$00,$07,$ff,$f8,$00,$04,$c0,$c8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$04,$61,$88,$00,$07,$ff,$f8,$00,$07,$ff,$f0,$00
	dc.b	$07,$ff,$f0,$00,$06,$73,$90,$00,$09,$ff,$f8,$00,$0e,$00,$08,$00,$0f,$ff,$f8,$00,$11,$ff,$f0,$00,$1e,$00,$30,$00,$1f,$ff,$f0,$00
	dc.b	$11,$ff,$f0,$00,$1e,$00,$10,$00,$1f,$ff,$f0,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00,$1f,$ff,$f8,$00,$11,$ff,$f8,$00,$1e,$00,$08,$00
	dc.b	$1f,$ff,$f8,$00,$09,$ff,$f0,$00,$0e,$00,$10,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$80,$60,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00
	dc.b	$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$4c,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$4c,$80,$00
	dc.b	$00,$7f,$80,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00
	dc.b	$01,$ff,$e0,$00,$01,$ff,$e0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$00,$03,$1e,$30,$00,$03,$1e,$30,$00,$03,$1e
	dc.b	$30,$00,$07,$bf,$78,$00,$07,$bf,$78,$00,$07,$bf,$78,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff
	dc.b	$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f0,$00,$07,$ff,$f0,$00,$07,$ff,$f0,$00,$0f,$ff
	dc.b	$f8,$00,$0f,$ff,$f8,$00,$0f,$ff,$f8,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff,$f0,$00,$1f,$ff
	dc.b	$f0,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$07,$ff,$e0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$00,$f3
	dc.b	$c0,$00,$00,$f3,$c0,$00,$00,$f3,$c0,$00,$00,$00
bd_ghost0_0	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$20,$01,$00,$00,$3f,$ff,$00,$00
	dc.b	$20,$01,$00,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$86,$18,$40,$00
	dc.b	$f9,$e7,$c0,$00,$80,$00,$40,$00,$84,$10,$40,$00,$fb,$ef,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00
	dc.b	$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$81,$e0,$40,$00,$fe,$1f,$c0,$00
	dc.b	$80,$00,$40,$00,$80,$c0,$40,$00,$ff,$3f,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$92,$49,$40,$00
	dc.b	$ff,$ff,$c0,$00,$92,$49,$40,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost0_1	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$18,$06,$00,$00,$3f,$ff,$00,$00,$20,$01,$00,$00
	dc.b	$20,$01,$00,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$40,$00,$80,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$86,$18,$40,$00,$86,$18,$40,$00,$ff,$ff,$c0,$00,$84,$10,$40,$00,$84,$10,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00
	dc.b	$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$81,$e0,$40,$00
	dc.b	$81,$e0,$40,$00,$ff,$ff,$c0,$00,$80,$c0,$40,$00,$80,$c0,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$92,$49,$40,$00,$92,$49,$40,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost0_2	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$20,$01,$00,$00,$3f,$ff,$00,$00
	dc.b	$3f,$ff,$00,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$86,$18,$40,$00
	dc.b	$f9,$e7,$c0,$00,$f9,$e7,$c0,$00,$84,$10,$40,$00,$fb,$ef,$c0,$00,$fb,$ef,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$81,$e0,$40,$00,$fe,$1f,$c0,$00
	dc.b	$fe,$1f,$c0,$00,$80,$c0,$40,$00,$ff,$3f,$c0,$00,$ff,$3f,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$92,$49,$40,$00
	dc.b	$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost0_3	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$20,$01,$00,$00
	dc.b	$3f,$ff,$00,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$80,$00,$40,$00,$f9,$e7,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$fb,$ef,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00
	dc.b	$fe,$1f,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$3f,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$92,$49,$40,$00,$ff,$ff,$c0,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost1_0	dc.b	$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$0c,$03,$00,$00,$0f,$ff,$00,$00,$0c,$03,$00,$00,$10,$00,$80,$00,$1f,$ff,$80,$00
	dc.b	$10,$00,$80,$00,$20,$00,$40,$00,$3f,$ff,$c0,$00,$20,$00,$40,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$43,$0c,$20,$00
	dc.b	$7c,$f3,$e0,$00,$40,$00,$20,$00,$42,$08,$20,$00,$7d,$f7,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00
	dc.b	$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$81,$e0,$40,$00,$fe,$1f,$c0,$00
	dc.b	$80,$00,$40,$00,$80,$c0,$40,$00,$ff,$3f,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$92,$49,$40,$00
	dc.b	$ff,$ff,$c0,$00,$92,$49,$40,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc
	dc.b	$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$3f,$ff
	dc.b	$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost1_1	dc.b	$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$0f,$ff,$00,$00,$0c,$03,$00,$00,$0c,$03,$00,$00,$1f,$ff,$80,$00,$10,$00,$80,$00
	dc.b	$10,$00,$80,$00,$3f,$ff,$c0,$00,$20,$00,$40,$00,$20,$00,$40,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00
	dc.b	$43,$0c,$20,$00,$43,$0c,$20,$00,$7f,$ff,$e0,$00,$42,$08,$20,$00,$42,$08,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00
	dc.b	$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$81,$e0,$40,$00
	dc.b	$81,$e0,$40,$00,$ff,$ff,$c0,$00,$80,$c0,$40,$00,$80,$c0,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$92,$49,$40,$00,$92,$49,$40,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc
	dc.b	$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$3f,$ff
	dc.b	$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost1_2	dc.b	$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$0c,$03,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$10,$00,$80,$00,$1f,$ff,$80,$00
	dc.b	$1f,$ff,$80,$00,$20,$00,$40,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$43,$0c,$20,$00
	dc.b	$7c,$f3,$e0,$00,$7c,$f3,$e0,$00,$42,$08,$20,$00,$7d,$f7,$e0,$00,$7d,$f7,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00
	dc.b	$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$81,$e0,$40,$00,$fe,$1f,$c0,$00
	dc.b	$fe,$1f,$c0,$00,$80,$c0,$40,$00,$ff,$3f,$c0,$00,$ff,$3f,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$92,$49,$40,$00
	dc.b	$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc
	dc.b	$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$3f,$ff
	dc.b	$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost1_3	dc.b	$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$0f,$ff,$00,$00,$0c,$03,$00,$00,$0f,$ff,$00,$00,$1f,$ff,$80,$00,$10,$00,$80,$00
	dc.b	$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$20,$00,$40,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00
	dc.b	$40,$00,$20,$00,$7c,$f3,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7d,$f7,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00
	dc.b	$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00
	dc.b	$fe,$1f,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$3f,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$92,$49,$40,$00,$ff,$ff,$c0,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00,$03,$fc,$00,$00,$03,$fc,$00,$00,$03,$fc
	dc.b	$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$3f,$ff
	dc.b	$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$6d,$b6
	dc.b	$80,$00,$6d,$b6,$80,$00,$6d,$b6,$80,$00,$00,$00
bd_ghost2_0	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$20,$01,$00,$00,$3f,$ff,$00,$00
	dc.b	$20,$01,$00,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$86,$18,$40,$00
	dc.b	$f9,$e7,$c0,$00,$80,$00,$40,$00,$84,$10,$40,$00,$fb,$ef,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00
	dc.b	$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$f0,$20,$00,$7f,$0f,$e0,$00
	dc.b	$40,$00,$20,$00,$40,$60,$20,$00,$7f,$9f,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$49,$24,$a0,$00
	dc.b	$7f,$ff,$e0,$00,$49,$24,$a0,$00,$36,$db,$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$36,$db
	dc.b	$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00
bd_ghost2_1	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$18,$06,$00,$00,$3f,$ff,$00,$00,$20,$01,$00,$00
	dc.b	$20,$01,$00,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$40,$00,$80,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$86,$18,$40,$00,$86,$18,$40,$00,$ff,$ff,$c0,$00,$84,$10,$40,$00,$84,$10,$40,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$80,$00,$40,$00
	dc.b	$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$40,$f0,$20,$00
	dc.b	$40,$f0,$20,$00,$7f,$ff,$e0,$00,$40,$60,$20,$00,$40,$60,$20,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00
	dc.b	$49,$24,$a0,$00,$49,$24,$a0,$00,$36,$db,$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$36,$db
	dc.b	$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00
bd_ghost2_2	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$20,$01,$00,$00,$3f,$ff,$00,$00
	dc.b	$3f,$ff,$00,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$86,$18,$40,$00
	dc.b	$f9,$e7,$c0,$00,$f9,$e7,$c0,$00,$84,$10,$40,$00,$fb,$ef,$c0,$00,$fb,$ef,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$40,$f0,$20,$00,$7f,$0f,$e0,$00
	dc.b	$7f,$0f,$e0,$00,$40,$60,$20,$00,$7f,$9f,$e0,$00,$7f,$9f,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$49,$24,$a0,$00
	dc.b	$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$36,$db,$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$36,$db
	dc.b	$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00
bd_ghost2_3	dc.b	$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$1f,$fe,$00,$00,$18,$06,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$20,$01,$00,$00
	dc.b	$3f,$ff,$00,$00,$7f,$ff,$80,$00,$40,$00,$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00
	dc.b	$80,$00,$40,$00,$f9,$e7,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$fb,$ef,$c0,$00,$ff,$ff,$c0,$00,$80,$00,$40,$00,$ff,$ff,$c0,$00
	dc.b	$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00
	dc.b	$7f,$0f,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$9f,$e0,$00,$7f,$ff,$e0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00
	dc.b	$49,$24,$a0,$00,$7f,$ff,$e0,$00,$36,$db,$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00,$07,$f8,$00,$00,$07,$f8,$00,$00,$07,$f8
	dc.b	$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$1f,$fe,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$3f,$ff,$00,$00,$7f,$ff,$80,$00,$7f,$ff
	dc.b	$80,$00,$7f,$ff,$80,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$ff,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$36,$db
	dc.b	$40,$00,$36,$db,$40,$00,$36,$db,$40,$00,$00,$00
bd_ghost3_0	dc.b	$0f,$c0,$0f,$c0,$0f,$c0,$70,$20,$7f,$e0,$70,$20,$80,$18,$ff,$f8,$80,$18,$80,$04,$ff,$fc,$80,$04,$88,$44,$f7,$bc,$80,$04,$80,$04
	dc.b	$ff,$fc,$80,$04,$80,$04,$ff,$fc,$80,$04,$80,$04,$ff,$fc,$80,$04,$a4,$94,$ff,$fc,$a4,$94,$b4,$b4,$ff,$fc,$b4,$b4,$4b,$48,$4b,$48
	dc.b	$4b,$48,$00,$00,$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$7f,$e0,$7f,$e0,$ff,$f8,$ff,$f8,$ff,$f8,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$4b,$48,$4b,$48,$4b,$48,$00,$00
bd_ghost3_1	dc.b	$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$70,$20,$70,$20,$ff,$f8,$80,$18,$80,$18,$ff,$fc,$80,$04,$80,$04,$ff,$fc,$88,$44,$88,$44,$ff,$fc
	dc.b	$80,$04,$80,$04,$ff,$fc,$80,$04,$80,$04,$ff,$fc,$80,$04,$80,$04,$ff,$fc,$a4,$94,$a4,$94,$ff,$fc,$b4,$b4,$b4,$b4,$4b,$48,$4b,$48
	dc.b	$4b,$48,$00,$00,$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$7f,$e0,$7f,$e0,$ff,$f8,$ff,$f8,$ff,$f8,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$4b,$48,$4b,$48,$4b,$48,$00,$00
bd_ghost3_2	dc.b	$0f,$c0,$0f,$c0,$0f,$c0,$70,$20,$7f,$e0,$7f,$e0,$80,$18,$ff,$f8,$ff,$f8,$80,$04,$ff,$fc,$ff,$fc,$88,$44,$f7,$bc,$f7,$bc,$80,$04
	dc.b	$ff,$fc,$ff,$fc,$80,$04,$ff,$fc,$ff,$fc,$80,$04,$ff,$fc,$ff,$fc,$a4,$94,$ff,$fc,$ff,$fc,$b4,$b4,$ff,$fc,$ff,$fc,$4b,$48,$4b,$48
	dc.b	$4b,$48,$00,$00,$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$7f,$e0,$7f,$e0,$ff,$f8,$ff,$f8,$ff,$f8,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$4b,$48,$4b,$48,$4b,$48,$00,$00
bd_ghost3_3	dc.b	$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$70,$20,$7f,$e0,$ff,$f8,$80,$18,$ff,$f8,$ff,$fc,$80,$04,$ff,$fc,$ff,$fc,$80,$04,$f7,$bc,$ff,$fc
	dc.b	$80,$04,$ff,$fc,$ff,$fc,$80,$04,$ff,$fc,$ff,$fc,$80,$04,$ff,$fc,$ff,$fc,$a4,$94,$ff,$fc,$ff,$fc,$b4,$b4,$ff,$fc,$4b,$48,$4b,$48
	dc.b	$4b,$48,$00,$00,$0f,$c0,$0f,$c0,$0f,$c0,$7f,$e0,$7f,$e0,$7f,$e0,$ff,$f8,$ff,$f8,$ff,$f8,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$4b,$48,$4b,$48,$4b,$48,$00,$00
bd_bat0	dc.b	$00,$ff,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$01,$00,$80,$00,$01,$00,$80,$00,$01,$ff,$80,$00,$02,$e7,$40,$00,$02,$e7,$40,$00
	dc.b	$02,$ff,$40,$00,$05,$24,$a0,$00,$05,$24,$a0,$00,$07,$3c,$e0,$00,$09,$e7,$90,$00,$09,$e7,$90,$00,$0f,$ff,$f0,$00,$30,$00,$0c,$00
	dc.b	$30,$00,$0c,$00,$3f,$ff,$fc,$00,$40,$00,$02,$00,$40,$00,$02,$00,$7f,$ff,$fe,$00,$80,$00,$02,$00,$80,$00,$02,$00,$ff,$ff,$fe,$00
	dc.b	$80,$00,$02,$00,$80,$00,$02,$00,$ff,$ff,$fe,$00,$8f,$81,$f1,$00,$8f,$81,$f1,$00,$ff,$ff,$ff,$00,$90,$42,$09,$00,$90,$42,$09,$00
	dc.b	$f0,$7e,$0f,$00,$a0,$24,$05,$00,$a0,$24,$05,$00,$e0,$3c,$07,$00,$a0,$24,$05,$00,$a0,$24,$05,$00,$e0,$3c,$07,$00,$40,$18,$02,$00
	dc.b	$40,$18,$02,$00,$40,$18,$02,$00,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$01,$ff,$80,$00,$01,$ff,$80,$00,$01,$ff
	dc.b	$80,$00,$02,$ff,$40,$00,$02,$ff,$40,$00,$02,$ff,$40,$00,$07,$3c,$e0,$00,$07,$3c,$e0,$00,$07,$3c,$e0,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$7f,$ff,$fe,$00,$7f,$ff,$fe,$00,$7f,$ff,$fe,$00,$ff,$ff
	dc.b	$fe,$00,$ff,$ff,$fe,$00,$ff,$ff,$fe,$00,$ff,$ff,$fe,$00,$ff,$ff,$fe,$00,$ff,$ff,$fe,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff
	dc.b	$ff,$00,$f0,$7e,$0f,$00,$f0,$7e,$0f,$00,$f0,$7e,$0f,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c
	dc.b	$07,$00,$e0,$3c,$07,$00,$40,$18,$02,$00,$40,$18,$02,$00,$40,$18,$02,$00,$00,$00
bd_bat1	dc.b	$00,$ff,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$01,$00,$80,$00,$01,$00,$80,$00,$01,$ff,$80,$00,$02,$e7,$40,$00,$02,$e7,$40,$00
	dc.b	$02,$ff,$40,$00,$05,$24,$a0,$00,$05,$24,$a0,$00,$07,$3c,$e0,$00,$09,$e7,$90,$00,$09,$e7,$90,$00,$0f,$ff,$f0,$00,$30,$00,$0c,$00
	dc.b	$30,$00,$0c,$00,$3f,$ff,$fc,$00,$40,$00,$02,$00,$40,$00,$02,$00,$7f,$ff,$fe,$00,$40,$00,$01,$00,$40,$00,$01,$00,$7f,$ff,$ff,$00
	dc.b	$40,$00,$01,$00,$40,$00,$01,$00,$7f,$ff,$ff,$00,$8f,$81,$f1,$00,$8f,$81,$f1,$00,$ff,$ff,$ff,$00,$90,$42,$09,$00,$90,$42,$09,$00
	dc.b	$f0,$7e,$0f,$00,$a0,$24,$05,$00,$a0,$24,$05,$00,$e0,$3c,$07,$00,$a0,$24,$05,$00,$a0,$24,$05,$00,$e0,$3c,$07,$00,$40,$18,$02,$00
	dc.b	$40,$18,$02,$00,$40,$18,$02,$00,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$00,$ff,$00,$00,$01,$ff,$80,$00,$01,$ff,$80,$00,$01,$ff
	dc.b	$80,$00,$02,$ff,$40,$00,$02,$ff,$40,$00,$02,$ff,$40,$00,$07,$3c,$e0,$00,$07,$3c,$e0,$00,$07,$3c,$e0,$00,$0f,$ff,$f0,$00,$0f,$ff
	dc.b	$f0,$00,$0f,$ff,$f0,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$7f,$ff,$fe,$00,$7f,$ff,$fe,$00,$7f,$ff,$fe,$00,$7f,$ff
	dc.b	$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff
	dc.b	$ff,$00,$f0,$7e,$0f,$00,$f0,$7e,$0f,$00,$f0,$7e,$0f,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c,$07,$00,$e0,$3c
	dc.b	$07,$00,$e0,$3c,$07,$00,$40,$18,$02,$00,$40,$18,$02,$00,$40,$18,$02,$00,$00,$00
bd_slime	dc.b	$06,$00,$06,$00,$06,$00,$09,$00,$0f,$00,$09,$00,$10,$80,$1f,$80,$10,$80,$20,$40,$3f,$c0,$20,$40,$40,$20,$7f,$e0,$40,$20,$44,$10
	dc.b	$7b,$f0,$40,$10,$80,$10,$ff,$f0,$80,$10,$80,$10,$ff,$f0,$80,$10,$40,$20,$7f,$e0,$40,$20,$20,$40,$3f,$c0,$20,$40,$10,$80,$1f,$80
	dc.b	$10,$80,$09,$00,$0f,$00,$09,$00,$06,$00,$06,$00,$06,$00,$00,$00,$06,$00,$06,$00,$06,$00,$0f,$00,$0f,$00,$0f,$00,$1f,$80,$1f,$80
	dc.b	$1f,$80,$3f,$c0,$3f,$c0,$3f,$c0,$7f,$e0,$7f,$e0,$7f,$e0,$7f,$f0,$7f,$f0,$7f,$f0,$ff,$f0,$ff,$f0,$ff,$f0,$ff,$f0,$ff,$f0,$ff,$f0
	dc.b	$7f,$e0,$7f,$e0,$7f,$e0,$3f,$c0,$3f,$c0,$3f,$c0,$1f,$80,$1f,$80,$1f,$80,$0f,$00,$0f,$00,$0f,$00,$06,$00,$06,$00,$06,$00,$00,$00
bd_bshot	dc.b	$03,$00,$03,$00,$03,$00,$1c,$e0,$1c,$e0,$1f,$e0,$20,$10,$20,$10,$3f,$f0,$40,$08,$40,$08,$7f,$f8,$40,$08,$40,$08,$7f,$f8,$40,$08
	dc.b	$40,$08,$7f,$f8,$80,$04,$80,$04,$ff,$fc,$8f,$c4,$8f,$c4,$f0,$3c,$40,$08,$40,$08,$7f,$f8,$40,$08,$40,$08,$7f,$f8,$20,$10,$20,$10
	dc.b	$3f,$f0,$10,$20,$10,$20,$1f,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$00,$00,$03,$00,$03,$00,$03,$00,$1f,$e0,$1f,$e0,$1f,$e0,$3f,$f0,$3f,$f0
	dc.b	$3f,$f0,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc,$ff,$fc
	dc.b	$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$7f,$f8,$3f,$f0,$3f,$f0,$3f,$f0,$1f,$e0,$1f,$e0,$1f,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$00,$00
bd_pw_inv	dc.b	$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$3f,$ff,$f0,$00
	dc.b	$3f,$ff,$f0,$00,$20,$00,$10,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$f8,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$20,$08,$00
	dc.b	$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$20,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$20,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00
	dc.b	$80,$20,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$20,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$20,$04,$00,$7f,$ff,$f8,$00
	dc.b	$7f,$ff,$f8,$00,$40,$20,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$f8,$08,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00
	dc.b	$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00,$01,$fe
	dc.b	$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$7f,$ff,$f8,$00,$7f,$ff
	dc.b	$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00
bd_pw_energy	dc.b	$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$3f,$ff,$f0,$00
	dc.b	$3f,$ff,$f0,$00,$20,$00,$10,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$f8,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$80,$08,$00
	dc.b	$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00
	dc.b	$80,$f0,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$7f,$ff,$f8,$00
	dc.b	$7f,$ff,$f8,$00,$40,$80,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$f8,$08,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00
	dc.b	$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00,$01,$fe
	dc.b	$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$7f,$ff,$f8,$00,$7f,$ff
	dc.b	$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00
bd_pw_twin	dc.b	$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$3f,$ff,$f0,$00
	dc.b	$3f,$ff,$f0,$00,$20,$00,$10,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$70,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$88,$08,$00
	dc.b	$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$80,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00
	dc.b	$80,$b8,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$88,$04,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$80,$88,$04,$00,$7f,$ff,$f8,$00
	dc.b	$7f,$ff,$f8,$00,$40,$88,$08,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$40,$70,$08,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00
	dc.b	$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$20,$00,$10,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$10,$00,$20,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00
	dc.b	$08,$00,$40,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$06,$01,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00,$01,$fe
	dc.b	$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$7f,$ff,$f8,$00,$7f,$ff
	dc.b	$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$7f,$ff,$f8,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$3f,$ff
	dc.b	$f0,$00,$3f,$ff,$f0,$00,$3f,$ff,$f0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$1f,$ff,$e0,$00,$0f,$ff,$c0,$00,$0f,$ff,$c0,$00,$0f,$ff
	dc.b	$c0,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$07,$ff,$80,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$01,$fe,$00,$00,$00,$00
bd_pw_life	dc.b	$00,$20,$00,$00,$00,$20,$00,$00,$00,$20,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00,$00,$50,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00
	dc.b	$00,$50,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$88,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$88,$00,$00,$00,$f8,$00,$00
	dc.b	$00,$f8,$00,$00,$00,$88,$00,$00,$01,$fc,$00,$00,$01,$fc,$00,$00,$01,$04,$00,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$7f,$07,$f0,$00
	dc.b	$ff,$ff,$f8,$00,$ff,$ff,$f8,$00,$80,$00,$08,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$40,$00,$10,$00,$3f,$ff,$e0,$00,$3f,$ff,$e0,$00
	dc.b	$20,$00,$20,$00,$1f,$ff,$c0,$00,$1f,$ff,$c0,$00,$10,$00,$40,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$08,$00,$80,$00,$07,$ff,$00,$00
	dc.b	$07,$ff,$00,$00,$04,$01,$00,$00,$07,$ff,$00,$00,$07,$ff,$00,$00,$04,$01,$00,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$08,$00,$80,$00
	dc.b	$0f,$ff,$80,$00,$0f,$ff,$80,$00,$08,$20,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$08,$50,$80,$00,$0f,$8f,$80,$00,$0f,$8f,$80,$00
	dc.b	$09,$8c,$80,$00,$1e,$03,$c0,$00,$1e,$03,$c0,$00,$16,$03,$40,$00,$08,$00,$80,$00,$08,$00,$80,$00,$08,$00,$80,$00,$00,$00,$00,$20
	dc.b	$00,$00,$00,$20,$00,$00,$00,$20,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00,$00,$70,$00,$00,$00,$70
	dc.b	$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8,$00,$00,$00,$f8
	dc.b	$00,$00,$00,$f8,$00,$00,$01,$fc,$00,$00,$01,$fc,$00,$00,$01,$fc,$00,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$ff,$ff
	dc.b	$f8,$00,$ff,$ff,$f8,$00,$ff,$ff,$f8,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$7f,$ff,$f0,$00,$3f,$ff,$e0,$00,$3f,$ff,$e0,$00,$3f,$ff
	dc.b	$e0,$00,$1f,$ff,$c0,$00,$1f,$ff,$c0,$00,$1f,$ff,$c0,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$07,$ff,$00,$00,$07,$ff
	dc.b	$00,$00,$07,$ff,$00,$00,$07,$ff,$00,$00,$07,$ff,$00,$00,$07,$ff,$00,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$0f,$ff
	dc.b	$80,$00,$0f,$ff,$80,$00,$0f,$ff,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$0f,$8f,$80,$00,$0f,$8f,$80,$00,$0f,$8f
	dc.b	$80,$00,$1e,$03,$c0,$00,$1e,$03,$c0,$00,$1e,$03,$c0,$00,$08,$00,$80,$00,$08,$00,$80,$00,$08,$00,$80,$00,$00,$00
bd_trap_closed	dc.b	$0f,$ff,$00,$00,$0f,$ff,$00,$00,$0f,$ff,$00,$00,$30,$00,$c0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$40,$00,$20,$00,$7f,$ff,$e0,$00
	dc.b	$7f,$ff,$e0,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$80,$60,$10,$00,$ff,$ff,$f0,$00,$ff,$9f,$f0,$00,$80,$60,$10,$00
	dc.b	$ff,$ff,$f0,$00,$ff,$9f,$f0,$00,$80,$60,$10,$00,$ff,$ff,$f0,$00,$ff,$9f,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00
	dc.b	$80,$00,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$00,$00,$0f,$ff,$00,$00,$0f,$ff
	dc.b	$00,$00,$0f,$ff,$00,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$00,$00
bd_trap_open	dc.b	$40,$00,$02,$00,$40,$00,$02,$00,$40,$00,$02,$00,$a0,$00,$05,$00,$e0,$00,$07,$00,$e0,$00,$07,$00,$90,$00,$09,$00,$f0,$00,$0f,$00
	dc.b	$f0,$00,$0f,$00,$48,$00,$12,$00,$78,$00,$1e,$00,$78,$00,$1e,$00,$44,$00,$22,$00,$7c,$00,$3e,$00,$7c,$00,$3e,$00,$23,$00,$c4,$00
	dc.b	$3f,$00,$fc,$00,$3f,$00,$fc,$00,$20,$81,$04,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$20,$81,$04,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00
	dc.b	$20,$81,$04,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$20,$81,$04,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$20,$ff,$04,$00,$3f,$ff,$fc,$00
	dc.b	$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$20,$00,$04,$00,$20,$00,$04,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$1f,$ff,$f8,$00
	dc.b	$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$00,$00,$40,$00,$02,$00,$40,$00,$02,$00,$40,$00,$02,$00,$e0,$00,$07,$00,$e0,$00,$07,$00,$e0,$00
	dc.b	$07,$00,$f0,$00,$0f,$00,$f0,$00,$0f,$00,$f0,$00,$0f,$00,$78,$00,$1e,$00,$78,$00,$1e,$00,$78,$00,$1e,$00,$7c,$00,$3e,$00,$7c,$00
	dc.b	$3e,$00,$7c,$00,$3e,$00,$3f,$00,$fc,$00,$3f,$00,$fc,$00,$3f,$00,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81
	dc.b	$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81,$fc,$00,$3f,$81
	dc.b	$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff,$fc,$00,$3f,$ff
	dc.b	$fc,$00,$3f,$ff,$fc,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$1f,$ff,$f8,$00,$00,$00
bd_boss	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00
	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00
	dc.b	$00,$00,$cf,$0f,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00
	dc.b	$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00
	dc.b	$00,$03,$30,$00,$cc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00
	dc.b	$00,$3c,$30,$00,$c3,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00
	dc.b	$00,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$3c,$00,$00,$03,$c3,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$3c,$00,$00,$03,$c3,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0c,$03,$c0,$00,$3c,$03,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$03,$c0,$00,$3c,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00
	dc.b	$c0,$00,$00,$00,$00,$00,$30,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00
	dc.b	$c0,$03,$ff,$ff,$fc,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$c0,$03,$ff,$ff,$fc,$00,$30,$00
	dc.b	$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$c0,$0c,$cc,$f3,$33,$00,$30,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00
	dc.b	$c0,$00,$00,$00,$00,$00,$30,$00,$c0,$0c,$cc,$f3,$33,$00,$30,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00
	dc.b	$00,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00
	dc.b	$00,$30,$00,$00,$00,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$00
bd_boss_hit	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00
	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00
	dc.b	$00,$00,$cf,$0f,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00
	dc.b	$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00
	dc.b	$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$3c,$30,$00,$c3,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0c,$3c,$00,$00,$03,$c3,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00
	dc.b	$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0c,$3c,$00,$00,$03,$c3,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00
	dc.b	$0c,$03,$c0,$00,$3c,$03,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0c,$03,$c0,$00,$3c,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00
	dc.b	$c0,$03,$ff,$ff,$fc,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$c0,$03,$ff,$ff,$fc,$00,$30,$00
	dc.b	$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$c0,$0c,$cc,$f3,$33,$00,$30,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00
	dc.b	$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$c0,$0c,$cc,$f3,$33,$00,$30,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$30,$00,$00,$00,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$00
bd_boss_stun	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00
	dc.b	$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00
	dc.b	$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$0f,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00
	dc.b	$00,$03,$30,$00,$cc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$30,$00,$cc,$00,$00,$00
	dc.b	$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3c,$30,$00,$c3,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$3c,$00,$00,$03,$c3,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0c,$3c,$00,$00,$03,$c3,$00,$00
	dc.b	$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0f,$c3,$ff,$ff,$fc,$3f,$00,$00,$0c,$03,$c0,$00,$3c,$03,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00
	dc.b	$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0c,$03,$c0,$00,$3c,$03,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00,$0f,$fc,$3f,$ff,$c3,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$c0,$00,$00,$00,$00,$00,$30,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$c0,$00,$00,$00,$00,$00,$30,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$c0,$03,$ff,$ff,$fc,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00
	dc.b	$ff,$fc,$00,$00,$03,$ff,$f0,$00,$c0,$03,$ff,$ff,$fc,$00,$30,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00,$ff,$fc,$00,$00,$03,$ff,$f0,$00
	dc.b	$c0,$0c,$cc,$f3,$33,$00,$30,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$c0,$0c,$cc,$f3,$33,$00,$30,$00
	dc.b	$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$ff,$f3,$33,$0c,$cc,$ff,$f0,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$30,$00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00
	dc.b	$0c,$00,$00,$00,$00,$03,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0c,$00,$00,$00,$00,$03,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$00,$00,$00,$00,$0c,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00
	dc.b	$00,$c0,$00,$00,$00,$30,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$c0,$00,$00,$00,$30,$00,$00
	dc.b	$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$30,$00,$00,$00,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00
	dc.b	$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00
	dc.b	$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$00,$cf,$ff,$30,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00,$00,$00,$00,$03,$ff,$ff,$fc,$00
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$f0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff
	dc.b	$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$3f,$ff,$ff,$ff,$ff,$ff,$c0,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc
	dc.b	$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$03,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$ff,$ff,$ff,$ff,$f0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0
	dc.b	$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00
	dc.b	$00,$00,$00,$00
bd_plane	dc.b	$00,$00,$78,$00,$00,$00,$78,$00,$00,$00,$78,$00,$00,$00,$fc,$00,$00,$00,$84,$00,$00,$00,$84,$00,$00,$01,$f8,$00,$00,$01,$08,$00
	dc.b	$00,$01,$08,$00,$00,$03,$f0,$00,$00,$02,$10,$00,$00,$02,$10,$00,$00,$07,$ef,$00,$00,$04,$2f,$00,$00,$04,$2f,$00,$00,$0f,$df,$80
	dc.b	$00,$08,$50,$80,$00,$08,$50,$80,$00,$1f,$9f,$80,$00,$10,$90,$80,$00,$10,$90,$80,$1f,$ff,$ff,$80,$1f,$e1,$f0,$80,$1f,$e1,$f0,$80
	dc.b	$7f,$ff,$ff,$00,$60,$00,$01,$00,$60,$00,$01,$00,$ff,$ff,$ff,$00,$80,$00,$01,$00,$80,$00,$01,$00,$7f,$ff,$ff,$00,$60,$00,$01,$00
	dc.b	$60,$00,$01,$00,$1f,$ff,$ff,$80,$1f,$e1,$f0,$80,$1f,$e1,$f0,$80,$00,$1f,$9f,$80,$00,$10,$90,$80,$00,$10,$90,$80,$00,$0f,$df,$80
	dc.b	$00,$08,$50,$80,$00,$08,$50,$80,$00,$07,$ef,$00,$00,$04,$2f,$00,$00,$04,$2f,$00,$00,$03,$f0,$00,$00,$02,$10,$00,$00,$02,$10,$00
	dc.b	$00,$01,$f8,$00,$00,$01,$08,$00,$00,$01,$08,$00,$00,$00,$fc,$00,$00,$00,$84,$00,$00,$00,$84,$00,$00,$00,$78,$00,$00,$00,$78,$00
	dc.b	$00,$00,$78,$00,$00,$00,$00,$00,$78,$00,$00,$00,$78,$00,$00,$00,$78,$00,$00,$00,$fc,$00,$00,$00,$fc,$00,$00,$00,$fc,$00,$00,$01
	dc.b	$f8,$00,$00,$01,$f8,$00,$00,$01,$f8,$00,$00,$03,$f0,$00,$00,$03,$f0,$00,$00,$03,$f0,$00,$00,$07,$ef,$00,$00,$07,$ef,$00,$00,$07
	dc.b	$ef,$00,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$1f,$9f,$80,$00,$1f,$9f,$80,$00,$1f,$9f,$80,$1f,$ff,$ff,$80,$1f,$ff
	dc.b	$ff,$80,$1f,$ff,$ff,$80,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$7f,$ff
	dc.b	$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$1f,$ff,$ff,$80,$1f,$ff,$ff,$80,$1f,$ff,$ff,$80,$00,$1f,$9f,$80,$00,$1f,$9f,$80,$00,$1f
	dc.b	$9f,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$0f,$df,$80,$00,$07,$ef,$00,$00,$07,$ef,$00,$00,$07,$ef,$00,$00,$03,$f0,$00,$00,$03
	dc.b	$f0,$00,$00,$03,$f0,$00,$00,$01,$f8,$00,$00,$01,$f8,$00,$00,$01,$f8,$00,$00,$00,$fc,$00,$00,$00,$fc,$00,$00,$00,$fc,$00,$00,$00
	dc.b	$78,$00,$00,$00,$78,$00,$00,$00,$78,$00,$00,$00
bd_plane_l	dc.b	$0f,$00,$00,$00,$0f,$00,$00,$00,$0f,$00,$00,$00,$1f,$80,$00,$00,$10,$80,$00,$00,$10,$80,$00,$00,$0f,$c0,$00,$00,$08,$40,$00,$00
	dc.b	$08,$40,$00,$00,$07,$e0,$00,$00,$04,$20,$00,$00,$04,$20,$00,$00,$7b,$f0,$00,$00,$7a,$10,$00,$00,$7a,$10,$00,$00,$fd,$f8,$00,$00
	dc.b	$85,$08,$00,$00,$85,$08,$00,$00,$fc,$fc,$00,$00,$84,$84,$00,$00,$84,$84,$00,$00,$ff,$ff,$fc,$00,$87,$c3,$fc,$00,$87,$c3,$fc,$00
	dc.b	$7f,$ff,$ff,$00,$40,$00,$03,$00,$40,$00,$03,$00,$7f,$ff,$ff,$80,$40,$00,$00,$80,$40,$00,$00,$80,$7f,$ff,$ff,$00,$40,$00,$03,$00
	dc.b	$40,$00,$03,$00,$ff,$ff,$fc,$00,$87,$c3,$fc,$00,$87,$c3,$fc,$00,$fc,$fc,$00,$00,$84,$84,$00,$00,$84,$84,$00,$00,$fd,$f8,$00,$00
	dc.b	$85,$08,$00,$00,$85,$08,$00,$00,$7b,$f0,$00,$00,$7a,$10,$00,$00,$7a,$10,$00,$00,$07,$e0,$00,$00,$04,$20,$00,$00,$04,$20,$00,$00
	dc.b	$0f,$c0,$00,$00,$08,$40,$00,$00,$08,$40,$00,$00,$1f,$80,$00,$00,$10,$80,$00,$00,$10,$80,$00,$00,$0f,$00,$00,$00,$0f,$00,$00,$00
	dc.b	$0f,$00,$00,$00,$00,$00,$0f,$00,$00,$00,$0f,$00,$00,$00,$0f,$00,$00,$00,$1f,$80,$00,$00,$1f,$80,$00,$00,$1f,$80,$00,$00,$0f,$c0
	dc.b	$00,$00,$0f,$c0,$00,$00,$0f,$c0,$00,$00,$07,$e0,$00,$00,$07,$e0,$00,$00,$07,$e0,$00,$00,$7b,$f0,$00,$00,$7b,$f0,$00,$00,$7b,$f0
	dc.b	$00,$00,$fd,$f8,$00,$00,$fd,$f8,$00,$00,$fd,$f8,$00,$00,$fc,$fc,$00,$00,$fc,$fc,$00,$00,$fc,$fc,$00,$00,$ff,$ff,$fc,$00,$ff,$ff
	dc.b	$fc,$00,$ff,$ff,$fc,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff
	dc.b	$ff,$00,$7f,$ff,$ff,$00,$7f,$ff,$ff,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$ff,$ff,$fc,$00,$fc,$fc,$00,$00,$fc,$fc,$00,$00,$fc,$fc
	dc.b	$00,$00,$fd,$f8,$00,$00,$fd,$f8,$00,$00,$fd,$f8,$00,$00,$7b,$f0,$00,$00,$7b,$f0,$00,$00,$7b,$f0,$00,$00,$07,$e0,$00,$00,$07,$e0
	dc.b	$00,$00,$07,$e0,$00,$00,$0f,$c0,$00,$00,$0f,$c0,$00,$00,$0f,$c0,$00,$00,$1f,$80,$00,$00,$1f,$80,$00,$00,$1f,$80,$00,$00,$0f,$00
	dc.b	$00,$00,$0f,$00,$00,$00,$0f,$00,$00,$00,$00,$00
bd_taxi	dc.b	$1e,$07,$80,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$21,$f8,$40,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00
	dc.b	$40,$00,$20,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$8e,$0e,$10,$00,$ff,$ff,$f0,$00
	dc.b	$ff,$ff,$f0,$00,$8e,$0e,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$8e,$0e,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$8e,$0e,$10,$00
	dc.b	$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$8e,$0e,$10,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00
	dc.b	$40,$00,$20,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$21,$f8,$40,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$00,$00,$1e,$07
	dc.b	$80,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff
	dc.b	$e0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$1e,$07,$80,$00,$00,$00
bd_inv0	dc.b	$00,$60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$90,$00,$00,$00,$f0,$00,$00,$00,$90,$00,$00,$00,$90,$00,$00,$00,$f0,$00,$00
	dc.b	$00,$90,$00,$00,$1f,$9f,$80,$00,$1f,$ff,$80,$00,$1f,$9f,$80,$00,$20,$00,$40,$00,$3f,$ff,$c0,$00,$20,$00,$40,$00,$40,$00,$20,$00
	dc.b	$7f,$ff,$e0,$00,$40,$00,$20,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00
	dc.b	$98,$01,$90,$00,$e7,$fe,$70,$00,$80,$00,$10,$00,$98,$01,$90,$00,$e7,$fe,$70,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00
	dc.b	$80,$00,$10,$00,$92,$04,$90,$00,$ed,$fb,$70,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$80,$00,$10,$00
	dc.b	$ff,$ff,$f0,$00,$80,$00,$10,$00,$aa,$95,$50,$00,$d5,$6a,$b0,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00
	dc.b	$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00
	dc.b	$80,$00,$10,$00,$a4,$92,$50,$00,$db,$6d,$b0,$00,$80,$00,$10,$00,$80,$00,$10,$00,$ff,$ff,$f0,$00,$80,$00,$10,$00,$92,$64,$90,$00
	dc.b	$ff,$ff,$f0,$00,$92,$64,$90,$00,$6d,$9b,$60,$00,$6d,$9b,$60,$00,$6d,$9b,$60,$00,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$60
	dc.b	$00,$00,$00,$f0,$00,$00,$00,$f0,$00,$00,$00,$f0,$00,$00,$00,$f0,$00,$00,$00,$f0,$00,$00,$00,$f0,$00,$00,$1f,$ff,$80,$00,$1f,$ff
	dc.b	$80,$00,$1f,$ff,$80,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$3f,$ff,$c0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$7f,$ff,$e0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff
	dc.b	$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$ff,$ff,$f0,$00,$6d,$9b
	dc.b	$60,$00,$6d,$9b,$60,$00,$6d,$9b,$60,$00,$00,$00
bd_inv1	dc.b	$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$01,$80,$60,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$02,$00,$10,$00,$03,$ff,$f0,$00
	dc.b	$03,$ff,$f0,$00,$04,$00,$08,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$08,$00,$04,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$10,$00,$02,$00
	dc.b	$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$10,$00,$02,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$11,$80,$62,$00,$1e,$7f,$9e,$00,$1e,$7f,$9e,$00
	dc.b	$13,$80,$72,$00,$1c,$7f,$8e,$00,$1c,$7f,$8e,$00,$11,$80,$62,$00,$1e,$7f,$9e,$00,$1e,$7f,$9e,$00,$10,$00,$02,$00,$1f,$ff,$fe,$00
	dc.b	$1f,$ff,$fe,$00,$10,$00,$02,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$18,$00,$06,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$22,$40,$91,$00
	dc.b	$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$26,$61,$99,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$4c,$cc,$cc,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80
	dc.b	$4c,$cc,$cc,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$99,$92,$66,$40,$ff,$f3,$ff,$c0,$ff,$f3,$ff,$c0,$99,$92,$66,$40,$ff,$f3,$ff,$c0
	dc.b	$ff,$f3,$ff,$c0,$b3,$21,$33,$40,$ff,$e1,$ff,$c0,$ff,$e1,$ff,$c0,$b5,$40,$ab,$40,$fd,$c0,$ef,$c0,$fd,$c0,$ef,$c0,$48,$80,$44,$80
	dc.b	$48,$80,$44,$80,$48,$80,$44,$80,$00,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff
	dc.b	$e0,$00,$03,$ff,$f0,$00,$03,$ff,$f0,$00,$03,$ff,$f0,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$0f,$ff,$fc,$00,$0f,$ff
	dc.b	$fc,$00,$0f,$ff,$fc,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff
	dc.b	$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff
	dc.b	$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff
	dc.b	$fe,$00,$1f,$ff,$fe,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$7f,$ff
	dc.b	$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$ff,$f3,$ff,$c0,$ff,$f3,$ff,$c0,$ff,$f3
	dc.b	$ff,$c0,$ff,$f3,$ff,$c0,$ff,$f3,$ff,$c0,$ff,$f3,$ff,$c0,$ff,$e1,$ff,$c0,$ff,$e1,$ff,$c0,$ff,$e1,$ff,$c0,$fd,$c0,$ef,$c0,$fd,$c0
	dc.b	$ef,$c0,$fd,$c0,$ef,$c0,$48,$80,$44,$80,$48,$80,$44,$80,$48,$80,$44,$80,$00,$00
bd_inv2	dc.b	$00,$0c,$00,$00,$00,$0c,$00,$00,$00,$0c,$00,$00,$00,$12,$00,$00,$00,$12,$00,$00,$00,$1e,$00,$00,$00,$21,$00,$00,$00,$21,$00,$00
	dc.b	$00,$3f,$00,$00,$00,$40,$80,$00,$00,$40,$80,$00,$00,$7f,$80,$00,$00,$40,$80,$00,$00,$40,$80,$00,$00,$7f,$80,$00,$00,$80,$40,$00
	dc.b	$00,$80,$40,$00,$00,$ff,$c0,$00,$00,$b3,$40,$00,$00,$80,$40,$00,$00,$cc,$c0,$00,$00,$b3,$40,$00,$00,$80,$40,$00,$00,$cc,$c0,$00
	dc.b	$7f,$00,$3f,$80,$7f,$00,$3f,$80,$7f,$ff,$ff,$80,$80,$00,$00,$40,$80,$00,$00,$40,$ff,$ff,$ff,$c0,$80,$00,$00,$40,$80,$00,$00,$40
	dc.b	$ff,$ff,$ff,$c0,$80,$00,$00,$40,$80,$00,$00,$40,$ff,$ff,$ff,$c0,$60,$00,$01,$80,$60,$00,$01,$80,$7f,$ff,$ff,$80,$1f,$00,$3e,$00
	dc.b	$1f,$00,$3e,$00,$1f,$ff,$fe,$00,$01,$40,$a0,$00,$01,$00,$20,$00,$01,$bf,$60,$00,$01,$00,$20,$00,$01,$00,$20,$00,$01,$ff,$e0,$00
	dc.b	$01,$00,$20,$00,$01,$00,$20,$00,$01,$ff,$e0,$00,$03,$80,$70,$00,$03,$80,$70,$00,$03,$ff,$f0,$00,$04,$00,$08,$00,$04,$00,$08,$00
	dc.b	$07,$ff,$f8,$00,$08,$00,$04,$00,$08,$00,$04,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00,$08,$00,$04,$00,$0f,$ff,$fc,$00,$10,$40,$82,$00
	dc.b	$10,$40,$82,$00,$1f,$ff,$fe,$00,$0f,$bf,$7c,$00,$0f,$bf,$7c,$00,$0f,$bf,$7c,$00,$00,$00,$00,$0c,$00,$00,$00,$0c,$00,$00,$00,$0c
	dc.b	$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$1e,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$3f,$00,$00,$00,$7f,$80,$00,$00,$7f
	dc.b	$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$7f,$80,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff
	dc.b	$ff,$80,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff
	dc.b	$ff,$c0,$ff,$ff,$ff,$c0,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$01,$ff
	dc.b	$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff,$e0,$00,$01,$ff
	dc.b	$e0,$00,$03,$ff,$f0,$00,$03,$ff,$f0,$00,$03,$ff,$f0,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$07,$ff,$f8,$00,$0f,$ff,$fc,$00,$0f,$ff
	dc.b	$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$0f,$bf
	dc.b	$7c,$00,$0f,$bf,$7c,$00,$0f,$bf,$7c,$00,$00,$00
bd_inv3	dc.b	$44,$40,$88,$80,$44,$40,$88,$80,$44,$40,$88,$80,$ee,$e1,$dd,$c0,$aa,$a1,$55,$40,$ee,$e1,$dd,$c0,$7f,$c0,$ff,$80,$5b,$40,$b6,$80
	dc.b	$7f,$c0,$ff,$80,$3f,$ff,$ff,$00,$2a,$ff,$d5,$00,$3f,$ff,$ff,$00,$1f,$ff,$fe,$00,$10,$00,$02,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00
	dc.b	$10,$00,$02,$00,$1f,$ff,$fe,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00,$0c,$ff,$cc,$00
	dc.b	$0f,$ff,$fc,$00,$08,$00,$04,$00,$0c,$ff,$cc,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00
	dc.b	$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$08,$00,$04,$00,$0d,$7f,$ac,$00,$1f,$ff,$fe,$00,$10,$00,$02,$00,$1f,$ff,$fe,$00,$3f,$ff,$ff,$00
	dc.b	$20,$00,$01,$00,$3f,$ff,$ff,$00,$7f,$ff,$ff,$80,$40,$00,$00,$80,$7f,$ff,$ff,$80,$ff,$ff,$ff,$c0,$80,$00,$00,$40,$ff,$ff,$ff,$c0
	dc.b	$ff,$ff,$ff,$c0,$80,$00,$00,$40,$f6,$ff,$db,$c0,$ff,$ff,$ff,$c0,$80,$00,$00,$40,$f6,$ff,$db,$c0,$ff,$ff,$ff,$c0,$80,$00,$00,$40
	dc.b	$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$80,$00,$00,$40,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$80,$00,$00,$40,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0
	dc.b	$80,$00,$00,$40,$ff,$ff,$ff,$c0,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$00,$00,$44,$40,$88,$80,$44,$40,$88,$80,$44,$40
	dc.b	$88,$80,$ee,$e1,$dd,$c0,$ee,$e1,$dd,$c0,$ee,$e1,$dd,$c0,$7f,$c0,$ff,$80,$7f,$c0,$ff,$80,$7f,$c0,$ff,$80,$3f,$ff,$ff,$00,$3f,$ff
	dc.b	$ff,$00,$3f,$ff,$ff,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$0f,$ff
	dc.b	$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff
	dc.b	$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff,$fc,$00,$0f,$ff
	dc.b	$fc,$00,$0f,$ff,$fc,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$1f,$ff,$fe,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$3f,$ff,$ff,$00,$7f,$ff
	dc.b	$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff
	dc.b	$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff
	dc.b	$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$ff,$ff,$ff,$c0,$7f,$ff
	dc.b	$ff,$80,$7f,$ff,$ff,$80,$7f,$ff,$ff,$80,$00,$00
bd_spark0	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$94,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$5a,$00,$00,$00,$58,$00,$00,$00,$00,$00,$00,$01,$84,$00,$00,$00,$84,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$01,$93,$00,$00,$00,$82,$00,$00,$00,$00,$00,$00,$00,$84,$00,$00,$00,$84,$00,$00,$00,$00,$00,$00,$01,$4a,$00,$00
	dc.b	$00,$48,$00,$00,$00,$00,$00,$00,$00,$54,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$94
	dc.b	$00,$00,$00,$94,$00,$00,$00,$94,$00,$00,$00,$5a,$00,$00,$00,$5a,$00,$00,$00,$5a,$00,$00,$01,$84,$00,$00,$01,$84,$00,$00,$01,$84
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$93,$00,$00,$01,$93,$00,$00,$01,$93,$00,$00,$00,$84,$00,$00,$00,$84
	dc.b	$00,$00,$00,$84,$00,$00,$01,$4a,$00,$00,$01,$4a,$00,$00,$01,$4a,$00,$00,$00,$54,$00,$00,$00,$54,$00,$00,$00,$54,$00,$00,$00,$10
	dc.b	$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
bd_spark1	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$48,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$48,$00,$00
	dc.b	$00,$48,$00,$00,$00,$00,$00,$00,$02,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$c0,$00,$04,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$c0,$00,$04,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$48,$00,$00,$00,$48,$00,$00,$00,$00,$00,$00,$00,$48,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$48,$00,$00,$00,$48
	dc.b	$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$c0,$00,$0c,$00,$c0,$00,$0c,$00
	dc.b	$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$0c,$00,$c0,$00,$0c,$00
	dc.b	$c0,$00,$0c,$00,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$01
	dc.b	$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48,$00,$00,$00,$48
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
bd_spark2	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$20,$80,$00,$00,$20,$00,$00
	dc.b	$00,$00,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$10,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$20,$00,$10,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$00,$00,$08,$00
	dc.b	$00,$00,$00,$00,$60,$10,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$20,$00,$10,$00,$20,$00,$00,$00,$00,$00
	dc.b	$20,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00
	dc.b	$00,$00,$00,$00,$02,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$20,$00,$00,$00,$20
	dc.b	$00,$00,$04,$20,$80,$00,$04,$20,$80,$00,$04,$20,$80,$00,$02,$01,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$10,$00,$10,$00,$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$0c,$00,$00,$00,$0c,$00,$00,$00,$0c,$00,$60,$10,$00,$00,$60,$10,$00,$00,$60,$10,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00
	dc.b	$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$02,$01,$00,$00,$02,$00,$80,$00,$02,$00,$80,$00,$02,$00,$80,$00,$00,$10,$00,$00,$00,$10
	dc.b	$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$00
bd_spark3	dc.b	$01,$02,$00,$00,$01,$02,$00,$00,$00,$00,$00,$00,$40,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$10,$00,$20,$00,$10,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$20,$00,$10,$00,$20,$00,$10,$00,$00,$00,$00,$00,$40,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$02,$00,$00,$01,$02,$00,$00,$01,$02,$00,$00,$40,$00,$08,$00,$40,$00,$08,$00,$40,$00
	dc.b	$08,$00,$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00
	dc.b	$00,$00,$80,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$80,$00,$00,$00,$80,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$10,$00,$20,$00,$10,$00,$20,$00,$10,$00,$40,$00,$08,$00,$40,$00
	dc.b	$08,$00,$40,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
bd_beam0	dc.b	$07,$e0,$06,$60,$08,$10,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30,$00,$00,$01,$f8,$01,$98,$00,$00,$03,$f0
	dc.b	$03,$30,$04,$08,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30,$00,$00,$07,$e0,$06,$60,$00,$00,$0f,$c0,$0c,$c0,$00,$00,$0f,$c0,$0c,$c0
	dc.b	$10,$20,$0f,$c0,$0c,$c0,$00,$00,$1f,$80,$19,$80,$00,$00,$0f,$c0,$0c,$c0,$00,$00,$0f,$c0,$0c,$c0,$00,$00,$0f,$c0,$0c,$c0,$10,$20
	dc.b	$00,$00,$0f,$f0,$0f,$f0,$0f,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$01,$f8,$01,$f8,$01,$f8
	dc.b	$07,$f8,$07,$f8,$07,$f8,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$07,$e0,$07,$e0,$07,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$e0
	dc.b	$1f,$e0,$1f,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$80,$1f,$80,$1f,$80,$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$e0,$1f,$e0
	dc.b	$1f,$e0,$00,$00
bd_beam1	dc.b	$07,$e0,$06,$60,$00,$00,$0f,$c0,$0c,$c0,$00,$00,$0f,$c0,$0c,$c0,$10,$20,$0f,$c0,$0c,$c0,$00,$00,$1f,$80,$19,$80,$00,$00,$0f,$c0
	dc.b	$0c,$c0,$00,$00,$0f,$c0,$0c,$c0,$00,$00,$0f,$c0,$0c,$c0,$10,$20,$07,$e0,$06,$60,$00,$00,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30
	dc.b	$00,$00,$03,$f0,$03,$30,$00,$00,$01,$f8,$01,$98,$02,$04,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30,$00,$00,$03,$f0,$03,$30,$00,$00
	dc.b	$00,$00,$07,$e0,$07,$e0,$07,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$e0,$1f,$e0,$1f,$e0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$80,$1f,$80,$1f,$80
	dc.b	$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$0f,$c0,$1f,$e0,$1f,$e0,$1f,$e0,$07,$e0,$07,$e0,$07,$e0,$03,$f0,$03,$f0,$03,$f0,$03,$f0
	dc.b	$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$fc,$03,$fc,$03,$fc,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0,$03,$f0
	dc.b	$03,$f0,$00,$00
bd_tbeam0	dc.b	$00,$4f,$f4,$00,$00,$b0,$0b,$00,$00,$b0,$0b,$00,$00,$9f,$e8,$00,$01,$60,$16,$00,$01,$60,$16,$00,$01,$3f,$d2,$00,$02,$c0,$2c,$00
	dc.b	$02,$c0,$2c,$00,$02,$4f,$a4,$80,$01,$b0,$5b,$40,$01,$b0,$5b,$40,$04,$93,$c9,$20,$03,$6c,$36,$c0,$03,$6c,$36,$c0,$01,$25,$f2,$40
	dc.b	$02,$da,$0d,$80,$02,$da,$0d,$80,$00,$4b,$fc,$80,$00,$34,$03,$40,$00,$34,$03,$40,$00,$17,$f9,$00,$00,$68,$06,$80,$00,$68,$06,$80
	dc.b	$00,$2f,$f2,$00,$00,$d0,$0d,$00,$00,$d0,$0d,$00,$00,$5f,$e4,$00,$01,$a0,$1a,$00,$01,$a0,$1a,$00,$00,$9f,$c9,$00,$03,$60,$36,$00
	dc.b	$03,$60,$36,$00,$01,$27,$92,$40,$06,$d8,$6d,$a0,$06,$d8,$6d,$a0,$02,$49,$a4,$80,$05,$b6,$5b,$60,$05,$b6,$5b,$60,$00,$93,$f9,$00
	dc.b	$03,$6c,$06,$c0,$03,$6c,$06,$c0,$00,$27,$fa,$00,$00,$58,$05,$80,$00,$58,$05,$80,$00,$4f,$fc,$00,$00,$30,$03,$00,$00,$30,$03,$00
	dc.b	$00,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$03,$ff,$fe,$00,$03,$ff
	dc.b	$fe,$00,$03,$ff,$fe,$00,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$03,$ff
	dc.b	$ff,$c0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$00,$7f,$ff,$c0,$00,$7f,$ff,$c0,$00,$7f,$ff,$c0,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$7f
	dc.b	$ff,$80,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$03,$ff,$ff,$00,$03,$ff
	dc.b	$ff,$00,$03,$ff,$ff,$00,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$03,$ff
	dc.b	$ff,$c0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$00,$00,$7f,$ff,$00,$00,$7f
	dc.b	$ff,$00,$00,$00
bd_tbeam1	dc.b	$04,$93,$c9,$20,$03,$6c,$36,$c0,$03,$6c,$36,$c0,$01,$25,$f2,$40,$02,$da,$0d,$80,$02,$da,$0d,$80,$00,$4b,$fc,$80,$00,$34,$03,$40
	dc.b	$00,$34,$03,$40,$00,$17,$f9,$00,$00,$68,$06,$80,$00,$68,$06,$80,$00,$2f,$f2,$00,$00,$d0,$0d,$00,$00,$d0,$0d,$00,$00,$5f,$e4,$00
	dc.b	$01,$a0,$1a,$00,$01,$a0,$1a,$00,$00,$9f,$c9,$00,$03,$60,$36,$00,$03,$60,$36,$00,$01,$27,$92,$40,$06,$d8,$6d,$a0,$06,$d8,$6d,$a0
	dc.b	$02,$49,$a4,$80,$05,$b6,$5b,$60,$05,$b6,$5b,$60,$00,$93,$f9,$00,$03,$6c,$06,$c0,$03,$6c,$06,$c0,$00,$27,$fa,$00,$00,$58,$05,$80
	dc.b	$00,$58,$05,$80,$00,$4f,$fc,$00,$00,$30,$03,$00,$00,$30,$03,$00,$00,$9f,$f8,$00,$00,$60,$06,$00,$00,$60,$06,$00,$01,$3f,$f2,$00
	dc.b	$00,$c0,$0c,$00,$00,$c0,$0c,$00,$02,$5f,$e4,$00,$01,$a0,$1b,$00,$01,$a0,$1b,$00,$04,$97,$c9,$20,$03,$68,$36,$c0,$03,$68,$36,$c0
	dc.b	$00,$00,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$00,$7f,$ff,$c0,$00,$7f
	dc.b	$ff,$c0,$00,$7f,$ff,$c0,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$80,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff
	dc.b	$fe,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$03,$ff,$ff,$00,$03,$ff,$ff,$00,$03,$ff,$ff,$00,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff
	dc.b	$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$03,$ff,$ff,$c0,$00,$7f,$ff,$80,$00,$7f
	dc.b	$ff,$80,$00,$7f,$ff,$80,$00,$7f,$ff,$00,$00,$7f,$ff,$00,$00,$7f,$ff,$00,$00,$ff,$fe,$00,$00,$ff,$fe,$00,$00,$ff,$fe,$00,$01,$ff
	dc.b	$fe,$00,$01,$ff,$fe,$00,$01,$ff,$fe,$00,$03,$ff,$ff,$00,$03,$ff,$ff,$00,$03,$ff,$ff,$00,$07,$ff,$ff,$e0,$07,$ff,$ff,$e0,$07,$ff
	dc.b	$ff,$e0,$00,$00
bd_cross	dc.b	$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00
	dc.b	$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00
	dc.b	$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00
	dc.b	$c0,$18,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$18,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$18,$03,$00,$c0,$00,$03,$00
	dc.b	$00,$00,$00,$00,$c0,$ff,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$ff,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$18,$03,$00
	dc.b	$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$18,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$18,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00
	dc.b	$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00
	dc.b	$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$00,$00,$00,$00,$c0,$00,$03,$00
	dc.b	$c0,$00,$03,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00
	dc.b	$00,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$c0,$00,$03,$00,$c0,$00
	dc.b	$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00
	dc.b	$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00
	dc.b	$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18
	dc.b	$03,$00,$c0,$18,$03,$00,$c0,$ff,$03,$00,$c0,$ff,$03,$00,$c0,$ff,$03,$00,$c0,$ff,$03,$00,$c0,$ff,$03,$00,$c0,$ff,$03,$00,$c0,$18
	dc.b	$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18,$03,$00,$c0,$18
	dc.b	$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00
	dc.b	$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$c0,$00
	dc.b	$03,$00,$c0,$00,$03,$00,$c0,$00,$03,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff
	dc.b	$ff,$00,$00,$00
bd_bolt	dc.b	$70,$00,$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$70,$00
	dc.b	$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$70,$00,$50,$00,$00,$00,$00,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00
	dc.b	$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00,$70,$00
	dc.b	$70,$00,$00,$00
bd_window	dc.b	$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$00,$00
	dc.b	$00,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00
	dc.b	$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$3f,$ff,$ff,$ff,$fc,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$3f,$ff,$ff,$ff,$fc,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00
	dc.b	$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00
	dc.b	$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$00,$00,$18,$00,$00,$00,$ff,$ff,$ff,$ff
	dc.b	$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff
	dc.b	$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00
	dc.b	$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00
	dc.b	$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00
	dc.b	$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$c0,$00,$18,$00,$03,$00,$ff,$ff
	dc.b	$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff
	dc.b	$ff,$00,$00,$00
	section	bobtab,data
BobTable:	; data,mask,words,height,width
	dc.l	bd_player_stand,bd_player_stand+278
	dc.w	2,23,26,0
	dc.l	bd_player_walk1,bd_player_walk1+278
	dc.w	2,23,26,0
	dc.l	bd_player_walk2,bd_player_walk2+278
	dc.w	2,23,26,0
	dc.l	bd_player_cheer,bd_player_cheer+278
	dc.w	2,23,26,0
	dc.l	bd_ghost0_0,bd_ghost0_0+182
	dc.w	2,15,18,0
	dc.l	bd_ghost0_1,bd_ghost0_1+182
	dc.w	2,15,18,0
	dc.l	bd_ghost0_2,bd_ghost0_2+182
	dc.w	2,15,18,0
	dc.l	bd_ghost0_3,bd_ghost0_3+182
	dc.w	2,15,18,0
	dc.l	bd_ghost1_0,bd_ghost1_0+182
	dc.w	2,15,19,0
	dc.l	bd_ghost1_1,bd_ghost1_1+182
	dc.w	2,15,19,0
	dc.l	bd_ghost1_2,bd_ghost1_2+182
	dc.w	2,15,19,0
	dc.l	bd_ghost1_3,bd_ghost1_3+182
	dc.w	2,15,19,0
	dc.l	bd_ghost2_0,bd_ghost2_0+182
	dc.w	2,15,19,0
	dc.l	bd_ghost2_1,bd_ghost2_1+182
	dc.w	2,15,19,0
	dc.l	bd_ghost2_2,bd_ghost2_2+182
	dc.w	2,15,19,0
	dc.l	bd_ghost2_3,bd_ghost2_3+182
	dc.w	2,15,19,0
	dc.l	bd_ghost3_0,bd_ghost3_0+68
	dc.w	1,11,14,0
	dc.l	bd_ghost3_1,bd_ghost3_1+68
	dc.w	1,11,14,0
	dc.l	bd_ghost3_2,bd_ghost3_2+68
	dc.w	1,11,14,0
	dc.l	bd_ghost3_3,bd_ghost3_3+68
	dc.w	1,11,14,0
	dc.l	bd_bat0,bd_bat0+170
	dc.w	2,14,24,0
	dc.l	bd_bat1,bd_bat1+170
	dc.w	2,14,24,0
	dc.l	bd_slime,bd_slime+80
	dc.w	1,13,12,0
	dc.l	bd_bshot,bd_bshot+80
	dc.w	1,13,14,0
	dc.l	bd_pw_inv,bd_pw_inv+254
	dc.w	2,21,22,0
	dc.l	bd_pw_energy,bd_pw_energy+254
	dc.w	2,21,22,0
	dc.l	bd_pw_twin,bd_pw_twin+254
	dc.w	2,21,22,0
	dc.l	bd_pw_life,bd_pw_life+254
	dc.w	2,21,21,0
	dc.l	bd_trap_closed,bd_trap_closed+122
	dc.w	2,10,20,0
	dc.l	bd_trap_open,bd_trap_open+170
	dc.w	2,14,24,0
	dc.l	bd_boss,bd_boss+1106
	dc.w	4,46,52,0
	dc.l	bd_boss_hit,bd_boss_hit+1106
	dc.w	4,46,52,0
	dc.l	bd_boss_stun,bd_boss_stun+1106
	dc.w	4,46,52,0
	dc.l	bd_plane,bd_plane+230
	dc.w	2,19,25,0
	dc.l	bd_plane_l,bd_plane_l+230
	dc.w	2,19,25,0
	dc.l	bd_taxi,bd_taxi+158
	dc.w	2,13,20,0
	dc.l	bd_inv0,bd_inv0+278
	dc.w	2,23,20,0
	dc.l	bd_inv1,bd_inv1+266
	dc.w	2,22,26,0
	dc.l	bd_inv2,bd_inv2+278
	dc.w	2,23,26,0
	dc.l	bd_inv3,bd_inv3+278
	dc.w	2,23,26,0
	dc.l	bd_spark0,bd_spark0+266
	dc.w	2,22,22,0
	dc.l	bd_spark1,bd_spark1+266
	dc.w	2,22,22,0
	dc.l	bd_spark2,bd_spark2+266
	dc.w	2,22,22,0
	dc.l	bd_spark3,bd_spark3+266
	dc.w	2,22,22,0
	dc.l	bd_beam0,bd_beam0+98
	dc.w	1,16,16,0
	dc.l	bd_beam1,bd_beam1+98
	dc.w	1,16,16,0
	dc.l	bd_tbeam0,bd_tbeam0+194
	dc.w	2,16,32,0
	dc.l	bd_tbeam1,bd_tbeam1+194
	dc.w	2,16,32,0
	dc.l	bd_cross,bd_cross+290
	dc.w	2,24,24,0
	dc.l	bd_bolt,bd_bolt+50
	dc.w	1,8,5,0
	dc.l	bd_window,bd_window+578
	dc.w	3,32,40,0
	section	bgdata,data
bg_jfk	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$aa,$00,$00,$04,$da,$00,$00,$04,$81,$00,$ca,$00,$00,$20,$da,$00,$00,$20
	dc.b	$81,$00,$81,$00,$81,$00,$ba,$00,$00,$10,$da,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$81,$00,$cc,$00,$00,$40,$da,$00,$00,$40
	dc.b	$81,$00,$81,$00,$81,$00,$b3,$00,$03,$20,$00,$00,$20,$dd,$00,$03,$20,$00,$00,$20,$81,$00,$b1,$00,$00,$08,$da,$00,$00,$08,$81,$00
	dc.b	$81,$00,$81,$00,$b5,$00,$00,$80,$da,$00,$00,$80,$81,$00,$a0,$00,$00,$08,$fc,$00,$00,$02,$e0,$00,$00,$08,$fc,$00,$00,$02,$81,$00
	dc.b	$cc,$00,$00,$02,$e4,$00,$00,$10,$f8,$00,$00,$02,$e4,$00,$00,$10,$f8,$00,$00,$02,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$d2,$00
	dc.b	$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$b8,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$bb,$00,$00,$08,$da,$00
	dc.b	$00,$08,$da,$00,$00,$08,$81,$00,$cc,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$c2,$00,$00,$0e,$da,$00,$00,$0e,$9c,$00,$00,$20
	dc.b	$da,$00,$00,$20,$bc,$00,$00,$3c,$da,$00,$00,$3c,$97,$00,$00,$04,$da,$00,$00,$04,$c1,$00,$00,$7c,$da,$00,$00,$7c,$81,$00,$ae,$00
	dc.b	$00,$f8,$da,$00,$00,$f8,$a0,$00,$00,$04,$da,$00,$00,$04,$b9,$00,$01,$01,$f8,$db,$00,$01,$01,$f8,$81,$00,$af,$00,$01,$03,$f0,$db
	dc.b	$00,$01,$03,$f0,$81,$00,$af,$00,$01,$03,$f0,$db,$00,$01,$03,$f0,$8e,$00,$00,$04,$fc,$00,$00,$20,$fa,$00,$00,$04,$e8,$00,$00,$04
	dc.b	$fc,$00,$00,$20,$fa,$00,$00,$04,$d9,$00,$01,$07,$f0,$db,$00,$01,$07,$f0,$a2,$00,$00,$40,$da,$00,$00,$40,$da,$00,$00,$40,$df,$00
	dc.b	$01,$07,$f0,$db,$00,$01,$07,$f0,$81,$00,$af,$00,$01,$07,$f0,$db,$00,$01,$07,$f0,$82,$00,$00,$04,$da,$00,$00,$04,$d7,$00,$01,$07
	dc.b	$f8,$db,$00,$01,$07,$f8,$81,$00,$af,$00,$01,$0f,$f8,$db,$00,$01,$0f,$f8,$81,$00,$af,$00,$01,$07,$fc,$db,$00,$01,$07,$fc,$a0,$00
	dc.b	$00,$02,$fb,$00,$00,$08,$e1,$00,$00,$02,$fb,$00,$00,$08,$c0,$00,$01,$07,$fc,$db,$00,$01,$07,$fc,$81,$00,$af,$00,$01,$07,$fe,$db
	dc.b	$00,$01,$07,$fe,$81,$00,$af,$00,$01,$07,$ff,$db,$00,$01,$07,$ff,$81,$00,$af,$00,$02,$03,$ff,$c0,$dc,$00,$02,$03,$ff,$c0,$94,$00
	dc.b	$00,$80,$f0,$00,$00,$01,$ec,$00,$00,$80,$f0,$00,$00,$01,$d8,$00,$03,$03,$ff,$f0,$60,$dd,$00,$03,$03,$ff,$f0,$60,$81,$00,$b1,$00
	dc.b	$03,$01,$ff,$ff,$c0,$dd,$00,$03,$01,$ff,$ff,$c0,$81,$00,$b0,$00,$02,$ff,$ff,$80,$dc,$00,$02,$ff,$ff,$80,$81,$00,$b0,$00,$01,$7f
	dc.b	$ff,$db,$00,$01,$7f,$ff,$99,$00,$00,$01,$da,$00,$00,$01,$c0,$00,$01,$3f,$fe,$db,$00,$01,$3f,$fe,$81,$00,$af,$00,$01,$0f,$f8,$db
	dc.b	$00,$01,$0f,$f8,$81,$00,$ae,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$ab,$00,$00,$02,$f4,$00
	dc.b	$00,$80,$e8,$00,$00,$02,$f4,$00,$00,$80,$81,$00,$a0,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$cc,$00
	dc.b	$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$98,$00,$00,$02,$da,$00,$00,$02,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$c9,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$c5,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$cb,$00,$00,$08,$e3,$00
	dc.b	$00,$40,$f9,$00,$00,$08,$e3,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$cd,$00,$00,$20,$fd,$00,$00,$20,$f5,$00,$00,$08
	dc.b	$ec,$00,$00,$20,$fd,$00,$00,$20,$f5,$00,$00,$08,$81,$00,$bf,$00,$00,$20,$f2,$00,$00,$40,$ea,$00,$00,$20,$f2,$00,$00,$40,$81,$00
	dc.b	$cd,$00,$00,$10,$da,$00,$00,$10,$da,$00,$00,$10,$81,$00,$b0,$00,$00,$01,$da,$00,$00,$01,$81,$00,$81,$00,$81,$00,$cf,$00,$00,$40
	dc.b	$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a5,$00,$00,$01,$da,$00,$00,$01,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c6,$00,$00,$08,$da,$00,$00,$08
	dc.b	$81,$00,$be,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$81,$00,$be,$00,$00,$08,$f8,$00,$00,$08,$e4,$00,$00,$08,$f8,$00,$00,$08
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a8,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$c0,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$cf,$00,$00,$40,$dc,$00,$02,$02,$00,$40,$dc,$00,$02,$02
	dc.b	$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$cf,$00,$00,$10,$da,$00,$00,$10,$81,$00,$b9,$00,$00,$08,$f7,$00,$00,$10,$fe,$00
	dc.b	$00,$30,$e9,$00,$00,$08,$f7,$00,$00,$10,$fe,$00,$00,$30,$81,$00,$ae,$00,$00,$30,$da,$00,$00,$30,$81,$00,$ae,$00,$00,$30,$f4,$00
	dc.b	$00,$40,$e8,$00,$00,$30,$f4,$00,$00,$40,$81,$00,$bc,$00,$01,$30,$10,$db,$00,$01,$30,$10,$81,$00,$af,$00,$00,$30,$da,$00,$00,$30
	dc.b	$81,$00,$ae,$00,$00,$30,$da,$00,$00,$30,$81,$00,$ae,$00,$00,$30,$fe,$00,$00,$08,$de,$00,$00,$30,$fe,$00,$00,$08,$81,$00,$b2,$00
	dc.b	$00,$30,$da,$00,$00,$30,$81,$00,$ae,$00,$00,$30,$da,$00,$00,$30,$81,$00,$b2,$00,$00,$40,$fe,$00,$00,$30,$de,$00,$00,$40,$fe,$00
	dc.b	$00,$30,$81,$00,$bd,$00,$00,$08,$f3,$00,$00,$30,$e9,$00,$00,$08,$f3,$00,$00,$30,$81,$00,$b1,$00,$03,$01,$ff,$ff,$f8,$f9,$00,$fd
	dc.b	$ff,$00,$c0,$ea,$00,$03,$01,$ff,$ff,$f8,$f9,$00,$fd,$ff,$00,$c0,$e6,$00,$03,$01,$ff,$ff,$c8,$f9,$00,$fd,$ff,$00,$c0,$ea,$00,$03
	dc.b	$01,$ff,$ff,$c8,$f9,$00,$fd,$ff,$00,$c0,$92,$00,$00,$01,$fe,$ff,$00,$fe,$fa,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$f0,$00,$00
	dc.b	$01,$fe,$ff,$00,$fe,$fa,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$ec,$00,$01,$01,$fe,$f7,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc
	dc.b	$f0,$00,$01,$01,$fe,$f7,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$eb,$00,$03,$01,$ff,$ff,$fe,$dd,$00,$03,$01,$ff,$ff,$fe,$e3,$00
	dc.b	$03,$0f,$ff,$ff,$fe,$fe,$00,$02,$3f,$f8,$01,$fe,$ff,$00,$fe,$fc,$00,$01,$01,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$f9,$00,$03
	dc.b	$0f,$ff,$ff,$fe,$fe,$00,$02,$3f,$f8,$01,$fe,$ff,$00,$fe,$fc,$00,$01,$01,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$f5,$00,$03,$0f
	dc.b	$ff,$ff,$fe,$fe,$00,$03,$3f,$f8,$01,$fe,$f7,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$f9,$00,$03,$0f,$ff,$ff,$fe,$fe,$00,$03,$3f
	dc.b	$f8,$01,$fe,$f7,$00,$fd,$ff,$00,$c0,$fd,$00,$01,$ff,$fc,$eb,$00,$03,$01,$ff,$ff,$fe,$dd,$00,$03,$01,$ff,$ff,$fe,$ea,$00,$f7,$ff
	dc.b	$00,$fe,$fe,$00,$00,$3f,$fe,$ff,$02,$80,$00,$06,$fd,$00,$00,$03,$fb,$ff,$00,$c0,$fd,$00,$02,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe,$00
	dc.b	$00,$3f,$fe,$ff,$02,$80,$00,$06,$fd,$00,$00,$03,$fb,$ff,$00,$c0,$fd,$00,$02,$ff,$fc,$00,$f3,$ff,$00,$fe,$fe,$00,$06,$3f,$ff,$ff
	dc.b	$fe,$7f,$ff,$f8,$fd,$00,$00,$03,$fb,$ff,$00,$c0,$fd,$00,$02,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe,$00,$06,$3f,$ff,$ff,$fe,$7f,$ff,$f8
	dc.b	$fd,$00,$00,$03,$fb,$ff,$00,$c0,$fd,$00,$02,$ff,$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80,$00,$06,$ea,$00
	dc.b	$f7,$ff,$00,$fe,$fe,$00,$00,$3f,$fe,$ff,$02,$80,$00,$06,$fd,$00,$00,$03,$f9,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe
	dc.b	$00,$00,$3f,$fe,$ff,$02,$80,$00,$06,$fd,$00,$00,$03,$f9,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f3,$ff,$00,$fe,$fe,$00,$06,$3f,$ff,$ff
	dc.b	$fe,$7f,$ff,$f8,$fd,$00,$00,$03,$f9,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe,$00,$06,$3f,$ff,$ff,$fe,$7f,$ff,$f8,$fd
	dc.b	$00,$00,$03,$f9,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80,$00,$06,$ea,$00,$f7,$ff
	dc.b	$00,$fe,$fe,$00,$00,$3f,$fe,$ff,$05,$80,$00,$06,$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe,$00,$00,$3f
	dc.b	$fe,$ff,$05,$80,$00,$06,$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f3,$ff,$00,$fe,$fe,$00,$09,$3f,$ff,$ff,$fe,$7f,$ff,$f8
	dc.b	$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f7,$ff,$00,$fe,$fe,$00,$09,$3f,$ff,$ff,$fe,$7f,$ff,$f8,$00,$00,$0f,$f7,$ff,$05
	dc.b	$f8,$00,$00,$ff,$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80,$00,$06,$ea,$00,$ef,$ff,$05,$80,$00,$06,$00,$00
	dc.b	$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$ef,$ff,$05,$80,$00,$06,$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$ec,$ff,$06,$fe
	dc.b	$7f,$ff,$f8,$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f0,$ff,$06,$fe,$7f,$ff,$f8,$00,$00,$0f,$f7,$ff,$05,$f8,$00,$00,$ff
	dc.b	$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80,$00,$06,$ea,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00
	dc.b	$ff,$fc,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$ec,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff
	dc.b	$fc,$00,$f0,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80
	dc.b	$00,$06,$ea,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00,$ff
	dc.b	$fc,$00,$ec,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$f0,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff
	dc.b	$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80,$00,$06,$ea,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00
	dc.b	$ff,$fc,$00,$ef,$ff,$02,$80,$00,$07,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$ec,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff
	dc.b	$fc,$00,$f0,$ff,$03,$fe,$7f,$ff,$f9,$f4,$ff,$05,$f8,$00,$00,$ff,$fc,$00,$fd,$ff,$f0,$00,$03,$01,$80,$00,$06,$dd,$00,$03,$01,$80
	dc.b	$00,$06,$ea,$00,$9c,$ff,$03,$fe,$00,$00,$01,$dd,$ff,$03,$fe,$00,$00,$01,$ea,$ff,$f0,$00,$03,$01,$ff,$ff,$fe,$dd,$00,$03,$01,$ff
	dc.b	$ff,$fe,$ea,$00,$9c,$ff,$03,$fe,$00,$00,$01,$dd,$ff,$03,$fe,$00,$00,$01,$ea,$ff,$f0,$00,$03,$01,$ff,$ff,$fe,$dd,$00,$03,$01,$ff
	dc.b	$ff,$fe,$ea,$00,$9c,$ff,$03,$fe,$00,$00,$01,$dd,$ff,$03,$fe,$00,$00,$01,$ea,$ff,$f0,$00,$03,$01,$ff,$ff,$fe,$dd,$00,$03,$01,$ff
	dc.b	$ff,$fe,$ea,$00,$9b,$ff,$01,$fc,$00,$db,$ff,$01,$fc,$00,$e9,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$e9,$00,$9b,$ff,$01,$fc
	dc.b	$00,$db,$ff,$01,$fc,$00,$e9,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$e9,$00,$9b,$ff,$01,$fc,$00,$db,$ff,$01,$fc,$00,$e9,$ff
	dc.b	$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03
	dc.b	$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db
	dc.b	$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01
	dc.b	$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff
	dc.b	$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03
	dc.b	$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db
	dc.b	$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01
	dc.b	$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff
	dc.b	$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03
	dc.b	$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db
	dc.b	$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01
	dc.b	$03,$ff,$d7,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$83,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d7,$00,$01,$03,$ff,$f2,$00,$00,$08,$eb
	dc.b	$00,$01,$03,$ff,$f2,$00,$00,$08,$93,$00,$01,$03,$ff,$f2,$00,$00,$08,$eb,$00,$01,$03,$ff,$f2,$00,$00,$08,$e7,$00,$01,$03,$ff,$f3
	dc.b	$00,$02,$0f,$ff,$f8,$ec,$00,$01,$03,$ff,$f3,$00,$02,$0f,$ff,$f8,$94,$00,$01,$03,$ff,$f3,$00,$02,$0f,$ff,$f8,$ec,$00,$01,$03,$ff
	dc.b	$f3,$00,$02,$0f,$ff,$f8,$e8,$00,$01,$03,$ff,$f3,$00,$fe,$ff,$00,$80,$ed,$00,$01,$03,$ff,$f3,$00,$fe,$ff,$00,$80,$95,$00,$01,$03
	dc.b	$ff,$f3,$00,$fe,$ff,$00,$80,$ed,$00,$01,$03,$ff,$f3,$00,$fe,$ff,$00,$80,$e9,$00,$01,$03,$ff,$f4,$00,$00,$03,$fe,$ff,$00,$e0,$ed
	dc.b	$00,$01,$03,$ff,$f4,$00,$00,$03,$fe,$ff,$00,$e0,$95,$00,$01,$03,$ff,$f4,$00,$00,$03,$fe,$ff,$00,$e0,$ed,$00,$01,$03,$ff,$f4,$00
	dc.b	$00,$03,$fe,$ff,$00,$e0,$e9,$00,$01,$03,$ff,$f4,$00,$00,$0f,$fe,$ff,$00,$f8,$ed,$00,$01,$03,$ff,$f4,$00,$00,$0f,$fe,$ff,$00,$f8
	dc.b	$95,$00,$01,$03,$ff,$f4,$00,$00,$0f,$fe,$ff,$00,$f8,$ed,$00,$01,$03,$ff,$f4,$00,$00,$0f,$fe,$ff,$00,$f8,$e9,$00,$01,$03,$ff,$f4
	dc.b	$00,$00,$3f,$fe,$ff,$00,$fe,$ed,$00,$01,$03,$ff,$f4,$00,$00,$3f,$fe,$ff,$00,$fe,$95,$00,$01,$03,$ff,$f4,$00,$00,$3f,$fe,$ff,$00
	dc.b	$fe,$ed,$00,$01,$03,$ff,$f4,$00,$00,$3f,$fe,$ff,$00,$fe,$e9,$00,$01,$03,$ff,$f4,$00,$fc,$ff,$00,$80,$ee,$00,$01,$03,$ff,$f4,$00
	dc.b	$fc,$ff,$00,$80,$96,$00,$01,$03,$ff,$f4,$00,$fc,$ff,$00,$80,$ee,$00,$01,$03,$ff,$f4,$00,$fc,$ff,$00,$80,$ea,$00,$01,$03,$ff,$f5
	dc.b	$00,$00,$01,$fc,$ff,$00,$c0,$ee,$00,$01,$03,$ff,$f5,$00,$00,$01,$fc,$ff,$00,$c0,$96,$00,$01,$03,$ff,$f5,$00,$00,$01,$fc,$ff,$00
	dc.b	$c0,$ee,$00,$01,$03,$ff,$f5,$00,$00,$01,$fc,$ff,$00,$c0,$ea,$00,$01,$03,$ff,$f5,$00,$00,$07,$fc,$ff,$00,$f0,$ee,$00,$01,$03,$ff
	dc.b	$f5,$00,$00,$07,$fc,$ff,$00,$f0,$96,$00,$01,$03,$ff,$f5,$00,$00,$07,$fc,$ff,$00,$f0,$ee,$00,$01,$03,$ff,$f5,$00,$00,$07,$fc,$ff
	dc.b	$00,$f0,$ea,$00,$01,$03,$ff,$f5,$00,$00,$0f,$fc,$ff,$00,$f8,$ee,$00,$01,$03,$ff,$f5,$00,$00,$0f,$fc,$ff,$00,$f8,$96,$00,$01,$03
	dc.b	$ff,$f5,$00,$00,$0f,$fc,$ff,$00,$f8,$ee,$00,$01,$03,$ff,$f5,$00,$00,$0f,$fc,$ff,$00,$f8,$ea,$00,$01,$03,$ff,$f5,$00,$00,$1f,$fc
	dc.b	$ff,$00,$fc,$ee,$00,$01,$03,$ff,$f5,$00,$00,$1f,$fc,$ff,$00,$fc,$96,$00,$01,$03,$ff,$f5,$00,$00,$1f,$fc,$ff,$00,$fc,$ee,$00,$01
	dc.b	$03,$ff,$f5,$00,$00,$1f,$fc,$ff,$00,$fc,$ea,$00,$01,$03,$ff,$f5,$00,$00,$3f,$fc,$ff,$00,$fe,$ee,$00,$01,$03,$ff,$f5,$00,$00,$3f
	dc.b	$fc,$ff,$00,$fe,$96,$00,$01,$03,$ff,$f5,$00,$00,$3f,$fc,$ff,$00,$fe,$ee,$00,$01,$03,$ff,$f5,$00,$00,$3f,$fc,$ff,$00,$fe,$ea,$00
	dc.b	$01,$03,$ff,$f5,$00,$00,$7f,$fb,$ff,$ee,$00,$01,$03,$ff,$f5,$00,$00,$7f,$fb,$ff,$96,$00,$01,$03,$ff,$f5,$00,$00,$7f,$fb,$ff,$ee
	dc.b	$00,$01,$03,$ff,$f5,$00,$00,$7f,$fb,$ff,$ea,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80,$ef,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80
	dc.b	$97,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80,$ef,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80,$eb,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00
	dc.b	$80,$ef,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80,$97,$00,$01,$03,$ff,$f5,$00,$fa,$ff,$00,$80,$ef,$00,$01,$03,$ff,$f5,$00,$fa,$ff
	dc.b	$00,$80,$eb,$00,$01,$03,$ff,$f6,$00,$00,$01,$fa,$ff,$00,$c0,$ef,$00,$01,$03,$ff,$f6,$00,$00,$01,$fa,$ff,$00,$c0,$97,$00,$01,$03
	dc.b	$ff,$f6,$00,$00,$01,$fa,$ff,$00,$c0,$ef,$00,$01,$03,$ff,$f6,$00,$00,$01,$fa,$ff,$00,$c0,$fd,$00,$00,$03,$f0,$ff,$01,$03,$ff,$f6
	dc.b	$00,$00,$03,$fa,$ff,$01,$e0,$03,$f0,$ff,$01,$03,$ff,$f6,$00,$00,$03,$fa,$ff,$01,$e0,$03,$fe,$ff,$9b,$00,$01,$03,$ff,$f6,$00,$00
	dc.b	$03,$fa,$ff,$00,$e0,$ef,$00,$01,$03,$ff,$f6,$00,$00,$03,$fa,$ff,$00,$e0,$fd,$00,$00,$03,$f0,$ff,$01,$03,$ff,$f6,$00,$00,$03,$fa
	dc.b	$ff,$01,$e0,$03,$f0,$ff,$01,$03,$ff,$f6,$00,$00,$03,$fa,$ff,$01,$e0,$03,$fe,$ff,$9b,$00,$01,$03,$ff,$f6,$00,$00,$03,$fa,$ff,$00
	dc.b	$e0,$ef,$00,$01,$03,$ff,$f6,$00,$00,$03,$fa,$ff,$00,$e0,$fd,$00,$00,$03,$f0,$ff,$01,$03,$ff,$f6,$00,$00,$07,$fa,$ff,$01,$f0,$03
	dc.b	$f0,$ff,$01,$03,$ff,$f6,$00,$00,$07,$fa,$ff,$01,$f0,$03,$fe,$ff,$9b,$00,$01,$03,$ff,$f6,$00,$00,$07,$fa,$ff,$00,$f0,$ef,$00,$01
	dc.b	$03,$ff,$f6,$00,$00,$07,$fa,$ff,$00,$f0,$fd,$00,$00,$03,$f0,$ff,$01,$03,$ff,$f6,$00,$00,$07,$fa,$ff,$01,$f0,$03,$f0,$ff,$01,$03
	dc.b	$ff,$f6,$00,$00,$07,$fa,$ff,$01,$f0,$03,$fe,$ff,$9b,$00,$01,$03,$ff,$f6,$00,$00,$07,$fa,$ff,$00,$f0,$ef,$00,$01,$03,$ff,$f6,$00
	dc.b	$00,$07,$fa,$ff,$00,$f0,$eb,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8,$ef,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8
	dc.b	$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$02,$f8,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff
	dc.b	$04,$f8,$00,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8,$ef,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8
	dc.b	$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$02,$f8,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff
	dc.b	$04,$f8,$00,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8,$ef,$00,$01,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$00,$f8
	dc.b	$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff,$02,$f8,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$0f,$fa,$ff
	dc.b	$04,$f8,$00,$3f,$ff,$ff,$fc,$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc
	dc.b	$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$0f,$0f,$3c,$f3,$cf,$3c
	dc.b	$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00
	dc.b	$16,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$14,$fc
	dc.b	$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$30,$c3,$0c
	dc.b	$fc,$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$02,$3c,$f3,$c0,$fd
	dc.b	$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c
	dc.b	$f3,$cf,$3c,$f3,$cf,$e9,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00,$16,$0f,$3c,$f3,$00,$30
	dc.b	$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$14,$fc,$00,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$30,$c3,$0c,$fc,$00,$02,$3c,$f3,$c0
	dc.b	$fd,$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00,$03
	dc.b	$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9
	dc.b	$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00,$16,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$14,$fc,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$30,$c3,$0c,$fc,$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00
	dc.b	$03,$cf,$00,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$02,$3c,$f3,$c0,$fd,$00,$07,$03,$c0,$00,$03,$cf,$00,$03,$ff,$f6,$00
	dc.b	$00,$1f,$fa,$ff,$00,$fc,$fc,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00,$0f,$0f,$3c,$f3,$cf
	dc.b	$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$e9,$00,$16,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$14,$fc,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$30,$c3,$0c,$ef,$00,$01,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$ef,$00,$01,$03,$ff
	dc.b	$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$02,$fc,$00,$3f,$f2,$ff,$02,$f0
	dc.b	$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$ef,$00,$01,$03,$ff
	dc.b	$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$02,$fc,$00,$3f,$f2,$ff,$02,$f0
	dc.b	$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$ef,$00,$01,$03,$ff
	dc.b	$f6,$00,$00,$1f,$fa,$ff,$00,$fc,$a8,$00,$00,$3f,$f2,$ff,$02,$f0,$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$02,$fc,$00,$3f,$f2,$ff,$02,$f0
	dc.b	$03,$ff,$f6,$00,$00,$1f,$fa,$ff,$04,$fc,$00,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$fe,$00,$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$ea,$00,$06
	dc.b	$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$ea,$00,$11,$03,$00,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3
	dc.b	$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$18,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$14,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$fe,$00,$02,$30,$c3,$0c,$fe,$00,$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$ea,$00,$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9
	dc.b	$00,$01,$03,$ff,$ea,$00,$11,$03,$00,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00
	dc.b	$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$18,$0f
	dc.b	$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$14,$30
	dc.b	$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$30,$c3,$0c,$fe,$00
	dc.b	$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03,$c0,$f8,$00,$06,$03,$c0,$3c,$f3
	dc.b	$c0,$00,$f0,$f9,$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03,$c0,$f8,$00,$11,$03,$00,$0f,$3c,$f3,$cf,$3c,$f3,$cf
	dc.b	$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3
	dc.b	$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$fe,$00,$02,$30,$c3,$0c,$fe,$00,$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03
	dc.b	$c0,$f8,$00,$06,$03,$c0,$3c,$f3,$c0,$00,$f0,$f9,$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03,$c0,$f8,$00,$11,$03
	dc.b	$00,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf
	dc.b	$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$fe,$00,$24,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c
	dc.b	$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$02,$30,$c3,$0c,$ef,$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03,$c0,$e9
	dc.b	$00,$01,$03,$ff,$fc,$00,$08,$3c,$03,$c0,$00,$00,$0f,$00,$03,$c0,$e2,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$fa,$00,$00,$3f,$f2,$ff,$14,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$00,$3f
	dc.b	$f2,$ff,$14,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00
	dc.b	$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$04,$3f,$ff,$ff,$00,$0f
	dc.b	$fd,$00,$00,$f0,$f6,$00,$01,$03,$ff,$ec,$00,$00,$0f,$fd,$00,$00,$f0,$f6,$00,$01,$03,$ff,$ec,$00,$00,$0f,$fe,$00,$0f,$0f,$3c,$f3
	dc.b	$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c
	dc.b	$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$18,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c
	dc.b	$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$14,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$04,$30,$c3,$0c,$00,$0f,$fd,$00,$00,$f0,$f6,$00,$0f,$03,$ff,$00,$00,$3c
	dc.b	$00,$0f,$3c,$00,$0f,$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fd,$00,$00,$f0,$f6,$00,$0f,$03,$ff,$00,$00,$3c,$00,$0f,$3c,$00,$0f
	dc.b	$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00
	dc.b	$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$04,$30,$c3,$0c,$00,$0f,$fd,$00,$00,$f0
	dc.b	$f6,$00,$0f,$03,$ff,$00,$00,$3c,$00,$0f,$3c,$00,$0f,$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fd,$00,$00,$f0,$f6,$00,$0f,$03,$ff
	dc.b	$00,$00,$3c,$00,$0f,$3c,$00,$0f,$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c
	dc.b	$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf
	dc.b	$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c
	dc.b	$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$04,$30
	dc.b	$c3,$0c,$00,$0f,$fd,$00,$00,$f0,$f6,$00,$0f,$03,$ff,$00,$00,$3c,$00,$0f,$3c,$00,$0f,$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fd
	dc.b	$00,$00,$f0,$f6,$00,$0f,$03,$ff,$00,$00,$3c,$00,$0f,$3c,$00,$0f,$00,$00,$0f,$00,$03,$c0,$fa,$00,$00,$0f,$fe,$00,$0f,$0f,$3c,$f3
	dc.b	$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c
	dc.b	$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c
	dc.b	$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30
	dc.b	$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$fe,$00,$02,$30,$c3,$0c,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0,$ea,$00,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f
	dc.b	$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$fc,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0
	dc.b	$fd,$00,$01,$f3,$cf,$fc,$00,$00,$0f,$f9,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0,$fd
	dc.b	$00,$01,$f3,$cf,$fc,$00,$00,$0f,$f9,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2
	dc.b	$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00
	dc.b	$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff
	dc.b	$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$02,$30,$c3,$0c,$fc,$00,$08,$3c,$00,$0f,$00,$03
	dc.b	$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0,$fd,$00,$01,$f3,$cf,$fc,$00,$00,$0f,$f9,$00,$08,$3c,$00,$0f,$00,$03,$cf
	dc.b	$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0,$fd,$00,$01,$f3,$cf,$fc,$00,$00,$0f,$f9,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf
	dc.b	$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3
	dc.b	$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$fe,$00,$02,$30,$c3,$0c,$fc,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0,$fd,$00,$01,$f3
	dc.b	$cf,$fc,$00,$00,$0f,$f9,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$fe,$00,$01,$03,$c0,$fd,$00,$01,$f3,$cf
	dc.b	$fc,$00,$00,$0f,$f9,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe
	dc.b	$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$28,$0f,$3c,$f3
	dc.b	$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3
	dc.b	$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$24,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$03,$ff,$00,$30,$c3,$0c
	dc.b	$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0,$fe,$00,$02,$30,$c3,$0c,$fc,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0
	dc.b	$fd,$00,$01,$03,$ff,$e8,$00,$08,$3c,$00,$0f,$00,$03,$cf,$3c,$03,$c0,$fd,$00,$01,$03,$ff,$e8,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf
	dc.b	$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$0f,$0f,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3,$cf,$3c,$f3
	dc.b	$cf,$3c,$f3,$cf,$fd,$00,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$18,$0f,$3c,$f3,$00,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30
	dc.b	$c3,$0c,$30,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$14,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$c3,$0c,$30,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$30,$c3,$0c,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$02,$3f,$ff,$ff,$ef,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$d4,$00,$00,$3f,$f2,$ff,$00,$f0
	dc.b	$ea,$00,$00,$3f,$f2,$ff,$00,$f0,$fa,$00,$00,$3f,$f2,$ff,$04,$f0,$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$04,$f0
	dc.b	$03,$ff,$00,$3f,$f2,$ff,$00,$f0,$fe,$00,$00,$3f,$81,$ff,$81,$ff,$af,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fe,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$aa,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fe,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9,$fd,$ff,$00,$f9
	dc.b	$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$92,$ff,$53,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f
	dc.b	$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3
	dc.b	$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff
	dc.b	$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ad,$ff,$53,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff
	dc.b	$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf
	dc.b	$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc,$ff,$3f,$cf,$f3,$fc
	dc.b	$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$9d,$ff,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a1,$00,$80
	even
bg_harbor	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c1,$00,$00,$02,$da,$00,$00,$02,$81,$00
	dc.b	$a3,$00,$00,$10,$da,$00,$00,$10,$81,$00,$ba,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b4,$00,$00,$08
	dc.b	$da,$00,$00,$08,$81,$00,$81,$00,$81,$00,$b1,$00,$00,$04,$da,$00,$00,$04,$81,$00,$c4,$00,$00,$04,$da,$00,$00,$04,$c0,$00,$01,$01
	dc.b	$c0,$db,$00,$01,$01,$c0,$81,$00,$af,$00,$01,$07,$c0,$db,$00,$01,$07,$c0,$81,$00,$af,$00,$01,$1f,$80,$db,$00,$01,$1f,$80,$8e,$00
	dc.b	$00,$20,$da,$00,$00,$20,$cb,$00,$00,$3f,$da,$00,$00,$3f,$81,$00,$ae,$00,$00,$7f,$da,$00,$00,$7f,$9a,$00,$00,$20,$da,$00,$00,$20
	dc.b	$da,$00,$00,$20,$e6,$00,$00,$fe,$da,$00,$00,$fe,$81,$00,$ae,$00,$00,$fe,$da,$00,$00,$fe,$81,$00,$af,$00,$01,$01,$fe,$db,$00,$01
	dc.b	$01,$fe,$81,$00,$af,$00,$01,$01,$fe,$db,$00,$01,$01,$fe,$8f,$00,$00,$01,$ec,$00,$00,$80,$f0,$00,$00,$01,$ec,$00,$00,$80,$e0,$00
	dc.b	$01,$03,$fe,$db,$00,$01,$03,$fe,$9a,$00,$00,$08,$da,$00,$00,$08,$da,$00,$00,$08,$e7,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$81,$00
	dc.b	$af,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$81,$00,$af,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$8a,$00,$00,$10,$da,$00,$00,$10,$cf,$00
	dc.b	$01,$03,$fe,$db,$00,$01,$03,$fe,$81,$00,$af,$00,$01,$07,$ff,$db,$00,$01,$07,$ff,$81,$00,$af,$00,$01,$03,$ff,$db,$00,$01,$03,$ff
	dc.b	$9c,$00,$00,$02,$e0,$00,$00,$02,$fc,$00,$00,$02,$e0,$00,$00,$02,$fc,$00,$00,$02,$e5,$00,$02,$03,$ff,$80,$dc,$00,$02,$03,$ff,$80
	dc.b	$81,$00,$f8,$00,$00,$80,$da,$00,$00,$80,$e2,$00,$02,$03,$ff,$c0,$dc,$00,$02,$03,$ff,$c0,$9a,$00,$00,$40,$da,$00,$00,$40,$da,$00
	dc.b	$00,$40,$e8,$00,$02,$03,$ff,$c0,$dc,$00,$02,$03,$ff,$c0,$81,$00,$b0,$00,$02,$03,$ff,$f0,$dc,$00,$02,$03,$ff,$f0,$81,$00,$b0,$00
	dc.b	$02,$01,$ff,$f8,$dc,$00,$02,$01,$ff,$f8,$81,$00,$f8,$00,$00,$02,$da,$00,$00,$02,$e2,$00,$04,$01,$ff,$fe,$00,$c0,$de,$00,$04,$01
	dc.b	$ff,$fe,$00,$c0,$81,$00,$b1,$00,$fe,$ff,$00,$80,$dd,$00,$fe,$ff,$00,$80,$81,$00,$b1,$00,$fe,$ff,$00,$80,$dd,$00,$fe,$ff,$00,$80
	dc.b	$81,$00,$b1,$00,$02,$7f,$ff,$ff,$dc,$00,$02,$7f,$ff,$ff,$81,$00,$f9,$00,$00,$20,$da,$00,$00,$20,$e1,$00,$02,$3f,$ff,$fe,$dc,$00
	dc.b	$02,$3f,$ff,$fe,$81,$00,$f8,$00,$00,$01,$da,$00,$00,$01,$e2,$00,$02,$1f,$ff,$fc,$dc,$00,$02,$1f,$ff,$fc,$81,$00,$b0,$00,$02,$07
	dc.b	$ff,$f0,$dc,$00,$02,$07,$ff,$f0,$9d,$00,$00,$08,$da,$00,$00,$08,$da,$00,$00,$08,$e5,$00,$02,$01,$ff,$c0,$dc,$00,$02,$01,$ff,$c0
	dc.b	$81,$00,$af,$00,$00,$08,$da,$00,$00,$08,$97,$00,$00,$80,$da,$00,$00,$80,$81,$00,$8e,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00
	dc.b	$81,$00,$c8,$00,$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$b3,$00,$00,$20,$da,$00,$00,$20,$81,$00,$af,$00,$00,$01,$da,$00
	dc.b	$00,$01,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c3,$00,$00,$20,$da,$00,$00,$20,$da,$00,$00,$20,$81,$00,$d1,$00,$00,$04,$da,$00
	dc.b	$00,$04,$81,$00,$9f,$00,$00,$04,$da,$00,$00,$04,$81,$00,$c1,$00,$00,$40,$e8,$00,$00,$10,$f4,$00,$00,$40,$e8,$00,$00,$10,$f4,$00
	dc.b	$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$dc,$00,$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$91,$00,$00,$02,$da,$00
	dc.b	$00,$02,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$e6,$00,$00,$40,$da,$00,$00,$40
	dc.b	$da,$00,$00,$40,$81,$00,$b0,$00,$00,$02,$da,$00,$00,$02,$81,$00,$cd,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$a7,$00
	dc.b	$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b3,$00,$00,$40,$f1,$00,$00,$40,$eb,$00,$00,$40,$f1,$00,$00,$40
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c9,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$c4,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$ab,$00,$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$ab,$00,$00,$40
	dc.b	$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$ba,$00,$00,$80,$da,$00,$00,$80,$d6,$00,$00,$80,$da,$00
	dc.b	$00,$80,$82,$00,$00,$80,$f7,$00,$00,$01,$e5,$00,$00,$80,$f7,$00,$00,$01,$e1,$00,$00,$80,$da,$00,$00,$80,$82,$00,$00,$80,$f6,$00
	dc.b	$00,$10,$e6,$00,$00,$80,$f6,$00,$00,$10,$e2,$00,$00,$80,$da,$00,$00,$80,$82,$00,$00,$80,$da,$00,$00,$80,$d6,$00,$00,$80,$da,$00
	dc.b	$00,$80,$8d,$00,$00,$01,$f8,$00,$01,$3f,$fe,$f5,$00,$00,$10,$f2,$00,$00,$01,$f8,$00,$01,$3f,$fe,$f5,$00,$00,$10,$e4,$00,$01,$3f
	dc.b	$fe,$db,$00,$01,$3f,$fe,$91,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$e9,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$e5,$00,$01,$1f,$ff,$f5
	dc.b	$00,$01,$3f,$fe,$e9,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$97,$00,$00,$02,$fc,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$fd,$00,$00,$01
	dc.b	$f4,$00,$00,$02,$fc,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$fd,$00,$00,$01,$f4,$00,$00,$02,$f8,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe
	dc.b	$e9,$00,$01,$1f,$ff,$f5,$00,$01,$3f,$fe,$94,$00,$04,$80,$00,$00,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$ee,$00,$04,$80,$00,$00,$1f
	dc.b	$ff,$f5,$00,$03,$3f,$fe,$00,$80,$e7,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80
	dc.b	$93,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$e7,$00,$01,$1f,$ff,$f5,$00,$03
	dc.b	$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$93,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f
	dc.b	$ff,$f5,$00,$03,$3f,$fe,$00,$80,$e7,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80
	dc.b	$93,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$e7,$00,$01,$1f,$ff,$f5,$00,$03
	dc.b	$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$f5,$00,$03,$3f,$fe,$00,$80,$9a,$00,$02,$10,$00,$08,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc
	dc.b	$fa,$00,$03,$3f,$fe,$00,$80,$f2,$00,$02,$10,$00,$08,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$03,$3f,$fe,$00,$80,$f2,$00
	dc.b	$00,$10,$f7,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$03,$3f,$fe,$00,$80,$eb,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$03
	dc.b	$3f,$fe,$00,$80,$98,$00,$00,$20,$fd,$00,$06,$1f,$ff,$00,$02,$00,$1f,$fc,$fa,$00,$03,$3f,$fe,$00,$80,$fa,$00,$00,$01,$f8,$00,$00
	dc.b	$20,$fd,$00,$06,$1f,$ff,$00,$02,$00,$1f,$fc,$fa,$00,$03,$3f,$fe,$00,$80,$fa,$00,$00,$01,$f4,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe
	dc.b	$00,$01,$1f,$fc,$fa,$00,$03,$3f,$fe,$00,$80,$fa,$00,$00,$01,$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$03
	dc.b	$3f,$fe,$00,$80,$fa,$00,$00,$01,$a0,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$00,$3f,$fe,$ff,$00,$80,$fb,$00
	dc.b	$00,$01,$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$00,$3f,$fe,$ff,$00,$80,$fb,$00,$00,$01,$f4,$00,$00,$20
	dc.b	$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fa,$00,$00,$3f,$fe,$ff,$00,$80,$fb,$00,$00,$01,$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe
	dc.b	$00,$01,$1f,$fc,$fa,$00,$00,$3f,$fe,$ff,$00,$80,$fb,$00,$00,$01,$a0,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00
	dc.b	$fc,$ff,$00,$80,$fb,$00,$00,$01,$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01
	dc.b	$f4,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$f8,$00,$00,$20,$fd,$00,$01,$1f
	dc.b	$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$a0,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00
	dc.b	$fc,$ff,$00,$80,$fb,$00,$00,$01,$fe,$00,$00,$40,$fc,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80
	dc.b	$fb,$00,$00,$01,$fe,$00,$00,$40,$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01
	dc.b	$f8,$00,$00,$20,$fd,$00,$01,$1f,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$a3,$00,$04,$3f,$f8,$00,$20,$00
	dc.b	$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc
	dc.b	$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$08,$3f,$f8,$00,$00,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc
	dc.b	$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01
	dc.b	$fb,$00,$01,$3f,$f8,$ac,$00,$05,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fc
	dc.b	$00,$05,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fc,$00,$09,$04,$3f,$f8,$00
	dc.b	$00,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$04,$3f,$f8,$00,$20,$00,$fc
	dc.b	$ff,$fe,$00,$01,$1f,$fc,$fb,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$01,$3f,$f8,$ab,$00,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe
	dc.b	$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe
	dc.b	$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$08,$3f,$f8,$00,$00,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc
	dc.b	$ff,$00,$80,$fb,$00,$00,$01,$fb,$00,$04,$3f,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00
	dc.b	$01,$fb,$00,$01,$3f,$f8,$ac,$00,$05,$ff,$ff,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00
	dc.b	$01,$fc,$00,$05,$ff,$ff,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fc,$00,$09,$ff
	dc.b	$ff,$f8,$00,$ff,$ff,$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fc,$00,$05,$ff,$ff
	dc.b	$f8,$00,$20,$00,$fc,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$00,$80,$fb,$00,$00,$01,$fc,$00,$02,$ff,$ff,$f8,$ac,$00,$f6,$ff
	dc.b	$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$03,$80,$00,$00,$0f,$f9,$ff,$00,$e0,$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$03
	dc.b	$80,$00,$00,$0f,$f9,$ff,$00,$e0,$f2,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$03,$80,$00,$00,$0f,$f9,$ff,$00,$e0,$f6,$ff,$fe
	dc.b	$00,$00,$1f,$fd,$ff,$fe,$00,$fc,$ff,$03,$80,$00,$00,$0f,$f9,$ff,$00,$e0,$fd,$ff,$ad,$00,$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00
	dc.b	$f0,$ff,$00,$e0,$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0,$f2,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0
	dc.b	$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0,$fd,$ff,$ad,$00,$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0
	dc.b	$f6,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0,$f2,$ff,$fe,$00,$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0,$f6,$ff,$fe,$00
	dc.b	$00,$1f,$fd,$ff,$fe,$00,$f0,$ff,$00,$e0,$fd,$ff,$ad,$00,$ee,$ff,$fe,$00,$f0,$ff,$00,$f0,$ee,$ff,$fe,$00,$f0,$ff,$00,$f0,$ea,$ff
	dc.b	$fe,$00,$f0,$ff,$00,$e0,$ee,$ff,$fe,$00,$f0,$ff,$00,$e0,$fd,$ff,$ad,$00,$ee,$ff,$fe,$00,$f0,$ff,$00,$e0,$ee,$ff,$fe,$00,$f0,$ff
	dc.b	$00,$e0,$ea,$ff,$fe,$00,$f0,$ff,$00,$e0,$ee,$ff,$fe,$00,$f0,$ff,$00,$e0,$fd,$ff,$ad,$00,$ee,$ff,$fe,$00,$f0,$ff,$00,$e0,$ee,$ff
	dc.b	$fe,$00,$f0,$ff,$00,$e0,$ea,$ff,$fe,$00,$f0,$ff,$00,$e0,$ee,$ff,$fe,$00,$f0,$ff,$00,$e0,$fd,$ff,$ad,$00,$da,$ff,$00,$e0,$da,$ff
	dc.b	$00,$e0,$d6,$ff,$00,$e0,$da,$ff,$00,$e0,$fd,$ff,$ad,$00,$da,$ff,$00,$e0,$da,$ff,$00,$e0,$d6,$ff,$00,$e0,$da,$ff,$00,$e0,$fd,$ff
	dc.b	$ad,$00,$da,$ff,$00,$e0,$da,$ff,$00,$e0,$d6,$ff,$00,$e0,$da,$ff,$00,$e0,$fd,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff
	dc.b	$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$ac,$ff,$fd,$00,$00,$3f
	dc.b	$fd,$ff,$00,$c0,$fe,$00,$00,$0f,$fe,$ff,$00,$c0,$fe,$00,$00,$0f,$fd,$ff,$00,$f0,$fe,$00,$00,$03,$f8,$ff,$fd,$00,$00,$3f,$fd,$ff
	dc.b	$00,$c0,$fe,$00,$00,$0f,$fe,$ff,$00,$c0,$fe,$00,$00,$0f,$fd,$ff,$00,$f0,$fe,$00,$00,$03,$f8,$ff,$fd,$00,$fd,$ff,$00,$c0,$fd,$00
	dc.b	$00,$3f,$fe,$ff,$00,$f0,$fe,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$fc,$f8,$00,$fd,$ff,$00,$c0,$fd,$00,$00,$3f
	dc.b	$fe,$ff,$00,$f0,$fe,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$fc,$f8,$00,$a9,$ff,$fd,$00,$00,$3f,$fd,$ff,$00,$c0
	dc.b	$fe,$00,$00,$0f,$fe,$ff,$00,$c0,$fe,$00,$00,$0f,$fd,$ff,$00,$f0,$fe,$00,$00,$03,$f8,$ff,$fd,$00,$00,$3f,$fd,$ff,$00,$c0,$fe,$00
	dc.b	$00,$0f,$fe,$ff,$00,$c0,$fe,$00,$00,$0f,$fd,$ff,$00,$f0,$fe,$00,$00,$03,$f8,$ff,$fd,$00,$fd,$ff,$00,$c0,$fd,$00,$00,$3f,$fe,$ff
	dc.b	$00,$f0,$fe,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$fc,$f8,$00,$fd,$ff,$00,$c0,$fd,$00,$00,$3f,$fe,$ff,$00,$f0
	dc.b	$fe,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$fc,$f8,$00,$a9,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff
	dc.b	$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03
	dc.b	$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc
	dc.b	$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f
	dc.b	$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd
	dc.b	$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df
	dc.b	$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7
	dc.b	$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff
	dc.b	$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff
	dc.b	$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02
	dc.b	$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3
	dc.b	$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc
	dc.b	$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7
	dc.b	$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff
	dc.b	$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff
	dc.b	$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03
	dc.b	$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$ac,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc
	dc.b	$fb,$ff,$03,$fd,$ff,$ff,$3f,$f7,$ff,$02,$df,$ff,$f3,$fb,$ff,$02,$f7,$ff,$fc,$fc,$ff,$02,$f7,$ff,$fc,$fb,$ff,$03,$fd,$ff,$ff,$3f
	dc.b	$f7,$ff,$02,$df,$ff,$f3,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00
	dc.b	$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c
	dc.b	$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0
	dc.b	$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00
	dc.b	$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c,$00,$20
	dc.b	$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02,$08,$00
	dc.b	$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03
	dc.b	$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08
	dc.b	$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00
	dc.b	$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08
	dc.b	$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00
	dc.b	$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03
	dc.b	$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02
	dc.b	$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20
	dc.b	$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$04,$0c,$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02
	dc.b	$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c
	dc.b	$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$04,$0c
	dc.b	$00,$20,$00,$0c,$fb,$00,$02,$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$fb,$00,$02
	dc.b	$08,$00,$03,$fc,$00,$02,$08,$00,$03,$fb,$00,$03,$02,$00,$00,$c0,$f7,$00,$02,$20,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$aa,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$aa,$00
	dc.b	$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00
	dc.b	$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00
	dc.b	$00,$c0,$f5,$00,$00,$0c,$aa,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$f8,$00,$00,$c0,$f5,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$eb,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$eb,$00,$00,$0c,$e7,$00,$00,$01,$fb,$ff,$00,$80,$e1,$00,$00,$01,$fb,$ff,$00,$80,$f4,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00
	dc.b	$00,$03,$fc,$00,$00,$01,$fb,$ff,$00,$80,$f8,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$fc,$00,$00,$01,$fb,$ff,$00,$80,$f8,$00
	dc.b	$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$eb,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$eb,$00,$00,$0c,$e7,$00
	dc.b	$00,$01,$fb,$ff,$00,$80,$e1,$00,$00,$01,$fb,$ff,$00,$80,$f4,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$fc,$00,$00,$01,$fb,$ff
	dc.b	$00,$80,$f8,$00,$00,$0c,$f9,$00,$00,$03,$fa,$00,$00,$03,$fc,$00,$00,$01,$fb,$ff,$00,$80,$f8,$00,$00,$0c,$fe,$00,$00,$0c,$f9,$00
	dc.b	$00,$03,$e3,$00,$00,$0c,$f9,$00,$00,$03,$e3,$00,$02,$0c,$ff,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$fc,$ff,$00,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$00,$ff,$f8,$00,$0c
	dc.b	$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$f9,$00,$00,$03,$fd
	dc.b	$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$fe,$00,$00,$0c,$f9,$00,$00,$03,$f2,$00
	dc.b	$01,$60,$00,$fe,$60,$f7,$00,$00,$0c,$f9,$00,$00,$03,$f2,$00,$01,$60,$00,$fe,$60,$f7,$00,$02,$0c,$ff,$f8,$f2,$00,$00,$01,$fc,$ff
	dc.b	$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$00,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00
	dc.b	$fc,$ff,$06,$f8,$00,$00,$ff,$f8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fc
	dc.b	$ff,$02,$f8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c
	dc.b	$fe,$00,$00,$0c,$f9,$00,$00,$03,$f2,$00,$01,$60,$00,$fe,$60,$f7,$00,$00,$0c,$f9,$00,$00,$03,$f2,$00,$01,$60,$00,$fe,$60,$f7,$00
	dc.b	$02,$0c,$ff,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$00,$f8,$f2,$00,$00,$01,$fc,$ff,$03
	dc.b	$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$00,$ff,$f8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$ff,$03,$f8
	dc.b	$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f
	dc.b	$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$0c,$30,$30,$00,$0c,$f9,$00,$00,$03,$fc,$00,$04,$60,$60,$00,$00,$60,$f3,$00,$06,$30,$30,$00
	dc.b	$30,$30,$00,$0c,$f9,$00,$00,$03,$fc,$00,$04,$60,$60,$00,$00,$60,$f3,$00,$08,$30,$30,$00,$30,$30,$00,$0c,$ff,$f8,$f2,$00,$00,$01
	dc.b	$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$00,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80
	dc.b	$00,$00,$fc,$ff,$06,$f8,$00,$00,$cf,$c8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$fc,$cf,$02,$c8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$cf,$06,$c8
	dc.b	$00,$0c,$30,$30,$00,$0c,$f9,$00,$00,$03,$fc,$00,$04,$60,$60,$00,$00,$60,$f3,$00,$06,$30,$30,$00,$30,$30,$00,$0c,$f9,$00,$00,$03
	dc.b	$fc,$00,$04,$60,$60,$00,$00,$60,$f3,$00,$08,$30,$30,$00,$30,$30,$00,$0c,$ff,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb
	dc.b	$ff,$02,$80,$00,$00,$fc,$ff,$00,$f8,$f2,$00,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$00
	dc.b	$cf,$c8,$00,$0c,$f9,$00,$00,$03,$fd,$00,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$cf,$02,$c8,$00,$0c,$f9
	dc.b	$00,$00,$03,$fd,$00,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$cf,$02,$c8,$00,$0c,$fe,$00,$00,$0c,$da,$00
	dc.b	$00,$0c,$da,$00,$02,$0c,$ff,$f8,$fa,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc
	dc.b	$ff,$00,$f8,$fa,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$00
	dc.b	$ff,$f8,$00,$0c,$fc,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00
	dc.b	$0c,$fc,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$fe,$00
	dc.b	$00,$0c,$e9,$00,$04,$60,$60,$00,$00,$60,$f7,$00,$00,$0c,$e9,$00,$04,$60,$60,$00,$00,$60,$f7,$00,$02,$0c,$ff,$f8,$fa,$00,$00,$03
	dc.b	$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$00,$f8,$fa,$00,$00,$03,$fc,$ff,$02,$fe,$00
	dc.b	$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fc,$ff,$06,$f8,$00,$00,$ff,$f8,$00,$0c,$fc,$00,$00,$03,$fc,$ff,$02,$fe
	dc.b	$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$fc,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc
	dc.b	$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fc,$ff,$02,$f8,$00,$0c,$e5,$00,$04,$60,$60,$00,$00,$60,$de,$00,$04,$60,$60,$00
	dc.b	$00,$60,$f6,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02
	dc.b	$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe
	dc.b	$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00
	dc.b	$00,$01,$fb,$9f,$02,$80,$00,$00,$f9,$ff,$01,$00,$30,$f9,$00,$fd,$c0,$01,$00,$c0,$fd,$00,$fe,$60,$f4,$00,$05,$30,$30,$00,$30,$00
	dc.b	$30,$f9,$00,$fd,$c0,$01,$00,$c0,$fd,$00,$fe,$60,$f4,$00,$07,$30,$30,$00,$30,$00,$30,$00,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02
	dc.b	$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8
	dc.b	$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00
	dc.b	$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80
	dc.b	$00,$00,$fb,$cf,$03,$ff,$ff,$00,$30,$f9,$00,$fd,$c0,$01,$00,$c0,$fd,$00,$fe,$60,$f4,$00,$05,$30,$30,$00,$30,$00,$30,$f9,$00,$fd
	dc.b	$c0,$01,$00,$c0,$fd,$00,$fe,$60,$f4,$00,$07,$30,$30,$00,$30,$00,$30,$00,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc
	dc.b	$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb
	dc.b	$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02
	dc.b	$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf
	dc.b	$05,$ff,$ff,$00,$00,$30,$00,$fe,$30,$de,$00,$01,$30,$00,$fe,$30,$de,$00,$01,$30,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00
	dc.b	$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00
	dc.b	$01,$fb,$ff,$02,$80,$00,$00,$f7,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80
	dc.b	$00,$00,$fb,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$ff,$05
	dc.b	$cf,$cf,$00,$00,$30,$00,$fe,$30,$ec,$00,$04,$60,$60,$00,$60,$60,$f8,$00,$01,$30,$00,$fe,$30,$ec,$00,$04,$60,$60,$00,$60,$60,$f8
	dc.b	$00,$01,$30,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02
	dc.b	$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f7,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff
	dc.b	$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fb,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc
	dc.b	$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fb,$ff,$01,$cf,$cf,$e5,$00,$04,$60,$60,$00,$60,$60,$de,$00,$04,$60,$60,$00,$60
	dc.b	$60,$f6,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00
	dc.b	$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00
	dc.b	$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00
	dc.b	$01,$fb,$9f,$02,$80,$00,$00,$f9,$ff,$01,$30,$30,$f9,$00,$02,$c0,$c0,$00,$fe,$c0,$01,$00,$00,$fb,$60,$f5,$00,$fb,$30,$f9,$00,$02
	dc.b	$c0,$c0,$00,$fe,$c0,$01,$00,$00,$fb,$60,$f5,$00,$fb,$30,$01,$00,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03
	dc.b	$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02
	dc.b	$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$03,$ff
	dc.b	$ff,$30,$30,$f9,$00,$02,$c0,$c0,$00,$fe,$c0,$01,$00,$00,$fb,$60,$f5,$00,$fb,$30,$f9,$00,$02,$c0,$c0,$00,$fe,$c0,$01,$00,$00,$fb
	dc.b	$60,$f5,$00,$fb,$30,$01,$00,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc
	dc.b	$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03
	dc.b	$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$07,$ff,$ff,$00,$00,$30,$30,$00,$30,$dd,$00
	dc.b	$03,$30,$30,$00,$30,$dd,$00,$01,$30,$30,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02
	dc.b	$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f7,$ff,$fc,$cf
	dc.b	$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$ff,$fc,$cf,$02,$00,$00,$03,$fc
	dc.b	$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$ff,$07,$cf,$cf,$00,$00,$30,$30,$00,$30,$eb,$00,$00
	dc.b	$60,$f4,$00,$03,$30,$30,$00,$30,$eb,$00,$00,$60,$f4,$00,$01,$30,$30,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03
	dc.b	$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02
	dc.b	$80,$00,$00,$f7,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fb,$ff
	dc.b	$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fb,$ff,$01,$cf,$cf,$e5,$00
	dc.b	$00,$60,$da,$00,$00,$60,$f2,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03
	dc.b	$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc
	dc.b	$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$f9,$ff,$00,$30,$f6,$00,$fd,$c0,$05,$00,$00,$60,$00,$00,$60,$f2,$00,$fd,$30,$f6
	dc.b	$00,$fd,$c0,$05,$00,$00,$60,$00,$00,$60,$f2,$00,$fd,$30,$fe,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8
	dc.b	$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80
	dc.b	$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00
	dc.b	$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$02,$ff,$ff
	dc.b	$30,$f6,$00,$fd,$c0,$05,$00,$00,$60,$00,$00,$60,$f2,$00,$fd,$30,$f6,$00,$fd,$c0,$05,$00,$00,$60,$00,$00,$60,$f2,$00,$fd,$30,$fe
	dc.b	$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03
	dc.b	$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f
	dc.b	$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc
	dc.b	$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$01,$ff,$ff,$fe,$00,$03,$30,$00,$00,$30,$dd,$00,$03,$30,$00,$00,$30,$dd
	dc.b	$00,$00,$30,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00
	dc.b	$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f7,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02
	dc.b	$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff
	dc.b	$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$ff,$01,$cf,$cf,$fe,$00,$03,$30,$00,$00,$30,$ed,$00,$05,$60,$00,$60,$00,$60,$60
	dc.b	$f7,$00,$03,$30,$00,$00,$30,$ed,$00,$05,$60,$00,$60,$00,$60,$60,$f7,$00,$00,$30,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01
	dc.b	$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01
	dc.b	$fb,$ff,$02,$80,$00,$00,$f7,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00
	dc.b	$00,$fb,$ff,$fc,$cf,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$fb,$ff,$01,$cf
	dc.b	$cf,$e6,$00,$05,$60,$00,$60,$00,$60,$60,$df,$00,$05,$60,$00,$60,$00,$60,$60,$f6,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00
	dc.b	$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00
	dc.b	$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00
	dc.b	$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$9f,$02,$80,$00,$00,$f9,$ff,$f7,$00,$09,$c0,$00
	dc.b	$00,$c0,$00,$c0,$00,$00,$60,$60,$fe,$00,$00,$60,$f4,$00,$fe,$30,$f7,$00,$09,$c0,$00,$00,$c0,$00,$c0,$00,$00,$60,$60,$fe,$00,$00
	dc.b	$60,$f4,$00,$fe,$30,$fd,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00
	dc.b	$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff
	dc.b	$02,$00,$00,$03,$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc
	dc.b	$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$01,$ff,$ff,$f7,$00,$09,$c0,$00,$00,$c0,$00,$c0
	dc.b	$00,$00,$60,$60,$fe,$00,$00,$60,$f4,$00,$fe,$30,$f7,$00,$09,$c0,$00,$00,$c0,$00,$c0,$00,$00,$60,$60,$fe,$00,$00,$60,$f4,$00,$fe
	dc.b	$30,$fd,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00
	dc.b	$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$01,$cf,$cf,$fc,$ff,$02,$00,$00,$03
	dc.b	$fc,$3f,$02,$3e,$00,$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$fc,$ff,$02,$00,$00,$03,$fc,$3f,$02,$3e,$00
	dc.b	$01,$fc,$9f,$03,$98,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$fb,$cf,$01,$ff,$ff,$ad,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00
	dc.b	$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00
	dc.b	$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00
	dc.b	$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$ad,$00,$fa,$ff,$02
	dc.b	$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe
	dc.b	$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00
	dc.b	$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00
	dc.b	$00,$f9,$ff,$ad,$00,$fa,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff
	dc.b	$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f2,$ff,$02,$00,$00,$03,$fc,$ff,$02
	dc.b	$fe,$00,$01,$fc,$ff,$03,$f8,$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f6,$ff,$02,$00,$00,$03,$fc,$ff,$02,$fe,$00,$01,$fc,$ff,$03,$f8
	dc.b	$00,$00,$01,$fb,$ff,$02,$80,$00,$00,$f9,$ff,$51,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00
	dc.b	$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$ab,$00
	dc.b	$7f,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$01,$c0,$00
	dc.b	$03,$27,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$01,$c0,$00,$03,$ad,$00,$7f,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f
	dc.b	$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff
	dc.b	$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff
	dc.b	$fc,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00
	dc.b	$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$00,$00,$1c,$27,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00
	dc.b	$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$00,$00,$1c,$ad,$00,$7f,$f1,$ff,$ff,$e3,$ff,$ff,$c7
	dc.b	$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f
	dc.b	$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff
	dc.b	$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$f1,$ff,$ff,$e3,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00
	dc.b	$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$00,$00,$e0,$27,$00,$01,$c0,$00,$03,$80
	dc.b	$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$00
	dc.b	$00,$e0,$ad,$00,$7f,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$1f,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00
	dc.b	$00,$80,$00,$07,$00,$26,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$80,$00,$07,$ac,$00,$7f,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff
	dc.b	$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff
	dc.b	$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff
	dc.b	$7f,$ff,$f8,$ff,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00
	dc.b	$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$00,$26,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$ac,$00,$7f,$ff,$ff,$c7,$ff,$ff
	dc.b	$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc
	dc.b	$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f
	dc.b	$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38
	dc.b	$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$01,$c0,$00,$26,$03,$80,$00,$07
	dc.b	$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38
	dc.b	$00,$01,$c0,$ac,$00,$7f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f
	dc.b	$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff
	dc.b	$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$00,$0e,$00,$00,$1c,$00
	dc.b	$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00
	dc.b	$01,$c0,$00,$0e,$00,$00,$25,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00
	dc.b	$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$ab,$00,$7f,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe
	dc.b	$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7
	dc.b	$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f
	dc.b	$ff,$f1,$ff,$ff,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0
	dc.b	$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$00,$00,$25,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c
	dc.b	$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$ab,$00,$7f,$ff,$8f,$ff,$ff,$1f,$ff
	dc.b	$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff
	dc.b	$f1,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe
	dc.b	$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00
	dc.b	$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$03,$80,$00,$07,$27,$00,$00,$0e,$00,$00
	dc.b	$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$03
	dc.b	$80,$00,$07,$ad,$00,$7f,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff
	dc.b	$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff
	dc.b	$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$f8,$1c,$00,$00,$38,$00,$00
	dc.b	$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03
	dc.b	$80,$00,$1c,$00,$00,$38,$27,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00
	dc.b	$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$1c,$00,$00,$38,$ad,$00,$7f,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff
	dc.b	$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$e3,$ff,$ff,$c7,$ff,$ff
	dc.b	$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc
	dc.b	$7f,$ff,$e3,$ff,$ff,$c7,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01
	dc.b	$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$c0,$27,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00
	dc.b	$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$c0,$ad,$00,$7f,$1f,$ff
	dc.b	$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff
	dc.b	$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe
	dc.b	$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$3f,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00
	dc.b	$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$00,$00,$0e,$00,$26,$00
	dc.b	$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00
	dc.b	$e0,$00,$01,$00,$00,$0e,$ac,$00,$7f,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8
	dc.b	$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$ff,$ff,$f1,$ff,$00,$00,$70
	dc.b	$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80
	dc.b	$00,$07,$00,$00,$0e,$00,$00,$70,$00,$26,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70
	dc.b	$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$ac,$00,$7f,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f
	dc.b	$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff
	dc.b	$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff
	dc.b	$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00
	dc.b	$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$03,$80,$00,$26,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00
	dc.b	$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$03,$80,$ac,$00,$7f,$ff
	dc.b	$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff
	dc.b	$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc
	dc.b	$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01
	dc.b	$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$1c,$00,$00,$25
	dc.b	$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01
	dc.b	$c0,$00,$03,$80,$00,$1c,$ab,$00,$7f,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff
	dc.b	$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff
	dc.b	$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$e3,$ff,$ff,$00,$e0,$00
	dc.b	$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$27,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00
	dc.b	$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$ad,$00,$7f,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff
	dc.b	$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff
	dc.b	$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff
	dc.b	$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00
	dc.b	$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$07,$00,$00,$0e,$27,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00
	dc.b	$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$07,$00,$00,$0e,$ad,$00
	dc.b	$7f,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff
	dc.b	$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$f8,$ff,$ff,$f1,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00
	dc.b	$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$00,$00
	dc.b	$70,$27,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00
	dc.b	$03,$80,$00,$07,$00,$00,$38,$00,$00,$70,$ad,$00,$7f,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff
	dc.b	$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff
	dc.b	$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff
	dc.b	$8f,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$c0,$00,$03,$80,$27,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00
	dc.b	$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$c0,$00,$03,$80,$ad,$00,$7f,$3f,$ff,$fc,$7f,$ff,$f8,$ff
	dc.b	$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff
	dc.b	$ff,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff
	dc.b	$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$3f,$ff,$fc,$7f,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00
	dc.b	$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$00,$00,$1c,$00,$26,$00,$38,$00,$00,$70,$00
	dc.b	$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$00,$00
	dc.b	$1c,$ac,$00,$7f,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff
	dc.b	$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8
	dc.b	$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$ff,$ff,$e3,$ff,$00,$00,$e0,$00,$01,$c0,$00,$03
	dc.b	$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c
	dc.b	$00,$00,$e0,$00,$26,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03
	dc.b	$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$ac,$00,$7f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3
	dc.b	$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f
	dc.b	$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$1f,$ff,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$07,$00,$00,$25,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0
	dc.b	$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$07,$ab,$00,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff
	dc.b	$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff
	dc.b	$1f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3
	dc.b	$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$f8,$ff,$ff,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e
	dc.b	$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$00,$00,$25,$70,$00,$00,$e0,$00,$01
	dc.b	$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38
	dc.b	$ab,$00,$7f,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff
	dc.b	$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff
	dc.b	$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$01
	dc.b	$c0,$00,$03,$27,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$01,$c0,$00,$03,$ad,$00,$7f,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff
	dc.b	$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff
	dc.b	$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe
	dc.b	$3f,$ff,$fc,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00
	dc.b	$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$00,$00,$1c,$27,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00
	dc.b	$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$00,$00,$1c,$ad,$00,$7f,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff
	dc.b	$fe,$3f,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff
	dc.b	$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$f1,$ff,$ff,$e3,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00
	dc.b	$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$00,$00,$e0,$27,$00,$01,$c0,$00
	dc.b	$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00
	dc.b	$70,$00,$00,$e0,$ad,$00,$7f,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff
	dc.b	$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff
	dc.b	$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$1f,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00
	dc.b	$70,$00,$00,$80,$00,$07,$00,$26,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00
	dc.b	$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$80,$00,$07,$ac,$00,$7f,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff
	dc.b	$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$7f,$ff,$f8,$ff,$ff,$f1
	dc.b	$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f
	dc.b	$ff,$ff,$7f,$ff,$f8,$ff,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38
	dc.b	$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$00,$26,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07
	dc.b	$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$38,$ac,$00,$7f,$ff,$ff,$c7
	dc.b	$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f
	dc.b	$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff
	dc.b	$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$c7,$ff,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00
	dc.b	$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$01,$c0,$00,$26,$03,$80
	dc.b	$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00
	dc.b	$00,$38,$00,$01,$c0,$ac,$00,$7f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff
	dc.b	$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff
	dc.b	$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$fe,$3f,$ff,$00,$0e,$00,$00
	dc.b	$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00
	dc.b	$e0,$00,$01,$c0,$00,$0e,$00,$00,$25,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00
	dc.b	$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$0e,$ab,$00,$7f,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$f1,$ff,$ff,$e3,$ff
	dc.b	$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff
	dc.b	$fe,$3f,$ff,$f1,$ff,$ff,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00
	dc.b	$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$00,$00,$25,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00
	dc.b	$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$70,$ab,$00,$7f,$ff,$8f,$ff,$ff
	dc.b	$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8
	dc.b	$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$8f,$ff,$ff,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70
	dc.b	$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$03,$80,$00,$07,$27,$00,$00,$0e
	dc.b	$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70
	dc.b	$00,$03,$80,$00,$07,$ad,$00,$7f,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc
	dc.b	$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f
	dc.b	$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$fc,$7f,$ff,$f8,$1c,$00,$00,$38
	dc.b	$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0
	dc.b	$00,$03,$80,$00,$1c,$00,$00,$38,$27,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38
	dc.b	$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$1c,$00,$00,$38,$ad,$00,$7f,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe
	dc.b	$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$e3,$ff,$ff,$c7
	dc.b	$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f
	dc.b	$ff,$fc,$7f,$ff,$e3,$ff,$ff,$c7,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0
	dc.b	$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$c0,$27,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c
	dc.b	$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$e0,$00,$01,$c0,$ad,$00,$7f
	dc.b	$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8
	dc.b	$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f
	dc.b	$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$1f,$ff,$fe,$3f,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70
	dc.b	$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$00,$00,$0e,$00
	dc.b	$26,$00,$1c,$00,$00,$38,$00,$00,$70,$00,$00,$e0,$00,$01,$c0,$00,$03,$80,$00,$07,$00,$00,$0e,$00,$00,$1c,$00,$00,$38,$00,$00,$70
	dc.b	$00,$00,$e0,$00,$01,$00,$00,$0e,$ac,$00,$52,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f
	dc.b	$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff
	dc.b	$ff,$1f,$ff,$fe,$3f,$ff,$fc,$7f,$ff,$f8,$ff,$ff,$f1,$ff,$ff,$e3,$ff,$ff,$c7,$ff,$ff,$8f,$ff,$ff,$1f,$ff,$fe,$ff,$ff,$f1,$ac,$ff
	dc.b	$81,$00,$d9,$00,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9
	dc.b	$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff
	dc.b	$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff
	dc.b	$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff
	dc.b	$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7
	dc.b	$ff,$7f,$81,$ff,$d9,$ff,$53,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f
	dc.b	$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7
	dc.b	$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$f7,$ff,$7f,$7f,$f7,$ff,$7f,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a1,$00,$80
	even
bg_liberty	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$af,$00,$00,$20,$da,$00,$00,$20,$81,$00,$c8,$00,$00,$20,$da,$00,$00,$20
	dc.b	$81,$00,$99,$00,$00,$04,$fb,$00,$00,$01,$e1,$00,$00,$04,$fb,$00,$00,$01,$81,$00,$81,$00,$81,$00,$b0,$00,$00,$02,$da,$00,$00,$02
	dc.b	$81,$00,$c0,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$81,$00,$bb,$00,$00,$40,$ef,$00,$00,$08,$ed,$00,$00,$40,$ef,$00,$00,$08
	dc.b	$81,$00,$cb,$00,$00,$40,$df,$00,$00,$01,$fd,$00,$00,$40,$df,$00,$00,$01,$fd,$00,$00,$40,$81,$00,$81,$00,$81,$00,$b6,$00,$00,$01
	dc.b	$da,$00,$00,$01,$81,$00,$c1,$00,$00,$20,$fc,$00,$01,$02,$01,$e1,$00,$00,$20,$fc,$00,$01,$02,$01,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$f6,$00,$01,$07,$80,$db,$00,$01,$07,$80,$81,$00,$af,$00,$00,$0f,$da,$00,$00,$0f,$81,$00,$ae,$00,$00,$3e,$da,$00
	dc.b	$00,$3e,$81,$00,$fd,$00,$00,$04,$da,$00,$00,$04,$db,$00,$00,$7e,$da,$00,$00,$7e,$81,$00,$ae,$00,$00,$fc,$da,$00,$00,$fc,$81,$00
	dc.b	$f6,$00,$00,$04,$f6,$00,$00,$80,$e6,$00,$00,$04,$f6,$00,$00,$80,$ee,$00,$00,$fc,$da,$00,$00,$fc,$81,$00,$af,$00,$01,$01,$fc,$db
	dc.b	$00,$01,$01,$fc,$81,$00,$af,$00,$01,$03,$f8,$db,$00,$01,$03,$f8,$81,$00,$af,$00,$01,$03,$f8,$db,$00,$01,$03,$f8,$81,$00,$e6,$00
	dc.b	$00,$10,$da,$00,$00,$10,$f3,$00,$01,$03,$f8,$db,$00,$01,$03,$f8,$81,$00,$af,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$81,$00,$af,$00
	dc.b	$01,$03,$fc,$db,$00,$01,$03,$fc,$81,$00,$f2,$00,$01,$04,$20,$db,$00,$01,$04,$20,$e8,$00,$01,$07,$fc,$db,$00,$01,$07,$fc,$81,$00
	dc.b	$e9,$00,$00,$04,$da,$00,$00,$04,$f0,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$81,$00,$af,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$81,$00
	dc.b	$af,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$81,$00,$af,$00,$02,$03,$ff,$80,$dc,$00,$02,$03,$ff,$80,$81,$00,$f6,$00,$00,$04,$da,$00
	dc.b	$00,$04,$e4,$00,$02,$03,$ff,$c0,$dc,$00,$02,$03,$ff,$c0,$88,$00,$00,$01,$da,$00,$00,$01,$da,$00,$00,$01,$fa,$00,$03,$01,$ff,$f0
	dc.b	$04,$dd,$00,$03,$01,$ff,$f0,$04,$81,$00,$b0,$00,$02,$ff,$fe,$38,$dc,$00,$02,$ff,$fe,$38,$81,$00,$b0,$00,$02,$ff,$ff,$f8,$dc,$00
	dc.b	$02,$ff,$ff,$f8,$81,$00,$b0,$00,$02,$7f,$ff,$f0,$dc,$00,$02,$7f,$ff,$f0,$81,$00,$f7,$00,$00,$01,$da,$00,$00,$01,$e3,$00,$02,$3f
	dc.b	$ff,$e0,$dc,$00,$02,$3f,$ff,$e0,$81,$00,$b0,$00,$02,$0f,$ff,$80,$dc,$00,$02,$0f,$ff,$80,$81,$00,$b0,$00,$01,$07,$ff,$db,$00,$01
	dc.b	$07,$ff,$81,$00,$ae,$00,$00,$20,$da,$00,$00,$20,$81,$00,$99,$00,$00,$ff,$da,$00,$00,$ff,$97,$00,$00,$80,$f7,$00,$00,$08,$ef,$00
	dc.b	$00,$04,$f8,$00,$00,$80,$f7,$00,$00,$08,$ef,$00,$00,$04,$df,$00,$00,$ff,$da,$00,$00,$ff,$9a,$00,$00,$02,$e0,$00,$00,$10,$fc,$00
	dc.b	$00,$02,$e0,$00,$00,$10,$fc,$00,$00,$02,$e6,$00,$00,$ff,$da,$00,$00,$ff,$81,$00,$fe,$00,$00,$44,$da,$00,$00,$44,$da,$00,$00,$ff
	dc.b	$da,$00,$00,$ff,$81,$00,$ae,$00,$00,$ff,$da,$00,$00,$ff,$96,$00,$00,$02,$da,$00,$00,$02,$c2,$00,$00,$ff,$da,$00,$00,$ff,$81,$00
	dc.b	$ae,$00,$00,$ff,$da,$00,$00,$ff,$81,$00,$ae,$00,$00,$ff,$da,$00,$00,$ff,$97,$00,$00,$08,$da,$00,$00,$08,$c1,$00,$00,$ff,$da,$00
	dc.b	$00,$ff,$81,$00,$ae,$00,$00,$ff,$da,$00,$00,$ff,$82,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c
	dc.b	$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c
	dc.b	$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d7,$00,$01,$10,$3c,$db,$00,$01,$10,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00
	dc.b	$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00
	dc.b	$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$e7,$00
	dc.b	$00,$02,$f1,$00,$00,$3c,$eb,$00,$00,$02,$f1,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$dd,$00,$00,$40,$fb,$00,$00,$3c,$e1,$00
	dc.b	$00,$40,$fb,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$db,$00,$00,$40,$fd,$00,$00,$3c,$df,$00,$00,$40,$fd,$00,$00,$3c,$82,$00
	dc.b	$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00
	dc.b	$00,$3c,$da,$00,$00,$3c,$de,$00,$03,$08,$00,$00,$01,$fd,$00,$00,$3c,$f7,$00,$00,$02,$ed,$00,$03,$08,$00,$00,$01,$fd,$00,$00,$3c
	dc.b	$f7,$00,$00,$02,$8d,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$f9,$00,$00,$40,$e3,$00,$00,$3c,$f9,$00,$00,$40,$8b,$00,$00,$3c
	dc.b	$da,$00,$00,$3c,$f1,$00,$00,$02,$e7,$00,$00,$3c,$f5,$00,$00,$02,$e7,$00,$00,$3c,$f5,$00,$00,$02,$8f,$00,$00,$3c,$da,$00,$00,$3c
	dc.b	$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$02,$3c,$00,$80,$fd,$00,$03,$08,$00,$00,$20,$e4,$00,$02
	dc.b	$3c,$00,$80,$fd,$00,$03,$08,$00,$00,$20,$8c,$00,$00,$3c,$da,$00,$00,$3c,$d6,$00,$00,$3c,$da,$00,$00,$3c,$82,$00,$00,$3c,$da,$00
	dc.b	$00,$3c,$d8,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$84,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$d8,$00,$02,$c6,$31,$bc
	dc.b	$dc,$00,$02,$c6,$31,$bc,$84,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$f1,$00,$00,$02,$e9,$00,$02,$c6,$31,$bc,$f5,$00,$00,$02
	dc.b	$e9,$00,$02,$c6,$31,$bc,$f5,$00,$00,$02,$91,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$d8,$00,$02,$c6,$31,$bc,$f6,$00,$00,$10
	dc.b	$e8,$00,$02,$c6,$31,$bc,$f6,$00,$00,$10,$90,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$d8,$00,$04,$c6,$31,$bc,$00,$02,$de,$00
	dc.b	$04,$c6,$31,$bc,$00,$02,$86,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$d8,$00,$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$84,$00
	dc.b	$02,$c6,$31,$bc,$dc,$00,$02,$c6,$31,$bc,$d8,$00,$02,$cf,$ff,$bc,$dc,$00,$02,$cf,$ff,$bc,$84,$00,$02,$cf,$ff,$bc,$dc,$00,$02,$cf
	dc.b	$ff,$bc,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c
	dc.b	$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00
	dc.b	$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f
	dc.b	$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c
	dc.b	$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00
	dc.b	$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f
	dc.b	$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$fe,$00,$00,$80,$e0,$00,$02,$0f,$ff,$3c,$fe,$00,$00,$80,$88,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f
	dc.b	$ff,$3c,$d8,$00,$05,$0f,$ff,$3c,$00,$00,$20,$df,$00,$05,$0f,$ff,$3c,$00,$00,$20,$87,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c
	dc.b	$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00
	dc.b	$02,$0f,$ff,$3c,$84,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$02,$0f,$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$84,$00,$02,$0f
	dc.b	$ff,$3c,$dc,$00,$02,$0f,$ff,$3c,$d8,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$83,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$d7,$00,$01,$0f
	dc.b	$ff,$db,$00,$01,$0f,$ff,$83,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$d7,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$83,$00,$01,$03,$fc,$db
	dc.b	$00,$01,$03,$fc,$d7,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$83,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$d7,$00,$01,$03,$fc,$db,$00,$01
	dc.b	$03,$fc,$83,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$ea,$00,$00,$04,$ef,$00,$01,$03,$fc,$ee,$00,$00,$04,$ef,$00,$01,$03,$fc,$83,$00
	dc.b	$01,$03,$fc,$db,$00,$01,$03,$fc,$d7,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$83,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$db,$00,$05,$ff
	dc.b	$ff,$80,$00,$03,$fc,$df,$00,$05,$ff,$ff,$80,$00,$03,$fc,$db,$00,$02,$ff,$ff,$80,$dc,$00,$02,$ff,$ff,$80,$d4,$00,$01,$03,$fc,$db
	dc.b	$00,$01,$03,$fc,$db,$00,$05,$ff,$ff,$80,$00,$03,$fc,$df,$00,$05,$ff,$ff,$80,$00,$03,$fc,$db,$00,$02,$ff,$ff,$80,$dc,$00,$02,$ff
	dc.b	$ff,$80,$d4,$00,$01,$03,$fc,$db,$00,$01,$03,$fc,$e1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$e5,$00,$0b,$03,$ff
	dc.b	$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$e1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$e2,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff
	dc.b	$ff,$80,$d4,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$f1
	dc.b	$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03
	dc.b	$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$f1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00
	dc.b	$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e7,$00,$00,$02,$fc,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$fd
	dc.b	$00,$00,$04,$fb,$00,$00,$80,$f7,$00,$00,$02,$fc,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$fd,$00,$00,$04,$fb,$00
	dc.b	$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$f1
	dc.b	$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03
	dc.b	$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$f1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00
	dc.b	$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$f1
	dc.b	$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$f6,$00,$00,$80,$ed,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00
	dc.b	$00,$80,$f1,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f3,$00,$00,$80,$e3,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03
	dc.b	$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$07,$fe,$fa,$00,$05,$08,$00,$01,$ff,$ff,$80,$f2,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80
	dc.b	$00,$07,$fe,$fa,$00,$05,$08,$00,$01,$ff,$ff,$80,$ee,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$f2
	dc.b	$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$e1,$00,$0b,$03
	dc.b	$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f,$ff,$f8,$00,$03,$01,$ff,$ff,$80,$f2,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f
	dc.b	$ff,$f8,$00,$03,$01,$ff,$ff,$80,$ee,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$f2,$00,$08,$03,$ff
	dc.b	$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$e1,$00,$0b,$03,$ff,$ff,$fc,$00
	dc.b	$00,$ff,$ff,$80,$00,$0f,$ff,$f8,$00,$03,$01,$ff,$ff,$80,$f2,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f,$ff,$f8,$00,$03
	dc.b	$01,$ff,$ff,$80,$ee,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$f2,$00,$08,$03,$ff,$ff,$fc,$00,$00
	dc.b	$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$e9,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff
	dc.b	$fc,$00,$00,$ff,$ff,$80,$00,$0f,$ff,$f8,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff
	dc.b	$ff,$80,$00,$0f,$ff,$f8,$00,$03,$01,$ff,$ff,$80,$f6,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00
	dc.b	$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f5,$00,$03,$01,$ff,$ff,$80,$e4,$00
	dc.b	$01,$0f,$ff,$db,$00,$01,$0f,$ff,$e9,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f,$ff,$fc,$00,$00
	dc.b	$0c,$fe,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f,$ff,$fc,$00,$00
	dc.b	$0c,$fe,$00,$03,$01,$ff,$ff,$80,$f6,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f9,$00,$00,$08,$fe,$00
	dc.b	$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f9,$00,$00,$08,$fe,$00,$03,$01,$ff
	dc.b	$ff,$80,$e4,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$e9,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f
	dc.b	$ff,$fc,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$0b,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$00,$0f
	dc.b	$ff,$fc,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$f6,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f9,$00
	dc.b	$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$08,$03,$ff,$ff,$fc,$00,$00,$ff,$ff,$80,$f9,$00,$00,$08,$fe
	dc.b	$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$e9,$00,$fe,$ff,$00,$80,$fd,$00,$05,$03,$ff,$ff,$fc,$00,$00,$fb
	dc.b	$ff,$00,$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$05,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00
	dc.b	$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$f6,$00,$fe,$ff,$00,$80,$fd,$00,$05,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$f0,$00
	dc.b	$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fa,$00,$fe,$ff,$00,$80,$fd,$00,$05,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$f0,$00
	dc.b	$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$ec,$00,$00,$03,$fc,$ff,$00,$80,$fd,$00
	dc.b	$05,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fd,$00,$00,$03,$fc,$ff,$00,$80,$fd,$00
	dc.b	$05,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$f9,$00,$00,$03,$fc,$ff,$00,$80,$fd,$00
	dc.b	$05,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$f0,$00,$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$fd,$00,$00,$03,$fc,$ff,$00,$80
	dc.b	$fd,$00,$05,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$f0,$00,$02,$fd,$00,$00,$08,$fe,$00,$03,$01,$ff,$ff,$80,$e4,$00,$01,$0f,$ff,$db
	dc.b	$00,$01,$0f,$ff,$f0,$00,$04,$ff,$ff,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$02,$fd,$00
	dc.b	$00,$08,$fe,$00,$00,$01,$fc,$ff,$02,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$02,$fd,$00
	dc.b	$00,$08,$fe,$00,$00,$01,$fc,$ff,$06,$00,$00,$ff,$ff,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff
	dc.b	$02,$f0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$02,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00
	dc.b	$fd,$ff,$02,$f0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$e6,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$f0,$00,$04,$ff,$ff,$00
	dc.b	$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00,$04,$08,$00,$20,$00,$03,$fc,$ff,$02,$00
	dc.b	$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00,$04,$08,$00,$20,$00,$03,$fc,$ff,$06,$00
	dc.b	$00,$ff,$ff,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08,$fe,$00
	dc.b	$00,$01,$fc,$ff,$02,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08
	dc.b	$fe,$00,$00,$01,$fc,$ff,$e6,$00,$02,$1f,$ff,$80,$dc,$00,$02,$1f,$ff,$80,$f1,$00,$04,$ff,$ff,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00
	dc.b	$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$02,$00,$00,$03,$fc,$ff,$00,$80,$fe,$00
	dc.b	$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$06,$00,$00,$ff,$ff,$00,$00,$03,$fc,$ff
	dc.b	$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$02,$00,$00,$03
	dc.b	$fc,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$fc,$ff,$e6,$00
	dc.b	$02,$1f,$ff,$80,$dc,$00,$02,$1f,$ff,$80,$f1,$00,$f7,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00
	dc.b	$00,$08,$fe,$00,$00,$01,$f4,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$00,$82,$fd,$00,$00,$08,$fe,$00,$00,$01
	dc.b	$f0,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$f4,$ff,$00,$80
	dc.b	$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$02,$fd,$00,$00,$08,$fe,$00,$00,$01,$fa,$ff,$e8,$00,$02,$1f,$ff,$80
	dc.b	$dc,$00,$02,$1f,$ff,$80,$f1,$00,$f7,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$02,$82,$00,$7f,$ed,$ff,$00,$80
	dc.b	$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fb,$ff,$02,$82,$00,$7f,$e9,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff
	dc.b	$04,$e0,$00,$02,$00,$7f,$ed,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$04,$e0,$00,$02,$00,$7f,$f3,$ff,$e8,$00
	dc.b	$02,$1f,$ff,$80,$dc,$00,$02,$1f,$ff,$80,$f1,$00,$f7,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$e4,$ff,$00,$80,$fe,$00
	dc.b	$06,$40,$03,$ff,$ff,$fc,$00,$00,$e0,$ff,$00,$80,$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$7f,$eb,$ff,$00,$80
	dc.b	$fe,$00,$06,$40,$03,$ff,$ff,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$7f,$f1,$ff,$e8,$00,$02,$1f,$ff,$80,$dc,$00,$02,$1f,$ff,$80,$f1,$00
	dc.b	$ef,$ff,$02,$fc,$00,$00,$dc,$ff,$02,$fc,$00,$00,$d8,$ff,$02,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$7f,$e3,$ff,$02,$fc,$00,$00,$fd,$ff
	dc.b	$02,$e0,$00,$7f,$f1,$ff,$e8,$00,$02,$1f,$ff,$80,$dc,$00,$02,$1f,$ff,$80,$f1,$00,$ef,$ff,$02,$fc,$00,$00,$dc,$ff,$02,$fc,$00,$00
	dc.b	$d8,$ff,$02,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$7f,$e3,$ff,$02,$fc,$00,$00,$fd,$ff,$02,$e0,$00,$7f,$f1,$ff,$e8,$00,$02,$1f,$ff,$80
	dc.b	$dc,$00,$02,$1f,$ff,$80,$f1,$00,$94,$ff,$02,$e0,$00,$7f,$dc,$ff,$02,$e0,$00,$7f,$f1,$ff,$e8,$00,$02,$1f,$ff,$80,$dc,$00,$02,$1f
	dc.b	$ff,$80,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00
	dc.b	$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0
	dc.b	$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff
	dc.b	$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f
	dc.b	$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00
	dc.b	$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0
	dc.b	$dc,$00,$02,$3f,$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f
	dc.b	$ff,$c0,$f1,$00,$94,$ff,$02,$c0,$00,$3f,$dc,$ff,$02,$c0,$00,$3f,$f1,$ff,$e8,$00,$02,$3f,$ff,$c0,$dc,$00,$02,$3f,$ff,$c0,$f1,$00
	dc.b	$94,$ff,$02,$80,$00,$1f,$dc,$ff,$02,$80,$00,$1f,$f1,$ff,$e8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0
	dc.b	$dc,$00,$02,$7f,$ff,$e0,$84,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$84,$00
	dc.b	$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$84,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f
	dc.b	$ff,$e0,$d8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$84,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0
	dc.b	$dc,$00,$02,$7f,$ff,$e0,$84,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$84,$00
	dc.b	$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$d8,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f,$ff,$e0,$84,$00,$02,$7f,$ff,$e0,$dc,$00,$02,$7f
	dc.b	$ff,$e0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0
	dc.b	$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00
	dc.b	$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff
	dc.b	$ff,$f0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0
	dc.b	$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00
	dc.b	$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$d8,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff,$ff,$f0,$84,$00,$02,$ff,$ff,$f0,$dc,$00,$02,$ff
	dc.b	$ff,$f0,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00
	dc.b	$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff
	dc.b	$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03
	dc.b	$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8
	dc.b	$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01
	dc.b	$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd
	dc.b	$00,$03,$01,$ff,$ff,$f8,$d9,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff,$ff,$f8,$85,$00,$03,$01,$ff,$ff,$f8,$dd,$00,$03,$01,$ff
	dc.b	$ff,$f8,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff
	dc.b	$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00
	dc.b	$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f
	dc.b	$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff
	dc.b	$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00
	dc.b	$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f
	dc.b	$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff
	dc.b	$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00
	dc.b	$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f
	dc.b	$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff
	dc.b	$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00,$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$d9,$00
	dc.b	$00,$0f,$fe,$ff,$dd,$00,$00,$0f,$fe,$ff,$da,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$db,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$17,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c
	dc.b	$00,$18,$00,$60,$03,$fd,$ff,$23,$fc,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30
	dc.b	$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$03,$fd,$ff,$0e,$fc,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$18,$00,$30,$e9,$00
	dc.b	$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$16,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe
	dc.b	$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$fb,$ff,$21,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3
	dc.b	$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$fb,$ff,$26,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$e7,$ff,$cf,$ff,$60
	dc.b	$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$07,$fd,$ff,$23,$fc,$60,$01,$80,$03,$00
	dc.b	$0c,$00,$18,$00,$60,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$07,$fd,$ff
	dc.b	$0f,$fc,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$60,$01,$80,$03,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00
	dc.b	$fc,$f2,$00,$17,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$fb,$fc,$ff,$22,$9f
	dc.b	$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe
	dc.b	$7f,$fb,$fc,$ff,$26,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$9f,$fe,$7f,$fc,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00
	dc.b	$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$1b,$fc,$ff,$22,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$06,$00,$18,$00,$30
	dc.b	$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$1b,$fc,$ff,$0e,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06
	dc.b	$00,$06,$00,$18,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$17,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe
	dc.b	$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$fd,$ff,$23,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f9
	dc.b	$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$fd,$ff,$27,$fc,$ff,$f9,$ff,$e7,$ff,$cf
	dc.b	$ff,$3f,$fe,$7f,$f9,$ff,$f9,$ff,$e7,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00
	dc.b	$c3,$fd,$ff,$23,$fc,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03
	dc.b	$00,$06,$00,$18,$00,$30,$00,$c3,$fd,$ff,$0f,$fc,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$30,$00,$60,$ea,$00,$00,$03,$fd
	dc.b	$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$17,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9
	dc.b	$ff,$e7,$ff,$cf,$ff,$3f,$fb,$ff,$21,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f
	dc.b	$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fb,$ff,$25,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$cf,$ff,$9f,$00,$c0,$03,$00
	dc.b	$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$03,$fd,$ff,$23,$fc,$00,$c0,$03,$00,$06,$00,$18,$00
	dc.b	$30,$00,$c0,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$03,$fd,$ff,$0e,$fc,$00
	dc.b	$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$00,$c0,$03,$e9,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$16
	dc.b	$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$fa,$ff,$20,$3f,$fc,$ff,$f9,$ff,$e7
	dc.b	$ff,$cf,$ff,$3f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$fa,$ff,$25,$3f,$fc
	dc.b	$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$ff,$3f,$fc,$ff,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00
	dc.b	$06,$00,$18,$03,$fd,$ff,$23,$fc,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00
	dc.b	$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$03,$fd,$ff,$0e,$fc,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$06,$00,$0c,$e9,$00,$00
	dc.b	$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$16,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f
	dc.b	$ff,$3f,$fc,$ff,$f9,$ff,$e7,$fb,$ff,$21,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff
	dc.b	$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$fb,$ff,$26,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f9,$ff,$f3,$ff,$18,$00
	dc.b	$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$03,$fd,$ff,$23,$fc,$18,$00,$60,$00,$c0,$03
	dc.b	$00,$06,$00,$18,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$03,$fd,$ff,$0e
	dc.b	$fc,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$18,$00,$60,$e9,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2
	dc.b	$00,$16,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fb,$ff,$21,$e7,$ff,$9f,$ff
	dc.b	$3f,$fc,$ff,$f9,$ff,$e7,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fb,$ff
	dc.b	$26,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$e7,$ff,$9f,$ff,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00
	dc.b	$18,$00,$60,$00,$c0,$03,$00,$07,$fd,$ff,$23,$fc,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$c0,$01,$80,$06,$00,$0c,$00,$30,$00
	dc.b	$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$07,$fd,$ff,$0f,$fc,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$c0,$01
	dc.b	$80,$06,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$17,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe
	dc.b	$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$fb,$fc,$ff,$22,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$3f,$fe,$7f,$f9,$ff
	dc.b	$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$fb,$fc,$ff,$26,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f
	dc.b	$fe,$3f,$fe,$7f,$f9,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$33,$fc,$ff,$22
	dc.b	$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00
	dc.b	$0c,$00,$33,$fc,$ff,$0e,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$0c,$00,$18,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00
	dc.b	$03,$fd,$ff,$00,$fc,$f2,$00,$17,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf
	dc.b	$fd,$ff,$23,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f
	dc.b	$fe,$7f,$f9,$ff,$f3,$ff,$cf,$fd,$ff,$27,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$f3,$ff,$e7,$00,$30,$00,$c0,$01,$80
	dc.b	$06,$00,$0c,$00,$30,$00,$60,$01,$80,$07,$00,$1c,$00,$78,$01,$e0,$07,$c3,$fd,$ff,$23,$fc,$07,$30,$1c,$c0,$71,$81,$c6,$07,$0c,$00
	dc.b	$30,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$07,$00,$1c,$00,$78,$01,$e0,$07,$c3,$fd,$ff,$0f,$fc,$07,$30,$1c
	dc.b	$c0,$71,$81,$c6,$07,$0c,$00,$30,$00,$30,$00,$c0,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$0e,$ff
	dc.b	$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fd,$ff,$04,$f7,$ff,$df,$ff,$3f,$fb,$ff,$18,$cf,$ff,$3f,$fe,$7f,$f9,$ff
	dc.b	$f3,$ff,$cf,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fd,$ff,$04,$f7,$ff,$df,$ff,$3f,$fb,$ff,$25,$cf,$ff,$3f
	dc.b	$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$cf,$ff,$3f,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$1f,$c0,$7f,$01,$fc,$07
	dc.b	$f0,$1f,$c3,$fd,$ff,$23,$fc,$1f,$c0,$7f,$01,$fc,$07,$f8,$1f,$e0,$00,$c0,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06
	dc.b	$00,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c3,$fd,$ff,$0e,$fc,$1f,$c0,$7f,$01,$fc,$07,$f8,$1f,$e0,$00,$c0,$01,$80,$03,$e9,$00,$00,$03
	dc.b	$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$0d,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ec,$ff,$12
	dc.b	$f7,$ff,$df,$ff,$3f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ec,$ff,$20,$f7,$ff,$df,$ff,$3f,$fe,$7f,$fc,$ff,$06
	dc.b	$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$7f,$c1,$ff,$03,$fc,$0f,$f0,$1f,$c3,$fd,$ff,$23,$fc,$1f,$c0,$7f,$01,$fc
	dc.b	$07,$f0,$1f,$c0,$06,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$7f,$c1,$ff,$03,$fc,$0f,$f0,$1f,$c3,$fd,$ff
	dc.b	$0e,$fc,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$06,$00,$06,$00,$18,$e9,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc
	dc.b	$f2,$00,$14,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fd,$ff,$f7,$f0,$ff,$16,$f9,$ff,$f9,$ff,$e7
	dc.b	$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fd,$ff,$f7,$f0,$ff,$1d,$f9,$ff,$f9,$ff,$e7,$ff,$30,$00,$60,$01,$80
	dc.b	$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$3f,$e6,$ff,$9b,$fe,$3f,$f8,$ff,$e3,$fd,$ff,$23,$fc,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e0
	dc.b	$18,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$3f,$e6,$ff,$9b,$fe,$3f,$f8,$ff,$e3,$fd,$ff,$0f,$fc,$3f,$e0
	dc.b	$ff,$83,$fe,$0f,$f8,$3f,$e0,$18,$00,$30,$00,$60,$01,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$16
	dc.b	$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$f2,$ff,$18,$e7,$ff,$cf,$ff,$9f,$fe
	dc.b	$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$f2,$ff,$1d,$e7,$ff,$cf,$ff,$9f,$fe,$c0,$03,$00,$06
	dc.b	$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$3f,$f0,$ff,$e3,$ff,$8f,$fb,$3f,$ef,$fd,$ff,$23,$fc,$ff,$e3,$ff,$87,$fe,$1f,$f8,$3f
	dc.b	$e0,$c0,$01,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$3f,$f0,$ff,$e3,$ff,$8f,$fb,$3f,$ef,$fd,$ff,$0f,$fc,$ff
	dc.b	$e3,$ff,$87,$fe,$1f,$f8,$3f,$e0,$c0,$01,$c0,$03,$00,$06,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00
	dc.b	$17,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$ef,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$fc,$ff,$05,$3f,$fc,$ff,$fb
	dc.b	$ff,$ef,$fe,$ff,$19,$3f,$fe,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$ef,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$fc
	dc.b	$ff,$05,$3f,$fc,$ff,$fb,$ff,$ef,$fe,$ff,$1d,$3f,$fe,$3f,$fc,$ff,$f9,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60
	dc.b	$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$f3,$fd,$ff,$23,$fe,$3f,$ec,$ff,$b3,$fe,$6f,$f9,$bf,$e3,$00,$0c,$00,$0c,$00,$30,$00,$60,$01,$80
	dc.b	$03,$00,$0c,$00,$18,$00,$60,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$f3,$fd,$ff,$0f,$fe,$3f,$ec,$ff,$b3,$fe,$6f,$f9,$bf,$e3,$00,$0c,$00
	dc.b	$0c,$00,$30,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$0e,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff
	dc.b	$f3,$ff,$e7,$ff,$9f,$f9,$ff,$00,$ef,$fd,$ff,$1a,$fd,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f
	dc.b	$fc,$ff,$f3,$ff,$e7,$ff,$9f,$f9,$ff,$00,$ef,$fd,$ff,$27,$fd,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$f3,$ff,$cf,$00,$60
	dc.b	$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e3,$fd,$ff,$23,$fc,$3f,$e0,$ff,$c3,$ff,$0f
	dc.b	$fe,$3f,$f8,$00,$30,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e3,$fd,$ff,$0f
	dc.b	$fc,$3f,$e0,$ff,$c3,$ff,$0f,$fe,$3f,$f8,$00,$30,$00,$60,$00,$c0,$ea,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc
	dc.b	$f2,$00,$0e,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f0,$ff,$16,$bf,$fe,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$9f,$ff
	dc.b	$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f0,$ff,$23,$bf,$fe,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$9f,$ff,$3f,$01,$80,$06,$00,$0c
	dc.b	$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e3,$fd,$ff,$23,$fc,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e0
	dc.b	$01,$80,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$3f,$e0,$ff,$83,$fe,$0f,$f8,$3f,$e3,$fd,$ff,$0e,$fc,$3f,$e0
	dc.b	$ff,$83,$fe,$0f,$f8,$3f,$e0,$01,$80,$01,$80,$06,$e9,$00,$00,$03,$fd,$ff,$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$0d,$fe
	dc.b	$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$e9,$ff,$0f,$fe,$7f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3
	dc.b	$e9,$ff,$1d,$fe,$7f,$fe,$7f,$f9,$ff,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$df,$c1,$ff,$07,$fc,$0f,$f0,$3f
	dc.b	$c3,$fd,$ff,$23,$fc,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$06,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$df
	dc.b	$c1,$ff,$07,$fc,$0f,$f0,$3f,$c3,$fd,$ff,$0e,$fc,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$06,$00,$0c,$00,$18,$e9,$00,$00,$03,$fd,$ff
	dc.b	$00,$fc,$df,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$16,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9
	dc.b	$ff,$f7,$ff,$df,$f2,$ff,$18,$f9,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f7,$ff,$df
	dc.b	$f2,$ff,$59,$f9,$ff,$f3,$ff,$e7,$ff,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f
	dc.b	$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$30,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03
	dc.b	$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$7f,$01,$fc,$07,$f0,$1f,$c0,$30,$00,$30,$00,$c0,$01,$f2,$00,$16
	dc.b	$e0,$3f,$80,$fe,$03,$f8,$0f,$e0,$3f,$80,$fe,$03,$f8,$0f,$e0,$3f,$80,$fe,$03,$f8,$0f,$e0,$30,$f0,$00,$16,$e0,$3f,$80,$fe,$03,$f8
	dc.b	$0f,$e0,$3f,$80,$fe,$03,$f8,$0f,$e0,$3f,$80,$fe,$03,$f8,$0f,$e0,$30,$fb,$00,$0e,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f
	dc.b	$fe,$7f,$fc,$ea,$ff,$10,$cf,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ea,$ff,$59,$cf,$ff,$cf,$ff,$3f,$fe
	dc.b	$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$07,$00,$1c,$00,$70,$01,$c0,$07,$00,$1c,$00,$70,$01,$c0,$07,$00,$1c
	dc.b	$00,$70,$01,$c0,$07,$00,$c0,$03,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$07,$00,$1c,$00,$70,$01,$c0,$07,$00
	dc.b	$1c,$00,$70,$01,$c0,$07,$00,$1c,$00,$70,$01,$c0,$07,$00,$c0,$03,$80,$03,$00,$0c,$f2,$00,$16,$f8,$ff,$e3,$ff,$8f,$fe,$3f,$f8,$ff
	dc.b	$e3,$ff,$8f,$fe,$3f,$f8,$ff,$e3,$ff,$8f,$fe,$3f,$f8,$f0,$f0,$00,$16,$f8,$ff,$e3,$ff,$8f,$fe,$3f,$f8,$ff,$e3,$ff,$8f,$fe,$3f,$f8
	dc.b	$ff,$e3,$ff,$8f,$fe,$3f,$f8,$f0,$fb,$00,$0e,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ea,$ff,$10,$3f,$fc,$7f
	dc.b	$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ea,$ff,$14,$3f,$fc,$7f,$fc,$ff,$f3,$00,$18,$00,$30,$00,$c0,$01,$80,$06
	dc.b	$00,$0c,$00,$30,$00,$60,$eb,$00,$11,$06,$00,$0c,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$eb,$00,$06,$06,$00
	dc.b	$0c,$00,$18,$00,$30,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff
	dc.b	$cf,$ff,$9f,$eb,$ff,$11,$f9,$ff,$f3,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$eb,$ff,$14,$f9,$ff,$f3,$ff,$e7
	dc.b	$ff,$cf,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$ea,$00,$10,$08,$00,$60,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00
	dc.b	$60,$00,$c0,$03,$ea,$00,$06,$08,$00,$60,$00,$60,$01,$80,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0d,$ff,$9f,$fe
	dc.b	$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ea,$ff,$10,$f7,$ff,$9f,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ea
	dc.b	$ff,$14,$f7,$ff,$9f,$ff,$9f,$fe,$7f,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$e9,$00,$0f,$01,$80,$03,$00,$06,$00
	dc.b	$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$e9,$00,$04,$01,$80,$03,$00,$06,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00
	dc.b	$0d,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$e9,$ff,$0f,$fe,$7f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9
	dc.b	$ff,$f3,$e9,$ff,$13,$fe,$7f,$fc,$ff,$f9,$ff,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$e9,$00,$0f,$0c,$00,$0c,$00
	dc.b	$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$e9,$00,$04,$0c,$00,$0c,$00,$30,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0
	dc.b	$fb,$00,$0d,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$e9,$ff,$0f,$f3,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3
	dc.b	$ff,$e7,$ff,$9f,$e9,$ff,$14,$f3,$ff,$f3,$ff,$cf,$ff,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$ea,$00,$10,$30
	dc.b	$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$ea,$00,$05,$30,$00,$60,$00,$c0,$03,$f2,$00,$eb,$ff,$00,$f0,$f0
	dc.b	$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ea,$ff,$10,$cf,$ff,$9f,$ff,$3f,$fc
	dc.b	$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ea,$ff,$14,$cf,$ff,$9f,$ff,$3f,$fc,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00
	dc.b	$0c,$00,$18,$eb,$00,$11,$01,$80,$03,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$eb,$00,$06,$01,$80,$03,$80,$06
	dc.b	$00,$0c,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7
	dc.b	$eb,$ff,$11,$fe,$7f,$fc,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$eb,$ff,$15,$fe,$7f,$fc,$7f,$f9,$ff,$f3,$00
	dc.b	$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$eb,$00,$11,$06,$00,$18,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00
	dc.b	$30,$00,$c0,$eb,$00,$06,$06,$00,$18,$00,$18,$00,$60,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$ff,$e7,$ff,$9f
	dc.b	$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$eb,$ff,$11,$f9,$ff,$e7,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f
	dc.b	$eb,$ff,$14,$f9,$ff,$e7,$ff,$e7,$ff,$9f,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$e8,$00,$0e,$60,$00,$c0,$01,$80
	dc.b	$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$e8,$00,$04,$60,$00,$c0,$01,$80,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00
	dc.b	$0d,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$e8,$ff,$0e,$9f,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f
	dc.b	$fc,$e8,$ff,$12,$9f,$ff,$3f,$fe,$7f,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$e9,$00,$0f,$03,$00,$03,$00,$0c,$00
	dc.b	$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$e9,$00,$04,$03,$00,$03,$00,$0c,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00
	dc.b	$0d,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$e9,$ff,$0f,$fc,$ff,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9
	dc.b	$ff,$e7,$e9,$ff,$14,$fc,$ff,$fc,$ff,$f3,$ff,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$ea,$00,$10,$0c,$00,$18
	dc.b	$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$00,$60,$01,$ea,$00,$04,$0c,$00,$18,$00,$30,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff
	dc.b	$00,$f0,$fb,$00,$0e,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$ea,$ff,$10,$f3,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f
	dc.b	$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$ea,$ff,$14,$f3,$ff,$e7,$ff,$cf,$ff,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06
	dc.b	$ea,$00,$10,$60,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$ea,$00,$05,$60,$00,$60,$01,$80,$03,$f2,$00,$eb
	dc.b	$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ea,$ff,$10,$9f,$ff
	dc.b	$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ea,$ff,$14,$9f,$ff,$9f,$fe,$7f,$fc,$00,$06,$00,$18,$00,$30,$00,$c0
	dc.b	$01,$80,$06,$00,$0c,$00,$30,$eb,$00,$11,$01,$80,$06,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$00,$0c,$00,$30,$eb,$00,$06,$01
	dc.b	$80,$06,$00,$06,$00,$18,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9
	dc.b	$ff,$f3,$ff,$cf,$eb,$ff,$11,$fe,$7f,$f9,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$ff,$f3,$ff,$cf,$eb,$ff,$15,$fe,$7f,$f9,$ff
	dc.b	$f9,$ff,$e7,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$00,$60,$00,$c0,$eb,$00,$11,$0c,$00,$18,$00,$30,$00,$60,$01,$80,$03,$00
	dc.b	$0c,$00,$18,$00,$60,$00,$c0,$eb,$00,$06,$0c,$00,$18,$00,$30,$00,$60,$f2,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00,$f0,$fb,$00,$0e
	dc.b	$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$ff,$9f,$ff,$3f,$eb,$ff,$11,$f3,$ff,$e7,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7
	dc.b	$ff,$9f,$ff,$3f,$eb,$ff,$14,$f3,$ff,$e7,$ff,$cf,$ff,$9f,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$e8,$00,$0e,$c0
	dc.b	$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$80,$06,$e8,$00,$03,$c0,$00,$c0,$03,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00
	dc.b	$f0,$fb,$00,$0d,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$7f,$f9,$e8,$ff,$0e,$3f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff
	dc.b	$3f,$fe,$7f,$f9,$e8,$ff,$12,$3f,$ff,$3f,$fc,$ff,$06,$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$e9,$00,$0f,$03,$00,$06
	dc.b	$00,$0c,$00,$30,$00,$60,$01,$80,$03,$00,$0c,$00,$18,$e9,$00,$04,$03,$00,$06,$00,$0c,$f1,$00,$eb,$ff,$00,$f0,$f0,$00,$eb,$ff,$00
	dc.b	$f0,$fb,$00,$0d,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f,$fc,$ff,$f3,$ff,$e7,$e9,$ff,$0f,$fc,$ff,$f9,$ff,$f3,$ff,$cf,$ff,$9f,$fe,$7f
	dc.b	$fc,$ff,$f3,$ff,$e7,$e9,$ff,$14,$fc,$ff,$f9,$ff,$f3,$ff,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$ea,$00,$10
	dc.b	$18,$00,$18,$00,$60,$00,$c0,$03,$00,$06,$00,$18,$00,$30,$00,$c0,$01,$ea,$00,$04,$18,$00,$18,$00,$60,$f1,$00,$eb,$ff,$00,$f0,$f0
	dc.b	$00,$eb,$ff,$00,$f0,$fb,$00,$0e,$e7,$ff,$9f,$ff,$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$ea,$ff,$10,$e7,$ff,$e7,$ff,$9f,$ff
	dc.b	$3f,$fc,$ff,$f9,$ff,$e7,$ff,$cf,$ff,$3f,$fe,$ea,$ff,$04,$e7,$ff,$e7,$ff,$9f,$ac,$ff,$81,$00,$d9,$00,$81,$ff,$81,$ff,$81,$ff,$81
	dc.b	$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$f1,$ff,$53,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff
	dc.b	$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f
	dc.b	$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03
	dc.b	$ff,$00,$3f,$f0,$03,$ff,$00,$3f,$f0,$03,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff
	dc.b	$81,$ff,$81,$ff,$81,$ff,$81,$ff,$a1,$ff,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$a1,$00,$80
	even
bg_manhattan	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b4,$00,$00,$08,$da,$00,$00,$08,$81,$00,$81,$00,$81,$00,$cb,$00,$00,$10
	dc.b	$e8,$00,$00,$04,$f4,$00,$00,$10,$e8,$00,$00,$04,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c1,$00,$02,$01,$00,$40,$dc,$00,$02,$01
	dc.b	$00,$40,$81,$00,$81,$00,$81,$00,$a2,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$ce,$00,$00,$20,$da,$00,$00,$20,$81,$00
	dc.b	$b0,$00,$00,$08,$da,$00,$00,$08,$81,$00,$95,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$d9,$00,$00,$08,$da,$00,$00,$08,$87,$00
	dc.b	$00,$20,$da,$00,$00,$20,$d2,$00,$01,$01,$e0,$db,$00,$01,$01,$e0,$a1,$00,$00,$40,$f8,$00,$00,$80,$e4,$00,$00,$40,$f8,$00,$00,$80
	dc.b	$e4,$00,$00,$40,$e0,$00,$01,$07,$c0,$db,$00,$01,$07,$c0,$81,$00,$af,$00,$01,$1f,$c0,$db,$00,$01,$1f,$c0,$84,$00,$00,$02,$da,$00
	dc.b	$00,$02,$d5,$00,$01,$3f,$80,$db,$00,$01,$3f,$80,$8a,$00,$00,$10,$da,$00,$00,$10,$cf,$00,$00,$7f,$da,$00,$00,$7f,$81,$00,$ae,$00
	dc.b	$00,$ff,$da,$00,$00,$ff,$81,$00,$af,$00,$01,$01,$ff,$db,$00,$01,$01,$ff,$8b,$00,$00,$04,$da,$00,$00,$04,$ce,$00,$01,$01,$fe,$db
	dc.b	$00,$01,$01,$fe,$81,$00,$af,$00,$01,$03,$fe,$db,$00,$01,$03,$fe,$8e,$00,$03,$04,$00,$00,$02,$dd,$00,$03,$04,$00,$00,$02,$ce,$00
	dc.b	$01,$03,$fe,$db,$00,$01,$03,$fe,$9c,$00,$00,$02,$da,$00,$00,$02,$bd,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$81,$00,$af,$00,$01,$07
	dc.b	$fe,$db,$00,$01,$07,$fe,$99,$00,$00,$02,$da,$00,$00,$02,$c0,$00,$01,$07,$fe,$db,$00,$01,$07,$fe,$81,$00,$af,$00,$01,$07,$fe,$db
	dc.b	$00,$01,$07,$fe,$81,$00,$af,$00,$01,$07,$ff,$db,$00,$01,$07,$ff,$81,$00,$af,$00,$01,$0f,$ff,$db,$00,$01,$0f,$ff,$98,$00,$00,$08
	dc.b	$da,$00,$00,$08,$c1,$00,$01,$07,$ff,$db,$00,$01,$07,$ff,$89,$00,$00,$10,$fa,$00,$00,$02,$e2,$00,$00,$10,$fa,$00,$00,$02,$d8,$00
	dc.b	$02,$07,$ff,$80,$dc,$00,$02,$07,$ff,$80,$81,$00,$b0,$00,$02,$07,$ff,$c0,$dc,$00,$02,$07,$ff,$c0,$81,$00,$b0,$00,$02,$07,$ff,$c0
	dc.b	$dc,$00,$02,$07,$ff,$c0,$90,$00,$00,$20,$da,$00,$00,$20,$ca,$00,$02,$07,$ff,$e0,$dc,$00,$02,$07,$ff,$e0,$81,$00,$b0,$00,$02,$03
	dc.b	$ff,$f8,$dc,$00,$02,$03,$ff,$f8,$81,$00,$b0,$00,$02,$03,$ff,$fc,$dc,$00,$02,$03,$ff,$fc,$9f,$00,$00,$08,$da,$00,$00,$08,$bb,$00
	dc.b	$04,$01,$ff,$ff,$80,$c0,$de,$00,$04,$01,$ff,$ff,$80,$c0,$81,$00,$b2,$00,$00,$01,$fe,$ff,$00,$c0,$de,$00,$00,$01,$fe,$ff,$00,$c0
	dc.b	$81,$00,$b1,$00,$fe,$ff,$00,$80,$dd,$00,$fe,$ff,$00,$80,$9b,$00,$00,$21,$da,$00,$00,$21,$c0,$00,$02,$7f,$ff,$ff,$dc,$00,$02,$7f
	dc.b	$ff,$ff,$87,$00,$00,$01,$da,$00,$00,$01,$d3,$00,$02,$3f,$ff,$fe,$dc,$00,$02,$3f,$ff,$fe,$81,$00,$b0,$00,$02,$1f,$ff,$fc,$dc,$00
	dc.b	$02,$1f,$ff,$fc,$81,$00,$b0,$00,$02,$07,$ff,$f0,$dc,$00,$02,$07,$ff,$f0,$81,$00,$b0,$00,$02,$01,$ff,$c0,$dc,$00,$02,$01,$ff,$c0
	dc.b	$81,$00,$af,$00,$00,$08,$da,$00,$00,$08,$97,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$81,$00,$af,$00,$00,$80,$da,$00,$00,$80
	dc.b	$81,$00,$81,$00,$81,$00,$a8,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$ac,$00,$00,$10,$da,$00,$00,$10
	dc.b	$81,$00,$81,$00,$81,$00,$ae,$00,$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$d2,$00,$00,$08,$f2,$00,$00,$04,$ea,$00,$00,$08
	dc.b	$f2,$00,$00,$04,$81,$00,$bc,$00,$00,$80,$da,$00,$00,$80,$81,$00,$81,$00,$81,$00,$a5,$00,$00,$01,$da,$00,$00,$01,$81,$00,$a0,$00
	dc.b	$00,$04,$da,$00,$00,$04,$81,$00,$d0,$00,$00,$40,$e2,$00,$00,$10,$fa,$00,$00,$40,$e2,$00,$00,$10,$fa,$00,$00,$40,$81,$00,$81,$00
	dc.b	$81,$00,$ca,$00,$00,$01,$da,$00,$00,$01,$81,$00,$be,$00,$00,$20,$da,$00,$00,$20,$da,$00,$00,$20,$81,$00,$d2,$00,$00,$20,$e7,$00
	dc.b	$00,$02,$f5,$00,$00,$20,$e7,$00,$00,$02,$81,$00,$ab,$00,$00,$40,$da,$00,$00,$40,$81,$00,$cd,$00,$00,$10,$fb,$00,$00,$10,$f5,$00
	dc.b	$00,$40,$ee,$00,$00,$10,$fb,$00,$00,$10,$f5,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c4,$00,$00,$40,$da,$00,$00,$40
	dc.b	$81,$00,$a6,$00,$00,$02,$da,$00,$00,$02,$81,$00,$9a,$00,$00,$01,$da,$00,$00,$01,$81,$00,$c3,$00,$00,$08,$da,$00,$00,$08,$81,$00
	dc.b	$ab,$00,$00,$40,$da,$00,$00,$40,$81,$00,$a8,$00,$00,$02,$da,$00,$00,$02,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$bd,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b3,$00,$00,$80,$da,$00,$00,$80,$81,$00,$c3,$00,$00,$20
	dc.b	$da,$00,$00,$20,$81,$00,$b4,$00,$00,$20,$ee,$00,$00,$0c,$ee,$00,$00,$20,$ee,$00,$00,$0c,$ee,$00,$00,$20,$81,$00,$c2,$00,$00,$0c
	dc.b	$da,$00,$00,$0c,$81,$00,$ae,$00,$00,$0c,$f3,$00,$00,$08,$e9,$00,$00,$0c,$f3,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$91,$00
	dc.b	$00,$0c,$f3,$00,$00,$08,$e9,$00,$00,$0c,$f3,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$99,$00,$00,$10,$fa,$00,$00,$0c,$f3,$00
	dc.b	$00,$08,$f1,$00,$00,$10,$fa,$00,$00,$0c,$f3,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$91,$00,$00,$0c,$fe,$00,$00,$08,$f7,$00
	dc.b	$00,$08,$e9,$00,$00,$0c,$fe,$00,$00,$08,$f7,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$91,$00,$00,$0c,$f3,$00,$00,$08,$e9,$00
	dc.b	$00,$0c,$f3,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$91,$00,$00,$0c,$f3,$00,$00,$08,$e9,$00,$00,$0c,$f3,$00,$00,$08,$d6,$00
	dc.b	$00,$08,$da,$00,$00,$08,$91,$00,$00,$0c,$f3,$00,$00,$08,$e9,$00,$00,$0c,$f3,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$94,$00
	dc.b	$03,$03,$ff,$e0,$0c,$f3,$00,$03,$08,$00,$7f,$fc,$ef,$00,$03,$03,$ff,$e0,$0c,$f3,$00,$03,$08,$00,$7f,$fc,$eb,$00,$02,$03,$ff,$e0
	dc.b	$f2,$00,$03,$08,$00,$7f,$fc,$ef,$00,$02,$03,$ff,$e0,$f2,$00,$03,$08,$00,$7f,$fc,$9e,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c
	dc.b	$f5,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$f5,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff
	dc.b	$f0,$fc,$00,$02,$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff
	dc.b	$00,$fc,$9e,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$f5,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff
	dc.b	$e0,$0c,$f5,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01
	dc.b	$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff,$00,$fc,$9e,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$f5,$00,$00,$01
	dc.b	$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$f5,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff,$f0,$fc,$00,$02
	dc.b	$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$f4,$00,$00,$01,$fd,$ff,$00,$fc,$9e,$00
	dc.b	$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$03,$03
	dc.b	$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa,$00,$01,$1f,$fc
	dc.b	$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc
	dc.b	$9e,$00,$01,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00
	dc.b	$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa,$00,$01
	dc.b	$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff
	dc.b	$00,$fc,$9e,$00,$03,$ff,$f0,$00,$01,$fe,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$03
	dc.b	$ff,$f0,$00,$01,$fe,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f2,$00,$01,$ff,$f0,$fc,$00,$02
	dc.b	$03,$ff,$e0,$fa,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$f6,$00,$01,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa,$00,$01,$1f,$fc
	dc.b	$fd,$00,$00,$01,$fd,$ff,$00,$fc,$a5,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f,$fc
	dc.b	$fe,$00,$01,$01,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$03,$03,$ff,$e0,$0c,$fb,$00,$01,$1f
	dc.b	$fc,$fe,$00,$01,$01,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$02,$03,$ff,$e0
	dc.b	$fa,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$02,$03,$ff,$e0,$fa
	dc.b	$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$aa,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00,$03
	dc.b	$fd,$ff,$00,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00
	dc.b	$03,$fd,$ff,$00,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00
	dc.b	$ff,$f0,$fc,$00,$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03
	dc.b	$02,$00,$ff,$f0,$fc,$00,$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$aa,$00
	dc.b	$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00,$03,$fd,$ff,$00,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd
	dc.b	$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00,$03,$fd,$ff,$00,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc
	dc.b	$fd,$00,$00,$7f,$fe,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc,$fd,$00
	dc.b	$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc
	dc.b	$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$aa,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00,$03,$fd,$ff,$00,$f0
	dc.b	$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00,$00,$03,$fd,$ff,$00
	dc.b	$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0,$fc,$00
	dc.b	$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$01,$7f,$f8,$fe,$00,$03,$02,$00,$ff,$f0
	dc.b	$fc,$00,$05,$03,$ff,$ff,$f3,$ff,$f0,$fd,$00,$01,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$aa,$00,$00,$7f,$fe,$ff
	dc.b	$04,$f8,$02,$00,$ff,$f0,$fc,$00,$0b,$03,$ff,$ff,$00,$3f,$f0,$00,$ff,$f8,$00,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00
	dc.b	$7f,$fe,$ff,$04,$f8,$02,$00,$ff,$f0,$fc,$00,$0b,$03,$ff,$ff,$00,$3f,$f0,$00,$ff,$f8,$00,$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc
	dc.b	$fd,$00,$00,$7f,$fe,$00,$00,$7f,$fe,$ff,$04,$f8,$02,$00,$ff,$f0,$fc,$00,$0b,$03,$ff,$ff,$00,$3f,$f0,$00,$ff,$f8,$00,$1f,$fc,$fd
	dc.b	$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe,$ff,$04,$f8,$02,$00,$ff,$f0,$fc,$00,$0b,$03,$ff,$ff,$00,$3f,$f0,$00,$ff,$f8,$00
	dc.b	$1f,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$e8,$00,$00,$7f,$fe,$ff,$04,$f8
	dc.b	$02,$00,$ff,$f0,$fd,$00,$07,$40,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe
	dc.b	$ff,$04,$f8,$02,$00,$ff,$f0,$fd,$00,$07,$40,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fd,$00
	dc.b	$00,$7f,$fe,$00,$00,$7f,$fe,$ff,$04,$f8,$02,$00,$ff,$f0,$fc,$00,$06,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01
	dc.b	$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$fe,$ff,$04,$f8,$02,$00,$ff,$f0,$fc,$00,$06,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00
	dc.b	$00,$01,$fd,$ff,$00,$fc,$fd,$00,$00,$7f,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$03,$80,$00,$00,$7f,$fa,$ff,$00,$f0,$fc
	dc.b	$00,$06,$07,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$05,$fc,$00,$80,$00,$00,$7f,$fa,$ff,$00,$f0,$fc,$00
	dc.b	$06,$07,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$09,$fc,$00,$80,$00,$00,$7f,$80,$00,$00,$7f,$fa,$ff,$00
	dc.b	$f0,$fc,$00,$06,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$05,$fc,$00,$80,$00,$00,$7f,$fa,$ff,$00,$f0
	dc.b	$fc,$00,$06,$03,$ff,$ff,$00,$3f,$f0,$00,$fd,$ff,$00,$fc,$fd,$00,$00,$01,$fd,$ff,$05,$fc,$00,$80,$00,$00,$7f,$ed,$00,$01,$ff,$c0
	dc.b	$db,$00,$01,$ff,$c0,$eb,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd
	dc.b	$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc
	dc.b	$00,$f2,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f6,$ff
	dc.b	$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$fd,$ff,$ed,$00,$01
	dc.b	$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8
	dc.b	$01,$fd,$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff
	dc.b	$01,$fc,$00,$f2,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00
	dc.b	$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$fd,$ff,$ed
	dc.b	$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03
	dc.b	$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01
	dc.b	$fd,$ff,$01,$fc,$00,$f2,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01
	dc.b	$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$fd
	dc.b	$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc
	dc.b	$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff
	dc.b	$f8,$01,$fd,$ff,$01,$fc,$00,$f2,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd
	dc.b	$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc
	dc.b	$00,$fd,$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff
	dc.b	$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00
	dc.b	$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f2,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8
	dc.b	$01,$fd,$ff,$01,$fc,$00,$f6,$ff,$00,$f0,$fe,$00,$00,$1f,$fd,$ff,$03,$00,$3f,$f0,$00,$fd,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff
	dc.b	$01,$fc,$00,$fd,$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f3,$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00
	dc.b	$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f3,$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc
	dc.b	$00,$ef,$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f3,$ff,$01,$00,$1f,$fd,$ff
	dc.b	$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$fd,$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$f3
	dc.b	$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$f3,$ff,$01,$00,$1f,$fd,$ff,$01,$00
	dc.b	$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$ef,$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff
	dc.b	$f8,$01,$fd,$ff,$01,$fc,$00,$f3,$ff,$01,$00,$1f,$fd,$ff,$01,$00,$3f,$fb,$ff,$05,$fc,$00,$03,$ff,$f8,$01,$fd,$ff,$01,$fc,$00,$fd
	dc.b	$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$ed,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$e4,$ff,$01,$00,$3f,$fb,$ff,$02
	dc.b	$fc,$00,$03,$e0,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$e4,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$f4,$ff,$ed,$00,$01,$ff,$c0
	dc.b	$db,$00,$01,$ff,$c0,$eb,$00,$ed,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$e4,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$e0,$ff,$01
	dc.b	$00,$3f,$fb,$ff,$02,$fc,$00,$03,$e4,$ff,$01,$00,$3f,$fb,$ff,$02,$fc,$00,$03,$f4,$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff,$c0,$eb
	dc.b	$00,$ed,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$d7,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$eb,$ff,$ed,$00,$01,$ff,$c0,$db,$00,$01,$ff
	dc.b	$c0,$eb,$00,$ed,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$d7,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$eb,$ff,$ed,$00,$01,$ff,$c0,$db,$00
	dc.b	$01,$ff,$c0,$eb,$00,$ed,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$d7,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$eb,$ff,$ed,$00,$01,$ff,$c0
	dc.b	$db,$00,$01,$ff,$c0,$eb,$00,$ed,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$d7,$ff,$01,$00,$3f,$db,$ff,$01,$00,$3f,$eb,$ff,$ed,$00,$01
	dc.b	$ff,$c0,$db,$00,$01,$ff,$c0,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$d8,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00
	dc.b	$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$d8,$ff,$02
	dc.b	$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc
	dc.b	$ff,$02,$e0,$00,$01,$d8,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb
	dc.b	$00,$ee,$ff,$02,$e0,$66,$61,$dc,$ff,$02,$e0,$66,$61,$d8,$ff,$02,$e6,$66,$61,$dc,$ff,$02,$e6,$66,$61,$eb,$ff,$ee,$00,$02,$19,$99
	dc.b	$9e,$dc,$00,$02,$19,$99,$9e,$eb,$00,$ee,$ff,$02,$e0,$66,$61,$dc,$ff,$02,$e0,$66,$61,$d8,$ff,$02,$e6,$66,$61,$dc,$ff,$02,$e6,$66
	dc.b	$61,$eb,$ff,$ee,$00,$02,$19,$99,$9e,$dc,$00,$02,$19,$99,$9e,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$d8,$ff,$02
	dc.b	$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc
	dc.b	$ff,$02,$e0,$00,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$e1,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff
	dc.b	$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$e1
	dc.b	$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$06,$01,$dc
	dc.b	$ff,$02,$e0,$06,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e6,$66,$61,$e1,$ff,$00,$fe,$fd,$ff,$02,$e6,$66,$61,$eb,$ff,$ee,$00,$02,$19,$99
	dc.b	$9e,$dc,$00,$02,$19,$99,$9e,$eb,$00,$ee,$ff,$02,$e0,$06,$01,$dc,$ff,$02,$e0,$06,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e6,$66,$61,$e1
	dc.b	$ff,$00,$fe,$fd,$ff,$02,$e6,$66,$61,$eb,$ff,$ee,$00,$02,$19,$99,$9e,$dc,$00,$02,$19,$99,$9e,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc
	dc.b	$ff,$02,$e0,$00,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$e1,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff
	dc.b	$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc,$ff,$02,$e0,$00,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$e1
	dc.b	$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$eb,$00,$ee,$ff,$02,$e0,$00,$01,$dc
	dc.b	$ff,$02,$e0,$00,$01,$dd,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$e1,$ff,$00,$fe,$fd,$ff,$02,$e0,$00,$01,$eb,$ff,$ee,$00,$02,$1f,$ff
	dc.b	$fe,$dc,$00,$02,$1f,$ff,$fe,$dd,$00,$00,$01,$fd,$00,$00,$06,$df,$00,$00,$01,$fd,$00,$00,$06,$d6,$00,$02,$06,$66,$60,$dc,$00,$02
	dc.b	$06,$66,$60,$d8,$00,$02,$19,$99,$9e,$dc,$00,$02,$19,$99,$9e,$dd,$00,$00,$01,$fd,$00,$00,$06,$df,$00,$00,$01,$fd,$00,$00,$06,$d6
	dc.b	$00,$02,$06,$66,$60,$dc,$00,$02,$06,$66,$60,$d8,$00,$02,$19,$99,$9e,$dc,$00,$02,$19,$99,$9e,$dd,$00,$00,$01,$da,$00,$00,$01,$81
	dc.b	$00,$fd,$00,$02,$1f,$ff,$fe,$dc,$00,$02,$1f,$ff,$fe,$81,$00,$b6,$00,$fe,$ff,$05,$fe,$00,$00,$1f,$ff,$fe,$e2,$00,$fe,$ff,$05,$fe
	dc.b	$00,$00,$1f,$ff,$fe,$81,$00,$b6,$00,$fe,$ff,$05,$fe,$00,$00,$1f,$ff,$fe,$e2,$00,$fe,$ff,$05,$fe,$00,$00,$1f,$ff,$fe,$81,$00,$b6
	dc.b	$00,$fe,$ff,$05,$fe,$00,$00,$1f,$ff,$fe,$e2,$00,$fe,$ff,$05,$fe,$00,$00,$1f,$ff,$fe,$de,$00,$fe,$30,$dc,$00,$fe,$30,$d8,$00,$fe
	dc.b	$33,$00,$30,$dd,$00,$fe,$33,$00,$30,$d9,$00,$fe,$cc,$05,$ce,$00,$00,$1f,$ff,$fe,$e2,$00,$fe,$cc,$05,$ce,$00,$00,$1f,$ff,$fe,$de
	dc.b	$00,$fe,$30,$dc,$00,$fe,$30,$dc,$00,$00,$3c,$fe,$00,$fe,$33,$00,$30,$e1,$00,$00,$3c,$fe,$00,$fe,$33,$00,$30,$dd,$00,$00,$3c,$fe
	dc.b	$00,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$e7,$00,$00,$3c,$fe,$00,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$8f,$00,$00,$3c,$da
	dc.b	$00,$00,$3c,$d6,$00,$00,$3c,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e7,$00,$00,$3c,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$ff,$00,$f0,$8f,$00,$00,$7e,$da,$00,$00,$7e,$d6,$00,$00,$7e,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e7,$00,$00,$7e,$fe
	dc.b	$00,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$d8,$00,$02,$0c,$c0,$c0,$dc,$00,$02,$0c,$c0,$c0,$e3,$00,$00,$7e,$f8,$00,$fe,$cc,$00
	dc.b	$c0,$e7,$00,$00,$7e,$f8,$00,$fe,$cc,$00,$c0,$e3,$00,$00,$7e,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$e7,$00,$00,$7e,$fe
	dc.b	$00,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$dd,$00,$00,$33,$fd,$00,$02,$0c,$c0,$c0,$e1,$00,$00,$33,$fd,$00,$02,$0c,$c0,$c0,$e3
	dc.b	$00,$00,$7e,$fe,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e7,$00,$00,$7e,$fe,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e3
	dc.b	$00,$00,$7e,$fe,$00,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$e7,$00,$00,$7e,$fe,$00,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$dd
	dc.b	$00,$00,$33,$da,$00,$00,$33,$dc,$00,$00,$7e,$fe,$00,$fe,$33,$00,$30,$e1,$00,$00,$7e,$fe,$00,$fe,$33,$00,$30,$dd,$00,$00,$7e,$fe
	dc.b	$00,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$e7,$00,$00,$7e,$fe,$00,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$8f,$00,$00,$7e,$da
	dc.b	$00,$00,$7e,$d6,$00,$00,$7e,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e7,$00,$00,$7e,$fe,$00,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$ff,$00,$f0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$de,$00,$00,$03,$fe,$ff,$00,$f0,$86,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00
	dc.b	$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$fa
	dc.b	$00,$02,$c0,$0c,$c0,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$02,$c0,$0c,$c0,$d9,$00,$fe,$cc,$00,$c0,$dd,$00,$fe,$cc,$00,$c0,$e4
	dc.b	$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$33,$00,$30,$e4,$00,$00,$03,$fe,$ff,$02,$f0,$30,$03,$fc,$00,$02,$c0,$0c,$c0,$e8,$00,$00,$03,$fe,$ff,$02,$f0,$30,$03,$fc,$00,$02
	dc.b	$c0,$0c,$c0,$df,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e3,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e4,$00,$00,$03,$fe
	dc.b	$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$e4
	dc.b	$00,$06,$03,$3f,$33,$33,$f0,$30,$03,$e0,$00,$06,$03,$3f,$33,$33,$f0,$30,$03,$db,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$e1,$00,$fe
	dc.b	$cc,$00,$c0,$fe,$33,$00,$30,$de,$00,$00,$03,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$33,$00
	dc.b	$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$e4,$00,$04,$03,$3f,$33,$33,$f0,$de,$00,$04,$03,$3f,$33,$33,$f0,$d9,$00,$fe,$cc,$00
	dc.b	$c0,$dd,$00,$fe,$cc,$00,$c0,$da,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$33,$00
	dc.b	$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$de,$00,$00,$03,$fe,$ff,$00,$f0,$86,$00,$00,$03,$fe
	dc.b	$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e4
	dc.b	$00,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$01,$0c,$0c,$e6,$00,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$01,$0c,$0c,$d7,$00,$fe,$cc,$00,$c0,$dd
	dc.b	$00,$fe,$cc,$00,$c0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe
	dc.b	$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$e4,$00,$00,$03,$fe,$ff,$03,$f0,$30,$03,$33,$fe,$00,$01,$0c,$0c,$e6,$00,$00,$03,$fe,$ff,$03
	dc.b	$f0,$30,$03,$33,$fe,$00,$01,$0c,$0c,$dd,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e3,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00
	dc.b	$c0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00
	dc.b	$03,$fe,$33,$00,$30,$eb,$00,$00,$10,$fb,$00,$07,$03,$f3,$3f,$3f,$f0,$30,$03,$33,$e8,$00,$00,$10,$fb,$00,$07,$03,$f3,$3f,$3f,$f0
	dc.b	$30,$03,$33,$e8,$00,$00,$10,$f6,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$e1,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$de,$00,$00,$03,$fe
	dc.b	$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$eb
	dc.b	$00,$00,$10,$fb,$00,$04,$03,$f3,$3f,$3f,$f0,$e5,$00,$00,$10,$fb,$00,$04,$03,$f3,$3f,$3f,$f0,$e5,$00,$00,$10,$f6,$00,$fe,$cc,$00
	dc.b	$c0,$dd,$00,$fe,$cc,$00,$c0,$da,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$33,$00
	dc.b	$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$eb,$00,$00,$10,$fb,$00,$00,$03,$fe,$ff,$00,$f0,$e5,$00,$00,$10,$fb,$00,$00,$03,$fe
	dc.b	$ff,$00,$f0,$e5,$00,$00,$10,$a3,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$e8,$00,$00,$03,$fe,$ff,$00
	dc.b	$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$eb,$00,$00,$10,$fb,$00,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$02,$c0,$0c,$c0,$ef,$00,$00
	dc.b	$10,$fb,$00,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$02,$c0,$0c,$c0,$ef,$00,$00,$10,$ec,$00,$fe,$cc,$00,$c0,$dd,$00,$fe,$cc,$00,$c0,$e4
	dc.b	$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$e8,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$33,$00,$30,$eb,$00,$00,$10,$fb,$00,$00,$03,$fe,$ff,$04,$f0,$33,$30,$03,$30,$fe,$00,$02,$c0,$0c,$c0,$ef,$00,$00,$10,$fb,$00,$00
	dc.b	$03,$fe,$ff,$04,$f0,$33,$30,$03,$30,$fe,$00,$02,$c0,$0c,$c0,$ef,$00,$00,$10,$f2,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e3
	dc.b	$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$e4,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$e8,$00,$00
	dc.b	$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$eb,$00,$00,$10,$fb,$00,$08,$03,$33,$ff,$3f,$30,$33,$30,$03,$30,$e9
	dc.b	$00,$00,$10,$fb,$00,$08,$03,$33,$ff,$3f,$30,$33,$30,$03,$30,$e9,$00,$00,$10,$f6,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$00
	dc.b	$1e,$ee,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$00,$1e,$eb,$00,$00,$03,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00
	dc.b	$f0,$fb,$00,$00,$1e,$ef,$00,$00,$03,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$1e,$f2,$00,$00,$10,$fb
	dc.b	$00,$04,$03,$33,$ff,$3f,$30,$e5,$00,$00,$10,$fb,$00,$04,$03,$33,$ff,$3f,$30,$e5,$00,$00,$10,$f6,$00,$fe,$cc,$00,$c0,$f1,$00,$00
	dc.b	$1e,$ee,$00,$fe,$cc,$00,$c0,$f1,$00,$00,$1e,$eb,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00
	dc.b	$1e,$ef,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$1e,$f2,$00,$00,$10,$fb,$00,$00,$03,$fe
	dc.b	$ff,$00,$f0,$e5,$00,$00,$10,$fb,$00,$00,$03,$fe,$ff,$00,$f0,$e5,$00,$00,$10,$e2,$00,$00,$3f,$da,$00,$00,$3f,$eb,$00,$00,$03,$fe
	dc.b	$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$3f,$ef,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$ff,$00,$f0,$fb,$00,$00,$3f,$f2,$00,$00,$10,$fb,$00,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$02,$c0,$00,$c0,$ef,$00,$00,$10,$fb,$00,$00
	dc.b	$03,$fe,$ff,$00,$f0,$fa,$00,$02,$c0,$00,$c0,$ef,$00,$00,$10,$ec,$00,$fe,$cc,$00,$c0,$fb,$00,$00,$3f,$e4,$00,$fe,$cc,$00,$c0,$fb
	dc.b	$00,$00,$3f,$eb,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fb,$00,$00,$3f,$ef,$00,$00,$03,$fe,$ff,$00
	dc.b	$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fb,$00,$00,$3f,$f2,$00,$00,$11,$fb,$00,$00,$03,$fe,$ff,$04,$f0,$30,$33,$00,$30,$fe
	dc.b	$00,$02,$c0,$00,$c0,$ef,$00,$00,$11,$fb,$00,$00,$03,$fe,$ff,$04,$f0,$30,$33,$00,$30,$fe,$00,$02,$c0,$00,$c0,$ef,$00,$00,$11,$f2
	dc.b	$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$fb,$00,$00,$3f,$ea,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$fb,$00,$00,$3f,$eb
	dc.b	$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$fb,$00,$00,$3f,$ef,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02
	dc.b	$ce,$00,$03,$fe,$33,$00,$30,$fb,$00,$00,$3f,$f3,$00,$fe,$ff,$00,$f0,$fd,$00,$08,$03,$ff,$33,$ff,$f0,$30,$33,$00,$30,$eb,$00,$00
	dc.b	$3f,$fe,$ff,$00,$f0,$fd,$00,$08,$03,$ff,$33,$ff,$f0,$30,$33,$00,$30,$eb,$00,$00,$3f,$fe,$ff,$00,$f0,$f8,$00,$fe,$cc,$00,$c0,$fe
	dc.b	$33,$00,$30,$f5,$00,$00,$3f,$ee,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$00,$3f,$f3,$00,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe
	dc.b	$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$3f,$f8,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$33,$00
	dc.b	$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$3f,$f8,$00,$00,$3f,$fe,$ff,$00,$f0,$fe,$ff,$00,$f0,$fd,$00,$04,$03,$ff
	dc.b	$33,$ff,$f0,$e7,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$04,$03,$ff,$33,$ff,$f0,$e7,$00,$00,$3f,$fe,$ff,$00,$f0,$f8,$00,$fe,$cc,$00
	dc.b	$c0,$f1,$00,$00,$3f,$ee,$00,$fe,$cc,$00,$c0,$f1,$00,$00,$3f,$f3,$00,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02
	dc.b	$fe,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$00,$3f,$f8,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00
	dc.b	$03,$fe,$ff,$00,$f0,$fb,$00,$00,$3f,$f8,$00,$00,$3f,$fe,$ff,$00,$f0,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$f3,$00,$01
	dc.b	$80,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$f3,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc
	dc.b	$00,$00,$3f,$fe,$ff,$00,$f0,$ad,$00,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc
	dc.b	$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$f0,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00
	dc.b	$f0,$fc,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$04,$f0,$f3,$f3,$3f,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fb,$00,$04
	dc.b	$c0,$c0,$00,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$04,$33,$f3,$f3,$3f,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fb,$00
	dc.b	$04,$c0,$c0,$00,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$04,$33,$f3,$f3,$3f,$30,$fe,$cc,$00,$c0,$f2,$00,$fe,$cc,$00
	dc.b	$c0,$f6,$00,$00,$1e,$fd,$00,$00,$0c,$fe,$cc,$00,$c0,$f2,$00,$fe,$cc,$00,$c0,$f6,$00,$00,$1e,$fd,$00,$00,$0c,$fe,$cc,$00,$c0,$fe
	dc.b	$33,$00,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$1e,$fd,$00
	dc.b	$fd,$33,$00,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$1e,$fd
	dc.b	$00,$fd,$33,$04,$30,$f3,$f3,$3f,$30,$fd,$00,$00,$03,$fe,$ff,$02,$f0,$30,$30,$fd,$00,$04,$c0,$c0,$00,$00,$10,$fe,$00,$01,$80,$01
	dc.b	$fd,$ff,$00,$e0,$fc,$00,$04,$33,$f3,$f3,$3f,$30,$fd,$00,$00,$03,$fe,$ff,$02,$f0,$30,$30,$fd,$00,$04,$c0,$c0,$00,$00,$10,$fe,$00
	dc.b	$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$04,$33,$f3,$f3,$3f,$30,$fe,$cc,$00,$c0,$f8,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$f6
	dc.b	$00,$00,$1e,$fd,$00,$00,$0c,$fe,$cc,$00,$c0,$f8,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$f6,$00,$00,$1e,$fd,$00,$00,$0c,$fe
	dc.b	$cc,$00,$c0,$fe,$33,$00,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff,$01
	dc.b	$e0,$1e,$fd,$00,$fd,$33,$00,$30,$fd,$00,$00,$03,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff
	dc.b	$01,$e0,$1e,$fd,$00,$fd,$33,$00,$30,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$02,$f0,$30,$30,$f9,$00,$00,$10,$fe,$00,$06,$80,$01,$99
	dc.b	$9f,$ff,$9f,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$02,$f0,$30,$30,$f9,$00,$00,$10,$fe,$00,$06,$80,$01,$99,$9f
	dc.b	$ff,$9f,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$f0,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$fd,$66,$01,$00,$3f,$f3,$00,$fe,$cc
	dc.b	$00,$c0,$fe,$33,$00,$30,$f5,$00,$fd,$66,$01,$00,$3f,$f8,$00,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03
	dc.b	$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce
	dc.b	$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$00,$f0,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33
	dc.b	$00,$f0,$f7,$00,$00,$10,$fe,$00,$06,$80,$01,$99,$9f,$ff,$9f,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$00,$f0,$f7
	dc.b	$00,$00,$10,$fe,$00,$06,$80,$01,$99,$9f,$ff,$9f,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$f0,$f8,$00,$fe,$cc,$00,$c0,$f1,$00,$fd,$66,$01
	dc.b	$00,$3f,$f3,$00,$fe,$cc,$00,$c0,$f1,$00,$fd,$66,$01,$00,$3f,$f8,$00,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe
	dc.b	$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$01,$f0,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff
	dc.b	$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$00,$f0,$fe,$ff,$01,$f0,$1f,$fa,$ff
	dc.b	$00,$f0,$f7,$00,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$f0,$1f,$fa,$ff,$00,$f0,$f7,$00,$00,$10
	dc.b	$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$f0,$df,$00,$00,$3f,$da,$00,$00,$3f,$f8,$00,$fe,$ff,$01,$f0,$1f
	dc.b	$fa,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$01,$f0,$1f
	dc.b	$fa,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$00,$3f,$fe,$ff,$09,$f0,$3f
	dc.b	$33,$ff,$f0,$1f,$f9,$f9,$ff,$9f,$fe,$ff,$00,$f0,$fb,$00,$04,$c0,$cc,$0c,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc,$00,$09
	dc.b	$33,$3f,$33,$ff,$f0,$1f,$f9,$f9,$ff,$9f,$fe,$ff,$00,$f0,$fb,$00,$04,$c0,$cc,$0c,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0,$fc
	dc.b	$00,$04,$33,$3f,$33,$ff,$f0,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f7,$00,$fe,$cc,$00,$c0,$f6,$00,$00,$3f,$fd,$00,$00,$0c,$fe,$cc
	dc.b	$01,$c0,$06,$fe,$66,$00,$60,$f7,$00,$fe,$cc,$00,$c0,$f6,$00,$00,$3f,$fd,$00,$00,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$30,$19,$fe,$99
	dc.b	$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$fd,$33,$01,$30,$19
	dc.b	$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$33,$00,$30,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$fd,$33,$09
	dc.b	$30,$3f,$33,$ff,$fc,$1f,$f9,$f9,$ff,$9f,$fe,$ff,$01,$f0,$30,$fc,$00,$04,$c0,$cc,$0c,$00,$10,$fe,$00,$01,$80,$01,$fd,$ff,$00,$e0
	dc.b	$fc,$00,$09,$33,$3f,$33,$ff,$fc,$1f,$f9,$f9,$ff,$9f,$fe,$ff,$01,$f0,$30,$fc,$00,$04,$c0,$cc,$0c,$00,$10,$fe,$00,$01,$80,$01,$fd
	dc.b	$ff,$00,$e0,$fc,$00,$04,$33,$3f,$33,$ff,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0
	dc.b	$f6,$00,$00,$3f,$fd,$00,$00,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$00,$c0,$f6,$00,$00
	dc.b	$3f,$fd,$00,$00,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00,$30
	dc.b	$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33
	dc.b	$00,$30,$fc,$00,$00,$01,$fd,$ff,$01,$e0,$3f,$fd,$00,$fd,$33,$00,$3c,$fe,$ff,$01,$fc,$1f,$fc,$ff,$03,$3f,$3f,$f0,$30,$f8,$00,$00
	dc.b	$10,$fe,$00,$06,$80,$01,$9f,$f9,$99,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fc,$ff,$03,$3f,$3f,$f0,$30,$f8,$00,$00,$10,$fe
	dc.b	$00,$06,$80,$01,$9f,$f9,$99,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$fd,$66,$00
	dc.b	$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f5,$00,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f
	dc.b	$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01
	dc.b	$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe
	dc.b	$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fc,$ff,$02,$3f,$3f,$f0,$f7,$00,$00,$10,$fe,$00,$06,$80,$01,$9f,$f9,$99,$99,$e0,$fc,$00,$00,$3f
	dc.b	$fe,$ff,$01,$fc,$1f,$fc,$ff,$02,$3f,$3f,$f0,$f7,$00,$00,$10,$fe,$00,$06,$80,$01,$9f,$f9,$99,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00
	dc.b	$fc,$f8,$00,$fe,$cc,$00,$c0,$f1,$00,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$f1,$00,$fd,$66,$00,$01,$fd,$ff,$00
	dc.b	$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99,$00,$e1
	dc.b	$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$00,$f0,$fc,$00,$00,$01,$fd,$99
	dc.b	$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f7,$00,$00,$10,$fd,$00,$00,$01,$fd,$ff,$00,$e0
	dc.b	$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f7,$00,$00,$10,$fd,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00
	dc.b	$fc,$e8,$00,$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$e7,$00,$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc
	dc.b	$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$03,$f0,$00,$00,$7f,$fa,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f
	dc.b	$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$03,$f0,$00,$00,$7f,$fa,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe
	dc.b	$ff,$08,$fc,$33,$33,$3f,$fc,$19,$9f,$9f,$f9,$fd,$ff,$00,$f0,$fb,$00,$09,$c0,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$05,$e0
	dc.b	$66,$00,$66,$66,$60,$fe,$33,$05,$3f,$fc,$19,$9f,$9f,$f9,$fd,$ff,$00,$f0,$fb,$00,$09,$c0,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd
	dc.b	$ff,$05,$e0,$66,$00,$66,$66,$60,$fe,$33,$01,$3f,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f7,$00,$fe,$cc,$06,$c0,$00,$00,$7f,$ff
	dc.b	$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f7,$00,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe
	dc.b	$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03
	dc.b	$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$00,$03,$fe
	dc.b	$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$08,$3c,$33,$33,$3f,$fc,$19,$9f,$9f,$f9,$fd,$ff,$10,$f0,$30,$33,$00,$30,$00
	dc.b	$00,$c0,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$05,$e0,$66,$00,$66,$66,$60,$fe,$33,$05,$3f,$fc,$19,$9f,$9f,$f9,$fd,$ff,$10
	dc.b	$f0,$30,$33,$00,$30,$00,$00,$c0,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$05,$e0,$66,$00,$66,$66,$60,$fe,$33,$01,$3f,$fc,$fe
	dc.b	$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff
	dc.b	$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$00,$00,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00
	dc.b	$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33
	dc.b	$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$00,$03,$fe,$33,$00
	dc.b	$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01,$fc,$1f,$fc,$ff,$06,$33,$ff,$30,$30,$33,$00,$30,$fc,$00,$0b,$0f
	dc.b	$ff,$ff,$98,$00,$19,$99,$9f,$ff,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fc,$ff,$06,$33,$ff,$30,$30,$33,$00,$30,$fc,$00
	dc.b	$0b,$0f,$ff,$ff,$98,$00,$19,$99,$9f,$ff,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f9
	dc.b	$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$00,$30,$f9,$00,$03,$7f,$ff,$ff,$fe,$fd
	dc.b	$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fb,$ff,$03,$e6,$66,$66
	dc.b	$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$00,$03,$fb,$ff,$03,$e6,$66
	dc.b	$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fc,$ff,$02,$33,$ff,$30,$f8,$00,$0b,$07,$ff,$e7
	dc.b	$98,$00,$19,$99,$9f,$ff,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fc,$ff,$02,$33,$ff,$30,$f8,$00,$0b,$07,$ff,$e7,$98,$00
	dc.b	$19,$99,$9f,$ff,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$f8,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd
	dc.b	$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$f8,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc
	dc.b	$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1
	dc.b	$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$00,$03,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67
	dc.b	$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$07,$ff,$e7,$80,$00,$00,$01
	dc.b	$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$07,$ff,$e7,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc
	dc.b	$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00
	dc.b	$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0
	dc.b	$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01
	dc.b	$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$09,$fc,$3f,$33,$ff,$fc,$19,$ff,$99,$9f,$9f,$fe,$ff
	dc.b	$00,$f0,$f8,$00,$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0f,$e0,$06,$00,$60,$06,$00,$33,$3f,$33,$ff,$fc,$19,$ff,$99,$9f,$9f,$fe
	dc.b	$ff,$00,$f0,$f8,$00,$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$06,$00,$60,$06,$00,$33,$3f,$33,$ff,$fc,$fe,$cc,$01,$c0,$06
	dc.b	$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0
	dc.b	$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00
	dc.b	$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c
	dc.b	$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd
	dc.b	$33,$09,$3c,$3f,$33,$ff,$fc,$19,$ff,$99,$9f,$9f,$fe,$ff,$03,$f0,$30,$33,$30,$fb,$00,$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0f
	dc.b	$e0,$06,$00,$60,$06,$00,$33,$3f,$33,$ff,$fc,$19,$ff,$99,$9f,$9f,$fe,$ff,$03,$f0,$30,$33,$30,$fb,$00,$06,$0f,$ff,$ff,$80,$00,$00
	dc.b	$01,$fd,$ff,$0a,$e0,$06,$00,$60,$06,$00,$33,$3f,$33,$ff,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc
	dc.b	$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33
	dc.b	$02,$30,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19
	dc.b	$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe
	dc.b	$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01
	dc.b	$fc,$1f,$fd,$ff,$06,$33,$f3,$33,$30,$30,$33,$30,$fb,$00,$0b,$0f,$ff,$ff,$80,$01,$80,$19,$f9,$f9,$99,$f9,$e0,$fc,$00,$00,$3f,$fe
	dc.b	$ff,$01,$fc,$1f,$fd,$ff,$06,$33,$f3,$33,$30,$30,$33,$30,$fb,$00,$0b,$0f,$ff,$ff,$80,$01,$80,$19,$f9,$f9,$99,$f9,$e0,$fc,$00,$00
	dc.b	$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc
	dc.b	$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01
	dc.b	$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff
	dc.b	$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe
	dc.b	$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$33,$f3,$33,$30,$f8,$00,$0b,$06,$66,$7f,$80,$01,$80,$19,$f9,$f9,$99,$f9,$e0,$fc,$00
	dc.b	$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$33,$f3,$33,$30,$f8,$00,$0b,$06,$66,$7f,$80,$01,$80,$19,$f9,$f9,$99,$f9,$e0,$fc,$00,$00
	dc.b	$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff
	dc.b	$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc
	dc.b	$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1
	dc.b	$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67
	dc.b	$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$66,$7f,$80,$00,$00,$01
	dc.b	$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$66,$7f,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc
	dc.b	$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00
	dc.b	$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0
	dc.b	$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01
	dc.b	$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$08,$fc,$f3,$33,$33,$fc,$1f,$ff,$9f,$f9,$fd,$ff,$00
	dc.b	$f0,$f9,$00,$07,$cc,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fe,$00,$0a,$60,$60,$33,$f3,$33,$33,$fc,$1f,$ff,$9f,$f9,$fd,$ff
	dc.b	$00,$f0,$f9,$00,$07,$cc,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fe,$00,$06,$60,$60,$33,$f3,$33,$33,$fc,$fe,$cc,$01,$c0,$06
	dc.b	$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0
	dc.b	$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00
	dc.b	$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c
	dc.b	$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd
	dc.b	$33,$08,$3c,$f3,$33,$33,$fc,$1f,$ff,$9f,$f9,$fd,$ff,$00,$f0,$f9,$00,$07,$cc,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fe,$00
	dc.b	$0a,$60,$60,$33,$f3,$33,$33,$fc,$1f,$ff,$9f,$f9,$fd,$ff,$00,$f0,$f9,$00,$07,$cc,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fe
	dc.b	$00,$06,$60,$60,$33,$f3,$33,$33,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc,$fe,$cc,$06,$c0,$00,$00
	dc.b	$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc,$fe,$cc
	dc.b	$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff
	dc.b	$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00
	dc.b	$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f
	dc.b	$f3,$3f,$f0,$f8,$00,$0b,$0f,$ff,$ff,$81,$99,$81,$99,$99,$f9,$ff,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f,$f3
	dc.b	$3f,$f0,$f8,$00,$0b,$0f,$ff,$ff,$81,$99,$81,$99,$99,$f9,$ff,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe
	dc.b	$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc
	dc.b	$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce
	dc.b	$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02
	dc.b	$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f
	dc.b	$f3,$3f,$f0,$f8,$00,$0b,$06,$66,$7f,$81,$99,$81,$99,$99,$f9,$ff,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f,$f3
	dc.b	$3f,$f0,$f8,$00,$0b,$06,$66,$7f,$81,$99,$81,$99,$99,$f9,$ff,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fd
	dc.b	$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f
	dc.b	$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30
	dc.b	$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff
	dc.b	$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00
	dc.b	$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$66,$7f,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc
	dc.b	$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$66,$7f,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc
	dc.b	$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff
	dc.b	$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9
	dc.b	$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1
	dc.b	$fd,$ff,$01,$fc,$3f,$fe,$ff,$09,$fc,$3f,$ff,$f3,$3c,$1f,$99,$ff,$99,$9f,$fe,$ff,$00,$f0,$fb,$00,$09,$cc,$00,$0c,$0f,$ff,$ff,$80
	dc.b	$00,$00,$01,$fd,$ff,$0f,$e0,$66,$60,$00,$66,$00,$33,$3f,$ff,$f3,$3c,$1f,$99,$ff,$99,$9f,$fe,$ff,$00,$f0,$fb,$00,$09,$cc,$00,$0c
	dc.b	$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$66,$60,$00,$66,$00,$33,$3f,$ff,$f3,$3c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00
	dc.b	$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9
	dc.b	$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19
	dc.b	$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe
	dc.b	$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$09,$3c,$3f,$ff,$f3
	dc.b	$3c,$1f,$99,$ff,$99,$9f,$fe,$ff,$10,$f0,$00,$00,$33,$30,$00,$00,$cc,$00,$0c,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0f,$e0,$66,$60
	dc.b	$00,$66,$00,$33,$3f,$ff,$f3,$3c,$1f,$99,$ff,$99,$9f,$fe,$ff,$10,$f0,$00,$00,$33,$30,$00,$00,$cc,$00,$0c,$0f,$ff,$ff,$80,$00,$00
	dc.b	$01,$fd,$ff,$0a,$e0,$66,$60,$00,$66,$00,$33,$3f,$ff,$f3,$3c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc
	dc.b	$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33
	dc.b	$02,$30,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19
	dc.b	$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe
	dc.b	$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01
	dc.b	$fc,$1f,$fd,$ff,$fe,$f3,$06,$30,$00,$00,$33,$30,$03,$30,$fe,$00,$06,$0f,$ff,$ff,$80,$00,$18,$01,$fd,$9f,$00,$e0,$fc,$00,$00,$3f
	dc.b	$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$06,$30,$00,$00,$33,$30,$03,$30,$fe,$00,$06,$0f,$ff,$ff,$80,$00,$18,$01,$fd,$9f,$00,$e0,$fc
	dc.b	$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff
	dc.b	$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe
	dc.b	$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f
	dc.b	$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc
	dc.b	$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$00,$30,$fd,$00,$01,$03,$30,$fe,$00,$06,$06,$66,$67,$80,$00,$18,$01,$fd
	dc.b	$9f,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$00,$30,$fd,$00,$01,$03,$30,$fe,$00,$06,$06,$66,$67,$80,$00,$18
	dc.b	$01,$fd,$9f,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff
	dc.b	$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd
	dc.b	$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67
	dc.b	$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff
	dc.b	$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00
	dc.b	$06,$06,$66,$67,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$66,$67,$80
	dc.b	$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00
	dc.b	$00,$01,$fd,$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe
	dc.b	$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc
	dc.b	$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$07,$fc,$33,$f3,$33
	dc.b	$3c,$19,$f9,$99,$fc,$ff,$00,$f0,$fb,$00,$09,$c0,$0c,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0d,$e0,$60,$60,$66,$00,$60,$33,$33
	dc.b	$f3,$33,$3c,$19,$f9,$99,$fc,$ff,$00,$f0,$fb,$00,$09,$c0,$0c,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$60,$60,$66,$00,$60
	dc.b	$33,$33,$f3,$33,$3c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00
	dc.b	$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00
	dc.b	$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33
	dc.b	$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00
	dc.b	$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$07,$3c,$33,$f3,$33,$3c,$19,$f9,$99,$fc,$ff,$03,$f0,$00,$00,$03,$fe,$00,$09,$c0,$0c
	dc.b	$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0d,$e0,$60,$60,$66,$00,$60,$33,$33,$f3,$33,$3c,$19,$f9,$99,$fc,$ff,$03,$f0,$00,$00,$03
	dc.b	$fe,$00,$09,$c0,$0c,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$60,$60,$66,$00,$60,$33,$33,$f3,$33,$3c,$fe,$cc,$01,$c0,$06
	dc.b	$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe
	dc.b	$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff
	dc.b	$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff
	dc.b	$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00
	dc.b	$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$06,$30,$00,$00,$03,$00,$00,$30,$fe,$00,$0b,$0f,$ff,$ff
	dc.b	$80,$00,$18,$19,$99,$f9,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$06,$30,$00,$00,$03,$00,$00,$30,$fe,$00
	dc.b	$0b,$0f,$ff,$ff,$80,$00,$18,$19,$99,$f9,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f
	dc.b	$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f
	dc.b	$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff
	dc.b	$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb
	dc.b	$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$00,$30,$fc,$00
	dc.b	$00,$30,$fe,$00,$0b,$06,$7f,$ff,$80,$00,$18,$19,$99,$f9,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$f3,$00,$30
	dc.b	$fc,$00,$00,$30,$fe,$00,$0b,$06,$7f,$ff,$80,$00,$18,$19,$99,$f9,$f9,$99,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00
	dc.b	$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fd,$00
	dc.b	$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33
	dc.b	$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f
	dc.b	$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe
	dc.b	$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$7f,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff
	dc.b	$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$06,$7f,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01
	dc.b	$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f
	dc.b	$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66
	dc.b	$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff
	dc.b	$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$08,$fc,$ff,$33,$33,$fc,$1f,$ff,$99,$f9,$fd,$ff,$00,$f0,$fb,$00,$09,$c0,$00,$00,$cf,$ff,$ff
	dc.b	$80,$00,$00,$01,$fd,$ff,$0e,$e0,$66,$06,$00,$06,$00,$33,$ff,$33,$33,$fc,$1f,$ff,$99,$f9,$fd,$ff,$00,$f0,$fb,$00,$09,$c0,$00,$00
	dc.b	$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$66,$06,$00,$06,$00,$33,$ff,$33,$33,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00
	dc.b	$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9
	dc.b	$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19
	dc.b	$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe
	dc.b	$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$08,$3c,$ff,$33,$33
	dc.b	$fc,$1f,$ff,$99,$f9,$fd,$ff,$10,$f0,$00,$30,$00,$30,$00,$00,$c0,$00,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0e,$e0,$66,$06,$00
	dc.b	$06,$00,$33,$ff,$33,$33,$fc,$1f,$ff,$99,$f9,$fd,$ff,$10,$f0,$00,$30,$00,$30,$00,$00,$c0,$00,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd
	dc.b	$ff,$0a,$e0,$66,$06,$00,$06,$00,$33,$ff,$33,$33,$fc,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30,$0f,$fc,$fe,$cc
	dc.b	$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$fd,$00,$fe,$33,$02,$30
	dc.b	$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99
	dc.b	$00,$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00
	dc.b	$9f,$fe,$ff,$00,$f0,$fe,$cc,$02,$ce,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe,$ff,$01,$fc,$1f
	dc.b	$fd,$ff,$08,$3f,$3f,$ff,$30,$00,$30,$00,$30,$03,$fd,$00,$0b,$0f,$ff,$ff,$80,$01,$80,$01,$9f,$f9,$9f,$f9,$e0,$fc,$00,$00,$3f,$fe
	dc.b	$ff,$01,$fc,$1f,$fd,$ff,$08,$3f,$3f,$ff,$30,$00,$30,$00,$30,$03,$fd,$00,$0b,$0f,$ff,$ff,$80,$01,$80,$01,$9f,$f9,$9f,$f9,$e0,$fc
	dc.b	$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff
	dc.b	$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fe,$33,$02,$30,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe
	dc.b	$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f
	dc.b	$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$cc,$02,$ce,$0c,$cf,$fb,$ff,$03,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc
	dc.b	$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f,$3f,$ff,$30,$fd,$00,$00,$03,$fd,$00,$0b,$0f,$e7,$ff,$80,$01,$80,$01,$9f
	dc.b	$f9,$9f,$f9,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$03,$3f,$3f,$ff,$30,$fd,$00,$00,$03,$fd,$00,$0b,$0f,$e7,$ff,$80,$01
	dc.b	$80,$01,$9f,$f9,$9f,$f9,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f8,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98
	dc.b	$7f,$ff,$ff,$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$f7,$00,$fe,$cc,$00,$c0,$fd,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff
	dc.b	$fe,$fd,$66,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf,$fe,$ff,$06,$f6
	dc.b	$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fd,$ff,$fe,$33,$00,$30,$fe,$ff,$02,$fe,$0c,$cf
	dc.b	$fe,$ff,$06,$f6,$66,$67,$e6,$66,$66,$67,$fd,$99,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0
	dc.b	$f8,$00,$06,$0f,$e7,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$0f,$e7
	dc.b	$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe
	dc.b	$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fe,$00,$06,$09,$99,$98,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc
	dc.b	$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff
	dc.b	$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$fd,$ff,$02,$f6,$66,$67,$f9,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$07,$fc,$f3
	dc.b	$3f,$f3,$3c,$19,$f9,$f9,$fc,$ff,$00,$f0,$fb,$00,$09,$0c,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0d,$e0,$00,$60,$00,$00,$60
	dc.b	$33,$f3,$3f,$f3,$3c,$19,$f9,$f9,$fc,$ff,$00,$f0,$fb,$00,$09,$0c,$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$00,$60,$00
	dc.b	$00,$60,$33,$f3,$3f,$f3,$3c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd
	dc.b	$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe
	dc.b	$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff
	dc.b	$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe
	dc.b	$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$07,$3c,$f3,$3f,$f3,$3c,$19,$f9,$f9,$fc,$ff,$00,$f0,$fb,$00,$09,$0c,$cc,$00
	dc.b	$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0d,$e0,$00,$60,$00,$00,$60,$33,$f3,$3f,$f3,$3c,$19,$f9,$f9,$fc,$ff,$00,$f0,$fb,$00,$09,$0c
	dc.b	$cc,$00,$cf,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$0a,$e0,$00,$60,$00,$00,$60,$33,$f3,$3f,$f3,$3c,$fe,$cc,$01,$c0,$06,$fe,$66,$00,$60
	dc.b	$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$01,$c0,$06,$fe,$66,$00
	dc.b	$60,$f9,$00,$01,$0f,$fc,$fe,$cc,$06,$c0,$00,$00,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$01,$fc,$0c,$fe,$cc,$00,$c0,$fe,$33,$01
	dc.b	$3c,$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$01,$3c
	dc.b	$19,$fe,$99,$00,$9f,$fe,$ff,$00,$f0,$fe,$ff,$02,$fe,$0f,$ff,$fe,$33,$00,$3f,$f7,$ff,$00,$e1,$fd,$99,$00,$9c,$fd,$33,$00,$3c,$fe
	dc.b	$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa
	dc.b	$ff,$00,$f0,$f8,$00,$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fb,$00
	dc.b	$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00
	dc.b	$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$f2,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa
	dc.b	$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$f2,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00
	dc.b	$06,$0f,$ff,$ff,$80,$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$f8,$00,$06,$0f,$ff,$ff,$80
	dc.b	$00,$00,$01,$fd,$ff,$00,$e0,$fc,$00,$00,$3f,$fe,$ff,$00,$fc,$f0,$00,$01,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd
	dc.b	$ff,$00,$fc,$ef,$00,$01,$0f,$fc,$fb,$00,$03,$7f,$ff,$ff,$fe,$fd,$00,$00,$01,$fd,$ff,$00,$fc,$fc,$00,$fe,$ff,$01,$fc,$1f,$fa,$ff
	dc.b	$00,$f0,$fe,$ff,$01,$fe,$0f,$f2,$ff,$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$01,$fc,$1f,$fa,$ff,$00,$f0,$fe,$ff,$01,$fe,$0f,$f2,$ff
	dc.b	$00,$e1,$fd,$ff,$01,$fc,$3f,$fe,$ff,$00,$fc,$ad,$ff,$81,$00,$d9,$00,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81
	dc.b	$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$9d,$ff,$52,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ac,$ff,$52,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81
	dc.b	$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$9c,$ff,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a1,$00,$80
	even
bg_harlem	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$d4,$00
	dc.b	$03,$40,$00,$00,$02,$f7,$00,$00,$02,$e8,$00,$03,$40,$00,$00,$02,$f7,$00,$00,$02,$81,$00,$c2,$00,$00,$02,$fb,$00,$00,$40,$f4,$00
	dc.b	$02,$04,$00,$40,$f1,$00,$00,$02,$fb,$00,$00,$40,$f4,$00,$02,$04,$00,$40,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b4,$00,$00,$02
	dc.b	$da,$00,$00,$02,$81,$00,$81,$00,$81,$00,$d1,$00,$00,$20,$da,$00,$00,$20,$da,$00,$00,$20,$81,$00,$b8,$00,$01,$40,$20,$db,$00,$01
	dc.b	$40,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c6,$00,$00,$04,$da,$00,$00,$04,$81,$00,$81,$00,$e7,$00,$00,$08
	dc.b	$da,$00,$00,$08,$81,$00,$01,$00,$02,$da,$00,$00,$02,$d9,$00,$01,$01,$f0,$db,$00,$01,$01,$f0,$81,$00,$fa,$00,$00,$04,$fd,$00,$00
	dc.b	$20,$df,$00,$00,$04,$fd,$00,$00,$20,$e4,$00,$01,$07,$e0,$db,$00,$01,$07,$e0,$81,$00,$e2,$00,$00,$04,$da,$00,$00,$04,$f7,$00,$01
	dc.b	$0f,$c0,$db,$00,$01,$0f,$c0,$81,$00,$af,$00,$01,$1f,$80,$db,$00,$01,$1f,$80,$81,$00,$af,$00,$01,$3f,$80,$db,$00,$01,$3f,$80,$81
	dc.b	$00,$f9,$00,$00,$80,$da,$00,$00,$80,$e0,$00,$00,$7f,$da,$00,$00,$7f,$81,$00,$ae,$00,$00,$ff,$da,$00,$00,$ff,$81,$00,$ae,$00,$00
	dc.b	$ff,$da,$00,$00,$ff,$81,$00,$af,$00,$01,$01,$ff,$db,$00,$01,$01,$ff,$81,$00,$e4,$00,$00,$20,$da,$00,$00,$20,$f5,$00,$01,$01,$ff
	dc.b	$db,$00,$01,$01,$ff,$81,$00,$af,$00,$01,$01,$ff,$db,$00,$01,$01,$ff,$81,$00,$af,$00,$01,$01,$ff,$db,$00,$01,$01,$ff,$81,$00,$f9
	dc.b	$00,$00,$08,$f9,$00,$00,$01,$f8,$00,$00,$08,$ed,$00,$00,$08,$f9,$00,$00,$01,$f8,$00,$00,$08,$f3,$00,$01,$01,$ff,$db,$00,$01,$01
	dc.b	$ff,$81,$00,$af,$00,$01,$03,$ff,$db,$00,$01,$03,$ff,$81,$00,$af,$00,$02,$01,$ff,$80,$dc,$00,$02,$01,$ff,$80,$81,$00,$b0,$00,$02
	dc.b	$01,$ff,$80,$dc,$00,$02,$01,$ff,$80,$81,$00,$f9,$00,$00,$20,$da,$00,$00,$20,$e1,$00,$02,$01,$ff,$c0,$dc,$00,$02,$01,$ff,$c0,$81
	dc.b	$00,$b0,$00,$02,$01,$ff,$e0,$dc,$00,$02,$01,$ff,$e0,$81,$00,$f5,$00,$02,$01,$00,$08,$dc,$00,$02,$01,$00,$08,$e7,$00,$02,$01,$ff
	dc.b	$f0,$dc,$00,$02,$01,$ff,$f0,$81,$00,$af,$00,$01,$ff,$f8,$db,$00,$01,$ff,$f8,$81,$00,$af,$00,$03,$ff,$fe,$00,$80,$dd,$00,$03,$ff
	dc.b	$fe,$00,$80,$81,$00,$b1,$00,$02,$7f,$ff,$ff,$dc,$00,$02,$7f,$ff,$ff,$81,$00,$b0,$00,$02,$3f,$ff,$fe,$dc,$00,$02,$3f,$ff,$fe,$81
	dc.b	$00,$b0,$00,$02,$1f,$ff,$fc,$dc,$00,$02,$1f,$ff,$fc,$81,$00,$b0,$00,$02,$0f,$ff,$f8,$dc,$00,$02,$0f,$ff,$f8,$81,$00,$b0,$00,$02
	dc.b	$07,$ff,$f0,$dc,$00,$02,$07,$ff,$f0,$81,$00,$b0,$00,$02,$01,$ff,$c0,$dc,$00,$02,$01,$ff,$c0,$81,$00,$af,$00,$00,$08,$da,$00,$00
	dc.b	$08,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$f5,$00,$00,$20,$da,$00,$00,$20,$81,$00,$ab,$00,$00,$08,$da,$00,$00,$08,$81,$00,$81
	dc.b	$00,$81,$00,$d1,$00,$00,$04,$f7,$00,$00,$08,$e5,$00,$00,$04,$f7,$00,$00,$08,$e5,$00,$00,$04,$81,$00,$81,$00,$81,$00,$cf,$00,$00
	dc.b	$04,$da,$00,$00,$04,$81,$00,$81,$00,$81,$00,$b8,$00,$00,$80,$da,$00,$00,$80,$81,$00,$9b,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$b6,$00,$00,$80,$da,$00,$00,$80,$81,$00,$b0,$00,$00,$40,$da,$00,$00,$40,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$be,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$ae,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$c6,$00,$00,$20,$da,$00,$00,$20,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$c4,$00,$00,$02,$da,$00,$00,$02,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$b7,$00,$00,$10,$da
	dc.b	$00,$00,$10,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$9d,$00,$00,$01,$fd,$00,$00,$40,$df,$00,$00,$01,$fd,$00,$00,$40,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$df,$00,$00,$08,$da,$00,$00,$08,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$ac,$00,$00,$02,$da,$00,$00,$02,$81,$00,$81,$00,$81,$00,$a0,$00,$00,$10,$da,$00,$00,$10,$81,$00,$81,$00,$81,$00,$c7,$00,$00
	dc.b	$08,$e9,$00,$00,$40,$f3,$00,$00,$08,$e9,$00,$00,$40,$81,$00,$c6,$00,$00,$08,$da,$00,$00,$08,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$ad,$00,$00,$80,$f4,$00,$00,$08,$e8,$00,$00,$80,$f4,$00,$00,$08,$81,$00,$81,$00,$81,$00,$b5,$00,$00,$02,$da,$00,$00,$02,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$c8,$00,$00,$80,$da,$00,$00,$80,$81,$00,$a2,$00,$00,$02,$da,$00,$00,$02,$81
	dc.b	$00,$c3,$00,$00,$80,$da,$00,$00,$80,$81,$00,$9a,$00,$00,$08,$da,$00,$00,$08,$d6,$00,$00,$08,$da,$00,$00,$08,$85,$00,$03,$02,$40
	dc.b	$00,$08,$dd,$00,$03,$02,$40,$00,$08,$d9,$00,$03,$02,$00,$00,$08,$dd,$00,$03,$02,$00,$00,$08,$85,$00,$03,$02,$00,$00,$08,$dd,$00
	dc.b	$03,$02,$00,$00,$08,$d9,$00,$03,$02,$00,$00,$08,$dd,$00,$03,$02,$00,$00,$08,$85,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$e7
	dc.b	$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$e3,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$e7,$00,$03,$02,$00,$00,$08,$f9,$00
	dc.b	$01,$7f,$ff,$97,$00,$04,$ff,$c0,$00,$00,$08,$fe,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$ef,$00,$04,$ff,$c0,$00,$00,$08,$fe
	dc.b	$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$eb,$00,$01,$ff,$c0,$fb,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$ef,$00,$01,$ff
	dc.b	$c0,$fb,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$99,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff
	dc.b	$f1,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$ed,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$03,$02,$00,$00
	dc.b	$08,$f9,$00,$01,$7f,$ff,$f1,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$03,$02,$00,$00,$08,$f9,$00,$01,$7f,$ff,$a0,$00,$00,$08,$fb,$00,$03
	dc.b	$0f,$ff,$ff,$c0,$fb,$00,$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$f8,$00,$00,$08,$fb,$00,$03,$0f,$ff,$ff,$c0,$fb,$00
	dc.b	$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$ed,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00
	dc.b	$01,$7f,$ff,$f1,$00,$03,$0f,$ff,$ff,$c0,$fb,$00,$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$a1,$00,$00,$40,$fa,$00,$06
	dc.b	$0f,$ff,$ff,$c0,$00,$00,$20,$fe,$00,$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$f9,$00,$00,$40,$fa,$00,$06,$0f,$ff,$ff
	dc.b	$c0,$00,$00,$20,$fe,$00,$06,$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$ed,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$20,$fe,$00,$06
	dc.b	$02,$00,$00,$08,$00,$00,$80,$fc,$00,$01,$7f,$ff,$f1,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$20,$fe,$00,$06,$02,$00,$00,$08,$00,$00,$80
	dc.b	$fc,$00,$01,$7f,$ff,$99,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$20,$fe,$00,$01,$02,$01,$fe,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$01,$7f,$ff
	dc.b	$f1,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$20,$fe,$00,$01,$02,$01,$fe,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$01,$7f,$ff,$ed,$00,$06,$0f,$ff
	dc.b	$ff,$c0,$00,$00,$20,$fe,$00,$01,$02,$01,$fe,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$01,$7f,$ff,$f1,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$20
	dc.b	$fe,$00,$01,$02,$01,$fe,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$01,$7f,$ff,$a8,$00,$01,$40,$80,$fd,$00,$00,$1f,$fe,$ff,$fc,$00,$09,$0f
	dc.b	$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$04,$7f,$ff,$00,$40,$80,$fd,$00,$00,$1f,$fe,$ff,$fc,$00
	dc.b	$09,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$07,$7f,$ff,$00,$40,$80,$00,$00,$40,$fc,$00,$00
	dc.b	$1f,$fe,$ff,$fc,$00,$09,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$fc,$00
	dc.b	$00,$1f,$fe,$ff,$fc,$00,$09,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$aa
	dc.b	$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$0a,$10,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$8b,$ff,$ff,$fe,$00
	dc.b	$03,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$0a,$10,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc,$ff,$03,$c0,$8b,$ff,$ff
	dc.b	$fe,$00,$03,$7f,$ff,$00,$40,$fe,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$0a,$10,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00,$07,$fc
	dc.b	$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$0a,$10,$0f,$ff,$ff,$c0,$00,$00,$20,$00,$00
	dc.b	$07,$fc,$ff,$03,$c0,$83,$ff,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$aa,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff
	dc.b	$02,$00,$00,$07,$f8,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff
	dc.b	$fe,$00,$03,$7f,$ff,$00,$40,$fe,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$fe,$00
	dc.b	$03,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$aa
	dc.b	$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$06,$40,$00,$00,$7f,$ff,$00,$40,$fc,$00
	dc.b	$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$06,$40,$00,$00,$7f,$ff,$00,$40,$fe,$00,$00,$40,$fc,$00,$00
	dc.b	$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01
	dc.b	$10,$0f,$fb,$ff,$02,$00,$00,$07,$f8,$ff,$fe,$00,$03,$7f,$ff,$00,$40,$aa,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f
	dc.b	$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07
	dc.b	$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$fe,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff
	dc.b	$05,$f8,$00,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00
	dc.b	$40,$aa,$00,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$fc
	dc.b	$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$fe,$00,$00,$40,$fc,$00,$00
	dc.b	$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$fc,$00,$00,$1f,$fe,$ff,$fd,$00,$01
	dc.b	$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$05,$f8,$00,$7f,$ff,$00,$40,$ab,$00,$02,$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$fd,$00,$01
	dc.b	$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02
	dc.b	$00,$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe,$ff,$04,$c0,$00,$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00
	dc.b	$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$fd,$00,$01,$10,$0f,$fb,$ff,$02,$00,$00,$07,$f7,$ff,$02
	dc.b	$f8,$00,$7f,$fe,$ff,$00,$c0,$ac,$00,$02,$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f7,$ff
	dc.b	$02,$f8,$00,$7f,$fe,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe
	dc.b	$ff,$04,$c0,$00,$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe,$ff
	dc.b	$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f7,$ff,$02,$f8,$00,$7f,$fe,$ff,$00,$c0,$ac,$00,$02
	dc.b	$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f1,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00
	dc.b	$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f1,$ff,$04,$c0,$00,$ff,$ff,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00
	dc.b	$00,$07,$f1,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$03,$00,$04,$00,$3f,$f9,$ff,$02,$00,$00,$07,$f1,$ff,$00,$c0,$ac,$00,$05,$ff,$ff
	dc.b	$c0,$00,$00,$07,$fc,$ff,$03,$00,$04,$00,$3f,$e6,$ff,$03,$c0,$00,$00,$07,$fc,$ff,$03,$00,$04,$00,$3f,$e6,$ff,$07,$c0,$00,$ff,$ff
	dc.b	$c0,$00,$00,$07,$fc,$ff,$03,$00,$04,$00,$3f,$e6,$ff,$03,$c0,$00,$00,$07,$fc,$ff,$03,$00,$04,$00,$3f,$e6,$ff,$00,$c0,$ac,$00,$f6
	dc.b	$ff,$03,$00,$04,$00,$3f,$dd,$ff,$03,$00,$04,$00,$3f,$d9,$ff,$03,$00,$04,$00,$3f,$dd,$ff,$03,$00,$04,$00,$3f,$e4,$ff,$ad,$00,$81
	dc.b	$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9,$ff,$ad,$00,$81,$ff,$d9
	dc.b	$ff,$ad,$00,$81,$ff,$d9,$ff,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$84,$00,$fa,$ff,$00,$f0,$e1,$00,$fa,$ff,$00,$f0,$81,$00,$b5,$00,$fa,$ff,$00,$f0,$e1
	dc.b	$00,$fa,$ff,$00,$f0,$89,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00
	dc.b	$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00
	dc.b	$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00,$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00
	dc.b	$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00
	dc.b	$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00
	dc.b	$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00,$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00
	dc.b	$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$dd,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00
	dc.b	$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$f6,$00,$01,$ff,$f0,$ea,$00,$00,$3f,$fb,$ff
	dc.b	$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$00,$f0,$ea,$00,$00,$3f,$fb,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$00,$f0,$e6,$00,$00,$c0,$fb,$00
	dc.b	$00,$30,$e1,$00,$00,$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$f6,$00,$01,$ff,$f0,$f6
	dc.b	$00,$00,$3f,$fe,$ff,$00,$80,$fa,$00,$00,$3f,$fb,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$00,$f0,$f6,$00,$00,$3f,$fe,$ff,$00,$80,$fa
	dc.b	$00,$00,$3f,$fb,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$00,$f0,$e6,$00,$00,$c0,$fb,$00,$00,$30,$e1,$00,$00,$c0,$fb,$00,$00,$30,$dd
	dc.b	$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$f6,$00,$04,$ff,$f0,$00,$00,$0f,$ed,$ff,$00,$3f,$fb,$ff,$00,$c0,$fd
	dc.b	$00,$00,$1f,$fe,$ff,$03,$f0,$00,$00,$0f,$ed,$ff,$00,$3f,$fb,$ff,$00,$c0,$fd,$00,$00,$1f,$fe,$ff,$00,$f0,$e6,$00,$00,$c0,$fb,$00
	dc.b	$00,$30,$e1,$00,$00,$c0,$fb,$00,$00,$30,$dd,$00,$00,$3f,$fb,$ff,$00,$c0,$e1,$00,$00,$3f,$fb,$ff,$00,$c0,$f2,$00,$00,$0f,$ed,$ff
	dc.b	$ee,$00,$00,$0f,$ed,$ff,$ee,$00,$01,$ff,$e0,$ea,$00,$fa,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$e0,$ea,$00,$fa,$ff,$00,$f0,$fd
	dc.b	$00,$00,$0f,$fe,$ff,$04,$e0,$00,$00,$ff,$e0,$de,$00,$00,$0f,$fe,$ff,$00,$e0,$de,$00,$00,$0f,$fe,$ff,$00,$e0,$fb,$00,$00,$0f,$f9
	dc.b	$ff,$00,$c0,$fe,$00,$00,$7f,$fa,$ff,$ee,$00,$00,$0f,$f9,$ff,$00,$c0,$fe,$00,$00,$7f,$fa,$ff,$ee,$00,$01,$ff,$e0,$f6,$00,$00,$1f
	dc.b	$fe,$ff,$f9,$00,$fa,$ff,$00,$f0,$fd,$00,$00,$0f,$fe,$ff,$00,$e0,$f6,$00,$00,$1f,$fe,$ff,$f9,$00,$fa,$ff,$00,$f0,$fd,$00,$00,$0f
	dc.b	$fe,$ff,$04,$e0,$00,$00,$ff,$e0,$f6,$00,$00,$1f,$fe,$ff,$ed,$00,$00,$0f,$fe,$ff,$00,$e0,$f6,$00,$00,$1f,$fe,$ff,$ed,$00,$00,$0f
	dc.b	$fe,$ff,$00,$e0,$fe,$00,$03,$1f,$ff,$ff,$f0,$fe,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$03,$3e,$1f,$00,$03,$fe,$ff,$00,$f0,$fa,$00
	dc.b	$03,$1f,$ff,$ff,$f0,$fe,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$03,$3e,$1f,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$00,$1f,$fe,$ff,$03,$e0
	dc.b	$00,$00,$07,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00,$00,$0f,$fe
	dc.b	$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00
	dc.b	$00,$0f,$fe,$ff,$07,$e0,$00,$00,$ff,$e0,$00,$00,$07,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04
	dc.b	$f3,$c1,$e0,$f0,$78,$fa,$00,$00,$0f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$04,$f3,$c1,$e0,$f0,$78,$fa,$00,$00,$0f,$fe,$ff,$00,$e0,$fe,$00,$03,$1f,$ff,$ff,$f0,$fe,$00,$00,$01,$fd,$ff,$00,$80,$f5
	dc.b	$00,$03,$3e,$1f,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$03,$1f,$ff,$ff,$f0,$fe,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$03,$3e,$1f,$00,$03
	dc.b	$fe,$ff,$00,$f0,$fa,$00,$00,$1f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00,$00,$0f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00,$00,$0f,$fe,$ff,$07,$e0,$00,$00,$ff,$e0,$00,$00,$07,$fe,$ff,$00,$f9,$fd,$ff,$00
	dc.b	$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$78,$fa,$00,$00,$0f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$78,$fa,$00,$00,$0f,$fe,$ff,$00,$e0,$fe,$00,$03,$1f
	dc.b	$ff,$ff,$f0,$fe,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$03,$3e,$1f,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$03,$1f,$ff,$ff,$f0,$fe,$00,$00
	dc.b	$01,$fd,$ff,$00,$80,$f5,$00,$03,$3e,$1f,$00,$03,$fe,$ff,$00,$f0,$fa,$00,$00,$1f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f8,$fd
	dc.b	$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00,$00,$0f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff
	dc.b	$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f8,$fa,$00,$00,$0f,$fe,$ff,$07,$e0,$00,$00
	dc.b	$ff,$e0,$00,$00,$07,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$78,$fa,$00,$00
	dc.b	$0f,$fe,$ff,$03,$e0,$00,$00,$07,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$78
	dc.b	$fa,$00,$00,$0f,$fe,$ff,$00,$e0,$f7,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$01,$3e,$1f,$fc,$00,$00,$0f,$fe,$ff,$00,$e0,$f7,$00,$00
	dc.b	$01,$fd,$ff,$00,$80,$f5,$00,$01,$3e,$1f,$fc,$00,$00,$0f,$fe,$ff,$00,$e0,$fb,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f
	dc.b	$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0,$fe,$00,$00,$0f,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8
	dc.b	$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0,$fe,$00,$00,$0f,$f7,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$00,$e0,$fe,$00,$00,$0f
	dc.b	$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$00,$e0
	dc.b	$fe,$00,$00,$0f,$fb,$ff,$f9,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$01,$3e,$1f,$fc,$00,$00,$0f,$fe,$ff,$00,$e0,$f7,$00,$00,$01,$fd
	dc.b	$ff,$00,$80,$f5,$00,$01,$3e,$1f,$fc,$00,$00,$0f,$fe,$ff,$00,$e0,$fb,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff
	dc.b	$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0,$fe,$00,$00,$0f,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00
	dc.b	$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0,$fe,$00,$00,$0f,$fb,$ff,$00,$c1,$fe,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$00,$e0,$fe,$00
	dc.b	$03,$0f,$07,$83,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0
	dc.b	$79,$fe,$ff,$00,$e0,$fe,$00,$03,$0f,$07,$83,$c1,$fe,$ff,$f9,$00,$00,$01,$fd,$ff,$01,$81,$f0,$f6,$00,$01,$3e,$1f,$fc,$00,$00,$0f
	dc.b	$fe,$ff,$00,$e0,$f7,$00,$00,$01,$fd,$ff,$01,$81,$f0,$f6,$00,$01,$3e,$1f,$fc,$00,$00,$0f,$fe,$ff,$00,$e0,$fb,$00,$fd,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0,$fe,$00,$00,$0f
	dc.b	$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e0
	dc.b	$fe,$00,$00,$0f,$fb,$ff,$00,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$04,$9e,$0f,$07,$83,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3
	dc.b	$c1,$e0,$f0,$79,$fe,$ff,$00,$e0,$fe,$00,$03,$0f,$07,$83,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$04,$9e,$0f,$07,$83,$3f,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$00,$e0,$fe,$00,$03,$0f,$07,$83,$c1,$fe,$ff,$fc,$00,$09,$7c,$3e,$00,$01,$ff
	dc.b	$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01,$0f,$80,$ed,$00,$09,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01
	dc.b	$f0,$fe,$00,$01,$0f,$80,$ee,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0
	dc.b	$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff
	dc.b	$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe
	dc.b	$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$fc,$00,$09,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01,$0f,$80,$ed
	dc.b	$00,$09,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01,$0f,$80,$ee,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8
	dc.b	$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00
	dc.b	$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff
	dc.b	$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e
	dc.b	$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$fc,$00,$09,$7c,$3e,$00,$01,$ff
	dc.b	$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01,$0f,$80,$ed,$00,$09,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01
	dc.b	$f0,$fe,$00,$01,$0f,$80,$ee,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0
	dc.b	$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff
	dc.b	$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe
	dc.b	$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$0e,$00,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01
	dc.b	$0f,$80,$f1,$00,$0d,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$01,$0f,$80,$f1,$00,$02
	dc.b	$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$19,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07
	dc.b	$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$1c,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0
	dc.b	$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$15,$cf,$07,$83
	dc.b	$c1,$f8,$3c,$1f,$00,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$f3
	dc.b	$00,$0d,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$f3,$00,$02,$07
	dc.b	$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83
	dc.b	$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9
	dc.b	$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$15,$cf,$07,$83,$c1
	dc.b	$f8,$3c,$1f,$00,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$f3,$00
	dc.b	$0d,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$f3,$00,$02,$07,$c0
	dc.b	$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c
	dc.b	$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0
	dc.b	$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$15,$cf,$07,$83,$c1,$f8
	dc.b	$3c,$1f,$00,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$fa,$00,$01
	dc.b	$7c,$3e,$fc,$00,$0d,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$81,$f0,$fe,$00,$01,$01,$f0,$fe,$00,$03,$0f,$80,$00,$3e,$fa
	dc.b	$00,$01,$7c,$3e,$fc,$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$24,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0
	dc.b	$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$24,$f8
	dc.b	$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27
	dc.b	$83,$c1,$e0,$cf,$fe,$ff,$10,$f8,$3c,$1f,$00,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$80,$fd,$00,$01,$01,$f0,$fe,$00,$03
	dc.b	$0f,$80,$00,$3e,$fa,$00,$01,$7c,$3e,$fc,$00,$0c,$07,$c0,$00,$00,$7c,$3e,$00,$01,$ff,$f0,$78,$3f,$80,$fd,$00,$01,$01,$f0,$fe,$00
	dc.b	$03,$0f,$80,$00,$3e,$fa,$00,$01,$7c,$3e,$fc,$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00
	dc.b	$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87
	dc.b	$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$0c,$f8,$3c,$1f
	dc.b	$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe,$ff,$14,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1
	dc.b	$e0,$cf,$fe,$ff,$0c,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe,$ff,$14,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0
	dc.b	$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa
	dc.b	$00,$01,$7c,$3e,$fc,$00,$01,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$01,$7c,$3e,$fc,$00,$02,$07,$c0,$00
	dc.b	$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff
	dc.b	$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0,$fc
	dc.b	$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$01,$7c,$3e,$fc,$00,$01,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00
	dc.b	$3e,$fa,$00,$01,$7c,$3e,$fc,$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd
	dc.b	$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c
	dc.b	$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1
	dc.b	$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$08,$7c,$3e,$00,$00,$f8,$00
	dc.b	$00,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$09,$7c,$3e,$00,$00,$f8,$00,$00,$07,$c0,$00,$fd,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf
	dc.b	$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$cf,$fb,$ff,$04,$c1,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$13,$f3
	dc.b	$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$12,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$07,$83,$c1,$f8,$3c,$1f,$f9,$00,$00,$01,$fd,$ff,$00
	dc.b	$80,$f5,$00,$00,$3e,$fa,$00,$04,$7c,$3e,$00,$00,$f8,$f8,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$04,$7c,$3e,$00,$00
	dc.b	$f8,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$04,$9e,$0f,$07,$83,$3f,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff
	dc.b	$04,$9e,$0f,$07,$83,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$fa
	dc.b	$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f8,$00,$04,$7c,$3e,$00,$00,$f8,$f9,$00,$06,$1f,$01
	dc.b	$e0,$ff,$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f8,$00,$04,$7c,$3e,$00,$00,$f8,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05
	dc.b	$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff
	dc.b	$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c
	dc.b	$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$fa,$00,$06,$1f,$01,$e0,$ff
	dc.b	$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f8,$00,$04,$7c,$3e,$00,$00,$f8,$f9,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd
	dc.b	$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f8,$00,$04,$7c,$3e,$00,$00,$f8,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f
	dc.b	$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8
	dc.b	$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00
	dc.b	$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0
	dc.b	$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$fa,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$06
	dc.b	$01,$f0,$f8,$00,$00,$0f,$80,$f4,$00,$00,$f8,$f9,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f4
	dc.b	$00,$00,$f8,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e
	dc.b	$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83
	dc.b	$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf
	dc.b	$07,$83,$c1,$fe,$ff,$03,$00,$00,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f4,$00
	dc.b	$00,$f8,$fe,$00,$01,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$06,$01,$f0,$f8,$00,$00,$0f,$80,$f4,$00,$00,$f8,$fe
	dc.b	$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$19,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f
	dc.b	$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$1c,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1
	dc.b	$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$0a,$cf,$07
	dc.b	$83,$c1,$f8,$3c,$1f,$00,$00,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8,$00,$00,$0f,$80,$00,$3e,$f6
	dc.b	$00,$00,$f8,$fe,$00,$01,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8,$00,$00,$0f,$80,$00,$3e,$f6,$00
	dc.b	$00,$f8,$fe,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78
	dc.b	$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1,$f8,$3c,$1f
	dc.b	$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff
	dc.b	$0a,$cf,$07,$83,$c1,$f8,$3c,$1f,$00,$00,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8,$00,$00,$0f,$80
	dc.b	$00,$3e,$f6,$00,$00,$f8,$fe,$00,$01,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8,$00,$00,$0f,$80,$00
	dc.b	$3e,$f6,$00,$00,$f8,$fe,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9
	dc.b	$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1
	dc.b	$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78
	dc.b	$27,$fe,$ff,$0a,$cf,$07,$83,$c1,$f8,$3c,$1f,$00,$00,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8,$00
	dc.b	$00,$0f,$80,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd,$00,$08,$01,$f0,$f8
	dc.b	$00,$00,$0f,$80,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff
	dc.b	$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f
	dc.b	$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$24,$f8,$3c
	dc.b	$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83
	dc.b	$c1,$e0,$cf,$fe,$ff,$24,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1
	dc.b	$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$06,$f8,$3c,$1f,$00,$00,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80,$fd
	dc.b	$00,$08,$01,$f0,$f8,$00,$00,$0f,$80,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fe,$00,$06,$1f,$01,$e0,$ff,$f8,$3f,$80
	dc.b	$fd,$00,$08,$01,$f0,$f8,$00,$00,$0f,$80,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f
	dc.b	$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7
	dc.b	$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00
	dc.b	$cf,$fa,$ff,$0c,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe,$ff,$14,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0
	dc.b	$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$0c,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe,$ff,$14,$3c,$1e,$0f,$07
	dc.b	$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$06,$f8,$3c,$1f,$00,$00,$03,$e0,$fd,$00,$00,$01,$fd
	dc.b	$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fd,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00
	dc.b	$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f
	dc.b	$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c,$1f,$e7,$fe
	dc.b	$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe
	dc.b	$ff,$06,$f8,$3c,$1f,$00,$00,$03,$e0,$fd,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0
	dc.b	$fd,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$02,$7c,$00,$1f,$fc,$00,$01,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd
	dc.b	$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa
	dc.b	$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0
	dc.b	$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c
	dc.b	$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$06,$f8,$3c,$1f,$3e,$00,$03,$e0,$fd,$00,$00,$01,$fd,$ff,$00,$80,$f5
	dc.b	$00,$00,$3e,$fa,$00,$09,$7c,$00,$1f,$00,$00,$7c,$3e,$00,$03,$e0,$fd,$00,$00,$01,$fd,$ff,$00,$80,$f5,$00,$00,$3e,$fa,$00,$09,$7c
	dc.b	$00,$1f,$00,$00,$7c,$3e,$00,$03,$e0,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$04,$c1,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00
	dc.b	$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$13,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7
	dc.b	$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$13,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf
	dc.b	$07,$83,$c1,$f8,$3c,$1f,$3e,$fa,$00,$00,$01,$fd,$ff,$01,$81,$f0,$f6,$00,$00,$3e,$fa,$00,$06,$7c,$00,$1f,$00,$00,$7c,$3e,$fa,$00
	dc.b	$00,$01,$fd,$ff,$01,$81,$f0,$f6,$00,$00,$3e,$fa,$00,$06,$7c,$00,$1f,$00,$00,$7c,$3e,$fe,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd
	dc.b	$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb
	dc.b	$ff,$00,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$04,$9e,$0f,$07,$83,$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe
	dc.b	$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$04,$9e,$0f,$07,$83,$3f,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$00,$3e,$fa,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe
	dc.b	$00,$02,$01,$f0,$f8,$f4,$00,$06,$7c,$00,$1f,$00,$00,$7c,$3e,$fa,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$f4
	dc.b	$00,$06,$7c,$00,$1f,$00,$00,$7c,$3e,$fe,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00
	dc.b	$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0
	dc.b	$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83
	dc.b	$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$00,$3e,$fa,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$f4,$00,$06
	dc.b	$7c,$00,$1f,$00,$00,$7c,$3e,$fa,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$f4,$00,$06,$7c,$00,$1f,$00,$00,$7c
	dc.b	$3e,$fe,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07
	dc.b	$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0
	dc.b	$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$07,$e7,$83,$c1,$e0,$cf,$07,$83
	dc.b	$c1,$fe,$ff,$00,$3e,$fa,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$ef,$00,$01,$7c,$3e,$fa,$00,$06,$01,$ff,$f0
	dc.b	$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$ef,$00,$01,$7c,$3e,$fe,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff
	dc.b	$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f
	dc.b	$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$c1,$fe
	dc.b	$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7
	dc.b	$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$15,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$03,$cf,$07,$83,$c1,$fe,$ff,$02,$3e,$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe
	dc.b	$00,$02,$01,$f0,$f8,$ef,$00,$03,$7c,$3e,$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$ef,$00,$04,$7c
	dc.b	$3e,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$19,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f
	dc.b	$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$1c,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1
	dc.b	$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$fe,$ff,$04,$f9,$e0,$f0,$78,$27,$fe,$ff,$09,$cf,$07
	dc.b	$83,$c1,$f8,$3c,$1f,$3e,$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$f8,$00,$03
	dc.b	$7c,$3e,$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$f8,$00,$04,$7c,$3e,$07,$c0
	dc.b	$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c
	dc.b	$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0
	dc.b	$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$09,$cf,$07,$83,$c1,$f8
	dc.b	$3c,$1f,$3e,$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$f8,$00,$03,$7c,$3e,$07
	dc.b	$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$f8,$00,$04,$7c,$3e,$07,$c0,$00,$fd,$ff
	dc.b	$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$21,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07
	dc.b	$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$24,$cf,$07,$83,$c1,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f
	dc.b	$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$fe,$ff,$09,$cf,$07,$83,$c1,$f8,$3c,$1f,$00
	dc.b	$07,$c0,$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$01,$07,$c0
	dc.b	$fc,$00,$06,$01,$ff,$f0,$7f,$ff,$81,$f0,$fe,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$02,$07,$c0,$00,$fd
	dc.b	$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$24,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9e,$0f,$07,$83,$3c,$1e,$0f,$07
	dc.b	$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$24,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f
	dc.b	$9e,$0f,$07,$83,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00
	dc.b	$07,$c0,$fc,$00,$05,$01,$ff,$f0,$7f,$ff,$80,$fd,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$01,$07,$c0,$fc
	dc.b	$00,$05,$01,$ff,$f0,$7f,$ff,$80,$fd,$00,$02,$01,$f0,$f8,$fa,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$02,$07,$c0,$00,$fd,$ff,$00
	dc.b	$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff
	dc.b	$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$1f,$0f,$87,$c0,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$0c,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe,$ff,$14,$3c,$1e,$0f,$07,$f9,$e0
	dc.b	$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$0c,$f8,$3c,$1f,$e7,$83,$c1,$e0,$f9,$e0,$f0,$78,$3f,$9f,$fe
	dc.b	$ff,$14,$3c,$1e,$0f,$07,$f9,$e0,$f0,$78,$33,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0
	dc.b	$fc,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$01,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00
	dc.b	$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00
	dc.b	$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8
	dc.b	$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83
	dc.b	$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$01
	dc.b	$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$00
	dc.b	$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00
	dc.b	$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00
	dc.b	$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79
	dc.b	$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$05,$f8,$3c,$1f,$00,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80
	dc.b	$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb,$00,$01,$07,$c0,$fc,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$fb
	dc.b	$00,$02,$07,$c0,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fa,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$03,$f8,$3c,$1f,$e7,$fe,$ff,$00,$f9,$fd
	dc.b	$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$0c,$f3,$c1,$e0,$f0,$79,$e0,$f0,$78,$27,$83,$c1,$e0,$cf,$fe,$ff,$02,$f8,$3c
	dc.b	$1f,$f9,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd,$00,$00,$7c,$f4,$00,$00,$01,$fd,$ff,$00,$80,$f3,$00,$01,$0f,$80,$fd
	dc.b	$00,$00,$7c,$f8,$00,$fd,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f8,$fd,$00,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$04,$e7,$83,$c1,$e0,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00
	dc.b	$3f,$fe,$ff,$00,$f9,$fe,$ff,$04,$f3,$c1,$e0,$f0,$79,$fe,$ff,$04,$e7,$83,$c1,$e0,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0
	dc.b	$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$7f,$ff,$00,$00,$03,$ff,$00
	dc.b	$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00
	dc.b	$7f,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe
	dc.b	$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f
	dc.b	$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$04,$e7,$83,$ff,$e0,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9
	dc.b	$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$04,$e7,$83,$ff,$e0,$cf,$fb,$ff,$02,$00
	dc.b	$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00
	dc.b	$7f,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00
	dc.b	$ff,$c0,$00,$00,$ff,$c0,$00,$7f,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff
	dc.b	$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f
	dc.b	$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$04,$e7,$83,$ff,$e0,$cf,$fb
	dc.b	$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$04,$e7,$83
	dc.b	$ff,$e0,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00
	dc.b	$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff
	dc.b	$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8
	dc.b	$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00
	dc.b	$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff
	dc.b	$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff
	dc.b	$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06
	dc.b	$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd
	dc.b	$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7
	dc.b	$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06
	dc.b	$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00
	dc.b	$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00
	dc.b	$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe
	dc.b	$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9
	dc.b	$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f
	dc.b	$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f
	dc.b	$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00
	dc.b	$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00
	dc.b	$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00
	dc.b	$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff
	dc.b	$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe
	dc.b	$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd
	dc.b	$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe
	dc.b	$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb
	dc.b	$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff,$c0,$00,$00,$ff,$c0,$00,$00
	dc.b	$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$14,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00
	dc.b	$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$05
	dc.b	$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$f7,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff
	dc.b	$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff
	dc.b	$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$02,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00,$00,$03,$ff,$fe,$00,$13,$ff
	dc.b	$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$fe,$00,$02,$ff,$c0,$01,$fd,$ff,$06,$80,$0f,$fc,$00
	dc.b	$00,$03,$ff,$fe,$00,$14,$ff,$c0,$00,$00,$ff,$c0,$00,$00,$ff,$c0,$00,$03,$ff,$00,$00,$03,$ff,$00,$0f,$fc,$00,$fd,$ff,$00,$e7,$fe
	dc.b	$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf
	dc.b	$fb,$ff,$00,$e7,$fe,$ff,$05,$f8,$00,$1f,$f8,$00,$1f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$e7,$fe,$ff,$00,$cf,$f7,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00,$f3,$fe,$ff,$00
	dc.b	$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$fb,$ff,$00,$e7,$fe,$ff,$00,$f9,$fd,$ff,$00,$9f,$fe,$ff,$00,$3f,$fe,$ff,$00,$f9,$fe,$ff,$00
	dc.b	$f3,$fe,$ff,$00,$f9,$fe,$ff,$00,$e7,$fe,$ff,$00,$cf,$a7,$ff,$81,$00,$d9,$00,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81
	dc.b	$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$9d,$ff,$52,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ac,$ff,$52,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff
	dc.b	$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$ff,$00,$81,$ff,$81,$ff,$81,$ff,$81
	dc.b	$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$81,$ff,$9c,$ff,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$a1,$00,$80
	even
bg_map	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$c7,$00,$ef,$ff,$00,$fc,$fe,$00,$ef,$ff,$c5,$00,$02,$1f,$ff,$fc,$fe,$00,$00,$f0,$c4,$00,$f1,$ff,$02,$e0
	dc.b	$00,$03,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$00,$fc,$fe,$00,$ef,$ff,$c5,$00,$02,$1f,$ff,$fc,$fe,$00,$00,$f0,$c4,$00,$f1,$ff
	dc.b	$02,$e0,$00,$03,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$00,$fc,$fe,$00,$ef,$ff,$c5,$00,$02,$1f,$ff,$fc,$fe,$00,$00,$f0,$c4,$00
	dc.b	$f1,$ff,$02,$e0,$00,$03,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$00,$fc,$fe,$00,$ef,$ff,$c5,$00,$02,$3f,$ff,$fc,$fe,$00,$00,$f0
	dc.b	$c4,$00,$f1,$ff,$02,$c0,$00,$03,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$00,$fc,$fe,$00,$ef,$ff,$c5,$00,$02,$3f,$ff,$fc,$fe,$00
	dc.b	$00,$f0,$c4,$00,$f1,$ff,$02,$c0,$00,$03,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$00,$f8,$fe,$00,$ef,$ff,$c5,$00,$02,$3f,$ff,$f8
	dc.b	$fe,$00,$00,$f0,$c4,$00,$f1,$ff,$02,$c0,$00,$07,$fe,$ff,$00,$0f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f8,$00,$00,$01,$ef,$ff,$c5,$00,$06
	dc.b	$3f,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$c0,$00,$07,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f8,$00,$00,$01,$ef,$ff
	dc.b	$c5,$00,$06,$7f,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$80,$00,$07,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f8,$00,$00
	dc.b	$01,$ef,$ff,$c5,$00,$06,$7f,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$80,$00,$07,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03
	dc.b	$f8,$00,$00,$01,$ef,$ff,$c5,$00,$06,$7f,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$80,$00,$07,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00
	dc.b	$ef,$ff,$03,$f8,$00,$00,$01,$ef,$ff,$c5,$00,$06,$7f,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$80,$00,$07,$ff,$ff,$fe,$1f,$f0
	dc.b	$ff,$d5,$00,$ef,$ff,$03,$f8,$00,$00,$01,$ef,$ff,$c5,$00,$06,$ff,$ff,$f8,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$00,$00,$07,$ff,$ff
	dc.b	$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f8,$00,$00,$01,$ef,$ff,$c5,$00,$fb,$ff,$00,$e0,$c4,$00,$f1,$ff,$06,$00,$00,$07,$ff,$ff,$fe
	dc.b	$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$01,$ef,$ff,$c5,$00,$06,$ff,$ff,$f0,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06,$00,$00,$0f
	dc.b	$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$01,$ef,$ff,$c5,$00,$06,$ff,$ff,$f0,$00,$00,$01,$e0,$c4,$00,$f1,$ff,$06
	dc.b	$00,$00,$0f,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$01,$ef,$ff,$c6,$00,$07,$01,$ff,$ff,$f0,$00,$00,$01,$e0,$c4
	dc.b	$00,$f2,$ff,$07,$fe,$00,$00,$0f,$ff,$ff,$fe,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$03,$ef,$ff,$c6,$00,$07,$01,$ff,$ff,$f0
	dc.b	$00,$00,$03,$e0,$c4,$00,$f2,$ff,$07,$fe,$00,$00,$0f,$ff,$ff,$fc,$1f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$03,$ef,$ff,$c6,$00
	dc.b	$07,$01,$ff,$ff,$f0,$00,$00,$03,$c0,$c4,$00,$f2,$ff,$07,$fe,$00,$00,$0f,$ff,$ff,$fc,$3f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00
	dc.b	$03,$ef,$ff,$c6,$00,$07,$01,$ff,$ff,$f0,$00,$00,$03,$c0,$c4,$00,$f2,$ff,$07,$fe,$00,$00,$0f,$ff,$ff,$fc,$3f,$f0,$ff,$d5,$00,$ef
	dc.b	$ff,$03,$f0,$00,$00,$03,$ef,$ff,$c6,$00,$07,$03,$ff,$ff,$f0,$00,$00,$03,$c0,$c4,$00,$f2,$ff,$07,$fc,$00,$00,$0f,$ff,$ff,$fc,$3f
	dc.b	$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$03,$ef,$ff,$c6,$00,$07,$03,$ff,$ff,$f0,$00,$00,$03,$c0,$c4,$00,$f2,$ff,$07,$fc,$00,$00
	dc.b	$0f,$ff,$ff,$fc,$3f,$f0,$ff,$d5,$00,$ef,$ff,$03,$f0,$00,$00,$03,$ef,$ff,$c6,$00,$00,$03,$fb,$ff,$00,$c0,$c4,$00,$f2,$ff,$07,$fc
	dc.b	$00,$00,$0f,$ff,$ff,$fc,$3f,$f0,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$03,$ef,$ff,$c6,$00,$07,$03,$ff,$ff,$e0,$00,$00,$03,$c0,$c4
	dc.b	$00,$f2,$ff,$07,$fc,$00,$00,$1f,$ff,$ff,$fc,$3f,$f0,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$03,$ef,$ff,$c6,$00,$07,$03,$ff,$ff,$e0
	dc.b	$00,$00,$03,$f8,$c4,$00,$f2,$ff,$07,$fc,$00,$00,$1f,$ff,$ff,$fc,$07,$f0,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$03,$ef,$ff,$c6,$00
	dc.b	$07,$07,$ff,$ff,$e0,$00,$00,$03,$fe,$c4,$00,$f2,$ff,$07,$f8,$00,$00,$1f,$ff,$ff,$fc,$01,$f0,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00
	dc.b	$03,$ef,$ff,$c6,$00,$08,$07,$ff,$ff,$e0,$00,$00,$03,$ff,$c0,$c5,$00,$f2,$ff,$08,$f8,$00,$00,$1f,$ff,$ff,$fc,$00,$3f,$f1,$ff,$d5
	dc.b	$00,$ef,$ff,$03,$e0,$00,$00,$07,$ef,$ff,$c6,$00,$08,$07,$ff,$ff,$e0,$00,$00,$07,$ff,$f0,$c5,$00,$f2,$ff,$08,$f8,$00,$00,$1f,$ff
	dc.b	$ff,$f8,$00,$0f,$f1,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$07,$ef,$ff,$c6,$00,$08,$07,$ff,$ff,$e0,$00,$00,$07,$ff,$fe,$c5,$00,$f2
	dc.b	$ff,$08,$f8,$00,$00,$1f,$ff,$ff,$f8,$00,$01,$f1,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$07,$ef,$ff,$c6,$00,$09,$0f,$ff,$ff,$e0,$00
	dc.b	$00,$07,$ff,$ff,$c0,$c6,$00,$f2,$ff,$09,$f0,$00,$00,$1f,$ff,$ff,$f8,$00,$00,$3f,$f2,$ff,$d5,$00,$ef,$ff,$03,$e0,$00,$00,$07,$ef
	dc.b	$ff,$c6,$00,$09,$0f,$ff,$ff,$e0,$00,$00,$07,$ff,$ff,$f0,$c6,$00,$f2,$ff,$09,$f0,$00,$00,$1f,$ff,$ff,$f8,$00,$00,$0f,$f2,$ff,$d5
	dc.b	$00,$ef,$ff,$03,$c0,$00,$00,$07,$ef,$ff,$c6,$00,$00,$0f,$f9,$ff,$00,$fe,$c6,$00,$f2,$ff,$09,$f0,$00,$00,$3f,$ff,$ff,$f8,$00,$00
	dc.b	$01,$f2,$ff,$d5,$00,$ef,$ff,$03,$c0,$00,$00,$07,$ef,$ff,$c6,$00,$06,$0f,$ff,$ff,$c0,$00,$00,$07,$fe,$ff,$00,$80,$c7,$00,$f2,$ff
	dc.b	$06,$f0,$00,$00,$3f,$ff,$ff,$f8,$fe,$00,$00,$7f,$f3,$ff,$d5,$00,$ef,$ff,$03,$c0,$00,$00,$07,$ef,$ff,$c6,$00,$06,$1f,$ff,$ff,$c0
	dc.b	$00,$00,$07,$fe,$ff,$00,$f0,$c7,$00,$f2,$ff,$06,$e0,$00,$00,$3f,$ff,$ff,$f8,$fe,$00,$00,$0f,$f3,$ff,$d5,$00,$ef,$ff,$03,$c0,$00
	dc.b	$00,$07,$ef,$ff,$c6,$00,$06,$1f,$ff,$ff,$c0,$00,$00,$07,$fe,$ff,$00,$fe,$c7,$00,$f2,$ff,$06,$e0,$00,$00,$3f,$ff,$ff,$f8,$fe,$00
	dc.b	$00,$01,$f3,$ff,$d5,$00,$ef,$ff,$03,$c0,$00,$00,$07,$ef,$ff,$c6,$00,$06,$1f,$ff,$ff,$c0,$00,$00,$07,$fd,$ff,$00,$80,$c8,$00,$f2
	dc.b	$ff,$06,$e0,$00,$00,$3f,$ff,$ff,$f8,$fd,$00,$00,$7f,$f4,$ff,$d5,$00,$ef,$ff,$03,$c0,$00,$00,$07,$ef,$ff,$c6,$00,$06,$1f,$ff,$ff
	dc.b	$c0,$00,$00,$07,$fd,$ff,$00,$f0,$c8,$00,$f2,$ff,$06,$e0,$00,$00,$3f,$ff,$ff,$f8,$fd,$00,$00,$0f,$f4,$ff,$d5,$00,$ef,$ff,$03,$c0
	dc.b	$00,$00,$0f,$ef,$ff,$c6,$00,$06,$3f,$ff,$ff,$c0,$00,$00,$0f,$fd,$ff,$00,$fc,$c8,$00,$f2,$ff,$06,$c0,$00,$00,$3f,$ff,$ff,$f0,$fd
	dc.b	$00,$00,$03,$f4,$ff,$d5,$00,$ef,$ff,$03,$c0,$00,$00,$0f,$ef,$ff,$c6,$00,$06,$3f,$ff,$ff,$c0,$00,$00,$0f,$fc,$ff,$00,$80,$c9,$00
	dc.b	$f2,$ff,$06,$c0,$00,$00,$3f,$ff,$ff,$f0,$fc,$00,$00,$7f,$f5,$ff,$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef,$ff,$c6,$00,$06,$3f,$ff
	dc.b	$ff,$80,$00,$00,$0f,$fc,$ff,$00,$f0,$c9,$00,$f2,$ff,$06,$c0,$00,$00,$7f,$ff,$ff,$f0,$fc,$00,$00,$0f,$f5,$ff,$d5,$00,$ef,$ff,$03
	dc.b	$80,$00,$00,$0f,$ef,$ff,$c6,$00,$00,$3f,$f6,$ff,$00,$fc,$c9,$00,$f2,$ff,$06,$c0,$00,$00,$7f,$ff,$ff,$f0,$fc,$00,$00,$03,$f5,$ff
	dc.b	$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef,$ff,$c6,$00,$06,$7f,$ff,$ff,$80,$00,$00,$0f,$fb,$ff,$00,$80,$ca,$00,$f2,$ff,$06,$80,$00
	dc.b	$00,$7f,$ff,$ff,$f0,$fb,$00,$00,$7f,$f6,$ff,$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef,$ff,$c6,$00,$06,$7f,$ff,$ff,$80,$00,$00,$0f
	dc.b	$fb,$ff,$00,$e0,$ca,$00,$f2,$ff,$06,$80,$00,$00,$7f,$ff,$ff,$f0,$fb,$00,$00,$1f,$f6,$ff,$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef
	dc.b	$ff,$c6,$00,$06,$7f,$ff,$ff,$80,$00,$00,$0f,$fb,$ff,$00,$fc,$ca,$00,$f2,$ff,$06,$80,$00,$00,$7f,$ff,$ff,$f0,$fb,$00,$00,$03,$f6
	dc.b	$ff,$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef,$ff,$c6,$00,$fe,$ff,$03,$80,$00,$00,$0f,$fa,$ff,$00,$fe,$cb,$00,$f2,$ff,$fe,$00,$03
	dc.b	$7f,$ff,$ff,$f0,$fa,$00,$00,$01,$f7,$ff,$d5,$00,$ef,$ff,$03,$80,$00,$00,$0f,$ef,$ff,$c7,$00,$00,$01,$fe,$ff,$03,$80,$00,$00,$0f
	dc.b	$f8,$ff,$cc,$00,$f3,$ff,$00,$fe,$fe,$00,$03,$7f,$ff,$ff,$f0,$f8,$00,$f8,$ff,$d5,$00,$ef,$ff,$fe,$00,$00,$0f,$ef,$ff,$c7,$00,$00
	dc.b	$07,$fe,$ff,$fe,$00,$00,$0f,$f7,$ff,$00,$80,$ce,$00,$f3,$ff,$00,$f8,$fe,$00,$fe,$ff,$00,$f0,$f7,$00,$00,$7f,$fa,$ff,$d5,$00,$ef
	dc.b	$ff,$fe,$00,$00,$0f,$ef,$ff,$c7,$00,$00,$0f,$fe,$ff,$fe,$00,$00,$0f,$f6,$ff,$00,$c0,$cf,$00,$f3,$ff,$00,$f0,$fe,$00,$fe,$ff,$00
	dc.b	$f0,$f6,$00,$00,$3f,$fb,$ff,$d5,$00,$ef,$ff,$fe,$00,$00,$1f,$ef,$ff,$c7,$00,$00,$1f,$fe,$ff,$fe,$00,$00,$1f,$f5,$ff,$00,$e0,$d0
	dc.b	$00,$f3,$ff,$00,$e0,$fe,$00,$fe,$ff,$00,$e0,$f5,$00,$00,$1f,$fc,$ff,$d5,$00,$ef,$ff,$fe,$00,$00,$1f,$ef,$ff,$c7,$00,$00,$3f,$ed
	dc.b	$ff,$00,$f0,$d1,$00,$f3,$ff,$00,$c0,$fe,$00,$fe,$ff,$00,$e0,$f4,$00,$00,$0f,$fd,$ff,$d5,$00,$f0,$ff,$00,$fe,$fe,$00,$00,$1f,$ef
	dc.b	$ff,$c7,$00,$03,$7f,$ff,$ff,$fe,$fe,$00,$00,$1f,$f3,$ff,$00,$f8,$d2,$00,$f3,$ff,$03,$80,$00,$00,$01,$fe,$ff,$00,$e0,$f3,$00,$00
	dc.b	$07,$fe,$ff,$d5,$00,$f0,$ff,$00,$fe,$fe,$00,$00,$1f,$ef,$ff,$c8,$00,$00,$01,$fe,$ff,$00,$fe,$fe,$00,$00,$1f,$f2,$ff,$00,$fc,$d3
	dc.b	$00,$f4,$ff,$00,$fe,$fe,$00,$00,$01,$fe,$ff,$00,$e0,$f2,$00,$02,$03,$ff,$ff,$d5,$00,$f0,$ff,$00,$fe,$fe,$00,$00,$1f,$ef,$ff,$c8
	dc.b	$00,$00,$03,$fe,$ff,$00,$fe,$fe,$00,$00,$1f,$f1,$ff,$00,$fe,$d4,$00,$f4,$ff,$00,$fc,$fe,$00,$00,$01,$fe,$ff,$00,$e0,$f1,$00,$01
	dc.b	$01,$ff,$d5,$00,$f0,$ff,$00,$fe,$fe,$00,$00,$1f,$ef,$ff,$c8,$00,$00,$07,$fe,$ff,$00,$fe,$fe,$00,$00,$1f,$ef,$ff,$d5,$00,$f4,$ff
	dc.b	$00,$f8,$fe,$00,$00,$01,$fe,$ff,$00,$e0,$c3,$00,$f0,$ff,$00,$fe,$fe,$00,$00,$1f,$ef,$ff,$c8,$00,$00,$0f,$fe,$ff,$00,$fe,$fe,$00
	dc.b	$00,$1f,$ef,$ff,$d5,$00,$f4,$ff,$00,$f0,$fe,$00,$00,$01,$fe,$ff,$00,$e0,$c3,$00,$f0,$ff,$00,$fc,$fe,$00,$00,$1f,$ef,$ff,$c8,$00
	dc.b	$00,$1f,$fe,$ff,$00,$fc,$fe,$00,$00,$1f,$ef,$ff,$d5,$00,$f4,$ff,$00,$e0,$fe,$00,$00,$03,$fe,$ff,$00,$e0,$c3,$00,$f0,$ff,$00,$fc
	dc.b	$fe,$00,$00,$1f,$ef,$ff,$c8,$00,$00,$7f,$fe,$ff,$00,$fc,$fe,$00,$00,$1f,$ef,$ff,$d5,$00,$f4,$ff,$00,$80,$fe,$00,$00,$03,$fe,$ff
	dc.b	$00,$e0,$c3,$00,$f0,$ff,$00,$fc,$fe,$00,$00,$1f,$ef,$ff,$c8,$00,$fd,$ff,$00,$fc,$fe,$00,$00,$1f,$ef,$ff,$d5,$00,$f4,$ff,$fd,$00
	dc.b	$00,$03,$fe,$ff,$00,$e0,$c3,$00,$f0,$ff,$00,$fc,$fe,$00,$00,$3f,$ef,$ff,$c9,$00,$00,$01,$e6,$ff,$d5,$00,$f5,$ff,$00,$fe,$fd,$00
	dc.b	$00,$03,$fe,$ff,$00,$c0,$c3,$00,$f0,$ff,$00,$fc,$fe,$00,$00,$3f,$ef,$ff,$c9,$00,$00,$03,$fd,$ff,$00,$fc,$fe,$00,$00,$3f,$ef,$ff
	dc.b	$d5,$00,$f5,$ff,$00,$fc,$fd,$00,$00,$03,$fe,$ff,$00,$c0,$c3,$00,$f0,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$c9,$00,$00,$07,$fd,$ff
	dc.b	$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$d5,$00,$f5,$ff,$00,$f8,$fd,$00,$00,$07,$fe,$ff,$00,$c0,$c3,$00,$f0,$ff,$00,$f8,$fe,$00,$00,$3f
	dc.b	$ef,$ff,$c9,$00,$00,$1f,$fd,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$d5,$00,$f5,$ff,$00,$e0,$fd,$00,$00,$07,$fe,$ff,$00,$c0,$c3,$00
	dc.b	$f0,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$c9,$00,$00,$3f,$fd,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$d5,$00,$f5,$ff,$00,$c0,$fd,$00
	dc.b	$00,$07,$fe,$ff,$00,$c0,$c3,$00,$f0,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff,$c9,$00,$00,$7f,$fd,$ff,$00,$f8,$fe,$00,$00,$3f,$ef,$ff
	dc.b	$d5,$00,$f5,$ff,$00,$80,$fd,$00,$00,$07,$fe,$ff,$00,$c0,$c3,$00,$f0,$ff,$00,$f0,$fe,$00,$00,$3f,$f0,$ff,$00,$c0,$c9,$00,$fc,$ff
	dc.b	$00,$f0,$fe,$00,$00,$3f,$f0,$ff,$00,$c0,$d5,$00,$f5,$ff,$fc,$00,$00,$0f,$fe,$ff,$00,$c0,$f0,$00,$00,$3f,$d5,$00,$f0,$ff,$00,$f0
	dc.b	$fe,$00,$00,$3f,$f1,$ff,$00,$f0,$c9,$00,$00,$01,$fc,$ff,$00,$f0,$fe,$00,$00,$3f,$f1,$ff,$00,$f0,$d4,$00,$f6,$ff,$00,$fe,$fc,$00
	dc.b	$00,$0f,$fe,$ff,$00,$c0,$f1,$00,$01,$0f,$ff,$d5,$00,$f0,$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$00,$fc,$c8,$00,$00,$07,$fc,$ff,$00
	dc.b	$f0,$fe,$00,$00,$3f,$f2,$ff,$00,$fc,$d3,$00,$f6,$ff,$00,$f8,$fc,$00,$00,$0f,$fe,$ff,$00,$c0,$f2,$00,$02,$03,$ff,$ff,$d5,$00,$f0
	dc.b	$ff,$00,$f0,$fe,$00,$00,$3f,$f2,$ff,$c7,$00,$00,$0f,$e8,$ff,$d2,$00,$f6,$ff,$00,$f0,$fc,$00,$00,$0f,$fe,$ff,$00,$c0,$f2,$00,$fe
	dc.b	$ff,$d5,$00,$f0,$ff,$00,$f0,$fe,$00,$00,$7f,$f3,$ff,$00,$c0,$c7,$00,$00,$1f,$fc,$ff,$00,$f0,$fe,$00,$00,$7f,$f3,$ff,$00,$c0,$d2
	dc.b	$00,$f6,$ff,$00,$e0,$fc,$00,$00,$0f,$fe,$ff,$00,$80,$f3,$00,$00,$3f,$fe,$ff,$d5,$00,$f0,$ff,$00,$e0,$fe,$00,$00,$7f,$f4,$ff,$00
	dc.b	$f0,$c6,$00,$00,$3f,$fc,$ff,$00,$e0,$fe,$00,$00,$7f,$f4,$ff,$00,$f0,$d1,$00,$f6,$ff,$00,$c0,$fc,$00,$00,$1f,$fe,$ff,$00,$80,$f4
	dc.b	$00,$00,$0f,$fd,$ff,$d5,$00,$f0,$ff,$00,$e0,$fe,$00,$00,$7f,$f5,$ff,$00,$fc,$c5,$00,$00,$7f,$fc,$ff,$00,$e0,$fe,$00,$00,$7f,$f5
	dc.b	$ff,$00,$fc,$d0,$00,$f6,$ff,$00,$80,$fc,$00,$00,$1f,$fe,$ff,$00,$80,$f5,$00,$00,$03,$fc,$ff,$d5,$00,$f0,$ff,$00,$e0,$fe,$00,$00
	dc.b	$7f,$f5,$ff,$c5,$00,$00,$01,$fb,$ff,$00,$e0,$fe,$00,$00,$7f,$f5,$ff,$cf,$00,$f7,$ff,$00,$fe,$fb,$00,$00,$1f,$fe,$ff,$00,$80,$f5
	dc.b	$00,$fb,$ff,$d5,$00,$f0,$ff,$00,$e0,$fe,$00,$00,$7f,$f6,$ff,$00,$c0,$c5,$00,$00,$03,$fb,$ff,$00,$e0,$fe,$00,$00,$7f,$f6,$ff,$00
	dc.b	$c0,$cf,$00,$f7,$ff,$00,$fc,$fb,$00,$00,$1f,$fe,$ff,$00,$80,$f6,$00,$00,$3f,$fb,$ff,$d5,$00,$f0,$ff,$00,$e0,$fe,$00,$00,$7f,$f7
	dc.b	$ff,$00,$f0,$c4,$00,$00,$07,$fb,$ff,$00,$e0,$fe,$00,$00,$7f,$f7,$ff,$00,$f0,$ce,$00,$f7,$ff,$00,$f8,$fb,$00,$00,$1f,$fe,$ff,$00
	dc.b	$80,$f7,$00,$00,$0f,$fa,$ff,$d5,$00,$f0,$ff,$00,$c0,$fe,$00,$00,$7f,$f8,$ff,$00,$fc,$c3,$00,$00,$0f,$fb,$ff,$00,$c0,$fe,$00,$00
	dc.b	$7f,$f8,$ff,$00,$fc,$cd,$00,$f7,$ff,$00,$f0,$fb,$00,$00,$3f,$fe,$ff,$00,$80,$f8,$00,$00,$03,$f9,$ff,$d5,$00,$f0,$ff,$00,$c0,$fe
	dc.b	$00,$f7,$ff,$c2,$00,$00,$1f,$fb,$ff,$00,$c0,$fe,$00,$f7,$ff,$cc,$00,$f7,$ff,$00,$e0,$fb,$00,$00,$3f,$fe,$ff,$f7,$00,$f8,$ff,$d5
	dc.b	$00,$f0,$ff,$00,$c0,$fe,$00,$f8,$ff,$00,$c0,$c2,$00,$00,$7f,$ee,$ff,$00,$c0,$cc,$00,$f7,$ff,$00,$80,$fb,$00,$00,$3f,$fe,$ff,$f8
	dc.b	$00,$00,$3f,$f8,$ff,$d5,$00,$f0,$ff,$00,$c0,$fe,$00,$f9,$ff,$00,$f0,$c1,$00,$fa,$ff,$00,$c0,$fe,$00,$f9,$ff,$00,$f0,$cb,$00,$f7
	dc.b	$ff,$fa,$00,$00,$3f,$fe,$ff,$f9,$00,$00,$0f,$f7,$ff,$d5,$00,$f0,$ff,$03,$80,$00,$00,$01,$fa,$ff,$00,$fc,$c1,$00,$00,$01,$fa,$ff
	dc.b	$03,$80,$00,$00,$01,$fa,$ff,$00,$fc,$ca,$00,$f8,$ff,$00,$fe,$fa,$00,$03,$7f,$ff,$ff,$fe,$fa,$00,$00,$03,$f6,$ff,$d5,$00,$f0,$ff
	dc.b	$03,$80,$00,$00,$01,$fa,$ff,$c0,$00,$00,$03,$fa,$ff,$03,$80,$00,$00,$01,$fa,$ff,$c9,$00,$f8,$ff,$00,$fc,$fa,$00,$03,$7f,$ff,$ff
	dc.b	$fe,$fa,$00,$f5,$ff,$d5,$00,$f0,$ff,$03,$80,$00,$00,$03,$fb,$ff,$00,$c0,$c0,$00,$00,$07,$fa,$ff,$03,$80,$00,$00,$03,$fb,$ff,$00
	dc.b	$c0,$c9,$00,$f8,$ff,$00,$f8,$fa,$00,$03,$7f,$ff,$ff,$fc,$fb,$00,$00,$3f,$f5,$ff,$d5,$00,$f0,$ff,$03,$80,$00,$00,$03,$fc,$ff,$00
	dc.b	$f0,$bf,$00,$00,$1f,$fa,$ff,$03,$80,$00,$00,$03,$fc,$ff,$00,$f0,$c8,$00,$f8,$ff,$00,$e0,$fa,$00,$03,$7f,$ff,$ff,$fc,$fc,$00,$00
	dc.b	$0f,$f4,$ff,$d5,$00,$f0,$ff,$03,$80,$00,$00,$03,$fd,$ff,$00,$fc,$be,$00,$00,$3f,$fa,$ff,$03,$80,$00,$00,$03,$fd,$ff,$00,$fc,$c7
	dc.b	$00,$f8,$ff,$00,$c0,$fa,$00,$03,$7f,$ff,$ff,$fc,$fd,$00,$00,$03,$f3,$ff,$d5,$00,$f0,$ff,$fe,$00,$00,$07,$fd,$ff,$bd,$00,$00,$7f
	dc.b	$fa,$ff,$fe,$00,$00,$07,$fd,$ff,$c6,$00,$f8,$ff,$00,$80,$fa,$00,$fe,$ff,$00,$f8,$fd,$00,$f2,$ff,$d5,$00,$f0,$ff,$fe,$00,$00,$07
	dc.b	$fe,$ff,$00,$fe,$bd,$00,$f9,$ff,$fe,$00,$00,$07,$fe,$ff,$00,$fe,$c6,$00,$f8,$ff,$f9,$00,$fe,$ff,$00,$f8,$fe,$00,$00,$01,$f2,$ff
	dc.b	$d5,$00,$f0,$ff,$fe,$00,$00,$07,$fe,$ff,$00,$fc,$be,$00,$00,$01,$f2,$ff,$00,$fc,$c6,$00,$f9,$ff,$00,$fe,$f9,$00,$fe,$ff,$00,$f8
	dc.b	$fe,$00,$00,$03,$f2,$ff,$d5,$00,$f0,$ff,$fe,$00,$00,$0f,$fe,$ff,$00,$f8,$be,$00,$00,$07,$f9,$ff,$fe,$00,$00,$0f,$fe,$ff,$00,$f8
	dc.b	$c6,$00,$f9,$ff,$00,$f8,$f9,$00,$fe,$ff,$00,$f0,$fe,$00,$00,$07,$f2,$ff,$d5,$00,$f1,$ff,$00,$fe,$fe,$00,$00,$0f,$fe,$ff,$00,$f0
	dc.b	$be,$00,$00,$0f,$fa,$ff,$00,$fe,$fe,$00,$00,$0f,$fe,$ff,$00,$f0,$c6,$00,$f9,$ff,$00,$f0,$fa,$00,$00,$01,$fe,$ff,$00,$f0,$fe,$00
	dc.b	$00,$0f,$f2,$ff,$d5,$00,$f1,$ff,$00,$fe,$fe,$00,$00,$0f,$fe,$ff,$00,$e0,$be,$00,$00,$1f,$fa,$ff,$00,$fe,$fe,$00,$00,$0f,$fe,$ff
	dc.b	$00,$e0,$c6,$00,$f9,$ff,$00,$e0,$fa,$00,$00,$01,$fe,$ff,$00,$f0,$fe,$00,$00,$1f,$f2,$ff,$d5,$00,$f1,$ff,$00,$fe,$fe,$00,$00,$1f
	dc.b	$fe,$ff,$00,$c0,$be,$00,$00,$3f,$fa,$ff,$00,$fe,$fe,$00,$00,$1f,$fe,$ff,$00,$c0,$c6,$00,$f9,$ff,$00,$c0,$fa,$00,$00,$01,$fe,$ff
	dc.b	$00,$e0,$fe,$00,$00,$3f,$f2,$ff,$d5,$00,$f1,$ff,$00,$fe,$fe,$00,$00,$1f,$fe,$ff,$00,$80,$be,$00,$00,$7f,$fa,$ff,$00,$fe,$fe,$00
	dc.b	$00,$1f,$fe,$ff,$00,$80,$c6,$00,$f9,$ff,$00,$80,$fa,$00,$00,$01,$fe,$ff,$00,$e0,$fe,$00,$00,$7f,$f2,$ff,$d5,$00,$f1,$ff,$00,$fe
	dc.b	$fe,$00,$00,$1f,$fe,$ff,$be,$00,$00,$01,$f9,$ff,$00,$fe,$fe,$00,$00,$1f,$fe,$ff,$c5,$00,$fa,$ff,$00,$fe,$f9,$00,$00,$01,$fe,$ff
	dc.b	$00,$e0,$fe,$00,$f1,$ff,$d5,$00,$f1,$ff,$00,$fc,$fe,$00,$03,$3f,$ff,$ff,$fe,$be,$00,$00,$03,$f9,$ff,$00,$fc,$fe,$00,$03,$3f,$ff
	dc.b	$ff,$fe,$c5,$00,$fa,$ff,$00,$fc,$f9,$00,$00,$03,$fe,$ff,$03,$c0,$00,$00,$01,$f1,$ff,$d5,$00,$f1,$ff,$00,$fc,$fe,$00,$03,$3f,$ff
	dc.b	$ff,$fc,$be,$00,$00,$07,$f9,$ff,$00,$fc,$fe,$00,$03,$3f,$ff,$ff,$fc,$c5,$00,$fa,$ff,$00,$f8,$f9,$00,$00,$03,$fe,$ff,$03,$c0,$00
	dc.b	$00,$03,$f1,$ff,$d5,$00,$f1,$ff,$00,$fc,$fe,$00,$03,$7f,$ff,$ff,$f8,$be,$00,$00,$3f,$f2,$ff,$00,$f8,$c5,$00,$fa,$ff,$00,$c0,$f9
	dc.b	$00,$00,$03,$fe,$ff,$03,$80,$00,$00,$07,$f1,$ff,$d5,$00,$f1,$ff,$00,$fc,$fe,$00,$03,$7f,$ff,$ff,$f0,$bf,$00,$00,$01,$f8,$ff,$00
	dc.b	$fc,$fe,$00,$03,$7f,$ff,$ff,$f0,$c5,$00,$fb,$ff,$00,$fe,$f8,$00,$00,$03,$fe,$ff,$03,$80,$00,$00,$0f,$f1,$ff,$d5,$00,$f1,$ff,$00
	dc.b	$fc,$fe,$00,$03,$7f,$ff,$ff,$e0,$bf,$00,$00,$0f,$f8,$ff,$00,$fc,$fe,$00,$03,$7f,$ff,$ff,$e0,$c5,$00,$fb,$ff,$00,$f0,$f8,$00,$00
	dc.b	$03,$fe,$ff,$03,$80,$00,$00,$1f,$f1,$ff,$d5,$00,$f1,$ff,$00,$f8,$fe,$00,$fe,$ff,$00,$c0,$bf,$00,$00,$7f,$f8,$ff,$00,$f8,$fe,$00
	dc.b	$fe,$ff,$00,$c0,$c5,$00,$fb,$ff,$00,$80,$f8,$00,$00,$07,$fe,$ff,$fe,$00,$00,$3f,$f1,$ff,$d5,$00,$f1,$ff,$00,$f8,$fe,$00,$fe,$ff
	dc.b	$00,$80,$c0,$00,$00,$03,$f7,$ff,$00,$f8,$fe,$00,$fe,$ff,$00,$80,$c5,$00,$fc,$ff,$00,$fc,$f7,$00,$00,$07,$fe,$ff,$fe,$00,$00,$7f
	dc.b	$f1,$ff,$d5,$00,$f1,$ff,$00,$f8,$fe,$00,$fe,$ff,$bf,$00,$00,$1f,$f7,$ff,$00,$f8,$fe,$00,$fe,$ff,$c4,$00,$fc,$ff,$00,$e0,$f7,$00
	dc.b	$00,$07,$fe,$ff,$fe,$00,$f0,$ff,$d5,$00,$f1,$ff,$06,$f8,$00,$00,$01,$ff,$ff,$fe,$bf,$00,$f6,$ff,$06,$f8,$00,$00,$01,$ff,$ff,$fe
	dc.b	$c4,$00,$fc,$ff,$f6,$00,$06,$07,$ff,$ff,$fe,$00,$00,$01,$f0,$ff,$d5,$00,$f1,$ff,$06,$f0,$00,$00,$01,$ff,$ff,$fc,$c0,$00,$00,$07
	dc.b	$f6,$ff,$06,$f0,$00,$00,$01,$ff,$ff,$fc,$c4,$00,$fd,$ff,$00,$f8,$f6,$00,$06,$0f,$ff,$ff,$fe,$00,$00,$03,$f0,$ff,$d5,$00,$f1,$ff
	dc.b	$06,$f0,$00,$00,$01,$ff,$ff,$f8,$c0,$00,$00,$3f,$f6,$ff,$06,$f0,$00,$00,$01,$ff,$ff,$f8,$c4,$00,$fd,$ff,$00,$c0,$f6,$00,$06,$0f
	dc.b	$ff,$ff,$fe,$00,$00,$07,$f0,$ff,$d5,$00,$f1,$ff,$06,$f0,$00,$00,$03,$ff,$ff,$f0,$c1,$00,$00,$01,$ef,$ff,$00,$f0,$c4,$00,$fe,$ff
	dc.b	$00,$fe,$f5,$00,$06,$0f,$ff,$ff,$fc,$00,$00,$0f,$f0,$ff,$d5,$00,$f1,$ff,$06,$f0,$00,$00,$03,$ff,$ff,$e0,$c1,$00,$00,$0f,$f5,$ff
	dc.b	$06,$f0,$00,$00,$03,$ff,$ff,$e0,$c4,$00,$fe,$ff,$00,$f0,$f5,$00,$06,$0f,$ff,$ff,$fc,$00,$00,$1f,$f0,$ff,$d5,$00,$f1,$ff,$06,$f0
	dc.b	$00,$00,$03,$ff,$ff,$c0,$c1,$00,$00,$7f,$f5,$ff,$06,$f0,$00,$00,$03,$ff,$ff,$c0,$c4,$00,$fe,$ff,$00,$80,$f5,$00,$06,$0f,$ff,$ff
	dc.b	$fc,$00,$00,$3f,$f0,$ff,$d5,$00,$f1,$ff,$06,$f0,$00,$00,$07,$ff,$ff,$80,$c2,$00,$00,$03,$f4,$ff,$06,$f0,$00,$00,$07,$ff,$ff,$80
	dc.b	$c4,$00,$02,$ff,$ff,$fc,$f4,$00,$06,$0f,$ff,$ff,$f8,$00,$00,$7f,$f0,$ff,$d5,$00,$f1,$ff,$05,$f0,$00,$00,$07,$ff,$ff,$c1,$00,$00
	dc.b	$1f,$f4,$ff,$05,$f0,$00,$00,$07,$ff,$ff,$c3,$00,$02,$ff,$ff,$e0,$f4,$00,$05,$0f,$ff,$ff,$f8,$00,$00,$ef,$ff,$d5,$00,$f1,$ff,$05
	dc.b	$f0,$00,$00,$0f,$ff,$fe,$c1,$00,$f3,$ff,$05,$f0,$00,$00,$0f,$ff,$fe,$c3,$00,$01,$ff,$ff,$f3,$00,$05,$0f,$ff,$ff,$f0,$00,$01,$ef
	dc.b	$ff,$d5,$00,$f1,$ff,$05,$f0,$00,$00,$0f,$ff,$fc,$c2,$00,$00,$07,$f3,$ff,$05,$f0,$00,$00,$0f,$ff,$fc,$c3,$00,$01,$ff,$f8,$f3,$00
	dc.b	$05,$0f,$ff,$ff,$f0,$00,$03,$ef,$ff,$d5,$00,$f1,$ff,$05,$e0,$00,$00,$0f,$ff,$f8,$c2,$00,$00,$3f,$f3,$ff,$05,$e0,$00,$00,$0f,$ff
	dc.b	$f8,$c3,$00,$01,$ff,$c0,$f3,$00,$05,$1f,$ff,$ff,$f0,$00,$07,$ef,$ff,$d5,$00,$f1,$ff,$05,$e0,$00,$00,$1f,$ff,$f0,$c3,$00,$00,$01
	dc.b	$f2,$ff,$05,$e0,$00,$00,$1f,$ff,$f0,$c3,$00,$00,$fe,$f2,$00,$05,$1f,$ff,$ff,$e0,$00,$0f,$ef,$ff,$d5,$00,$f1,$ff,$05,$e0,$00,$00
	dc.b	$1f,$ff,$e0,$c3,$00,$00,$0f,$ed,$ff,$00,$fe,$c3,$00,$00,$f0,$f2,$00,$05,$1f,$ff,$ff,$e0,$00,$1f,$ef,$ff,$d5,$00,$f1,$ff,$05,$e0
	dc.b	$00,$00,$1f,$ff,$c0,$c3,$00,$00,$7f,$f2,$ff,$05,$e0,$00,$00,$1f,$ff,$c0,$c3,$00,$00,$80,$f2,$00,$05,$1f,$ff,$ff,$e0,$00,$3f,$ef
	dc.b	$ff,$d5,$00,$f1,$ff,$05,$e0,$00,$00,$3f,$ff,$80,$c3,$00,$f1,$ff,$05,$e0,$00,$00,$3f,$ff,$80,$b3,$00,$05,$1f,$ff,$ff,$c0,$00,$7f
	dc.b	$ef,$ff,$d5,$00,$f1,$ff,$04,$e0,$00,$00,$3f,$ff,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$3f,$ff,$b2,$00,$04,$1f,$ff,$ff,$c0,$00,$ee,$ff
	dc.b	$d5,$00,$f1,$ff,$04,$e0,$00,$00,$3f,$fe,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$3f,$fe,$b2,$00,$04,$1f,$ff,$ff,$c0,$01,$ee,$ff,$d5,$00
	dc.b	$f1,$ff,$04,$e0,$00,$00,$7f,$fc,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$7f,$fc,$b2,$00,$04,$1f,$ff,$ff,$80,$03,$ee,$ff,$d5,$00,$f1,$ff
	dc.b	$04,$e0,$00,$00,$7f,$f8,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$7f,$f8,$b2,$00,$04,$1f,$ff,$ff,$80,$07,$ee,$ff,$d5,$00,$f1,$ff,$04,$e0
	dc.b	$00,$00,$ff,$f0,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$ff,$f0,$b2,$00,$04,$1f,$ff,$ff,$00,$0f,$ee,$ff,$d5,$00,$f1,$ff,$04,$e0,$00,$00
	dc.b	$ff,$e0,$c2,$00,$f1,$ff,$04,$e0,$00,$00,$ff,$e0,$b2,$00,$04,$1f,$ff,$ff,$00,$1f,$ee,$ff,$d5,$00,$f1,$ff,$04,$e0,$00,$00,$ff,$c0
	dc.b	$c2,$00,$ec,$ff,$00,$fe,$b3,$00,$04,$1f,$ff,$ff,$00,$3f,$ee,$ff,$d5,$00,$f1,$ff,$04,$c0,$00,$01,$ff,$80,$c2,$00,$f1,$ff,$04,$c0
	dc.b	$00,$01,$ff,$80,$b2,$00,$04,$3f,$ff,$fe,$00,$7f,$ee,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$01,$ff,$c1,$00,$f1,$ff,$03,$c0,$00,$01,$ff
	dc.b	$b1,$00,$03,$3f,$ff,$fe,$00,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$01,$ff,$c1,$00,$f1,$ff,$03,$c0,$00,$01,$ff,$b1,$00,$03,$3f,$ff
	dc.b	$fe,$00,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$03,$fe,$c1,$00,$f1,$ff,$03,$c0,$00,$03,$fe,$b1,$00,$03,$3f,$ff,$fc,$01,$ed,$ff,$d5
	dc.b	$00,$f1,$ff,$03,$c0,$00,$03,$fe,$c1,$00,$f1,$ff,$03,$c0,$00,$03,$fe,$b1,$00,$03,$3f,$ff,$fc,$01,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0
	dc.b	$00,$03,$fe,$c1,$00,$f1,$ff,$03,$c0,$00,$03,$fe,$b1,$00,$03,$3f,$ff,$fc,$01,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$07,$fc,$c1,$00
	dc.b	$f1,$ff,$03,$c0,$00,$07,$fc,$b1,$00,$03,$3f,$ff,$f8,$03,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$07,$fc,$c1,$00,$f1,$ff,$03,$c0,$00
	dc.b	$07,$fc,$b1,$00,$03,$3f,$ff,$f8,$03,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$07,$fc,$c1,$00,$ec,$ff,$00,$fe,$b3,$00,$03,$3f,$ff,$f8
	dc.b	$03,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$0f,$f8,$c1,$00,$f1,$ff,$03,$c0,$00,$0f,$f8,$b1,$00,$03,$3f,$ff,$f0,$07,$ed,$ff,$d5,$00
	dc.b	$f1,$ff,$03,$c0,$00,$0f,$f8,$c1,$00,$f1,$ff,$03,$c0,$00,$0f,$f8,$b1,$00,$03,$3f,$ff,$f0,$07,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00
	dc.b	$1f,$f8,$c1,$00,$f1,$ff,$03,$c0,$00,$1f,$f8,$b1,$00,$03,$3f,$ff,$e0,$07,$ed,$ff,$d5,$00,$f1,$ff,$03,$c0,$00,$1f,$f0,$c1,$00,$f1
	dc.b	$ff,$03,$c0,$00,$1f,$f0,$b1,$00,$03,$3f,$ff,$e0,$0f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$1f,$f0,$c1,$00,$f1,$ff,$03,$80,$00,$1f
	dc.b	$f0,$b1,$00,$03,$7f,$ff,$e0,$0f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$3f,$f0,$c1,$00,$f1,$ff,$03,$80,$00,$3f,$f0,$b1,$00,$03,$7f
	dc.b	$ff,$c0,$0f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$3f,$e0,$c1,$00,$f1,$ff,$03,$80,$00,$3f,$e0,$b1,$00,$03,$7f,$ff,$c0,$1f,$ed,$ff
	dc.b	$d5,$00,$f1,$ff,$03,$80,$00,$3f,$e0,$c1,$00,$f1,$ff,$03,$80,$00,$3f,$e0,$b1,$00,$03,$7f,$ff,$c0,$1f,$ed,$ff,$d5,$00,$f1,$ff,$03
	dc.b	$80,$00,$7f,$e0,$c1,$00,$f1,$ff,$00,$bf,$fd,$ff,$00,$fe,$b3,$00,$03,$7f,$ff,$80,$1f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$7f,$c0
	dc.b	$c1,$00,$f1,$ff,$03,$80,$00,$7f,$c0,$b1,$00,$03,$7f,$ff,$80,$3f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$7f,$c0,$c1,$00,$f1,$ff,$03
	dc.b	$80,$00,$7f,$c0,$b1,$00,$03,$7f,$ff,$80,$3f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$ff,$c0,$c1,$00,$f1,$ff,$03,$80,$00,$ff,$c0,$b1
	dc.b	$00,$03,$7f,$ff,$00,$3f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$ff,$80,$c1,$00,$f6,$ff,$00,$df,$fd,$ff,$03,$80,$00,$ff,$80,$b6,$00
	dc.b	$00,$20,$fd,$00,$03,$7f,$ff,$00,$7f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$00,$ff,$80,$c1,$00,$f7,$ff,$01,$80,$1f,$fd,$ff,$03,$80,$00
	dc.b	$ff,$80,$b7,$00,$01,$7f,$e0,$fd,$00,$03,$7f,$ff,$00,$7f,$ed,$ff,$d5,$00,$f1,$ff,$03,$80,$01,$ff,$80,$c1,$00,$f8,$ff,$02,$00,$00
	dc.b	$1f,$fd,$ff,$03,$80,$01,$ff,$80,$b8,$00,$02,$ff,$ff,$e0,$fd,$00,$03,$7f,$fe,$00,$7f,$ed,$ff,$d5,$00,$f1,$ff,$02,$80,$01,$ff,$c0
	dc.b	$00,$fa,$ff,$00,$fe,$fe,$00,$00,$0f,$fd,$ff,$02,$80,$01,$ff,$b9,$00,$00,$01,$fe,$ff,$00,$f0,$fd,$00,$02,$7f,$fe,$00,$ec,$ff,$d5
	dc.b	$00,$f1,$ff,$02,$00,$03,$ff,$c0,$00,$fb,$ff,$00,$fc,$fd,$00,$00,$0f,$fd,$ff,$02,$00,$03,$ff,$ba,$00,$00,$03,$fd,$ff,$00,$f0,$fd
	dc.b	$00,$02,$ff,$fc,$00,$ec,$ff,$d5,$00,$f1,$ff,$02,$00,$03,$ff,$c0,$00,$fc,$ff,$00,$f8,$fc,$00,$00,$0f,$fd,$ff,$02,$00,$03,$ff,$bb
	dc.b	$00,$00,$07,$fc,$ff,$00,$f0,$fd,$00,$02,$ff,$fc,$00,$ec,$ff,$d5,$00,$f1,$ff,$02,$00,$03,$fe,$c0,$00,$fd,$ff,$00,$f0,$fb,$00,$00
	dc.b	$0f,$fd,$ff,$02,$00,$03,$fe,$bc,$00,$00,$0f,$fb,$ff,$00,$f0,$fd,$00,$02,$ff,$fc,$01,$ec,$ff,$d5,$00,$f1,$ff,$02,$00,$07,$fe,$c0
	dc.b	$00,$fe,$ff,$00,$e0,$fa,$00,$00,$07,$fd,$ff,$02,$00,$07,$fe,$bd,$00,$00,$1f,$fa,$ff,$00,$f8,$fd,$00,$02,$ff,$f8,$01,$ec,$ff,$d5
	dc.b	$00,$f1,$ff,$02,$00,$07,$fe,$c0,$00,$02,$ff,$ff,$c0,$f9,$00,$00,$07,$fd,$ff,$02,$00,$07,$fe,$be,$00,$00,$3f,$f9,$ff,$00,$f8,$fd
	dc.b	$00,$02,$ff,$f8,$01,$ec,$ff,$d5,$00,$f1,$ff,$02,$01,$ff,$fc,$c0,$00,$01,$ff,$80,$f8,$00,$00,$07,$fd,$ff,$02,$01,$ff,$fc,$bf,$00
	dc.b	$00,$7f,$f8,$ff,$00,$f8,$fd,$00,$02,$fe,$00,$03,$ec,$ff,$d5,$00,$f1,$ff,$02,$7f,$ff,$fc,$b5,$00,$00,$07,$fd,$ff,$02,$7f,$ff,$fc
	dc.b	$c0,$00,$f6,$ff,$00,$f8,$fd,$00,$02,$80,$00,$03,$ec,$ff,$d5,$00,$ef,$ff,$00,$fc,$b5,$00,$00,$07,$fb,$ff,$00,$fc,$c0,$00,$f6,$ff
	dc.b	$00,$f8,$fb,$00,$00,$03,$ec,$ff,$d5,$00,$ef,$ff,$00,$f8,$b5,$00,$00,$03,$fb,$ff,$00,$f8,$c0,$00,$f6,$ff,$00,$fc,$fb,$00,$00,$07
	dc.b	$ec,$ff,$d5,$00,$ef,$ff,$00,$f8,$b5,$00,$00,$03,$fb,$ff,$00,$f8,$c0,$00,$f6,$ff,$00,$fc,$fb,$00,$00,$07,$ec,$ff,$d5,$00,$f4,$ff
	dc.b	$00,$f7,$fd,$ff,$00,$f8,$b5,$00,$00,$03,$fb,$ff,$00,$f8,$c0,$00,$f6,$ff,$02,$fc,$00,$08,$fd,$00,$00,$07,$ec,$ff,$d5,$00,$f5,$ff
	dc.b	$01,$fc,$07,$fd,$ff,$00,$f0,$b5,$00,$00,$03,$fb,$ff,$00,$f0,$c0,$00,$f6,$ff,$02,$fc,$03,$f8,$fd,$00,$00,$0f,$ec,$ff,$d5,$00,$f5
	dc.b	$ff,$01,$00,$07,$fd,$ff,$00,$f0,$b5,$00,$00,$01,$fb,$ff,$00,$f0,$c0,$00,$f6,$ff,$02,$fe,$ff,$f8,$fd,$00,$00,$0f,$ec,$ff,$d5,$00
	dc.b	$f5,$ff,$01,$00,$07,$fd,$ff,$00,$f0,$b5,$00,$00,$01,$fb,$ff,$00,$f0,$c0,$00,$f6,$ff,$02,$fe,$ff,$f8,$fd,$00,$00,$0f,$ec,$ff,$d5
	dc.b	$00,$f5,$ff,$01,$00,$03,$fd,$ff,$00,$e0,$b5,$00,$00,$01,$fb,$ff,$00,$e0,$c0,$00,$f6,$ff,$02,$fe,$ff,$fc,$fd,$00,$00,$1f,$ec,$ff
	dc.b	$d5,$00,$f5,$ff,$01,$80,$03,$fd,$ff,$00,$e0,$b5,$00,$00,$01,$fb,$ff,$00,$e0,$c0,$00,$f6,$ff,$02,$fe,$7f,$fc,$fd,$00,$00,$1f,$ec
	dc.b	$ff,$d5,$00,$f5,$ff,$01,$80,$03,$fd,$ff,$00,$e0,$b4,$00,$fb,$ff,$00,$e0,$c0,$00,$f5,$ff,$01,$7f,$fc,$fd,$00,$00,$1f,$ec,$ff,$d5
	dc.b	$00,$f5,$ff,$01,$80,$03,$fd,$ff,$00,$c0,$b4,$00,$fb,$ff,$00,$c0,$c0,$00,$f5,$ff,$01,$7f,$fc,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$f5
	dc.b	$ff,$01,$80,$03,$fd,$ff,$00,$c0,$b4,$00,$fb,$ff,$00,$c0,$c0,$00,$f5,$ff,$01,$7f,$fc,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$f5,$ff,$01
	dc.b	$80,$03,$fd,$ff,$00,$c0,$b4,$00,$fb,$ff,$00,$c0,$c0,$00,$f5,$ff,$01,$7f,$fc,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$f5,$ff,$01,$80,$01
	dc.b	$fd,$ff,$00,$80,$b4,$00,$fb,$ff,$00,$80,$c0,$00,$f5,$ff,$01,$7f,$fe,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$f5,$ff,$01,$c0,$01,$fd,$ff
	dc.b	$00,$80,$b4,$00,$00,$7f,$fc,$ff,$00,$80,$c0,$00,$f5,$ff,$01,$bf,$fe,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$f5,$ff,$01,$c0,$01,$fd,$ff
	dc.b	$00,$80,$b4,$00,$00,$7f,$fc,$ff,$00,$80,$c0,$00,$f5,$ff,$01,$bf,$fe,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$f5,$ff,$01,$c0,$7f,$fd,$ff
	dc.b	$f0,$00,$01,$03,$e0,$c6,$00,$00,$7f,$fc,$ff,$f0,$00,$01,$03,$e0,$d2,$00,$f5,$ff,$01,$bf,$80,$fd,$00,$eb,$ff,$d5,$00,$f5,$ff,$00
	dc.b	$df,$fc,$ff,$f0,$00,$00,$3e,$c5,$00,$00,$7f,$fc,$ff,$f0,$00,$00,$3e,$d1,$00,$f5,$ff,$00,$a0,$fc,$00,$eb,$ff,$d5,$00,$ef,$ff,$f1
	dc.b	$00,$01,$03,$e0,$c5,$00,$00,$3f,$fc,$ff,$f1,$00,$01,$03,$e0,$d1,$00,$f5,$ff,$00,$c0,$fc,$00,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$f1
	dc.b	$00,$00,$3e,$c4,$00,$00,$3f,$fd,$ff,$00,$fe,$f1,$00,$00,$3e,$d0,$00,$f5,$ff,$00,$c0,$fd,$00,$00,$01,$eb,$ff,$d5,$00,$f0,$ff,$00
	dc.b	$fe,$f2,$00,$01,$03,$e0,$c4,$00,$00,$3f,$fd,$ff,$00,$fe,$f2,$00,$01,$03,$e0,$d0,$00,$f5,$ff,$00,$c0,$fd,$00,$00,$01,$eb,$ff,$d5
	dc.b	$00,$f0,$ff,$00,$fe,$f2,$00,$00,$3e,$c3,$00,$00,$3f,$fd,$ff,$00,$fe,$f2,$00,$00,$3e,$cf,$00,$f5,$ff,$00,$c0,$fd,$00,$00,$01,$eb
	dc.b	$ff,$d5,$00,$f0,$ff,$00,$fc,$f3,$00,$04,$03,$e0,$00,$03,$e0,$c6,$00,$00,$3f,$fd,$ff,$00,$fc,$f3,$00,$04,$03,$e0,$00,$03,$e0,$d2
	dc.b	$00,$f5,$ff,$00,$c0,$fd,$00,$00,$03,$eb,$ff,$d5,$00,$f0,$ff,$00,$fc,$f3,$00,$03,$3e,$00,$00,$3e,$c5,$00,$00,$1f,$fd,$ff,$00,$fc
	dc.b	$f3,$00,$03,$3e,$00,$00,$3e,$d1,$00,$f5,$ff,$00,$e0,$fd,$00,$00,$03,$eb,$ff,$d5,$00,$f0,$ff,$00,$fc,$f4,$00,$04,$03,$e0,$00,$03
	dc.b	$e0,$c5,$00,$00,$1f,$fd,$ff,$00,$fc,$f4,$00,$04,$03,$e0,$00,$03,$e0,$d1,$00,$f5,$ff,$00,$e0,$fd,$00,$00,$03,$eb,$ff,$d5,$00,$f0
	dc.b	$ff,$00,$f8,$f4,$00,$03,$3e,$00,$00,$3e,$c4,$00,$00,$1f,$fd,$ff,$00,$f8,$f4,$00,$03,$3e,$00,$00,$3e,$d0,$00,$f5,$ff,$00,$e0,$fd
	dc.b	$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f2,$00,$01,$03,$e0,$c4,$00,$00,$1f,$fd,$ff,$00,$f8,$f2,$00,$01,$03,$e0,$d0,$00,$f5
	dc.b	$ff,$00,$e0,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f2,$00,$00,$3e,$c3,$00,$00,$0f,$fd,$ff,$00,$f8,$f2,$00,$00,$3e,$cf
	dc.b	$00,$f5,$ff,$00,$f0,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f0,$f3,$00,$04,$03,$e0,$00,$03,$e0,$c6,$00,$00,$0f,$fd,$ff,$00
	dc.b	$f0,$f3,$00,$04,$03,$e0,$00,$03,$e0,$d2,$00,$f5,$ff,$00,$f0,$fd,$00,$00,$0f,$eb,$ff,$d5,$00,$f0,$ff,$00,$f0,$f3,$00,$03,$3e,$00
	dc.b	$00,$3e,$c5,$00,$00,$0f,$fd,$ff,$00,$f0,$f3,$00,$03,$3e,$00,$00,$3e,$d1,$00,$f5,$ff,$00,$f0,$fd,$00,$00,$0f,$eb,$ff,$d5,$00,$f0
	dc.b	$ff,$00,$f0,$f4,$00,$04,$03,$e0,$00,$03,$e0,$c5,$00,$00,$0f,$fd,$ff,$00,$f0,$f4,$00,$04,$03,$e0,$00,$03,$e0,$d1,$00,$f5,$ff,$00
	dc.b	$f0,$fd,$00,$00,$0f,$eb,$ff,$d5,$00,$f0,$ff,$00,$f0,$f4,$00,$03,$3e,$00,$00,$3e,$c4,$00,$00,$07,$fd,$ff,$00,$f0,$f4,$00,$03,$3e
	dc.b	$00,$00,$3e,$d0,$00,$f5,$ff,$00,$f8,$fd,$00,$00,$0f,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f2,$00,$01,$03,$e0,$c4,$00,$00,$07,$fd,$ff
	dc.b	$00,$f8,$f2,$00,$01,$03,$e0,$d0,$00,$f5,$ff,$00,$f8,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f2,$00,$00,$3e,$c3,$00,$00
	dc.b	$07,$fd,$ff,$00,$f8,$f2,$00,$00,$3e,$cf,$00,$f5,$ff,$00,$f8,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f3,$00,$04,$03,$e0
	dc.b	$00,$03,$e0,$c6,$00,$00,$07,$fd,$ff,$00,$f8,$f3,$00,$04,$03,$e0,$00,$03,$e0,$d2,$00,$f5,$ff,$00,$f8,$fd,$00,$00,$07,$eb,$ff,$d5
	dc.b	$00,$f0,$ff,$00,$f8,$f3,$00,$03,$3e,$00,$00,$3e,$c5,$00,$00,$07,$fd,$ff,$00,$f8,$f3,$00,$03,$3e,$00,$00,$3e,$d1,$00,$f5,$ff,$00
	dc.b	$f8,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$f8,$f4,$00,$04,$03,$e0,$00,$03,$e0,$c5,$00,$00,$03,$fd,$ff,$00,$f8,$f4,$00,$04
	dc.b	$03,$e0,$00,$03,$e0,$d1,$00,$f5,$ff,$00,$fc,$fd,$00,$00,$07,$eb,$ff,$d5,$00,$f0,$ff,$00,$fc,$f4,$00,$03,$3e,$00,$00,$3e,$c4,$00
	dc.b	$00,$03,$fd,$ff,$00,$fc,$f4,$00,$03,$3e,$00,$00,$3e,$d0,$00,$f5,$ff,$00,$fc,$fd,$00,$00,$03,$eb,$ff,$d5,$00,$f0,$ff,$00,$fc,$f2
	dc.b	$00,$01,$03,$e0,$c4,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$01,$03,$e0,$d0,$00,$f5,$ff,$00,$fc,$fd,$00,$00,$03,$eb,$ff,$d5,$00,$f0
	dc.b	$ff,$00,$fc,$f2,$00,$00,$3e,$c3,$00,$00,$03,$fd,$ff,$00,$fc,$f2,$00,$00,$3e,$cf,$00,$f5,$ff,$00,$fc,$fd,$00,$00,$03,$eb,$ff,$d5
	dc.b	$00,$f0,$ff,$00,$fc,$f3,$00,$01,$03,$e0,$c3,$00,$00,$01,$fd,$ff,$00,$fc,$f3,$00,$01,$03,$e0,$cf,$00,$f5,$ff,$00,$fe,$fd,$00,$00
	dc.b	$03,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$f3,$00,$00,$3e,$c2,$00,$00,$01,$fd,$ff,$00,$fe,$f3,$00,$00,$3e,$ce,$00,$f5,$ff,$00,$fe,$fd
	dc.b	$00,$00,$01,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$f4,$00,$01,$03,$e0,$c2,$00,$00,$01,$fd,$ff,$00,$fe,$f4,$00,$01,$03,$e0,$ce,$00,$f5
	dc.b	$ff,$00,$fe,$fd,$00,$00,$01,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$f4,$00,$00,$3e,$c1,$00,$00,$01,$fd,$ff,$00,$fe,$f4,$00,$00,$3e,$cd
	dc.b	$00,$f5,$ff,$00,$fe,$fd,$00,$00,$01,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$b3,$00,$00,$01,$fd,$ff,$00,$fe,$bf,$00,$f5,$ff,$00,$fe,$fd
	dc.b	$00,$00,$01,$eb,$ff,$d5,$00,$f0,$ff,$00,$fe,$b2,$00,$fd,$ff,$00,$fe,$bf,$00,$f4,$ff,$fd,$00,$00,$01,$eb,$ff,$d5,$00,$ef,$ff,$b2
	dc.b	$00,$fc,$ff,$bf,$00,$f4,$ff,$fc,$00,$eb,$ff,$d5,$00,$ef,$ff,$b2,$00,$fc,$ff,$bf,$00,$f4,$ff,$fc,$00,$eb,$ff,$d5,$00,$ef,$ff,$b2
	dc.b	$00,$fc,$ff,$bf,$00,$f4,$ff,$fc,$00,$eb,$ff,$d5,$00,$ef,$ff,$b2,$00,$00,$7f,$fd,$ff,$bf,$00,$f4,$ff,$00,$80,$fd,$00,$eb,$ff,$d5
	dc.b	$00,$ef,$ff,$b2,$00,$00,$7f,$fd,$ff,$bf,$00,$f4,$ff,$00,$80,$fd,$00,$eb,$ff,$d5,$00,$ef,$ff,$00,$80,$b3,$00,$00,$7f,$fd,$ff,$00
	dc.b	$80,$c0,$00,$f4,$ff,$00,$80,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$ef,$ff,$00,$80,$b3,$00,$00,$7f,$fd,$ff,$00,$80,$c0,$00,$f4,$ff,$00
	dc.b	$80,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$ef,$ff,$00,$80,$b3,$00,$00,$3f,$fd,$ff,$00,$80,$c0,$00,$f4,$ff,$00,$c0,$fd,$00,$00,$7f,$ec
	dc.b	$ff,$d5,$00,$ef,$ff,$00,$80,$b3,$00,$00,$3f,$fd,$ff,$00,$80,$c0,$00,$f4,$ff,$00,$c0,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$ef,$ff,$00
	dc.b	$80,$b3,$00,$00,$3f,$fd,$ff,$00,$80,$c0,$00,$f4,$ff,$00,$c0,$fd,$00,$00,$7f,$ec,$ff,$d5,$00,$ef,$ff,$00,$c0,$b3,$00,$00,$3f,$fd
	dc.b	$ff,$00,$c0,$c0,$00,$f4,$ff,$00,$c0,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$ef,$ff,$00,$c0,$b3,$00,$00,$3f,$fd,$ff,$00,$c0,$c0,$00,$f4
	dc.b	$ff,$00,$c0,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$ef,$ff,$00,$c0,$b3,$00,$00,$1f,$fd,$ff,$00,$c0,$c0,$00,$f4,$ff,$00,$e0,$fd,$00,$00
	dc.b	$3f,$ec,$ff,$d5,$00,$ef,$ff,$00,$c0,$b3,$00,$00,$1f,$fd,$ff,$00,$c0,$c0,$00,$f4,$ff,$00,$e0,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$ef
	dc.b	$ff,$00,$c0,$b3,$00,$00,$1f,$fd,$ff,$00,$c0,$c0,$00,$f4,$ff,$00,$e0,$fd,$00,$00,$3f,$ec,$ff,$d5,$00,$ef,$ff,$00,$e0,$b3,$00,$00
	dc.b	$1f,$fd,$ff,$00,$e0,$c0,$00,$f4,$ff,$00,$e0,$fd,$00,$00,$1f,$ec,$ff,$d5,$00,$ef,$ff,$00,$e0,$b3,$00,$00,$0f,$fd,$ff,$00,$e0,$c0
	dc.b	$00,$f4,$ff,$00,$f0,$fd,$00,$00,$1f,$ec,$ff,$d5,$00,$ef,$ff,$00,$e0,$b3,$00,$00,$0f,$fd,$ff,$00,$e0,$c0,$00,$f4,$ff,$00,$f0,$fd
	dc.b	$00,$00,$1f,$ec,$ff,$d5,$00,$ef,$ff,$00,$e0,$b3,$00,$00,$0f,$fd,$ff,$00,$e0,$c0,$00,$f4,$ff,$00,$f0,$fd,$00,$00,$1f,$ec,$ff,$d5
	dc.b	$00,$ef,$ff,$00,$f0,$b3,$00,$00,$0f,$fd,$ff,$00,$f0,$c0,$00,$f4,$ff,$00,$f0,$fd,$00,$00,$0f,$ec,$ff,$d5,$00,$ef,$ff,$00,$f0,$b3
	dc.b	$00,$00,$0f,$fd,$ff,$00,$f0,$c0,$00,$f4,$ff,$00,$f0,$fd,$00,$00,$0f,$ec,$ff,$d5,$00,$ef,$ff,$00,$f0,$b3,$00,$00,$07,$fd,$ff,$00
	dc.b	$f0,$c0,$00,$f4,$ff,$00,$f8,$fd,$00,$00,$0f,$ec,$ff,$d5,$00,$ef,$ff,$00,$f0,$b3,$00,$00,$07,$fd,$ff,$00,$f0,$c0,$00,$f4,$ff,$00
	dc.b	$f8,$fd,$00,$00,$0f,$ec,$ff,$d5,$00,$ef,$ff,$00,$f0,$b3,$00,$00,$07,$fd,$ff,$00,$f0,$c0,$00,$f4,$ff,$00,$f8,$fd,$00,$00,$0f,$ec
	dc.b	$ff,$d5,$00,$ef,$ff,$00,$f8,$b3,$00,$00,$07,$fd,$ff,$00,$f8,$c0,$00,$f4,$ff,$00,$f8,$fd,$00,$00,$07,$ec,$ff,$d5,$00,$ef,$ff,$00
	dc.b	$f8,$b3,$00,$00,$03,$fd,$ff,$00,$f8,$c0,$00,$f4,$ff,$00,$fc,$fd,$00,$00,$07,$ec,$ff,$d5,$00,$ef,$ff,$00,$f8,$b3,$00,$00,$03,$fd
	dc.b	$ff,$00,$f8,$c0,$00,$f4,$ff,$00,$fc,$fd,$00,$00,$07,$ec,$ff,$d5,$00,$ef,$ff,$00,$f8,$b3,$00,$00,$03,$fd,$ff,$00,$f8,$c0,$00,$f4
	dc.b	$ff,$00,$fc,$fd,$00,$00,$07,$ec,$ff,$d5,$00,$ef,$ff,$00,$f8,$b3,$00,$00,$03,$fd,$ff,$00,$f8,$c0,$00,$f4,$ff,$00,$fc,$fd,$00,$00
	dc.b	$07,$ec,$ff,$d5,$00,$ef,$ff,$00,$fc,$b3,$00,$00,$01,$fd,$ff,$00,$fc,$c0,$00,$f4,$ff,$00,$fe,$fd,$00,$00,$03,$ec,$ff,$d5,$00,$ef
	dc.b	$ff,$00,$fc,$b3,$00,$00,$01,$fd,$ff,$00,$fc,$c0,$00,$f4,$ff,$00,$fe,$fd,$00,$00,$03,$ec,$ff,$d5,$00,$f4,$ff,$00,$fe,$81,$00,$e7
	dc.b	$00,$f4,$ff,$00,$fe,$fd,$00,$00,$03,$ec,$ff,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81
	dc.b	$00,$81,$00,$81,$00,$81,$00,$f3,$00,$80
	even
bg_flight	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$c7,$00,$d9,$ff,$d5,$00,$f2,$ff,$fb,$00,$00,$1f,$ef,$ff,$81,$00,$d9,$ff,$d5,$00,$f2,$ff,$fb,$00,$00,$1f
	dc.b	$ef,$ff,$81,$00,$d9,$ff,$d5,$00,$f4,$ff,$02,$fd,$ff,$80,$fc,$00,$00,$3f,$ef,$ff,$c8,$00,$00,$02,$bb,$00,$d9,$ff,$d5,$00,$f5,$ff
	dc.b	$03,$fe,$01,$ff,$80,$fc,$00,$00,$3f,$ef,$ff,$c9,$00,$01,$01,$fe,$bb,$00,$02,$ff,$ff,$df,$dc,$ff,$d5,$00,$f5,$ff,$03,$80,$00,$ff
	dc.b	$80,$fc,$00,$00,$3f,$ef,$ff,$d3,$00,$00,$20,$f8,$00,$01,$7f,$ff,$bb,$00,$d9,$ff,$d5,$00,$f6,$ff,$04,$c0,$00,$00,$ff,$c0,$fc,$00
	dc.b	$00,$7f,$ef,$ff,$ca,$00,$02,$3f,$ff,$ff,$bb,$00,$d9,$ff,$d5,$00,$f7,$ff,$00,$e0,$fe,$00,$01,$7f,$c0,$fc,$00,$00,$7f,$ef,$ff,$cb
	dc.b	$00,$00,$1f,$fe,$ff,$00,$80,$bc,$00,$d9,$ff,$d5,$00,$f8,$ff,$00,$f8,$fd,$00,$01,$7f,$e0,$fc,$00,$00,$7f,$ef,$ff,$cc,$00,$00,$07
	dc.b	$fd,$ff,$00,$80,$bc,$00,$d9,$ff,$d5,$00,$f9,$ff,$00,$fc,$fc,$00,$01,$3f,$e0,$fc,$00,$ee,$ff,$cd,$00,$00,$03,$fc,$ff,$00,$c0,$bc
	dc.b	$00,$fb,$ff,$02,$f8,$00,$01,$e3,$ff,$d4,$00,$fb,$ff,$00,$f8,$fa,$00,$01,$3f,$e0,$fc,$00,$ef,$ff,$ce,$00,$00,$07,$fa,$ff,$00,$c0
	dc.b	$e9,$00,$00,$ff,$d5,$00,$fd,$ff,$00,$e0,$fd,$00,$00,$7f,$e6,$ff,$00,$fe,$d3,$00,$fd,$ff,$00,$e0,$f8,$00,$01,$1f,$f0,$fc,$00,$f1
	dc.b	$ff,$00,$fe,$cf,$00,$00,$1f,$f8,$ff,$00,$e0,$eb,$00,$02,$01,$ff,$ff,$d5,$00,$02,$ff,$ff,$c0,$fb,$00,$00,$7f,$e7,$ff,$00,$fe,$d2
	dc.b	$00,$02,$ff,$ff,$c0,$fb,$00,$00,$40,$fd,$00,$01,$1f,$f0,$fc,$00,$f2,$ff,$00,$fe,$d0,$00,$00,$3f,$fb,$ff,$00,$bf,$fd,$ff,$00,$e0
	dc.b	$ec,$00,$00,$01,$fe,$ff,$cc,$00,$00,$3f,$e8,$ff,$00,$fc,$c8,$00,$00,$20,$fd,$00,$01,$0f,$f0,$fd,$00,$00,$01,$f3,$ff,$00,$fc,$d1
	dc.b	$00,$f8,$ff,$00,$df,$fd,$ff,$00,$f0,$ed,$00,$00,$03,$fd,$ff,$cc,$00,$00,$1f,$e8,$ff,$00,$c0,$c8,$00,$00,$10,$fd,$00,$01,$0f,$f8
	dc.b	$fd,$00,$00,$01,$f3,$ff,$00,$c0,$d1,$00,$f8,$ff,$00,$ef,$fd,$ff,$00,$f0,$ed,$00,$00,$3f,$fd,$ff,$cc,$00,$00,$0f,$e9,$ff,$00,$fe
	dc.b	$c7,$00,$00,$0c,$fd,$00,$01,$07,$f8,$fd,$00,$00,$01,$f4,$ff,$00,$fe,$d0,$00,$f8,$ff,$00,$f3,$fd,$ff,$00,$f8,$ee,$00,$00,$01,$fc
	dc.b	$ff,$cc,$00,$00,$0f,$fd,$ff,$00,$fb,$fa,$ff,$04,$df,$ff,$ff,$7f,$df,$fa,$ff,$00,$e0,$c7,$00,$00,$0e,$fd,$00,$01,$07,$f8,$fd,$00
	dc.b	$00,$03,$f4,$ff,$00,$e0,$d0,$00,$f8,$ff,$00,$f1,$fd,$ff,$00,$fc,$fa,$00,$04,$20,$00,$00,$80,$20,$fa,$00,$00,$1f,$fc,$ff,$cc,$00
	dc.b	$00,$07,$e9,$ff,$c6,$00,$00,$07,$fd,$00,$01,$03,$fc,$fd,$00,$00,$03,$f4,$ff,$cf,$00,$f8,$ff,$00,$f8,$fd,$ff,$00,$fc,$ee,$00,$fb
	dc.b	$ff,$cc,$00,$00,$03,$ea,$ff,$00,$f0,$c6,$00,$01,$03,$80,$fe,$00,$01,$03,$fc,$fd,$00,$00,$03,$f5,$ff,$00,$f0,$cf,$00,$f8,$ff,$01
	dc.b	$fc,$7f,$fe,$ff,$00,$fc,$ef,$00,$00,$0f,$fb,$ff,$cc,$00,$00,$01,$ea,$ff,$c5,$00,$01,$01,$e0,$fe,$00,$01,$01,$fe,$fd,$00,$00,$07
	dc.b	$f5,$ff,$ce,$00,$f8,$ff,$01,$fe,$1f,$fe,$ff,$00,$fe,$ef,$00,$fa,$ff,$cc,$00,$00,$01,$eb,$ff,$00,$f8,$c5,$00,$01,$01,$f0,$fe,$00
	dc.b	$01,$01,$fe,$fd,$00,$00,$07,$f6,$ff,$00,$f8,$ce,$00,$f8,$ff,$01,$fe,$0f,$fe,$ff,$00,$fe,$f0,$00,$00,$07,$fa,$ff,$cb,$00,$eb,$ff
	dc.b	$00,$80,$c4,$00,$00,$f8,$fd,$00,$00,$fe,$fd,$00,$00,$07,$f6,$ff,$00,$80,$ce,$00,$f7,$ff,$00,$07,$fd,$ff,$f0,$00,$00,$7f,$fa,$ff
	dc.b	$cb,$00,$00,$7f,$ed,$ff,$00,$fc,$c3,$00,$00,$7c,$fd,$00,$00,$ff,$fd,$00,$00,$0f,$f7,$ff,$00,$fc,$cd,$00,$f7,$ff,$00,$83,$fd,$ff
	dc.b	$f1,$00,$00,$03,$f9,$ff,$cb,$00,$00,$3f,$ed,$ff,$00,$c0,$c3,$00,$00,$3f,$fd,$00,$00,$7f,$fd,$00,$00,$0f,$f7,$ff,$00,$c0,$cd,$00
	dc.b	$f7,$ff,$00,$c0,$fd,$ff,$00,$80,$f2,$00,$00,$3f,$f9,$ff,$cb,$00,$00,$3f,$ed,$ff,$00,$c0,$c3,$00,$06,$3f,$80,$00,$00,$01,$ff,$80
	dc.b	$fe,$00,$00,$0f,$f7,$ff,$00,$c0,$cd,$00,$f7,$ff,$04,$c0,$7f,$ff,$ff,$fe,$f1,$00,$00,$3f,$f9,$ff,$cb,$00,$00,$1f,$ed,$ff,$00,$c0
	dc.b	$c3,$00,$06,$1f,$c0,$00,$00,$07,$ff,$80,$fe,$00,$00,$1f,$f7,$ff,$00,$c0,$cd,$00,$f7,$ff,$04,$e0,$3f,$ff,$ff,$f8,$f1,$00,$00,$3f
	dc.b	$f9,$ff,$cb,$00,$00,$0f,$ed,$ff,$00,$e0,$c3,$00,$06,$0f,$e0,$00,$00,$1f,$ff,$c0,$fe,$00,$00,$1f,$f7,$ff,$00,$e0,$cd,$00,$f7,$ff
	dc.b	$04,$f0,$1f,$ff,$ff,$e0,$f1,$00,$00,$1f,$f9,$ff,$cb,$00,$00,$07,$fd,$ff,$00,$fe,$f2,$ff,$00,$e0,$c3,$00,$06,$07,$f8,$00,$00,$7f
	dc.b	$ff,$c0,$fe,$00,$00,$1f,$f7,$ff,$00,$e0,$cd,$00,$f7,$ff,$05,$f8,$07,$ff,$ff,$80,$01,$f2,$00,$00,$1f,$f9,$ff,$cb,$00,$00,$03,$ed
	dc.b	$ff,$00,$e0,$c3,$00,$06,$03,$fc,$00,$01,$ff,$ff,$e0,$fe,$00,$00,$1f,$f7,$ff,$00,$e0,$cd,$00,$f7,$ff,$03,$fc,$03,$ff,$fe,$f0,$00
	dc.b	$00,$1f,$f9,$ff,$cb,$00,$00,$03,$ed,$ff,$00,$e0,$c3,$00,$06,$03,$fe,$00,$07,$ff,$ff,$f0,$fe,$00,$00,$3f,$f7,$ff,$00,$e0,$cd,$00
	dc.b	$f7,$ff,$03,$fc,$01,$ff,$f8,$f0,$00,$00,$1f,$f9,$ff,$cb,$00,$00,$01,$ed,$ff,$00,$e0,$c3,$00,$06,$01,$ff,$00,$1f,$ff,$ff,$f0,$fe
	dc.b	$00,$00,$3f,$f7,$ff,$00,$e0,$cd,$00,$f7,$ff,$03,$fe,$00,$ff,$e0,$f0,$00,$00,$1f,$f9,$ff,$ca,$00,$ed,$ff,$00,$f0,$c2,$00,$05,$ff
	dc.b	$c0,$7f,$ff,$ff,$f8,$fe,$00,$00,$3f,$f7,$ff,$00,$f0,$cd,$00,$f6,$ff,$02,$00,$3f,$80,$f0,$00,$00,$0f,$f9,$ff,$ca,$00,$00,$7f,$ee
	dc.b	$ff,$00,$f0,$c2,$00,$01,$7f,$e1,$fe,$ff,$00,$f8,$fe,$00,$00,$7f,$f7,$ff,$00,$f0,$cd,$00,$f6,$ff,$01,$80,$1e,$ef,$00,$00,$0f,$f9
	dc.b	$ff,$ca,$00,$00,$7f,$ee,$ff,$00,$f0,$c2,$00,$01,$7f,$f7,$fe,$ff,$00,$fc,$fe,$00,$00,$7f,$f8,$ff,$01,$7f,$f0,$cd,$00,$f6,$ff,$01
	dc.b	$80,$08,$f0,$00,$01,$80,$0f,$f9,$ff,$ca,$00,$00,$3f,$ee,$ff,$00,$f0,$c2,$00,$00,$3f,$fd,$ff,$03,$fe,$00,$00,$01,$f7,$ff,$01,$7f
	dc.b	$f0,$cd,$00,$f6,$ff,$00,$c0,$ef,$00,$01,$80,$0f,$f9,$ff,$ca,$00,$00,$1f,$ee,$ff,$00,$f0,$c2,$00,$00,$1f,$fd,$ff,$03,$fe,$00,$00
	dc.b	$07,$f8,$ff,$02,$fe,$3f,$f0,$cd,$00,$f6,$ff,$00,$e0,$f0,$00,$02,$01,$c0,$0f,$f9,$ff,$ca,$00,$00,$0f,$ee,$ff,$00,$f8,$c2,$00,$00
	dc.b	$0f,$fc,$ff,$02,$00,$00,$1f,$f8,$ff,$02,$fe,$3f,$f8,$cd,$00,$f6,$ff,$00,$f0,$f0,$00,$02,$01,$c0,$07,$f9,$ff,$ca,$00,$00,$0f,$f8
	dc.b	$ff,$00,$df,$f8,$ff,$00,$f8,$c2,$00,$00,$0f,$fc,$ff,$02,$00,$00,$7f,$f8,$ff,$02,$fc,$1f,$f8,$cd,$00,$f6,$ff,$00,$f0,$f8,$00,$00
	dc.b	$20,$fa,$00,$02,$03,$e0,$07,$f9,$ff,$ca,$00,$00,$07,$ee,$ff,$00,$f8,$c2,$00,$00,$07,$fc,$ff,$01,$80,$01,$f7,$ff,$02,$fc,$1f,$f8
	dc.b	$cd,$00,$f6,$ff,$00,$f8,$f0,$00,$02,$03,$e0,$07,$f9,$ff,$ca,$00,$00,$03,$ee,$ff,$00,$f8,$c2,$00,$00,$03,$fc,$ff,$01,$c0,$07,$f7
	dc.b	$ff,$02,$fc,$0f,$f8,$cd,$00,$f6,$ff,$00,$fc,$f0,$00,$02,$03,$f0,$07,$f9,$ff,$ca,$00,$00,$01,$ee,$ff,$00,$f8,$c2,$00,$00,$01,$fc
	dc.b	$ff,$01,$c0,$1f,$f7,$ff,$02,$f8,$0f,$f8,$cd,$00,$f6,$ff,$00,$fe,$f0,$00,$02,$07,$f0,$07,$f9,$ff,$ca,$00,$00,$01,$ee,$ff,$00,$fc
	dc.b	$c2,$00,$00,$01,$fc,$ff,$01,$e0,$7f,$f7,$ff,$02,$f8,$07,$fc,$cd,$00,$f6,$ff,$00,$fe,$f0,$00,$02,$07,$f8,$03,$f9,$ff,$c9,$00,$ee
	dc.b	$ff,$00,$fc,$c1,$00,$fc,$ff,$00,$e1,$f6,$ff,$02,$f0,$07,$fc,$cd,$00,$f5,$ff,$f0,$00,$02,$0f,$f8,$03,$f9,$ff,$c9,$00,$00,$7f,$ef
	dc.b	$ff,$00,$fc,$c1,$00,$00,$7f,$fd,$ff,$00,$f7,$f6,$ff,$02,$f0,$03,$fc,$cd,$00,$f5,$ff,$00,$80,$f1,$00,$02,$0f,$fc,$03,$f9,$ff,$c9
	dc.b	$00,$00,$7f,$ef,$ff,$00,$fc,$c1,$00,$00,$7f,$f0,$ff,$01,$83,$fc,$cd,$00,$f5,$ff,$00,$80,$f0,$00,$01,$7c,$03,$f9,$ff,$c9,$00,$ee
	dc.b	$ff,$00,$fc,$c1,$00,$ef,$ff,$01,$fd,$fc,$cd,$00,$f5,$ff,$ef,$00,$01,$02,$03,$f9,$ff,$c9,$00,$fd,$ff,$00,$f7,$f3,$ff,$00,$fe,$c1
	dc.b	$00,$ee,$ff,$00,$fe,$cd,$00,$f5,$ff,$fd,$00,$00,$08,$f3,$00,$00,$01,$f9,$ff,$c9,$00,$ee,$ff,$00,$fe,$c1,$00,$ee,$ff,$00,$fe,$cd
	dc.b	$00,$f5,$ff,$ee,$00,$00,$01,$f9,$ff,$ca,$00,$00,$01,$ee,$ff,$00,$fe,$c2,$00,$00,$01,$ee,$ff,$00,$fe,$cd,$00,$f6,$ff,$00,$fe,$ee
	dc.b	$00,$00,$01,$f9,$ff,$ca,$00,$00,$01,$ee,$ff,$00,$fe,$c2,$00,$00,$01,$ee,$ff,$00,$fe,$cd,$00,$f6,$ff,$00,$fe,$ee,$00,$00,$01,$f9
	dc.b	$ff,$c9,$00,$ee,$ff,$00,$fe,$c2,$00,$00,$01,$ee,$ff,$00,$fe,$cd,$00,$f5,$ff,$ee,$00,$00,$01,$f9,$ff,$ca,$00,$00,$03,$ed,$ff,$c2
	dc.b	$00,$00,$03,$ed,$ff,$cd,$00,$f6,$ff,$00,$fc,$ed,$00,$f9,$ff,$ca,$00,$00,$03,$ed,$ff,$c2,$00,$00,$03,$ed,$ff,$cd,$00,$f6,$ff,$00
	dc.b	$fc,$ed,$00,$f9,$ff,$ca,$00,$00,$03,$ed,$ff,$c2,$00,$00,$03,$ef,$ff,$01,$fd,$ff,$cd,$00,$f6,$ff,$00,$fc,$ef,$00,$01,$02,$00,$f9
	dc.b	$ff,$ca,$00,$00,$07,$ed,$ff,$00,$80,$c3,$00,$00,$07,$ef,$ff,$02,$e1,$ff,$80,$ce,$00,$f6,$ff,$00,$f8,$ef,$00,$02,$1e,$00,$7f,$fa
	dc.b	$ff,$ca,$00,$00,$07,$ed,$ff,$00,$80,$c3,$00,$00,$07,$f0,$ff,$03,$fe,$01,$ff,$80,$ce,$00,$f6,$ff,$00,$f8,$f0,$00,$03,$01,$fe,$00
	dc.b	$7f,$fa,$ff,$ca,$00,$00,$07,$fe,$ff,$00,$fe,$f1,$ff,$00,$c0,$c3,$00,$00,$07,$f0,$ff,$03,$f0,$01,$ff,$c0,$ce,$00,$f6,$ff,$00,$f8
	dc.b	$fe,$00,$00,$01,$f4,$00,$03,$0f,$fe,$00,$3f,$fa,$ff,$ca,$00,$00,$0f,$f1,$ff,$00,$df,$fe,$ff,$00,$e0,$c3,$00,$00,$0f,$f0,$ff,$03
	dc.b	$00,$01,$ff,$e0,$ce,$00,$f6,$ff,$00,$f0,$f1,$00,$04,$20,$ff,$fe,$00,$1f,$fa,$ff,$ca,$00,$00,$0f,$f8,$ff,$00,$df,$f7,$ff,$00,$f0
	dc.b	$c3,$00,$00,$0f,$f0,$ff,$03,$00,$01,$ff,$f0,$ce,$00,$f6,$ff,$00,$f0,$f8,$00,$00,$20,$fa,$00,$03,$ff,$fe,$00,$0f,$fa,$ff,$ca,$00
	dc.b	$00,$0f,$ed,$ff,$00,$f0,$c3,$00,$00,$0f,$f0,$ff,$03,$00,$00,$ff,$f0,$ce,$00,$f6,$ff,$00,$f0,$f0,$00,$03,$ff,$ff,$00,$0f,$fa,$ff
	dc.b	$ca,$00,$00,$1f,$ed,$ff,$00,$f8,$c3,$00,$00,$1f,$f0,$ff,$03,$00,$00,$ff,$f8,$ce,$00,$f6,$ff,$00,$e0,$f0,$00,$03,$ff,$ff,$00,$07
	dc.b	$fa,$ff,$ca,$00,$00,$1f,$ed,$ff,$00,$fc,$c3,$00,$00,$1f,$f0,$ff,$03,$80,$00,$ff,$fc,$ce,$00,$f6,$ff,$00,$e0,$f0,$00,$03,$7f,$ff
	dc.b	$00,$03,$fa,$ff,$ca,$00,$00,$1f,$ed,$ff,$00,$fc,$c3,$00,$00,$1f,$f0,$ff,$03,$80,$00,$ff,$fc,$ce,$00,$f6,$ff,$00,$e0,$f0,$00,$03
	dc.b	$7f,$ff,$00,$03,$fa,$ff,$ca,$00,$00,$3f,$ed,$ff,$00,$fe,$c3,$00,$00,$3f,$f0,$ff,$03,$80,$00,$ff,$fe,$ce,$00,$f6,$ff,$00,$c0,$f0
	dc.b	$00,$03,$7f,$ff,$00,$01,$fa,$ff,$ca,$00,$00,$3f,$fb,$ff,$00,$ef,$f3,$ff,$c3,$00,$00,$3f,$f0,$ff,$03,$80,$00,$ff,$ff,$ce,$00,$f6
	dc.b	$ff,$00,$c0,$fb,$00,$00,$10,$f7,$00,$03,$7f,$ff,$00,$00,$fa,$ff,$ca,$00,$00,$3f,$ec,$ff,$c3,$00,$00,$3f,$f0,$ff,$03,$80,$00,$ff
	dc.b	$ff,$ce,$00,$f6,$ff,$00,$c0,$f0,$00,$03,$7f,$ff,$00,$00,$fa,$ff,$ca,$00,$00,$7f,$ec,$ff,$00,$80,$c4,$00,$00,$7f,$f0,$ff,$04,$80
	dc.b	$00,$ff,$ff,$80,$cf,$00,$f6,$ff,$00,$80,$f0,$00,$04,$7f,$ff,$00,$00,$7f,$fb,$ff,$ca,$00,$00,$7f,$ec,$ff,$00,$c0,$c4,$00,$00,$7f
	dc.b	$f0,$ff,$04,$c0,$00,$ff,$ff,$c0,$cf,$00,$f6,$ff,$00,$80,$f0,$00,$04,$3f,$ff,$00,$00,$3f,$fb,$ff,$ca,$00,$00,$7f,$ec,$ff,$00,$e0
	dc.b	$c4,$00,$00,$7f,$f0,$ff,$04,$c0,$00,$ff,$ff,$e0,$cf,$00,$f6,$ff,$00,$80,$f0,$00,$04,$3f,$ff,$00,$00,$1f,$fb,$ff,$ca,$00,$eb,$ff
	dc.b	$00,$e0,$c4,$00,$ef,$ff,$04,$c0,$00,$ff,$ff,$e0,$cf,$00,$f6,$ff,$ef,$00,$04,$3f,$ff,$00,$00,$1f,$fb,$ff,$ca,$00,$eb,$ff,$00,$f0
	dc.b	$c4,$00,$ef,$ff,$04,$c0,$00,$7f,$ff,$f0,$cf,$00,$f6,$ff,$ef,$00,$04,$3f,$ff,$80,$00,$0f,$fb,$ff,$ca,$00,$eb,$ff,$00,$f8,$c4,$00
	dc.b	$ef,$ff,$04,$c0,$00,$7f,$ff,$f8,$cf,$00,$f6,$ff,$ef,$00,$04,$3f,$ff,$80,$00,$07,$fb,$ff,$cb,$00,$00,$01,$eb,$ff,$00,$f8,$c5,$00
	dc.b	$00,$01,$ef,$ff,$04,$c0,$00,$7f,$ff,$f8,$cf,$00,$f7,$ff,$00,$fe,$ef,$00,$04,$3f,$ff,$80,$00,$07,$fb,$ff,$cb,$00,$00,$01,$eb,$ff
	dc.b	$00,$fc,$c5,$00,$00,$01,$ef,$ff,$04,$c0,$00,$7f,$ff,$fc,$cf,$00,$f7,$ff,$00,$fe,$ef,$00,$04,$3f,$ff,$80,$00,$03,$fb,$ff,$cb,$00
	dc.b	$00,$01,$eb,$ff,$00,$fc,$c5,$00,$00,$01,$ef,$ff,$04,$e0,$00,$7f,$ff,$fc,$cf,$00,$f7,$ff,$00,$fe,$ef,$00,$04,$1f,$ff,$80,$00,$03
	dc.b	$fb,$ff,$cb,$00,$00,$03,$eb,$ff,$00,$f8,$c5,$00,$00,$03,$ef,$ff,$04,$e0,$00,$7f,$ff,$f8,$cf,$00,$f7,$ff,$00,$fc,$ef,$00,$04,$1f
	dc.b	$ff,$80,$00,$07,$fb,$ff,$cb,$00,$00,$03,$eb,$ff,$00,$f8,$c5,$00,$00,$03,$ef,$ff,$04,$e0,$01,$ff,$ff,$f8,$cf,$00,$f7,$ff,$00,$fc
	dc.b	$ef,$00,$04,$1f,$fe,$00,$00,$07,$fb,$ff,$cb,$00,$03,$03,$ff,$ff,$bf,$ee,$ff,$00,$f0,$c5,$00,$00,$03,$ef,$ff,$04,$e0,$03,$ff,$ff
	dc.b	$f0,$cf,$00,$f7,$ff,$03,$fc,$00,$00,$40,$f2,$00,$04,$1f,$fc,$00,$00,$0f,$fb,$ff,$cb,$00,$00,$07,$eb,$ff,$00,$f0,$c5,$00,$00,$07
	dc.b	$ef,$ff,$04,$e0,$0f,$ff,$ff,$f0,$cf,$00,$f7,$ff,$00,$f8,$ef,$00,$04,$1f,$f0,$00,$00,$0f,$fb,$ff,$cb,$00,$00,$07,$eb,$ff,$00,$f0
	dc.b	$c5,$00,$00,$07,$ef,$ff,$04,$e0,$1f,$ff,$ff,$f0,$cf,$00,$f7,$ff,$00,$f8,$ef,$00,$04,$1f,$e0,$00,$00,$0f,$fb,$ff,$cb,$00,$00,$0f
	dc.b	$eb,$ff,$00,$e0,$c5,$00,$00,$0f,$ef,$ff,$04,$f0,$7f,$ff,$ff,$e0,$cf,$00,$f7,$ff,$00,$f0,$ef,$00,$04,$0f,$80,$00,$00,$1f,$fb,$ff
	dc.b	$cb,$00,$00,$0f,$fc,$ff,$00,$df,$f1,$ff,$00,$e0,$c5,$00,$00,$0f,$ef,$ff,$00,$f0,$fe,$ff,$00,$e0,$cf,$00,$f7,$ff,$00,$f0,$fc,$00
	dc.b	$00,$20,$f5,$00,$00,$0f,$fe,$00,$00,$1f,$fb,$ff,$cb,$00,$00,$1f,$eb,$ff,$00,$c0,$c5,$00,$00,$1f,$ef,$ff,$00,$f3,$fe,$ff,$00,$c0
	dc.b	$cf,$00,$f7,$ff,$00,$e0,$ef,$00,$00,$0c,$fe,$00,$00,$3f,$fb,$ff,$cb,$00,$00,$1f,$eb,$ff,$00,$c0,$c5,$00,$00,$1f,$ef,$ff,$00,$f7
	dc.b	$fe,$ff,$00,$c0,$cf,$00,$f7,$ff,$00,$e0,$ef,$00,$00,$08,$fe,$00,$00,$3f,$fb,$ff,$cb,$00,$00,$3f,$fa,$ff,$00,$f7,$f3,$ff,$00,$c0
	dc.b	$c5,$00,$00,$3f,$eb,$ff,$00,$c0,$cf,$00,$f7,$ff,$00,$c0,$fa,$00,$00,$08,$f3,$00,$00,$3f,$fb,$ff,$cb,$00,$00,$7f,$eb,$ff,$00,$80
	dc.b	$c5,$00,$00,$7f,$eb,$ff,$00,$80,$cf,$00,$f7,$ff,$00,$80,$eb,$00,$00,$7f,$fb,$ff,$cb,$00,$00,$7f,$eb,$ff,$00,$80,$c5,$00,$00,$7f
	dc.b	$eb,$ff,$00,$80,$cf,$00,$f7,$ff,$00,$80,$eb,$00,$00,$7f,$fb,$ff,$cb,$00,$fe,$ff,$00,$bf,$ee,$ff,$c4,$00,$ea,$ff,$ce,$00,$f7,$ff
	dc.b	$fe,$00,$00,$40,$ee,$00,$fa,$ff,$cb,$00,$ea,$ff,$c4,$00,$ea,$ff,$ce,$00,$f7,$ff,$ea,$00,$fa,$ff,$cc,$00,$00,$01,$ea,$ff,$c5,$00
	dc.b	$00,$01,$ea,$ff,$ce,$00,$f8,$ff,$00,$fe,$ea,$00,$fa,$ff,$cc,$00,$00,$01,$eb,$ff,$00,$fe,$c5,$00,$00,$01,$eb,$ff,$00,$fe,$ce,$00
	dc.b	$f8,$ff,$00,$fe,$eb,$00,$00,$01,$fa,$ff,$cc,$00,$00,$03,$fc,$ff,$00,$ef,$f1,$ff,$00,$fe,$c5,$00,$00,$03,$eb,$ff,$00,$fe,$ce,$00
	dc.b	$f8,$ff,$00,$fc,$fc,$00,$00,$10,$f1,$00,$00,$01,$fa,$ff,$cc,$00,$00,$07,$eb,$ff,$00,$fc,$c5,$00,$00,$07,$eb,$ff,$00,$fc,$ce,$00
	dc.b	$f8,$ff,$00,$f8,$eb,$00,$00,$03,$fa,$ff,$cc,$00,$00,$07,$eb,$ff,$00,$fc,$c5,$00,$00,$07,$eb,$ff,$00,$fc,$ce,$00,$f8,$ff,$00,$f8
	dc.b	$eb,$00,$00,$03,$fa,$ff,$cc,$00,$00,$0f,$fd,$ff,$00,$7f,$f0,$ff,$00,$fc,$c5,$00,$00,$0f,$eb,$ff,$00,$fc,$ce,$00,$f8,$ff,$00,$f0
	dc.b	$fd,$00,$00,$80,$f0,$00,$00,$03,$fa,$ff,$cc,$00,$00,$0f,$eb,$ff,$00,$fe,$c5,$00,$00,$0f,$eb,$ff,$00,$fe,$ce,$00,$f8,$ff,$00,$f0
	dc.b	$eb,$00,$00,$01,$fa,$ff,$cc,$00,$00,$1f,$eb,$ff,$00,$fe,$c5,$00,$00,$1f,$eb,$ff,$00,$fe,$ce,$00,$f8,$ff,$00,$e0,$eb,$00,$00,$01
	dc.b	$fa,$ff,$cc,$00,$00,$3f,$ea,$ff,$c5,$00,$00,$3f,$ea,$ff,$ce,$00,$f8,$ff,$00,$c0,$ea,$00,$fa,$ff,$cc,$00,$00,$3f,$ea,$ff,$c5,$00
	dc.b	$00,$3f,$ea,$ff,$ce,$00,$f8,$ff,$00,$c0,$ea,$00,$fa,$ff,$cc,$00,$00,$7f,$ea,$ff,$00,$80,$c6,$00,$00,$7f,$ea,$ff,$00,$80,$cf,$00
	dc.b	$f8,$ff,$00,$80,$ea,$00,$00,$7f,$fb,$ff,$cc,$00,$00,$7f,$ea,$ff,$00,$80,$c6,$00,$00,$7f,$ea,$ff,$00,$80,$cf,$00,$f8,$ff,$00,$80
	dc.b	$ea,$00,$00,$7f,$fb,$ff,$cc,$00,$e9,$ff,$00,$c0,$c6,$00,$e9,$ff,$00,$c0,$cf,$00,$f8,$ff,$e9,$00,$00,$3f,$fb,$ff,$cc,$00,$e9,$ff
	dc.b	$00,$c0,$c6,$00,$e9,$ff,$00,$c0,$cf,$00,$f8,$ff,$e9,$00,$00,$3f,$fb,$ff,$cd,$00,$00,$01,$e9,$ff,$00,$e0,$c7,$00,$00,$01,$e9,$ff
	dc.b	$00,$e0,$cf,$00,$f9,$ff,$00,$fe,$e9,$00,$00,$1f,$fb,$ff,$cd,$00,$00,$01,$fc,$ff,$00,$f7,$ef,$ff,$00,$e0,$c7,$00,$00,$01,$e9,$ff
	dc.b	$00,$e0,$cf,$00,$f9,$ff,$00,$fe,$fc,$00,$00,$08,$ef,$00,$00,$1f,$fb,$ff,$cd,$00,$00,$03,$e9,$ff,$00,$f0,$c7,$00,$00,$03,$e9,$ff
	dc.b	$00,$f0,$cf,$00,$f9,$ff,$00,$fc,$e9,$00,$00,$0f,$fb,$ff,$cd,$00,$00,$03,$e9,$ff,$00,$f0,$c7,$00,$00,$03,$e9,$ff,$00,$f0,$cf,$00
	dc.b	$f9,$ff,$00,$fc,$e9,$00,$00,$0f,$fb,$ff,$cd,$00,$00,$03,$e9,$ff,$00,$f8,$c7,$00,$00,$03,$e9,$ff,$00,$f8,$cf,$00,$f9,$ff,$00,$fc
	dc.b	$e9,$00,$00,$07,$fb,$ff,$cd,$00,$00,$03,$e9,$ff,$00,$f8,$c7,$00,$00,$03,$e9,$ff,$00,$f8,$cf,$00,$f9,$ff,$00,$fc,$e9,$00,$00,$07
	dc.b	$fb,$ff,$cd,$00,$00,$07,$e9,$ff,$00,$f8,$c7,$00,$00,$07,$e9,$ff,$00,$f8,$cf,$00,$f9,$ff,$00,$f8,$e9,$00,$00,$07,$fb,$ff,$cd,$00
	dc.b	$00,$07,$e9,$ff,$00,$fc,$c7,$00,$00,$07,$e9,$ff,$00,$fc,$cf,$00,$f9,$ff,$00,$f8,$e9,$00,$00,$03,$fb,$ff,$cd,$00,$00,$07,$e9,$ff
	dc.b	$00,$fc,$c7,$00,$00,$07,$e9,$ff,$00,$fc,$cf,$00,$f9,$ff,$00,$f8,$e9,$00,$00,$03,$fb,$ff,$cd,$00,$03,$07,$ff,$ff,$fd,$ec,$ff,$00
	dc.b	$fe,$c7,$00,$00,$07,$e9,$ff,$00,$fe,$cf,$00,$f9,$ff,$03,$f8,$00,$00,$02,$ec,$00,$00,$01,$fb,$ff,$cd,$00,$00,$0f,$e9,$ff,$00,$fe
	dc.b	$c7,$00,$00,$0f,$e9,$ff,$00,$fe,$cf,$00,$f9,$ff,$00,$f0,$e9,$00,$00,$01,$fb,$ff,$cd,$00,$00,$0f,$e8,$ff,$c7,$00,$00,$0f,$e8,$ff
	dc.b	$cf,$00,$f9,$ff,$00,$f0,$e8,$00,$fb,$ff,$cd,$00,$00,$0f,$e8,$ff,$c7,$00,$00,$0f,$e8,$ff,$cf,$00,$f9,$ff,$00,$f0,$e8,$00,$fb,$ff
	dc.b	$cd,$00,$00,$0f,$e8,$ff,$00,$80,$c8,$00,$00,$0f,$e8,$ff,$00,$80,$d0,$00,$f9,$ff,$00,$f0,$e8,$00,$00,$7f,$fc,$ff,$cd,$00,$00,$1f
	dc.b	$e8,$ff,$00,$80,$c8,$00,$00,$1f,$e8,$ff,$00,$80,$d0,$00,$f9,$ff,$00,$e0,$e8,$00,$00,$7f,$fc,$ff,$cd,$00,$00,$1f,$e8,$ff,$00,$c0
	dc.b	$c8,$00,$00,$1f,$e8,$ff,$00,$c0,$d0,$00,$f9,$ff,$00,$e0,$e8,$00,$00,$3f,$fc,$ff,$cd,$00,$00,$1f,$e8,$ff,$00,$c0,$c8,$00,$00,$1f
	dc.b	$e8,$ff,$00,$c0,$d0,$00,$f9,$ff,$00,$e0,$e8,$00,$00,$3f,$fc,$ff,$cd,$00,$00,$1f,$e8,$ff,$00,$e0,$c8,$00,$00,$1f,$e8,$ff,$00,$e0
	dc.b	$d0,$00,$f9,$ff,$00,$e0,$e8,$00,$00,$1f,$fc,$ff,$cd,$00,$00,$3f,$e8,$ff,$00,$e0,$c8,$00,$00,$3f,$e8,$ff,$00,$e0,$d0,$00,$f9,$ff
	dc.b	$00,$c0,$e8,$00,$00,$1f,$fc,$ff,$cd,$00,$00,$3f,$e8,$ff,$00,$f0,$c8,$00,$00,$3f,$e8,$ff,$00,$f0,$d0,$00,$f9,$ff,$00,$c0,$e8,$00
	dc.b	$00,$0f,$fc,$ff,$cd,$00,$00,$3f,$fa,$ff,$00,$fe,$f0,$ff,$00,$f0,$c8,$00,$00,$3f,$e8,$ff,$00,$f0,$d0,$00,$f9,$ff,$00,$c0,$fa,$00
	dc.b	$00,$01,$f0,$00,$00,$0f,$fc,$ff,$cd,$00,$00,$3f,$e8,$ff,$00,$f0,$c8,$00,$00,$3f,$e8,$ff,$00,$f0,$d0,$00,$f9,$ff,$00,$c0,$e8,$00
	dc.b	$00,$0f,$fc,$ff,$cd,$00,$00,$7f,$e8,$ff,$00,$e0,$c8,$00,$00,$7f,$e8,$ff,$00,$e0,$d0,$00,$f9,$ff,$00,$80,$e8,$00,$00,$1f,$fc,$ff
	dc.b	$cd,$00,$00,$7f,$e8,$ff,$00,$e0,$c8,$00,$00,$7f,$e8,$ff,$00,$e0,$d0,$00,$f9,$ff,$00,$80,$e8,$00,$00,$1f,$fc,$ff,$cd,$00,$00,$7f
	dc.b	$e8,$ff,$00,$c0,$c8,$00,$00,$7f,$e8,$ff,$00,$c0,$d0,$00,$f9,$ff,$00,$80,$e8,$00,$00,$3f,$fc,$ff,$cd,$00,$00,$7f,$e8,$ff,$00,$c0
	dc.b	$c8,$00,$00,$7f,$e8,$ff,$00,$c0,$d0,$00,$f9,$ff,$00,$80,$e8,$00,$00,$3f,$fc,$ff,$cd,$00,$e7,$ff,$00,$80,$c8,$00,$e7,$ff,$00,$80
	dc.b	$d0,$00,$f9,$ff,$e7,$00,$00,$7f,$fc,$ff,$cd,$00,$f9,$ff,$00,$df,$f0,$ff,$00,$80,$c8,$00,$e7,$ff,$00,$80,$d0,$00,$f9,$ff,$f9,$00
	dc.b	$00,$20,$f0,$00,$00,$7f,$fc,$ff,$cd,$00,$ef,$ff,$00,$ef,$fa,$ff,$c7,$00,$e7,$ff,$cf,$00,$f9,$ff,$ef,$00,$00,$10,$fa,$00,$fb,$ff
	dc.b	$cd,$00,$e7,$ff,$c7,$00,$e7,$ff,$cf,$00,$f9,$ff,$e7,$00,$fb,$ff,$ce,$00,$00,$01,$e8,$ff,$00,$fe,$c8,$00,$00,$01,$e8,$ff,$00,$fe
	dc.b	$cf,$00,$fa,$ff,$00,$fe,$e8,$00,$00,$01,$fb,$ff,$ce,$00,$00,$01,$e8,$ff,$00,$fe,$c8,$00,$00,$01,$e8,$ff,$00,$fe,$cf,$00,$fa,$ff
	dc.b	$00,$fe,$e8,$00,$00,$01,$fb,$ff,$ce,$00,$00,$01,$e8,$ff,$00,$fc,$c8,$00,$00,$01,$e8,$ff,$00,$fc,$cf,$00,$fa,$ff,$00,$fe,$e8,$00
	dc.b	$00,$03,$fb,$ff,$ce,$00,$00,$01,$e8,$ff,$00,$fc,$c8,$00,$00,$01,$e8,$ff,$00,$fc,$cf,$00,$fa,$ff,$00,$fe,$e8,$00,$00,$03,$fb,$ff
	dc.b	$ce,$00,$00,$03,$e8,$ff,$00,$f8,$c8,$00,$00,$03,$e8,$ff,$00,$f8,$cf,$00,$fa,$ff,$00,$fc,$e8,$00,$00,$07,$fb,$ff,$ce,$00,$00,$03
	dc.b	$f7,$ff,$00,$fd,$f3,$ff,$00,$f8,$c8,$00,$00,$03,$e8,$ff,$00,$f8,$cf,$00,$fa,$ff,$00,$fc,$f7,$00,$00,$02,$f3,$00,$00,$07,$fb,$ff
	dc.b	$ce,$00,$00,$03,$e8,$ff,$00,$f8,$c8,$00,$00,$03,$e8,$ff,$00,$f8,$cf,$00,$fa,$ff,$00,$fc,$e8,$00,$00,$07,$fb,$ff,$ce,$00,$00,$03
	dc.b	$e8,$ff,$00,$f0,$c8,$00,$00,$03,$e8,$ff,$00,$f0,$cf,$00,$fa,$ff,$00,$fc,$e8,$00,$00,$0f,$fb,$ff,$ce,$00,$00,$07,$f0,$ff,$00,$bf
	dc.b	$fa,$ff,$00,$f0,$c8,$00,$00,$07,$e8,$ff,$00,$f0,$cf,$00,$fa,$ff,$00,$f8,$f0,$00,$00,$40,$fa,$00,$00,$0f,$fb,$ff,$ce,$00,$00,$07
	dc.b	$e8,$ff,$00,$e0,$c8,$00,$00,$07,$e8,$ff,$00,$e0,$cf,$00,$fa,$ff,$00,$f8,$e8,$00,$00,$1f,$fb,$ff,$ce,$00,$00,$07,$e8,$ff,$00,$e0
	dc.b	$c8,$00,$00,$07,$e8,$ff,$00,$e0,$cf,$00,$fa,$ff,$00,$f8,$e8,$00,$00,$1f,$fb,$ff,$ce,$00,$00,$0f,$e8,$ff,$00,$c0,$c8,$00,$00,$0f
	dc.b	$e8,$ff,$00,$c0,$cf,$00,$fa,$ff,$00,$f0,$e8,$00,$00,$3f,$fb,$ff,$ce,$00,$00,$0f,$e8,$ff,$00,$c0,$c8,$00,$00,$0f,$e8,$ff,$00,$c0
	dc.b	$cf,$00,$fa,$ff,$00,$f0,$e8,$00,$00,$3f,$fb,$ff,$ce,$00,$00,$1f,$e8,$ff,$00,$80,$c8,$00,$00,$1f,$e8,$ff,$00,$80,$cf,$00,$fa,$ff
	dc.b	$00,$e0,$e8,$00,$00,$7f,$fb,$ff,$ce,$00,$00,$1f,$e8,$ff,$00,$80,$c8,$00,$00,$1f,$e8,$ff,$00,$80,$cf,$00,$fa,$ff,$00,$e0,$e8,$00
	dc.b	$00,$7f,$fb,$ff,$ce,$00,$00,$3f,$e8,$ff,$c7,$00,$00,$3f,$e8,$ff,$ce,$00,$fa,$ff,$00,$c0,$e8,$00,$fa,$ff,$ce,$00,$00,$3f,$e8,$ff
	dc.b	$c7,$00,$00,$3f,$e8,$ff,$ce,$00,$fa,$ff,$00,$c0,$e8,$00,$fa,$ff,$ce,$00,$00,$7f,$ef,$ff,$00,$fb,$fc,$ff,$00,$fe,$c7,$00,$00,$7f
	dc.b	$e9,$ff,$00,$fe,$ce,$00,$fa,$ff,$00,$80,$ef,$00,$00,$04,$fc,$00,$00,$01,$fa,$ff,$ce,$00,$00,$7f,$e9,$ff,$00,$fe,$c7,$00,$00,$7f
	dc.b	$e9,$ff,$00,$fe,$ce,$00,$fa,$ff,$00,$80,$e9,$00,$00,$01,$fa,$ff,$ce,$00,$fd,$ff,$00,$fe,$ed,$ff,$00,$fc,$c7,$00,$e8,$ff,$00,$fc
	dc.b	$ce,$00,$fa,$ff,$fd,$00,$00,$01,$ed,$00,$00,$03,$fa,$ff,$ce,$00,$e8,$ff,$00,$fc,$c7,$00,$e8,$ff,$00,$fc,$ce,$00,$fa,$ff,$e8,$00
	dc.b	$00,$03,$fa,$ff,$cf,$00,$00,$01,$e8,$ff,$00,$fc,$c8,$00,$00,$01,$e8,$ff,$00,$fc,$ce,$00,$fb,$ff,$00,$fe,$e8,$00,$00,$03,$fa,$ff
	dc.b	$cf,$00,$00,$01,$e8,$ff,$00,$fe,$c8,$00,$00,$01,$e8,$ff,$00,$fe,$ce,$00,$fb,$ff,$00,$fe,$e8,$00,$00,$01,$fa,$ff,$cf,$00,$00,$03
	dc.b	$f3,$ff,$00,$fe,$fb,$ff,$00,$bf,$fe,$ff,$00,$fe,$c8,$00,$00,$03,$e8,$ff,$00,$fe,$ce,$00,$fb,$ff,$00,$fc,$f3,$00,$00,$01,$fb,$00
	dc.b	$00,$40,$fe,$00,$00,$01,$fa,$ff,$cf,$00,$00,$03,$e8,$ff,$00,$fe,$c8,$00,$00,$03,$e8,$ff,$00,$fe,$ce,$00,$fb,$ff,$00,$fc,$e8,$00
	dc.b	$00,$01,$fa,$ff,$cf,$00,$03,$07,$ff,$ff,$fd,$eb,$ff,$00,$fe,$c8,$00,$00,$07,$e8,$ff,$00,$fe,$ce,$00,$fb,$ff,$03,$f8,$00,$00,$02
	dc.b	$eb,$00,$00,$01,$fa,$ff,$cf,$00,$00,$07,$e7,$ff,$c8,$00,$00,$07,$e7,$ff,$ce,$00,$fb,$ff,$00,$f8,$e7,$00,$fa,$ff,$cf,$00,$00,$0f
	dc.b	$e7,$ff,$c8,$00,$00,$0f,$e7,$ff,$ce,$00,$fb,$ff,$00,$f0,$e7,$00,$fa,$ff,$cf,$00,$00,$0f,$e7,$ff,$c8,$00,$00,$0f,$e7,$ff,$ce,$00
	dc.b	$fb,$ff,$00,$f0,$e7,$00,$fa,$ff,$cf,$00,$00,$1f,$fb,$ff,$00,$df,$ee,$ff,$c8,$00,$00,$1f,$e7,$ff,$ce,$00,$fb,$ff,$00,$e0,$fb,$00
	dc.b	$00,$20,$ee,$00,$fa,$ff,$cf,$00,$00,$1f,$fd,$ff,$00,$7f,$f5,$ff,$00,$df,$f9,$ff,$00,$80,$c9,$00,$00,$1f,$e7,$ff,$00,$80,$cf,$00
	dc.b	$fb,$ff,$00,$e0,$fd,$00,$00,$80,$f5,$00,$00,$20,$f9,$00,$00,$7f,$fb,$ff,$cf,$00,$00,$3f,$e7,$ff,$00,$80,$c9,$00,$00,$3f,$e7,$ff
	dc.b	$00,$80,$cf,$00,$fb,$ff,$00,$c0,$e7,$00,$00,$7f,$fb,$ff,$cf,$00,$00,$3f,$e7,$ff,$00,$80,$c9,$00,$00,$3f,$e7,$ff,$00,$80,$cf,$00
	dc.b	$fb,$ff,$00,$c0,$e7,$00,$00,$7f,$fb,$ff,$cf,$00,$00,$7f,$e7,$ff,$00,$80,$c9,$00,$00,$7f,$e7,$ff,$00,$80,$cf,$00,$fb,$ff,$00,$80
	dc.b	$e7,$00,$00,$7f,$fb,$ff,$cf,$00,$02,$7f,$ff,$ef,$e9,$ff,$00,$c0,$c9,$00,$00,$7f,$e7,$ff,$00,$c0,$cf,$00,$fb,$ff,$02,$80,$00,$10
	dc.b	$e9,$00,$00,$3f,$fb,$ff,$cf,$00,$e6,$ff,$00,$c0,$c9,$00,$e6,$ff,$00,$c0,$cf,$00,$fb,$ff,$e6,$00,$00,$3f,$fb,$ff,$cf,$00,$e6,$ff
	dc.b	$00,$c0,$c9,$00,$e6,$ff,$00,$c0,$cf,$00,$fb,$ff,$e6,$00,$00,$3f,$fb,$ff,$d0,$00,$00,$01,$e6,$ff,$00,$e0,$ca,$00,$00,$01,$e6,$ff
	dc.b	$00,$e0,$cf,$00,$fc,$ff,$00,$fe,$e6,$00,$00,$1f,$fb,$ff,$d0,$00,$00,$01,$e6,$ff,$00,$e0,$ca,$00,$00,$01,$e6,$ff,$00,$e0,$cf,$00
	dc.b	$fc,$ff,$00,$fe,$e6,$00,$00,$1f,$fb,$ff,$d0,$00,$00,$03,$e6,$ff,$00,$e0,$ca,$00,$00,$03,$e6,$ff,$00,$e0,$cf,$00,$fc,$ff,$00,$fc
	dc.b	$e6,$00,$00,$1f,$fb,$ff,$d0,$00,$00,$03,$e6,$ff,$00,$e0,$ca,$00,$00,$03,$e6,$ff,$00,$e0,$cf,$00,$fc,$ff,$00,$fc,$e6,$00,$00,$1f
	dc.b	$fb,$ff,$d0,$00,$00,$07,$e6,$ff,$00,$f0,$ca,$00,$00,$07,$e6,$ff,$00,$f0,$cf,$00,$fc,$ff,$00,$f8,$e6,$00,$00,$0f,$fb,$ff,$d0,$00
	dc.b	$00,$07,$eb,$ff,$00,$df,$fd,$ff,$00,$f0,$ca,$00,$00,$07,$e6,$ff,$00,$f0,$cf,$00,$fc,$ff,$00,$f8,$eb,$00,$00,$20,$fd,$00,$00,$0f
	dc.b	$fb,$ff,$d0,$00,$00,$0f,$e6,$ff,$00,$f0,$ca,$00,$00,$0f,$e6,$ff,$00,$f0,$cf,$00,$fc,$ff,$00,$f0,$e6,$00,$00,$0f,$fb,$ff,$d0,$00
	dc.b	$00,$0f,$f1,$ff,$00,$f7,$f7,$ff,$00,$f0,$ca,$00,$00,$0f,$e6,$ff,$00,$f0,$cf,$00,$fc,$ff,$00,$f0,$f1,$00,$00,$08,$f7,$00,$00,$0f
	dc.b	$fb,$ff,$d0,$00,$00,$1f,$ef,$ff,$00,$7f,$f9,$ff,$00,$f8,$ca,$00,$00,$1f,$e6,$ff,$00,$f8,$cf,$00,$fc,$ff,$00,$e0,$ef,$00,$00,$80
	dc.b	$f9,$00,$00,$07,$fb,$ff,$d0,$00,$00,$1f,$e6,$ff,$00,$f8,$ca,$00,$00,$1f,$e6,$ff,$00,$f8,$cf,$00,$fc,$ff,$00,$e0,$e6,$00,$00,$07
	dc.b	$fb,$ff,$d0,$00,$00,$3f,$ef,$ff,$00,$7f,$fb,$ff,$02,$f7,$ff,$f8,$ca,$00,$00,$3f,$e6,$ff,$00,$f8,$cf,$00,$fc,$ff,$00,$c0,$ef,$00
	dc.b	$00,$80,$fb,$00,$02,$08,$00,$07,$fb,$ff,$d0,$00,$00,$3f,$e6,$ff,$00,$f8,$ca,$00,$00,$3f,$e6,$ff,$00,$f8,$cf,$00,$fc,$ff,$00,$c0
	dc.b	$e6,$00,$00,$07,$fb,$ff,$d0,$00,$00,$7f,$e6,$ff,$00,$fc,$ca,$00,$00,$7f,$e6,$ff,$00,$fc,$cf,$00,$fc,$ff,$00,$80,$e6,$00,$00,$03
	dc.b	$fb,$ff,$d0,$00,$00,$7f,$e6,$ff,$00,$fc,$ca,$00,$00,$7f,$e6,$ff,$00,$fc,$cf,$00,$fc,$ff,$00,$80,$e6,$00,$00,$03,$fb,$ff,$d0,$00
	dc.b	$00,$7f,$f3,$ff,$00,$fb,$f5,$ff,$00,$fc,$ca,$00,$00,$7f,$e6,$ff,$00,$fc,$cf,$00,$fc,$ff,$00,$80,$f3,$00,$00,$04,$f5,$00,$00,$03
	dc.b	$fb,$ff,$d0,$00,$e5,$ff,$00,$fe,$ca,$00,$e5,$ff,$00,$fe,$cf,$00,$fc,$ff,$e5,$00,$00,$01,$fb,$ff,$d0,$00,$e5,$ff,$00,$fe,$ca,$00
	dc.b	$e5,$ff,$00,$fe,$cf,$00,$fc,$ff,$e5,$00,$00,$01,$fb,$ff,$d1,$00,$00,$01,$e4,$ff,$cb,$00,$00,$01,$e4,$ff,$cf,$00,$fd,$ff,$00,$fe
	dc.b	$e4,$00,$fb,$ff,$d1,$00,$00,$01,$e6,$ff,$01,$df,$ff,$cb,$00,$00,$01,$e4,$ff,$cf,$00,$fd,$ff,$00,$fe,$e6,$00,$01,$20,$00,$fb,$ff
	dc.b	$d1,$00,$00,$03,$e4,$ff,$00,$80,$cc,$00,$00,$03,$e4,$ff,$00,$80,$d0,$00,$fd,$ff,$00,$fc,$e4,$00,$00,$7f,$fc,$ff,$d1,$00,$00,$03
	dc.b	$e4,$ff,$00,$80,$cc,$00,$00,$03,$e4,$ff,$00,$80,$d0,$00,$fd,$ff,$00,$fc,$e4,$00,$00,$7f,$fc,$ff,$d1,$00,$00,$03,$fa,$ff,$00,$df
	dc.b	$ec,$ff,$00,$80,$cc,$00,$00,$03,$e4,$ff,$00,$80,$d0,$00,$fd,$ff,$00,$fc,$fa,$00,$00,$20,$ec,$00,$00,$7f,$fc,$ff,$d1,$00,$00,$07
	dc.b	$e4,$ff,$00,$c0,$cc,$00,$00,$07,$e4,$ff,$00,$c0,$d0,$00,$fd,$ff,$00,$f8,$e4,$00,$00,$3f,$fc,$ff,$d1,$00,$00,$07,$e4,$ff,$00,$c0
	dc.b	$cc,$00,$00,$07,$e4,$ff,$00,$c0,$d0,$00,$fd,$ff,$00,$f8,$e4,$00,$00,$3f,$fc,$ff,$d1,$00,$00,$0f,$e4,$ff,$00,$e0,$cc,$00,$00,$0f
	dc.b	$e4,$ff,$00,$e0,$d0,$00,$fd,$ff,$00,$f0,$e4,$00,$00,$1f,$fc,$ff,$d1,$00,$00,$0f,$f9,$ff,$00,$fe,$ed,$ff,$00,$e0,$cc,$00,$00,$0f
	dc.b	$e4,$ff,$00,$e0,$d0,$00,$fd,$ff,$00,$f0,$f9,$00,$00,$01,$ed,$00,$00,$1f,$fc,$ff,$d1,$00,$00,$0f,$f0,$ff,$00,$ef,$f6,$ff,$00,$e0
	dc.b	$cc,$00,$00,$0f,$e4,$ff,$00,$e0,$d0,$00,$fd,$ff,$00,$f0,$f0,$00,$00,$10,$f6,$00,$00,$1f,$fc,$ff,$d1,$00,$00,$1f,$e4,$ff,$00,$f0
	dc.b	$cc,$00,$00,$1f,$e4,$ff,$00,$f0,$d0,$00,$fd,$ff,$00,$e0,$e4,$00,$00,$0f,$fc,$ff,$d1,$00,$00,$1f,$f7,$ff,$00,$fd,$f0,$ff,$01,$fb
	dc.b	$f0,$cc,$00,$00,$1f,$e4,$ff,$00,$f0,$d0,$00,$fd,$ff,$00,$e0,$f7,$00,$00,$02,$f0,$00,$01,$04,$0f,$fc,$ff,$d1,$00,$00,$3f,$e4,$ff
	dc.b	$00,$f8,$cc,$00,$00,$3f,$e4,$ff,$00,$f8,$d0,$00,$fd,$ff,$00,$c0,$e4,$00,$00,$07,$fc,$ff,$d1,$00,$00,$3f,$e4,$ff,$00,$f8,$cc,$00
	dc.b	$00,$3f,$e4,$ff,$00,$f8,$d0,$00,$fd,$ff,$00,$c0,$e4,$00,$00,$07,$fc,$ff,$d1,$00,$00,$7f,$ee,$ff,$00,$fd,$f8,$ff,$00,$fc,$cc,$00
	dc.b	$00,$7f,$e4,$ff,$00,$fc,$d0,$00,$fd,$ff,$00,$80,$ee,$00,$00,$02,$f8,$00,$00,$03,$fc,$ff,$d1,$00,$00,$7f,$f6,$ff,$00,$ef,$f0,$ff
	dc.b	$00,$fc,$cc,$00,$00,$7f,$e4,$ff,$00,$fc,$d0,$00,$fd,$ff,$00,$80,$f6,$00,$00,$10,$f0,$00,$00,$03,$fc,$ff,$d1,$00,$00,$7f,$ee,$ff
	dc.b	$00,$fe,$f8,$ff,$00,$fc,$cc,$00,$00,$7f,$e4,$ff,$00,$fc,$d0,$00,$fd,$ff,$00,$80,$ee,$00,$00,$01,$f8,$00,$00,$03,$fc,$ff,$d1,$00
	dc.b	$e3,$ff,$00,$fe,$cc,$00,$e3,$ff,$00,$fe,$d0,$00,$fd,$ff,$e3,$00,$00,$01,$fc,$ff,$d1,$00,$e3,$ff,$00,$fe,$cc,$00,$e3,$ff,$00,$fe
	dc.b	$d0,$00,$fd,$ff,$e3,$00,$00,$01,$fc,$ff,$d2,$00,$00,$01,$e2,$ff,$cd,$00,$00,$01,$e2,$ff,$d0,$00,$fe,$ff,$00,$fe,$e2,$00,$fc,$ff
	dc.b	$d2,$00,$00,$01,$e2,$ff,$cd,$00,$00,$01,$e2,$ff,$d0,$00,$fe,$ff,$00,$fe,$e2,$00,$fc,$ff,$d2,$00,$00,$01,$e2,$ff,$cd,$00,$00,$01
	dc.b	$e2,$ff,$d0,$00,$fe,$ff,$00,$fe,$e2,$00,$fc,$ff,$d2,$00,$00,$03,$e2,$ff,$00,$80,$ce,$00,$00,$03,$e2,$ff,$00,$80,$d1,$00,$fe,$ff
	dc.b	$00,$fc,$e2,$00,$00,$7f,$fd,$ff,$d2,$00,$00,$03,$e2,$ff,$00,$80,$ce,$00,$00,$03,$e2,$ff,$00,$80,$d1,$00,$fe,$ff,$00,$fc,$e2,$00
	dc.b	$00,$7f,$fd,$ff,$d2,$00,$00,$07,$e2,$ff,$00,$c0,$ce,$00,$00,$07,$e2,$ff,$00,$c0,$d1,$00,$fe,$ff,$00,$f8,$e2,$00,$00,$3f,$fd,$ff
	dc.b	$d2,$00,$00,$07,$e2,$ff,$00,$c0,$ce,$00,$00,$07,$e2,$ff,$00,$c0,$d1,$00,$fe,$ff,$00,$f8,$e2,$00,$00,$3f,$fd,$ff,$d2,$00,$00,$0f
	dc.b	$f9,$ff,$00,$f7,$eb,$ff,$00,$e0,$ce,$00,$00,$0f,$e2,$ff,$00,$e0,$d1,$00,$fe,$ff,$00,$f0,$f9,$00,$00,$08,$eb,$00,$00,$1f,$fd,$ff
	dc.b	$d2,$00,$00,$0f,$e2,$ff,$00,$e0,$ce,$00,$00,$0f,$e2,$ff,$00,$e0,$d1,$00,$fe,$ff,$00,$f0,$e2,$00,$00,$1f,$fd,$ff,$d2,$00,$00,$0f
	dc.b	$e2,$ff,$00,$e0,$ce,$00,$00,$0f,$e2,$ff,$00,$e0,$d1,$00,$fe,$ff,$00,$f0,$e2,$00,$00,$1f,$fd,$ff,$d2,$00,$02,$1f,$ff,$f7,$e4,$ff
	dc.b	$00,$f0,$ce,$00,$00,$1f,$e2,$ff,$00,$f0,$d1,$00,$fe,$ff,$02,$e0,$00,$08,$e4,$00,$00,$0f,$fd,$ff,$d2,$00,$00,$1f,$fa,$ff,$00,$f7
	dc.b	$ea,$ff,$00,$f0,$ce,$00,$00,$1f,$e2,$ff,$00,$f0,$d1,$00,$fe,$ff,$00,$e0,$fa,$00,$00,$08,$ea,$00,$00,$0f,$fd,$ff,$d2,$00,$00,$3f
	dc.b	$f4,$ff,$00,$ef,$f0,$ff,$00,$f8,$ce,$00,$00,$3f,$e2,$ff,$00,$f8,$d1,$00,$fe,$ff,$00,$c0,$f4,$00,$00,$10,$f0,$00,$00,$07,$fd,$ff
	dc.b	$d2,$00,$00,$3f,$e2,$ff,$00,$f8,$ce,$00,$00,$3f,$e2,$ff,$00,$f8,$d1,$00,$fe,$ff,$00,$c0,$e2,$00,$00,$07,$fd,$ff,$d2,$00,$00,$3f
	dc.b	$e2,$ff,$00,$f8,$ce,$00,$00,$3f,$e2,$ff,$00,$f8,$d1,$00,$fe,$ff,$00,$c0,$e2,$00,$00,$07,$fd,$ff,$d2,$00,$00,$7f,$e2,$ff,$00,$fc
	dc.b	$ce,$00,$00,$7f,$e2,$ff,$00,$fc,$d1,$00,$fe,$ff,$00,$80,$e2,$00,$00,$03,$fd,$ff,$d2,$00,$00,$7f,$e2,$ff,$00,$fc,$ce,$00,$00,$7f
	dc.b	$e2,$ff,$00,$fc,$d1,$00,$fe,$ff,$00,$80,$e2,$00,$00,$03,$fd,$ff,$d2,$00,$e1,$ff,$00,$fe,$ce,$00,$e1,$ff,$00,$fe,$d1,$00,$fe,$ff
	dc.b	$e1,$00,$00,$01,$fd,$ff,$d2,$00,$e1,$ff,$00,$fe,$ce,$00,$e1,$ff,$00,$fe,$d1,$00,$fe,$ff,$e1,$00,$00,$01,$fd,$ff,$d3,$00,$00,$01
	dc.b	$e0,$ff,$cf,$00,$00,$01,$e0,$ff,$d1,$00,$02,$ff,$ff,$fe,$e0,$00,$fd,$ff,$d3,$00,$00,$01,$fc,$ff,$00,$fe,$f8,$ff,$00,$fe,$f0,$ff
	dc.b	$cf,$00,$00,$01,$e0,$ff,$d1,$00,$02,$ff,$ff,$fe,$fc,$00,$00,$01,$f8,$00,$00,$01,$f0,$00,$fd,$ff,$d3,$00,$00,$01,$e0,$ff,$cf,$00
	dc.b	$00,$01,$e0,$ff,$d1,$00,$02,$ff,$ff,$fe,$e0,$00,$fd,$ff,$d3,$00,$00,$03,$e0,$ff,$00,$80,$d0,$00,$00,$03,$e0,$ff,$00,$80,$d2,$00
	dc.b	$02,$ff,$ff,$fc,$e0,$00,$00,$7f,$fe,$ff,$d3,$00,$00,$03,$e0,$ff,$00,$80,$d0,$00,$00,$03,$e0,$ff,$00,$80,$d2,$00,$02,$ff,$ff,$fc
	dc.b	$e0,$00,$00,$7f,$fe,$ff,$d3,$00,$00,$07,$e7,$ff,$00,$fd,$fb,$ff,$00,$c0,$d0,$00,$00,$07,$e0,$ff,$00,$c0,$d2,$00,$02,$ff,$ff,$f8
	dc.b	$e7,$00,$00,$02,$fb,$00,$00,$3f,$fe,$ff,$81,$00,$ad,$00,$02,$ff,$ff,$f8,$e0,$00,$00,$3f,$fe,$ff,$81,$00,$81,$00,$81,$00,$81,$00
	dc.b	$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$81,$00,$f3,$00,$80
	even
	section	paldata,data
PalTable:	; per scene: 7 PF1 colours + 1 pad, then 58 sky colours
	dc.w	$ddf,$fd6,$113,$667,$435,$777,$333,$000
	dc.w	$102,$102,$102,$102,$102,$102,$103,$103,$213,$213,$213,$213,$213,$213,$213,$213,$213,$213,$214,$214,$214,$214,$324,$324,$324,$324,$324,$324,$324,$325,$325,$325,$325,$325,$325,$325,$435,$435,$435,$435,$436,$436,$436,$436,$436,$436,$436,$436,$436,$436,$546,$546,$547,$547,$547,$547,$547,$547
	dc.w	$9bf,$fd6,$113,$236,$744,$864,$531,$000
	dc.w	$013,$013,$013,$013,$013,$013,$014,$014,$024,$024,$124,$124,$124,$124,$124,$124,$124,$124,$125,$125,$125,$125,$135,$135,$135,$135,$135,$135,$135,$236,$236,$236,$236,$236,$236,$236,$246,$246,$246,$246,$247,$247,$247,$247,$247,$247,$247,$247,$347,$347,$357,$357,$358,$358,$358,$358,$358,$358
	dc.w	$bdf,$fc5,$113,$236,$3a8,$354,$666,$000
	dc.w	$012,$012,$012,$012,$012,$012,$013,$013,$113,$113,$113,$113,$113,$113,$113,$123,$123,$123,$124,$124,$124,$124,$224,$224,$224,$224,$224,$224,$224,$225,$225,$225,$225,$225,$225,$225,$325,$325,$325,$325,$326,$326,$326,$336,$336,$336,$336,$336,$336,$336,$436,$436,$437,$437,$437,$437,$437,$437
	dc.w	$dde,$fe7,$112,$778,$548,$863,$444,$000
	dc.w	$103,$103,$103,$103,$103,$103,$104,$104,$204,$204,$214,$214,$214,$214,$214,$214,$214,$214,$215,$215,$215,$215,$315,$315,$315,$315,$315,$315,$315,$326,$326,$326,$326,$326,$326,$326,$426,$426,$426,$426,$427,$427,$427,$427,$427,$427,$427,$427,$437,$437,$537,$537,$538,$538,$538,$538,$538,$538
	dc.w	$ccd,$fd5,$113,$655,$643,$953,$444,$000
	dc.w	$201,$201,$201,$201,$201,$201,$201,$201,$301,$301,$302,$302,$302,$302,$302,$312,$312,$312,$312,$312,$312,$312,$412,$412,$412,$412,$412,$412,$412,$413,$413,$413,$413,$413,$413,$413,$513,$513,$513,$513,$513,$513,$513,$523,$523,$523,$523,$523,$524,$524,$624,$624,$624,$624,$624,$624,$624,$624
	dc.w	$fff,$fe5,$125,$6a4,$8c6,$9ac,$d44,$000
	dc.w	$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$013,$013,$013,$013,$013,$013,$013,$013,$013,$013,$013,$013,$013,$013,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024
	dc.w	$fff,$fe5,$125,$6a4,$8c6,$9ac,$d44,$000
	dc.w	$012,$012,$012,$012,$012,$012,$012,$012,$012,$012,$013,$013,$013,$013,$013,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$023,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$024,$034,$034,$034,$034,$034,$035,$035,$035,$035,$035,$035,$035,$035,$035,$035
PF2Pal:	dc.w	$000,$fff,$5e4,$fe3,$d4e,$e82,$8cf,$112
BgTable:	dc.l	bg_jfk,bg_harbor,bg_liberty,bg_manhattan,bg_harlem,bg_map,bg_flight
MapPos:	dc.w	262,186,138,176,102,180,150,110,166,44
	section	logodata,data_c
LOGO_H	equ	76
LogoData	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$fe,$01,$ff,$f9,$ff,$fc,$01,$ff,$c0,$00,$3f,$fe,$1f,$ff,$ff,$fc,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$fe,$01,$ff,$f9,$ff,$fc,$01,$ff,$c0,$00,$3f
	dc.b	$fe,$1f,$ff,$ff,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$fe,$01,$ff
	dc.b	$f9,$ff,$fc,$01,$ff,$c0,$00,$3f,$fe,$1f,$ff,$ff,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$ff,$ff,$c3,$ff,$ff,$ff,$fe,$07,$ff,$f8,$00,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$c3,$ff,$ff,$ff,$fe,$07,$ff,$f8,$00,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$c3,$ff,$ff,$ff,$fe,$07,$ff,$f8,$00,$ff
	dc.b	$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$ff,$ff,$f3,$ff
	dc.b	$ff,$ff,$fe,$1f,$ff,$fe,$01,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$03,$f0,$03,$f3,$00,$0f,$00,$06,$1f,$00,$7e,$01,$e0,$03,$f0,$00,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$f0,$03,$f3,$00,$0f,$00,$06,$1f,$00,$7e,$01,$e0,$03,$f0,$00,$00,$06,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$f0,$03,$fb,$00,$0f,$00,$06,$3f,$00,$7f,$03,$e0
	dc.b	$03,$f0,$00,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$8f,$fc,$7b,$ff
	dc.b	$ff,$ff,$fe,$3c,$ff,$8f,$03,$9f,$fc,$7f,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$07,$8f,$fc,$7b,$ff,$ff,$ff,$fe,$3c,$ff,$8f,$03,$9f,$fc,$7f,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$83,$f0,$7b,$e0,$7f,$e0,$7e,$7c,$1e,$0f,$87,$87,$e0,$71,$f8,$0f,$e6,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$7f,$ff,$9b,$ff,$ff,$ff,$fe,$73,$ff,$f3,$87,$7f
	dc.b	$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$7f,$ff,$9b,$ff
	dc.b	$ff,$ff,$fe,$73,$ff,$f3,$87,$7f,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$1e,$0f,$fc,$19,$e0,$79,$e0,$7c,$f0,$7f,$83,$c7,$0f,$f8,$71,$f8,$0f,$e6,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1d,$ff,$ff,$f9,$ff,$f9,$ff,$fc,$ef,$ff,$fd,$c6,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1d,$ff,$ff,$f9,$ff,$ff,$ff,$ff,$ef,$ff,$fd,$c6,$ff
	dc.b	$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3c,$1e,$1e,$18,$60
	dc.b	$60,$60,$61,$e0,$f3,$81,$ce,$1c,$3c,$71,$98,$0c,$66,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$3b,$fe,$1f,$f8,$7f,$e0,$7f,$e1,$df,$f3,$fe,$cf,$fc,$3f,$ff,$9f,$fc,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3b,$ff,$ff,$f8,$7f,$fe,$7f,$ff,$df,$ff,$fe,$cf,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$38,$18,$06,$18,$60,$60,$60,$61,$c0,$c1,$c0,$ee,$18
	dc.b	$0c,$71,$98,$0c,$66,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$37,$f8,$07,$f8,$7f
	dc.b	$e0,$7f,$e1,$bf,$c1,$ff,$ed,$f8,$0f,$ff,$9f,$fc,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$37,$ff,$87,$fc,$7f,$f0,$7f,$f1,$bf,$fd,$ff,$ed,$ff,$0f,$ff,$df,$fe,$7f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$70,$38,$07,$18,$60,$60,$60,$63,$81,$c0,$c0,$ec,$1e,$0e,$7f,$98,$0c,$7e,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f8,$07,$f8,$7f,$e0,$7f,$e3,$ff,$c0,$ff,$6f,$fe
	dc.b	$0f,$ff,$9f,$fc,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$fe,$07,$fc,$7f
	dc.b	$f0,$7f,$f3,$ff,$f0,$ff,$6f,$fe,$0f,$ff,$df,$fe,$7f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$70,$30,$03,$18,$60,$60,$60,$63,$81,$80,$c0,$7c,$1f,$e7,$ff,$18,$0c,$3c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$6f,$f0,$03,$f8,$7f,$e0,$7f,$e3,$7f,$80,$ff,$ff,$ef,$e7,$ff,$1f,$fc,$3c,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$6f,$fc,$03,$fc,$7f,$f0,$7f,$f3,$7f,$e0,$ff,$ff,$ef
	dc.b	$e7,$ff,$df,$fe,$3f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60,$30,$03,$f8,$60
	dc.b	$60,$60,$63,$01,$80,$e0,$7c,$0f,$ff,$c0,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$7f,$f0,$03,$f8,$7f,$e0,$7f,$e3,$ff,$80,$ff,$bf,$f3,$ff,$c0,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$fc,$03,$fc,$7f,$f0,$7f,$f3,$ff,$e0,$ff,$bf,$f3,$ff,$f1,$df,$fe,$03,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60,$30,$01,$f0,$60,$7f,$e0,$63,$01,$80,$60,$3c,$03
	dc.b	$ff,$80,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f0,$01,$f0,$7f
	dc.b	$ff,$ff,$e3,$ff,$80,$7f,$ff,$fc,$3f,$80,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$7f,$f8,$01,$fc,$7f,$ff,$ff,$f3,$ff,$c0,$7f,$ff,$fc,$3f,$b0,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$e0,$30,$7f,$f0,$60,$7f,$e0,$67,$01,$80,$60,$3e,$00,$3f,$c0,$18,$0c,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f0,$7f,$f0,$7f,$ff,$ff,$e7,$ff,$80,$7f,$ff,$ff
	dc.b	$c3,$c0,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f8,$7f,$fc,$7f
	dc.b	$ff,$ff,$f7,$ff,$c0,$7f,$ff,$ff,$c3,$c0,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$e0,$30,$ff,$f8,$60,$7f,$e0,$67,$01,$80,$60,$36,$00,$03,$e0,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$df,$f0,$ff,$f8,$7f,$80,$1f,$e6,$ff,$80,$7f,$f7,$ff,$fc,$e0,$1f,$fc,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$df,$f8,$ff,$f8,$7f,$80,$1f,$f6,$ff,$c0,$7f,$ff,$ff
	dc.b	$fc,$e0,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$c0,$30,$ff,$f8,$60
	dc.b	$00,$00,$66,$01,$80,$60,$37,$00,$00,$f0,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$ff,$f0,$c0,$18,$7f,$ff,$ff,$e7,$ff,$80,$7f,$f7,$ff,$ff,$70,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f8,$c0,$18,$7f,$ff,$ff,$f7,$ff,$c0,$7f,$ff,$ff,$ff,$70,$1f,$fe,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$c0,$30,$c0,$18,$60,$7f,$e0,$66,$01,$80,$60,$33,$c0
	dc.b	$00,$70,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f0,$ff,$f8,$7f
	dc.b	$ff,$ff,$e7,$ff,$80,$7f,$f3,$ff,$ff,$b0,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$ff,$f8,$ff,$f8,$7f,$ff,$ff,$f7,$ff,$c0,$7f,$fb,$ff,$ff,$b0,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$e0,$30,$f8,$18,$60,$7f,$e0,$67,$01,$80,$60,$31,$fc,$00,$30,$18,$0c,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f0,$ff,$f8,$7f,$ff,$ff,$e7,$ff,$80,$7f,$f1,$ff
	dc.b	$ff,$f0,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f8,$ff,$f8,$7f
	dc.b	$ff,$ff,$f7,$ff,$c0,$7f,$f9,$ff,$ff,$f0,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$60,$30,$78,$18,$60,$60,$60,$63,$01,$80,$60,$33,$ff,$c0,$38,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f0,$7f,$f8,$7f,$e0,$7f,$e3,$ff,$80,$7f,$f3,$ff,$ff,$f8,$1f,$fc,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f8,$7f,$fc,$7f,$ff,$ff,$f3,$ff,$c0,$7f,$fb,$ff
	dc.b	$ff,$f8,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60,$30,$18,$18,$60
	dc.b	$60,$60,$63,$01,$80,$e0,$37,$e7,$f0,$38,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$7f,$f0,$1f,$f8,$7f,$e0,$7f,$e3,$ff,$80,$ff,$f7,$e7,$ff,$d8,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f8,$1f,$fc,$7f,$f0,$7f,$f3,$ff,$c0,$ff,$ff,$e7,$ff,$d8,$1f,$fe,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60,$30,$18,$18,$60,$60,$60,$63,$01,$80,$e0,$77,$e0
	dc.b	$78,$18,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f0,$1f,$f8,$7f
	dc.b	$e0,$7f,$e3,$ff,$80,$df,$f6,$60,$7f,$f8,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$7f,$f8,$1f,$fc,$7f,$f0,$7f,$f3,$ff,$c0,$df,$fe,$60,$7f,$f8,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$70,$38,$18,$18,$60,$60,$60,$63,$81,$c0,$c0,$66,$70,$18,$38,$18,$0c,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f8,$1f,$f8,$7f,$e0,$7f,$e3,$ff,$c0,$ff,$e7,$f0
	dc.b	$1f,$f8,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7f,$f8,$1f,$fc,$7f
	dc.b	$f0,$7f,$f3,$ff,$c0,$ff,$ff,$f0,$1f,$f8,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$30,$38,$18,$18,$60,$60,$60,$61,$81,$c1,$c0,$e6,$70,$18,$30,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3f,$d8,$1f,$f8,$7f,$e0,$7f,$e1,$fe,$c1,$ff,$e7,$b0,$1f,$f0,$1f,$fc,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3f,$d8,$1f,$fc,$7f,$f0,$7f,$f1,$fe,$c1,$ff,$ff,$b0
	dc.b	$1f,$fc,$1f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$38,$1e,$38,$18,$60
	dc.b	$60,$60,$61,$c0,$f3,$c0,$c6,$3c,$38,$30,$18,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$3f,$fe,$3f,$f8,$7f,$e0,$7f,$e1,$ff,$f3,$bf,$c7,$fc,$3f,$f0,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3f,$fe,$3f,$fc,$7f,$f0,$7f,$f1,$ff,$f3,$bf,$f7,$fc,$3f,$fc,$1f,$fe,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$1f,$f8,$19,$e0,$79,$e0,$7c,$e0,$ff,$81,$c6,$3f
	dc.b	$f8,$70,$78,$0f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$ef,$ff,$f9,$ff
	dc.b	$f9,$ff,$fc,$ff,$7f,$ff,$c7,$df,$f7,$f0,$7f,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$1f,$ef,$ff,$fd,$ff,$f9,$ff,$fc,$ff,$7f,$ff,$f7,$df,$f7,$f8,$7f,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$0f,$f8,$3b,$e0,$7f,$e0,$7e,$70,$7f,$83,$86,$1f,$f0,$60,$f8,$0f,$80,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$f3,$e7,$fb,$ff,$ff,$ff,$fe,$7f,$9e,$7f,$87,$e7
	dc.b	$ef,$e0,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$f3,$e7,$ff,$ff
	dc.b	$ff,$ff,$fe,$7f,$9e,$7f,$e7,$e7,$ef,$f8,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$07,$83,$e0,$f3,$e0,$7f,$e0,$7e,$3c,$1e,$0f,$07,$07,$e1,$e0,$f8,$0f,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$fc,$1f,$f3,$1f,$8f,$1f,$86,$3f,$e1,$ff,$07,$f8,$1f,$e0,$c7,$f1,$80,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$fc,$1f,$ff,$1f,$8f,$1f,$86,$3f,$e1,$ff,$e7,$f8
	dc.b	$1f,$f8,$c7,$f1,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$f0,$07,$e3,$00
	dc.b	$0f,$00,$06,$1f,$00,$7e,$03,$e0,$07,$c0,$c0,$01,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$03,$ff,$ff,$e3,$ff,$ff,$ff,$fe,$1f,$ff,$fe,$03,$ff,$ff,$c0,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$c3,$ff,$ff,$f0,$ff,$ff,$80,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$83,$ff,$ff,$ff,$fe,$07,$ff,$f8,$01,$ff
	dc.b	$ff,$00,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$83,$ff
	dc.b	$ff,$ff,$fe,$07,$ff,$f8,$01,$ff,$ff,$00,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$ff,$ff,$fb,$ff,$ff,$ff,$fe,$07,$ff,$ff,$81,$ff,$ff,$f0,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$fc,$01,$ff,$f9,$ff,$fc,$01,$ff,$c0,$00,$3f,$fc,$00,$7f,$ff,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$fc,$01,$ff,$f9,$ff,$fc,$01,$ff,$c0,$00,$3f
	dc.b	$fc,$00,$7f,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1f,$ff,$e1,$ff
	dc.b	$ff,$ff,$ff,$01,$ff,$fe,$00,$3f,$ff,$c0,$7f,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$ff,$00,$1f,$fe,$1f,$ff,$00,$1f,$f0,$00,$03
	dc.b	$ff,$00,$07,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$ff,$ff,$f8,$00,$fc,$00,$7f
	dc.b	$ff,$f8,$1f,$ff,$fe,$0f,$ff,$ff,$f3,$ff,$ff,$c0,$01,$ff,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$ff,$ff,$f8,$00,$fc,$00,$7f,$ff,$f8,$1f,$ff,$fe,$0f,$ff,$ff,$f3,$ff,$ff,$c0,$01,$ff,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$03,$ff,$ff,$f8,$00,$fc,$00,$7f,$ff,$f8,$1f,$ff,$fe,$0f,$ff,$ff,$f3,$ff,$ff,$c0,$01,$ff,$f0,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$01,$fe,$00,$ff,$ff,$fe,$3f,$ff,$ff,$9f,$ff,$ff
	dc.b	$ff,$ff,$ff,$f0,$07,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$01,$fe,$00,$ff
	dc.b	$ff,$fe,$3f,$ff,$ff,$9f,$ff,$ff,$ff,$ff,$ff,$f0,$07,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$07,$ff,$ff,$fc,$01,$fe,$00,$ff,$ff,$fe,$3f,$ff,$ff,$9f,$ff,$ff,$ff,$ff,$ff,$f0,$07,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$03,$ff,$00,$ff,$ff,$ff,$3f,$ff,$ff,$df,$ff,$ff,$ff,$ff,$ff,$f8,$0f,$ff,$ff,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$00,$00,$0c,$03,$87,$00,$c0,$00,$0f,$30,$00,$03,$d8,$00,$00
	dc.b	$1e,$00,$00,$78,$0f,$00,$1f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$00,$00,$0c,$03,$87,$00,$c0
	dc.b	$00,$0f,$30,$00,$03,$d8,$00,$00,$1e,$00,$00,$78,$0f,$00,$1f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$06,$00,$00,$0c,$03,$87,$00,$c0,$00,$0f,$b0,$00,$03,$f8,$00,$00,$1e,$00,$00,$7c,$1f,$00,$1f,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$03,$7b,$00,$ff,$ff,$f3,$bf,$ff,$fc,$ff,$ff,$ff,$ff,$ff,$ff,$9c,$1c,$ff,$e3,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$03,$7b,$00,$ff,$ff,$f3,$bf,$ff,$fc,$ff,$ff,$ff
	dc.b	$ff,$ff,$ff,$9c,$1c,$ff,$e3,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$7f,$f8,$0c,$03,$03,$80,$f8
	dc.b	$1e,$03,$fe,$07,$80,$ff,$03,$ff,$9f,$c0,$f8,$1e,$3c,$3f,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$07,$ff,$ff,$fc,$03,$ff,$80,$ff,$ff,$fd,$ff,$ff,$ff,$7f,$ff,$ff,$ff,$ff,$ff,$ee,$3b,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$fc,$03,$ff,$80,$ff,$ff,$fd,$ff,$ff,$ff,$7f,$ff,$ff,$ff,$ff,$ff,$ee,$3b,$ff,$ff,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$7f,$f8,$0c,$07,$03,$80,$78,$1f,$01,$de,$07,$c0,$7f,$03,$ff
	dc.b	$9b,$c0,$fc,$0e,$38,$7f,$c3,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$f7,$fc,$07,$fd,$80,$7f
	dc.b	$ff,$fe,$df,$ff,$ff,$bf,$ff,$ff,$fb,$ff,$ff,$f6,$37,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$07,$ff,$f7,$fe,$07,$fd,$80,$7f,$ff,$fe,$df,$ff,$ff,$bf,$ff,$ff,$ff,$ff,$ff,$f6,$37,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$06,$60,$f0,$1c,$07,$01,$80,$18,$1b,$80,$e6,$06,$e0,$3b,$03,$01,$98,$c0,$ce,$07,$70,$e1,$e3,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$e0,$ef,$fc,$06,$ff,$80,$1f,$fb,$ff,$e7,$fe,$ff,$fb,$ff,$01
	dc.b	$f8,$ff,$cf,$ff,$7f,$e1,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ef,$fe,$06,$ff,$80,$1f
	dc.b	$ff,$ff,$e7,$ff,$ff,$fb,$ff,$ff,$fc,$ff,$ff,$ff,$7f,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$06,$60,$e0,$38,$0e,$01,$c0,$18,$19,$80,$e6,$06,$60,$3b,$03,$0f,$98,$c0,$c6,$07,$70,$c0,$63,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$e0,$df,$f8,$0f,$ff,$c0,$1f,$f9,$ff,$67,$fe,$7f,$db,$ff,$0f,$f8,$ff,$c7,$fb,$6f,$c0,$7f,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$f0,$df,$fe,$0f,$ff,$c0,$1f,$fd,$ff,$67,$ff,$7f,$db,$ff,$8f
	dc.b	$fc,$ff,$e7,$fb,$6f,$f8,$7f,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$e1,$c0,$30,$0e,$01,$c0,$18
	dc.b	$19,$c0,$66,$06,$70,$1b,$03,$1f,$f8,$c0,$c6,$03,$60,$f0,$73,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$07,$e1,$ff,$f0,$0d,$fe,$c0,$1f,$f9,$ff,$e7,$fe,$7f,$fb,$ff,$1f,$f8,$ff,$c7,$ff,$7f,$f0,$7f,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$f1,$ff,$fe,$0d,$fe,$c0,$1f,$fd,$ff,$e7,$ff,$7f,$fb,$ff,$9f,$fc,$ff,$e7,$ff,$7f,$f0,$7f,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$c3,$c0,$70,$0c,$00,$e0,$18,$18,$c0,$66,$06,$30,$1b,$03,$1f
	dc.b	$f0,$c0,$c6,$03,$60,$ff,$3f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$c3,$bf,$f0,$0f,$ff,$e0,$1f
	dc.b	$f8,$ff,$e7,$fe,$3f,$fb,$ff,$19,$f0,$ff,$c7,$ff,$7f,$7f,$3f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$f3,$bf,$fc,$0f,$ff,$e0,$1f,$fc,$ff,$e7,$ff,$3f,$fb,$ff,$99,$fc,$ff,$e7,$ff,$7f,$7f,$3f,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$80,$e0,$1c,$c0,$e0,$18,$19,$c0,$66,$06,$70,$1b,$03,$f9,$80,$c0,$c6,$03,$60,$7f,$fe,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$7f,$e0,$1f,$ff,$60,$1f,$f9,$ff,$e7,$fe,$7f,$fb,$ff,$ff
	dc.b	$80,$ff,$c7,$ff,$7f,$9f,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$33,$7f,$f8,$1f,$ff,$60,$1f
	dc.b	$fd,$ff,$f7,$ff,$7f,$ff,$ff,$ff,$8c,$ff,$e7,$ff,$ff,$9f,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$07,$01,$c0,$1c,$c0,$60,$18,$19,$c0,$66,$06,$70,$1b,$03,$f9,$80,$c0,$ce,$07,$60,$1f,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$c0,$1b,$ff,$e0,$1f,$f9,$bf,$e7,$fe,$6f,$fb,$ff,$ff,$80,$ff,$cf,$ff,$7f,$e1,$fc,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$f8,$1b,$ff,$e0,$1f,$fd,$bf,$f7,$ff,$6f,$ff,$ff,$ff
	dc.b	$80,$ff,$ef,$ff,$ff,$e1,$fd,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$01,$80,$39,$c0,$70,$18
	dc.b	$1b,$80,$e6,$06,$e0,$3b,$03,$f9,$80,$c0,$fe,$06,$70,$01,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$0e,$ff,$80,$3f,$ff,$f0,$1f,$fb,$ff,$e7,$fe,$ff,$fb,$fc,$07,$80,$ff,$fd,$fe,$7f,$fe,$1e,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$ff,$f0,$3f,$ff,$f0,$1f,$ff,$ff,$f7,$ff,$ff,$ff,$fc,$07,$c0,$ff,$fd,$ff,$ff,$fe,$1e,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1e,$03,$80,$39,$e0,$70,$18,$1f,$80,$c6,$07,$e0,$33,$00,$01
	dc.b	$80,$c0,$fc,$0e,$30,$00,$1f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1d,$ff,$80,$37,$ff,$b0,$1f
	dc.b	$ff,$7f,$c7,$ff,$df,$f3,$ff,$ff,$80,$ff,$fb,$fe,$3f,$ff,$e7,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$1d,$ff,$e0,$37,$ff,$b0,$1f,$ff,$7f,$f7,$ff,$df,$ff,$ff,$ff,$c0,$ff,$fb,$ff,$bf,$ff,$e7,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$07,$00,$31,$e0,$38,$18,$1f,$01,$c6,$07,$c0,$73,$03,$f9,$80,$c0,$f8,$7c,$38,$00,$07,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1b,$ff,$00,$3f,$ff,$f8,$1f,$fe,$ff,$c7,$ff,$bf,$f3,$ff,$ff
	dc.b	$80,$ff,$07,$fc,$3f,$ff,$fb,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1b,$ff,$c0,$3f,$ff,$f8,$1f
	dc.b	$fe,$ff,$f7,$ff,$bf,$ff,$ff,$ff,$c0,$ff,$07,$ff,$3f,$ff,$fb,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$38,$06,$00,$73,$f0,$38,$18,$1e,$03,$86,$07,$80,$e3,$03,$f9,$80,$c0,$00,$78,$1e,$00,$03,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$3f,$fe,$00,$7f,$ff,$d8,$1f,$e1,$ff,$87,$f8,$7f,$e3,$ff,$ff,$80,$ff,$ff,$f8,$1f,$ff,$fd,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3f,$ff,$c0,$7f,$ff,$d8,$1f,$e1,$ff,$e7,$f8,$7f,$fb,$ff,$ff
	dc.b	$c0,$ff,$ff,$ff,$1f,$ff,$fd,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$78,$0e,$00,$73,$f0,$18,$18
	dc.b	$00,$0f,$06,$00,$03,$c3,$03,$19,$80,$c0,$e0,$78,$0f,$e0,$01,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$77,$fe,$00,$6f,$ff,$f8,$1f,$ff,$ff,$07,$ff,$ff,$c3,$ff,$1f,$80,$ff,$ff,$b8,$0f,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$77,$ff,$80,$6f,$ff,$f8,$1f,$ff,$ff,$e7,$ff,$ff,$fb,$ff,$ff,$c0,$ff,$ff,$be,$0f,$ff,$ff,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$70,$1c,$00,$e7,$f0,$1c,$18,$1f,$fe,$06,$07,$ff,$83,$03,$1f
	dc.b	$80,$c0,$f0,$3c,$1f,$fe,$01,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$6f,$fc,$00,$ff,$ff,$fc,$1f
	dc.b	$ff,$fe,$07,$ff,$ff,$83,$ff,$1f,$80,$ff,$ff,$dc,$1f,$ff,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$6f,$ff,$00,$ff,$ff,$fc,$1f,$ff,$ff,$c7,$ff,$ff,$f3,$ff,$9f,$c0,$ff,$ff,$dc,$1f,$ff,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$e0,$38,$00,$e7,$f0,$1c,$18,$1f,$f8,$06,$07,$fe,$03,$03,$0f,$00,$c0,$f8,$1c,$3f,$3f,$81,$c0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$f8,$00,$d8,$0f,$ec,$1f,$ff,$f8,$07,$ff,$fe,$03,$ff,$0f
	dc.b	$00,$ff,$ff,$ec,$3f,$3f,$fe,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$00,$d8,$0f,$ec,$1f
	dc.b	$ff,$ff,$87,$ff,$ff,$e3,$ff,$8f,$c0,$ff,$ff,$ec,$3f,$3f,$fe,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$01,$e0,$30,$00,$c0,$00,$0e,$18,$18,$00,$06,$06,$00,$03,$03,$00,$f0,$c0,$d8,$0e,$3f,$03,$c0,$c0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$01,$df,$f0,$00,$ff,$ff,$fe,$1f,$f8,$00,$07,$fe,$00,$03,$ff,$00,$f0,$ff,$df,$fe,$33,$03,$ff,$c0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$df,$fe,$00,$ff,$ff,$fe,$1f,$ff,$fe,$07,$ff,$ff,$83,$ff,$80
	dc.b	$f0,$ff,$ff,$fe,$33,$03,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$c0,$70,$7d,$cf,$fc,$0e,$18
	dc.b	$18,$00,$06,$06,$00,$03,$03,$01,$f8,$c0,$dc,$0e,$33,$80,$c1,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$bf,$f0,$7d,$ff,$ff,$f6,$1f,$f8,$00,$07,$fe,$00,$03,$ff,$01,$f8,$ff,$df,$f6,$3f,$80,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$03,$bf,$fc,$7d,$ff,$ff,$f6,$1f,$fc,$00,$07,$ff,$00,$03,$ff,$81,$f8,$ff,$ff,$f6,$3f,$80,$ff,$c0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$80,$e0,$ff,$cf,$fc,$06,$18,$18,$00,$06,$06,$00,$03,$03,$01
	dc.b	$f8,$c0,$cc,$07,$33,$80,$c1,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$7f,$e0,$ff,$bf,$ff,$fe,$1f
	dc.b	$f8,$00,$07,$fe,$00,$03,$ff,$01,$98,$ff,$cf,$ff,$3d,$80,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$7f,$f8,$ff,$bf,$ff,$fe,$1f,$fc,$00,$07,$ff,$00,$03,$ff,$81,$98,$ff,$ef,$ff,$3d,$80,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$00,$c0,$ff,$9c,$0c,$07,$18,$18,$00,$06,$06,$00,$03,$03,$01,$98,$c0,$ce,$07,$31,$e1,$c1,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$c0,$c7,$fc,$0f,$ff,$1f,$f8,$00,$07,$fe,$00,$03,$ff,$01
	dc.b	$f8,$ff,$cf,$fb,$3f,$e1,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$f8,$c7,$ff,$ff,$ff,$1f
	dc.b	$fc,$00,$07,$ff,$00,$03,$ff,$81,$f8,$ff,$ef,$fb,$3f,$e1,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$0f,$01,$ff,$c7,$9c,$0e,$07,$f8,$1f,$00,$1e,$07,$c0,$0f,$03,$ff,$9b,$c0,$f6,$03,$f1,$ff,$c3,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$0e,$ff,$ff,$ff,$7c,$0f,$fb,$ff,$ff,$00,$1f,$ff,$c0,$0f,$ff,$ff,$fb,$ff,$f7,$ff,$fe,$ff,$bf,$80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$ff,$ff,$ff,$7e,$0f,$fb,$ff,$ff,$00,$1f,$ff,$c0,$0f,$ff,$ff
	dc.b	$fb,$ff,$f7,$ff,$fe,$ff,$bf,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$03,$ff,$c7,$3e,$1e,$03,$f8
	dc.b	$1f,$80,$3e,$07,$e0,$1f,$03,$ff,$9f,$c0,$ff,$03,$f0,$ff,$83,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$0d,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff,$ff,$ff,$ff,$fd,$ff,$3f,$7f,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$0d,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff,$ff,$ff,$ff,$fd,$ff,$3f,$7f,$c0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$03,$ff,$c7,$3e,$1e,$03,$f8,$1f,$80,$3e,$07,$e0,$1f,$03,$ff
	dc.b	$9f,$c0,$fb,$01,$f8,$3f,$0f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$fc,$00,$3c,$c6,$19,$fc,$47
	dc.b	$e1,$80,$31,$f8,$60,$18,$fc,$00,$7e,$3f,$1b,$fe,$3f,$c0,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$0f,$fc,$00,$3c,$c6,$19,$fc,$47,$e1,$80,$31,$f8,$60,$18,$fc,$00,$7e,$3f,$1b,$fe,$3f,$c0,$ff,$c0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$00,$04,$06,$18,$00,$40,$01,$80,$30,$00,$60,$18,$00,$00,$1e,$00,$1b,$80,$3f,$00,$3e,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff
	dc.b	$ff,$ff,$fb,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$fe,$1f,$ff,$ff
	dc.b	$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff,$ff,$ff,$fb,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$0f,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff,$ff,$ff,$f9,$ff,$ff,$ff,$f8,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff,$ff,$ff,$f9,$ff,$ff,$ff,$f8,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$fe,$1f,$ff,$ff,$ff,$80,$3f,$ff,$e0,$1f,$ff,$ff
	dc.b	$ff,$ff,$f9,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$ff,$fc,$0f,$ff,$ff
	dc.b	$ff,$00,$1f,$ff,$c0,$0f,$ff,$ff,$f3,$ff,$f0,$ff,$e1,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$07,$ff,$ff,$ff,$fc,$0f,$ff,$ff,$ff,$00,$1f,$ff,$c0,$0f,$ff,$ff,$f3,$ff,$f0,$ff,$e1,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$ff,$ff,$ff,$ff,$0f,$ff,$ff,$ff,$c0,$1f,$ff,$f0,$0f,$ff,$ff,$ff,$ff,$fc,$ff,$f9,$ff,$fe,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$7f,$ff,$ff,$7f,$00,$ff,$f7,$ff,$c0,$01,$ff,$f0,$00,$ff,$ff,$fc,$3f,$fc,$0f,$f8,$1f,$f8,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	section	sindata,data
SinTab:
	dc.b	0,3,6,9,12,16,19,22,25,28,31,34,37,40,43,46
	dc.b	49,51,54,57,60,63,65,68,71,73,76,78,81,83,85,88
	dc.b	90,92,94,96,98,100,102,104,106,107,109,111,112,113,115,116
	dc.b	117,118,120,121,122,122,123,124,125,125,126,126,126,127,127,127
	dc.b	127,127,127,127,126,126,126,125,125,124,123,122,122,121,120,118
	dc.b	117,116,115,113,112,111,109,107,106,104,102,100,98,96,94,92
	dc.b	90,88,85,83,81,78,76,73,71,68,65,63,60,57,54,51
	dc.b	49,46,43,40,37,34,31,28,25,22,19,16,12,9,6,3
	dc.b	0,-3,-6,-9,-12,-16,-19,-22,-25,-28,-31,-34,-37,-40,-43,-46
	dc.b	-49,-51,-54,-57,-60,-63,-65,-68,-71,-73,-76,-78,-81,-83,-85,-88
	dc.b	-90,-92,-94,-96,-98,-100,-102,-104,-106,-107,-109,-111,-112,-113,-115,-116
	dc.b	-117,-118,-120,-121,-122,-122,-123,-124,-125,-125,-126,-126,-126,-127,-127,-127
	dc.b	-127,-127,-127,-127,-126,-126,-126,-125,-125,-124,-123,-122,-122,-121,-120,-118
	dc.b	-117,-116,-115,-113,-112,-111,-109,-107,-106,-104,-102,-100,-98,-96,-94,-92
	dc.b	-90,-88,-85,-83,-81,-78,-76,-73,-71,-68,-65,-63,-60,-57,-54,-51
	dc.b	-49,-46,-43,-40,-37,-34,-31,-28,-25,-22,-19,-16,-12,-9,-6,-3

;---------------------------------------------------------------------
; file: gen_music.s
;---------------------------------------------------------------------
; generated by make_sound.py - original music for Ghost Zappers (Amiga)
	section	sampdata,data_c
smp_bass64	dc.b	$48,$47,$45,$44,$43,$41,$40,$3f,$3e,$3c,$3b,$3a,$38,$37,$36,$34,$33,$32,$30,$2f,$2e,$2c,$2b,$2a,$ec,$eb,$ea,$e9,$e7,$e6,$e5,$e3
	dc.b	$e2,$e1,$df,$de,$dd,$db,$da,$d9,$d8,$d6,$d5,$d4,$d2,$d1,$d0,$ce,$cd,$cc,$ca,$c9,$c8,$c6,$c5,$c4,$c2,$c1,$c0,$bf,$bd,$bc,$bb,$b9
smp_lead32	dc.b	$1f,$37,$37,$37,$37,$37,$37,$37,$1f,$f0,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$d8,$f0
smp_tri32	dc.b	$9c,$a8,$b5,$c2,$ce,$da,$e7,$f4,$00,$0c,$19,$26,$32,$3e,$4b,$58,$64,$58,$4b,$3e,$32,$26,$19,$0c,$00,$f4,$e7,$da,$ce,$c2,$b5,$a8
smp_sine32	dc.b	$00,$15,$2a,$3d,$4e,$5b,$66,$6c,$6e,$6c,$66,$5b,$4e,$3d,$2a,$15,$00,$eb,$d6,$c3,$b2,$a5,$9a,$94,$92,$94,$9a,$a5,$b2,$c3,$d6,$eb
smp_kick	dc.b	$09,$11,$1a,$22,$2b,$33,$3a,$42,$49,$50,$56,$5c,$62,$67,$6b,$6f,$72,$75,$78,$7a,$7b,$7b,$7c,$7b,$7a,$78,$76,$74,$70,$6d,$69,$64
	dc.b	$5f,$5a,$54,$4e,$47,$40,$39,$32,$2b,$23,$1b,$13,$0b,$03,$fb,$f4,$ec,$e4,$dc,$d5,$ce,$c7,$c0,$ba,$b3,$ae,$a8,$a3,$9e,$9a,$96,$93
	dc.b	$90,$8d,$8b,$8a,$88,$88,$88,$88,$89,$8a,$8c,$8e,$90,$93,$97,$9b,$9f,$a3,$a8,$ae,$b3,$b9,$bf,$c5,$cc,$d2,$d9,$e0,$e7,$ee,$f5,$fd
	dc.b	$04,$0b,$12,$19,$20,$27,$2d,$34,$3a,$40,$46,$4b,$50,$55,$5a,$5e,$62,$66,$69,$6c,$6e,$70,$72,$73,$74,$75,$75,$75,$74,$73,$72,$70
	dc.b	$6e,$6b,$68,$65,$62,$5e,$5a,$55,$51,$4c,$47,$41,$3c,$36,$30,$2a,$24,$1e,$17,$11,$0b,$04,$fe,$f7,$f1,$eb,$e4,$de,$d8,$d2,$cd,$c7
	dc.b	$c2,$bd,$b8,$b3,$af,$aa,$a6,$a3,$9f,$9c,$9a,$97,$95,$93,$91,$90,$8f,$8f,$8f,$8f,$8f,$90,$91,$92,$94,$96,$98,$9b,$9d,$a0,$a4,$a7
	dc.b	$ab,$af,$b3,$b8,$bd,$c1,$c6,$cb,$d1,$d6,$db,$e1,$e7,$ec,$f2,$f8,$fd,$03,$09,$0e,$14,$1a,$1f,$24,$2a,$2f,$34,$39,$3d,$42,$46,$4a
	dc.b	$4e,$52,$56,$59,$5c,$5f,$62,$64,$66,$68,$6a,$6b,$6c,$6d,$6d,$6e,$6e,$6d,$6d,$6c,$6b,$6a,$68,$67,$65,$62,$60,$5d,$5a,$57,$54,$51
	dc.b	$4d,$49,$45,$41,$3d,$38,$34,$2f,$2b,$26,$21,$1c,$17,$12,$0d,$08,$03,$fe,$f9,$f4,$ef,$ea,$e5,$e0,$dc,$d7,$d2,$ce,$ca,$c6,$c2,$be
	dc.b	$ba,$b6,$b3,$b0,$ad,$aa,$a7,$a4,$a2,$a0,$9e,$9c,$9b,$9a,$98,$98,$97,$96,$96,$96,$96,$97,$97,$98,$99,$9a,$9c,$9d,$9f,$a1,$a3,$a6
	dc.b	$a8,$ab,$ae,$b1,$b4,$b7,$bb,$be,$c2,$c6,$c9,$cd,$d1,$d5,$da,$de,$e2,$e7,$eb,$ef,$f4,$f8,$fd,$01,$05,$0a,$0e,$13,$17,$1b,$1f,$23
	dc.b	$28,$2b,$2f,$33,$37,$3a,$3e,$41,$45,$48,$4b,$4d,$50,$53,$55,$57,$59,$5b,$5d,$5f,$60,$61,$63,$64,$64,$65,$65,$66,$66,$66,$65,$65
	dc.b	$64,$64,$63,$62,$60,$5f,$5e,$5c,$5a,$58,$56,$54,$51,$4f,$4c,$4a,$47,$44,$41,$3e,$3a,$37,$34,$30,$2d,$29,$25,$22,$1e,$1a,$16,$13
	dc.b	$0f,$0b,$07,$03,$ff,$fb,$f7,$f4,$f0,$ec,$e8,$e5,$e1,$dd,$da,$d6,$d3,$d0,$cd,$c9,$c6,$c3,$c0,$be,$bb,$b8,$b6,$b4,$b1,$af,$ad,$ab
	dc.b	$aa,$a8,$a6,$a5,$a4,$a3,$a2,$a1,$a0,$a0,$9f,$9f,$9f,$9f,$9f,$9f,$9f,$a0,$a1,$a1,$a2,$a3,$a4,$a6,$a7,$a8,$aa,$ac,$ae,$af,$b1,$b4
	dc.b	$b6,$b8,$bb,$bd,$c0,$c2,$c5,$c8,$cb,$ce,$d1,$d4,$d7,$da,$dd,$e0,$e3,$e7,$ea,$ed,$f1,$f4,$f7,$fb,$fe,$02,$05,$08,$0c,$0f,$12,$15
	dc.b	$19,$1c,$1f,$22,$25,$28,$2b,$2e,$31,$33,$36,$39,$3b,$3e,$40,$42,$44,$47,$49,$4b,$4c,$4e,$50,$51,$53,$54,$56,$57,$58,$59,$5a,$5a
	dc.b	$5b,$5c,$5c,$5c,$5d,$5d,$5d,$5d,$5c,$5c,$5c,$5b,$5b,$5a,$59,$58,$57,$56,$55,$54,$52,$51,$4f,$4e,$4c,$4a,$48,$46,$44,$42,$40,$3e
	dc.b	$3c,$39,$37,$35,$32,$2f,$2d,$2a,$28,$25,$22,$1f,$1d,$1a,$17,$14,$11,$0e,$0b,$09,$06,$03,$00,$fd,$fa,$f7,$f4,$f1,$ef,$ec,$e9,$e6
	dc.b	$e4,$e1,$de,$dc,$d9,$d7,$d4,$d2,$cf,$cd,$cb,$c9,$c7,$c4,$c2,$c0,$bf,$bd,$bb,$b9,$b8,$b6,$b5,$b3,$b2,$b1,$b0,$af,$ae,$ad,$ac,$ab
	dc.b	$aa,$aa,$a9,$a9,$a9,$a8,$a8,$a8,$a8,$a8,$a8,$a9,$a9,$a9,$aa,$aa,$ab,$ac,$ac,$ad,$ae,$af,$b0,$b2,$b3,$b4,$b5,$b7,$b8,$ba,$bb,$bd
	dc.b	$bf,$c1,$c2,$c4,$c6,$c8,$ca,$cc,$ce,$d1,$d3,$d5,$d7,$d9,$dc,$de,$e0,$e3,$e5,$e8,$ea,$ed,$ef,$f2,$f4,$f7,$f9,$fb,$fe,$00,$03,$05
	dc.b	$08,$0a,$0d,$0f,$12,$14,$16,$19,$1b,$1d,$20,$22,$24,$26,$28,$2a,$2d,$2f,$30,$32,$34,$36,$38,$3a,$3b,$3d,$3f,$40,$42,$43,$44,$46
	dc.b	$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f,$4f,$50,$51,$51,$52,$52,$52,$53,$53,$53,$53,$53,$53,$53,$52,$52,$52,$52,$51,$51,$50,$4f,$4f
	dc.b	$4e,$4d,$4c,$4b,$4a,$49,$48,$47,$46,$45,$43,$42,$41,$3f,$3e,$3c,$3b,$39,$37,$36,$34,$32,$31,$2f,$2d,$2b,$29,$27,$25,$23,$21,$1f
	dc.b	$1d,$1b,$19,$17,$15,$13,$11,$0f,$0c,$0a,$08,$06,$04,$02,$00,$fe,$fb,$f9,$f7,$f5,$f3,$f1,$ef,$ed,$eb,$e9,$e7,$e5,$e3,$e1,$df,$dd
	dc.b	$db,$d9,$d8,$d6,$d4,$d3,$d1,$cf,$ce,$cc,$cb,$c9,$c8,$c6,$c5,$c4,$c2,$c1,$c0,$bf,$be,$bd,$bc,$bb,$ba,$b9,$b8,$b8,$b7,$b6,$b6,$b5
	dc.b	$b4,$b4,$b4,$b3,$b3,$b3,$b3,$b2,$b2,$b2,$b2,$b2,$b2,$b3,$b3,$b3,$b3,$b4,$b4,$b4,$b5,$b6,$b6,$b7,$b7,$b8,$b9,$ba,$bb,$bb,$bc,$bd
	dc.b	$be,$bf,$c1,$c2,$c3,$c4,$c5,$c7,$c8,$c9,$cb,$cc,$cd,$cf,$d0,$d2,$d3,$d5,$d7,$d8,$da,$dc,$dd,$df,$e1,$e2,$e4,$e6,$e8,$e9,$eb,$ed
	dc.b	$ef,$f1,$f2,$f4,$f6,$f8,$fa,$fc,$fd,$ff,$01,$03,$05,$07,$08,$0a,$0c,$0e,$10,$11,$13,$15,$17,$18,$1a,$1c,$1d,$1f,$20,$22,$24,$25
	dc.b	$27,$28,$2a,$2b,$2c,$2e,$2f,$31,$32,$33,$34,$35,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f,$40,$40,$41,$42,$43,$43,$44,$45,$45,$46,$46
	dc.b	$46,$47,$47,$48,$48,$48,$48,$48,$48,$48,$49,$49,$48,$48,$48,$48,$48,$48,$47,$47,$47,$46,$46,$45,$45,$44,$44,$43,$42,$42,$41,$40
	dc.b	$3f,$3f,$3e,$3d,$3c,$3b,$3a,$39,$38,$37,$36,$35,$33,$32,$31,$30,$2f,$2d,$2c,$2b,$29,$28,$27,$25,$24,$22,$21,$20,$1e,$1d,$1b,$1a
	dc.b	$18,$17,$15,$14,$12,$10,$0f,$0d,$0c,$0a,$09,$07,$05,$04,$02,$01,$ff,$fe,$fc,$fa,$f9,$f7,$f6,$f4,$f3,$f1,$f0,$ee,$ed,$eb,$ea,$e8
	dc.b	$e7,$e5,$e4,$e3,$e1,$e0,$df,$dd,$dc,$db,$d9,$d8,$d7,$d6,$d5,$d3,$d2,$d1,$d0,$cf,$ce,$cd,$cc,$cb,$ca,$c9,$c8,$c8,$c7,$c6,$c5,$c5
	dc.b	$c4,$c3,$c3,$c2,$c1,$c1,$c0,$c0,$c0,$bf,$bf,$be,$be,$be,$be,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$be,$be,$be,$be
	dc.b	$bf,$bf,$bf,$c0,$c0,$c1,$c1,$c2,$c2,$c3,$c4,$c4,$c5,$c6,$c6,$c7,$c8,$c9,$c9,$ca,$cb,$cc,$cd,$ce,$cf,$d0,$d1,$d2,$d3,$d4,$d5,$d6
	dc.b	$d7,$d8,$da,$db,$dc,$dd,$de,$e0,$e1,$e2,$e3,$e5,$e6,$e7,$e8,$ea,$eb,$ec,$ee,$ef,$f0,$f2,$f3,$f4,$f6,$f7,$f9,$fa,$fb,$fd,$fe,$ff
	dc.b	$01,$02,$04,$05,$06,$08,$09,$0a,$0c,$0d,$0e,$10,$11,$12,$13,$15,$16,$17,$18,$1a,$1b,$1c,$1d,$1e,$20,$21,$22,$23,$24,$25,$26,$27
	dc.b	$28,$29,$2a,$2b,$2c,$2d,$2e,$2f,$30,$30,$31,$32,$33,$33,$34,$35,$36,$36,$37,$37,$38,$38,$39,$3a,$3a,$3a,$3b,$3b,$3c,$3c,$3c,$3d
	dc.b	$3d,$3d,$3d,$3d,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3e,$3d,$3d,$3d,$3d,$3d,$3c,$3c,$3c,$3b,$3b,$3b,$3a,$3a,$39,$39,$38
	dc.b	$38,$37,$37,$36,$35,$35,$34,$33,$33,$32,$31,$30,$2f,$2f,$2e,$2d,$2c,$2b,$2a,$29,$29,$28,$27,$26,$25,$24,$23,$22,$21,$20,$1e,$1d
	dc.b	$1c,$1b,$1a,$19,$18,$17,$16,$15,$13,$12,$11,$10,$0f,$0e,$0c,$0b,$0a,$09,$08,$06,$05,$04,$03,$02,$00,$ff,$fe,$fd,$fc,$fb,$f9,$f8
	dc.b	$f7,$f6,$f5,$f4,$f2,$f1,$f0,$ef,$ee,$ed,$ec,$eb,$ea,$e8,$e7,$e6,$e5,$e4,$e3,$e2,$e1,$e0,$df,$df,$de,$dd,$dc,$db,$da,$d9,$d8,$d8
	dc.b	$d7,$d6,$d5,$d4,$d4,$d3,$d2,$d2,$d1,$d0,$d0,$cf,$cf,$ce,$ce,$cd,$cc,$cc,$cc,$cb,$cb,$ca,$ca,$ca,$c9,$c9,$c9,$c8,$c8,$c8,$c8,$c8
	dc.b	$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c8,$c8,$c8,$c8,$c8,$c8,$c9,$c9,$c9,$ca,$ca,$ca,$cb,$cb,$cc,$cc,$cc,$cd,$cd
	dc.b	$ce,$ce,$cf,$d0,$d0,$d1,$d1,$d2,$d3,$d3,$d4,$d5,$d5,$d6,$d7,$d8,$d8,$d9,$da,$db,$dc,$dd,$dd,$de,$df,$e0,$e1,$e2,$e3,$e4,$e5,$e6
	dc.b	$e6,$e7,$e8,$e9,$ea,$eb,$ec,$ed,$ee,$ef,$f0,$f1,$f2,$f3,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff,$00,$01,$02,$03,$04,$05,$06
	dc.b	$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1a,$1b,$1c,$1d,$1e,$1f,$20,$20,$21,$22,$23,$23
	dc.b	$24,$25,$26,$26,$27,$28,$28,$29,$29,$2a,$2b,$2b,$2c,$2c,$2d,$2d,$2e,$2e,$2f,$2f,$30,$30,$30,$31,$31,$31,$32,$32,$32,$33,$33,$33
	dc.b	$33,$33,$33,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$33,$33,$33,$33,$33,$32,$32,$32,$32,$31,$31,$31,$30
	dc.b	$30,$2f,$2f,$2f,$2e,$2e,$2d,$2d,$2c,$2c,$2b,$2b,$2a,$2a,$29,$28,$28,$27,$26,$26,$25,$24,$24,$23,$22,$22,$21,$20,$1f,$1f,$1e,$1d
	dc.b	$1c,$1b,$1b,$1a,$19,$18,$17,$16,$16,$15,$14,$13,$12,$11,$10,$0f,$0f,$0e,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$05,$04,$04,$03,$02,$01
	dc.b	$00,$ff,$fe,$fd,$fc,$fb,$fa,$f9,$f9,$f8,$f7,$f6,$f5,$f4,$f3,$f2,$f1,$f1,$f0,$ef,$ee,$ed,$ec,$ec,$eb,$ea,$e9,$e8,$e8,$e7,$e6,$e5
	dc.b	$e5,$e4,$e3,$e2,$e2,$e1,$e0,$e0,$df,$de,$de,$dd,$dd,$dc,$db,$db,$da,$da,$d9,$d9,$d8,$d8,$d7,$d7,$d6,$d6,$d6,$d5,$d5,$d5,$d4,$d4
	dc.b	$d4,$d3,$d3,$d3,$d2,$d2,$d2,$d2,$d2,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d0,$d0,$d0,$d0,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d1,$d1
	dc.b	$d2,$d2,$d2,$d2,$d3,$d3,$d3,$d3
smp_snare	dc.b	$1d,$ac,$de,$d7,$3b,$32,$5d,$c8,$09,$c2,$e7,$1f,$c7,$e9,$3f,$2c,$f1,$37,$60,$cb,$60,$4c,$09,$e7,$7b,$07,$d9,$d9,$62,$33,$57,$47
	dc.b	$22,$70,$00,$1e,$4e,$25,$4f,$18,$2d,$b2,$d0,$d9,$b0,$c9,$ae,$cc,$0a,$d7,$d5,$b6,$be,$35,$ff,$f6,$a6,$09,$a2,$c7,$34,$f5,$e5,$fc
	dc.b	$18,$0c,$aa,$88,$bb,$b3,$aa,$2d,$23,$c1,$ff,$d3,$30,$e2,$c2,$c1,$fb,$c9,$04,$3d,$e8,$cc,$56,$04,$bd,$b8,$c6,$23,$42,$04,$c8,$01
	dc.b	$6e,$1f,$6d,$5b,$ca,$46,$40,$28,$fb,$3b,$e1,$19,$1c,$72,$64,$fb,$23,$eb,$67,$5e,$fc,$34,$2d,$de,$44,$1c,$42,$16,$ba,$ef,$b9,$4f
	dc.b	$44,$3a,$df,$b3,$3a,$43,$b0,$f1,$a9,$1a,$19,$ad,$e5,$ef,$be,$21,$d6,$b2,$e7,$05,$ad,$bf,$2f,$f6,$d3,$e1,$a0,$b2,$c5,$ef,$b5,$b5
	dc.b	$9e,$fb,$bb,$2a,$25,$a7,$c4,$0c,$c5,$ba,$3e,$05,$f8,$2d,$33,$d2,$c6,$fd,$ff,$08,$34,$2d,$61,$d5,$08,$ff,$54,$f4,$ec,$16,$13,$fd
	dc.b	$f9,$64,$18,$5a,$29,$da,$6f,$55,$69,$61,$54,$e8,$18,$ec,$08,$d1,$01,$5d,$ec,$3a,$05,$fe,$4e,$51,$0b,$22,$c9,$dc,$41,$03,$fb,$19
	dc.b	$ad,$fb,$ed,$21,$b5,$2e,$a6,$b5,$f2,$fd,$ba,$a8,$1c,$ba,$ef,$f2,$d4,$ed,$e5,$23,$b6,$04,$bd,$d6,$01,$cb,$cf,$11,$ae,$e9,$3c,$3d
	dc.b	$b6,$cd,$d7,$3c,$37,$39,$f0,$d3,$38,$27,$1c,$55,$26,$c9,$42,$f7,$2e,$58,$e4,$e2,$e2,$24,$fc,$2d,$3e,$f3,$32,$fc,$1d,$58,$4f,$e2
	dc.b	$11,$fb,$d3,$40,$2b,$f4,$37,$1a,$07,$c9,$d1,$42,$43,$0e,$34,$0f,$cf,$ca,$e1,$33,$22,$29,$2c,$c9,$cd,$b7,$14,$21,$dd,$fa,$b7,$22
	dc.b	$18,$27,$0f,$19,$a1,$04,$cc,$1f,$0d,$16,$0f,$c5,$0d,$b0,$1b,$1a,$c4,$17,$e8,$d4,$19,$cd,$b3,$cc,$e1,$2c,$3c,$e0,$13,$f5,$45,$0b
	dc.b	$44,$d6,$4c,$e2,$4e,$f2,$de,$0b,$34,$fe,$26,$1a,$0a,$25,$fa,$37,$d9,$55,$21,$39,$3c,$32,$09,$e1,$2f,$02,$fe,$44,$31,$f9,$f9,$04
	dc.b	$01,$f2,$da,$fe,$40,$1c,$38,$10,$e5,$03,$ba,$de,$ee,$00,$08,$ee,$e9,$ca,$ea,$20,$11,$bf,$b3,$ea,$f8,$d1,$0f,$06,$fb,$c2,$bf,$a9
	dc.b	$c5,$e3,$13,$b1,$dd,$fa,$c4,$04,$ec,$ce,$03,$b3,$12,$17,$c5,$ef,$d1,$35,$00,$c8,$e2,$2f,$00,$2d,$1e,$47,$18,$46,$40,$1f,$2d,$14
	dc.b	$3d,$1c,$48,$35,$15,$fb,$fa,$2a,$3a,$1c,$29,$fe,$e6,$fe,$fc,$01,$1b,$ea,$f4,$2b,$2b,$dc,$04,$13,$02,$e7,$ff,$37,$0f,$1b,$2c,$1f
	dc.b	$ef,$c1,$e9,$17,$21,$2b,$ea,$0f,$f6,$fb,$cd,$cc,$e4,$b3,$d7,$fe,$dd,$c1,$e4,$bc,$f6,$b0,$db,$ef,$b1,$f9,$bf,$e6,$b7,$de,$cb,$da
	dc.b	$0e,$e3,$0f,$1a,$d9,$c7,$c1,$ff,$35,$ec,$11,$21,$14,$22,$3a,$e5,$d3,$e3,$e2,$21,$17,$f1,$28,$31,$ee,$21,$31,$eb,$3b,$4b,$eb,$e2
	dc.b	$03,$2c,$4b,$0c,$2f,$e7,$2b,$23,$e7,$31,$39,$1c,$e5,$44,$2c,$fa,$02,$fa,$07,$f3,$2a,$25,$d5,$31,$0c,$1f,$10,$f1,$10,$28,$da,$14
	dc.b	$f5,$ee,$e8,$07,$d4,$12,$0f,$be,$13,$ce,$e6,$f5,$dc,$b7,$0f,$c8,$cc,$0b,$db,$15,$03,$d6,$bb,$20,$c6,$0a,$f3,$11,$0b,$08,$f9,$1b
	dc.b	$d2,$e2,$15,$ee,$0c,$03,$0a,$01,$24,$f9,$22,$f6,$f5,$e8,$f1,$ea,$17,$2f,$f4,$f7,$14,$2d,$47,$18,$ff,$ec,$f6,$f9,$f4,$e2,$17,$fb
	dc.b	$42,$16,$24,$e8,$33,$0b,$31,$11,$05,$00,$e5,$d6,$2f,$fe,$1f,$f3,$d1,$07,$cc,$d4,$fc,$e1,$25,$cc,$0c,$fb,$0c,$d3,$f0,$e8,$e7,$10
	dc.b	$1c,$d8,$f7,$f6,$03,$18,$cf,$d0,$fc,$cb,$ce,$c5,$bf,$ec,$fb,$de,$d9,$09,$0a,$f3,$0b,$24,$18,$09,$0e,$2a,$fa,$07,$13,$2d,$27,$df
	dc.b	$ea,$f9,$24,$14,$fa,$eb,$22,$24,$3c,$12,$12,$eb,$e8,$0d,$03,$fc,$ed,$3f,$33,$1a,$3d,$41,$21,$fb,$e4,$27,$0b,$1b,$32,$ec,$11,$14
	dc.b	$05,$df,$f5,$f3,$11,$21,$ee,$0e,$e7,$23,$15,$fc,$f2,$e4,$e3,$1e,$e9,$f2,$1d,$fe,$f3,$e6,$d1,$e1,$04,$f8,$05,$d2,$f1,$14,$e8,$00
	dc.b	$cc,$1a,$fa,$d9,$d3,$f7,$f8,$d0,$22,$1c,$f5,$d7,$18,$fc,$11,$ff,$ec,$1f,$2d,$ed,$0a,$fc,$2d,$0a,$2c,$2b,$f8,$27,$07,$35,$10,$2c
	dc.b	$fe,$00,$19,$3e,$11,$f4,$16,$05,$17,$16,$0e,$02,$f6,$21,$15,$f7,$25,$e5,$21,$1c,$24,$ff,$15,$22,$2e,$03,$db,$01,$07,$1e,$1d,$f7
	dc.b	$fd,$f6,$0b,$ef,$03,$d8,$f1,$1b,$e5,$02,$fd,$0e,$0d,$0d,$e5,$df,$01,$04,$0e,$c8,$cb,$fa,$12,$19,$05,$ec,$d0,$fe,$12,$f0,$05,$18
	dc.b	$d2,$11,$e8,$f0,$df,$00,$04,$18,$e6,$e0,$22,$0e,$f1,$28,$eb,$06,$f6,$f7,$e4,$25,$2e,$1d,$f3,$0b,$03,$17,$1c,$0b,$fd,$2d,$f9,$07
	dc.b	$0f,$fb,$16,$15,$36,$fe,$33,$19,$fa,$10,$19,$1c,$e4,$0f,$06,$25,$f3,$1a,$0a,$f4,$09,$07,$0a,$0d,$07,$13,$02,$16,$01,$e6,$f0,$fa
	dc.b	$05,$d2,$e2,$04,$d8,$d4,$f3,$14,$f2,$10,$09,$dd,$09,$ef,$08,$04,$e6,$d5,$17,$d9,$18,$11,$08,$1c,$1c,$11,$f1,$12,$d8,$01,$fc,$0e
	dc.b	$0f,$09,$1c,$26,$e9,$f3,$e5,$26,$0e,$2a,$f7,$ec,$25,$2c,$ff,$08,$f4,$30,$01,$0f,$f2,$2c,$f5,$0c,$1b,$20,$2f,$08,$1f,$f3,$06,$ee
	dc.b	$09,$03,$29,$e6,$fd,$01,$25,$1d,$e5,$0f,$03,$22,$f4,$f6,$e6,$e0,$13,$f6,$04,$01,$fd,$d3,$09,$e2,$d9,$f7,$d4,$05,$dd,$dd,$0b,$e5
	dc.b	$d8,$0d,$ce,$0b,$d9,$d8,$e1,$dc,$ff,$d3,$d3,$0a,$e4,$eb,$e1,$da,$0b,$fd,$0d,$fb,$11,$00,$e5,$02,$21,$e4,$18,$1f,$08,$04,$28,$eb
	dc.b	$08,$04,$18,$0b,$28,$f0,$f1,$15,$f0,$ff,$17,$12,$02,$30,$10,$0b,$15,$f2,$1a,$24,$16,$1d,$19,$f7,$06,$f6,$fc,$03,$00,$e9,$ff,$0d
	dc.b	$f9,$e9,$1b,$e2,$13,$e2,$e1,$0a,$0e,$fd,$fe,$fb,$eb,$dd,$ec,$ff,$04,$0c,$02,$11,$f9,$e9,$f7,$e0,$fd,$e1,$d9,$09,$eb,$05,$f9,$08
	dc.b	$0b,$14,$0b,$fe,$01,$da,$15,$0f,$ec,$e8,$0a,$f2,$f5,$e1,$18,$06,$fd,$ed,$0d,$e8,$16,$f5,$03,$ff,$01,$18,$1c,$0f,$f2,$f0,$f7,$14
	dc.b	$18,$ff,$17,$0c,$09,$ff,$1d,$f5,$08,$fe,$16,$0a,$15,$ee,$03,$0e,$e9,$fb,$f4,$ef,$f5,$f9,$e4,$11,$ed,$f8,$0b,$fe,$11,$0f,$e1,$10
	dc.b	$de,$dc,$12,$0d,$fb,$fb,$02,$f0,$de,$d8,$e9,$06,$fb,$07,$0d,$db,$08,$e4,$f9,$f6,$ee,$ea,$ec,$ec,$e3,$f8,$e1,$f9,$11,$f1,$08,$0e
	dc.b	$0f,$ee,$e9,$ed,$06,$10,$0b,$f0,$13,$04,$14,$15,$03,$20,$0c,$10,$10,$1f,$12,$f6,$f2,$08,$00,$ff,$f2,$0c,$01,$09,$f3,$1f,$f3,$20
	dc.b	$1f,$11,$0a,$07,$0c,$19,$1e,$04,$18,$0e,$fb,$03,$f0,$ea,$eb,$17,$f7,$0b,$fe,$eb,$ee,$f8,$f8,$fc,$e7,$f2,$ec,$f3,$ee,$fc,$06,$fe
	dc.b	$dd,$df,$ff,$e9,$01,$fd,$0b,$09,$eb,$f9,$e1,$ed,$0f,$01,$f1,$fc,$0f,$ee,$f2,$09,$0b,$04,$0d,$09,$07,$ff,$07,$fb,$f9,$fa,$f1,$f4
	dc.b	$1c,$04,$f6,$f2,$f0,$19,$f2,$17,$1b,$1e,$f1,$01,$18,$f7,$04,$f9,$1d,$19,$1b,$f9,$08,$06,$14,$fc,$07,$fe,$16,$06,$0a,$fd,$17,$04
	dc.b	$17,$fe,$1b,$1c,$00,$f6,$fb,$02,$17,$0f,$0d,$ea,$ef,$03,$0e,$fd,$e5,$0b,$0a,$ed,$05,$eb,$0b,$e4,$f3,$0c,$e8,$f3,$ee,$dd,$df,$f6
	dc.b	$e8,$0f,$f0,$df,$0c,$08,$ff,$07,$e7,$ef,$0a,$04,$e9,$06,$fa,$e5,$e9,$f3,$10,$03,$0c,$03,$ef,$f9,$fa,$ee,$01,$14,$04,$f4,$1b,$0d
	dc.b	$f1,$0a,$fd,$f8,$06,$0f,$fd,$06,$12,$f6,$21,$f5,$0b,$0a,$21,$0c,$03,$07,$0e,$1e,$fb,$ef,$13,$fe,$10,$0a,$10,$0e,$fa,$eb,$02,$0e
	dc.b	$ef,$0b,$fc,$06,$02,$0a,$e6,$07,$f8,$ef,$e3,$ea,$e2,$0c,$f8,$0e,$f9,$eb,$02,$e8,$f0,$03,$07,$ef,$e5,$f1,$09,$03,$0a,$f3,$0e,$f9
	dc.b	$fa,$0e,$fc,$09,$06,$e9,$02,$0d,$01,$f7,$ed,$08,$f9,$07,$ff,$0c,$fd,$f0,$16,$ff,$1d,$fd,$1d,$1c,$f5,$0e,$03,$16,$11,$1d,$f9,$0e
	dc.b	$16,$f5,$f6,$15,$03,$03,$0b,$0d,$10,$1b,$01,$12,$09,$07,$00,$0b,$f9,$f2,$0d,$02,$fc,$03,$f5,$f5,$fc,$13,$f4,$0f,$fc,$eb,$0a,$f8
	dc.b	$0b,$f7,$e7,$00,$07,$f0,$f1,$e5,$f9,$08,$06,$00,$09,$fd,$04,$f8,$e7,$eb,$e9,$05,$e5,$fb,$f4,$07,$fd,$00,$ea,$f4,$12,$07,$ff,$0a
	dc.b	$0d,$ee,$14,$07,$00,$0a,$fd,$13,$10,$0a,$f8,$19,$03,$17,$f5,$f8,$f9,$fa,$01,$11,$02,$1b,$19,$17,$fe,$0e,$0a,$f9,$00,$09,$08,$fa
	dc.b	$19,$f8,$0c,$0e,$09,$12,$07,$11,$f0,$f0,$07,$04,$07,$0b,$fc,$04,$fe,$03,$f5,$0f,$fb,$07,$02,$f2,$e9,$e8,$f7,$f8,$ed,$fd,$f1,$01
	dc.b	$01,$06,$0a,$e9,$f3,$fa,$f1,$f7,$ef,$ef,$e9,$f1,$f5,$fe,$f1,$09,$ee,$f5,$ff,$f6,$08,$fe,$ff,$ff,$f8,$ee,$12,$02,$14,$f8,$fe,$f3
	dc.b	$04,$13,$0b,$04,$07,$13,$04,$15,$10,$11,$03,$04,$0a,$fc,$0a,$f8,$08,$12,$ff,$1a,$0e,$f9,$18,$02,$11,$00,$15,$0e,$f9,$04,$03,$f2
	dc.b	$f5,$fc,$00,$ff,$04,$00,$f9,$03,$f1,$0f,$06,$f5,$f6,$07,$fc,$02,$f3,$05,$f5,$00,$0a,$fc,$03,$01,$ff,$e7,$f7,$09,$03,$03,$fc,$01
	dc.b	$fc,$ee,$fe,$fe,$07,$ee,$02,$eb,$0c,$ef,$ec,$f7,$f2,$05,$fc,$09,$0f,$0e,$0a,$f2,$f6,$f8,$fd,$09,$05,$fe,$fa,$14,$00,$01,$10,$0e
	dc.b	$0c,$0e,$0b,$fd,$fe,$09,$fe,$18,$00,$00,$fd,$0e,$00,$01,$15,$10,$fd,$f8,$0a,$00,$14,$0e,$12,$0d,$fb,$fa,$08,$fb,$fe,$f7,$fe,$f4
	dc.b	$ff,$0c,$03,$f0,$00,$fe,$f2,$00,$fb,$ff,$eb,$f7,$01,$ec,$02,$e9,$fb,$07,$f6,$07,$06,$f9,$f0,$09,$f4,$ff,$08,$ed,$fe,$fd,$03,$0b
	dc.b	$0a,$f3,$0a,$f4,$0c,$0f,$fc,$00,$0f,$10,$0f,$0e,$f3,$05,$f7,$13,$fd,$14,$06,$05,$14,$11,$05,$fc,$fa,$fc,$05,$ff,$fd,$0e,$10,$09
	dc.b	$0f,$fc,$11,$13,$10,$06,$f8,$0a,$fb,$f9,$fe,$fc,$fb,$fa,$0a,$10,$fb,$08,$f1,$05,$05,$f1,$f3,$f8,$fb,$fd,$09,$03,$f6,$f0,$08,$f5
	dc.b	$fe,$f2,$ef,$ef,$01,$fd,$f7,$fb,$f9,$fb,$ff,$f1,$f2,$02,$05,$ee,$f9,$01,$ee,$fd,$ef,$fe,$fd,$ff,$f3,$f9,$ff,$f3,$f6,$02,$f4,$01
	dc.b	$0a,$00,$02,$01,$f5,$02,$0c,$0a,$01,$0e,$0c,$07,$f8,$01,$f9,$14,$13,$f9,$13,$f8,$03,$0e,$0e,$14,$0a,$03,$14,$02,$10,$11,$01,$0a
	dc.b	$09,$05,$08,$fe,$f9,$03,$02,$08,$f9,$f2,$f2,$fa,$04,$00,$ff,$07,$f6,$f9,$f6,$09,$02,$f1,$04,$f9,$02,$06,$ed,$f2,$ef,$ed,$fd,$00
	dc.b	$ed,$01,$f7,$f3,$f3,$05,$ee,$fb,$f5,$04,$02,$f7,$ff,$01,$f8,$f8,$f4,$03,$f7,$fa,$f3,$0c,$0b,$0c,$05,$00,$02,$0f,$0f,$08,$0b,$ff
	dc.b	$02,$fb,$01,$0c,$04,$0f,$00,$0b,$0e,$11,$07,$12,$07,$fc,$ff,$fd,$09,$10,$0e,$fa,$0a,$fc,$fe,$08,$06,$0d,$fa,$09,$08,$03,$01,$0b
	dc.b	$fc,$0c,$f3,$0b,$0b,$f4,$0b,$fd,$f7,$00,$f5,$07,$fd,$03,$f8,$fc,$f8,$f5,$fb,$fb,$f0,$07,$fa,$03,$05,$f7,$f9,$fc,$f4,$f2,$f5,$07
	dc.b	$fe,$fa,$f3,$f8,$fa,$06,$fe,$02,$03,$f9,$07,$0b,$03,$00,$f8,$08,$f9,$07,$02,$0d,$04,$07,$f8,$f8,$0c,$0f,$08,$0b,$03,$0d,$fe,$0a
	dc.b	$f9,$05,$02,$08,$09,$08,$05,$05,$f9,$06,$f8,$05,$fe,$0f,$f8,$0b,$07,$0a,$0c,$f8,$f8,$f9,$f9,$01,$08,$fa,$fd,$fc,$fc,$00,$0a,$f7
	dc.b	$02,$05,$00,$05,$02,$f2,$f9,$fd,$f1,$f0,$f3,$fb,$f9,$02,$fd,$03,$f2,$fc,$f0,$f5,$04,$05,$fb,$f1,$f2,$06,$06,$ff,$f2,$08,$fa,$09
	dc.b	$01,$05,$04,$fd,$f6,$f9,$fb,$09,$ff,$0b,$fe,$08,$fa,$0e,$08,$03,$0f,$fa,$03,$0c,$01,$0b,$0f,$02,$0b,$fa,$00,$10,$04,$01,$0e,$03
	dc.b	$08,$08,$fb,$06,$0a,$08,$fa,$fb,$07,$05,$07,$fd,$f8,$f6,$fc,$fd,$fb,$f7,$f8,$fe,$00,$fc,$f3,$fa,$f4,$ff,$f9,$fa,$f8,$fa,$f3,$05
	dc.b	$05,$06,$fd,$f4,$f9,$f4,$f7,$fb,$f2,$fa,$fa,$fb,$f3,$f7,$f7,$ff,$ff,$f6,$f5,$f9,$07,$fa,$01,$05,$fb,$fc,$06,$08,$0a,$f9,$fd,$0b
	dc.b	$fb,$fe,$0c,$0c,$fe,$07,$03,$05,$fe,$01,$0b,$02,$fc,$06,$06,$05,$08,$05,$0e,$04,$09,$03,$00,$08,$0a,$0a,$02,$03,$06,$fd,$06,$07
	dc.b	$08,$f9,$0b,$01,$ff,$01,$09,$04,$00,$05,$fc,$07,$ff,$01,$f5,$03,$01,$fa,$00,$f4,$06,$00,$fa,$01,$05,$fb,$f2,$f7,$fc,$fc,$fd,$fd
	dc.b	$fb,$fa,$02,$fe,$fc,$fa,$f3,$f5,$fc,$07,$f6,$07,$f7,$fb,$fe,$f9,$ff,$ff,$ff,$04,$fd,$fd,$07,$fa,$08,$05,$06,$fc,$0c,$fe,$fd,$fd
	dc.b	$05,$0c,$ff,$02,$fe,$07,$03,$fb,$06,$fe,$06,$02,$08,$fe,$08,$09,$fb,$fc,$0a,$fd,$ff,$02,$fe,$09,$02,$04,$03,$03,$02,$fd,$06,$02
smp_hat	dc.b	$2c,$f1,$c7,$2c,$b7,$07,$fe,$1a,$ef,$45,$e7,$f4,$da,$21,$e6,$3c,$08,$fa,$2f,$c6,$f8,$d3,$17,$12,$cd,$27,$d3,$10,$56,$13,$c6,$ff
	dc.b	$18,$df,$35,$d5,$ce,$fa,$59,$c7,$fe,$20,$d4,$23,$22,$03,$e6,$cc,$00,$4d,$06,$cb,$35,$a6,$4e,$ec,$33,$9b,$53,$f7,$cd,$4f,$c3,$f5
	dc.b	$34,$d6,$3d,$e8,$c5,$3f,$e8,$e6,$27,$f8,$ce,$fd,$07,$00,$f0,$1f,$f9,$1b,$ea,$27,$d5,$fe,$3d,$0d,$e1,$c5,$58,$ee,$0d,$07,$f4,$b7
	dc.b	$49,$c3,$2d,$0b,$f9,$f8,$ee,$08,$e2,$0e,$04,$11,$17,$b6,$28,$ea,$3d,$cb,$36,$c6,$e2,$47,$fc,$00,$e7,$13,$e4,$e6,$2a,$e4,$13,$ed
	dc.b	$05,$31,$d5,$15,$ff,$f9,$f4,$1d,$ca,$04,$3a,$e5,$e4,$3e,$dd,$db,$50,$c1,$28,$d2,$2a,$d8,$3f,$cb,$1f,$df,$0a,$2a,$c5,$12,$f9,$1f
	dc.b	$db,$21,$04,$c9,$25,$e5,$07,$23,$cd,$34,$09,$0d,$d5,$ea,$fb,$17,$1a,$d2,$10,$2a,$ca,$2e,$ff,$d3,$3e,$c3,$1c,$db,$2d,$f1,$14,$f9
	dc.b	$df,$12,$13,$0c,$cb,$01,$2d,$f5,$f2,$27,$d4,$f4,$09,$f3,$1f,$03,$01,$0b,$fa,$0a,$f4,$e9,$0e,$ff,$0f,$e3,$f1,$35,$04,$e3,$e8,$18
	dc.b	$06,$fc,$1c,$01,$fd,$cf,$2c,$ee,$f4,$13,$05,$0b,$f5,$d3,$03,$0b,$f3,$01,$2a,$f0,$07,$f9,$fb,$10,$dd,$1a,$05,$ed,$02,$0b,$ef,$22
	dc.b	$f1,$f8,$0d,$0b,$f8,$df,$22,$02,$06,$d6,$02,$13,$01,$08,$f0,$17,$00,$e0,$1f,$00,$e4,$29,$ea,$0d,$fd,$e4,$fe,$21,$e6,$1f,$fa,$db
	dc.b	$26,$e6,$f6,$20,$f9,$e8,$12,$fb,$07,$03,$f7,$fb,$f9,$16,$07,$e9,$0d,$ea,$26,$e4,$0a,$fc,$f5,$23,$fd,$f2,$10,$f8,$f2,$fc,$04,$0d
	dc.b	$ec,$f8,$0d,$06,$11,$e1,$1b,$08,$ff,$da,$11,$f8,$18,$ea,$09,$e9,$08,$0f,$f5,$0d,$fa,$05,$fc,$0b,$e9,$1c,$fa,$eb,$f7,$10,$f9,$04
	dc.b	$13,$01,$03,$db,$19,$07,$fb,$e8,$10,$f5,$0a,$f0,$23,$f5,$e9,$1f,$ff,$f2,$07,$f4,$16,$e0,$00,$01,$19,$e5,$12,$fb,$13,$e6,$01,$02
	dc.b	$11,$fd,$01,$f2,$fe,$f9,$04,$14,$f9,$f2,$00,$0a,$fe,$04,$0e,$e7,$03,$ff,$fb,$01,$11,$05,$fc,$eb,$19,$f0,$f8,$05,$03,$05,$05,$f3
	dc.b	$17,$e2,$0c,$01,$09,$f1,$06,$0a,$ec,$fc,$19,$05,$e7,$15,$f3,$08,$00,$fe,$f7,$10,$e9,$01,$18,$f3,$f7,$16,$fe,$f2,$f8,$0c,$f8,$0b
	dc.b	$07,$f4,$f6,$12,$f2,$01,$ff,$02,$10,$e9,$10,$f6,$01,$03,$04,$f3,$06,$fc,$02,$12,$f7,$03,$04,$00,$05,$fb,$f5,$05,$ff,$0b,$f6,$fd
	dc.b	$fb,$03,$fe,$10,$fd,$ef,$16,$f5,$06,$06,$ff,$eb,$0d,$f7,$0d,$02,$ec,$16,$ee,$0e,$ff,$f6,$0b,$00,$f1,$09,$05,$fe,$05,$ec,$0f,$05
	dc.b	$f8,$00,$f8,$11,$fe,$f8,$fc,$04,$f7,$03,$00,$06,$f5,$13,$f1,$ff,$0c,$04,$fe,$f5,$fa,$0b,$07,$fd,$01,$00,$02,$f4,$0b,$f5,$fa,$04
	dc.b	$fd,$00,$0f,$fd,$03,$fa,$f7,$0f,$fb,$04,$fd,$f5,$07,$f8,$02,$07,$f6,$0b,$04,$00,$f6,$0b,$ff,$ef,$0a,$06,$01,$f3,$06,$07,$f2,$0b
	dc.b	$f7,$0d,$f2,$0c,$f2,$0b,$ff,$04,$f9,$fd,$00,$fd,$03,$fe,$fe,$06,$06,$04,$ff,$fa,$fe,$03,$f9,$06
smp_noise	dc.b	$50,$21,$29,$b6,$a2,$4c,$d3,$d8,$63,$a2,$b7,$e5,$33,$0a,$58,$a6,$15,$19,$fc,$99,$61,$b6,$56,$b5,$a8,$bf,$bc,$2b,$31,$33,$cc,$d0
	dc.b	$c6,$9d,$10,$4b,$b4,$e1,$f0,$d3,$24,$16,$be,$98,$b8,$d2,$a4,$4c,$d6,$e9,$fe,$23,$a6,$0a,$bb,$55,$e3,$f4,$cc,$f8,$c4,$cd,$a0,$37
	dc.b	$25,$a5,$de,$09,$68,$14,$0c,$4b,$46,$ee,$08,$51,$fa,$54,$fb,$a3,$59,$2f,$00,$58,$42,$27,$1a,$ac,$39,$b8,$6b,$68,$44,$ae,$ef,$6b
	dc.b	$f2,$6d,$1c,$4a,$cb,$5a,$5b,$a1,$e7,$e9,$da,$cf,$f7,$52,$3f,$1b,$05,$ee,$ed,$b3,$13,$39,$61,$5d,$0e,$a8,$d1,$08,$de,$ec,$e6,$fd
	dc.b	$18,$9a,$cf,$b2,$18,$2b,$9b,$56,$db,$c6,$36,$5d,$57,$96,$46,$d5,$d0,$fe,$2b,$a8,$51,$b0,$68,$f3,$48,$cd,$ee,$20,$bb,$c1,$47,$35
	dc.b	$39,$51,$47,$03,$b5,$d6,$01,$b0,$4d,$53,$98,$bc,$49,$4a,$c9,$f6,$5c,$2d,$ce,$47,$01,$1e,$ad,$99,$e4,$15,$b9,$52,$13,$df,$b6,$57
	dc.b	$37,$2a,$d1,$e7,$b6,$10,$66,$4f,$20,$27,$cd,$ec,$96,$3e,$3b,$94,$5b,$20,$16,$94,$ca,$43,$d5,$67,$1f,$ef,$e5,$df,$c9,$f9,$27,$47
	dc.b	$e9,$a9,$03,$24,$4c,$e4,$20,$18,$d4,$aa,$a0,$6b,$1f,$50,$cb,$2e,$56,$d4,$b3,$3a,$58,$43,$43,$16,$23,$28,$31,$22,$6d,$cb,$ee,$e7
	dc.b	$9a,$2e,$10,$bc,$32,$c3,$08,$3f,$59,$26,$02,$4c,$4b,$53,$ba,$a7,$ae,$cb,$44,$3a,$ba,$28,$dc,$a6,$e0,$36,$d6,$3f,$db,$cb,$d3,$4d
	dc.b	$fa,$51,$12,$62,$a2,$56,$00,$51,$e6,$d4,$9e,$4e,$b0,$be,$ec,$0f,$59,$f7,$d8,$2f,$3d,$fd,$1d,$b9,$1e,$93,$ce,$39,$b7,$3a,$fe,$3a
	dc.b	$a5,$19,$1d,$eb,$66,$e6,$9a,$be,$e4,$95,$d9,$49,$bc,$27,$1c,$c9,$2b,$de,$ae,$e6,$14,$b7,$47,$d4,$d2,$32,$15,$dc,$55,$6d,$dd,$58
	dc.b	$e1,$bb,$63,$5c,$eb,$c4,$32,$af,$33,$14,$b7,$e3,$21,$9a,$53,$ca,$08,$9d,$6d,$24,$22,$96,$2a,$ee,$e6,$0a,$fa,$b4,$2b,$1d,$d4,$24
	dc.b	$24,$cd,$17,$b0,$49,$a9,$30,$ac,$ab,$a9,$be,$be,$cc,$05,$be,$2d,$d3,$9b,$ff,$c0,$5f,$db,$93,$26,$5a,$4a,$25,$b3,$a6,$03,$31,$a8
	dc.b	$ca,$c5,$6c,$d3,$f8,$a8,$b8,$9b,$d2,$42,$d7,$34,$a7,$39,$9c,$4d,$24,$b8,$e1,$f2,$1b,$53,$a6,$45,$ba,$ea,$66,$ce,$e7,$4d,$42,$21
	dc.b	$41,$ab,$2b,$9f,$61,$b5,$ee,$14,$42,$27,$ba,$e6,$e1,$98,$29,$4a,$68,$af,$5c,$ab,$ec,$9c,$cc,$d7,$2d,$27,$3b,$11,$0e,$69,$25,$dc
	dc.b	$05,$2c,$a7,$24,$c9,$de,$27,$e7,$4b,$0d,$6b,$9e,$20,$b5,$4d,$4d,$51,$a2,$fe,$c7,$67,$9d,$c3,$20,$eb,$c6,$f7,$42,$f5,$4e,$f4,$ac
	dc.b	$ff,$22,$a9,$ed,$0d,$92,$a6,$17,$1a,$d5,$02,$c0,$26,$63,$e2,$9e,$c3,$f6,$0d,$1a,$fa,$23,$30,$ab,$39,$c3,$dd,$49,$66,$d2,$05,$2c
	dc.b	$9c,$b6,$b1,$30,$31,$aa,$18,$bb,$5f,$e8,$f7,$3e,$30,$aa,$ed,$5e,$4a,$14,$3c,$f5,$23,$64,$b0,$00,$07,$9d,$60,$4b,$fc,$02,$5d,$b9
	dc.b	$11,$33,$ae,$e7,$16,$54,$01,$e7,$69,$5c,$3a,$ce,$66,$68,$f6,$af,$ed,$2c,$37,$d4,$2c,$4f,$2f,$60,$1d,$be,$1b,$d2,$de,$26,$6a,$21
	dc.b	$65,$01,$2b,$d9,$ab,$df,$fc,$10,$25,$ee,$37,$4b,$d1,$4c,$44,$05,$98,$b2,$25,$be,$37,$b5,$d1,$c9,$4b,$2a,$d3,$38,$99,$45,$a9,$51
	dc.b	$35,$50,$35,$0d,$c6,$3f,$42,$d1,$24,$5e,$e7,$64,$69,$d7,$0b,$95,$c9,$1b,$3e,$51,$49,$5b,$2d,$20,$38,$0a,$17,$3d,$66,$d3,$b9,$28
	dc.b	$bb,$b8,$03,$e5,$f0,$0c,$af,$12,$ca,$db,$2e,$b4,$b4,$d9,$9d,$5f,$19,$24,$fe,$10,$e1,$3e,$d8,$c2,$ba,$a1,$01,$ee,$08,$a6,$c3,$c1
	dc.b	$db,$e1,$c2,$38,$07,$6d,$47,$6a,$94,$25,$f4,$59,$19,$1b,$65,$28,$d9,$5c,$62,$e7,$09,$d0,$5a,$47,$e4,$43,$f4,$9c,$58,$bc,$03,$63
	dc.b	$b7,$64,$08,$94,$a0,$25,$3c,$50,$ef,$a9,$08,$2d,$69,$3d,$20,$61,$36,$b4,$f7,$db,$a5,$9e,$41,$0d,$10,$c4,$cb,$e7,$1d,$f1,$96,$26
	dc.b	$08,$1f,$1a,$38,$13,$2c,$a2,$5e,$a9,$3f,$d4,$a5,$3a,$f2,$e9,$23,$fa,$07,$b0,$e8,$41,$0a,$65,$b2,$27,$5b,$41,$32,$e4,$63,$0c,$0c
	dc.b	$ad,$93,$15,$08,$62,$d5,$37,$59,$de,$ed,$20,$03,$b5,$c3,$4a,$bd,$ba,$42,$4d,$4d,$5f,$6d,$f7,$0b,$d2,$a1,$a8,$32,$fd,$db,$ae,$22
	dc.b	$a8,$1a,$58,$d8,$f5,$1a,$d5,$13,$0e,$e2,$d8,$f0,$93,$c8,$c3,$35,$f2,$4b,$b0,$33,$53,$f8,$e1,$d5,$0b,$b9,$17,$4b,$4f,$b1,$08,$cc
	dc.b	$55,$a3,$a3,$96,$02,$99,$12,$eb,$14,$59,$0b,$0a,$6e,$fa,$3d,$e2,$c3,$3c,$33,$d2,$f8,$02,$e9,$00,$24,$4d,$43,$19,$b6,$03,$f4,$b9
	dc.b	$63,$23,$67,$34,$fc,$e1,$c2,$fd,$a0,$e3,$9b,$bf,$5a,$e1,$f9,$f6,$9c,$6a,$d9,$2d,$05,$49,$4a,$cc,$0a,$b8,$22,$e2,$22,$4a,$04,$e5
	dc.b	$5a,$04,$e0,$51,$fd,$fc,$17,$00,$b1,$b6,$a3,$20,$c1,$bb,$e2,$30,$ac,$c5,$44,$30,$fc,$fb,$c0,$b5,$49,$97,$9b,$10,$b5,$1c,$9b,$10
	dc.b	$9e,$cb,$ba,$65,$16,$0e,$96,$30,$24,$d0,$a5,$f5,$6c,$51,$b8,$49,$16,$41,$46,$ba,$23,$cc,$31,$dd,$f6,$14,$c5,$e7,$aa,$bf,$4f,$01
	dc.b	$ee,$b3,$a7,$fb,$19,$9b,$3e,$01,$ac,$fc,$af,$17,$48,$57,$3c,$21,$05,$e3,$9c,$07,$c4,$43,$40,$e6,$14,$35,$3a,$2b,$a7,$af,$fb,$c5
	dc.b	$4f,$d0,$53,$ec,$bc,$2e,$40,$11,$ac,$94,$22,$29,$d7,$e2,$b4,$21,$ca,$4e,$ef,$e2,$cf,$28,$38,$ed,$3e,$fc,$e3,$0c,$ca,$d5,$de,$2d
	dc.b	$34,$4e,$23,$37,$f4,$2c,$b6,$c1,$ea,$dc,$0b,$2b,$2d,$b5,$66,$93,$a6,$b2,$5e,$f2,$a0,$c3,$a4,$9a,$e7,$6b,$19,$05,$2f,$15,$62,$46
	dc.b	$1f,$f3,$be,$23,$43,$d1,$99,$16,$03,$c5,$b7,$9a,$c7,$92,$b5,$6d,$3e,$e0,$e9,$13,$04,$34,$a1,$a6,$d1,$49,$5b,$df,$66,$cf,$17,$bd
	dc.b	$5f,$10,$cb,$ec,$a9,$a2,$d3,$62,$43,$64,$53,$45,$10,$2b,$67,$0e,$3b,$39,$65,$f7,$f7,$13,$98,$ac,$a1,$1d,$6d,$27,$c5,$d7,$64,$04
	dc.b	$94,$49,$c9,$a6,$26,$47,$a3,$5f,$fb,$e0,$57,$cd,$62,$28,$5a,$00,$be,$34,$52,$bf,$bf,$c9,$1a,$b4,$a9,$5c,$27,$24,$19,$3a,$09,$9b
	dc.b	$fc,$1b,$fe,$6b,$57,$51,$fe,$6b,$5c,$d0,$c3,$11,$9e,$42,$fb,$09,$01,$e9,$29,$b8,$69,$2c,$f7,$2a,$95,$c0,$12,$da,$19,$cb,$0b,$c6
	dc.b	$fa,$19,$e3,$00,$c0,$2c,$e4,$4e,$d0,$ba,$af,$11,$c4,$a8,$cd,$c6,$f1,$e6,$b2,$65,$b3,$43,$b9,$00,$6d,$4d,$04,$31,$3f,$d4,$0e,$0f
	dc.b	$ea,$2a,$9f,$45,$fb,$1d,$f5,$dc,$e1,$0d,$5f,$cb,$96,$ad,$51,$66,$be,$11,$21,$b8,$3e,$e0,$26,$fd,$34,$56,$e6,$d1,$1d,$b2,$b7,$44
	dc.b	$dc,$1d,$10,$4d,$a2,$b6,$c4,$d8,$d2,$cd,$20,$ce,$f4,$50,$e2,$13,$66,$ed,$ba,$97,$32,$24,$61,$2c,$a4,$b7,$a9,$a0,$53,$0b,$98,$e9
	dc.b	$3a,$a4,$cc,$b4,$22,$55,$d6,$c8,$d1,$1c,$af,$4a,$98,$24,$4f,$da,$fb,$68,$09,$ce,$f4,$67,$2b,$b9,$15,$1d,$1e,$0e,$05,$1f,$d6,$de
	dc.b	$09,$43,$f3,$e2,$cb,$d5,$92,$45,$4d,$de,$f9,$94,$5d,$62,$fb,$94,$f1,$d2,$c5,$94,$e4,$ed,$0d,$e9,$b6,$34,$e8,$e5,$cc,$ef,$c7,$3a
	dc.b	$5a,$44,$29,$d1,$35,$44,$ed,$4e,$ba,$d2,$1e,$1a,$ce,$1b,$bb,$96,$9d,$08,$bb,$a9,$cd,$2f,$32,$c5,$b3,$ff,$dd,$d7,$42,$6e,$f8,$40
	dc.b	$db,$4c,$63,$9e,$3d,$a2,$f9,$bc,$4b,$46,$48,$ad,$3b,$c9,$3c,$f3,$34,$99,$f7,$3c,$05,$6a,$fa,$28,$d7,$d9,$1c,$9b,$60,$05,$ca,$1e
	dc.b	$be,$55,$50,$c2,$ab,$1d,$d9,$b7,$cf,$ac,$40,$94,$9b,$3e,$fb,$15,$e4,$a6,$b5,$a6,$1a,$5f,$6d,$1c,$9f,$20,$2c,$40,$ae,$c5,$6a,$3f
	dc.b	$38,$43,$f3,$bc,$2a,$e1,$b0,$58,$fd,$f2,$d3,$2b,$bc,$bb,$de,$33,$cf,$49,$5b,$0c,$a1,$b4,$d3,$cc,$e3,$92,$1e,$e5,$bb,$96,$4f,$3d
	dc.b	$c7,$31,$23,$09,$e7,$05,$ff,$0b,$19,$d9,$1f,$aa,$05,$a1,$4a,$af,$52,$be,$fd,$a8,$10,$4a,$23,$06,$2c,$ca,$e3,$17,$a2,$5f,$c0,$fe
	dc.b	$56,$a4,$42,$9f,$0d,$60,$ee,$e3,$2e,$47,$cc,$9b,$a1,$d5,$62,$65,$a7,$32,$07,$bc,$06,$c9,$1c,$b9,$37,$ed,$a9,$1e,$e1,$f7,$24,$54
	dc.b	$b7,$ba,$ea,$dc,$b5,$6e,$f3,$e0,$d7,$6c,$d9,$e4,$3a,$f1,$32,$18,$0e,$c1,$3a,$5e,$ca,$66,$f4,$e9,$32,$6a,$15,$04,$6d,$d4,$d4,$c3
	dc.b	$4e,$97,$47,$2a,$cf,$0c,$0c,$5e,$b4,$9a,$e0,$b0,$e3,$12,$c5,$44,$a6,$ea,$5c,$34,$31,$40,$b8,$48,$2a,$11,$5a,$15,$d4,$33,$11,$a3
	dc.b	$9e,$3c,$df,$46,$ee,$51,$51,$c4,$22,$17,$95,$3d,$e6,$d5,$9b,$09,$b3,$01,$c3,$9d,$33,$e8,$f4,$15,$01,$c3,$d2,$e9,$af,$a4,$10,$9d
	dc.b	$ea,$a5,$00,$3c,$af,$b0,$0d,$fd,$21,$bd,$1a,$34,$c8,$a2,$3d,$d9,$5d,$a6,$26,$ef,$df,$d9,$15,$97,$d5,$6b,$1a,$6c,$f3,$b2,$9c,$46
	dc.b	$be,$e4,$39,$4e,$ab,$9e,$63,$5e,$51,$46,$95,$2b,$aa,$f5,$97,$c0,$08,$bf,$05,$cb,$fc,$33,$b1,$2c,$96,$12,$24,$9c,$b7,$d0,$40,$1a
	dc.b	$9e,$22,$94,$e8,$ce,$4d,$23,$50,$96,$51,$21,$c5,$e6,$69,$a8,$d7,$51,$07,$bb,$00,$f7,$5e,$97,$c8,$06,$db,$e9,$b5,$de,$df,$1c,$c6
	dc.b	$69,$00,$45,$1c,$53,$56,$45,$98,$0c,$d0,$b3,$57,$23,$a5,$e6,$65,$19,$1c,$c4,$c7,$b4,$68,$5a,$da,$09,$bf,$b0,$09,$42,$50,$d6,$2d
	dc.b	$05,$b0,$6d,$69,$b2,$5f,$5c,$d8,$0d,$63,$ac,$d8,$54,$32,$3a,$54,$ed,$ec,$f3,$5f,$57,$5f,$ce,$3d,$a9,$bb,$3a,$19,$cd,$0f,$c5,$c5
	dc.b	$29,$e1,$29,$fb,$01,$17,$2f,$e4,$4d,$fe,$b0,$bd,$99,$3a,$95,$cd,$ed,$35,$6b,$39,$a1,$5e,$6b,$51,$fe,$d9,$f7,$c8,$eb,$9b,$34,$e6
	dc.b	$d7,$19,$35,$15,$06,$53,$3f,$05,$f5,$48,$9b,$6d,$04,$e9,$34,$0d,$04,$1d,$9d,$d2,$ea,$d5,$48,$f7,$ef,$19,$9e,$04,$b1,$49,$f5,$31
	dc.b	$ab,$3d,$60,$2b,$b0,$ed,$f5,$b9,$14,$2f,$be,$f6,$c9,$2a,$5a,$41,$30,$ad,$ab,$f5,$e2,$05,$e6,$40,$03,$63,$e5,$e6,$3b,$5b,$0e,$23
	dc.b	$b3,$51,$b9,$2f,$ee,$d6,$3b,$f4,$1c,$ac,$af,$bf,$1b,$ca,$f7,$4e,$0a,$93,$54,$c6,$14,$fb,$ec,$a3,$16,$c8,$0a,$1a,$0d,$48,$9d,$b3
	dc.b	$22,$9a,$4e,$25,$4a,$d4,$5c,$9d,$ee,$b9,$26,$18,$2a,$15,$3f,$b9,$f6,$11,$5f,$a6,$d4,$e3,$e5,$a1,$f0,$0b,$d2,$b0,$2b,$ce,$06,$05
	dc.b	$2b,$19,$aa,$33,$1c,$6b,$fc,$2a,$5f,$6b,$d1,$18,$d8,$06,$6d,$e0,$af,$0e,$04,$1d,$fe,$ba,$18,$2e,$69,$92,$97,$1c,$ac,$4d,$42,$6e
	dc.b	$ed,$db,$0d,$1e,$94,$be,$d0,$40,$d6,$01,$d9,$93,$29,$dd,$31,$1a,$98,$b9,$db,$dc,$26,$5c,$41,$20,$fc,$1c,$56,$08,$dc,$3e,$ed,$35
smp_null	dc.b	$00,$00,$00,$00
	section	musdata,data
InstTable:	; sample, words, loop, loopwords, vol, decay, floor, pad
	dc.l	smp_null
	dc.w	2
	dc.l	smp_null
	dc.w	2,0,0,0,0
	dc.l	smp_bass64
	dc.w	32
	dc.l	smp_bass64
	dc.w	32,52,1,34,0
	dc.l	smp_lead32
	dc.w	16
	dc.l	smp_lead32
	dc.w	16,40,0,40,0
	dc.l	smp_kick
	dc.w	900
	dc.l	smp_null
	dc.w	2,64,0,64,0
	dc.l	smp_snare
	dc.w	1200
	dc.l	smp_null
	dc.w	2,50,0,50,0
	dc.l	smp_hat
	dc.w	300
	dc.l	smp_null
	dc.w	2,28,0,28,0
	dc.l	smp_tri32
	dc.w	16
	dc.l	smp_tri32
	dc.w	16,30,1,14,0
	dc.l	smp_sine32
	dc.w	16
	dc.l	smp_sine32
	dc.w	16,48,3,0,0
PeriodTable:	dc.w	0,856,808,762,720,678,640,604,570,538,508,480,453,428,404,381,360,339,320,302,285,269,254,240,226,214,202,190,180,170,160,151,143,135,127,120,113
Patterns:
	dc.b	5,1,0,0,25,3,0,0,0,0,0,0,17,1,0,0,0,0,0,0,0,0,0,0
	dc.b	5,1,0,0,0,0,0,0,0,0,0,0,15,1,0,0,25,5,17,1,0,0,0,0
	dc.b	0,0,0,0,25,3,5,1,0,0,0,0,8,1,0,0,0,0,0,0,0,0,0,0
	dc.b	10,1,0,0,0,0,0,0,0,0,0,0,12,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,0,0,25,3,0,0,0,0,0,0,13,1,0,0,0,0,0,0,0,0,0,0
	dc.b	1,1,0,0,0,0,0,0,0,0,0,0,12,1,0,0,25,5,13,1,0,0,0,0
	dc.b	0,0,0,0,25,3,1,1,0,0,0,0,5,1,0,0,0,0,0,0,0,0,0,0
	dc.b	8,1,0,0,0,0,0,0,0,0,0,0,10,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,0,0,25,3,0,0,0,0,0,0,22,1,0,0,0,0,0,0,0,0,0,0
	dc.b	10,1,0,0,0,0,0,0,0,0,0,0,8,1,0,0,25,5,10,1,0,0,0,0
	dc.b	0,0,0,0,25,3,10,1,0,0,0,0,13,1,0,0,0,0,0,0,0,0,0,0
	dc.b	15,1,0,0,0,0,0,0,0,0,0,0,17,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,0,0,25,3,0,0,0,0,0,0,24,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,0,0,25,4,0,0,0,0,0,0,10,1,0,0,25,5,12,1,0,0,25,3
	dc.b	0,0,0,0,25,3,16,1,0,0,0,0,0,0,0,0,25,5,7,1,0,0,0,0
	dc.b	0,0,0,0,25,4,10,1,0,0,0,0,12,1,0,0,25,5,0,0,0,0,0,0
	dc.b	5,1,29,2,25,3,0,0,0,0,0,0,17,1,0,0,25,5,0,0,0,0,0,0
	dc.b	5,1,32,2,25,4,0,0,0,0,0,0,15,1,31,2,25,5,17,1,0,0,25,3
	dc.b	0,0,29,2,25,3,5,1,0,0,0,0,8,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,24,2,25,4,0,0,0,0,0,0,12,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,25,2,25,3,0,0,0,0,0,0,13,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,29,2,25,4,0,0,0,0,0,0,12,1,27,2,25,5,13,1,0,0,25,3
	dc.b	0,0,25,2,25,3,1,1,0,0,0,0,5,1,24,2,25,5,0,0,0,0,0,0
	dc.b	8,1,20,2,25,4,0,0,0,0,0,0,10,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,22,2,25,3,0,0,0,0,0,0,22,1,0,0,25,5,0,0,25,2,0,0
	dc.b	10,1,0,0,25,4,0,0,29,2,0,0,8,1,0,0,25,5,10,1,34,2,25,3
	dc.b	0,0,0,0,25,3,10,1,0,0,0,0,13,1,0,0,25,5,0,0,32,2,0,0
	dc.b	15,1,0,0,25,4,0,0,29,2,0,0,17,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,31,2,25,3,0,0,0,0,0,0,24,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,28,2,25,4,0,0,0,0,0,0,10,1,0,0,25,5,12,1,0,0,25,3
	dc.b	0,0,24,2,25,3,16,1,0,0,0,0,0,0,0,0,25,4,7,1,0,0,0,0
	dc.b	0,0,255,0,25,4,10,1,0,0,25,4,12,1,0,0,25,4,0,0,0,0,25,4
	dc.b	5,1,24,2,25,3,0,0,0,0,0,0,17,1,29,2,25,5,0,0,0,0,0,0
	dc.b	5,1,32,2,25,4,0,0,0,0,0,0,15,1,36,2,25,5,17,1,0,0,25,3
	dc.b	0,0,34,2,25,3,5,1,0,0,0,0,8,1,32,2,25,5,0,0,0,0,0,0
	dc.b	10,1,31,2,25,4,0,0,0,0,0,0,12,1,29,2,25,5,0,0,0,0,0,0
	dc.b	1,1,32,2,25,3,0,0,0,0,0,0,13,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,29,2,25,4,0,0,0,0,0,0,12,1,0,0,25,5,13,1,0,0,25,3
	dc.b	0,0,25,2,25,3,1,1,0,0,0,0,5,1,27,2,25,5,0,0,0,0,0,0
	dc.b	8,1,29,2,25,4,0,0,0,0,0,0,10,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,25,2,25,3,0,0,0,0,0,0,22,1,22,2,25,5,0,0,0,0,0,0
	dc.b	10,1,25,2,25,4,0,0,0,0,0,0,8,1,29,2,25,5,10,1,0,0,25,3
	dc.b	0,0,27,2,25,3,10,1,0,0,0,0,13,1,25,2,25,5,0,0,0,0,0,0
	dc.b	15,1,24,2,25,4,0,0,0,0,0,0,17,1,22,2,25,5,0,0,0,0,0,0
	dc.b	12,1,24,2,25,3,0,0,0,0,0,0,24,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,0,0,25,4,0,0,0,0,0,0,10,1,28,2,25,5,12,1,0,0,25,3
	dc.b	0,0,31,2,25,3,16,1,0,0,0,0,0,0,0,0,25,4,7,1,0,0,0,0
	dc.b	0,0,36,2,25,4,10,1,0,0,25,4,12,1,255,0,25,4,0,0,0,0,25,4
	dc.b	5,1,20,6,25,3,0,0,0,0,0,0,17,1,0,0,25,5,0,0,0,0,0,0
	dc.b	5,1,0,0,25,4,0,0,0,0,0,0,15,1,0,0,25,5,17,1,0,0,25,3
	dc.b	0,0,24,6,25,3,5,1,0,0,0,0,8,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,0,0,25,4,0,0,0,0,0,0,12,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,17,6,25,3,0,0,0,0,0,0,13,1,0,0,25,5,0,0,0,0,0,0
	dc.b	1,1,0,0,25,4,0,0,0,0,0,0,12,1,0,0,25,5,13,1,0,0,25,3
	dc.b	0,0,20,6,25,3,1,1,0,0,0,0,5,1,0,0,25,5,0,0,0,0,0,0
	dc.b	8,1,0,0,25,4,0,0,0,0,0,0,10,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,13,6,25,3,0,0,0,0,0,0,22,1,0,0,25,5,0,0,0,0,0,0
	dc.b	10,1,0,0,25,4,0,0,0,0,0,0,8,1,0,0,25,5,10,1,0,0,25,3
	dc.b	0,0,17,6,25,3,10,1,0,0,0,0,13,1,0,0,25,5,0,0,0,0,0,0
	dc.b	15,1,0,0,25,4,0,0,0,0,0,0,17,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,16,6,25,3,0,0,0,0,0,0,24,1,0,0,25,5,0,0,0,0,0,0
	dc.b	12,1,0,0,25,4,0,0,0,0,0,0,10,1,0,0,25,5,12,1,0,0,25,3
	dc.b	0,0,19,6,25,3,16,1,0,0,0,0,0,0,0,0,25,5,7,1,0,0,0,0
	dc.b	0,0,0,0,25,4,10,1,0,0,0,0,12,1,0,0,25,5,0,0,0,0,0,0
	dc.b	5,1,17,2,25,3,0,0,0,0,0,0,0,0,20,2,0,0,0,0,0,0,0,0
	dc.b	5,1,24,2,25,3,0,0,0,0,0,0,0,0,29,2,0,0,0,0,0,0,0,0
	dc.b	17,1,0,0,25,3,0,0,0,0,0,0,0,0,24,2,25,4,0,0,0,0,0,0
	dc.b	17,1,29,2,25,3,0,0,0,0,0,0,0,0,0,0,25,4,0,0,0,0,0,0
	dc.b	5,1,32,2,25,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	255,0,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	5,1,24,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	4,1,23,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	3,1,22,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	2,1,21,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	1,1,20,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	255,0,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b	5,1,29,2,25,3,5,1,0,0,0,0,17,1,0,0,25,5,5,1,30,2,25,3
	dc.b	5,1,0,0,25,4,5,1,0,0,0,0,6,1,29,2,25,5,5,1,0,0,25,3
	dc.b	5,1,0,0,25,3,5,1,0,0,0,0,17,1,24,2,25,5,5,1,0,0,25,3
	dc.b	8,1,0,0,25,4,5,1,0,0,0,0,6,1,0,0,25,4,5,1,0,0,25,4
	dc.b	5,1,29,2,25,3,5,1,0,0,0,0,17,1,0,0,25,5,5,1,30,2,25,3
	dc.b	5,1,0,0,25,4,5,1,0,0,0,0,6,1,32,2,25,5,5,1,0,0,25,3
	dc.b	5,1,0,0,25,3,5,1,0,0,0,0,17,1,30,2,25,5,5,1,0,0,25,3
	dc.b	8,1,29,2,25,4,5,1,0,0,0,0,6,1,0,0,25,4,5,1,0,0,25,4
	dc.b	8,1,32,2,25,3,8,1,0,0,0,0,20,1,0,0,25,5,8,1,33,2,25,3
	dc.b	8,1,0,0,25,4,8,1,0,0,0,0,9,1,32,2,25,5,8,1,0,0,25,3
	dc.b	6,1,0,0,25,3,6,1,0,0,0,0,18,1,27,2,25,5,6,1,0,0,25,3
	dc.b	6,1,0,0,25,4,6,1,0,0,0,0,7,1,0,0,25,4,6,1,0,0,25,4
	dc.b	8,1,30,2,25,3,8,1,0,0,0,0,20,1,0,0,25,5,8,1,31,2,25,3
	dc.b	8,1,0,0,25,4,8,1,0,0,0,0,9,1,30,2,25,5,8,1,0,0,25,3
	dc.b	6,1,29,2,25,3,6,1,0,0,0,0,18,1,0,0,25,5,6,1,0,0,25,3
	dc.b	6,1,255,0,25,4,6,1,0,0,0,0,7,1,0,0,25,4,6,1,0,0,25,4
SongMain:	dc.b	0,1,2,1,2,3,1,2,$ff,1
SongWin:	dc.b	4,$fe
SongLose:	dc.b	5,$fe
SongBoss:	dc.b	6,$ff,0
	even
SfxTable:	; sample, words, period, pstep, vol, vstep, ticks, pad
SFX_ZAP	equ	0
	dc.l	smp_bass64
	dc.w	32,160,9,36,0,6,0
SFX_CATCH	equ	1
	dc.l	smp_sine32
	dc.w	16,240,-14,60,-3,14,0
SFX_SLIMED	equ	2
	dc.l	smp_tri32
	dc.w	16,200,36,60,-2,22,0
SFX_POWER	equ	3
	dc.l	smp_sine32
	dc.w	16,360,-16,56,-1,20,0
SFX_BOSSHIT	equ	4
	dc.l	smp_noise
	dc.w	1024,500,20,64,-4,14,0
SFX_DROP	equ	5
	dc.l	smp_tri32
	dc.w	16,500,-30,30,-4,6,0
SFX_TRAP	equ	6
	dc.l	smp_noise
	dc.w	1024,180,22,50,-2,22,0
SFX_MOVE	equ	7
	dc.l	smp_sine32
	dc.w	16,250,0,40,-10,4,0
SFX_SELECT	equ	8
	dc.l	smp_sine32
	dc.w	16,200,-10,56,-6,8,0
SFX_SHOOT	equ	9
	dc.l	smp_lead32
	dc.w	16,180,18,40,-5,7,0
SFX_NOTE0	equ	10
	dc.l	smp_lead32
	dc.w	16,214,0,50,-2,18,0
SFX_NOTE1	equ	11
	dc.l	smp_lead32
	dc.w	16,170,0,50,-2,18,0
SFX_NOTE2	equ	12
	dc.l	smp_lead32
	dc.w	16,143,0,50,-2,18,0
SFX_NOTE3	equ	13
	dc.l	smp_lead32
	dc.w	16,113,0,50,-2,18,0
SFX_BUZZ	equ	14
	dc.l	smp_bass64
	dc.w	32,600,0,50,-2,20,0
SFX_EXPLODE	equ	15
	dc.l	smp_noise
	dc.w	1024,300,40,64,-3,20,0
SFX_LIFE	equ	16
	dc.l	smp_sine32
	dc.w	16,300,-8,56,0,24,0
SFX_TICK	equ	17
	dc.l	smp_noise
	dc.w	1024,120,0,30,-15,2,0
SFX_BOSSROAR	equ	18
	dc.l	smp_bass64
	dc.w	32,900,30,64,-2,30,0
SFX_WARN	equ	19
	dc.l	smp_lead32
	dc.w	16,300,0,50,0,10,0


