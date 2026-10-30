; =====================================================================
;  STRONKIE'S HUNTERS  -  Commodore 64 machine language game
;
;  LOAD"STRONKIES HUNTERS",8  then  RUN
;
;  Controls: joystick in PORT 2 (left/right + fire)  or  A / D / SPACE
;            RUN/STOP quits back to BASIC
;
;  Home screens rotate (title + ghost, then the Top 10 Hall of Fame).
;  3 minutes without input starts a demo game; any key/fire ends it.
;
;  Sprites: 0 ghost, 1 hunter, 2+3 proton beam, 4 ghost slime ball
;  SID:     home screens = 3 voice tune,  game = riff + effects
;  Background: scrolling New York skyline (extended colour text mode,
;              RAM character set at $3000, fine scroll below raster 178)
;  Tuned for PAL (50 Hz) machines.
; =====================================================================

VIC         = $d000
MSBX        = VIC+16
D011        = VIC+17
RASTER      = VIC+18
SPENA       = VIC+21
D016        = VIC+22
SPYEX       = VIC+23
D018        = VIC+24
SPMC        = VIC+28
SPXEX       = VIC+29
COLLISION   = VIC+30
BORDER      = VIC+32
BGCOL       = VIC+33
BGCOL1      = VIC+34
BGCOL2      = VIC+35
BGCOL3      = VIC+36
SPCOL       = VIC+39
SID         = $d400
SIDVOL      = SID+24
OSC3        = SID+27
JOY         = $dc00                 ; joystick port 2
CHROUT      = $ffd2
GETIN       = $ffe4
KEYPRESS    = $c5
KEYBUF      = $c6
CURSORBLINK = $cc
SCREEN      = $0400
COLORRAM    = $d800
SPRPTR      = $07f8
CHARSET     = $3800
PTR         = $fb                   ; zero page pointers
PTR2        = $fd
PMAX        = 160                   ; blaster power: full
PUNLOCK     = 80                    ; overheated blaster works again from here
PDRAIN      = 2                     ; power used per frame of firing
GB          = 12                    ; game border colour: the grey TV bezel
NTILES      = 18
NGTILES     = 142
TMCODE      = 205
STREETCODE  = 165
STREETCOL   = 7

        * = $0801

        ; BASIC stub:  10 SYS 3200
        .byte $0b,$08,$0a,$00,$9e,$33,$32,$30,$30,$00,$00,$00

; ---------------------------------------------------------------------
;  sprite data lives low ($0840-$0c7f) so the VIC chip can see it
; ---------------------------------------------------------------------
        .align 64
spr_ghost
        .byte 0,0,0
        .byte 7,255,224
        .byte 31,255,248
        .byte 63,255,252
        .byte 127,255,254
        .byte 127,255,254
        .byte 113,255,142
        .byte 117,255,174
        .byte 113,255,142
        .byte 127,255,254
        .byte 127,255,254
        .byte 127,255,254
        .byte 126,0,126
        .byte 127,0,254
        .byte 127,255,254
        .byte 127,255,254
        .byte 127,255,254
        .byte 63,255,252
        .byte 31,255,248
        .byte 57,255,156
        .byte 48,255,12
        .align 64
spr_player
        .byte 0,60,0
        .byte 0,126,0
        .byte 0,126,0
        .byte 0,60,0
        .byte 0,24,0
        .byte 15,255,0
        .byte 31,255,128
        .byte 31,255,192
        .byte 31,255,224
        .byte 31,255,224
        .byte 15,255,192
        .byte 0,255,0
        .byte 0,255,0
        .byte 0,255,0
        .byte 0,102,0
        .byte 0,102,0
        .byte 0,102,0
        .byte 0,102,0
        .byte 0,102,0
        .byte 1,231,128
        .byte 1,231,128
        .align 64
spr_beam
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,255,0
        .align 64
spr_orb
        .byte 0,0,0
        .byte 0,255,0
        .byte 3,255,192
        .byte 7,255,224
        .byte 15,255,240
        .byte 15,126,240
        .byte 14,255,112
        .byte 15,255,240
        .byte 7,255,224
        .byte 7,255,224
        .byte 3,231,192
        .byte 1,255,128
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,60,0
        .byte 0,60,0
        .byte 0,24,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .align 64
spr_boss
        .byte 0,24,0
        .byte 1,126,128
        .byte 3,126,192
        .byte 15,255,240
        .byte 31,255,248
        .byte 63,255,252
        .byte 63,255,252
        .byte 51,255,204
        .byte 60,255,60
        .byte 63,255,252
        .byte 127,255,254
        .byte 255,255,255
        .byte 252,0,63
        .byte 250,165,95
        .byte 127,255,254
        .byte 63,255,252
        .byte 63,255,252
        .byte 63,255,252
        .byte 31,255,248
        .byte 15,255,240
        .byte 7,255,224
        .align 64
spr_trapc
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 3,255,192
        .byte 15,255,240
        .byte 31,255,248
        .byte 31,231,248
        .byte 31,231,248
        .byte 31,231,248
        .byte 31,255,248
        .byte 31,255,248
        .align 64
spr_trapo
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 64,0,2
        .byte 96,0,6
        .byte 48,0,12
        .byte 56,0,28
        .byte 28,0,56
        .byte 31,0,248
        .byte 31,0,248
        .byte 31,0,248
        .byte 31,0,248
        .byte 31,0,248
        .byte 31,255,248
        .byte 31,255,248
        .align 64
spr_pwi
        .byte 0,0,0
        .byte 0,255,0
        .byte 3,255,192
        .byte 7,255,224
        .byte 15,255,240
        .byte 15,255,240
        .byte 31,131,248
        .byte 31,239,248
        .byte 63,239,252
        .byte 63,239,252
        .byte 63,239,252
        .byte 63,239,252
        .byte 63,239,252
        .byte 31,239,248
        .byte 31,131,248
        .byte 15,255,240
        .byte 15,255,240
        .byte 7,255,224
        .byte 3,255,192
        .byte 0,255,0
        .byte 0,0,0
        .align 64
spr_pwe
        .byte 0,0,0
        .byte 0,255,0
        .byte 3,255,192
        .byte 7,255,224
        .byte 15,255,240
        .byte 15,255,240
        .byte 31,131,248
        .byte 31,191,248
        .byte 63,191,252
        .byte 63,191,252
        .byte 63,135,252
        .byte 63,191,252
        .byte 63,191,252
        .byte 31,191,248
        .byte 31,131,248
        .byte 15,255,240
        .byte 15,255,240
        .byte 7,255,224
        .byte 3,255,192
        .byte 0,255,0
        .byte 0,0,0
        .align 64
spr_pwg
        .byte 0,0,0
        .byte 0,255,0
        .byte 3,255,192
        .byte 7,255,224
        .byte 15,255,240
        .byte 15,255,240
        .byte 31,199,248
        .byte 31,187,248
        .byte 63,191,252
        .byte 63,191,252
        .byte 63,163,252
        .byte 63,187,252
        .byte 63,187,252
        .byte 31,187,248
        .byte 31,199,248
        .byte 15,255,240
        .byte 15,255,240
        .byte 7,255,224
        .byte 3,255,192
        .byte 0,255,0
        .byte 0,0,0
        .align 64
spr_pws
        .byte 0,16,0
        .byte 0,16,0
        .byte 0,56,0
        .byte 0,56,0
        .byte 0,56,0
        .byte 0,124,0
        .byte 0,124,0
        .byte 63,255,248
        .byte 31,255,240
        .byte 15,255,224
        .byte 7,255,192
        .byte 3,255,128
        .byte 1,255,0
        .byte 1,255,0
        .byte 3,255,128
        .byte 3,239,128
        .byte 3,199,128
        .byte 3,1,128
        .byte 4,0,64
        .byte 0,0,0
        .byte 0,0,0
        .align 64
spr_beam2
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .byte 12,0,48
        .byte 30,0,120
        .align 64
spr_boss_s
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,24,0
        .byte 0,255,0
        .byte 1,255,128
        .byte 1,255,128
        .byte 1,255,128
        .byte 3,255,192
        .byte 3,129,192
        .byte 1,255,128
        .byte 1,255,128
        .byte 0,255,0
        .byte 0,126,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .align 64
spr_car_ra
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,255,0
        .byte 0,24,0
        .byte 2,24,64
        .byte 6,24,96
        .byte 15,255,240
        .byte 63,255,252
        .byte 127,255,252
        .byte 127,255,252
        .byte 112,126,14
        .byte 96,60,6
        .byte 64,24,2
        .byte 64,24,2
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .align 64
spr_car_rb
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 1,231,128
        .byte 1,231,128
        .byte 1,231,128
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 2,0,64
        .byte 15,129,240
        .byte 31,195,248
        .byte 31,195,248
        .byte 31,195,248
        .byte 31,195,248
        .byte 15,129,240
        .align 64
spr_car_la
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,255,0
        .byte 0,24,0
        .byte 2,24,64
        .byte 6,24,96
        .byte 15,255,240
        .byte 63,255,252
        .byte 63,255,254
        .byte 63,255,254
        .byte 112,126,14
        .byte 96,60,6
        .byte 64,24,2
        .byte 64,24,2
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .align 64
spr_car_lb
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 1,231,128
        .byte 1,231,128
        .byte 1,231,128
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 0,0,0
        .byte 2,0,64
        .byte 15,129,240
        .byte 31,195,248
        .byte 31,195,248
        .byte 31,195,248
        .byte 31,195,248
        .byte 15,129,240
        .align 64

        * = $0c80

; ---------------------------------------------------------------------
;  one-time initialisation
; ---------------------------------------------------------------------
start   lda #0
        sta BORDER
        sta BGCOL
        ldx #$18
clrsid  sta SID,x               ; silence the SID
        dex
        bpl clrsid
        lda #1
        sta CURSORBLINK         ; no blinking cursor

        lda #spr_ghost/64       ; sprite pointers
        sta SPRPTR
        lda #spr_player/64
        sta SPRPTR+1
        lda #spr_beam/64
        sta SPRPTR+2
        sta SPRPTR+3
        lda #spr_orb/64
        sta SPRPTR+4
        lda #spr_boss/64
        sta SPRPTR+5
        lda #spr_trapc/64
        sta SPRPTR+6
        lda #spr_beam/64        ; sprite 7 = suction ray
        sta SPRPTR+7
        lda #5                  ; green blob creature
        sta SPCOL
        lda #8                  ; orange hunter
        sta SPCOL+1
        lda #7                  ; yellow beam
        sta SPCOL+2
        sta SPCOL+3
        lda #13                 ; bright green slime
        sta SPCOL+4
        lda #1                  ; boss: white marshmallow
        sta SPCOL+5
        lda #12                 ; ghost trap
        sta SPCOL+6
        lda #3                  ; suction ray
        sta SPCOL+7
        lda #0
        sta SPMC
        sta MSBX
        lda #15
        sta SIDVOL
        lda #255
        sta hlrow               ; no highlighted Hall of Fame row

        jsr copychars           ; RAM character set with the skyline tiles
        lda #$1e                ; screen $0400, characters $3800
        sta D018
        jsr intro               ; 10 second logo screen

; ---------------------------------------------------------------------
;  HOME SCREENS (title / Hall of Fame, rotating)
; ---------------------------------------------------------------------
title   lda #0
        sta demo
        sta scr
        sta rotl
        sta roth
        sta idlel
        sta idleh
        jsr ecmoff
        jsr sethome
        jsr drawhome

hloop   jsr waitframe
        jsr readinput
        lda key                 ; M = music on / off
        cmp #36
        bne mk1
        lda mprev
        bne mk2
        lda #1
        sta mprev
        lda mute
        eor #1
        sta mute
        jsr mutechange
        jmp mk2
mk1     lda #0
        sta mprev
mk2     lda key
        cmp #63                 ; RUN/STOP
        bne hnostop
        jmp quit
hnostop lda inf                 ; fire = start the game
        beq hnofire
        jmp newgame
hnofire lda key                 ; any other activity resets the idle timer
        cmp #64
        bne hact
        lda joyv
        and #$1f
        cmp #$1f
        beq hidle
hact    lda #0
        sta idlel
        sta idleh
        jmp hanim
hidle   inc idlel               ; 9000 frames = 3 minutes -> demo
        bne hid2
        inc idleh
hid2    lda idleh
        cmp #$23
        bcc hanim
        bne hdemo
        lda idlel
        cmp #$28
        bcc hanim
hdemo   jmp startdemo
hanim   lda scr
        bne hanim1
        jsr titleanim
        jmp hrot
hanim1  cmp #2
        bcs hanim2
        jsr hallblink
        jmp hrot
hanim2  cmp #3
        bcs hanim3
        jsr pinfoanim
        jmp hrot
hanim3  jsr bossanim
hrot    inc rotl                ; next screen every 400 frames: title, hall, power-ups, boss
        bne hr2
        inc roth
hr2     lda roth
        cmp #1
        bcc hmus
        bne hswitch
        lda rotl
        cmp #$90
        bcc hmus
hswitch lda #0
        sta rotl
        sta roth
        inc scr
        lda scr
        cmp #4
        bcc hsw2
        lda #0
        sta scr
hsw2    jsr drawhome
hmus    lda mute
        bne hmus2
        jsr hmusic
hmus2   jmp hloop

drawhome
        jsr ptrfix
        lda scr
        bne dhhall
        jmp showtitle
dhhall  cmp #2
        bcs dhp
        jmp showhall
dhp     cmp #3
        bcs dhboss
        jmp showpinfo
dhboss  jmp showbint

showtitle
        jsr drawbg
        lda #<titlescr
        sta PTR
        lda #>titlescr
        sta PTR+1
        jsr printstr
        lda #TMCODE             ; trademark mark next to the title
        sta SCREEN+40+26
        lda #7
        sta COLORRAM+40+26
        jsr showmute
        lda #<(SCREEN+20*40+15) ; best hunter: name + score + level
        sta PTR
        lda #>(SCREEN+20*40+15)
        sta PTR+1
        ldx #0
        jsr putname
        lda #<(SCREEN+20*40+24)
        sta PTR
        lda #>(SCREEN+20*40+24)
        sta PTR+1
        lda hsh_tab
        ldx hsl_tab
        jsr put4
        lda #<(SCREEN+20*40+32)
        sta PTR
        lda #>(SCREEN+20*40+32)
        sta PTR+1
        lda hlv_tab
        jsr put2bin
        lda #13                 ; big floating ghost: sprite 0 doubled
        sta SPYEX
        lda #1
        sta SPXEX
        sta SPENA
        lda #5
        sta SPCOL
        lda #0
        sta MSBX
        rts

showhall
        lda #0
        sta SPENA
        jsr drawbg
        lda #<hallscr
        sta PTR
        lda #>hallscr
        sta PTR+1
        jsr printstr
        jmp drawhall

; ---- boss intro screen (third home screen)
showbint
        jsr drawbg
        lda #<bintscr
        sta PTR
        lda #>bintscr
        sta PTR+1
        jsr printstr
        lda #$20                ; only the boss sprite, doubled both ways
        sta SPENA
        sta SPXEX
        sta SPYEX
        lda #0
        sta MSBX
        lda #1
        sta SPCOL+5
        rts

bossanim
        inc ph                  ; the boss sways and bobs
        inc ph2
        inc ph2
        ldx ph
        lda sintab_x,x
        lsr
        lsr
        clc
        adc #130
        sta VIC+10
        ldx ph2
        lda sintab_y,x
        sta VIC+11
        lda ph                  ; angry colour flicker
        and #8
        beq ba1
        lda #10
        jmp ba2
ba1     lda #1
ba2     sta SPCOL+5
        lda ph                  ; blink the prompt
        and #$20
        beq ba3
        lda #11
        jmp ba4
ba3     lda #1
ba4     ldx #18
ba5     sta COLORRAM+22*40+10,x
        dex
        bpl ba5
        rts

; ---- M key: music on / off
mutechange
        lda mute
        beq mc1
        lda #$40                ; music off: silence the voices
        sta SID+4
        lda #$20
        sta SID+11
        lda #$10
        sta SID+18
        jmp showmute
mc1     lda #1                  ; music on again: restart the tune
        sta hstimer
showmute
        lda scr                 ; (the message lives on the title screen)
        bne sm9
        ldx #0
        lda mute
        beq smm
        ldx #11
smm     ldy #0
sml     lda mutemsg,x
        and #$3f
        sta SCREEN+21*40+14,y
        inx
        iny
        cpy #11
        bne sml
        lda #5                  ; green = on, red = off
        ldy mute
        beq smc
        lda #2
smc     ldy #10
smd     sta COLORRAM+21*40+14,y
        dey
        bpl smd
sm9     rts

titleanim
        inc ph                  ; gentle sway and bob
        inc ph2
        inc ph2
        ldx ph
        lda sintab_x,x
        lsr
        lsr
        clc
        adc #130
        sta VIC
        ldx ph2
        lda sintab_y,x
        sta VIC+1
        lda ph                  ; blink "PRESS FIRE"
        and #$20
        beq tb1
        lda #11
        jmp tb2
tb1     lda #1
tb2     ldx #18
tb3     sta COLORRAM+22*40+10,x
        dex
        bpl tb3
        rts

; fill the Hall of Fame rows with names and scores
drawhall
        lda #0
        sta ri
dh1     ldx ri
        lda hrow_lo,x
        sta PTR
        lda hrow_hi,x
        sta PTR+1
        txa
        asl
        asl
        asl
        tax
        jsr putname             ; 8 characters at (PTR)
        lda PTR
        clc
        adc #10
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        ldx ri
        lda hsh_tab,x
        pha
        lda hsl_tab,x
        tax
        pla
        jsr put4
        lda PTR
        clc
        adc #8
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        ldx ri
        lda hlv_tab,x
        jsr put2bin             ; level reached
        inc ri
        lda ri
        cmp #10
        bne dh1
        rts

hallblink                       ; highlight the new entry
        lda hlrow
        cmp #10
        bcs hbdone
        tax
        lda hcol_lo,x
        sta PTR
        lda hcol_hi,x
        sta PTR+1
        lda rotl
        and #$10
        beq hb1
        lda #1
        jmp hb2
hb1     lda #7
hb2     ldy #24
hb3     sta (PTR),y
        dey
        bpl hb3
hbdone  rts

; ---------------------------------------------------------------------
;  DEMO MODE: the computer plays; fire / any key ends it
; ---------------------------------------------------------------------
startdemo
        lda #1
        sta demo
        jmp newgame

enddemo lda #0
        sta demo
        jmp title

; ---------------------------------------------------------------------
;  NEW GAME
; ---------------------------------------------------------------------
newgame lda #255
        sta hlrow
        jsr setgame
        lda #0
        sta scl
        sta sch
        sta hits
        sta gbl
        sta gbh
        sta mnote
        sta dmtl
        sta dmth
        sta invt
        sta dbt
        sta gmode
        lda #3
        sta lives
        lda #1
        sta lvl
        jsr startlevel          ; (falls into the game loop)

; ---------------------------------------------------------------------
;  GAME LOOP - once per frame
; ---------------------------------------------------------------------
gframe  jsr waitframe
        lda #$c0                ; 38 columns, no scrolling at the top
        sta D016
        jsr readinput
        lda key
        cmp #63                 ; RUN/STOP
        bne gnostop
        jmp quit
gnostop lda demo
        beq gnodemo
        lda inf                 ; demo: real fire starts a real game
        beq dm1
        lda #0
        sta demo
        jmp newgame
dm1     lda key                 ; any other key/joystick ends the demo
        cmp #64
        bne dmend
        lda joyv
        and #$1f
        cmp #$1f
        bne dmend
        inc dmtl                ; demo lasts 3000 frames (60 seconds)
        bne dm2
        inc dmth
dm2     lda dmth
        cmp #$17
        bcc dm3
        bne dmend
        lda dmtl
        cmp #$70
        bcs dmend
dm3     jsr demoai
        jmp gnodemo
dmend   jmp enddemo
gnodemo lda gmode               ; cutscenes: car, countdown, boss approach, level end
        beq gnorm
        jsr cinematic
        jsr zaptick
        jsr gametimers
        jsr scrollsky
        jmp bodyend
gnorm   jsr powerupdate          ; blaster power: drain / recharge

        inc ph                  ; ghost floats: advance sine phases
        inc ph2
        inc ph2
        lda ph
        and #$0f
        bne ph2ok
        inc ph2
ph2ok   ldx ph
        clc
        lda sintab_x,x          ; X = 50..290 (9 bit)
        adc #50
        sta gxl
        lda #0
        adc #0
        sta gxh
        ldx ph2
        lda sintab_y,x          ; Y = 91..141
        sta gy

        lda inl                 ; move left
        beq notleft
        lda pxh
        bne doleft
        lda pxl
        cmp #31
        bcc notleft
doleft  sec
        lda pxl
        sbc #5
        sta pxl
        lda pxh
        sbc #0
        sta pxh
notleft lda inr                 ; move right
        beq notright
        lda pxh
        beq doright
        lda pxl
        cmp #44
        bcs notright
doright clc
        lda pxl
        adc #5
        sta pxl
        lda pxh
        adc #0
        sta pxh
notright jsr powupd                ; falling power-up

        lda COLLISION           ; hardware sprite collisions (read once)
        sta col
        jsr bossupdate          ; boss fight / trap / level logic

; ----- the ghost fights back: it spits slime balls that home in -------
        lda pact
        bne pmove
        lda bstate
        cmp #2
        bcc pt1
        jmp pdone               ; stunned boss / level over: no attacks
pt1     dec stimer              ; no ball in flight: count down
        beq pt2
        jmp pdone
pt2     jsr spawnorbs           ; creature: homing slime;  boss: 4 attack patterns
        lda #$00                ; "spit" sound
        sta SID+14
        lda #$0c
        sta SID+15
        lda #$81
        sta SID+18
        lda #6
        sta zap
        jmp pdone
pmove   lda jy                  ; ball falls (speed depends on level / pattern)
        clc
        adc jspd
        sta jy
        cmp #236
        bcc pm1
        lda #0                  ; fell off the bottom: dodged
        sta pact
        jsr resettimer
        jmp pdone
pm1     lda jmode
        beq phome
        cmp #1
        bne pm2
        jmp pdone               ; mode 1: straight down
pm2     cmp #2
        bne pm3
        lda jxl                 ; mode 2: drifts left
        bne pm2a
        dec jxh
pm2a    dec jxl
        jmp pdone
pm3     inc jxl                 ; mode 3: drifts right
        bne pm3a
        inc jxh
pm3a    jmp pdone
phome   lda ph                  ; mode 0: drifts toward the hunter
        and #1
        bne pdone
        lda jxh
        cmp pxh
        bcc pright
        bne pleft
        lda jxl
        cmp pxl
        bcc pright
        beq pdone
pleft   lda jxl
        bne pl1
        dec jxh
pl1     dec jxl
        jmp pdone
pright  inc jxl
        bne pdone
        inc jxh
pdone   jsr moveorb2            ; second slime ball

        lda gxl                 ; place the sprites
        sta VIC
        lda gy
        sta VIC+1
        lda pxl
        sta VIC+2
        sta VIC+4
        sta VIC+6
        lda #221                ; hunter stands on the street
        sta VIC+3
        lda #179
        sta VIC+5
        lda #137
        sta VIC+7
        lda jxl
        sta VIC+8
        lda jy
        sta VIC+9
        lda bxl                 ; boss
        sta VIC+10
        lda byv
        sta VIC+11
        lda bstate
        cmp #3
        bcs pl_ray
        lda j2xl                ; sprite 7 = second slime ball ...
        sta VIC+14
        lda j2y
        sta VIC+15
        lda #spr_orb/64
        sta SPRPTR+7
        jmp pl_r2
pl_ray  lda txl                 ; ... or the suction ray (state 3)
        sta VIC+14
        lda #179
        sta VIC+15
        lda #spr_beam/64
        sta SPRPTR+7
pl_r2
        lda bstate              ; sprite 6 = ghost trap (state 3), else power-up
        cmp #3
        bcs pl_trap
        lda pwxl
        sta VIC+12
        lda pwy
        sta VIC+13
        clc
        lda #spr_pwi/64         ; I, E, G or star
        adc pwtype
        sta SPRPTR+6
        lda pwtype              ; glowing colours (2 per type, flip every 4 frames)
        asl
        sta t1
        lda ph
        lsr
        lsr
        and #1
        ora t1
        tax
        lda pwcol,x
        sta SPCOL+6
        jmp pl_done
pl_trap lda txl
        sta VIC+12
        lda #221
        sta VIC+13
        lda #12
        sta SPCOL+6
pl_done lda dbt                 ; two proton beams?
        beq pb1
        lda #spr_beam2/64
        jmp pb2
pb1     lda #spr_beam/64
pb2     sta SPRPTR+2
        sta SPRPTR+3
        lda #0                  ; X bit 8 for the sprites
        ldx pxh
        beq msbok
        lda #14
msbok   ora gxh
        ldx jxh
        beq msbok2
        ora #16
msbok2  ldx bxh
        beq msbok3
        ora #32
msbok3  ldx bstate              ; sprite 7: second ball or ray
        cpx #3
        bcs mb_r
        ldx j2xh
        beq msbok4
        ora #$80
        jmp msbok4
mb_r    ldx txh
        beq msbok4
        ora #$80
msbok4  ldx bstate              ; sprite 6: trap or power-up
        cpx #3
        bcs msbok6
        ldx pwxh
        beq msbok5
        ora #$40
        jmp msbok5
msbok6  ldx txh
        beq msbok5
        ora #$40
msbok5  sta MSBX

        lda #2                  ; which sprites are visible?
        ldx bstate
        bne sm1
        ora #1                  ; the ordinary ghost
sm1     ldx bstate
        beq sm4
        cpx #4
        bcs sm4
        ora #$20                ; boss (states 1-3)
        cpx #3
        bne sm4
        ora #$40                ; ghost trap
        ldx tph
        cpx #15
        bcc sm4
        ora #$80                ; suction ray once the trap is open
sm4     sta spm
        ldx ppact
        beq sm5
        lda pwtype
        cmp #3
        bne sm4b
        lda ph                  ; the big star blinks
        and #8
        beq sm5
sm4b    lda spm
        ora #$40                ; falling power-up
        sta spm
sm5     lda spm
        ldx pact
        beq sm6
        ora #16                 ; slime ball
sm6     ldx p2act               ; second slime ball (sprite 7)
        beq nopsp
        ora #$80
nopsp   ldx fon                 ; beam only while the blaster has power
        beq nobeam
        ora #12                 ; proton beam
nobeam  sta spm
        lda ht                  ; hunter blinks after being hit
        and #4
        beq noblink
        lda spm
        and #$fd
        sta spm
noblink lda binv                ; boss blinks while invulnerable
        and #4
        beq noblink2
        lda spm
        and #$df
        sta spm
noblink2 lda spm
        sta SPENA

        lda fon                 ; fire = proton beam (needs power)
        beq nofire
        lda OSC3                ; crackling buzz
        sta SID+7
        and #3
        clc
        adc #6
        sta SID+8
        lda #$21
        sta SID+11
        lda bstate              ; (only the ordinary ghost is caught this way)
        bne fired
        lda col                 ; beam touching the ghost?
        and #1
        beq fired
        lda col
        and #12
        beq fired
        jsr gothit
        jmp fired
nofire  lda bstate              ; (voice 2 belongs to the trap suction in state 3)
        cmp #3
        beq fired
        lda #$20
        sta SID+11
fired

        lda pact                ; slime ball touching the hunter?
        beq nohurt
        lda invt                ; invincible: slime can't hurt
        bne nohurt
        lda jy                  ; (it must really be down at the hunter)
        cmp #200
        bcc nohurt
        lda col
        and #$12
        cmp #$12
        bne nohurt
        jsr hurt
nohurt  lda p2act               ; the second ball of a boss pattern
        beq nohurt2
        lda invt
        bne nohurt2
        lda j2y
        cmp #200
        bcc nohurt2
        lda col
        and #$82
        cmp #$82
        bne nohurt2
        lda pact
        pha
        jsr hurt
        pla
        sta pact
        lda #0
        sta p2act
nohurt2
        lda zap                 ; end of noise burst
        beq nozap
        dec zap
        bne nozap
        lda #$80
        sta SID+18
nozap
        lda flash               ; colour flash after hitting the ghost
        beq noflash
        dec flash
        bne flashing
        lda #GB
        sta BORDER
        lda #5
        sta SPCOL
        jmp noflash
flashing lda flash
        sta BORDER
        sta SPCOL
noflash
        lda ht                  ; red border while recovering
        beq noht
        dec ht
        bne htact
        lda #GB
        sta BORDER
        jmp noht
htact   lda #2
        sta BORDER
noht
        jsr gametimers
        jsr scrollsky
        lda mute
        bne nomus
        jsr domusic
nomus
        lda lives
        bne gcont
        jmp gameover
gcont
bodyend jsr waitsky             ; wait for raster 170 (top of the skyline)
        lda fine                ; fine scroll for the skyline rows only
        ora #$c0
        sta D016
        jsr waitbot             ; raster 242: the bottom bezel must not scroll
        lda #$c0
        sta D016
        jmp gframe

; ---------------------------------------------------------------------
;  ghost was hit: +10 points (BCD), noise, flash, ghost jumps away
; ---------------------------------------------------------------------
gothit  lda #$10
        ldx #0
        jsr addscore
        inc hits                ; the ghosts get meaner
        inc lvlg                ; quota full = boss
        sei                     ; total busted (BCD)
        sed
        clc
        lda gbl
        adc #1
        sta gbl
        lda gbh
        adc #0
        sta gbh
        cld
        cli
        jsr showprog
        lda #40                 ; 16% chance the creature drops a power-up
        jsr maybedrop
        jsr showscore
        lda #$c8
        sta SID+14
        lda #$1e
        sta SID+15
        lda #$81
        sta SID+18
        lda #8
        sta zap
        lda #12
        sta flash
        lda OSC3
        and #$7f
        clc
        adc #40
        clc
        adc ph
        sta ph
        lda lvlg
        cmp need
        bcc gh9
        jsr startboss
gh9     rts

; ---------------------------------------------------------------------
;  hunter was hit by slime: lose a life
; ---------------------------------------------------------------------
hurt    lda #0
        sta pact
        dec lives
        jsr showlives
        lda #48
        sta ht
        lda #$00                ; low rumble
        sta SID+14
        lda #$05
        sta SID+15
        lda #$81
        sta SID+18
        lda #20
        sta zap
        jsr resettimer
        rts

; next attack comes sooner as you catch ghosts in a level (80 - 6 per
; catch) and on higher levels; the boss attacks every 28-43 frames
resettimer
        lda bstate
        cmp #1
        bne rt0
        lda OSC3
        and #$0f
        clc
        adc #28
        sta stimer
        rts
rt0     ldx lvlg
        cpx #11
        bcc rt1
        ldx #10
rt1     lda diff,x
        pha
        ldx lvl
        dex
        cpx #7
        bcc rt2
        ldx #6
rt2     pla
        sec
        sbc lvlpen,x
        bcc rt3
        cmp #12
        bcs rt4
rt3     lda #12
rt4     sta stimer
        lda OSC3
        and #$1f
        clc
        adc stimer
        sta stimer
        rts

; ---------------------------------------------------------------------
;  the computer plays the demo
; ---------------------------------------------------------------------
demoai  lda #0
        sta inl
        sta inr
        sta inf
        sta intrap
        lda pact                ; dodge a falling ball first
        beq dtrack
        lda jy
        cmp #90
        bcc dtrack
        lda jxl
        sta d1l
        lda jxh
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #28
        bcs dtrack
        lda sgn                 ; ball right of hunter -> run left
        beq drun_r
        lda #1
        sta inl
        rts
drun_r  lda #1
        sta inr
        rts
dtrack  lda p2act               ; second ball?
        beq dtr1
        lda j2y
        cmp #90
        bcc dtr1
        lda j2xl
        sta d1l
        lda j2xh
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #28
        bcs dtr1
        lda sgn
        beq drun_r
        lda #1
        sta inl
        rts
dtr1    lda bstate
        cmp #2
        bcc dnorm
        bne dnone               ; trap busy / level over: just wait
        clc                     ; stunned boss: stand under it, deploy the trap
        lda bxl
        adc #12
        sta d1l
        lda bxh
        adc #0
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #6
        bcs dmove
        lda #1
        sta intrap
dnone   rts
dnorm   lda ppact              ; low on power? go and collect the power-up
        beq dn1
        lda plock
        bne dn0
        lda pwr
        cmp #70
        bcs dn1
dn0     lda pwxl
        sta d1l
        lda pwxh
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #8
        bcs dmove
        rts
dn1     lda gxl                 ; otherwise get under the ghost and zap
        sta d1l
        lda gxh
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #12
        bcs dmove
        lda #1
        sta inf
        rts
dmove   lda sgn
        beq dm_l
        lda #1
        sta inr
        rts
dm_l    lda #1
        sta inl
        rts

absdiff sec                     ; A = |d1-d2| (max 255), sgn = 1 if d1>=d2
        lda d1l
        sbc d2l
        sta t1
        lda d1h
        sbc d2h
        sta t2
        bcs ad1
        lda #0
        sec
        sbc t1
        sta t1
        lda #0
        sbc t2
        sta t2
        lda #0
        sta sgn
        jmp ad2
ad1     lda #1
        sta sgn
ad2     lda t2
        beq ad3
        lda #255
        rts
ad3     lda t1
        rts

; ---------------------------------------------------------------------
;  BOSS FIGHT:  states  0 normal   1 boss fight (3 hits)   2 stunned
;                       3 trap sucks the boss in           4 level done
; ---------------------------------------------------------------------
; ---------------------------------------------------------------------
;  LEVEL START  (called for every level; ends in the car arrival scene)
; ---------------------------------------------------------------------
startlevel
        lda #0
        sta SPENA
        lda #spr_ghost/64
        sta SPRPTR
        lda #spr_player/64
        sta SPRPTR+1
        lda #spr_beam/64
        sta SPRPTR+2
        sta SPRPTR+3
        lda #<hudscr
        sta PTR
        lda #>hudscr
        sta PTR+1
        jsr printstr
        lda demo
        beq stl1
        lda #<demostr
        sta PTR
        lda #>demostr
        sta PTR+1
        jsr printstr
stl1    lda #$0c
        sta SPYEX
        lda #0
        sta SPXEX
        sta MSBX
        sta bstate
        sta lvlg
        sta bncnt
        sta tcool
        sta binv
        sta intrap
        sta plock
        sta fon
        sta ppact
        sta pbn
        sta p2act
        sta bpat
        sta pact
        sta tph
        sta flash
        sta zap
        sta ht
        sta gph
        sta gcnt
        sta carxl
        sta carxh
        sta scrollon
        sta cdir
        sta pxh
        lda #PMAX
        sta pwr
        lda #160
        sta pxl
        lda #5
        sta SPCOL
        lda #100                ; first attack comes after the countdown
        sta stimer
        lda #7
        sta fine
        lda #40
        sta mapnext
        ldx lvl                 ; each level needs 5 more creatures: 20,25,30 ...
        dex
        cpx #9
        bcc stl2
        ldx #8
stl2    lda needtab,x
        sta need
        jsr calcospd
        jsr ecmon
        jsr drawsky
        jsr hudinit
        jsr drawpower
        jsr showscore
        jsr showhi
        jsr showlives
        jsr showlvl
        jsr showprog
        lda #1
        sta mtimer
        sta gmode               ; 1 = car arrives, hunter gets out, countdown
        rts

; ---------------------------------------------------------------------
;  CUTSCENES  (gmode 1 = arrival, 2 = boss approaching, 3 = leaving, 4 = level complete)
; ---------------------------------------------------------------------
cinematic
        lda gmode
        cmp #1
        bne ci2
        jmp introseq
ci2     cmp #2
        bne ci3
        jmp approachseq
ci3     cmp #3
        bne ci4
        jmp outroseq
ci4     jmp lcseq

cinplace                        ; put hunter, car and boss on the screen
        lda pxl
        sta VIC+2
        lda #221
        sta VIC+3
        lda carxl
        sta VIC+12
        sta VIC+14
        lda #221
        sta VIC+13
        sta VIC+15
        lda bxl
        sta VIC+10
        lda byv
        sta VIC+11
        lda #0
        ldx pxh
        beq cp1
        ora #$02
cp1     ldx carxh
        beq cp2
        ora #$c0
cp2     ldx bxh
        beq cp3
        ora #$20
cp3     sta MSBX
        lda cmask
        sta SPENA
        rts

carset                          ; car = two sprites (body red, glass + wheels cyan), doubled in X
        lda cdir
        bne cr1
        lda #spr_car_ra/64
        sta SPRPTR+6
        lda #spr_car_rb/64
        sta SPRPTR+7
        jmp cr2
cr1     lda #spr_car_la/64
        sta SPRPTR+6
        lda #spr_car_lb/64
        sta SPRPTR+7
cr2     lda #2
        sta SPCOL+6
        lda #3
        sta SPCOL+7
        lda SPXEX
        ora #$c0
        sta SPXEX
        lda SPYEX
        and #$3f
        sta SPYEX
        rts

carunset
        lda SPXEX
        and #$3f
        sta SPXEX
        rts

engine  inc ecnt                ; engine rumble
        lda ecnt
        and #3
        asl
        asl
        asl
        clc
        adc #$40
        sta SID+7
        lda #3
        sta SID+8
        lda #$21
        sta SID+11
        rts

brake   lda #$00                ; tyre squeal
        sta SID+14
        lda #$30
        sta SID+15
        lda #$81
        sta SID+18
        lda #12
        sta zap
        rts

zaptick lda zap
        beq zt1
        dec zap
        bne zt1
        lda #$80
        sta SID+18
zt1     rts

thump   lda #$00                ; footstep
        sta SID+14
        lda #$06
        sta SID+15
        lda #$81
        sta SID+18
        lda #5
        sta zap
        rts

scream  lda #$00                ; scary shriek
        sta SID
        lda #$28
        sta SID+1
        lda #$21
        sta SID+4
        lda #22
        sta bpt
        rts

beep    tay                     ; countdown beep, A = note index
        lda freqlo,y
        sta SID
        lda freqhi,y
        sta SID+1
        lda #$21
        sta SID+4
        lda #14
        sta bpt
        rts

; ---- arrival: car drives in, hunter gets out, car leaves, 3-2-1-GO
introseq
        lda gph
        bne it1
        jsr carset
        lda #1
        sta scrollon
        clc
        lda carxl
        adc #3
        sta carxl
        lda carxh
        adc #0
        sta carxh
        jsr engine
        lda #$c0
        sta cmask
        lda carxl
        cmp #70
        bcc it_pl
        lda #1
        sta gph
        lda #0
        sta gcnt
        sta scrollon
        lda #$20
        sta SID+11
        jsr brake
it_pl   jmp cinplace
it1     cmp #1
        bne it2
        inc gcnt
        lda gcnt
        cmp #24
        bcc it_pl
        lda #2
        sta gph
        clc
        lda carxl
        adc #22
        sta pxl
        lda #0
        sta pxh
        lda #$c2
        sta cmask
        jmp cinplace
it2     cmp #2
        bne it3
        clc
        lda pxl
        adc #2
        sta pxl
        cmp #160
        bcc it_pl
        lda #3
        sta gph
        lda #1
        sta scrollon
        jmp cinplace
it3     cmp #3
        bne it4
        clc
        lda carxl
        adc #4
        sta carxl
        lda carxh
        adc #0
        sta carxh
        jsr engine
        lda carxh
        beq it_pl
        lda carxl
        cmp #80
        bcc it_pl
        lda #4
        sta gph
        lda #0
        sta gcnt
        sta scrollon
        lda #$02
        sta cmask
        lda #$20
        sta SID+11
        jsr carunset
        jmp cinplace
it4     jsr countdown
        jmp cinplace

countdown
        lda gcnt
        bne cd1
        ldx #0
        jsr bigshow
        lda #5
        jsr beep
        jmp cd9
cd1     cmp #50
        bne cd2
        ldx #1
        jsr bigshow
        lda #5
        jsr beep
        jmp cd9
cd2     cmp #100
        bne cd3
        ldx #2
        jsr bigshow
        lda #5
        jsr beep
        jmp cd9
cd3     cmp #150
        bne cd4
        ldx #3
        jsr bigshow
        lda #8
        jsr beep
        jmp cd9
cd4     cmp #190
        bne cd9
        jsr bigclear
        lda #0
        sta gmode
        lda #1
        sta scrollon
        sta mtimer
        lda #$20
        sta SID+4
cd9     inc gcnt
        lda bpt
        beq cd10
        dec bpt
        bne cd10
        lda #$20
        sta SID+4
cd10    rts

bigshow stx tmpx                ; X = 0 "3", 1 "2", 2 "1", 3 "GO!"
        jsr bigclear
        ldx tmpx
        cpx #3
        bcs bs_go
        txa
        ldx #18
        jmp drawglyph
bs_go   lda #3
        ldx #14
        jsr drawglyph
        lda #4
        ldx #18
        jsr drawglyph
        lda #5
        ldx #22
        jmp drawglyph

bigclear
        ldx #14
bk1     lda #32
        sta SCREEN+8*40+12,x
        sta SCREEN+9*40+12,x
        sta SCREEN+10*40+12,x
        sta SCREEN+11*40+12,x
        sta SCREEN+12*40+12,x
        lda #7
        sta COLORRAM+8*40+12,x
        sta COLORRAM+9*40+12,x
        sta COLORRAM+10*40+12,x
        sta COLORRAM+11*40+12,x
        sta COLORRAM+12*40+12,x
        dex
        bpl bk1
        rts

drawglyph                       ; A = glyph 0-5, X = first column: 3x5 block letters
        sta t1
        asl
        asl
        clc
        adc t1
        sta gfi
        stx tmpx
        lda #<(SCREEN+8*40)
        clc
        adc tmpx
        sta PTR
        lda #>(SCREEN+8*40)
        adc #0
        sta PTR+1
        lda #5
        sta grow
gl1     ldx gfi
        lda bigfont,x
        sta t2
        ldy #0
gl2     lda t2
        and bmask,y
        beq gl3
        lda #38
        sta (PTR),y
gl3     iny
        cpy #3
        bne gl2
        inc gfi
        lda PTR
        clc
        adc #40
        sta PTR
        bcc gl4
        inc PTR+1
gl4     dec grow
        bne gl1
        rts

; ---- boss approaching: the screen stops, footsteps and growls, the boss grows from far away
startboss
        lda #5
        sta bstate
        lda #2
        sta gmode
        lda #0
        sta gph
        sta gcnt
        rts

approachseq
        lda gph
        bne ap_a
        lda gcnt
        bne ap_a
        lda #$02                ; only the hunter stays on the screen
        sta cmask
        lda #0
        sta scrollon
        lda SPXEX
        and #$df
        sta SPXEX
        lda SPYEX
        and #$df
        sta SPYEX
        lda #1
        sta thc
        lda #24
        sta thint
        lda #<appstr
        sta PTR
        lda #>appstr
        sta PTR+1
        jsr printstr
ap_a    ldx gph
        lda gcnt
        cmp apdur,x
        beq ap_nx
        jmp ap_snd
ap_nx   lda #0
        sta gcnt
        inc gph
        lda gph
        cmp #1
        bne ap_e2
        lda #spr_boss_s/64      ; stage 1: a tiny shape in the distance
        sta SPRPTR+5
        lda #172
        sta bxl
        lda #0
        sta bxh
        lda #106
        sta byv
        lda #$22
        sta cmask
        lda #1
        sta SPCOL+5
        lda #18
        sta thint
        jsr scream
        jmp ap_snd
ap_e2   cmp #2
        bne ap_e3
        lda #spr_boss/64        ; stage 2: closer
        sta SPRPTR+5
        lda #14
        sta thint
        jsr scream
        jmp ap_snd
ap_e3   cmp #3
        bne ap_e4
        lda SPXEX               ; stage 3: huge
        ora #$20
        sta SPXEX
        lda SPYEX
        ora #$20
        sta SPYEX
        lda #161
        sta bxl
        lda #95
        sta byv
        lda #10
        sta thint
        jsr scream
        jmp ap_snd
ap_e4   cmp #4
        bne ap_e5
        lda #<readystr
        sta PTR
        lda #>readystr
        sta PTR+1
        jsr printstr
        lda #$20
        sta SID+11
        jmp ap_snd
ap_e5   lda #<endapp            ; ready: the fight begins
        sta PTR
        lda #>endapp
        sta PTR+1
        jsr printstr
        jsr beginfight
        lda #0
        sta gmode
        lda #1
        sta scrollon
        sta mtimer
        lda #15
        sta SIDVOL
        lda #$20
        sta SID+4
        sta SID+11
        rts
ap_snd  lda gph
        cmp #4
        bcs ap_x
        dec thc
        bne ap_g
        lda thint
        sta thc
        jsr thump
ap_g    lda gcnt
        and #$3f
        asl
        sta SID+7
        lda #2
        sta SID+8
        lda #$21
        sta SID+11
        lda gph                 ; volume swells with every stage
        asl
        clc
        adc #8
        sta SIDVOL
ap_x    lda bpt
        beq ap_y
        dec bpt
        bne ap_y
        lda #$20
        sta SID+4
ap_y    inc gcnt
        jmp cinplace
apdur   .byte 120,60,60,60,70

; ---- boss caught: the hunter gets into a car and drives away
startoutro
        lda #3
        sta gmode
        lda #0
        sta gph
        sta gcnt
        sta scrollon
        lda #$02
        sta cmask
        lda #<blank1214
        sta PTR
        lda #>blank1214
        sta PTR+1
        jmp printstr

outroseq
        lda gph
        bne ot1
        lda pxl                 ; hunter walks to the middle of the street
        sta d1l
        lda pxh
        sta d1h
        lda #160
        sta d2l
        lda #0
        sta d2h
        jsr absdiff
        cmp #3
        bcc ot0b
        lda sgn
        beq ot0r
        sec
        lda pxl
        sbc #3
        sta pxl
        lda pxh
        sbc #0
        sta pxh
        jmp ot_pl
ot0r    clc
        lda pxl
        adc #3
        sta pxl
        jmp ot_pl
ot0b    lda #160
        sta pxl
        lda #0
        sta pxh
        sta carxl
        sta carxh
        sta cdir
        sta gcnt
        lda #1
        sta gph
        jsr carset
        lda #$c2
        sta cmask
ot_pl   jmp cinplace
ot1     cmp #1
        bne ot2
        clc                     ; the car drives in from the left
        lda carxl
        adc #3
        sta carxl
        jsr engine
        lda carxl
        cmp #108
        bcc ot_pl
        lda #2
        sta gph
        lda #0
        sta gcnt
        lda #$20
        sta SID+11
        jsr brake
        jmp ot_pl
ot2     cmp #2
        bne ot3
        inc gcnt
        lda gcnt
        cmp #15
        bcc ot_pl
        cmp #25                 ; hunter walks into the car
        bcs ot2b
        sec
        lda pxl
        sbc #2
        sta pxl
        jmp ot_pl
ot2b    lda #3
        sta gph
        lda #0
        sta gcnt
        lda #$c0                ; hunter is inside
        sta cmask
        jmp ot_pl
ot3     inc gcnt
        lda gcnt
        cmp #20
        bcc ot3p
        lda #1
        sta scrollon
        clc
        lda carxl
        adc #4
        sta carxl
        lda carxh
        adc #0
        sta carxh
        jsr engine
        lda carxh
        beq ot3p
        lda carxl
        cmp #80
        bcc ot3p
        lda #4                  ; car is gone: the level complete screen
        sta gmode
        lda #0
        sta gph
        sta gcnt
        sta scrollon
        lda #$20
        sta SID+11
        jmp carunset
ot3p    jmp cinplace

; ---- level complete screen: level, creatures busted, score; fire / space continues
lcseq
        lda gph
        bne lc1
        jsr levelscreen
        lda #1
        sta gph
        lda #0
        sta gcnt
        rts
lc1     lda gcnt
        cmp #250
        bcs lc1b
        inc gcnt
lc1b    lda gcnt
        and #$20
        beq lc_a
        lda #11
        jmp lc_b
lc_a    lda #1
lc_b    ldx #26
lc_c    sta COLORRAM+20*40+9,x
        dex
        bpl lc_c
        lda demo
        beq lc2
        lda gcnt
        cmp #120
        bcs lc_go
        rts
lc2     lda gcnt
        cmp #30
        bcc lc_x
        lda inf
        beq lc_x
lc_go   lda lvl
        cmp #99
        bcs lc_nl
        inc lvl
lc_nl   jmp startlevel
lc_x    rts

levelscreen
        jsr ecmoff
        lda #0
        sta BORDER
        sta SPENA
        sta MSBX
        lda #$20
        sta SID+4
        sta SID+11
        lda #$80
        sta SID+18
        jsr drawbg
        lda #<lcstr
        sta PTR
        lda #>lcstr
        sta PTR+1
        jsr printstr
        lda #<(SCREEN+4*40+17)  ; level just finished
        sta PTR
        lda #>(SCREEN+4*40+17)
        sta PTR+1
        lda lvl
        jsr put2bin
        lda #<(SCREEN+8*40+24)  ; creatures busted
        sta PTR
        lda #>(SCREEN+8*40+24)
        sta PTR+1
        lda gbh
        ldx gbl
        jsr put4
        lda #<(SCREEN+10*40+24) ; score
        sta PTR
        lda #>(SCREEN+10*40+24)
        sta PTR+1
        lda sch
        ldx scl
        jsr put4
        lda #<(SCREEN+12*40+24) ; high score
        sta PTR
        lda #>(SCREEN+12*40+24)
        sta PTR+1
        lda hsh_tab
        ldx hsl_tab
        jsr put4
        lda #<(SCREEN+16*40+20) ; next level
        sta PTR
        lda #>(SCREEN+16*40+20)
        sta PTR+1
        lda lvl
        clc
        adc #1
        jsr put2bin
        ldx #0                  ; little fanfare
lv_f    ldy fanotes,x
        lda freqlo,y
        sta SID
        lda freqhi,y
        sta SID+1
        lda #$21
        sta SID+4
        ldy #10
lv_w    jsr waitframe
        dey
        bne lv_w
        inx
        cpx #4
        bne lv_f
        lda #$20
        sta SID+4
        rts

; ---- home screen 3: the power-ups explained, with the real icons
ptrfix  lda #spr_ghost/64
        sta SPRPTR
        lda #spr_player/64
        sta SPRPTR+1
        lda #spr_beam/64
        sta SPRPTR+2
        sta SPRPTR+3
        lda #5
        sta SPCOL
        lda #8
        sta SPCOL+1
        lda #7
        sta SPCOL+2
        sta SPCOL+3
        rts

showpinfo
        jsr drawbg
        lda #<pinfoscr
        sta PTR
        lda #>pinfoscr
        sta PTR+1
        jsr printstr
        lda #spr_pwi/64
        sta SPRPTR
        lda #spr_pwe/64
        sta SPRPTR+1
        lda #spr_pwg/64
        sta SPRPTR+2
        lda #spr_pws/64
        sta SPRPTR+3
        ldx #0
pn_l    txa
        asl
        tay
        lda #40
        sta VIC,y
        lda pinfy,x
        sta VIC+1,y
        inx
        cpx #4
        bne pn_l
        lda #0
        sta MSBX
        sta SPXEX
        sta SPYEX
        lda #$0f
        sta SPENA
        rts

pinfoanim
        inc ph
        lda ph
        lsr
        lsr
        and #1
        tax
        lda pwcol,x
        sta SPCOL
        lda pwcol+2,x
        sta SPCOL+1
        lda pwcol+4,x
        sta SPCOL+2
        lda pwcol+6,x
        sta SPCOL+3
        rts

addscore                        ; A = BCD low, X = BCD high
        sei
        sed
        clc
        adc scl
        sta scl
        txa
        adc sch
        sta sch
        cld
        cli
        rts

beginfight
        lda #spr_boss/64
        sta SPRPTR+5
        lda #1
        sta bstate
        lda #3
        sta bhp
        lda #0
        sta binv
        sta tph
        sta bpat
        sta p2act
        lda #1
        sta SPCOL+5
        lda SPXEX               ; boss sprite is doubled in both directions
        ora #$20
        sta SPXEX
        lda SPYEX
        ora #$20
        sta SPYEX
        lda #40
        sta stimer
        lda #60
        sta bncnt
        lda #<bosshud
        sta PTR
        lda #>bosshud
        sta PTR+1
        jsr printstr
        rts

bossupdate
        lda bstate
        bne bu0
        rts
bu0     cmp #1
        bne bu2
        lda gxl                 ; state 1: the boss floats like the ghost
        sec
        sbc #12
        sta bxl
        lda gxh
        sbc #0
        sta bxh
        lda gy
        sec
        sbc #10
        sta byv
        lda binv
        beq bu1a
        dec binv
bu1a    lda fon
        beq bu1x
        lda binv
        bne bu1x
        lda col
        and #$20                ; boss touched ...
        beq bu1x
        lda col
        and #12                 ; ... by the beam
        beq bu1x
        jsr bosshit
bu1x    rts
bu2     cmp #2
        bne bu3
        lda byv                 ; state 2: stunned, sinks to height 150
        cmp #150
        bcs bu2a
        clc
        adc #2
        sta byv
bu2a    lda intrap
        beq bu2x
        lda tcool
        bne bu2x
        jsr trapdeploy
bu2x    rts
bu3     cmp #3
        bne bu4
        jmp trapsuck
bu4     cmp #4
        bne bu5
        dec lcount
        bne bu5
        jmp startoutro
bu5     rts

bosshit dec bhp
        lda #40
        sta binv
        lda #$50                ; +50 per boss hit
        ldx #0
        jsr addscore
        jsr showscore
        lda #90                 ; 35% chance the boss drops a power-up
        jsr maybedrop
        lda #$c8
        sta SID+14
        lda #$1e
        sta SID+15
        lda #$81
        sta SID+18
        lda #10
        sta zap
        lda #12
        sta flash
        lda bhp
        beq bh1
        tax
        lda bhpcol,x
        sta SPCOL+5
        jmp showboss
bh1     lda #2                  ; third hit: stunned!
        sta bstate
        lda #0
        sta pact
        sta p2act
        lda #2                  ; overcooked: red
        sta SPCOL+5
        lda #<stunstr
        sta PTR
        lda #>stunstr
        sta PTR+1
        jsr printstr
        jmp showboss

trapdeploy
        clc
        lda bxl
        adc #12
        sta d1l
        lda bxh
        adc #0
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #24                 ; hunter must stand under the boss
        bcc td1
        lda #30                 ; too far away: the trap fizzles
        sta tcool
        lda #$00
        sta SID+14
        lda #$03
        sta SID+15
        lda #$81
        sta SID+18
        lda #6
        sta zap
        rts
td1     lda pxh                 ; trap lands right next to the hunter
        bne td2
        lda pxl
        cmp #232
        bcs td2
        clc
        adc #24
        sta txl
        lda #0
        sta txh
        jmp td3
td2     sec
        lda pxl
        sbc #24
        sta txl
        lda pxh
        sbc #0
        sta txh
td3     lda #3
        sta bstate
        lda #0
        sta ppact               ; sprite 6 is the trap now
        sta p2act               ; sprite 7 becomes the suction ray
        sta tph
        lda SPYEX               ; ray is double height
        ora #$80
        sta SPYEX
        lda #spr_trapc/64
        sta SPRPTR+6
        lda #<blank34
        sta PTR
        lda #>blank34
        sta PTR+1
        jsr printstr
        lda #$c8                ; clunk
        sta SID+14
        lda #$04
        sta SID+15
        lda #$81
        sta SID+18
        lda #5
        sta zap
        rts

trapsuck
        inc tph
        lda tph
        cmp #15
        bcs ts1
        rts                     ; trap still closed
ts1     lda #spr_trapo/64       ; trap opens, ray shines
        sta SPRPTR+6
        lda #0                  ; rising suction sound on voice 2
        sta SID+7
        lda tph
        lsr
        lsr
        lsr
        clc
        adc #4
        sta SID+8
        lda #$21
        sta SID+11
        lda SPXEX               ; X the boss is pulled toward
        and #$20
        beq ts2
        sec
        lda txl
        sbc #12
        sta d1l
        lda txh
        sbc #0
        sta d1h
        jmp ts3
ts2     lda txl
        sta d1l
        lda txh
        sta d1h
ts3     lda bxl
        sta d2l
        lda bxh
        sta d2h
        jsr absdiff
        cmp #3
        bcc ts5
        lda sgn
        beq ts4
        clc
        lda bxl
        adc #2
        sta bxl
        lda bxh
        adc #0
        sta bxh
        jmp ts5
ts4     sec
        lda bxl
        sbc #2
        sta bxl
        lda bxh
        sbc #0
        sta bxh
ts5     lda SPXEX
        and #$20
        beq ts6
        lda byv                 ; still big: sink, then shrink
        clc
        adc #2
        sta byv
        cmp #185
        bcc ts9
        lda SPXEX
        and #$df
        sta SPXEX
        lda SPYEX
        and #$df
        sta SPYEX
        clc
        lda bxl
        adc #12
        sta bxl
        lda bxh
        adc #0
        sta bxh
        lda byv
        clc
        adc #11
        sta byv
        rts
ts6     lda byv                 ; small now: drop into the trap
        clc
        adc #2
        sta byv
        cmp #224
        bcc ts9
        jmp bosscaptured
ts9     rts

bosscaptured
        lda #4
        sta bstate
        lda #70
        sta lcount
        lda #$20                ; suction off
        sta SID+11
        lda #0                  ; +100 points
        ldx #1
        jsr addscore
        jsr showscore
        lda #$c8
        sta SID+14
        lda #$0a
        sta SID+15
        lda #$81
        sta SID+18
        lda #25
        sta zap
        lda #<capstr
        sta PTR
        lda #>capstr
        sta PTR+1
        jmp printstr

gametimers
        lda tcool
        beq gt1
        dec tcool
gt1     lda bncnt               ; banner text disappears after 60 frames
        beq gt2
        dec bncnt
        bne gt2
        lda #<blank12
        sta PTR
        lda #>blank12
        sta PTR+1
        jsr printstr
gt2     lda pbn                 ; "POWER UP!" banner
        beq gt3
        dec pbn
        bne gt3
        lda #1
        ldx #20
        jsr showmsg
gt3     rts

; ---------------------------------------------------------------------
;  BLASTER POWER METER and POWER-UPS
; ---------------------------------------------------------------------
powerupdate
        lda invt                ; invincible: 250 x 2 frames = 10 seconds
        beq pv0
        lda ph
        and #1
        bne pv1
        dec invt
pv1     lda ph                  ; rainbow hunter
        and #7
        tax
        lda rainbow,x
        sta SPCOL+1
        lda invt
        bne pv0
        lda #8
        sta SPCOL+1
pv0     lda dbt                 ; twin beams: 187 x 4 frames = 12.5 seconds
        beq pv2
        lda ph
        and #3
        bne pv2
        dec dbt
pv2     lda #0
        sta fon
        lda inf
        beq pw_idle
        lda plock
        bne pw_idle
        lda pwr
        beq pw_idle
        lda #1                  ; firing: the beam works and drains power
        sta fon
        lda pwr
        sec
        sbc #PDRAIN
        bcs pw1
        lda #0
pw1     sta pwr
        bne pw_draw
        lda #1                  ; ran dry: overheated, wait for the recharge
        sta plock
        lda #2                  ; red "RECHARGING"
        ldx #0
        jsr showmsg
        jmp pw_draw
pw_idle lda pwr                 ; not firing: recharge 1 per frame
        cmp #PMAX
        bcs pw2
        inc pwr
pw2     lda plock
        beq pw_draw
        lda pwr
        cmp #PUNLOCK
        bcc pw_draw
        lda #0                  ; recharged enough: blaster ready again
        sta plock
        lda #1                  ; erase the message
        ldx #20
        jsr showmsg
pw_draw jmp drawpower

drawpower                       ; 8 cells in the top bezel (columns 30-37), 20 units each
        ldx #2                  ; colour: red low, yellow, green
        lda pwr
        cmp #48
        bcc dp2
        ldx #7
        cmp #96
        bcc dp2
        ldx #5
dp2     lda plock               ; overheated: blinking red/white
        beq dp3
        ldx #2
        lda ph
        and #4
        beq dp3
        ldx #1
dp3     stx pcol
        lda pwr
        sta prem
        ldx #0
dp4     lda prem
        cmp #20
        bcc dp5
        sbc #20
        sta prem
        lda #166                ; full cell
        jmp dp6
dp5     tay
        lda pcell,y             ; partial cell or empty
        ldy #0
        sty prem
dp6     sta SCREEN+30,x
        lda pcol
        sta COLORRAM+30,x
        inx
        cpx #8
        bne dp4
        rts

maybedrop                       ; a catch rolls: 10% I, 20% E, 20% G, 5% star (45% nothing)
        lda ppact
        bne md1                 ; only one at a time
        lda OSC3
        cmp #141
        bcs md1
        ldx #3
        cmp #128
        bcs md2
        ldx #2
        cmp #77
        bcs md2
        ldx #1
        cmp #26
        bcs md2
        ldx #0
md2     stx pwtype
        lda gxl                 ; falls from where the creature was
        sta pwxl
        lda gxh
        sta pwxh
        lda gy
        clc
        adc #12
        sta pwy
        lda OSC3                ; drifts left or right
        and #1
        sta pwdir
        lda #1
        sta ppact
md1     rts

powupd  lda ppact               ; falling power-up: 1 down, 1 sideways every other frame
        bne pu0
        rts
pu0     lda pwy
        clc
        adc #1
        sta pwy
        lda ph
        and #1
        bne pu_c
        lda pwdir
        bne pu_r
        sec
        lda pwxl
        sbc #1
        sta pwxl
        lda pwxh
        sbc #0
        sta pwxh
        bne pu_c
        lda pwxl
        cmp #30
        bcs pu_c
        lda #1                  ; bounce off the left edge
        sta pwdir
        jmp pu_c
pu_r    clc
        lda pwxl
        adc #1
        sta pwxl
        lda pwxh
        adc #0
        sta pwxh
        beq pu_c
        lda pwxl
        cmp #44
        bcc pu_c
        lda #0                  ; bounce off the right edge
        sta pwdir
pu_c    lda pwy
        cmp #208                ; low enough to touch the hunter?
        bcc pu9
        lda pwxl
        sta d1l
        lda pwxh
        sta d1h
        lda pxl
        sta d2l
        lda pxh
        sta d2h
        jsr absdiff
        cmp #20
        bcs pu_m
        jmp getpower
pu_m    lda pwy                 ; missed it: it falls off the screen
        cmp #236
        bcc pu9
        lda #0
        sta ppact
pu9     rts

getpower
        lda #0
        sta ppact
        ldx pwtype
        bne gp1
        lda #250                ; I: invincible for 10 seconds
        sta invt
        jmp gp9
gp1     cpx #1
        bne gp2
        lda #PMAX               ; E: full energy at once
        sta pwr
        lda #0
        sta plock
        jmp gp9
gp2     cpx #2
        bne gp3
        lda #187                ; G: two proton beams
        sta dbt
        jmp gp9
gp3     lda lives               ; star: extra life (max 9)
        cmp #9
        bcs gp9
        inc lives
        jsr showlives
gp9     ldx pwtype
        lda pwmsgc,x
        pha
        lda pwmsgx,x
        tax
        pla
        jsr showmsg
        lda #40
        sta pbn
        lda #$00                ; zing
        sta SID+14
        lda #$30
        sta SID+15
        lda #$81
        sta SID+18
        lda #6
        sta zap
        lda #8
        sta flash
        rts

showmsg                         ; A = colour, X = 0/10/20/..: write a 10 character message
        sta tmpx
        ldy #0
sm_l    lda msgtxt,x
        and #$3f
        sta SCREEN+5*40+15,y
        lda tmpx
        sta COLORRAM+5*40+15,y
        inx
        iny
        cpy #10
        bne sm_l
        rts

; ---------------------------------------------------------------------
;  SLIME ATTACKS.  The creature spits one homing ball.  The boss cycles
;  through 4 patterns:  0 homing  1 spread  2 sniper  3 pincer
; ---------------------------------------------------------------------
spawnorbs
        lda gxl                 ; start at the creature's / boss's mouth
        sta jxl
        lda gxh
        sta jxh
        lda gy
        clc
        adc #10
        ldx bstate
        beq so1
        adc #20
so1     sta jy
        lda #1
        sta pact
        lda ospd
        sta jspd
        lda #0
        sta jmode               ; 0 = homing
        sta p2act
        lda bstate
        cmp #1
        beq so2
        rts                     ; ordinary creature: homing slime only
so2     lda bpat
        and #3
        tax
        inc bpat
        cpx #1
        beq so_spread
        cpx #2
        beq so_snipe
        cpx #3
        beq so_pincer
        rts                     ; pattern 0: homing slime
so_spread                       ; two balls fly apart left and right
        lda #2
        sta jmode
        lda #3
        sta j2mode
        lda ospd
        clc
        adc #1
        sta jspd
        sta j2spd
so_b    lda jxl                 ; second ball starts where the first one does
        sta j2xl
        lda jxh
        sta j2xh
        lda jy
        sta j2y
        lda #1
        sta p2act
        sta j2fresh
        rts
so_snipe                        ; fast ball drops straight onto the hunter
        lda pxl
        sta jxl
        lda pxh
        sta jxh
        lda #1
        sta jmode
        lda ospd
        clc
        adc #2
        sta jspd
        rts
so_pincer                       ; two straight balls either side of the hunter
        lda #1
        sta jmode
        sta j2mode
        lda ospd
        clc
        adc #1
        sta jspd
        sta j2spd
        sec                     ; left ball: hunter X - 40 (not below 30)
        lda pxl
        sbc #40
        sta jxl
        lda pxh
        sbc #0
        sta jxh
        cmp #$ff
        beq so_pl
        lda jxh
        bne so_p2
        lda jxl
        cmp #30
        bcs so_p2
so_pl   lda #30
        sta jxl
        lda #0
        sta jxh
so_p2   clc                     ; right ball: hunter X + 40 (not above 300)
        lda pxl
        adc #40
        sta j2xl
        lda pxh
        adc #0
        sta j2xh
        cmp #2
        bcs so_pr
        cmp #1
        bne so_p3
        lda j2xl
        cmp #44
        bcc so_p3
so_pr   lda #44
        sta j2xl
        lda #1
        sta j2xh
so_p3   lda jy
        sta j2y
        lda #1
        sta p2act
        sta j2fresh
        rts

moveorb2
        lda p2act
        bne mo0
        rts
mo0     lda j2fresh             ; just spawned: stays put this frame
        beq mo1
        lda #0
        sta j2fresh
        rts
mo1     lda j2y
        clc
        adc j2spd
        sta j2y
        cmp #236
        bcc mo2
        lda #0
        sta p2act
        rts
mo2     lda j2mode
        cmp #2
        beq mo3
        cmp #3
        bne mo9
        inc j2xl                ; drifts right
        bne mo9
        inc j2xh
        rts
mo3     lda j2xl                ; drifts left
        bne mo4
        dec j2xh
mo4     dec j2xl
mo9     rts

calcospd
        ldx lvl                 ; slime speed by level: 3,3,4,4,5,5,6...
        dex
        cpx #10
        bcc cs1
        ldx #9
cs1     lda ospdtab,x
        sta ospd
        rts

showprog
        lda #<(SCREEN+49)       ; CAUGHT:00/20  (row 1)
        sta PTR
        lda #>(SCREEN+49)
        sta PTR+1
        lda lvlg
        jsr put2bin
        lda #<(SCREEN+52)
        sta PTR
        lda #>(SCREEN+52)
        sta PTR+1
        lda need
        jmp put2bin

showlvl lda #<(SCREEN+24*40+33)
        sta PTR
        lda #>(SCREEN+24*40+33)
        sta PTR+1
        lda #$80
        sta hmask
        lda lvl
        jsr put2bin
        jmp hmclr

showboss
        lda bhp
        ora #$30
        sta SCREEN+50
        rts

put2bin                         ; A = 0..99 -> two digits at (PTR)
        ldx #0
p2b1    cmp #10
        bcc p2b2
        sbc #10
        inx
        jmp p2b1
p2b2    pha
        txa
        ora #$30
        ora hmask
        ldy #0
        sta (PTR),y
        pla
        ora #$30
        ora hmask
        iny
        sta (PTR),y
        rts

hmclr   lda #0
        sta hmask
        rts

; ---------------------------------------------------------------------
;  GAME OVER
; ---------------------------------------------------------------------
gameover
        lda demo
        beq go1
        jmp enddemo
go1     lda #$c0
        sta D016
        lda #1                  ; only the ghost remains
        sta SPENA
        lda #GB
        sta BORDER
        lda #$20                ; silence voices 1 + 2, stop noise
        sta SID+4
        sta SID+11
        lda #$80
        sta SID+18
        jsr findrank            ; does the score make the Top 10?
        lda #<gostr
        sta PTR
        lda #>gostr
        sta PTR+1
        jsr printstr
        ldx #0                  ; falling jingle
gj1     ldy gonotes,x
        lda freqlo,y
        sta SID
        lda freqhi,y
        sta SID+1
        lda #$21
        sta SID+4
        ldy #20
gj2     jsr waitframe
        dey
        bne gj2
        inx
        cpx #4
        bne gj1
        lda #$20
        sta SID+4
        ldy #90                 ; pause
gj3     jsr waitframe
        dey
        bne gj3
        lda rank
        cmp #255
        beq go2
        jmp nameentry
go2     jmp title

; ---------------------------------------------------------------------
;  Top 10: find the rank of the score, insert a new entry
; ---------------------------------------------------------------------
findrank
        lda sch
        ora scl
        beq fr4                 ; 0 points never qualifies
        ldx #0
fr1     lda sch
        cmp hsh_tab,x
        bcc fr3                 ; below this entry
        bne fr2                 ; above this entry
        lda scl
        cmp hsl_tab,x
        bcc fr3
        beq fr3                 ; ties rank below
fr2     stx rank
        rts
fr3     inx
        cpx #10
        bne fr1
fr4     lda #255
        sta rank
        rts

insertscore
        ldx #9
is1     cpx rank
        beq is3
        lda hsh_tab-1,x         ; shift lower entries down
        sta hsh_tab,x
        lda hsl_tab-1,x
        sta hsl_tab,x
        lda hlv_tab-1,x
        sta hlv_tab,x
        txa
        pha
        asl
        asl
        asl
        tay
        ldx #8
is2     lda names-8,y
        sta names,y
        iny
        dex
        bne is2
        pla
        tax
        dex
        jmp is1
is3     lda sch
        ldx rank
        sta hsh_tab,x
        lda scl
        sta hsl_tab,x
        lda lvl
        sta hlv_tab,x
        txa
        asl
        asl
        asl
        tay
        ldx #0
is4     lda ename,x
        sta names,y
        iny
        inx
        cpx #8
        bne is4
        rts

; ---------------------------------------------------------------------
;  NAME ENTRY (keyboard: type + RETURN;  joystick: up/down/left/right)
; ---------------------------------------------------------------------
nameentry
        jsr ecmoff
        lda #0
        sta BORDER
        jsr sethome
        lda #0
        sta SPENA
        lda #<entryscr
        sta PTR
        lda #>entryscr
        sta PTR+1
        jsr printstr
        lda #<(SCREEN+9*40+24)
        sta PTR
        lda #>(SCREEN+9*40+24)
        sta PTR+1
        lda sch
        ldx scl
        jsr put4
        lda #<(SCREEN+10*40+27)
        sta PTR
        lda #>(SCREEN+10*40+27)
        sta PTR+1
        lda lvl
        jsr put2bin
        ldx #7
        lda #$20
ne1     sta ename,x
        dex
        bpl ne1
        lda #0
        sta npos
        sta ndelay
        sta nready
        sta ncnt
        sta KEYBUF              ; flush the keyboard buffer

nloop   jsr waitframe
        lda KEYPRESS
        cmp #63
        bne nl1
        jmp quit
nl1     lda JOY
        sta joyv
        and #$10                ; fire released?
        beq nfirehi
        lda #1
        sta nready
        jmp nj
nfirehi lda nready              ; fire pressed (ignore until released once)
        beq nj
        jmp nfinish
nj      lda joyv
        and #$0f
        cmp #$0f
        bne nj1
        lda #0
        sta ndelay
        jmp nkey
nj1     lda ndelay
        beq nj2
        dec ndelay
        jmp nkey
nj2     lda #10
        sta ndelay
        lda joyv
        and #1
        bne nj3
        jsr nup
        jmp nkey
nj3     lda joyv
        and #2
        bne nj4
        jsr ndown
        jmp nkey
nj4     lda joyv
        and #8
        bne nj5
        jsr nright
        jmp nkey
nj5     lda joyv
        and #4
        bne nkey
        jsr nleft
nkey    jsr GETIN
        cmp #0
        beq ndraw
        cmp #13                 ; RETURN
        bne nk1
        jmp nfinish
nk1     cmp #$14                ; DEL
        bne nk2
        ldx npos
        lda ename,x
        cmp #$20
        bne ndel1
        cpx #0
        beq ndraw
        dec npos
        ldx npos
ndel1   lda #$20
        sta ename,x
        jmp ndraw
nk2     cmp #$20                ; space
        beq nstore
        cmp #$30                ; digits
        bcc ndraw
        cmp #$3a
        bcc nstore
        cmp #$41                ; letters
        bcc ndraw
        cmp #$5b
        bcs ndraw
nstore  ldx npos
        sta ename,x
        cpx #7
        bcs ndraw
        inc npos
ndraw   ldx #0
nd1     lda ename,x
        cmp #$20
        bne nd2
        lda #45                 ; '-' for an empty slot
        jmp nd3
nd2     and #$3f
nd3     sta SCREEN+14*40+16,x
        lda #13
        cpx npos
        bne nd5
        lda ncnt                ; cursor blinks
        and #$08
        beq nd4
        lda #1
        jmp nd5
nd4     lda #7
nd5     sta COLORRAM+14*40+16,x
        inx
        cpx #8
        bne nd1
        inc ncnt
        lda mute
        bne ne_nm
        jsr hmusic
ne_nm   jmp nloop

nfinish ldx #7                  ; empty name -> default
nf1     lda ename,x
        cmp #$20
        bne nf2
        dex
        bpl nf1
        ldx #7
nf3     lda defname,x
        sta ename,x
        dex
        bpl nf3
nf2     jsr insertscore
        lda rank
        sta hlrow
nrel    jsr waitframe           ; wait until fire / space are released
        lda JOY
        and #$10
        beq nrel
        lda KEYPRESS
        cmp #60
        beq nrel
        lda #0
        sta KEYBUF
        lda #1                  ; show the Hall of Fame with the new entry
        sta scr
        lda #0
        sta rotl
        sta roth
        sta idlel
        sta idleh
        jsr drawhome
        jmp hloop

nup     ldx npos
        lda ename,x
        cmp #$41
        bcc nupA
        clc
        adc #1
        cmp #$5b
        bcc nups
        lda #$20
        jmp nups
nupA    lda #$41
nups    sta ename,x
        rts

ndown   ldx npos
        lda ename,x
        cmp #$20
        beq ndZ
        cmp #$42
        bcc ndsp
        sec
        sbc #1
        jmp nds
ndZ     lda #$5a
        jmp nds
ndsp    lda #$20
nds     sta ename,x
        rts

nright  lda npos
        cmp #7
        bcs nrr
        inc npos
nrr     rts

nleft   lda npos
        beq nll
        dec npos
nll     rts

; ---------------------------------------------------------------------
;  RUN/STOP pressed: tidy up and return to BASIC
; ---------------------------------------------------------------------
quit    lda #0
        sta SPENA
        sta SPYEX
        sta SPXEX
        sta SID+4
        sta SID+11
        sta SID+18
        sta SIDVOL
        sta CURSORBLINK
        sta KEYBUF
        lda #$1b
        sta D011
        lda #$c8
        sta D016
        lda #$15                ; back to the ROM character set
        sta D018
        lda #14
        sta BORDER
        lda #6
        sta BGCOL
        lda #$9a
        jsr CHROUT
        lda #$93
        jsr CHROUT
        rts

; ---------------------------------------------------------------------
;  input: keyboard (A/D/SPACE) + joystick port 2
; ---------------------------------------------------------------------
readinput
        lda #0
        sta inl
        sta inr
        sta inf
        sta intrap
        lda KEYPRESS
        sta key
        cmp #10
        bne ri1
        inc inl
ri1     lda key
        cmp #18
        bne ri2
        inc inr
ri2     lda key
        cmp #60
        bne ri3
        inc inf
ri3     lda JOY
        sta joyv
        and #4
        bne ri4
        inc inl
ri4     lda joyv
        and #8
        bne ri5
        inc inr
ri5     lda joyv
        and #16
        bne ri6
        inc inf
ri6     lda joyv
        and #1                  ; stick up = ghost trap
        bne ri7
        inc intrap
ri7     lda key
        cmp #22                 ; T = ghost trap
        bne ri8
        inc intrap
ri8     rts

; ---------------------------------------------------------------------
;  scrolling New York skyline
; ---------------------------------------------------------------------
copychars                       ; ROM characters -> RAM, then add the tiles
        sei
        lda $01
        and #$fb                ; character ROM visible at $d000
        sta $01
        lda #$00
        sta PTR
        sta PTR2
        lda #$d0
        sta PTR+1
        lda #>CHARSET
        sta PTR2+1
        ldx #8                  ; 2 KB
cc1     ldy #0
cc2     lda (PTR),y
        sta (PTR2),y
        iny
        bne cc2
        inc PTR+1
        inc PTR2+1
        dex
        bne cc1
        lda $01
        ora #$04
        sta $01
        cli
        ldx #0                  ; patch in the building tiles
nt1     lda tilecodes,x
        pha
        asl
        asl
        asl
        sta PTR2
        pla
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>CHARSET
        sta PTR2+1
        stx tmpx
        txa
        asl
        asl
        asl
        tax
        ldy #0
nt2     lda tiledata,x
        sta (PTR2),y
        inx
        iny
        cpy #8
        bne nt2
        ldx tmpx
        inx
        cpx #NTILES
        bne nt1
        lda #<gtiledata         ; graveyard tiles for the home screens
        sta PTR
        lda #>gtiledata
        sta PTR+1
        ldx #0
pg1     lda gtilecodes,x
        pha
        asl
        asl
        asl
        sta PTR2
        pla
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>CHARSET
        sta PTR2+1
        ldy #0
pg2     lda (PTR),y
        sta (PTR2),y
        iny
        cpy #8
        bne pg2
        lda PTR
        clc
        adc #8
        sta PTR
        bcc pg3
        inc PTR+1
pg3     inx
        cpx #NGTILES
        bne pg1
        rts

drawbg                          ; run-length decoded graveyard -> screen + colours
        lda #<bgmap
        sta PTR
        lda #>bgmap
        sta PTR+1
        lda #<SCREEN
        sta PTR2
        lda #>SCREEN
        sta PTR2+1
db1     ldy #0
        lda (PTR),y
        beq db4
        tax
        iny
        lda (PTR),y
        ldy #0
db2     sta (PTR2),y
        iny
        dex
        bne db2
        tya
        clc
        adc PTR2
        sta PTR2
        bcc db3
        inc PTR2+1
db3     lda PTR
        clc
        adc #2
        sta PTR
        bcc db1
        inc PTR+1
        jmp db1
db4     ldx #0                  ; colour of every cell from its tile
db5     ldy SCREEN,x
        lda gcol-64,y
        sta COLORRAM,x
        ldy SCREEN+256,x
        lda gcol-64,y
        sta COLORRAM+256,x
        ldy SCREEN+512,x
        lda gcol-64,y
        sta COLORRAM+512,x
        ldy SCREEN+768,x
        lda gcol-64,y
        sta COLORRAM+768,x
        inx
        bne db5
        rts

ecmon   lda #$5b                ; extended colour text mode
        sta D011
        lda #GB                 ; grey TV bezel
        sta BORDER
        lda #6                  ; building colours: blue, grey, brown
        sta BGCOL1
        lda #11
        sta BGCOL2
        lda #9
        sta BGCOL3
        rts

ecmoff  lda #$1b
        sta D011
        lda #$c8
        sta D016
        rts

drawsky ldx #0                  ; first 40 columns of the skyline
ds1
        lda skyrow0,x
        sta SCREEN+15*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+15*40,x
        lda skyrow1,x
        sta SCREEN+16*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+16*40,x
        lda skyrow2,x
        sta SCREEN+17*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+17*40,x
        lda skyrow3,x
        sta SCREEN+18*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+18*40,x
        lda skyrow4,x
        sta SCREEN+19*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+19*40,x
        lda skyrow5,x
        sta SCREEN+20*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+20*40,x
        lda skyrow6,x
        sta SCREEN+21*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+21*40,x
        lda skyrow7,x
        sta SCREEN+22*40,x
        and #$3f
        tay
        lda ctab,y
        sta COLORRAM+22*40,x
        lda #STREETCODE
        sta SCREEN+23*40,x
        lda #STREETCOL
        sta COLORRAM+23*40,x
        inx
        cpx #40
        beq ds2
        jmp ds1
ds2     rts

scrollsky
        lda scrollon
        beq ssdone
        dec fine
        bpl ssdone
        lda #7
        sta fine
        jsr shiftsky            ; 8 pixels: move the characters one left
ssdone  rts

shiftsky
        ldx #0
sh1
        lda SCREEN+15*40+1,x
        sta SCREEN+15*40,x
        lda COLORRAM+15*40+1,x
        sta COLORRAM+15*40,x
        lda SCREEN+16*40+1,x
        sta SCREEN+16*40,x
        lda COLORRAM+16*40+1,x
        sta COLORRAM+16*40,x
        lda SCREEN+17*40+1,x
        sta SCREEN+17*40,x
        lda COLORRAM+17*40+1,x
        sta COLORRAM+17*40,x
        lda SCREEN+18*40+1,x
        sta SCREEN+18*40,x
        lda COLORRAM+18*40+1,x
        sta COLORRAM+18*40,x
        lda SCREEN+19*40+1,x
        sta SCREEN+19*40,x
        lda COLORRAM+19*40+1,x
        sta COLORRAM+19*40,x
        lda SCREEN+20*40+1,x
        sta SCREEN+20*40,x
        lda COLORRAM+20*40+1,x
        sta COLORRAM+20*40,x
        lda SCREEN+21*40+1,x
        sta SCREEN+21*40,x
        lda COLORRAM+21*40+1,x
        sta COLORRAM+21*40,x
        lda SCREEN+22*40+1,x
        sta SCREEN+22*40,x
        lda COLORRAM+22*40+1,x
        sta COLORRAM+22*40,x
        inx
        cpx #39
        beq sh2
        jmp sh1
sh2     ldy mapnext             ; bring in the next skyline column
        lda skyrow0,y
        sta SCREEN+15*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+15*40+39
        lda skyrow1,y
        sta SCREEN+16*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+16*40+39
        lda skyrow2,y
        sta SCREEN+17*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+17*40+39
        lda skyrow3,y
        sta SCREEN+18*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+18*40+39
        lda skyrow4,y
        sta SCREEN+19*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+19*40+39
        lda skyrow5,y
        sta SCREEN+20*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+20*40+39
        lda skyrow6,y
        sta SCREEN+21*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+21*40+39
        lda skyrow7,y
        sta SCREEN+22*40+39
        and #$3f
        tax
        lda ctab,x
        sta COLORRAM+22*40+39
        iny
        tya
        and #127
        sta mapnext
        rts

waitsky lda RASTER              ; wait until raster line 170
        cmp #170
        bcc waitsky
        rts

waitbot lda RASTER              ; wait until raster line 242
        cmp #242
        bcc waitbot
        rts

; ---------------------------------------------------------------------
;  sound set-ups
; ---------------------------------------------------------------------
setgame lda #0                  ; game: voice 1 riff, 2 beam, 3 noise
        sta SID+4
        sta SID+11
        sta SID+18
        lda #$09
        sta SID+5
        lda #$f4
        sta SID+6
        lda #$00
        sta SID+12
        lda #$f0
        sta SID+13
        lda #$09
        sta SID+19
        sta SID+20
        lda #$c8
        sta SID+14
        lda #$1e
        sta SID+15
        lda #$80
        sta SID+18
        rts

sethome lda #0                  ; home: 3 voice tune
        sta SID+4
        sta SID+11
        sta SID+18
        sta SID+2               ; voice 1 pulse width $0800
        lda #$08
        sta SID+3
        lda #$19                ; lead: pulse
        sta SID+5
        lda #$a6
        sta SID+6
        lda #$05                ; arpeggio: plucked saw
        sta SID+12
        lda #$85
        sta SID+13
        lda #$09                ; bass: triangle
        sta SID+19
        lda #$c5
        sta SID+20
        lda #1
        sta hstimer
        lda #0
        sta hstep
        rts

; ---------------------------------------------------------------------
;  subroutines
; ---------------------------------------------------------------------
waitframe                       ; wait for one full frame (raster line 248)
        lda RASTER
        cmp #$f8
        bne waitframe
wfl2    lda RASTER
        cmp #$f8
        beq wfl2
        rts

printstr                        ; print 0-terminated string at (PTR)
        ldy #0
ps1     lda (PTR),y
        beq psdone
        jsr CHROUT
        iny
        bne ps1
        inc PTR+1
        jmp ps1
psdone  rts

put4                            ; A,X = BCD hi,lo -> 4 digits at (PTR)
        pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        ora hmask
        ldy #0
        sta (PTR),y
        pla
        and #$0f
        ora #$30
        ora hmask
        iny
        sta (PTR),y
        txa
        pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        ora hmask
        iny
        sta (PTR),y
        pla
        and #$0f
        ora #$30
        ora hmask
        iny
        sta (PTR),y
        rts

putname ldy #0                  ; 8 name characters, from names,x to (PTR)
pn1     lda names,x
        and #$3f
        sta (PTR),y
        inx
        iny
        cpy #8
        bne pn1
        rts

showscore
        lda #<(SCREEN+24*40+8)
        sta PTR
        lda #>(SCREEN+24*40+8)
        sta PTR+1
        lda #$80
        sta hmask
        lda sch
        ldx scl
        jsr put4
        jmp hmclr

showhi  lda #<(SCREEN+24*40+19)
        sta PTR
        lda #>(SCREEN+24*40+19)
        sta PTR+1
        lda #$80
        sta hmask
        lda hsh_tab
        ldx hsl_tab
        jsr put4
        jmp hmclr

showlives                       ; little balls on the left of the top bezel
        ldx #0
sl1     lda #160
        cpx lives
        bcs sl2
        lda #191
sl2     sta SCREEN+1,x
        lda #2
        sta COLORRAM+1,x
        inx
        cpx #9
        bne sl1
        rts

hudinit                         ; TV bezel: dark grey bars on rows 0 and 24
        ldx #39
hu1     lda #160
        sta SCREEN,x
        sta SCREEN+24*40,x
        lda #1
        sta COLORRAM,x
        sta COLORRAM+24*40,x
        dex
        bpl hu1
        lda #<ttltxt            ; game title, top middle
        sta PTR
        lda #>ttltxt
        sta PTR+1
        lda #<(SCREEN+11)
        sta PTR2
        lda #>(SCREEN+11)
        sta PTR2+1
        lda #7
        sta tmpx
        jsr puts80
        lda #<lblscore          ; bottom: score, high score, level
        sta PTR
        lda #>lblscore
        sta PTR+1
        lda #<(SCREEN+24*40+2)
        sta PTR2
        lda #>(SCREEN+24*40+2)
        sta PTR2+1
        lda #15
        sta tmpx
        jsr puts80
        lda #<lblhi
        sta PTR
        lda #>lblhi
        sta PTR+1
        lda #<(SCREEN+24*40+16)
        sta PTR2
        lda #>(SCREEN+24*40+16)
        sta PTR2+1
        lda #15
        sta tmpx
        jsr puts80
        lda #<lbllvl
        sta PTR
        lda #>lbllvl
        sta PTR+1
        lda #<(SCREEN+24*40+27)
        sta PTR2
        lda #>(SCREEN+24*40+27)
        sta PTR2+1
        lda #15
        sta tmpx
        jmp puts80

puts80                          ; text at (PTR) -> (PTR2) in bezel colours, colour in tmpx
        ldy #0
p80a    lda (PTR),y
        beq p80b
        and #$3f
        ora #$80
        sta (PTR2),y
        iny
        bne p80a
p80b    lda PTR2+1
        clc
        adc #$d4
        sta PTR2+1
        lda tmpx
p80c    dey
        bmi p80d
        sta (PTR2),y
        jmp p80c
p80d    rts

domusic dec mtimer              ; game riff sequencer, once per frame
        bne musicchk
        ldx mnote
        lda notes,x
        cmp #9
        beq restnote
        tay
        lda freqlo,y
        sta SID
        lda freqhi,y
        sta SID+1
        lda #$21
        sta SID+4
restnote lda durs,x
        sta mtimer
        inx
        cpx #16
        bcc notewrap
        ldx #0
notewrap stx mnote
        rts
musicchk lda mtimer
        cmp #1
        bne musicdone
        lda #$20                ; short gap between notes
        sta SID+4
musicdone rts

hmusic  dec hstimer             ; home tune: 3 voices, 8 frames per step
        bne hm9
        lda #8
        sta hstimer
        ldx hstep
        ldy htr1,x              ; voice 1: lead (pulse)
        cpy #254                ; 254 = hold the current note
        beq hm2
        cpy #255                ; 255 = rest
        beq hm1
        lda hfl,y
        sta SID
        lda hfh,y
        sta SID+1
        lda #$41
        sta SID+4
        jmp hm2
hm1     lda #$40
        sta SID+4
hm2     ldy htr2,x              ; voice 2: arpeggio (saw)
        cpy #255
        beq hm3
        lda hfl,y
        sta SID+7
        lda hfh,y
        sta SID+8
        lda #$21
        sta SID+11
        jmp hm4
hm3     lda #$20
        sta SID+11
hm4     ldy htr3,x              ; voice 3: bass (triangle)
        cpy #255
        beq hm5
        lda hfl,y
        sta SID+14
        lda hfh,y
        sta SID+15
        lda #$11
        sta SID+18
        jmp hm6
hm5     lda #$10
        sta SID+18
hm6     inx
        cpx #128
        bcc hm7
        ldx #0
hm7     stx hstep
        rts
hm9     lda hstimer
        cmp #2
        bne hm10
        lda #$20                ; short gaps for arpeggio and bass
        sta SID+11
        lda #$10
        sta SID+18
hm10    rts

lowend
        * = $4000
; ---------------------------------------------------------------------
;  variables
; ---------------------------------------------------------------------
ph      .byte 0
ph2     .byte 0
gxl     .byte 0
gxh     .byte 0
gy      .byte 0
pxl     .byte 0
pxh     .byte 0
key     .byte 0
joyv    .byte 0
inl     .byte 0
inr     .byte 0
inf     .byte 0
col     .byte 0
spm     .byte 0
scl     .byte 0
sch     .byte 0
zap     .byte 0
flash   .byte 0
ht      .byte 0
mtimer  .byte 0
mnote   .byte 0
lives   .byte 0
hits    .byte 0
pact    .byte 0
jxl     .byte 0
jxh     .byte 0
jy      .byte 0
stimer  .byte 0
rank    .byte 0
demo    .byte 0
dmtl    .byte 0
dmth    .byte 0
fine    .byte 0
mapnext .byte 0
idlel   .byte 0
idleh   .byte 0
rotl    .byte 0
roth    .byte 0
scr     .byte 0
hlrow   .byte 0
hstimer .byte 0
hstep   .byte 0
npos    .byte 0
ndelay  .byte 0
nready  .byte 0
ncnt    .byte 0
ri      .byte 0
tmpx    .byte 0
t1      .byte 0
t2      .byte 0
sgn     .byte 0
d1l     .byte 0
d1h     .byte 0
d2l     .byte 0
d2h     .byte 0
lvl     .byte 1
lvlg    .byte 0
bstate  .byte 0
bhp     .byte 0
binv    .byte 0
bxl     .byte 0
bxh     .byte 0
byv     .byte 0
txl     .byte 0
txh     .byte 0
tph     .byte 0
tcool   .byte 0
lcount  .byte 0
bncnt   .byte 0
ospd    .byte 3
intrap  .byte 0
pwr     .byte 160
plock   .byte 0
fon     .byte 0
ppact   .byte 0
pwxl    .byte 0
pwxh    .byte 0
pwy     .byte 0
pwdir   .byte 0
pbn     .byte 0
pcol    .byte 0
prem    .byte 0
mute    .byte 0
mprev   .byte 0
bpat    .byte 0
jspd    .byte 3
jmode   .byte 0
p2act   .byte 0
j2xl    .byte 0
j2xh    .byte 0
j2y     .byte 0
j2spd   .byte 3
j2mode  .byte 0
j2fresh .byte 0
gmode   .byte 0
gph     .byte 0
gcnt    .byte 0
carxl   .byte 0
carxh   .byte 0
cdir    .byte 0
cmask   .byte 0
scrollon .byte 0
need    .byte 20
gbl     .byte 0
gbh     .byte 0
hmask   .byte 0
pwtype  .byte 0
invt    .byte 0
dbt     .byte 0
ecnt    .byte 0
bpt     .byte 0
thc     .byte 0
thint   .byte 0
gfi     .byte 0
grow    .byte 0
ename   .byte 32,32,32,32,32,32,32,32

; ---------------------------------------------------------------------
;  text screens (PETSCII: $93 clear, $13 home, $11 down, $1d right)
; ---------------------------------------------------------------------
titlescr
        .byte $13,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "STRONKIE'S HUNTERS"
        .byte $13,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "2026"
        .byte $13,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text "A GHOST HUNTING GAME"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$1d,$1d,$1d,$1d,$05
        .text "JOYSTICK (PORT 2) OR A/D + SPACE"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$1d,$1d,$1d,$99
        .text "DODGE THE SLIME - YOU HAVE 3 LIVES"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9f
        .text "GRAB POWER-UPS TO RECHARGE"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$1d,$1d,$1d,$9e
        .text "HIGH SCORE:               LV:  "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$05
        .text "PRESS FIRE OR SPACE"
        .byte 0
hudscr
        .byte $93
        .byte $13,$11,$1d,$1d,$99
        .text "CAUGHT:00/20"
        .byte 0
gostr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1c
        .text "GAME OVER"
        .byte 0
demostr
        .byte $13,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "DEMO - PRESS FIRE TO PLAY"
        .byte 0
hallscr
        .byte $13,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "- HALL OF FAME -"
        .byte $13,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text "TOP 10 GHOST HUNTERS"
        .byte $13,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text " 1.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text " 2.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $9f
        .text " 3.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$9a
        .text " 4.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$9a
        .text " 5.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text " 6.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text " 7.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text " 8.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text " 9.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9a
        .text "10.                 LV   "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "PRESS FIRE OR SPACE TO PLAY"
        .byte 0
entryscr
        .byte $93
        .byte $13,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$9e
        .text "NEW HIGH SCORE!"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$9a
        .text "YOU MADE THE TOP 10 LIST"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "YOUR SCORE: 0000"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "LEVEL REACHED: 00"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "ENTER YOUR NAME"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$1d,$1d,$1d,$1d,$98
        .text "TYPE YOUR NAME AND PRESS RETURN"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$98
        .text "OR USE THE JOYSTICK:"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$98
        .text "UP/DOWN:LETTER RIGHT:NEXT FIRE:OK"
        .byte 0
defname .text "NO NAME "
mutemsg .text "M:MUSIC ON "
        .text "M:MUSIC OFF"
bintscr
        .byte $13,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1c
        .text "WARNING - BOSS AHEAD!"
        .byte $13,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "THE MARSHMALLOW MAULER"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$1d,$1d,$1d,$1d,$1d,$05
        .text "CATCH 20 GHOSTS AND HE ARRIVES"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$99
        .text "HIT HIM 3 TIMES TO STUN HIM"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$1d,$1d,$9f
        .text "THEN DEPLOY THE TRAP: STICK UP OR T"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$1d,$1d,$1c
        .text "ATTACKS: HOMING SPREAD SNIPER PINCER"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$05
        .text "PRESS FIRE OR SPACE"
        .byte 0
bosshud
        .byte $13,$11,$1d,$1d,$1c
        .text "BOSS HP:3   "
        .byte 0
caughtstr
        .byte $13,$11,$1d,$1d,$99
        .text "CAUGHT:00/20"
        .byte 0
warnstr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1c
        .text "WARNING! BOSS GHOST!"
        .byte 0
stunstr
        .byte $13,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "BOSS STUNNED! DEPLOY THE TRAP!"
        .byte $13,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$05
        .text "STAND UNDER IT - PRESS UP OR T"
        .byte 0
capstr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "BOSS CAPTURED!"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$99
        .text "LEVEL COMPLETE!  +100"
        .byte 0
lvlstr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "GET READY - LEVEL "
        .byte 0
blank12
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$05
        .text "                                        "
        .byte 0
blank1214
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$05
        .text "                                        "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$05
        .text "                                        "
        .byte 0
blank34
        .byte $13,$11,$11,$11,$05
        .text "                                                                                "
        .byte 0
msgtxt                  ; 10 character messages (row 5, column 15)
        .text "RECHARGING"
        .text "POWER UP! "
        .text "          "
        .text "INVINCIBLE"
        .text "FULL POWER"
        .text "TWIN BEAMS"
        .text "EXTRA LIFE"

; ---------------------------------------------------------------------
;  Top 10 (BCD scores + 8 character names, initial entries)
; ---------------------------------------------------------------------
hsh_tab
        .byte $06,$04,$03,$02,$02,$01,$01,$00,$00,$00
hsl_tab
        .byte $00,$50,$00,$50,$00,$50,$00,$80,$50,$30
hlv_tab
        .byte 2,2,1,1,1,1,1,1,1,1
names
        .text "STRONKIE"
        .text "SPOOKY  "
        .text "PHANTOM "
        .text "WISPY   "
        .text "SHADOW  "
        .text "GLOOMY  "
        .text "SPECTRE "
        .text "BOOBOO  "
        .text "HAUNTER "
        .text "FLOATY  "

hrow_lo
        .byte $ac,$fc,$4c,$9c,$ec,$3c,$8c,$dc,$2c,$7c
hrow_hi
        .byte $04,$04,$05,$05,$05,$06,$06,$06,$07,$07
hcol_lo
        .byte $a7,$f7,$47,$97,$e7,$37,$87,$d7,$27,$77
hcol_hi
        .byte $d8,$d8,$d9,$d9,$d9,$da,$da,$da,$db,$db

; ---------------------------------------------------------------------
;  game music data
; ---------------------------------------------------------------------
; note frequencies (PAL): A2 C3 D3 E3 G3 A3 C4 D4 E4
freqlo  .byte <1873,<2228,<2500,<2807,<3338,<3747,<4455,<5001,<5614
freqhi  .byte >1873,>2228,>2500,>2807,>3338,>3747,>4455,>5001,>5614
notes   .byte 0,0,1,0,2,3,4,9,0,0,1,0,5,4,3,2
durs    .byte 6,6,6,6,6,6,12,6,6,6,6,6,6,6,6,12
gonotes .byte 8,6,5,0               ; game over jingle: E4 C4 A3 A2
diff    .byte 80,74,68,62,56,50,44,38,32,26,20
lvlpen  .byte 0,4,8,12,16,20,24
ospdtab .byte 3,3,4,4,5,5,6,6,6,6
bhpcol  .byte 2,8,7,1                ; boss colour by HP: toasted gold, orange, red
ppart   .byte 160,170,170,172,172,190,190,190   ; partial power cells
pwcol   .byte 3,1,7,1,13,1,7,1      ; power-up colours: I cyan, E yellow, G green, star yellow (flashing white)
pwmsgx  .byte 30,40,50,60
pwmsgc  .byte 3,7,13,7
rainbow .byte 2,8,7,5,3,6,4,10
needtab .byte 20,25,30,35,40,45,50,55,60
fanotes .byte 5,6,7,8
pinfy   .byte 94,126,158,190
bmask   .byte 4,2,1
pcell   .byte 160,170,170,170,170,172,172,172,172,172,190,190,190,190,190,189,189,189,189,189
bigfont
        .byte 7,1,7,1,7
        .byte 7,1,7,4,7
        .byte 2,6,2,2,7
        .byte 7,4,5,5,7
        .byte 7,5,5,5,7
        .byte 2,2,2,0,2
ttltxt  .text "STRONKIE'S HUNTERS"
        .byte 0
lblscore .text "SCORE:"
        .byte 0
lblhi   .text "HI:"
        .byte 0
lbllvl  .text "LEVEL:"
        .byte 0
appstr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1c
        .text "YOU HEAR THE BOSS APPROACHING..."
        .byte 0
readystr
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$05
        .text "                                        "
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "READY TO FIGHT!"
        .byte 0
endapp
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$05
        .text "                                        "
        .byte 0
lcstr
        .byte $13,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $9e
        .text "LEVEL 00 COMPLETE!"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$05
        .text "GHOSTS BUSTED: 0000"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$05
        .text "YOUR SCORE:    0000"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$9e
        .text "HIGH SCORE:    0000"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$99
        .text "NEXT: LEVEL 00"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "PRESS SPACE OR FIRE TO GO ON"
        .byte 0
pinfoscr
        .byte $13,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$9e
        .text "POWER-UPS"
        .byte $13,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$9f
        .text "CATCH THEM BEFORE THEY LAND!"
        .byte $13,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "INVINCIBLE FOR 10 SECONDS"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$98
        .text "DROP RATE 10%"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$05
        .text "FULL ENERGY AT ONCE"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d
        .byte $1d,$1d,$1d,$98
        .text "DROP RATE 20%"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$1d
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "TWO PROTON BEAMS FOR 15 SECONDS"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$98
        .text "DROP RATE 20%"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$05
        .text "EXTRA LIFE"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$98
        .text "DROP RATE 5%"
        .byte $13,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
        .byte $11,$11,$11,$11,$11,$11,$11,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d
        .byte $1d,$05
        .text "PRESS FIRE OR SPACE"
        .byte 0

; ---------------------------------------------------------------------
;  home screen tune: 4 bars of Am - F - C - E, 3 voices, 32 steps
; ---------------------------------------------------------------------
hfl
        .byte 123,207,133,81,180,197,247,158,10,163,109,103,137,238,59,20
        .byte 161,69,219,207,18,219,119,39,138
hfh
        .byte 5,5,6,7,8,9,10,11,13,14,16,17,19,21,23,26
        .byte 27,29,32,34,39,43,46,52,58
htr1
        .byte 21,254,20,19,254,17,254,255,22,254,21,20,254,19,254,255
        .byte 23,254,21,254,19,254,15,254,18,254,16,254,17,254,254,255
        .byte 17,19,21,254,24,254,23,254,23,254,20,18,254,20,254,255
        .byte 22,254,24,254,22,19,254,255,21,254,16,18,254,20,254,19
        .byte 20,254,22,254,24,254,22,254,21,254,19,254,17,254,19,254
        .byte 19,254,22,254,21,20,254,255,16,254,18,254,21,254,254,255
        .byte 17,254,19,254,21,20,19,18,17,254,14,17,19,254,17,254
        .byte 18,254,20,23,254,20,18,254,17,254,254,254,254,254,254,255
htr2
        .byte 9,11,13,11,9,11,13,11,7,9,11,9,7,9,11,9
        .byte 11,13,15,13,11,13,15,13,13,16,18,16,13,16,18,16
        .byte 9,11,13,11,9,11,13,11,8,10,12,10,8,10,12,10
        .byte 7,9,11,9,7,9,11,9,13,16,20,16,13,16,20,16
        .byte 12,14,17,14,12,14,17,14,9,11,13,11,9,11,13,11
        .byte 7,9,11,9,7,9,11,9,13,16,18,16,13,16,18,16
        .byte 9,11,13,11,9,11,13,11,7,9,11,9,7,9,11,9
        .byte 8,10,12,10,8,10,12,10,9,11,13,11,9,11,13,11
htr3
        .byte 3,254,3,254,3,254,9,254,1,254,1,254,1,254,7,254
        .byte 4,254,4,254,4,254,11,254,0,254,0,254,0,254,6,254
        .byte 3,254,3,9,3,254,3,9,2,254,2,8,2,254,2,8
        .byte 1,254,1,7,1,254,1,7,0,254,0,6,0,254,0,6
        .byte 5,254,254,5,254,254,12,5,3,254,254,3,254,254,9,3
        .byte 1,254,254,1,254,254,7,1,0,254,254,0,254,254,6,0
        .byte 3,254,3,254,3,254,9,254,1,254,1,254,1,254,7,254
        .byte 2,254,2,254,2,254,8,254,3,254,3,254,3,254,9,254

; ---------------------------------------------------------------------
;  skyline: tiles, colours and the 128 column city map (8 rows)
; ---------------------------------------------------------------------
tilecodes
        .byte 0,27,28,29,30,31,34,35,36,37,38,42,44,59,60,61
        .byte 62,63
tiledata
        .byte $00,$66,$66,$00,$00,$66,$66,$00
        .byte $00,$66,$66,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$66,$66,$00
        .byte $00,$7e,$00,$00,$00,$7e,$00,$00
        .byte $ff,$00,$00,$00,$00,$00,$00,$00
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $01,$03,$07,$0f,$1f,$3f,$7f,$ff
        .byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff
        .byte $3c,$7e,$7e,$3c,$24,$24,$24,$00
        .byte $00,$00,$00,$f0,$f0,$00,$00,$00
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
        .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
        .byte $00,$10,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$04,$00,$00,$00
        .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
        .byte $fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc
        .byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
ctab
        .byte 7,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 1,1,1,1,1,1,1,1,1,1,1,7,7,7,15,1
        .byte 1,1,1,1,9,7,1,1,1,1,1,1,1,1,1,1
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
skyrow0
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,32,32,32,31,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,32,60,32,32,32,32,32,32,32,32,32,32,59,32,32
        .byte 32,32,32,32,32,32,32,31,32,32,32,32,32,32,32,32
        .byte 32,60,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,60,32,32,32,32,32,32,32,32,32,32,32,32,60,32
        .byte 32,32,32,60,32,32,32,32,60,32,32,32,32,32,32,32
skyrow1
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,36,32,32,32
        .byte 32,32,32,32,128,32,32,32,32,32,32,32,32,32,36,32
        .byte 32,32,32,32,32,32,32,60,32,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 60,32,32,32,32,32,32,31,32,60,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,32,32,60,32,32,32,32,32,32,32
        .byte 32,60,32,32,32,32,32,32,59,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,59,32,32,32,32,32,32,32,32,32,32
skyrow2
        .byte 59,32,32,32,32,32,32,32,32,32,158,158,158,158,158,158
        .byte 32,32,32,158,157,158,32,32,32,32,32,32,94,94,94,94
        .byte 94,32,32,32,32,32,32,32,32,32,32,32,32,60,32,32
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,59,59,32,32
        .byte 32,32,32,32,32,32,32,38,32,32,32,32,32,32,32,32
        .byte 32,32,60,32,60,32,32,32,59,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,59,32,32,32,32,32,32,32,32,32
        .byte 32,32,32,60,32,32,32,32,36,32,32,32,32,32,32,32
skyrow3
        .byte 32,32,32,32,32,32,32,32,32,32,128,157,156,128,156,128
        .byte 60,32,32,157,156,156,32,32,32,32,32,32,93,64,64,64
        .byte 91,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,32,59,32,32,32,60,32,32,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,34,38,35,59,32,32,32,32,222,222
        .byte 222,222,222,222,32,32,60,32,32,94,94,94,94,32,32,32
        .byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
        .byte 32,222,222,222,222,32,32,32,222,222,222,222,32,32,32,32
skyrow4
        .byte 32,32,32,32,32,32,32,32,32,32,160,156,155,155,155,128
        .byte 32,32,158,157,160,157,158,32,32,32,32,32,64,64,93,64
        .byte 64,32,32,32,32,36,32,32,32,32,32,32,32,32,32,32
        .byte 32,32,32,32,32,32,36,32,94,94,94,158,158,158,32,32
        .byte 32,32,32,32,32,32,224,221,221,32,32,32,32,32,192,192
        .byte 192,192,220,221,32,32,32,32,32,93,64,64,96,32,32,32
        .byte 32,222,222,222,222,222,222,32,32,32,32,32,32,32,32,32
        .byte 32,221,221,192,221,32,32,32,192,221,221,221,32,222,222,32
skyrow5
        .byte 94,94,94,94,94,222,222,222,222,222,155,128,128,128,128,156
        .byte 32,32,156,155,157,128,155,32,32,32,32,32,93,92,64,64
        .byte 93,222,222,222,222,158,158,158,158,36,32,32,32,32,32,32
        .byte 158,158,158,158,32,94,94,94,91,96,64,128,128,128,32,32
        .byte 32,32,36,32,36,32,224,219,221,32,32,36,32,32,220,219
        .byte 192,192,220,192,32,222,222,222,222,64,91,93,93,32,32,32
        .byte 32,221,192,224,220,224,219,32,32,32,32,32,222,222,222,222
        .byte 222,219,221,192,221,32,32,32,220,192,220,221,32,224,219,32
skyrow6
        .byte 64,93,93,64,92,192,220,192,192,219,128,128,157,155,157,155
        .byte 32,32,156,128,128,128,157,32,158,158,158,158,96,92,93,64
        .byte 93,224,219,192,192,128,128,155,128,94,94,94,94,94,94,94
        .byte 157,128,155,156,32,93,64,64,96,93,64,157,128,128,32,158
        .byte 158,158,158,94,94,32,192,221,221,32,222,222,222,222,224,219
        .byte 192,219,221,192,32,219,219,192,221,92,64,91,64,94,94,94
        .byte 94,192,192,220,220,219,221,94,94,94,94,32,221,219,221,224
        .byte 221,192,221,221,192,158,158,158,192,221,224,220,32,224,221,32
skyrow7
        .byte 96,91,92,64,93,224,219,219,221,219,128,128,157,157,128,157
        .byte 32,32,157,155,128,157,128,32,156,128,157,156,93,64,64,92
        .byte 93,220,219,221,219,128,157,128,128,64,93,92,96,64,93,64
        .byte 156,156,155,156,32,64,92,64,64,64,92,157,128,128,32,157
        .byte 128,128,155,96,64,32,192,221,192,32,192,219,224,220,224,221
        .byte 221,221,192,224,32,192,220,221,221,64,92,93,64,93,93,92
        .byte 64,192,221,219,192,192,192,92,64,91,91,32,220,192,224,192
        .byte 221,224,221,192,224,128,155,128,219,192,192,219,32,224,219,32

; ghost floating paths (sine tables)
sintab_x
        .byte 120,123,126,129,132,135,138,141,143,146,149,152,155,158,160,163
        .byte 166,169,171,174,177,179,182,184,187,189,191,194,196,198,201,203
        .byte 205,207,209,211,213,215,216,218,220,221,223,224,226,227,228,230
        .byte 231,232,233,234,235,236,236,237,238,238,239,239,239,240,240,240
        .byte 240,240,240,240,239,239,239,238,238,237,236,236,235,234,233,232
        .byte 231,230,228,227,226,224,223,221,220,218,216,215,213,211,209,207
        .byte 205,203,201,198,196,194,191,189,187,184,182,179,177,174,171,169
        .byte 166,163,160,158,155,152,149,146,143,141,138,135,132,129,126,123
        .byte 120,117,114,111,108,105,102,99,97,94,91,88,85,82,80,77
        .byte 74,71,69,66,63,61,58,56,53,51,49,46,44,42,39,37
        .byte 35,33,31,29,27,25,24,22,20,19,17,16,14,13,12,10
        .byte 9,8,7,6,5,4,4,3,2,2,1,1,1,0,0,0
        .byte 0,0,0,0,1,1,1,2,2,3,4,4,5,6,7,8
        .byte 9,10,12,13,14,16,17,19,20,22,24,25,27,29,31,33
        .byte 35,37,39,42,44,46,49,51,53,56,58,61,63,66,69,71
        .byte 74,77,80,82,85,88,91,94,97,99,102,105,108,111,114,117
sintab_y
        .byte 116,117,117,118,118,119,120,120,121,121,122,123,123,124,124,125
        .byte 126,126,127,127,128,128,129,129,130,130,131,131,132,132,133,133
        .byte 134,134,135,135,135,136,136,136,137,137,137,138,138,138,139,139
        .byte 139,139,140,140,140,140,140,140,141,141,141,141,141,141,141,141
        .byte 141,141,141,141,141,141,141,141,141,140,140,140,140,140,140,139
        .byte 139,139,139,138,138,138,137,137,137,136,136,136,135,135,135,134
        .byte 134,133,133,132,132,131,131,130,130,129,129,128,128,127,127,126
        .byte 126,125,124,124,123,123,122,121,121,120,120,119,118,118,117,117
        .byte 116,115,115,114,114,113,112,112,111,111,110,109,109,108,108,107
        .byte 106,106,105,105,104,104,103,103,102,102,101,101,100,100,99,99
        .byte 98,98,97,97,97,96,96,96,95,95,95,94,94,94,93,93
        .byte 93,93,92,92,92,92,92,92,91,91,91,91,91,91,91,91
        .byte 91,91,91,91,91,91,91,91,91,92,92,92,92,92,92,93
        .byte 93,93,93,94,94,94,95,95,95,96,96,96,97,97,97,98
        .byte 98,99,99,100,100,101,101,102,102,103,103,104,104,105,105,106
        .byte 106,107,108,108,109,109,110,111,111,112,112,113,114,114,115,115

gtilecodes
        .byte 64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79
        .byte 80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95
        .byte 96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111
        .byte 112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127
        .byte 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
        .byte 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
        .byte 160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
        .byte 176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
        .byte 192,193,194,195,196,197,198,199,200,201,202,203,204,205
gtiledata
        .byte $00,$00,$04,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$02,$00
        .byte $00,$00,$00,$20,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$03,$03
        .byte $00,$00,$07,$3f,$7f,$ff,$ff,$ff
        .byte $00,$20,$ff,$ff,$ff,$ff,$ff,$fd
        .byte $00,$00,$00,$e0,$f0,$f8,$fe,$fe
        .byte $02,$87,$cf,$ff,$7f,$3b,$11,$00
        .byte $40,$e1,$f3,$ff,$fe,$dc,$88,$00
        .byte $00,$00,$00,$00,$00,$10,$00,$00
        .byte $07,$0f,$1f,$1f,$1f,$3f,$3f,$3f
        .byte $ff,$ef,$83,$83,$01,$83,$83,$ef
        .byte $f8,$f0,$f8,$fd,$ff,$ff,$ff,$ff
        .byte $ff,$7f,$ff,$ff,$ff,$fb,$f1,$e0
        .byte $00,$80,$c0,$c0,$c0,$e0,$e0,$e0
        .byte $3f,$3f,$7f,$3f,$3f,$3f,$3f,$3f
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$fe,$fe
        .byte $f1,$fb,$ff,$ff,$df,$07,$03,$03
        .byte $e0,$e0,$f0,$e0,$e0,$e0,$e0,$e0
        .byte $00,$00,$00,$06,$06,$06,$06,$06
        .byte $1f,$1f,$1f,$0f,$07,$03,$03,$00
        .byte $f7,$e3,$c1,$e3,$f7,$ff,$ff,$ff
        .byte $fc,$fe,$fe,$ff,$ff,$ff,$ff,$ff
        .byte $01,$03,$03,$07,$df,$fe,$fe,$f8
        .byte $c0,$c0,$c0,$80,$00,$00,$00,$00
        .byte $07,$03,$03,$03,$03,$03,$03,$03
        .byte $00,$00,$00,$00,$00,$00,$01,$83
        .byte $00,$00,$00,$06,$1e,$7c,$f0,$c0
        .byte $7f,$3f,$07,$00,$00,$00,$00,$00
        .byte $ff,$ff,$ff,$20,$00,$00,$00,$00
        .byte $f0,$e0,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$03,$03,$03,$03
        .byte $00,$00,$00,$00,$e0,$e0,$e0,$e0
        .byte $01,$01,$01,$01,$03,$07,$07,$0f
        .byte $8f,$be,$f8,$e0,$c0,$c0,$80,$00
        .byte $03,$03,$03,$03,$03,$03,$03,$63
        .byte $e0,$e0,$e0,$e0,$e0,$e1,$e1,$e3
        .byte $1f,$1e,$3c,$7c,$f8,$f0,$e0,$c0
        .byte $00,$60,$70,$30,$38,$18,$1c,$0c
        .byte $63,$63,$63,$63,$63,$63,$63,$73
        .byte $e7,$e7,$ef,$ff,$fe,$fc,$f8,$f0
        .byte $c0,$80,$00,$00,$00,$00,$00,$00
        .byte $02,$87,$cf,$ff,$7f,$3b,$11,$01
        .byte $40,$e1,$f3,$ff,$fe,$dc,$88,$80
        .byte $00,$60,$70,$30,$38,$1c,$0e,$06
        .byte $0e,$06,$07,$03,$01,$01,$00,$00
        .byte $00,$7e,$7e,$fe,$fe,$fe,$fe,$fe
        .byte $37,$37,$37,$37,$37,$3f,$3f,$3f
        .byte $f0,$e0,$e0,$e0,$c0,$c0,$c0,$c0
        .byte $03,$03,$07,$06,$06,$0e,$0c,$0c
        .byte $80,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$18,$18,$18,$18,$18
        .byte $07,$03,$01,$01,$00,$00,$00,$00
        .byte $00,$80,$80,$c0,$e0,$70,$30,$3c
        .byte $7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e
        .byte $00,$0c,$1c,$18,$38,$70,$60,$e0
        .byte $3f,$1f,$1f,$1f,$0f,$0f,$0f,$07
        .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
        .byte $00,$00,$00,$00,$00,$00,$00,$03
        .byte $00,$00,$00,$03,$07,$3e,$7c,$e0
        .byte $1c,$38,$78,$e0,$c0,$00,$00,$00
        .byte $1c,$0c,$0c,$0c,$0c,$0c,$0c,$0e
        .byte $1e,$1f,$0f,$07,$03,$01,$00,$00
        .byte $00,$00,$80,$c0,$e0,$f0,$f8,$7c
        .byte $7f,$7f,$7f,$7f,$ff,$fe,$fe,$fe
        .byte $c0,$80,$80,$00,$00,$00,$00,$00
        .byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f
        .byte $e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0
        .byte $00,$00,$00,$00,$00,$01,$03,$07
        .byte $07,$1e,$3c,$7c,$f8,$f0,$e0,$c0
        .byte $c0,$00,$00,$00,$00,$00,$00,$00
        .byte $06,$06,$06,$06,$07,$03,$00,$00
        .byte $00,$00,$00,$00,$80,$e0,$f0,$3c
        .byte $3c,$1e,$1f,$0f,$07,$03,$01,$00
        .byte $fe,$fc,$fc,$fc,$fc,$fc,$fc,$fc
        .byte $e0,$e0,$e0,$e0,$e0,$e0,$e1,$e3
        .byte $0f,$1f,$3e,$7c,$78,$f0,$f0,$e0
        .byte $1e,$07,$03,$00,$00,$00,$00,$00
        .byte $00,$80,$c0,$f0,$7c,$1f,$07,$07
        .byte $00,$00,$00,$00,$00,$00,$80,$c0
        .byte $00,$00,$00,$00,$01,$01,$01,$01
        .byte $fc,$fc,$fc,$fc,$ff,$ff,$ff,$ff
        .byte $e7,$ef,$ff,$fe,$fc,$f8,$f0,$e0
        .byte $00,$00,$00,$00,$00,$00,$00,$01
        .byte $00,$60,$60,$e0,$c0,$c0,$c0,$c0
        .byte $03,$01,$00,$00,$00,$00,$00,$00
        .byte $e0,$f0,$f8,$7c,$3e,$1f,$0f,$07
        .byte $01,$01,$01,$01,$01,$01,$81,$e1
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        .byte $00,$00,$00,$00,$00,$07,$1f,$3f
        .byte $00,$00,$00,$00,$00,$e0,$ff,$3f
        .byte $01,$01,$03,$03,$03,$03,$c7,$fe
        .byte $80,$80,$80,$00,$00,$00,$00,$00
        .byte $f1,$f9,$7d,$3f,$1f,$0f,$07,$03
        .byte $00,$01,$07,$0f,$3f,$7e,$fc,$f0
        .byte $fe,$f8,$f0,$c0,$80,$00,$00,$00
        .byte $7e,$00,$00,$00,$00,$00,$00,$00
        .byte $01,$01,$01,$01,$01,$01,$01,$01
        .byte $ef,$ff,$ff,$fc,$f8,$e0,$e0,$e0
        .byte $e0,$80,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$01,$1f,$1f,$00
        .byte $00,$00,$00,$0f,$ff,$f8,$00,$00
        .byte $00,$00,$00,$80,$e0,$f8,$3e,$0f
        .byte $01,$01,$01,$01,$01,$01,$01,$81
        .byte $1f,$1f,$1f,$1f,$1f,$7f,$7f,$7f
        .byte $03,$00,$00,$00,$00,$00,$00,$00
        .byte $e1,$f9,$3f,$0f,$03,$01,$01,$01
        .byte $3f,$1f,$1f,$1f,$1f,$1f,$1f,$1f
        .byte $00,$00,$00,$00,$03,$0f,$1f,$38
        .byte $70,$70,$70,$70,$fe,$ff,$ff,$f8
        .byte $00,$00,$01,$03,$07,$8f,$cf,$ef
        .byte $00,$00,$f0,$f8,$fc,$fe,$9e,$9e
        .byte $00,$00,$00,$01,$03,$03,$07,$07
        .byte $00,$00,$7c,$ff,$ff,$ff,$ff,$e7
        .byte $00,$00,$00,$00,$80,$80,$c1,$c3
        .byte $07,$07,$07,$07,$3f,$ff,$ff,$8f
        .byte $01,$01,$01,$01,$e1,$f9,$fd,$8f
        .byte $3d,$3d,$7f,$3f,$38,$3c,$1f,$0f
        .byte $fd,$fd,$ff,$ff,$00,$71,$ff,$ff
        .byte $ec,$ec,$ff,$ef,$ef,$ef,$cf,$8f
        .byte $02,$02,$9e,$9e,$9e,$9e,$9e,$fe
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $e7,$00,$00,$e7,$e7,$e7,$e7,$e7
        .byte $c3,$c3,$c7,$c3,$c3,$c3,$c1,$c0
        .byte $df,$df,$ff,$ff,$80,$c7,$ff,$ff
        .byte $df,$df,$ff,$ff,$0f,$1f,$fd,$f9
        .byte $1f,$1f,$5f,$5f,$df,$ff,$ff,$ff
        .byte $e0,$e8,$e8,$fa,$fe,$ff,$ff,$ff
        .byte $00,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $03,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $fe,$28,$48,$5a,$de,$ff,$ff,$ff
        .byte $0f,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $fe,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $07,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $ff,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $c0,$08,$48,$5a,$de,$ff,$ff,$ff
        .byte $3f,$0a,$48,$5a,$de,$ff,$ff,$ff
        .byte $e1,$09,$49,$5b,$df,$ff,$ff,$ff
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        .byte $ff,$ff,$ff,$df,$ff,$fd,$ff,$ff
        .byte $e9,$4f,$49,$49,$49,$00,$00,$00
gcol
        .byte 1,1,1,7,7,7,7,4,4,1,7,7,7,7,7,7
        .byte 7,7,7,7,9,7,7,7,7,7,9,9,9,7,7,7
        .byte 9,9,9,9,9,9,9,9,9,9,9,4,4,9,9,9
        .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
        .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
        .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
        .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,8,8,12
        .byte 12,12,12,12,8,8,8,8,12,12,12,12,12,8,8,5
        .byte 5,5,5,5,5,5,5,5,5,5,5,5,9,7,0,0
        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
bgmap
        .byte 7,32,1,64,4,32,1,65,6,32,1,66,4,32,1,64
        .byte 5,32,1,64,5,32,1,64,5,32,1,66,46,32,1,65
        .byte 21,32,1,66,1,32,1,67,1,68,1,69,1,70,6,32
        .byte 1,71,1,72,9,32,1,73,11,32,1,66,1,71,1,72
        .byte 4,32,1,74,1,75,1,76,1,77,1,78,6,32,1,73
        .byte 8,32,1,73,7,32,1,65,6,32,1,65,4,32,1,79
        .byte 1,80,1,81,1,82,1,83,4,32,1,84,30,32,1,85
        .byte 1,86,1,87,1,88,1,89,3,32,1,66,1,90,1,91
        .byte 1,92,29,32,1,93,1,94,1,95,3,32,1,96,1,97
        .byte 1,98,1,99,36,32,1,100,1,101,1,102,34,32,1,103
        .byte 2,32,1,104,1,105,1,106,2,32,1,107,1,108,26,32
        .byte 1,73,1,32,1,109,1,32,1,110,1,111,1,32,1,112
        .byte 1,113,3,32,1,114,1,115,26,32,1,116,1,32,1,117
        .byte 1,118,1,32,1,119,1,120,1,121,1,122,1,32,1,123
        .byte 1,124,1,125,27,32,1,126,2,32,1,127,1,128,1,129
        .byte 1,130,1,131,1,132,1,133,1,134,1,135,28,32,1,136
        .byte 1,137,2,32,1,138,1,139,1,32,1,131,1,140,1,141
        .byte 1,115,30,32,1,142,1,143,1,144,1,145,1,146,1,32
        .byte 1,131,1,147,1,106,2,32,1,148,1,149,28,32,1,150
        .byte 1,151,1,152,1,153,1,32,1,131,1,132,1,32,1,154
        .byte 1,155,1,156,1,157,29,32,1,150,1,158,1,153,1,32
        .byte 1,131,1,140,1,159,1,160,1,32,1,161,31,32,1,162
        .byte 1,153,1,32,1,131,1,163,1,164,31,32,1,165,1,166
        .byte 1,167,1,168,1,153,1,32,1,169,1,132,34,32,1,170
        .byte 1,171,1,153,1,32,1,172,1,132,35,32,1,162,1,153
        .byte 1,32,1,131,1,132,35,32,1,162,1,153,1,32,1,131
        .byte 1,132,1,32,1,173,1,174,1,175,1,176,26,32,1,177
        .byte 1,178,1,179,1,180,1,181,1,153,1,32,1,131,1,132
        .byte 1,32,1,182,1,183,1,184,1,185,26,32,1,186,1,187
        .byte 1,188,1,189,1,190,1,153,1,32,1,191,1,192,1,193
        .byte 1,194,1,195,1,196,1,197,26,193,1,198,1,199,1,200
        .byte 1,201,1,202,1,203,1,193,40,204,0

; ---------------------------------------------------------------------
;  INTRO SCREEN: the GHOST HUNTERS logo as a C64 bitmap picture,
;  shown for 10 seconds (fire / any key skips it after 1 second).
;  The picture is run-length packed; it is unpacked into VIC bank 3
;  (bitmap $e000, colours $c000), which the game does not use.
; ---------------------------------------------------------------------
intro   jsr sethome             ; start the home tune
        lda #0
        sta SPENA
        sta BORDER
        sta BGCOL
        lda #$0b
        sta D011                ; screen off while unpacking
        lda #<introbm
        sta PTR
        lda #>introbm
        sta PTR+1
        lda #0
        sta PTR2
        lda #$e0
        sta PTR2+1
        jsr unrle
        lda #<introscr
        sta PTR
        lda #>introscr
        sta PTR+1
        lda #0
        sta PTR2
        lda #$c0
        sta PTR2+1
        jsr unrle
        lda $dd00
        and #$fc                ; VIC bank 3 = $c000-$ffff
        sta $dd00
        lda #$08                ; screen $c000, bitmap $e000
        sta D018
        lda #$c8
        sta D016
        lda #$3b                ; bitmap mode on
        sta D011
        lda #0
        sta introtl
        sta introth
iloop   jsr waitframe
        lda mute
        bne in1
        jsr hmusic
in1     inc introtl
        bne in2
        inc introth
in2     lda introth
        cmp #1                  ; 500 frames = 10 seconds
        bcc in3
        lda introtl
        cmp #$f4
        bcs idone
in3     lda introth             ; skip allowed after 60 frames
        bne in4
        lda introtl
        cmp #60
        bcc iloop
in4     lda JOY
        and #$10
        beq idone
        lda KEYPRESS
        cmp #64
        bne idone
        jmp iloop
idone   lda #$0b
        sta D011
        lda $dd00
        ora #$03                ; back to VIC bank 0
        sta $dd00
        lda #$1e
        sta D018
        lda #$c8
        sta D016
        lda #$1b
        sta D011
        lda #0
        sta SID+4
        sta SID+11
        sta SID+18
irel    jsr waitframe           ; wait until fire / keys are released
        lda JOY
        and #$10
        beq irel
        lda KEYPRESS
        cmp #64
        bne irel
        lda #0
        sta KEYBUF
        rts

urget   ldy #0
        lda (PTR),y
        inc PTR
        bne ug1
        inc PTR+1
ug1     cmp #0
        rts
urput   ldy #0
        sta (PTR2),y
        inc PTR2
        bne up1
        inc PTR2+1
up1     rts
unrle   jsr urget
        beq urend
        bmi urrun
        sta urn
ul1     jsr urget
        jsr urput
        dec urn
        bne ul1
        jmp unrle
urrun   and #$7f
        sta urn
        jsr urget
ur2     jsr urput
        dec urn
        bne ur2
        jmp unrle
urend   rts
urn     .byte 0
introtl .byte 0
introth .byte 0
introbm
        .byte 255,0,255,0,255,0,255,0,255,0,255,0,255,0,255,0
        .byte 255,0,255,0,255,0,183,0,4,4,0,8,18,255,0,213
        .byte 0,20,1,3,15,31,0,0,3,63,255,248,192,1,0,0
        .byte 254,255,255,0,0,248,131,0,5,231,255,255,28,4,131,0
        .byte 5,224,240,240,112,112,131,0,5,127,127,255,224,224,131,0
        .byte 131,255,133,0,5,254,254,255,7,7,131,0,5,7,15,15
        .byte 28,28,131,0,131,255,133,0,131,255,133,0,1,192,132,224
        .byte 131,0,5,1,3,14,62,126,131,0,1,108,131,126,4,108
        .byte 0,0,252,132,255,1,95,131,0,5,128,224,248,254,255,142
        .byte 0,18,1,1,0,0,1,15,63,124,240,192,0,0,254,255
        .byte 255,0,0,120,131,0,5,199,255,255,60,8,131,0,5,207
        .byte 255,255,252,252,131,0,131,255,133,0,131,255,133,0,131,255
        .byte 133,0,131,255,133,0,5,248,252,254,14,14,227,0,25,1
        .byte 3,3,7,14,60,120,224,192,192,129,3,3,15,31,126,120
        .byte 224,192,192,128,255,255,7,1,133,0,7,128,192,224,240,112
        .byte 56,56,134,112,5,48,48,252,127,31,133,3,2,0,0,134
        .byte 129,3,127,254,248,133,192,3,15,15,3,133,0,3,128,224
        .byte 240,133,112,3,15,31,31,133,24,32,224,193,3,7,15,31
        .byte 31,63,254,252,252,248,248,224,192,196,0,0,8,28,60,62
        .byte 60,28,1,33,3,3,7,39,47,79,132,255,17,231,227,195
        .byte 193,128,192,224,240,248,252,252,254,3,7,15,14,14,131,28
        .byte 4,131,7,15,14,132,28,4,255,255,7,1,133,0,7,128
        .byte 192,224,224,112,112,56,131,252,133,124,11,3,15,31,28,56
        .byte 120,112,224,248,252,248,133,24,131,15,133,14,8,240,248,252
        .byte 30,14,7,3,3,134,14,2,142,142,224,0,5,14,12,28
        .byte 28,24,131,56,131,7,1,6,132,14,144,0,2,28,28,131
        .byte 14,3,7,7,3,133,48,3,240,240,192,136,3,136,129,135
        .byte 192,1,255,135,0,1,255,135,112,1,240,136,24,3,63,127
        .byte 127,132,255,7,252,130,130,8,0,64,128,137,0,14,12,31
        .byte 31,63,63,126,126,252,252,128,128,0,8,4,131,0,2,254
        .byte 255,131,127,3,63,61,113,132,28,9,156,142,142,135,14,14
        .byte 7,7,1,134,0,6,192,248,254,63,7,56,131,28,16,15
        .byte 15,199,240,124,125,127,127,224,224,192,0,224,224,192,128,132
        .byte 0,136,24,136,14,131,1,133,0,4,142,254,252,252,228,0
        .byte 1,56,134,48,1,56,134,12,2,14,14,139,0,5,31,63
        .byte 63,112,112,131,0,131,255,133,0,131,255,2,1,1,131,3
        .byte 1,131,132,195,1,129,131,128,132,129,1,255,131,0,131,255
        .byte 2,192,255,131,0,131,255,2,0,240,131,0,131,240,22,112
        .byte 24,25,29,33,48,32,16,49,248,240,192,128,1,6,2,255
        .byte 0,0,8,16,8,131,0,4,15,15,31,31,131,63,18,126
        .byte 248,248,240,240,224,224,192,192,128,32,8,1,1,0,1,0
        .byte 32,131,0,8,63,127,63,127,199,195,1,64,132,128,9,0
        .byte 192,224,248,126,31,15,1,1,132,0,8,128,240,252,252,62
        .byte 15,7,1,133,0,6,128,192,224,224,112,112,136,0,135,24
        .byte 1,28,136,14,240,0,131,56,3,24,28,28,133,14,5,6
        .byte 7,7,3,3,134,0,5,128,128,63,63,31,134,0,3,192
        .byte 224,224,132,112,3,15,63,63,133,48,2,195,195,134,3,136
        .byte 129,136,192,136,0,136,112,1,28,135,24,2,255,255,131,127
        .byte 19,63,63,31,0,0,128,128,192,193,225,243,126,124,252,252
        .byte 248,248,240,240,140,0,6,1,3,3,7,127,127,131,255,8
        .byte 254,252,252,159,191,63,49,57,131,56,2,0,128,131,192,6
        .byte 224,224,112,127,15,3,134,0,6,192,224,224,112,112,48,137
        .byte 56,136,0,136,28,136,14,240,0,5,7,7,3,3,1,131
        .byte 0,15,1,1,128,192,224,240,120,62,192,224,240,120,62,31
        .byte 7,133,0,4,1,255,255,254,131,112,5,96,224,224,128,0
        .byte 135,48,1,240,132,3,4,7,127,255,224,133,129,131,0,132
        .byte 192,4,240,254,127,7,133,0,3,15,15,30,132,112,4,240
        .byte 240,224,0,132,24,13,30,31,15,0,31,15,7,3,1,192
        .byte 224,224,251,133,255,7,127,63,240,228,232,224,240,131,255,131
        .byte 0,2,1,15,131,255,3,15,63,127,132,255,9,252,248,248
        .byte 240,224,192,128,0,0,136,56,7,112,56,60,30,15,7,1
        .byte 133,0,20,128,255,255,126,56,48,112,112,224,225,195,7,56
        .byte 56,112,112,224,224,192,128,133,0,3,15,15,14,132,28,4
        .byte 248,248,240,0,132,14,3,15,7,3,133,0,4,192,248,252
        .byte 28,191,0,1,255,135,0,1,255,135,0,1,224,135,0,1
        .byte 31,135,0,1,255,135,0,1,252,135,0,4,31,31,7,3
        .byte 132,0,11,255,128,224,255,127,15,0,0,252,0,0,131,255
        .byte 13,0,0,3,7,63,255,248,128,0,0,255,240,192,133,0
        .byte 5,255,224,255,255,127,131,0,2,255,0,131,255,131,0,5
        .byte 252,7,255,255,254,132,0,4,28,31,15,15,131,0,2,1
        .byte 0,131,255,131,0,2,255,0,131,255,131,0,1,255,131,224
        .byte 1,192,131,0,3,255,15,3,133,0,132,255,1,15,131,0
        .byte 132,255,1,240,131,0,3,255,248,224,133,0,1,255,135,0
        .byte 5,159,56,63,63,31,131,0,11,255,224,252,255,159,1,0
        .byte 0,255,0,0,131,255,7,0,0,255,31,126,248,224,131,0
        .byte 1,252,135,0,5,7,12,15,15,7,131,0,2,255,0,131
        .byte 255,131,0,2,255,0,131,255,131,0,5,224,28,252,252,248
        .byte 155,0,1,31,135,0,1,252,135,0,1,28,136,0,134,3
        .byte 12,1,0,255,255,0,0,192,248,252,28,255,255,131,0,21
        .byte 3,7,7,248,248,56,56,248,248,240,0,63,127,112,112,120
        .byte 127,63,3,255,255,132,0,20,128,128,255,255,3,3,15,127
        .byte 254,224,127,255,224,224,248,127,63,3,255,255,132,0,20,128
        .byte 128,255,255,7,3,31,127,254,224,15,15,14,14,15,15,7
        .byte 0,255,255,131,0,23,240,248,120,255,255,0,0,3,31,63
        .byte 60,255,255,192,192,224,252,254,15,255,255,3,1,133,0,35
        .byte 128,192,224,224,112,120,60,7,7,6,6,7,7,3,0,255
        .byte 255,0,0,128,240,252,60,255,255,0,0,1,15,31,29,255
        .byte 255,64,64,132,192,12,255,255,0,0,7,127,255,225,255,255
        .byte 0,0,132,192,10,255,255,0,0,120,255,255,225,255,255,131
        .byte 0,13,128,192,224,255,255,240,240,248,255,255,227,255,255,132
        .byte 0,21,128,192,255,255,0,0,127,255,255,224,255,255,0,0
        .byte 192,252,255,15,255,255,7,132,3,11,131,31,31,28,24,30
        .byte 31,15,0,255,255,131,0,5,192,224,224,255,255,131,0,19
        .byte 63,63,56,255,255,3,0,0,240,248,124,128,224,248,124,30
        .byte 15,7,3,134,0,30,128,128,0,1,7,15,30,28,56,56
        .byte 255,248,192,128,7,31,62,120,255,31,1,0,240,252,126,15
        .byte 255,255,227,99,132,3,2,0,0,134,128,136,0,136,12,136
        .byte 6,136,0,136,1,136,192,136,224,136,3,136,128,136,192,136
        .byte 0,132,28,132,12,2,48,48,134,112,2,3,3,134,1,15
        .byte 128,128,192,192,196,198,199,199,28,14,15,7,3,1,1,133
        .byte 0,5,128,192,224,224,12,135,14,134,57,13,56,56,193,195
        .byte 195,199,199,206,254,252,193,129,129,133,1,136,192,136,224,8
        .byte 240,112,56,56,28,28,15,15,136,225,136,192,136,224,16,3
        .byte 1,1,0,31,63,63,57,131,195,227,227,247,255,254,192,136
        .byte 0,136,96,136,56,2,30,14,134,7,136,1,136,192,4,112
        .byte 112,96,96,131,224,4,96,112,112,96,131,112,6,56,62,7
        .byte 3,1,1,132,0,2,131,131,131,195,3,227,227,99,136,128
        .byte 136,0,136,12,131,6,131,7,133,0,131,255,2,0,0,131
        .byte 1,131,255,2,0,0,133,192,3,128,0,0,136,224,136,3
        .byte 136,128,136,192,136,0,136,12,136,112,136,1,131,199,133,198
        .byte 16,128,192,224,224,112,56,60,28,112,56,60,28,14,7,7
        .byte 3,134,14,2,142,142,136,56,1,120,135,0,136,1,136,192
        .byte 136,224,1,3,135,0,1,129,135,1,136,192,131,224,131,255
        .byte 10,0,0,49,113,113,225,193,129,1,1,136,192,136,0,136
        .byte 96,133,56,10,63,63,62,7,14,14,60,248,240,224,131,1
        .byte 7,3,7,15,30,124,248,192,131,128,132,0,131,112,8,56
        .byte 60,28,15,7,31,7,1,132,0,19,128,128,224,252,127,15
        .byte 3,0,0,115,127,63,0,192,240,248,62,128,128,142,0,136
        .byte 12,131,7,133,6,131,255,133,0,131,255,133,1,1,128,135
        .byte 192,136,224,136,3,136,128,136,192,136,0,136,12,136,112,136
        .byte 1,136,198,24,14,15,7,3,1,1,0,0,1,1,128,128
        .byte 192,224,240,112,206,238,238,126,62,62,30,14,136,56,136,0
        .byte 136,1,136,192,136,224,136,0,136,1,136,192,3,126,255,255
        .byte 133,224,8,1,193,225,225,113,113,49,57,134,192,2,195,199
        .byte 134,0,2,128,224,136,96,24,0,0,62,63,63,51,59,57
        .byte 7,3,3,1,0,128,192,224,224,192,192,224,224,112,120,56
        .byte 134,0,15,1,1,3,1,0,0,120,252,254,206,224,248,127
        .byte 31,3,134,0,11,224,248,254,31,7,15,7,3,3,1,1
        .byte 132,0,2,128,128,131,192,1,224,136,0,136,12,136,6,136
        .byte 0,136,1,136,192,136,224,132,3,132,1,133,128,134,192,131
        .byte 224,2,112,120,136,0,2,12,12,131,28,3,56,120,240,133
        .byte 112,3,96,224,224,135,1,1,3,133,198,3,199,135,135,136
        .byte 0,16,56,60,30,14,7,7,3,1,6,6,2,0,0,128
        .byte 128,192,136,56,136,0,136,1,136,192,136,224,136,0,136,1
        .byte 136,192,136,224,3,63,63,15,133,0,10,207,142,28,28,56
        .byte 56,112,240,224,112,132,96,2,224,224,136,96,136,56,16,224
        .byte 112,120,56,28,14,15,7,28,14,15,7,3,1,1,0,132
        .byte 1,4,129,193,225,241,131,199,5,195,195,193,193,192,131,0
        .byte 6,128,128,192,224,240,3,135,1,2,128,128,131,192,131,193
        .byte 132,224,132,192,2,0,1,134,3,11,28,252,248,240,0,0
        .byte 255,255,7,7,3,131,0,21,255,255,0,240,248,248,56,56
        .byte 248,248,1,63,127,126,112,112,127,127,192,128,128,131,0,10
        .byte 255,255,224,254,127,31,3,3,255,255,136,0,35,224,240,120
        .byte 60,30,15,7,1,62,31,7,0,0,128,248,255,3,255,255
        .byte 248,0,0,7,255,225,195,7,15,30,124,248,224,192,192,128
        .byte 133,0,11,7,127,254,240,192,224,255,255,131,3,1,131,0
        .byte 10,255,255,192,252,254,62,14,14,254,254,136,0,8,224,240
        .byte 112,56,28,30,15,7,134,56,2,248,240,136,0,11,1,63
        .byte 127,254,224,224,255,127,192,192,128,131,0,12,255,255,112,127
        .byte 63,7,0,0,255,255,0,128,134,192,11,1,63,127,126,112
        .byte 112,127,127,192,192,128,131,0,21,255,255,112,127,63,3,0
        .byte 0,255,255,3,255,255,240,0,0,255,255,224,192,128,131,0
        .byte 10,255,255,224,239,255,255,248,252,255,223,131,224,16,128,0
        .byte 0,255,255,56,63,31,7,0,0,255,255,3,131,193,132,224
        .byte 17,192,128,192,192,224,240,112,63,63,121,63,31,3,0,0
        .byte 255,255,132,192,29,195,199,255,254,120,63,31,7,0,192,252
        .byte 255,3,159,255,252,0,0,15,255,131,135,15,30,60,248,240
        .byte 192,128,143,0,1,255,135,0,1,255,135,0,1,224,135,0
        .byte 1,31,135,0,1,255,135,0,1,252,151,0,2,63,3,134
        .byte 0,2,255,240,150,0,1,63,135,0,1,255,135,0,1,248
        .byte 143,0,1,3,135,0,1,240,143,0,1,63,135,0,1,255
        .byte 135,0,1,255,143,0,1,31,135,0,1,255,135,0,1,255
        .byte 135,0,1,255,135,0,1,255,135,0,1,135,135,0,1,255
        .byte 135,0,1,255,135,0,1,128,135,0,1,15,135,0,1,255
        .byte 135,0,1,248,135,0,1,63,135,0,1,254,255,0,255,0
        .byte 255,0,160,0,2,7,7,142,0,2,62,227,134,0,2,7
        .byte 28,134,0,2,193,97,134,0,2,193,193,134,0,2,199,199
        .byte 134,0,2,7,7,134,0,2,7,28,134,0,2,193,97,134
        .byte 0,2,248,142,134,0,2,7,28,134,0,2,193,97,134,0
        .byte 2,252,142,134,0,2,63,48,134,0,2,128,1,134,0,2
        .byte 248,156,134,0,2,12,28,134,0,2,3,14,134,0,2,224
        .byte 112,134,0,2,56,56,134,0,2,56,56,134,0,2,56,56
        .byte 134,0,2,254,192,255,0,10,0,13,13,9,24,31,16,48
        .byte 48,0,131,129,6,193,193,64,96,193,129,131,128,5,129,193
        .byte 231,16,176,131,48,5,176,16,28,49,17,131,25,11,17,49
        .byte 97,193,227,227,162,182,182,148,156,131,199,133,198,9,7,143
        .byte 143,139,219,219,83,115,16,133,48,4,16,28,49,17,131,25
        .byte 4,17,49,97,130,133,131,3,134,142,16,133,48,4,16,28
        .byte 49,17,131,25,3,17,49,97,131,134,5,252,140,132,134,134
        .byte 131,48,1,63,132,48,4,1,3,3,131,131,3,18,1,4
        .byte 240,152,12,12,13,12,152,28,44,108,204,140,254,12,12,8
        .byte 133,24,34,8,14,16,0,0,248,24,24,57,121,104,108,76
        .byte 196,254,134,130,131,56,60,60,52,54,54,50,51,56,120,120
        .byte 88,216,216,152,152,131,192,1,254,132,192,255,0,2,0,32
        .byte 135,0,1,96,135,0,1,126,135,0,1,7,135,0,1,193
        .byte 135,0,1,156,135,0,1,198,135,0,1,115,135,0,1,7
        .byte 135,0,1,193,135,0,1,248,135,0,1,7,135,0,1,193
        .byte 135,0,1,134,135,0,1,63,135,0,1,192,135,0,1,240
        .byte 135,0,1,12,135,0,1,7,135,0,1,217,135,0,1,3
        .byte 135,0,1,51,135,0,1,152,135,0,1,255,255,0,11,0
        .byte 0,62,99,97,96,120,30,0,0,63,133,3,3,0,0,231
        .byte 132,6,14,7,0,0,240,56,24,25,25,241,0,0,62,227
        .byte 129,131,128,10,0,0,14,14,143,143,205,205,0,0,132,24
        .byte 12,152,152,0,0,195,198,196,200,208,240,0,0,134,49,3
        .byte 0,0,252,132,128,19,252,0,192,207,216,216,24,30,7,0
        .byte 0,128,192,64,0,0,128,0,0,133,193,3,255,0,0,134
        .byte 152,2,0,0,134,49,11,0,0,195,195,227,227,179,179,0
        .byte 0,63,133,3,3,0,0,231,132,6,4,7,0,0,241,132
        .byte 1,5,241,0,0,252,142,131,134,15,252,0,0,62,99,97
        .byte 96,120,30,0,0,1,3,6,6,132,0,30,224,49,27,27
        .byte 51,51,0,0,240,152,13,13,12,12,0,0,120,204,134,134
        .byte 12,12,0,0,62,103,65,252,230,195,240,0,5,3,1,65
        .byte 99,62,131,0,5,3,131,131,3,3,131,0,133,6,131,0
        .byte 2,49,17,131,24,131,0,5,128,128,129,227,62,131,0,5
        .byte 204,140,140,12,12,131,0,5,216,216,120,120,56,131,0,5
        .byte 248,216,204,198,195,131,0,133,49,131,0,132,128,1,254,133
        .byte 0,3,16,24,15,131,0,5,192,96,96,192,128,131,0,133
        .byte 193,131,0,131,152,2,140,135,131,0,5,49,49,33,97,193
        .byte 131,0,5,155,155,143,143,135,131,0,133,3,131,0,132,6
        .byte 1,7,131,0,132,1,1,249,131,0,2,140,132,131,134,131
        .byte 0,5,3,1,65,99,62,132,0,4,128,129,3,7,131,0
        .byte 5,99,195,131,1,248,131,0,131,12,2,152,241,131,0,5
        .byte 24,48,96,192,254,131,0,131,195,2,102,60,187,0,0
introscr
        .byte 255,16,221,16,4,32,16,32,32,163,16,3,32,32,16,131
        .byte 32,162,16,6,32,16,32,32,16,32,162,16,6,32,16,32
        .byte 32,16,32,162,16,131,32,3,16,32,32,162,16,134,32,164
        .byte 16,2,32,32,255,16,255,16,219,16,2,48,16,150,48,144
        .byte 16,152,48,144,16,152,48,143,16,154,48,142,16,154,48,135
        .byte 16,0
