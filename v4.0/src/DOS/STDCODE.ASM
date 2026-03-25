;	SCCSID = @(#)stdcode.asm	1.1 85/04/10
TITLE   MS-DOS MISC DOS ROUTINES - Int 25 and 26 handlers and other
NAME    STDCODE

;
; System call dispatch code
;

.xlist
include STDSW.ASM
.list

include MS_CODE.ASM
	END
