SaveReg MACRO	reglist 		;; push those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth + 1
	PUSH	reg
ENDM
ENDM


RestoreReg  MACRO   reglist		;; pop those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth - 1
	POP	reg
ENDM
ENDM
