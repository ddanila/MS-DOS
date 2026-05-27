;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; *** MACROS **** MACROS **** MACROS ****
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IF1                                     ;
        ;%OUT .               �MACROS  .INC�
ENDIF                                   ;
                                        ;
; WASM: JUMP macro rewritten to plain JMP -- the short-jump optimization
;       used 'LBL&_J' name concatenation which WASM doesn't expand
;       correctly in -zcm=masm mode (E074 in the IFNDEF/IF expressions).
JUMP    MACRO   LBL
        JMP     LBL
        ENDM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; *** MACROS **** MACROS **** MACROS ****
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
