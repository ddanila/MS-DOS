;*************************************
; COMMAND EQUs which are switch dependant

IF1
    IF IBM
;        %OUT IBM version			;WASM: %OUT unsupported
    ELSE
;        %OUT Normal version			;WASM: %OUT unsupported
    ENDIF

    IF   HIGHMEM
;        %OUT Highmem version			;WASM: %OUT unsupported
    ENDIF

    IF   KANJI
;        %OUT Kanji version			;WASM: %OUT unsupported
    ENDIF
ENDIF
