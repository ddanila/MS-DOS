;	SCCSID = @(#)shrprint.asm	1.1 85/04/10
TITLE	SHRPRINT - PRINTF at SHARE level
NAME	SHRPRINT
;
;
;   Modification history:
;
;	Created: MZ 16 June 1984
;

;; .xlist
;
; get the appropriate segment definitions
;
include DOSSEG.ASM

Share	SEGMENT PARA PUBLIC 'SHARE'
	ASSUME	SS:DOSGROUP,CS:SHARE

INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
;; .list

	I_Need	Proc_ID,WORD
	I_Need	User_ID,WORD

BREAK	<debugging output>

include PRINT.ASM

SHARE	ENDS
END
