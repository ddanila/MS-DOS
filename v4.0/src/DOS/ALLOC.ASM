;	SCCSID = @(#)alloc.asm	1.1 85/04/09
TITLE ALLOC.ASM - memory arena manager
NAME Alloc
;
; Memory related system calls and low level routines for MSDOS 2.X.
; I/O specs are defined in DISPATCH.
;
;   $ALLOC
;   $SETBLOCK
;   $DEALLOC
;   $AllocOper
;   arena_free_process
;   arena_next
;   check_signature
;   Coalesce
;
;   Modification history:
;
;       Created: ARR 30 March 1983
;

.xlist
;
; get the appropriate segment definitions
;
include dosseg.asm

CODE    SEGMENT BYTE PUBLIC  'CODE'
	ASSUME  SS:DOSGROUP,CS:DOSGROUP

.xcref
INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
.cref
.list

.lall

SUBTTL memory allocation utility routines
PAGE
;
; arena data
;
	i_need  arena_head,WORD         ; seg address of start of arena
	i_need  CurrentPDB,WORD         ; current process data block addr
	i_need  FirstArena,WORD         ; first free block found
	i_need  BestArena,WORD          ; best free block found
	i_need  LastArena,WORD          ; last free block found
	i_need  AllocMethod,BYTE        ; how to alloc first(best)last
	i_need  UmbArenaHead,WORD       ; first UMB arena header
	i_need  UmbLinkMcb,WORD         ; conventional-to-UMB link MCB
	i_need  UmbArenaTail,WORD       ; final guarded UMB MCB
	i_need  UmbLinked,BYTE          ; UMB arena link state
	i_need  AllocScanDomain,BYTE    ; allocator arena selector
	i_need  ArenaFreeDomain,BYTE    ; process cleanup arena selector
	I_need  EXTERR_LOCUS,BYTE       ; Extended Error Locus

;
; arena_free_process
; input:    BX - PID of process
; output:   free all blocks allocated to that PID
;
	procedure   arena_free_process,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     DI,arena_signature
	MOV     [ArenaFreeDomain],0
	MOV     AX,[arena_head]
	CALL    Check_Signature         ; ES <- AX, check for valid block
	retc

arena_free_process_loop:
	PUSH    ES
	POP     DS
	CMP     DS:[arena_owner],BX     ; is block owned by pid?
	JNZ     arena_free_next         ; no, skip to next
	MOV     DS:[arena_owner],DI     ; yes... free him

arena_free_next:
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; end of road, Jack?
	JNZ     arena_free_continue
	CMP     [ArenaFreeDomain],0
	JNZ     arena_free_done
	CMP     [UmbArenaHead],0
	JZ      arena_free_done
	MOV     [ArenaFreeDomain],1
	MOV     AX,[UmbArenaHead]
	CALL    Check_Signature
	retc
	JMP     arena_free_process_loop

arena_free_continue:
	CALL    arena_next              ; next item in ES/AX carry set if trash
	retc
	CMP     AX,[UmbArenaHead]
	JNZ     arena_free_process_loop
	MOV     [ArenaFreeDomain],1
	JMP     arena_free_process_loop

arena_free_done:
	return

EndProc arena_free_process

;
; arena_next
; input:    DS - pointer to block head
; output:   AX,ES - pointers to next head
;           carry set if trashed arena
;
	procedure   arena_next,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     AX,DS                   ; AX <- current block
	ADD     AX,DS:[arena_size]      ; AX <- AX + current block length
	INC     AX                      ; remember that header!
;
;       fall into check_signature and return
;
;       CALL    check_signature         ; ES <- AX, carry set if error
;       RET
EndProc arena_next

;
; check_signature
; input:    AX - address of block header
; output:   ES=AX, carry set if signature is bad
;
	procedure   check_signature,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     ES,AX                   ; ES <- AX
	CMP     BYTE PTR ES:[DI],arena_signature_normal
					; IF next signature = not_end THEN
	retz                            ;   GOTO ok
	CMP     BYTE PTR ES:[DI],arena_signature_end
					; IF next signature = end then
	retz                            ;   GOTO ok
	STC                             ; set error
	return

EndProc Check_signature

;
; Coalesce - combine free blocks ahead with current block
; input:    DS - pointer to head of free block
; output:   updated head of block, AX is next block
;           carry set -> trashed arena
;
	procedure   Coalesce,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; IF current signature = END THEN
	retz                            ;   GOTO ok
	CALL    arena_next              ; ES, AX <- next block, Carry set if error
	retc                            ; IF no error THEN GOTO check

coalesce_check:
	CMP     ES:[arena_owner],DI
	retnz                           ; IF next block isnt free THEN return
	MOV     CX,ES:[arena_size]      ; CX <- next block size
	INC     CX                      ; CX <- CX + 1 (for header size)
	ADD     DS:[arena_size],CX      ; current size <- current size + CX
	MOV     CL,ES:[DI]              ; move up signature
	MOV     DS:[DI],CL
	JMP     coalesce                ; try again
EndProc Coalesce

SUBTTL $Alloc - allocate space in memory
PAGE
;
;   Assembler usage:
;           MOV     BX,size
;           MOV     AH,Alloc
;           INT     21h
;         AX:0 is pointer to allocated memory
;         BX is max size if not enough memory
;
;   Description:
;           Alloc returns  a  pointer  to  a  free  block of
;       memory that has the requested  size  in  paragraphs.
;
;   Error return:
;           AX = error_not_enough_memory
;              = error_arena_trashed
;
	procedure   $ALLOC,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING

	EnterCrit   critMem
	XOR     AX,AX
	MOV     DI,AX

	MOV     [FirstArena],AX         ; init the options
	MOV     [BestArena],AX
	MOV     [LastArena],AX

	PUSH    AX                      ; alloc_max <- 0
	MOV     [AllocScanDomain],AL
	CMP     [UmbLinked],AL
	JZ      alloc_start_low
	MOV     AL,[AllocMethod]
	TEST    AL,alloc_domain_mask
	JZ      alloc_start_low
	INC     [AllocScanDomain]
	MOV     AX,[UmbArenaHead]
	JMP     alloc_start_scan

alloc_start_low:
	MOV     AX,[arena_head]

alloc_start_scan:
	CALL    Check_signature         ; ES <- AX, carry set if error
	JC      alloc_err               ; IF error THEN GOTO err

alloc_scan:
	PUSH    ES
	POP     DS                      ; DS <- ES
	CMP     DS:[arena_owner],DI
	JZ      alloc_free              ; IF current block is free THEN examine

alloc_next:
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; IF current block is last THEN
	JZ      alloc_end               ;   GOTO end
	CALL    arena_next              ; AX, ES <- next block, Carry set if error
	JC      alloc_err
	CMP     [AllocScanDomain],0
	JNZ     alloc_scan
	CMP     AX,[UmbArenaHead]
	JNZ     alloc_scan
	JMP     alloc_end

alloc_err:
	POP     AX

alloc_trashed:
	LeaveCrit   critMem
	error   error_arena_trashed

alloc_end:
	CMP     [FirstArena],0
	JNZ     alloc_do_split
	CMP     [AllocScanDomain],0
	JZ      alloc_fail
	TEST    [AllocMethod],alloc_domain_fallback
	JZ      alloc_fail
	MOV     [AllocScanDomain],0
	MOV     AX,[arena_head]
	CALL    Check_signature
	JC      alloc_err
	JMP     alloc_scan

alloc_fail:
	invoke  get_user_stack
	POP     BX
	MOV     [SI].user_BX,BX
	LeaveCrit   critMem
	error   error_not_enough_memory

alloc_free:
	CALL    coalesce                ; add following free block to current
	JC      alloc_err               ; IF error THEN GOTO err
	MOV     CX,DS:[arena_size]

	POP     DX                      ; check for max found size
	CMP     CX,DX
	JNA     alloc_test
	MOV     DX,CX

alloc_test:
	PUSH    DX
	CMP     BX,CX                   ; IF BX > size of current block THEN
	JA      alloc_next              ;   GOTO next

	CMP     [FirstArena],0
	JNZ     alloc_best
	MOV     [FirstArena],DS         ; save first one found
alloc_best:
	CMP     [BestArena],0
	JZ      alloc_make_best         ; initial best
	PUSH    ES
	MOV     ES,[BestArena]
	CMP     ES:[arena_size],CX      ; is size of best larger than found?
	POP     ES
	JBE     alloc_last
alloc_make_best:
	MOV     [BestArena],DS          ; assign best
alloc_last:
	MOV     [LastArena],DS          ; assign last
	JMP     alloc_next

;
; split the block high
;
alloc_do_split_high:
	MOV     DS,[LastArena]
	MOV     CX,DS:[arena_size]
	SUB     CX,BX
	MOV     DX,DS
	JE      alloc_set_owner         ; sizes are equal, no split
	ADD     DX,CX                   ; point to next block
	MOV     ES,DX                   ; no decrement!
	DEC     CX
	XCHG    BX,CX                   ; bx has size of lower block
	JMP     alloc_set_sizes         ; cx has upper (requested) size

;
; we have scanned memory and have found all appropriate blocks
; check for the type of allocation desired; first and best are identical
; last must be split high
;
alloc_do_split:
	MOV     AL,[AllocMethod]
	AND     AL,alloc_fit_mask
	CMP     AL,1
	JA      alloc_do_split_high
	MOV     DS,[FirstArena]
	JB      alloc_get_size
	MOV     DS,[BestArena]
alloc_get_size:
	MOV     CX,DS:[arena_size]
	SUB     CX,BX                   ; get room left over
	MOV     AX,DS
	MOV     DX,AX                   ; save for owner setting
	JE      alloc_set_owner         ; IF BX = size THEN (don't split)
	ADD     AX,BX
	INC     AX                      ; remember the header
	MOV     ES,AX                   ; ES <- DS + BX (new header location)
	DEC     CX                      ; CX <- size of split block
alloc_set_sizes:
	MOV     DS:[arena_size],BX      ; current size <- BX
	MOV     ES:[arena_size],CX      ; split size <- CX
	MOV     BL,arena_signature_normal
	XCHG    BL,DS:[DI]              ; current signature <- 4D
	MOV     ES:[DI],BL              ; new block sig <- old block sig
	MOV     ES:[arena_owner],DI

alloc_set_owner:
	MOV     DS,DX
	MOV     AX,[CurrentPDB]
	MOV     DS:[arena_owner],AX
	MOV     AX,DS
	INC     AX
	POP     BX
	LeaveCrit   critMem
	transfer    SYS_RET_OK

EndProc $alloc

SUBTTL $SETBLOCK - change size of an allocated block (if possible)
PAGE
;
;   Assembler usage:
;           MOV     ES,block
;           MOV     BX,newsize
;           MOV     AH,setblock
;           INT     21h
;         if setblock fails for growing, BX will have the maximum
;         size possible
;   Error return:
;           AX = error_invalid_block
;              = error_arena_trashed
;              = error_not_enough_memory
;              = error_invalid_function
;
	procedure   $SETBLOCK,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	EnterCrit   critMem
	MOV     DI,arena_signature
	MOV     AX,ES
	DEC     AX
	CALL    check_signature
	JNC     setblock_grab

setblock_bad:
	JMP     alloc_trashed

setblock_grab:
	MOV     DS,AX
	CALL    coalesce
	JC      setblock_bad
	MOV     CX,DS:[arena_size]
	PUSH    CX
	CMP     BX,CX
	JBE     alloc_get_size
	JMP     alloc_fail
EndProc $setblock

SUBTTL $DEALLOC - free previously allocated piece of memory
PAGE
;
;   Assembler usage:
;           MOV     ES,block
;           MOV     AH,dealloc
;           INT     21h
;
;   Error return:
;           AX = error_invalid_block
;              = error_arena_trashed
;
	procedure   $DEALLOC,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	EnterCrit   critMem
	MOV     DI,arena_signature
	MOV     AX,ES
	DEC     AX
	CALL    check_signature
	JC      dealloc_err
	MOV     ES:[arena_owner],DI
	LeaveCrit   critMem
	transfer    SYS_RET_OK

dealloc_err:
	LeaveCrit   critMem
	error   error_invalid_block
EndProc $DEALLOC

SUBTTL RegisterUmb - add a provider-owned UMB extent
PAGE
;
;   BX = first paragraph of provider extent
;   DX = extent size in paragraphs
;   Carry clear on success, set if the extent cannot be represented safely
;
	PUBLIC  RegisterUmb
	procedure RegisterUmb,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	PUSH    DS
	PUSH    ES
	CMP     DX,3
	JB      RegisterUmbError
	MOV     AX,BX
	ADD     AX,DX
	JC      RegisterUmbError
	CMP     CS:[UmbArenaHead],0
	JNZ     RegisterUmbAppend

	MOV     DI,arena_signature
	MOV     AX,CS:[arena_head]
	CALL    Check_Signature
	JC      RegisterUmbError
RegisterUmbFindLowTail:
	PUSH    ES
	POP     DS
	CMP     DS:[arena_signature],arena_signature_end
	JZ      RegisterUmbLowTailFound
	CALL    arena_next
	JC      RegisterUmbError
	JMP     RegisterUmbFindLowTail

RegisterUmbLowTailFound:
	CMP     DS:[arena_owner],arena_owner_system
	JNZ     RegisterUmbError
	CMP     DS:[arena_size],0
	JZ      RegisterUmbError
	MOV     AX,DS
	ADD     AX,DS:[arena_size]
	INC     AX
	CMP     AX,BX
	JA      RegisterUmbError
	DEC     DS:[arena_size]
	DEC     AX
	MOV     CS:[UmbLinkMcb],DS
	MOV     CS:[UmbArenaHead],AX
	CMP     AX,BX
	JZ      RegisterUmbMakeExtent
	MOV     ES,AX
	MOV     ES:[arena_signature],arena_signature_normal
	MOV     ES:[arena_owner],arena_owner_dos
	MOV     CX,BX
	SUB     CX,AX
	DEC     CX
	MOV     ES:[arena_size],CX
	MOV     BYTE PTR ES:[arena_name],'S'
	MOV     BYTE PTR ES:[arena_name+1],'C'
	JMP     RegisterUmbMakeExtent

RegisterUmbAppend:
	MOV     AX,CS:[UmbArenaTail]
	OR      AX,AX
	JZ      RegisterUmbError
	MOV     ES,AX
	MOV     CX,AX
	INC     CX
	CMP     CX,BX
	JA      RegisterUmbError
	MOV     AX,BX
	SUB     AX,CX
	MOV     ES:[arena_size],AX
	MOV     ES:[arena_signature],arena_signature_normal

RegisterUmbMakeExtent:
	MOV     ES,BX
	MOV     ES:[arena_signature],arena_signature_normal
	MOV     ES:[arena_owner],arena_owner_system
	MOV     AX,DX
	SUB     AX,2
	MOV     ES:[arena_size],AX
	MOV     AX,BX
	ADD     AX,DX
	DEC     AX
	MOV     ES,AX
	MOV     ES:[arena_signature],arena_signature_end
	MOV     ES:[arena_owner],arena_owner_dos
	MOV     ES:[arena_size],0
	MOV     BYTE PTR ES:[arena_name],'S'
	MOV     BYTE PTR ES:[arena_name+1],'M'
	MOV     CS:[UmbArenaTail],AX
	POP     ES
	POP     DS
	MOV     AX,1
	CLC
	return

RegisterUmbError:
	POP     ES
	POP     DS
	XOR     AX,AX
	STC
	return
EndProc RegisterUmb

SUBTTL $AllocOper - get/set allocation mechanism
PAGE
;
;   Assembler usage:
;           MOV     AH,AllocOper
;           MOV     BX,method
;           MOV     AL,func
;           INT     21h
;
;   Error return:
;           AX = error_invalid_function
;
	procedure   $AllocOper,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	OR      AL,AL
	JZ      AllocOperGet
	CMP     AL,1
	JZ      AllocOperSet
	CMP     AL,2
	JZ      AllocOperGetLink
	CMP     AL,3
	JZ      AllocOperSetLink
	CMP     AL,4
	JZ      AllocOperRegisterUmb
	CMP     AL,5
	JZ      AllocOperResetUmb

AllocOperError:
	MOV     EXTERR_LOCUS,errLoc_mem ; Extended Error Locus
	error   error_invalid_function

AllocOperGet:
	MOV     AL,BYTE PTR [AllocMethod]
	XOR     AH,AH
	transfer    SYS_RET_OK

AllocOperSet:
	OR      BH,BH
	JNZ     AllocOperError
	CMP     BL,2
	JBE     AllocOperSetValid
	CMP     BL,40H
	JB      AllocOperError
	CMP     BL,42H
	JBE     AllocOperSetValid
	CMP     BL,80H
	JB      AllocOperError
	CMP     BL,82H
	JA      AllocOperError
AllocOperSetValid:
	MOV     [AllocMethod],BL
	transfer    SYS_RET_OK

AllocOperGetLink:
	MOV     AL,[UmbLinked]
	transfer    SYS_RET_OK

AllocOperSetLink:
	CMP     BX,1
	JA      AllocOperError
	CMP     [UmbArenaHead],0
	JZ      AllocOperError
	CMP     BL,[UmbLinked]
	JZ      AllocOperLinkDone
	PUSH    AX
	PUSH    DX
	PUSH    DI
	PUSH    DS
	PUSH    ES
	MOV     DI,arena_signature
	MOV     AX,[arena_head]
	CALL    Check_Signature
	JC      AllocOperLinkError
AllocOperFindLinkMcb:
	PUSH    ES
	POP     DS
	MOV     DX,AX
	ADD     DX,DS:[arena_size]
	INC     DX
	CMP     DX,[UmbArenaHead]
	JZ      AllocOperLinkMcbFound
	CMP     DS:[arena_signature],arena_signature_end
	JZ      AllocOperLinkError
	CALL    arena_next
	JC      AllocOperLinkError
	JMP     AllocOperFindLinkMcb

AllocOperLinkMcbFound:
	MOV     [UmbLinkMcb],AX
	OR      BL,BL
	JZ      AllocOperUnlink
	CMP     DS:[arena_signature],arena_signature_end
	JNZ     AllocOperLinkError
	MOV     DS:[arena_signature],arena_signature_normal
	JMP     AllocOperStoreLink

AllocOperUnlink:
	CMP     DS:[arena_signature],arena_signature_normal
	JNZ     AllocOperLinkError
	MOV     DS:[arena_signature],arena_signature_end

AllocOperStoreLink:
	MOV     [UmbLinked],BL
	POP     ES
	POP     DS
	POP     DI
	POP     DX
	POP     AX

AllocOperLinkDone:
	transfer    SYS_RET_OK

AllocOperLinkError:
	POP     ES
	POP     DS
	POP     DI
	POP     DX
	POP     AX
	JMP     AllocOperError

AllocOperRegisterUmb:
; SYSINIT's full signature keeps ordinary 5804h calls on the public error path.
	CMP     CX,4D55H
	JNZ     AllocOperError
	CMP     SI,2142H
	JNZ     AllocOperError
	CMP     DI,0A55AH
	JNZ     AllocOperError
	CALL    RegisterUmb
	transfer    SYS_RET_OK

AllocOperResetUmb:
; Boot-only transaction abort. SYSINIT is the sole signed caller and invokes
; this before any UMB can have been linked or allocated.
	CMP     CX,4D55H
	JNZ     AllocOperError
	CMP     SI,2142H
	JNZ     AllocOperError
	CMP     DI,0A55AH
	JNZ     AllocOperError
	CMP     [UmbLinked],0
	JNZ     AllocOperError
	MOV     AX,[UmbLinkMcb]
	OR      AX,AX
	JZ      AllocOperResetDone
	PUSH    DS
	MOV     DS,AX
	CMP     DS:[arena_signature],arena_signature_end
	JNZ     AllocOperResetBad
	INC     DS:[arena_size]
	POP     DS
AllocOperResetDone:
	MOV     [UmbArenaHead],0
	MOV     [UmbArenaTail],0
	MOV     [UmbLinkMcb],0
	transfer    SYS_RET_OK
AllocOperResetBad:
	POP     DS
	JMP     AllocOperError

EndProc $AllocOper

CODE    ENDS
    END
