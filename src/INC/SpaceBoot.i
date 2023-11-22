EFindName	=-276
IOpenIntuition	=-30
ECacheClearU	=-636
IOpenScreenTagList=-612

MAGIC_ROMEND	=$01000000		;End of Kickstart ROM
MAGIC_SIZEOFFS	=-$14			;Offs from endROM to KS size
TEMP_ColdReboot	=-726

TD_Read	=2
TD_Write=3
TD_Update=4
TD_Clear=5
TD_Motor=9

KS20	=36
RtInit	=$16
libVersion=$14			;fixates these values in case
ioDevice=$14			;lib includes deviate
ioUnit=	$18			;"port" (ptr to drive)
LibList=$17a

LowMemChkSum=$24
ChkBase	=$26
ColdCapture=$2a
CoolCapture=$2e
WarmCapture=$32
KickTagPtr=$22a

INTENA	=$dff09a
DMACON	=$dff096
COLOR00	=$dff180
