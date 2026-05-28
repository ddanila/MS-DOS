;
; maximum and minimum routines.
;

;; .xlist
include	VERSION.INC
include CMACROS.INC
;; .list

sBegin	code
assumes cs,code

cProc	max,<PUBLIC>
parmW	a
parmW	b
cBegin
	mov	ax,a
	cmp	ax,b
	jg	maxdone
	mov	ax,b
maxdone:
cEnd

cProc	min,<PUBLIC>
parmW	a
parmW	b
cBegin
	mov	ax,a
	cmp	ax,b
	jl	mindone
	mov	ax,b
mindone:
cEnd

sEnd

end
