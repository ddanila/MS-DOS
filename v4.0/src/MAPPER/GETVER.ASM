page 80,132

title CP/DOS DosGetVersion mapper

dosxxx	segment byte public 'dos'
	assume	cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
;**********************************************************************
;*
;*   MODULE:   dosgetversion
;*
;*   CALLING SEQUENCE:
;*
;*	 push@	   word  versionword pointer
;*	 call	   dosgetversion
;*
;*   MODULES CALLED:  PC-DOS Int 21h, ah=30h, get version
;*
;*********************************************************************

	    public   dosgetversion
	    .sall
	    include  MACROS.INC

argframe	    struc
old_bp	    dw	     ?
Return	    dd	     ?
Data	    dd	     ?	     ; return data area pointer
argframe	    ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

dosgetversion	proc	far
	MapEnter dosgetversion
	lds	si,[bp].data	      ; set pointer

	mov	ah,30h		      ; get DOS version
	int	21h

	mov	byte ptr [si],ah      ; minor version
	mov	byte ptr [si]+1,al    ; major version

exit:	mexit			      ; pop registers
	sub	ax,ax
	retfar str_retsz
;
dosgetversion endp

dosxxx	    ends

	    end
