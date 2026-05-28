;
page 80,132
;
title CP/DOS DosGetDBCSEv
;
dosxxx	segment byte public 'dos'
	assume	cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
;**********************************************************************
;*
;*   MODULE:   DosGetDBCSEv
;*
;*   CALLING SEQUENCE:
;*
;*	       PUSH   WORD     Length
;*	       PUSH@  DWORD    Countrycode
;*	       PUSH@  DWORD    Memorybuffer
;*
;*   MODULES CALLED:  none
;*
;*********************************************************************
;
	public	DosGetDBCSEv
	;; .sall
	include MACROS.INC

argframe	struc
old_bp	dw	?
return	dd	?
DataAreaPtr	dd	?      ; Data buffer pointer
CountryCodePtr	dd	?      ; Country code pointer
DataAreaLength	dw	?      ; Length of data area
argframe	ends
	str_retsz EQU SIZEOF argframe - 6	;; WASM: precomputed for retfar str_retsz

DosGetDBCSEv	proc	far

	MapEnter DosGetDBCSEv		    ;AN000; push registers

; Get the country, so we can then get the country case map stuff

;	lds	si,[bp].CountryCodePtr
;	mov	ax,ds:[si]

; Note: do the country selection later (maybe never)

	mov	ax,6300H		     ;AN000; get DBCS vector
	INT	21H			     ;AN000; DS:SI-->vector area

	jc	Exit
Copy_Vector:
	les	di,[bp].DataAreaPtr	     ;AN000; ES:DI-->return buffer
	mov	cx,[bp].DataAreaLength	     ;AN000;
loopx:
	mov    al,ds:[si]		     ;AN000;
	mov    es:[di],al		     ;AN000;
	inc    si			     ;AN000;
	inc    di			     ;AN000;
	loop   loopx			     ;AN000;

	xor	ax,ax			     ;AN000;

Exit:
	Mexit				    ;AN000;pop registers

	retfar str_retsz	;AN000; return

DosGetDBCSEv	endp

dosxxx	ends

	end
