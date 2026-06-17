/* OW-compat module for ATTRIB (option b: OW cstart is the entry).
   - getpspbyte/putpspbyte: MS-C SLIBCE PSP-byte accessors OW's clib lacks,
     using OW's _psp (set by cstart).
   - main(): the C entry cstart calls; reconstructs the DOS command tail
     (PSP:0x80) and hands it to the utility's inmain(), replacing the old
     MS-C XCMAIN asm startup. */
#include <dos.h>
extern unsigned _psp;

unsigned char getpspbyte(unsigned off)
{
    return *(unsigned char __far *)MK_FP(_psp, off);
}
void putpspbyte(unsigned off, unsigned char val)
{
    *(unsigned char __far *)MK_FP(_psp, off) = val;
}

extern int inmain(char *line);
static char _ow_cmdtail[130];
int main(void)
{
    unsigned n = getpspbyte(0x80), i;
    if (n > 128) n = 128;
    for (i = 0; i < n; i++) _ow_cmdtail[i] = getpspbyte(0x81 + i);
    _ow_cmdtail[n] = '\0';
    inmain(_ow_cmdtail);
    return 0;
}
