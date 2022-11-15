; The recreated BigByte-CharSineScroller
;
; Disassembled from the original code using IRA V1.05beta and tidied by Robert Price.


    INCLUDE 'include/hardware/custom.i'
    INCLUDE 'include/hardware/hw_examples.i'

ABSEXECBASE	EQU	$4
AUTO_INT2	EQU	$68
AUTO_INT3	EQU	$6C
TRAP_01		EQU	$80
EXT_0004	EQU	$82
TRAP_02		EQU	$84
EXT_0006	EQU	$86
TRAP_03		EQU	$88
CIAA_PRA	EQU	$BFE001
CIAA_ICR	EQU	$BFED01

    SECTION S_0,CODE,CHIP

START:
; save the original register values to the stack.
    MOVEM.L	D0-D7/A0-A6,-(A7)

; open the graphics library
    MOVEA.L	ABSEXECBASE,A6		
    LEA		GFXNAME,A1		; libname = graphics.library
    MOVEQ	#0,D0			; version = 0
    JSR		(-552,A6)		; OpenLibrary(libName, version)
    MOVE.L	D0,GFXBASE	

; open the dos.library
    MOVEA.L	ABSEXECBASE,A6		
    LEA		DOSNAME,A1		; libname = dos.library
    MOVEQ	#0,D0			; version = 0
    JSR		(-552,A6)		; OpenLibrary(libName, version)
    MOVE.L	D0,DOSBASE	

; load the custom chipset base into A5.
    MOVEA.L	#CUSTOM,A5

; take control of the system.
    BSR		TAKESYSTEM

; move the addresses of the 3 visible bitplanes into the copper list
; these will be set to the bitplane registers in the copper list.
    MOVE.L	#LAB_0086,D0
    MOVE	D0,PL1L+2	
    SWAP	D0
    MOVE	D0,PL1H+2
    MOVE.L	#LAB_0088,D0
    MOVE	D0,PL2L+2
    SWAP	D0
    MOVE	D0,PL2H+2
    MOVE.L	#LAB_0089,D0
    MOVE	D0,PL3L+2
    SWAP	D0
    MOVE	D0,PL3H+2

; load the colours into the copper list.
    MOVEA.L	#COLOURPALETTE,A0
    MOVEA.L	#PALETTE,A1
    MOVEQ	#7,D1
    BSR		LoadColours		

; setup the copper
    CLR.L   SPR0DATA(A5)		
    MOVE.L	#COPLIST,COP1LCH(A5)	; Move the address of the copper list to COP1LCH
    CLR		COPJMP1(A5)				; Clear COPJMP1
    MOVE	#$83C0,DMACON(A5)		; Set DMACON

; initialise the soundtracker module.
    JSR		mt_init

    LEA		(SCROLLER,PC),A3		; load the start address of the scroll text into A3
MAIN:
; wait for the vertical raster beam to be in position.
    MOVEM.L	D0-D1,-(A7)
    MOVE.L	#$0000C800,D1
    BSR		WAITBEAM
    MOVEM.L	(A7)+,D0-D1

; play the music
    MOVEM.L	D0-D7/A0-A6,-(A7)
    JSR		mt_music
    MOVEM.L	(A7)+,D0-D7/A0-A6

    BSR		CLS	
    BSR		SINEBLIT		
    BSR		SCROLLVISIBLE		

; loop if the left mouse button hasn't been pressed.
    BTST	#6,CIAA_PRA		
    BNE.S	MAIN			

; stop the soundtracker music
    JSR		mt_end

EXIT:
; restore the system.
    BSR		FREESYSTEM

; close the graphics library.
    MOVEA.L	ABSEXECBASE.W,A6
    MOVEA.L	(GFXBASE,PC),A1
    JSR		(-414,A6)

; close the dos.library
    MOVEA.L	(DOSBASE,PC),A1
    JSR		(-414,A6)

; restore the saved registers from the stack
    MOVEM.L	(A7)+,D0-D7/A0-A6

; return to the operating system
    RTS




SINEBLIT:
    LEA		LAB_008C,A0
    MOVEA.L	#LAB_0087,A2
    LEA		(SINEDATA,PC),A4	; Set A4 to the start of the sine table
    ADDA.L	(SINEPTR,PC),A4		; Add the offset of the sineptr to A4 to get the current position in the sine table
    ADDQ.L	#2,SINEPTR			; increment the SINEPTR by 2 to get the next position in the sinetable
    CMPI.L	#SINELEN,SINEPTR	; check if the SINEPTR is greater than the length of the sine table
    BNE.S	LAB_0004			; if it isn't skip the next instruction
    SUBI.L	#SINELEN,SINEPTR	; reset SINEPTR
LAB_0004:
    MOVEQ	#11,D6
LAB_0005:
    MOVEA.L	A2,A1
    MOVE	(A4),D0
    LEA		(4,A4),A4
    CMPA.L	#SINEEND,A4
    BLT.S	LAB_0006
    SUBA.L	#SINELEN,A4			; Reset A4 to the start of the sine table
LAB_0006:
    MULS	#$0030,D0
    ADDA.L	D0,A1
    BSR		BLITTEXT
    ADDQ.L	#4,A0
    ADDQ.L	#4,A2
    DBF		D6,LAB_0005
    RTS


SCROLLVISIBLE:
    MOVE	(SPEED,PC),D1			; Load the scroller speed in D1
    MOVE	D1,D0					; move the sped into D0 as well
    LSL		#4,D0					
    OR		D1,D0
    SUB		D0,SCRVAL+2
    BPL.S	.EndScrollVisible
    ADDI	#$0110,SCRVAL+2
    ADDQ	#2,PL1L+2
    ADDQ	#2,PL2L+2
    ADDQ	#2,PL3L+2
    SUBQ	#2,POINTEROFFSET
    BPL.S	.EndScrollVisible
    ADDQ	#4,POINTEROFFSET
    SUBQ	#4,PL1L+2
    SUBQ	#4,PL2L+2
    SUBQ	#4,PL3L+2
    BSR		SCROLLHIDDEN
    BSR		DOCHAR
    ADDI.L	#$00000004,SINEPTR
    CMPI.L	#SINELEN,SINEPTR
    BLT.S	.EndScrollVisible
    SUBI.L	#SINELEN,SINEPTR
.EndScrollVisible:
    RTS

; Blit the text
; A0 - Source
; A1 - Destination
BLITTEXT:
blth	= 32						; blit height 32
bltw	= 2							; blit width 2

    MOVEM.L	A0-A1,-(A7)				; Save A0 and A1 to the stack
    BSR		BWAIT
    MOVE.L	#$FFFFFFFF,BLTAFWM(A5)	; Set BLTAFWM (blitter mask)
    MOVE	#$002C,BLTAMOD(A5)		; Set BLTAMOD (blitter modulo for source A)
    MOVE	#$002C,BLTDMOD(A5)		; Set BLTDMOD (blitter modulo for destination D)
    ;MOVE	#$09F0,BLTCON0(A5)		; Set BLTCON0
    MOVE	#%000100111110000,BLTCON0(A5)	; Set BLTCON0 		
    MOVE	#$0000,BLTCON1(A5)		; Set BLTCON1
    BSR		BWAIT			
    MOVE.L	A0,BLTAPTH(A5)			; Set BLTAPTH
    MOVE.L	A1,BLTDPTH(A5)			; Set BLTDPTH
    MOVE	#$0802,BLTSIZE(A5)		; Set BLTSIZE with height 32 and width 2
    ADDA.L	#$00002580,A0
    ADDA.L	#$00002580,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)			; Set BLTAPTH
    MOVE.L	A1,BLTDPTH(A5)			; Set BLTDPTH
    MOVE	#$0802,BLTSIZE(A5)		; Set BLTSIZE with height 32 and width 2
    ADDA.L	#$00002580,A0
    ADDA.L	#$00002580,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)			; Set BLTAPTH
    MOVE.L	A1,BLTDPTH(A5)			; Set BLTDPTH
    MOVE	#$0802,BLTSIZE(A5)		; Set BLTSIZE with height 32 and width 2
    MOVEM.L	(A7)+,A0-A1				; Restore A0 and A1 from the stack
    RTS								; return


CLS:
    MOVEA.L	#LAB_0087,A0
    BSR		BWAIT
    MOVE.L	A0,BLTDPTH(A5)
    MOVE	#$0000,BLTDMOD(A5)
    MOVE	#$0100,BLTCON0(A5)
    MOVE	#$2818,BLTSIZE(A5)	; Set BLTSIZE with height 80 and width 24
    ADDA.L	#$00002580,A0
    BSR		BWAIT
    MOVE.L	A0,BLTDPTH(A5)
    MOVE	#$0000,BLTDMOD(A5)
    MOVE	#$0100,BLTCON0(A5)
    MOVE	#$2818,BLTSIZE(A5)	; Set BLTSIZE with height 80 and width 24
    ADDA.L	#$00002580,A0
    BSR		BWAIT
    MOVE.L	A0,BLTDPTH(A5)
    MOVE	#$0000,BLTDMOD(A5)
    MOVE	#$0100,BLTCON0(A5)
    MOVE	#$2818,BLTSIZE(A5)	; Set BLTSIZE with height 80 and width 24
    ADDA.L	#$00002580,A0
    RTS


SCROLLHIDDEN:
screenwidth = 320+32			; screen width of 320 pixels + 32 pixels for the next font character
sh_blth		= 32				; scroll height of 32 pixels
sh_bltw		= screenwidth/16		; screen width in words
sh_bltskip 	= (screenwidth-320)/8
sh_planes 	= 3					; 3 bitplanes

    MOVE	#$09F0,BLTCON0(A5)
    MOVE	#$0000,BLTCON1(A5)
    MOVE	#sh_bltskip,BLTAMOD(A5)
    MOVE	#sh_bltskip,BLTDMOD(A5)
    LEA		LAB_008C,A0
    LEA		LAB_008B,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
;    MOVE	#$0816,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    MOVE	#((sh_blth*sh_planes)<<6)+sh_bltw,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    ADDA.L	#$00002580,A0
    ADDA.L	#$00002580,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
;    MOVE	#$0816,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    MOVE	#((sh_blth*sh_planes)<<6)+sh_bltw,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    ADDA.L	#$00002580,A0
    ADDA.L	#$00002580,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
;    MOVE	#$0816,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    MOVE	#((sh_blth*sh_planes)<<6)+sh_bltw,BLTSIZE(A5)	; set BLTSIZE with height 32 and width 22
    RTS

; A3 = address of current letter in the scoll text.
DOCHAR:
    LEA		(ASCIIVALUES,PC),A1			; load the start address of the ascii values into A1
    LEA		(CHARACTEROFFSETS,PC),A2	; load the start address of the character offsets in the font into A2
    MOVEQ	#0,D0						; clear D0, we use this to store the current character
NEWCHAR:
    MOVE.B	(A3)+,D0					; get the current letter of the scroll text in D0 and move to the addres of the next character in A3
    BNE.S	GOTLETTER					; if we've not got a letter we need to restart the scroll text
ENDOFSCROLL:
    LEA		(SCROLLER,PC),A3			; load the start address of the scroll text into A3
    BRA.S	NEWCHAR						; look for the next character
GOTLETTER:
    CMP.B	#$05,D0						; is the character $5? If it is it's a control character and the next byte will be the scroller speed
    BNE.S	TRYAGAIN					; not a control character so skip to TRYAGAIN
    MOVE.B	(A3)+,D0					; get the controller speed 
    MOVE	D0,SPEED					; save the speed to the SPEED in memory
    BRA.S	NEWCHAR						; get the next character
TRYAGAIN:
    MOVE	(A2)+,D2					; get the character offset into D2 and increment A2 to the next location
    CMP.B	(A1)+,D0					; does the character the ascii values match the value in the scroll text?
    BNE.S	TRYAGAIN					; if it doesn't we loop back to try the next character
BLITLETTER:
    BSR		BWAIT						; wait for the blitter to be ready.
    MOVE.L	#$FFFFFFFF,BLTAFWM(A5)
    MOVE	#$0024,BLTAMOD(A5)
    MOVE	#$002C,BLTDMOD(A5)
    MOVE	#$09F0,BLTCON0(A5)
    CLR		BLTCON1(A5)
    LEA		FONT,A0						; load the address of our font image into A0
    ADDA	D2,A0						; add the offset of the current character to A0 so we should be pointing to the address of the character we need to blit.
    LEA		LAB_008D,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
    MOVE	#$0802,BLTSIZE(A5)	; BLTSIZE (win/width, height) 0000100000000010    height = 32, width = 2
;	ADDA.L	#$00001F40,A0		; 8000 bytes (320x200 font size)
    ADDA.L	#$00001900,A0		; 6400 bytes (320x160 font size)
    ADDA.L	#$00002580,A1		; 9600 bytes (320x240 screen size)
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
    MOVE	#$0802,BLTSIZE(A5)	; BLTSIZE (win/width, height) 0000100000000010    height = 32, width = 2
;	ADDA.L	#$00001F40,A0
    ADDA.L	#$00001900,A0
    ADDA.L	#$00002580,A1
    BSR		BWAIT
    MOVE.L	A0,BLTAPTH(A5)
    MOVE.L	A1,BLTDPTH(A5)
    MOVE	#$0802,BLTSIZE(A5)	; BLTSIZE (win/width, height) 0000100000000010    height = 32, width = 2
;	ADDA.L	#$00001F40,A0
    RTS


; Wait for the vertical raster position to be in the correct position.
; D1 - position to wait for.
WAITBEAM:
    MOVE.L	VPOSR(A5),D0		; Get VPOSR into D0
    ANDI.L	#$0001FF00,D0
    CMP.L	D1,D0
    BNE.S	WAITBEAM		
    RTS				

; Wait for the blitter to be free.
BWAIT:
    BTST    #$E,DMACONR(A5)		; test DMACONR bit 14 BBUSY (Blitter Busy) flag.
    BNE.S	BWAIT
    RTS


TAKESYSTEM:
    MOVE	(28,A5),SYSTEMINTS		; copy INTENAR
    MOVE	(2,A5),SYSTEMDMA		; copy DMACONR 
    MOVE	#$7FFF,INTENA(A5)		; set INTENA
    MOVE	#$7FFF,DMACON(A5)		; set DMACON
    MOVE.B	#$7F,CIAA_ICR		
    MOVE.L	AUTO_INT2,LEVEL2VECTOR	
    MOVE.L	AUTO_INT3,LEVEL3VECTOR	
    MOVE.L	TRAP_01,TRAP0ADDR	
    MOVE.L	EXT_0004,TRAP1ADDR
    MOVE.L	TRAP_02,TRAP2ADDR
    MOVE.L	EXT_0006,TRAP3ADDR
    MOVE.L	TRAP_03,TRAP4ADDR
    RTS				

FREESYSTEM:
    MOVE.L	LEVEL2VECTOR,AUTO_INT2
    MOVE.L	LEVEL3VECTOR,AUTO_INT3
    MOVE.L	TRAP0ADDR,TRAP_01
    MOVE.L	TRAP1ADDR,EXT_0004
    MOVE.L	TRAP2ADDR,TRAP_02
    MOVE.L	TRAP3ADDR,EXT_0006
    MOVE.L	TRAP4ADDR,TRAP_03
    MOVEA.L	GFXBASE,A1
    MOVE.L	(38,A1),CUSTOM+COP1LCH	
    MOVE.L	(50,A1),CUSTOM+COP2LCH	
    MOVE	SYSTEMINTS,D0
    ORI		#$C000,D0
    MOVE	D0,INTENA(A5)		; set INTENA
    MOVE	SYSTEMDMA,D0		
    ORI		#$8100,D0
    MOVE	D0,DMACON(A5)		; set DMACON
    MOVE.B	#$9B,CIAA_ICR
    RTS


SYSTEMINTS:
    DS.W	1
SYSTEMDMA:
    DS.W	1
LEVEL2VECTOR:
    DS.L	1
LEVEL3VECTOR:
    DS.L	1
TRAP0ADDR:
    DS.L	1
TRAP1ADDR:
    DS.L	1
TRAP2ADDR:
    DS.L	1
TRAP3ADDR:
    DS.L	1
TRAP4ADDR:
    DS.L	1
DOSBASE:
    DS.L	1
GFXBASE:
    DS.L	1
DOSNAME:
    DC.B	"dos.library",0
    EVEN
GFXNAME:
    DC.B	"graphics.library",0
    EVEN

; Load colours into the copper list.
; A0 - the address of the colours to copy to the copper list
; A1 - the address in the copper list to copy the colours to
; D1 - the number of colours to add
LoadColours:
    MOVE	#$0180,D0			; COLOR00 into D0
.LoadColourLoop:
    MOVE	D0,(A1)+			; write the COLOR0x register to the copper list
    ADDQ	#2,D0				; increment to the next COLOR0x register
    MOVE	(A0)+,(A1)+			; write the value of the colour to the copper list
    DBF		D1,.LoadColourLoop	; loop if we have more colours to add
    RTS							; return


; Copper List
COPLIST:
    DC.W	$01FC,$0000
    DC.W	$0106,$0000
    DC.W	DIWSTRT,$2C81	; Set DIWSTRT to vertical 44 and horizontal 129
    DC.W	DIWSTOP,$F4C1	; Set DIWSTOP to vertical 244 and horizontal 193
    DC.W	DDFSTRT,$0030	; Set DDFSTRT to wide - this is needed for horizontal scrolling.
    DC.W	DDFSTOP,$00D0	; Set DDFSTOP to normal.
    DC.W	BPLCON0,$3200
SCRVAL:
    DC.W	BPLCON1,$0000	; Set BPLCON1 - this is the delay in horizontal scrolling
    DC.W	BPL1MOD,$0006
    DC.W	BPL2MOD,$0006
PL1H:    
	DC.W	BPL1PTH,$0000
PL1L:
    DC.W	BPL1PTL,$0000
PL2H:
    DC.W	BPL2PTH,$0000
PL2L:
    DC.W	BPL2PTL,$0000
PL3H:
    DC.W	BPL3PTH,$0000
PL3L:
    DC.W	BPL3PTL,$0000
PALETTE:
    DS.W	16			; reserve 16 words for the colour palette.
    DC.W	$FFFF,$FFFE	; impossible position so end of the copper list.
; end of copper list

    
WBCLIST:
    DS.L	1
SINEPTR:
    DS.L	1
SPEED:
    DC.W	$0002
POINTEROFFSET:
    DS.W	1

; Sinewave data table.
SINEDATA:
    DC.L	$00780075,$0072006C,$00690066,$00630060
    DC.L	$005D005A,$00570054,$0051004E,$004B0048
    DC.L	$00450042,$003F003C,$00390036,$00330030
    DC.L	$002D002A,$00270024,$0021001E,$001B0019
    DC.L	$00170015,$00130011,$000F000E,$000D000C
    DC.L	$000B000A,$000A0009,$00090008,$00080007
    DC.L	$00070006,$00060005,$00050004,$00040003
    DC.L	$00030002,$00020002,$00010001,$00010001
    DC.L	$00010001,$00020002,$00020003,$00030004
    DC.L	$00040005,$00050006,$00060007,$00070007
    DC.L	$00080008,$00090009,$000A000A,$000B000C
    DC.L	$000D000E,$000F0011,$00130015,$00170019
    DC.L	$001B001E,$00210024,$0027002A,$002D0030
    DC.L	$00330036,$0039003C,$003F0042,$00450048
    DC.L	$004B004E,$00510054,$0057005A,$005D0060
    DC.L	$00630066,$0069006C,$00720075
    DC.W	$0076
SINEEND:

SINELEN 	EQU SINEEND-SINEDATA				; The length of the sine table

; offsets of the characters in the font. - guess by Rob seems to offset by 40 bytes - 320 pixels
CHARACTEROFFSETS:
;	DC.L	$0028002C,$00300034,$0038003C,$00400044 ; 01234567
;	DC.L	$0048004C,$0528052C,$05300534,$0538053C	; 89ABCDEF
;	DC.L	$05400544,$0548054C,$0A280A2C,$0A300A34 ; GHIJKLMN
;	DC.L	$0A380A3C,$0A400A44,$0A480A4C,$0F280F2C ; OPQRSTUV
;	DC.L	$0F300F34,$0F380F3C,$0F400F44,$0F480F4C ; WXYZ.:,"
;	DC.L	$1428142C,$14301434,$1438143C,$14401444 ; @!?()?; 

; character offsets recalculated to use the raw ripped font.
    dc.w	$0000,$0004,$0008,$000c,$0010,$0014,$0018,$001C,$0020,$0024		; 0123456789
    dc.w	$0500,$0504,$0508,$050c,$0510,$0514,$0518,$051C,$0520,$0524		; ABCDEFGHIJ
    dc.w	$0a00,$0a04,$0a08,$0a0c,$0a10,$0a14,$0a18,$0a1C,$0a20,$0a24		; KLMNOPQRST
    dc.w	$0f00,$0f04,$0f08,$0f0c,$0f10,$0f14,$0f18,$0f1C,$0f20,$0f24		; UVWXYZ.:,"
    dc.w	$1400,$1404,$1408,$140c,$1410,$1414,$1418,$141C					; @!?()-; 


; The order of the letters in the font graphic
ASCIIVALUES:
    DC.B	'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:,"@!?()-; '

    EVEN

; The text to scroll. $05 is a control byte, followed by a speed - $01 fastest
SCROLLER:
    DC.B	'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:,"@!?()-; '
    dc.b	'   BIG-'
    dc.B	$05,$01
    dc.b	'BYTE '
    dc.B	$05,$03
    dc.B	'IS PROUD TO PRESENT A CHAR-SINE SCROLLER IN 1988 ---  SCROLLTEXT WRAPS  ---    '

    EVEN
; The original font graphic 320x200
FONT:
;	INCLUDE 'font.s'

; raw font is 320x160 and has 3 bitplanes.
    INCBIN 'font.raw'

    EVEN
; The colour palette.
COLOURPALETTE:
    DC.W	$0000,$0ECA,$00DD,$00AA,$0088,$0055,$0032,$03CF

; Include soundtracker player and module.
    EVEN
    INCLUDE 'include/SoundTracker_v2.3.s'
    EVEN
    INCBIN	'demondownloader.mod'

; Reserve space for the screen in chip memory.
    SECTION S_1,BSS,CHIP
    
; screen is 32 (hidden) + 320 (visible) + 32 (hidden) pixels wide, 80? pixels high, 3 bit planes
SCREEN:
    DS.W	1
LAB_0086:
    DS.L	479
    DS.W	1
LAB_0087:
    DS.L	1920
    DS.W	1
LAB_0088:
    DS.L	2400
LAB_0089:
    DS.L	2399
    DS.W	1
HIDDEN:
    DS.L	480
LAB_008B:
    DS.L	1
LAB_008C:
    DS.L	10
LAB_008D:
    DS.L	6709
    END
