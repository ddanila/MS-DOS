; Include guard: WASM rejects macro redefinitions on second inclusion.
IFNDEF JUMPMAC_INC_
JUMPMAC_INC_ EQU 1
					  ;;Rev 3.30 Modification
;
; given a label <lbl> either 2 byte jump to another label <lbl>_J
; if it is near enough or 3 byte jump to <lbl>
;
;ALWAYS TRY A 3 BYTE NEAR JUMP (Rev 3.30 replaced complex 2/3-byte optimization)
JUMP MACRO LBL
				JMP LBL
	ENDM					;;End of Modification
ENDIF ;; JUMPMAC_INC_
