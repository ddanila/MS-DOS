;
; string functions for lattice C
;

.xlist
include	VERSION.INC
include CMACROS.INC
.list

sBegin	data
assumes ds,data

externB XLTab
externB XUTab

sEnd

sBegin	code
assumes cs,code

externP strlen

;
; strbscan (string, set) returns pointer to 1st char in set or end
;
cProc	strbscan,<PUBLIC>,<SI,DI>
parmW	strn
parmW	set
cBegin
	push	ds
	pop	es
	cCall	strlen,<set>
	inc	ax
	mov	bx, ax
	mov	si,strn
	cld
bscan:
	lodsb
	mov	cx,bx
	mov	di,set
;
; While not in the set
;
	repnz	scasb
	jnz	bscan
	lea	ax,[si-1]
cEnd

;
; strbskip ( string, set ) returns pointer to 1st char not in set
;
cProc	strbskip,<PUBLIC>,<SI,DI>
parmW	strn
parmW	set
cBegin
	push	ds
	pop	es
	cCall	strlen,<set>
	inc	ax
	mov	bx, ax
	mov	si,strn
	cld
bskip:
	lodsb
	or	al,al
	jz	eskip
	mov	cx,bx
	mov	di,set
;
; While not in the set
;
	repnz	scasb
	jz	bskip
eskip:
	lea	ax,[si-1]
cEnd

;
; strpre (s1, s2) returns -1 if s1 is a prefix of s2, 0 otherwise. Ignores
; case.
;
cProc	strpre,<PUBLIC>,<si,di>
parmW	pref
parmW	strn
cBegin
	cld
	mov	si,pref
	mov	di,strn
	mov	bx,OFFSET DGROUP:xltab
preCompare:
	lodsb
	mov	ah,[di]
	inc	di

	xlat
	xchg	ah,al
	xlat

	cmp	ah,al
	jnz	preDif
	or	ah,ah
	jnz	preCompare
preYes:
	mov	ax,-1
	jmp	short preDone
preDif:
	or	ah,ah
	jz	preYes
	xor	ax,ax
preDone:
cEnd

sEnd

end
