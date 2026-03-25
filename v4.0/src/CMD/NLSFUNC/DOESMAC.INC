BREAK	MACRO	subtitle
	SUBTTL	subtitle
	PAGE
ENDM

CallInstall MACRO   name,mpx,fn,save,restore
IF Installed
    IFNB    <save>
    IRP reg,<save>
	PUSH	reg
    ENDM
    ENDIF
	MOV	AX,(mpx SHL 8) + fn
	INT	2Fh
    IFNB    <restore>
    IRP reg,<restore>
	POP	reg
    ENDM
    ENDIF
ELSE
	DOSInvoke	name
ENDIF
ENDM

BREAK <SaveReg>

SaveReg MACRO	reglist 		;; push those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth + 1
	PUSH	reg
ENDM
ENDM

BREAK <RestoreReg>

RestoreReg  MACRO   reglist		;; pop those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth - 1
	POP	reg
ENDM
ENDM
