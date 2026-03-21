;
page 60,132
;
title CP/DOS  DosFreeSeg  mapper
;
dosxxx  segment byte public 'dos'
        assume  cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
; ************************************************************************* *
; *
; *      MODULE: DosFreeSeg
; *
; *      FILE NAME: dos023.asm
; *
; *      FUNCTION: This module deallocates a segment
; *
; *
; *      CALLING SEQUENCE:
; *
; *             push    selector        ; selector of the segment
; *             call    dosfreeseg
; *
; *      RETURN SEQUENCE:
; *
; *      MODULES CALLED:  DOS int 21h, ah=49h
; *
; *************************************************************************

        public  dosfreeseg
        .sall
        .xlist
        include MACROS.INC
        .list

invalid_selector equ 0006h


argframe     struc
Old_bp   dw      ?
Return   dd      ?
Selector dw      ?         ; selector of the segment to be freed
argframe     ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

dosfreeseg proc   far
        MapEnter dosfreeseg              ; push registers

        mov     es,[bp].selector        ; get selector in es

        mov     ah,49h
        int     21h                     ; free memory segment
        jc      error                   ; jump if error

        sub     ax,ax                   ; zero return code
        jmp     exit                    ; go to exit

error:  mov     ax,invalid_selector     ; put in error code

exit:   Mexit                           ; pop registers
        retfar str_retsz	; return

dosfreeseg endp

dosxxx  ends

        end
