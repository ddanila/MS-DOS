;	SCCSID = @(#)stdcpmio.asm	1.1 85/04/10
;
; Standard device IO for MSDOS (first 12 function calls)
;

.xlist
include STDSW.ASM
include DOSSEG.ASM
.list

TITLE   STDCPMIO - device IO for MSDOS
NAME    STDCPMIO

include CPMIO.ASM
