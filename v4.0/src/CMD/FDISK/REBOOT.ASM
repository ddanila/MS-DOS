
	title	Reboot Support for FDISK

IF1
	;%OUT ASSEMBLING: Reboot
	;%OUT
ENDIF

ROMDATA segment at 040h
	org	072h
BootType	dw	?
ROMDATA ends

_text	segment byte public 'code'
	assume	cs:_TEXT
	assume	ds:nothing
	assume	es:nothing
	assume	ss:nothing

	public	_reboot
_reboot proc	near

	mov	ax,ROMDATA
	mov	ds,ax
	assume	ds:ROMDATA

	mov	BootType,1234h

	cli
	cld
	; far jmp to 0FFFFh:0000h (ROM BIOS power-on reset vector)
	; WASM does not support 'jmp label_far' where label is in AT segment
	db	0EAh		; far JMP opcode
	dw	0000h		; offset 0
	dw	0FFFFh		; segment 0FFFFh

_reboot endp

_text	ends

	end
