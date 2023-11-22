
	*===============================================k
	;						|
	* 		 >> SpaceBoot <<		(
	;						|
	*-----------------------------------------------+
	; 	    © 2023 Henrik Erlandsson		|
	*=========#=====================================#
	; 1.1	  | Public release |
	*---------+----------------'
	; Notes: /
	*-------'

;Source cleaned up and unified symbols dependencies somewhat.
;Contributors are advised to not use CBM-Amiga includes, since they
;are distributed with a Copyright notice.

;Variables

K	=1024
BootDst	=$80000-5*K		;best copy dest for 1K bootblock.
MenuTop	=(64-10+7)*9/8		;+7 is baseline for font.
MenuLeft=200+6+7*8-12
TopEdge	=0			;must now always be 0. 18 === crap
WBHeight=200			;decision: do not use smaller value.
				;KS20+ min:34,42,50, ...
BG	=$223
FG	=$ccf
FG2	=$abf

BGblue	=$225
BGgreen	=$252			;not used
BGred	=$522
BGorange=$642

;OS values and offsets

	INCDIR "INC/"
	INCLUDE "Symbols.S"
	INCLUDE "SpaceBoot.i"

;Bootblock start

Boot:	dc.b "DOS",0
	dc.l 0,880

Start:

    *--- Copy all to Chipmem ---*

	movem.l d0-a6,-(SP)
	lea BootDst,a5
	pea BootCode-BootRoutines(a5)		;offset prevents extra rts
	lea Boot(PC),a0				;only for Install Boot
	lea BootRoutines(PC),a4

	move.w #(R-BootRoutines)/2,d4
.l:
	clr.w WBFont-BootRoutines(a5)		;clr bss
	move.w (a4)+,(a5)+
	subq.w #1,d4
	bne.s .l				;at end a5=BSS=R, d4=0.l

	movem.l a0-a1,(a5)			;save Boot(orig)+trackdisk

    *--- Get Gfxbase ---*

	move.l 156(a6),a3			;gfxbase
	moveq #-1,d5				;const

.FindUnit:					;a1=StdIOReq
	move.l ioDevice(a1),a0
	lea 36+4*4(a0),a2		;end of 4 unit ptrs(or 0) in DeviceBase
	movea.l $3c(a0),a0
	lea $30+4*4(a0),a0		;end of 4 drive flags

	move.l ioUnit(a1),d1
	moveq #3,d0

BootRoutines:
;nothing between here and ReadLMB!
ReadLMB:				;harmless rtn. finishes copyloop
	btst #6,$bfe001
	rts

********************  FINDSTRRES  ********************
;input:		d0=resident base
;		d1=strlen
;		a1=string to search
;output:	a0=&str
;used:		d2/d3/a2 saved by main, a0 as return code

findstrres:
	movea.l	d0,a0
.search:
	move.w d1,d2
	subq.w #2,d2			;-(dbne,+)
	movea.l a1,a2
	move.b (a2)+,d3
.s1:	cmp.b (a0)+,d3
	bne.b .s1
.s2:	cmpm.b (a2)+,(a0)+
	dbne d2,.s2
	bne.b .search
	suba.l d1,a0
	rts

;;0
BootCode:	;d4-d5/a0-a1/a5=0.l,-1.l,Boot,trackdisk,R. Z flag=0 if LMB.
	beq.w BootExit				;LMB bypasses all.

    *--- Disable non-boot drives ---*		;d5=-1

.unitl:
	move.l d5,-(a0)				;default:eliminate
	cmp.l -(a2),d1
	bne.s .notfound
	move.l d0,d2
	clr.l (a0)				;clear found boot drive
.notfound:
	dbf d0,.unitl				;d2=boot drive (bonus info)
	add.b d2,DFa-R(A5)
;	add.b d2,DFb-R(A5)

    *--- Get Intbase ---*
	
	movea.l	LibList(a6),a0
	lea intuitionlib(PC),a1
	jsr EFindName(a6)
	move.l d0,d6				;intuitionbase
	
	lea intuitionlib(PC),a1
	jsr EFindResident(a6)			;->d0=residentbase (findstrres)

    *--- Poke font ptrs into scr struct ---*

	lea Fontname(PC),a0
	lea FontDef(PC),a1
	move.l a0,(a1)
	move.l a1,WbFont-R(A5)

    *--- Copy res.base's ^title to scr ---*

	lea wbname(PC),a1			;'Workbench Screen',0
	moveq #wbnamee-wbname,d1		;strlen
	bsr.s findstrres
	move.l a1,title-R(a5)		;@keep d0/a1 until next findstrres!

    *--- Read KickV ---*

	move.w #IOpenScr,d7
	cmpi.w #KS20,libVersion(a6)
	blo.b .lt20

	IF WBHeight<>200
	bhi.b .gt20
	move.w #WBHeight,WBh-R(a5)
.gt20:
	ENDC

    *--- Copy res.base's pubname to ours ---*	;on 2.0+

	moveq #10,d1				;strlen
	clr.b -1(a1,d1.w)			;'Workbench',0
	bsr.s findstrres
	move.l a0,pubname-R(a5)
;	jsr ECacheClearU(a6)			;@nec? runs in chipmem.
	move.w #IOpenScreenTagList,d7
.lt20:
	bchg #1,$bfe001				;filter off

    *--- Check resident ---*

	move.w #BG,d5
	move.b $212(a6),d1			;if rare intermittent bug,
	cmp.b $213(a6),d1			;then Vfrq mismatches PSU Hz
	beq.s .nobug
	move.w #BGorange,d5
.nobug:
	lea VirusText(PC),a0
	move.l $2a(a6),d0		;check cold- & coolcapture & kicktagptr
	or.l $2e(a6),d0
	or.l $22a(a6),d0
	beq.s .noVirus
	move.w #BGRed,d5			;d5=#BGRed if virus.
	move.w #"!!",(a0)
.noVirus:

	movea.l	d6,a6				;intuitionbase
	jsr IOpenIntuition(a6)			;KS1.x mandatory (undocumented)

	lea wbscreen(PC),a0
	lea tagitems(PC),a1			;Workbench need to be Pub
	jsr (a6,d7.w)				;open the screen

********************  MAIN CODE  ********************

;;1
.FInit:						;rastport, copper.
	move.l d0,a2				;screen

	lea $54(a2),a6				;rastport
	exg a3,a6				;a3/a6=rastport/gfxbase now

	move.l 38(a6),a4			;cop0
	bsr.w .SearchCopper

	move.l 50(a6),a4			;cop1
	move.l #$00960020,(a4)
	bsr.w .SearchCopper
	bne.w .FExit				;RMB held? nope, exit

    *--- Display text ---*

	lea MenuText(PC),a2
	moveq #0,d0				;line spacing (sort of)
	moveq #MenuTop,d6
	move.w #MenuLeft,d4
.line:
.indent:
	add.w d0,d6
	move.l a2,a0
.char:
	move.b (a2)+,d0
	cmp.b #" ",d0
	bhs.s .char

	move.l d4,d0
	move.l d6,d1
	move.l a3,a1				;rastport
	jsr GMove(a6)

	subq.w #1,a2
	move.l a2,d0
	sub.l a0,d0
	move.l a3,a1				;rastport
	jsr GText(a6)				;default: 60 col font on all.
.ctrl:
	move.b (a2)+,d0
	beq.s .done
	cmp.b #10,d0				;indent?
	bhs.s .noIndent				;else it's linespacing
	lsl.w #2,d0
	add.w d0,d4
	moveq #25,d0
	bra.s .line
.noIndent:
	moveq #13,d0
	bra.s .line
.done:

;	bra.w .MainStart
	PEA .MainStart(PC)

    *--- Dynamic DoIO ---*

.MotorOff:	;@move this to above .CopyDisk if branch gain
	moveq #TD_Motor,d0		;motor
	moveq #0,d1			;off
.DoIo2:	;R/W trackdisk. d0/d1/d5/d6=command,bytesize,memptr,start
	MOVEM.L D0-A6,-(SP)		;@opti only d1
	move.l BSS+4-R(a5),a1		;device
	move.w d0,28(a1)		;command
	movem.l d1/d5/d6,36(a1)		;bytesize,memptr,start
;	move.l d5,40(a1)		;src mem addr (can be in Fastmem)
;	move.l d6,44(a1)		;start sector
	move.l 4.w,a6			;@if called from outside
	jsr EDoIO(a6)
	tst.l d0
	MOVEM.L (SP)+,D0-A6		;returns length or OK in d2
	RTS

.WriteBoot:
	movem.l d0-a6,-(SP)
;	move.w #BGblue,(a4)
	moveq #1<<2,d4			;length 1K	
	moveq #1-1,d7
	bra.s .TrackDisk
.WaitSwap:
	addq.b #4,(a4)			;purple
.wsl:	bsr.s .ReadRMB
	bne.s .wsl
	subq.b #4,(a4)
	rts

.SearchCopper:		;a4=search startaddr -> a4=ptr+2 to replacement.w
.l:
	cmp.w #$180,(a4)+
	addq.w #2,a4
	bne.s .l
	move.w d5,-(a4)				;colors
.ClrScr:					;harmless rtn. ish.
	moveq #0,d0				;pen
	move.l a3,a1				;rastport
	jsr GSetRast(a6)			;fill pen 0 = clr
.ReadRMB:					;harmless rtn.
	btst #10,$dff016
	rts

    *--- Dual-purpose trackdisk routine ---*

;;8
.CopyDisk:
	movem.l d0-a6,-(SP)
;	move.w #BGCopy,(a4)
	move.w #440<<2,d4		;length 440K
	moveq #2-1,d7

.TrackDisk:	;d4.w/d7/a4=KBsize<<8,cmd(1=write boot, 2=copy disk),^bgcolor
	addq.w #BGBlue-BG,(a4)
	move.l 4.w,a6
	ext.l d4
	lsl.l #8,d4			;bytesize
	moveq #0,d6			;start sector
	move.l (a5),d5			;bootorig

	move.l d4,d0
	moveq #_Chip,d1			;do not change!
	jsr EAllocMem(a6)
	tst.l d0
	beq.s .noMem

	move.l d0,a1			;@must be saved until end

	moveq #TD_Clear,d0		;invalidate disk buffer to force reread
	moveq #0,d1			;it has this BB in its first 2 sectors
	bsr.w .DoIo2

	tst.w d7
	beq.s .wrBoot
	move.l a1,d5			;replace TD memptr with alloced
.trackLoop:
	moveq #TD_Read,d0		;read
	move.l d4,d1			;size
	bsr.w .DoIo2
	bne.s .copyError
	bsr.w .MotorOff
	bsr.s .WaitSwap
;	bra.s .wr
.wr:
.wrBoot:
	moveq #TD_Write,d0		;write
	move.l d4,d1			;size
	bsr.w .DoIo2
	bne.s .copyError
	moveq #TD_Update,d0		;write dirty buffer to disk
;	move.l d4,d1			;size
	bsr.w .DoIo2
	bsr.w .MotorOff
	add.l d4,d6			;sector offset=440K
	tst.w d7			;wrBoot or last write
	beq.s .noSwap
	bsr.w .WaitSwap
.noSwap:
	dbf d7,.trackLoop
	bra.s .copyDone

.copyError:
	move.w #BGred,(a4)
.errorL:
	bsr.s .ReadRMB
	bne.s .errorL
.copyDone:
	move.l d4,d0
	jsr EFreeMem(a6)
.noMem:
	movem.l (SP)+,d0-a6

    *--- main start ---*

.MainStart:
;	bsr.w .MotorOff

;;2

    *--- Start Floop ---*

.FLoop:
;	jsr WaitTOF(a6)				;don't!

	move.w #BG,(a4)
	move.w #FG,4(a4)
	lea $dff006,a0				;rasters
	move.w #$4000,$9a-6(a0)
.l2:
	cmp.b #$62,(a0)
	bne.s .l2

	move.b $bfec01,d0			;read key (hpos raster)
	clr.w $180-6(a0)
.l3:
	cmp.b #$7a,(a0)
	bne.s .l3

	bsr.w ReadLMB
	beq.s HardReset
	move.w #BG,$180-6(a0)
	move.w #FG2,$182-6(a0)
	move.w #$c000,$9a-6(a0)

	lsr.b #1,d0
	bcc.s .FLoop
	cmp.b #$3a,d0				;Esc
	beq.s .FExit
	sub.b #$5f/2,d0
	beq.w .WriteBoot			;F1
	addq.b #1,d0
	beq.w .CopyDisk				;F2
	addq.b #1,d0
	bne.s .NoFilter				;F3
	bclr #1,$bfe001
.NoFilter:
	addq.b #1,d0				;F4
	bne.s .FLoop

    *--- End Floop ---*

.HogFast:
	move.l a6,-(SP)
	move.l 4.w,a6
.meml:
	move.l #_Largest+_Fast,d1
	jsr EAvailMem(a6)
	cmp.l MinFastHog-R(A5),d0		;640b instead of 1K is OK.
	blt.s .memdone
	moveq #_Fast,d1
	jsr EAllocMem(a6)
	bra.s .meml
.memdone:
	move.l (SP)+,a6
;	bra.s .FExit

    *--- exit ---*
;;3
.FExit:
	bsr.w .ClrScr

********************  END MAIN CODE  ********************

BootExit:
	movem.l (SP)+,d0-a6

    *--- Standard Exit ---*

	lea doslib(PC),a1
	move.l #"dos.",(a1)
	jsr EFindResident(a6)
	movea.l	d0,a1
	move.l RtInit(a1),a0			;dosinit
	moveq #0,d0
	rts

********************  Functions  ********************

;;4
HardReset:
	moveq #1,d7			;hard reset end
	ror.l #8,d7			;=MAGIC_ROMEND
	move.l 4.w,a6

    *--- disable ints and dma ---*

	lea DMACON,a4
	move.w #$4000,INTENA-DMACON(a4)	;disable ints to avoid interference
	move.w #$0580,(a4)		;and some DMA to avoid delayed prefetch
;	clr.w COLOR00-DMACON(a4)	;cosmetic (avoid random bg color)

    *--- clr coldcapture, set other two+nuke chkbase(+lowmemchksum?) ---*

	clr.l ColdCapture(a6)		;must be 0
	st CoolCapture+3(a6)		;must not be 0
	st WarmCapture+3(a6)		;must not be 0
	not.l ChkBase(a6)		;must be not correct (clr is unsafe)

SoftReset:				;d7.b/a6=0,execbase
	lea GoAway(PC),a5
	cmp.w #KS20,libVersion(a6)		;V36?
	blt.s .pre20
	jmp TEMP_ColdReboot(a6)			;Let Exec do it...
	;NOTE: Control flow never returns to here

;---- manually reset the Amiga ---------------------------------------------
.pre20:	jsr ESupervisor(a6)			;supervise-jump to code at (a5)
	;NOTE: Control flow never returns to here

;-------------- MagicResetCode ---------DO NOT CHANGE-----------------------
;Potential spot for 1w of data, e.g. by moving below data. See PRINTT.
intuitionlib:					;toggle position dep on CNOP
	dc.b 'intuit'
doslib:	dc.b 'ion.library',0
Gap:
	CNOP 0,4				;IMPORTANT! Longword align!
GapE:
	IF2
	PRINTT "If 2, move intui/doslib declaration to above Gap."
	PRINTV GapE-Gap
	ENDC

GoAway:						;d7=MAGIC_ROMEND
;	lea.l MAGIC_ROMEND,a0			;(end of ROM)
	move.l d7,a0
	sub.l MAGIC_SIZEOFFS(a0),a0		;(end of ROM)-(ROM size)=PC
	move.l 4(a0),a0				;Get Initial Program Counter
	subq.l #2,a0				;now points to second RESET
	addq.b #1,(7).w
Reset:	reset					;first RESET instruction
	jmp (a0)				;CPU Prefetch executes this
	;NOTE: the RESET and JMP instructions must share a longword!
;---------------------------------------DO NOT CHANGE-----------------------
GapToggle:

FontDef:dc.l 0			;Fontname
	dc.w 8,0,8		;height, style, flags
;;7
MenuText:
VirusText:
	dc.b "No "
VirusText2:
	dc.b "Resident/Virus"
VirusText3:
	dc.b 2				;!! is poked here if Resident/Virus
	dc.b " LMB·Hard Reset",1
	dc.b "F1·Write Boot",10
	dc.b "F2·Copy DF"
DFa:	dc.b "0"
;	dc.b ">DF"
;DFb:	dc.b "0"
	dc.b 10
	dc.b "F3·Filter On",10
	dc.b "F4·FastMem Off"
	dc.b 0
Fontname:
	dc.b "topaz.font",0
FontNameE:
	dc.b "Photon"			;TODO: Replace this with useful code.
              
wbname:	dc.b 'Workbench Screen',0
wbnameE:
	CNOP 0,2

tagitems:
	dc.l $8000002f			;SA_PubName
pubname:
	dc.l 'r05s'			;Part credit. Replaced w ^'Workbench',0
wbscreen:				;@DON'T SEP! TAG_DONE in wbscreen below
	dc.w 0				;WORD LeftEdge
MinFastHog:
	dc.w TopEdge			;WORD TopEdge
	dc.w 640			;WORD Width
WBh:	dc.w WBHeight			;WORD Height (200=KS1.x min height)
	dc.w 1				;WORD Depth
	dc.b 0,1			;UBYTE DetailPen, BlockPen 0=weird
	dc.w $8000			;UWORD ViewModes -> HIRES
	dc.w 1				;UWORD Type -> WBENCHSCREEN
;@put nothing between here and zeroes!
********************  "BSS"  ******************** ;Actual END OF BOOTBLOCK
WbFont:	dc.l 0				;struct TextAttr *Font, defaults
title:	dc.l 0				;UBYTE *DefaultTitle, ROM
	dc.l 0				;struct Gadget *Gadgets, UNUSED
	dc.l 0				;struct BitMap *CustomBitMap, NULL
WBscreenE:
BSS:					;@actual BSS
R:					;@PC rel base to use
BootE:
	dcb.l 1024/4,0			;filler

	IF2
	PRINTT "Must be even:"
	PRINTV VirusText-Boot
	ENDC
	AUTO ?BootE-Boot\ws0\Boot\0\2\cc0\
	END

