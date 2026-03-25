;
;       if1                         ;; WASM single-pass: IF1 not supported, removed
;               ;%out    macros.inc
;       endif


pushal  macro
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        push    ss
        push    bp
        endm
;
popal   macro
        pop     bp
        pop     ss
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        endm
;
MapEnter   macro   Routine         ;; WASM: renamed from Enter (conflicts with x86 ENTER instruction)

        push    bp
        mov     bp,sp
        pushal

        endm
;
Mexit   macro

        popal
        mov     sp,bp
        pop     bp

        endm
;
;; WASM: ret SIZEOF str - 6 fails in instruction operand context.
;; Use local var assignment to force constant evaluation, then ret the constant.
retfar  macro   nbytes      ;; WASM: call as retfar (SIZEOF str - 6) — pass precomputed size
        ret     nbytes
        endm
