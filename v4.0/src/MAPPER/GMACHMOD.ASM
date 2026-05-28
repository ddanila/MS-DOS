;0
page 80,132
;
title CP/DOS DOSGETMACHINEMODE mapper
;
dosxxx	segment byte public 'dos'
	assume	cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
;**********************************************************************
;*
;*   MODULE:   dosgetmachinemode
;*	Note that in PCDOS, this call should NOT BE ISSUED!
;*	This mapper does not return anything, it is meant
;*	only to allow the utility to link without errors.
;*
;*********************************************************************

	    public   dosgetmachinemode
	    ;; .sall
	    ;; .xlist
	    include  MACROS.INC
	    ;; .list

argframe	    struc
modeaddr    dw	     ?
argframe	    ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

dosgetmachinemode proc	far
	MapEnter DosGetMachMode	      ; push registers

	sub	ax,ax		      ; set good return code

	mexit			      ; pop registers
	retfar str_retsz	; return garbage (Not supported in PCDOS)

dosgetmachinemode endp

dosxxx	    ends

	    end
