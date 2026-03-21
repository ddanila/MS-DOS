;
page 60,132
;
title CP/DOS VioSetCurPos mapper
;
vioxxx  segment byte public 'vio'
        assume  cs:vioxxx,ds:nothing,es:nothing,ss:nothing
;
; ************************************************************************* *
; *
; *      MODULE:  viosetcurpos
; *
; *      FILE NAME:  scurpos.asm
; *
; *      CALLING SEQUENCE:
; *
; *             push    word    row value
; *             push    word    column value
; *             push    word    vio handle
; *             call    viosetcurpos
; *
; *
; *      MODULES CALLED:  BIOS Int 10h
; *
; *************************************************************************

        public  viosetcurpos
        .sall
        .xlist
        include MACROS.INC
        .list

error_bvs_parameter equ    0002h

argframe     struc
old_bp  dw      ?
return  dd      ?
handle  dw      ?           ; vio handle
column  dw      ?           ; column value
row     dw      ?           ; row value
argframe     ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

viosetcurpos proc   far
        MapEnter viosetcurpos            ; push registers

        mov     bh,0
        mov     ax,[bp].row             ; get column number
        cmp     al,25                   ; compare with maximum size allowed
        jg      error                   ; branch if illegal size
        mov     dh,al                   ; load row in dh

        mov     ax,[bp].column          ; get column number
        cmp     al,80                   ; check for upper boundry
        jg      error                   ; branch if illegal size
        mov     dl,al                   ; load column in dl

        mov     ah,02                   ; set BIOS function  code
        pushal                          ; Save registers in case int 10h
                                        ;   messes them up
        int     10h                     ; set cursor position
        popal

        sub     ax,ax                   ; set good return code
        jmp     exit                    ; return

error:  mov     ax,error_bvs_parameter  ; set error return code
exit:   Mexit                           ; pop registers
        retfar str_retsz	; return

viosetcurpos endp
vioxxx  ends
        end
