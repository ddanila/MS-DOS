; Clean-room XMS 2.00 manager for the repository MS-DOS tree.
;
; This driver is intentionally not added to production media until the full
; XMS 2.00 conformance suite passes.  It shares no source with Microsoft's
; published HIMEM implementation.

        .model  tiny
        .386
        .code
        org     0

MAX_HANDLES     equ     32
HANDLE_SIZE     equ     8
MAX_UMB_BLOCKS  equ     32
UMB_BLOCK_SIZE  equ     6

ERR_NOT_IMPLEMENTED equ 080h
ERR_A20         equ     082h
ERR_GENERAL     equ     08eh
ERR_HMA_MISSING equ     090h
ERR_HMA_USED    equ     091h
ERR_HMA_SMALL   equ     092h
ERR_HMA_FREE    equ     093h
ERR_NO_MEMORY   equ     0a0h
ERR_NO_HANDLES  equ     0a1h
ERR_BAD_HANDLE  equ     0a2h
ERR_BAD_SOURCE  equ     0a3h
ERR_BAD_SRC_OFF equ     0a4h
ERR_BAD_DEST    equ     0a5h
ERR_BAD_DST_OFF equ     0a6h
ERR_BAD_LENGTH  equ     0a7h
ERR_OVERLAP     equ     0a8h
ERR_NOT_LOCKED  equ     0aah
ERR_LOCKED      equ     0abh
ERR_LOCK_OVER   equ     0ach
ERR_UMB_SMALL   equ     0b0h
ERR_NO_UMBS     equ     0b1h
ERR_BAD_UMB     equ     0b2h

device_header:
        dw      0ffffh, 0ffffh
        dw      08000h
        dw      strategy
        dw      interrupt
        db      'HIMEM$  '

request_ptr     dd      0
old_int2f       dd      0
old_int15       dd      0
extended_kb     dw      0
hma_owned       db      0
a20_initial     db      0
a20_local       dw      0
a20_global      dw      0
caller_ds       dw      0
caller_si       dw      0
move_length     dd      0
move_source     dd      0
move_dest       dd      0
move_chunk      dd      0
handles         db      MAX_HANDLES * HANDLE_SIZE dup (0)
umb_count       dw      0
umb_committed   db      0
umb_blocks      db      MAX_UMB_BLOCKS * UMB_BLOCK_SIZE dup (0)

strategy proc far
        mov     word ptr cs:[request_ptr], bx
        mov     word ptr cs:[request_ptr+2], es
        ret
strategy endp

interrupt proc far
        push    ax
        push    bx
        push    ds
ifdef DEBUG
        mov     al, 'I'
        call    debug_mark
endif
        les     bx, cs:[request_ptr]
        mov     al, es:[bx+2]
        or      al, al
        jnz     short interrupt_bad
        push    cs
        pop     ds
        call    initialize
        jmp     short interrupt_done
interrupt_bad:
        mov     word ptr es:[bx+3], 08103h
interrupt_done:
        pop     ds
        pop     bx
        pop     ax
        ret
interrupt endp

initialize proc near
ifdef DEBUG
        mov     al, 'A'
        call    debug_mark
endif
        ; Refuse a second XMS manager.
        mov     ax, 04300h
        int     02fh
        cmp     al, 080h
        je      init_fail
        mov     ax, 0e700h
        int     02fh
        cmp     al, 0ffh
        je      init_fail
ifdef DEBUG
        mov     al, 'B'
        call    debug_mark
endif

        mov     ax, 0352fh
        int     021h
        mov     word ptr [old_int2f], bx
        mov     word ptr [old_int2f+2], es
        mov     ax, 03515h
        int     021h
        mov     word ptr [old_int15], bx
        mov     word ptr [old_int15+2], es
ifdef DEBUG
        mov     al, 'C'
        call    debug_mark
endif

        mov     ah, 088h
        int     015h
        mov     [extended_kb], ax
        or      ax, ax
        jz      init_fail
ifdef DEBUG
        mov     al, 'D'
        call    debug_mark
endif

        ; Establish the XMS idle state. The repository's supported machines
        ; have a controllable fast A20 gate; later hardware backends may mark
        ; an irreversibly enabled gate as initial-on after an alias test.
        in      al, 092h
        and     al, 0fch
        out     092h, al
        mov     [a20_initial], 0

        push    ds
        push    cs
        pop     ds
ifdef DEBUG
        mov     al, 'E'
        call    debug_mark
endif
        mov     dx, offset multiplex_handler
        mov     ax, 0252fh
        int     021h
        mov     dx, offset int15_handler
        mov     ax, 02515h
        int     021h
        pop     ds

        les     bx, cs:[request_ptr]
        mov     word ptr es:[bx+14], offset resident_end
        mov     word ptr es:[bx+16], cs
        mov     word ptr es:[bx+3], 00100h
ifdef DEBUG
        mov     al, 'F'
        call    debug_mark
endif
        ret
init_fail:
        les     bx, cs:[request_ptr]
        mov     word ptr es:[bx+14], 0
        mov     word ptr es:[bx+16], cs
        mov     word ptr es:[bx+3], 08100h
        ret
initialize endp

ifdef DEBUG
debug_mark proc near
        push    dx
        mov     dx, 0e9h
        out     dx, al
        pop     dx
        ret
debug_mark endp
endif

multiplex_handler proc far
        cmp     ax, 04300h
        je      short multiplex_installed
        cmp     ax, 04310h
        je      short multiplex_entry
        cmp     ax, 0e700h
        je      short private_installed
        cmp     ax, 0e701h
        je      private_register
        cmp     ax, 0e702h
        je      private_unregister
        jmp     dword ptr cs:[old_int2f]
multiplex_installed:
        mov     al, 080h
        iret
multiplex_entry:
        mov     bx, offset xms_control
        push    cs
        pop     es
        iret
private_installed:
        mov     ax, 0e7ffh
        mov     bx, 04d55h              ; 'UM'
        mov     cx, 1
        iret
multiplex_handler endp

; Internal repository peer call. DS:SI points to version, count, then sorted
; segment/size word pairs. This is deliberately not a public UMB API.
private_register:
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        push    ds
        pop     es
        push    cs
        pop     ds
ifdef UMB_TEST_REJECT
        jmp     short private_bad
endif
        cmp     [umb_committed], 0
        jne     short private_bad
        cmp     word ptr es:[si], 1
        jne     short private_bad
        mov     cx, word ptr es:[si+2]
        or      cx, cx
        jz      short private_bad
        cmp     cx, MAX_UMB_BLOCKS
        ja      short private_bad
        add     si, 4
        xor     bp, bp
        mov     di, si
private_validate:
        mov     ax, word ptr es:[di]
        mov     dx, word ptr es:[di+2]
        or      dx, dx
        jz      short private_bad
        cmp     ax, 0a000h
        jb      short private_bad
        cmp     ax, bp
        jb      short private_bad
        add     ax, dx
        jc      short private_bad
        cmp     ax, 0f000h
        ja      short private_bad
        mov     bp, ax
        add     di, 4
        loop    private_validate

        mov     cx, word ptr es:[si-2]
        mov     [umb_count], cx
        mov     di, offset umb_blocks
private_copy:
        mov     ax, word ptr es:[si]
        mov     word ptr [di], ax
        mov     ax, word ptr es:[si+2]
        mov     word ptr [di+2], ax
        mov     byte ptr [di+4], 0       ; free
        mov     byte ptr [di+5], 0
        add     si, 4
        add     di, UMB_BLOCK_SIZE
        loop    private_copy
        mov     [umb_committed], 1
        mov     ax, 1
        xor     bx, bx
        jmp     short private_done
private_bad:
        xor     ax, ax
        mov     bl, 1
private_done:
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        iret

private_unregister:
        push    cx
        push    si
        push    ds
        push    cs
        pop     ds
        mov     si, offset umb_blocks
        mov     cx, [umb_count]
        jcxz    short private_unregister_clear
private_unregister_scan:
        cmp     byte ptr [si+4], 0
        jne     short private_unregister_busy
        add     si, UMB_BLOCK_SIZE
        loop    private_unregister_scan
private_unregister_clear:
        mov     [umb_count], 0
        mov     [umb_committed], 0
        mov     ax, 1
        xor     bx, bx
        jmp     short private_unregister_done
private_unregister_busy:
        xor     ax, ax
        mov     bl, 2
private_unregister_done:
        pop     ds
        pop     si
        pop     cx
        iret

int15_handler proc far
        cmp     ah, 088h
        jne     short int15_chain
        xor     ax, ax
        clc
        retf    2
int15_chain:
        jmp     dword ptr cs:[old_int15]
int15_handler endp

xms_control proc far
        mov     word ptr cs:[caller_ds], ds
        mov     word ptr cs:[caller_si], si
        push    cx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        push    cs
        pop     ds
        cmp     ah, 011h
        ja      short xms_unknown
        mov     al, ah
        xor     ah, ah
        mov     si, ax
        shl     si, 1
        call    word ptr cs:[xms_table+si]
        jmp     short xms_return
xms_unknown:
        mov     bl, ERR_NOT_IMPLEMENTED
        xor     ax, ax
xms_return:
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     cx
        retf
xms_control endp

xms_table:
        dw      xms_version, xms_hma_request, xms_hma_release
        dw      xms_global_enable, xms_global_disable
        dw      xms_local_enable, xms_local_disable, xms_a20_query
        dw      xms_query_free, xms_allocate, xms_free, xms_move
        dw      xms_lock, xms_unlock, xms_handle_info, xms_reallocate
        dw      xms_umb_request, xms_umb_release

xms_success:
        mov     ax, 1
        clc
        ret
xms_failure:
        xor     ax, ax
        clc
        ret
xms_bad_handle:
        mov     bl, ERR_BAD_HANDLE
        jmp     xms_failure
xms_a20_failed:
        mov     bl, ERR_A20
        jmp     xms_failure

xms_version proc near
        mov     ax, 0200h
        mov     bx, 0100h
        xor     dx, dx
        cmp     [extended_kb], 0
        je      short version_done
        inc     dx
version_done:
        ret
xms_version endp

xms_hma_request proc near
        cmp     [extended_kb], 0
        je      short hma_missing
        cmp     [hma_owned], 0
        jne     short hma_used
        mov     [hma_owned], 1
        jmp     xms_success
hma_missing:
        mov     bl, ERR_HMA_MISSING
        jmp     xms_failure
hma_used:
        mov     bl, ERR_HMA_USED
        jmp     xms_failure
xms_hma_request endp

xms_hma_release proc near
        cmp     [hma_owned], 0
        je      short hma_not_owned
        mov     [hma_owned], 0
        jmp     xms_success
hma_not_owned:
        mov     bl, ERR_HMA_FREE
        jmp     xms_failure
xms_hma_release endp

xms_global_enable proc near
        inc     [a20_global]
        call    enable_a20
        jc      xms_a20_failed
        jmp     xms_success
xms_global_enable endp

xms_global_disable proc near
        cmp     [a20_global], 0
        je      short global_disable_now
        dec     [a20_global]
global_disable_now:
        call    reconcile_a20
        jc      xms_a20_failed
        jmp     xms_success
xms_global_disable endp

xms_local_enable proc near
        inc     [a20_local]
        call    enable_a20
        jc      xms_a20_failed
        jmp     xms_success
xms_local_enable endp

xms_local_disable proc near
        cmp     [a20_local], 0
        je      short a20_underflow
        dec     [a20_local]
        call    reconcile_a20
        jc      xms_a20_failed
        jmp     xms_success
a20_underflow:
        mov     bl, ERR_A20
        jmp     xms_failure
xms_local_disable endp

xms_a20_query proc near
        xor     ax, ax
        in      al, 092h
        and     al, 2
        shr     al, 1
        ret
xms_a20_query endp

enable_a20 proc near
        in      al, 092h
        or      al, 2
        and     al, 0feh
        out     092h, al
        in      al, 092h
        test    al, 2
        jz      short enable_a20_fail
        clc
        ret
enable_a20_fail:
        stc
        ret
enable_a20 endp

reconcile_a20 proc near
        cmp     [a20_initial], 0
        jne     short reconcile_on
        cmp     [a20_global], 0
        jne     short reconcile_on
        cmp     [a20_local], 0
        jne     short reconcile_on
        in      al, 092h
        and     al, 0fch
        out     092h, al
        in      al, 092h
        test    al, 2
        jnz     short reconcile_fail
        clc
        ret
reconcile_on:
        jmp     enable_a20
reconcile_fail:
        stc
        ret
reconcile_a20 endp

xms_query_free proc near
        call    largest_gap
        mov     bx, ax
        call    total_free
        mov     dx, ax
        mov     ax, bx
        clc
        ret
xms_query_free endp

xms_allocate proc near
        call    find_free_handle
        jc      short allocate_no_handle
        push    si
        mov     bx, dx
        call    find_gap
        pop     si
        jc      short allocate_no_memory
        mov     byte ptr [si], 1
        mov     byte ptr [si+1], 0
        mov     word ptr [si+2], ax
        mov     word ptr [si+4], dx
        mov     dx, si
        sub     dx, offset handles
        mov     cl, 3
        shr     dx, cl
        inc     dx
        jmp     xms_success
allocate_no_memory:
        mov     bl, ERR_NO_MEMORY
        jmp     xms_failure
allocate_no_handle:
        mov     bl, ERR_NO_HANDLES
        jmp     xms_failure
xms_allocate endp

xms_free proc near
        call    validate_handle
        jc      xms_bad_handle
        cmp     byte ptr [si+1], 0
        jne     short free_locked
        mov     byte ptr [si], 0
        mov     word ptr [si+2], 0
        mov     word ptr [si+4], 0
        jmp     xms_success
free_locked:
        mov     bl, ERR_LOCKED
        jmp     xms_failure
xms_free endp

xms_lock proc near
        call    validate_handle
        jc      xms_bad_handle
        cmp     byte ptr [si+1], 0ffh
        je      short lock_overflow
        inc     byte ptr [si+1]
        mov     ax, word ptr [si+2]
        mov     dx, ax
        mov     cl, 6
        shr     dx, cl
        add     dx, 0010h
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        mov     bx, ax
        jmp     xms_success
lock_overflow:
        mov     bl, ERR_LOCK_OVER
        jmp     xms_failure
xms_lock endp

xms_unlock proc near
        call    validate_handle
        jc      xms_bad_handle
        cmp     byte ptr [si+1], 0
        je      short unlock_underflow
        dec     byte ptr [si+1]
        jmp     xms_success
unlock_underflow:
        mov     bl, ERR_NOT_LOCKED
        jmp     xms_failure
xms_unlock endp

xms_handle_info proc near
        call    validate_handle
        jc      xms_bad_handle
        mov     bh, byte ptr [si+1]
        call    count_free_handles
        mov     bl, al
        mov     dx, word ptr [si+4]
        jmp     xms_success
xms_handle_info endp

xms_reallocate proc near
        call    validate_handle
        jc      xms_bad_handle
        cmp     byte ptr [si+1], 0
        jne     short realloc_locked
        mov     ax, word ptr [si+4]
        cmp     bx, ax
        jbe     short realloc_resize
        push    dx
        mov     dx, bx
        call    gap_after_handle
        pop     dx
        jc      short realloc_move
realloc_resize:
        mov     word ptr [si+4], bx
        jmp     xms_success
realloc_move:
        push    si
        push    bx
        call    find_gap
        pop     bx
        pop     si
        jc      short realloc_no_memory
        push    bx
        push    ax
        movzx   ecx, word ptr [si+4]
        shl     ecx, 10
        mov     [move_length], ecx
        movzx   edx, word ptr [si+2]
        shl     edx, 10
        add     edx, 00100000h
        mov     [move_source], edx
        movzx   edx, ax
        shl     edx, 10
        add     edx, 00100000h
        mov     [move_dest], edx
        call    copy_move_blocks
        pop     ax
        pop     bx
        jc      short realloc_no_memory
        mov     word ptr [si+2], ax
        mov     word ptr [si+4], bx
        jmp     xms_success
realloc_locked:
        mov     bl, ERR_LOCKED
        jmp     xms_failure
realloc_no_memory:
        mov     bl, ERR_NO_MEMORY
        jmp     xms_failure
xms_reallocate endp

xms_move proc near
        push    bx
        push    dx
        push    es
        mov     es, [caller_ds]
        mov     di, [caller_si]
        mov     eax, dword ptr es:[di]
        test    al, 1
        jnz     short move_bad_length
        mov     [move_length], eax
        or      eax, eax
        jz      move_success

        mov     dx, word ptr es:[di+4]
        mov     eax, dword ptr es:[di+6]
        mov     ecx, [move_length]
        call    resolve_move_address
        jc      short move_bad_source
        mov     [move_source], eax

        mov     dx, word ptr es:[di+10]
        mov     eax, dword ptr es:[di+12]
        mov     ecx, [move_length]
        call    resolve_move_address
        jc      short move_bad_dest
        mov     [move_dest], eax

move_copy:
        call    copy_move_blocks
        jc      short move_general_failure
move_success:
        pop     es
        pop     dx
        pop     bx
        jmp     xms_success
move_bad_length:
        mov     bl, ERR_BAD_LENGTH
        jmp     short move_failure
move_bad_source:
        mov     bl, ERR_BAD_SOURCE
        cmp     bh, ERR_BAD_SRC_OFF
        jne     short move_failure
        mov     bl, ERR_BAD_LENGTH
        jmp     short move_failure
move_bad_dest:
        mov     bl, ERR_BAD_DEST
        cmp     bh, ERR_BAD_SRC_OFF
        jne     short move_failure
        mov     bl, ERR_BAD_LENGTH
        jmp     short move_failure
move_general_failure:
        mov     bl, ERR_GENERAL
move_failure:
        pop     es
        add     sp, 4
        jmp     xms_failure
xms_move endp

xms_umb_request proc near
        or      dx, dx
        jz      short umb_request_fail
        mov     si, offset umb_blocks
        mov     cx, [umb_count]
        xor     bp, bp                  ; largest free block
        mov     di, 0ffffh              ; first suitable block
        jcxz    umb_request_fail
umb_request_scan:
        cmp     byte ptr [si+4], 0
        jne     short umb_request_next
        mov     ax, word ptr [si+2]
        cmp     ax, bp
        jbe     short umb_request_size
        mov     bp, ax
umb_request_size:
        cmp     di, 0ffffh
        jne     short umb_request_next
        cmp     ax, dx
        jb      short umb_request_next
        mov     di, si
umb_request_next:
        add     si, UMB_BLOCK_SIZE
        loop    umb_request_scan
        cmp     di, 0ffffh
        je      short umb_request_fail
        mov     bx, word ptr [di]
        cmp     word ptr [di+2], dx
        je      short umb_request_exact
        cmp     [umb_count], MAX_UMB_BLOCKS
        jae     short umb_request_fail
        call    insert_umb_after
        mov     ax, word ptr [di]
        add     ax, dx
        mov     word ptr [di+UMB_BLOCK_SIZE], ax
        mov     ax, word ptr [di+2]
        sub     ax, dx
        mov     word ptr [di+UMB_BLOCK_SIZE+2], ax
        mov     byte ptr [di+UMB_BLOCK_SIZE+4], 0
        mov     word ptr [di+2], dx
umb_request_exact:
        mov     byte ptr [di+4], 1
        jmp     xms_success
umb_request_fail:
        mov     dx, bp
        or      bp, bp
        jz      short umb_none
        mov     bl, ERR_UMB_SMALL
        jmp     xms_failure
umb_none:
        mov     bl, ERR_NO_UMBS
        jmp     xms_failure
xms_umb_request endp

xms_umb_release proc near
        mov     si, offset umb_blocks
        mov     cx, [umb_count]
        xor     di, di
        jcxz    umb_release_bad
umb_release_find:
        cmp     word ptr [si], dx
        jne     short umb_release_next
        cmp     byte ptr [si+4], 1
        je      short umb_release_found
umb_release_next:
        inc     di
        add     si, UMB_BLOCK_SIZE
        loop    umb_release_find
umb_release_bad:
        mov     bl, ERR_BAD_UMB
        jmp     xms_failure
umb_release_found:
        mov     byte ptr [si+4], 0
        call    coalesce_umb_blocks
        jmp     xms_success
xms_umb_release endp

; Insert an empty UMB entry after DI, shifting later entries upward.
insert_umb_after proc near
        push    ax
        push    cx
        push    si
        push    di
        mov     ax, [umb_count]
        inc     ax
        mov     [umb_count], ax
        dec     ax
        mov     cx, ax
        mov     si, offset umb_blocks
        imul    ax, UMB_BLOCK_SIZE
        add     si, ax
insert_umb_shift:
        cmp     si, di
        jbe     short insert_umb_done
        mov     ax, word ptr [si-UMB_BLOCK_SIZE]
        mov     word ptr [si], ax
        mov     ax, word ptr [si-UMB_BLOCK_SIZE+2]
        mov     word ptr [si+2], ax
        mov     ax, word ptr [si-UMB_BLOCK_SIZE+4]
        mov     word ptr [si+4], ax
        sub     si, UMB_BLOCK_SIZE
        loop    insert_umb_shift
insert_umb_done:
        pop     di
        pop     si
        pop     cx
        pop     ax
        ret
insert_umb_after endp

coalesce_umb_blocks proc near
        push    ax
        push    bx
        push    cx
        push    si
        mov     si, offset umb_blocks
        mov     cx, [umb_count]
        dec     cx
        jcxz    short coalesce_done
coalesce_scan:
        cmp     byte ptr [si+4], 0
        jne     short coalesce_next
        cmp     byte ptr [si+UMB_BLOCK_SIZE+4], 0
        jne     short coalesce_next
        mov     ax, word ptr [si]
        add     ax, word ptr [si+2]
        cmp     ax, word ptr [si+UMB_BLOCK_SIZE]
        jne     short coalesce_next
        mov     ax, word ptr [si+UMB_BLOCK_SIZE+2]
        add     word ptr [si+2], ax
        call    remove_next_umb
        dec     [umb_count]
        dec     cx
        jcxz    short coalesce_done
        jmp     short coalesce_scan
coalesce_next:
        add     si, UMB_BLOCK_SIZE
        loop    coalesce_scan
coalesce_done:
        pop     si
        pop     cx
        pop     bx
        pop     ax
        ret
coalesce_umb_blocks endp

remove_next_umb proc near
        push    ax
        push    cx
        push    di
        mov     di, si
        add     di, UMB_BLOCK_SIZE
        mov     ax, offset umb_blocks
        mov     cx, [umb_count]
        imul    cx, UMB_BLOCK_SIZE
        add     ax, cx
remove_umb_shift:
        add     di, UMB_BLOCK_SIZE
        cmp     di, ax
        jae     short remove_umb_done
        mov     cx, word ptr [di]
        mov     word ptr [di-UMB_BLOCK_SIZE], cx
        mov     cx, word ptr [di+2]
        mov     word ptr [di-UMB_BLOCK_SIZE+2], cx
        mov     cx, word ptr [di+4]
        mov     word ptr [di-UMB_BLOCK_SIZE+4], cx
        jmp     short remove_umb_shift
remove_umb_done:
        pop     di
        pop     cx
        pop     ax
        ret
remove_next_umb endp

; Resolve an XMS move endpoint. DX is a handle (zero means a packed
; segment:offset conventional address), EAX is its offset, and ECX is length.
; Returns EAX=physical address. On an invalid nonzero-handle offset, BH=A4h.
resolve_move_address proc near
        xor     bh, bh
        or      dx, dx
        jnz     short resolve_handle
        mov     edx, eax
        and     eax, 0ffffh
        shr     edx, 16
        shl     edx, 4
        add     eax, edx
        clc
        ret
resolve_handle:
        push    dx
        call    validate_handle
        pop     dx
        jc      short resolve_bad_handle
        mov     ebx, ecx
        add     ebx, eax
        jc      short resolve_bad_offset
        movzx   edx, word ptr [si+4]
        shl     edx, 10
        cmp     ebx, edx
        ja      short resolve_bad_offset
        movzx   edx, word ptr [si+2]
        shl     edx, 10
        add     edx, 00100000h
        add     eax, edx
        clc
        ret
resolve_bad_offset:
        mov     bh, ERR_BAD_SRC_OFF
resolve_bad_handle:
        stc
        ret
resolve_move_address endp

copy_move_blocks proc near
copy_move_next:
        mov     eax, [move_length]
        or      eax, eax
        jz      short copy_move_done
        cmp     eax, 0000fffeh
        jbe     short copy_move_final
        mov     ecx, 0000fffeh
        jmp     short copy_move_chunk
copy_move_final:
        mov     ecx, eax
copy_move_chunk:
        mov     [move_chunk], ecx
        mov     eax, [move_source]
        mov     di, offset move_source_desc
        call    set_move_descriptor
        mov     eax, [move_dest]
        mov     di, offset move_dest_desc
        call    set_move_descriptor
        shr     ecx, 1
        push    ds
        push    es
        push    si
        push    di
        push    cs
        pop     es
        mov     si, offset move_gdt
        mov     ah, 087h
        int     015h
        pop     di
        pop     si
        pop     es
        pop     ds
        jc      short copy_move_fail
        mov     ecx, [move_chunk]
        add     [move_source], ecx
        add     [move_dest], ecx
        sub     [move_length], ecx
        jmp     short copy_move_next
copy_move_done:
        clc
        ret
copy_move_fail:
        stc
        ret
copy_move_blocks endp

; EAX=linear base, DI=descriptor. The BIOS move service uses 16-bit limits.
set_move_descriptor proc near
        mov     word ptr [di], 0ffffh
        mov     word ptr [di+2], ax
        shr     eax, 16
        mov     byte ptr [di+4], al
        mov     byte ptr [di+5], 093h
        mov     byte ptr [di+6], 0
        mov     byte ptr [di+7], ah
        ret
set_move_descriptor endp

        align   2
move_gdt:
        dq      0
        dq      0
move_source_desc:
        dq      0
move_dest_desc:
        dq      0
        dq      0
        dq      0

xms_unknown_function proc near
        mov     bl, ERR_NOT_IMPLEMENTED
        jmp     xms_failure
xms_unknown_function endp

validate_handle proc near
        or      dx, dx
        jz      short validate_bad
        cmp     dx, MAX_HANDLES
        ja      short validate_bad
        mov     si, dx
        dec     si
        mov     cl, 3
        shl     si, cl
        add     si, offset handles
        cmp     byte ptr [si], 1
        jne     short validate_bad
        clc
        ret
validate_bad:
        stc
        ret
validate_handle endp

find_free_handle proc near
        mov     si, offset handles
        mov     cx, MAX_HANDLES
find_free_loop:
        cmp     byte ptr [si], 0
        je      short find_free_found
        add     si, HANDLE_SIZE
        loop    find_free_loop
        stc
        ret
find_free_found:
        clc
        ret
find_free_handle endp

count_free_handles proc near
        push    cx
        push    si
        xor     ax, ax
        mov     si, offset handles
        mov     cx, MAX_HANDLES
count_handles_loop:
        cmp     byte ptr [si], 0
        jne     short count_handles_used
        inc     al
count_handles_used:
        add     si, HANDLE_SIZE
        loop    count_handles_loop
        pop     si
        pop     cx
        ret
count_free_handles endp

; Find a first-fit gap of BX KiB. Returns AX=base KiB.
find_gap proc near
        xor     ax, ax
find_gap_retry:
        mov     di, ax
        add     di, bx
        jc      short find_gap_fail
        cmp     di, [extended_kb]
        ja      short find_gap_fail
        mov     si, offset handles
        mov     cx, MAX_HANDLES
find_gap_scan:
        cmp     byte ptr [si], 1
        jne     short find_gap_next
        mov     bp, word ptr [si+2]
        cmp     di, bp
        jbe     short find_gap_next
        add     bp, word ptr [si+4]
        cmp     ax, bp
        jae     short find_gap_next
        mov     ax, bp
        jmp     short find_gap_retry
find_gap_next:
        add     si, HANDLE_SIZE
        loop    find_gap_scan
        clc
        ret
find_gap_fail:
        stc
        ret
find_gap endp

; Verify that growing SI's block to DX KiB does not overlap another handle.
gap_after_handle proc near
        mov     ax, word ptr [si+2]
        add     ax, dx
        jc      short gap_after_fail
        cmp     ax, [extended_kb]
        ja      short gap_after_fail
        mov     di, offset handles
        mov     cx, MAX_HANDLES
gap_after_loop:
        cmp     di, si
        je      short gap_after_next
        cmp     byte ptr [di], 1
        jne     short gap_after_next
        mov     bp, word ptr [di+2]
        cmp     bp, word ptr [si+2]
        jbe     short gap_after_next
        cmp     bp, ax
        jb      short gap_after_fail
gap_after_next:
        add     di, HANDLE_SIZE
        loop    gap_after_loop
        clc
        ret
gap_after_fail:
        stc
        ret
gap_after_handle endp

; Return the largest unallocated interval in AX (KiB).
largest_gap proc near
        push    cx
        push    si
        push    di
        push    bp
        xor     ax, ax                  ; largest
        xor     bx, bx                  ; candidate base
largest_retry:
        mov     dx, [extended_kb]       ; next used base, or pool end
        mov     di, 0ffffh              ; next handle offset
        mov     si, offset handles
        mov     cx, MAX_HANDLES
largest_scan:
        cmp     byte ptr [si], 1
        jne     short largest_next
        mov     bp, word ptr [si+2]
        cmp     bp, bx
        jb      short largest_next
        cmp     bp, dx
        jae     short largest_next
        mov     dx, bp
        mov     di, si
largest_next:
        add     si, HANDLE_SIZE
        loop    largest_scan
        mov     bp, dx
        sub     bp, bx
        cmp     bp, ax
        jbe     short largest_keep
        mov     ax, bp
largest_keep:
        cmp     di, 0ffffh
        je      short largest_done
        mov     bx, word ptr [di+2]
        add     bx, word ptr [di+4]
        jmp     short largest_retry
largest_done:
        pop     bp
        pop     di
        pop     si
        pop     cx
        ret
largest_gap endp

; Return total unallocated extended memory in AX (KiB).
total_free proc near
        push    cx
        push    si
        mov     ax, [extended_kb]
        mov     si, offset handles
        mov     cx, MAX_HANDLES
total_free_loop:
        cmp     byte ptr [si], 1
        jne     short total_free_next
        sub     ax, word ptr [si+4]
total_free_next:
        add     si, HANDLE_SIZE
        loop    total_free_loop
        pop     si
        pop     cx
        ret
total_free endp

resident_end label byte
        end
