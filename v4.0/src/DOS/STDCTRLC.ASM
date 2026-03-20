;	SCCSID = @(#)stdctrlc.asm	1.1 85/04/10
;
; ^C and error handler for MSDOS
;

.xlist
include STDSW.ASM
.list

TITLE   Control C detection, Hard error and EXIT routines
NAME    STDCTRLC

include CTRLC.ASM
