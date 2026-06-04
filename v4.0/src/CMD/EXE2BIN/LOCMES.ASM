;	SCCSID = @(#)locmes.asm	1.1 85/06/13
	title   LOCATE (EXE2BIN) Messages

FALSE   EQU     0
TRUE    EQU     NOT FALSE

set_addr macro sym,name
    public name
    ifidn <name>,<>
	dw offset sym
    else
    public name
name    dw  offset sym
    endif
endm


DATA    SEGMENT PUBLIC BYTE

	PUBLIC  bad_vers

bad_vers    db    "Incorrect DOS version$"

AccDen      db      "Access denied",0
	    set_addr    AccDen,AccDen_ptr

notfnd      db      "File not found",0
	    set_addr    notfnd,notfnd_ptr

NOROOM      db      "Insufficient memory",0
	    set_addr    noroom,noroom_ptr

DIRFULL     db      "File creation error",0
	    set_addr    dirfull,dirfull_ptr

FULL        db      "Insufficient disk space",0
	    set_addr    full,full_ptr

CANTFIX     db      "File cannot be converted",0
	    set_addr    cantfix,cantfix_ptr

PROMPT      db      "Fix-ups needed - base segment (hex): ",0
	    set_addr    prompt,prompt_ptr


crlf        db      13,10,0
	    set_addr    crlf,crlf_ptr

rdbad       db      "WARNING - Read error on EXE file.",13,10
	    db      "          Amount read less than size in header.",0
	    set_addr    rdbad,rdbad_ptr


DATA    ENDS
	END
