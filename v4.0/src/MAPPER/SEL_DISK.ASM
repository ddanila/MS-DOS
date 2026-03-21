;
page 80,132
;
title CP/DOS DosSelectDisk mapper
;
dosxxx  segment byte public 'dos'
        assume  cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
;**********************************************************************
;*
;*   MODULE:   dosselectdisk
;*
;*   FILE NAME: dos048.asm
;*
;*   CALLING SEQUENCE:
;*
;*       push      word  drive          drive number
;*       call      dosselectdisk
;*
;*   MODULES CALLED:  PC-DOS Int 21h, ah=0eh, select disk
;*
;*********************************************************************

            public   dosselectdisk
            .sall
            .xlist
            include  MACROS.INC
            .list

argframe         struc
old_bp      dw       ?
Return      dd       ?
Drive       dw       ?       ; drive number
argframe         ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

dosselectdisk  proc  far
        MapEnter Dosselectdisk         ; push registers

        mov     dx,[bp].drive         ; load drive number
        dec     dx                    ; adjust for cp/dos incompatibility

        mov     ah,0eh
        int     21h                   ; select the drive

        sub     ax,ax                 ; set good return code

        mexit                         ; pop registers
        retfar str_retsz	; return

dosselectdisk endp

dosxxx      ends

            end
