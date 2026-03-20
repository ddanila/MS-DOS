;	SCCSID = @(#)ibmcpmio.asm	1.1 85/04/10
;
; Standard device IO for MSDOS (first 12 function calls)
;

.xlist
include MSSW.ASM
include DOSSEG.ASM
.list

TITLE	IBMCPMIO - device IO for MSDOS
NAME	IBMCPMIO

include CPMIO.ASM
