;	SCCSID = @(#)ibmctrlc.asm	1.1 85/04/10
;
; ^C and error handler for MSDOS
;

.xlist
include MSSW.ASM
.list

;; TITLE	Control C detection, Hard error and EXIT routines
NAME	IBMCTRLC

include CTRLC.ASM
