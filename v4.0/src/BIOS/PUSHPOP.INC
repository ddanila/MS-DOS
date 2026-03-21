IFNDEF ?stackdepth_init_
?stackdepth_init_ EQU 1
?stackdepth   =   0			;; WASM: must be initialized before use
ENDIF

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
