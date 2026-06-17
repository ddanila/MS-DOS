/* OW-compat shim: MS C 5.10 SLIBCE PSP-byte accessors (getpspbyte/putpspbyte),
   which Open Watcom's clib lacks. PSP segment fetched via INT 21h AH=62h so
   the functions need no C-runtime startup init. Compiled cdecl (-ecc) to match
   the MS-C ABI of the callers. */
#include <dos.h>
unsigned char getpspbyte(unsigned off)
{
    union REGS r; struct SREGS s;
    r.h.ah = 0x62; intdosx(&r, &r, &s);          /* BX <- PSP segment */
    return *(unsigned char __far *)MK_FP(r.x.bx, off);
}
void putpspbyte(unsigned off, unsigned char val)
{
    union REGS r; struct SREGS s;
    r.h.ah = 0x62; intdosx(&r, &r, &s);
    *(unsigned char __far *)MK_FP(r.x.bx, off) = val;
}
