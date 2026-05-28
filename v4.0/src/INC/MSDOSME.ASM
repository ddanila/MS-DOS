;	SCCSID = @(#)ibmdosmes.asm	1.1 85/04/10
;
; Standard device IO for MSDOS (first 12 function calls)
;
debug=0
;; .xlist
include MSSW.ASM
include DOSSEG.ASM
;; .list

TITLE   IBMDOSMES - DOS OEM dependancies
NAME    IBMDOSMES

include DOSMES.ASM
	END
