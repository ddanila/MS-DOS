;	SCCSID = @(#)fordata.asm	1.1 85/05/14
;	SCCSID = @(#)fordata.asm	1.1 85/05/14
; Data structure definitions included by tfor.asm

for_info        STRUC
    for_args        DB          (SIZE arg_unit) DUP (?) ; argv[] structure
    FOR_COM_START   DB          ?                       ;; WASM: (?) not valid without DUP
    FOR_EXPAND      DW          ?                       ;; WASM: (?) not valid without DUP
    FOR_MINARG      DW          ?                       ;; WASM: (?) not valid without DUP
    FOR_MAXARG      DW          ?                       ;; WASM: (?) not valid without DUP
    forbuf          DW          64 DUP (?)              ; temporary buffer
    fordma          DW          64 DUP (?)              ; FindFirst/Next buffer
    FOR_VAR         DB          ?                       ;; WASM: (?) not valid without DUP
for_info        ENDS

; empty segment done for bogus addressing
for_segment     segment
f       LABEL   BYTE
for_segment     ends
