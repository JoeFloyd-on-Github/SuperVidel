/*
 * videl_ref.c - golden model for the SV-Lite Videl core.
 *
 * Compiles Hatari's unmodified src/falcon/videl.c (sources S035) against
 * the minimal stubs in ./stubs, replays register-write vectors, and prints
 * the geometry and palette Hatari derives.  The VHDL testbench
 * (hdl/videl/tb/tb_videl_core.vhd) checks the core against this output.
 *
 * Licence: GPL-2.0-or-later (links Hatari code).
 *
 * Vector file format (one command per line, '#' comments):
 *   test <name> <mono|rgb|vga|tv>   start a test (resets the model)
 *   w <addr> <b|w|l> <value>         CPU write, hex address and value
 *   end                              print the result line
 * Output, one line per test:
 *   <name> bpp xsize left right ysize upper lower nextline hscroll use_st
 *          base pal0..pal15 (24-bit RGB hex)
 */
#include <string.h>
#include <stdlib.h>
#include "videl.c"

uint8_t IoMem[0x1000000];
uint32_t IoAccessCurrentAddress, IoAccessBaseAddress;
int nIoMemAccessSize;
CNF_PARAMS ConfigureParams;
uint8_t STRam[16];
uint16_t TosVersion = 0x404;
bool bUseHighRes, bUseVDIRes;
uint32_t ref_palette[256];
bool Screen_Lock(void){return false;}
void Screen_UnLock(void){}
void Screen_GenConvUpdate(bool u){(void)u;}

uint32_t Video_GetScreenBaseAddr(void)
{
	return (IoMem[0xff8201] << 16) | (IoMem[0xff8203] << 8) | IoMem[0xff820d];
}

/* Call Hatari's write handler for one byte/word access, as ioMemTabFalcon.c would. */
static void dispatch(uint32_t a, int size)
{
	IoAccessCurrentAddress = a;
	IoAccessBaseAddress = a;
	nIoMemAccessSize = size;
	if (a == 0xff8201 || a == 0xff8203 || a == 0xff820d)
		VIDEL_ScreenBase_WriteByte();
	else if (a == 0xff8260)
		VIDEL_ST_ShiftModeWriteByte();
	else if (a == 0xff8266 && size != SIZE_BYTE)
		VIDEL_Falcon_ShiftMode_WriteWord();
	else if (a >= 0xff8240 && a < 0xff8260)
		Videl_ColorReg_WriteWord();
	else if (a >= 0xff9800 && a < 0xff9c00)
		VIDEL_FalconColorRegsWrite();
}

static void cpu_write(uint32_t a, int size, uint32_t v)
{
	a &= 0xffffff;
	if (size == SIZE_LONG && a >= 0xff9800 && a < 0xff9c00) {
		IoMem_WriteLong(a, v);
		dispatch(a, SIZE_LONG);
		return;
	}
	if (size == SIZE_LONG) {      /* two word accesses, as Hatari's ioMem does for .L */
		cpu_write(a, SIZE_WORD, v >> 16);
		cpu_write(a + 2, SIZE_WORD, v & 0xffff);
		return;
	}
	if (size == SIZE_WORD) {
		IoMem_WriteWord(a, v);
		if (a >= 0xff8240 && a < 0xff8260)
			dispatch(a, SIZE_WORD);
		else if (a == 0xff8266)
			dispatch(a, SIZE_WORD);
		else {
			dispatch(a, SIZE_WORD);
			dispatch(a + 1, SIZE_WORD);
		}
		return;
	}
	IoMem_WriteByte(a, v);
	dispatch(a, SIZE_BYTE);
}

int main(int argc, char **argv)
{
	FILE *f = argc > 1 ? fopen(argv[1], "r") : stdin;
	char line[256], name[64] = "", mon[16];
	if (!f) { perror(argv[1]); return 1; }
	ConfigureParams.Screen.bAllowOverscan = 1;
	while (fgets(line, sizeof line, f)) {
		char *p = line;
		while (*p == ' ' || *p == '\t') p++;
		if (*p == '#' || *p == '\n' || !*p) continue;
		if (!strncmp(p, "test", 4)) {
			sscanf(p, "test %63s %15s", name, mon);
			memset(IoMem, 0, sizeof IoMem);
			IoMem[0xff8006] = !strcmp(mon, "mono") ? 0x00 : !strcmp(mon, "rgb") ? 0x40
			                : !strcmp(mon, "vga") ? 0x80 : 0xc0;
			memset(&videl, 0, sizeof videl);
			VIDEL_reset();
		} else if (*p == 'w') {
			unsigned a, v; char s;
			sscanf(p, "w %x %c %x", &a, &s, &v);
			cpu_write(a, s == 'b' ? SIZE_BYTE : s == 'w' ? SIZE_WORD : SIZE_LONG, v);
		} else if (!strncmp(p, "end", 3)) {
			int w = VIDEL_getScreenWidth();
			int h = VIDEL_getScreenHeight();
			int bpp = VIDEL_getScreenBpp();
			(void)w; (void)h;
			videl.save_scrBpp = bpp;
			videl.hostColorsSync = false;
			memset(ref_palette, 0, sizeof ref_palette);
			VIDEL_UpdateColors();
			printf("%s %d %d %d %d %d %d %d %d %d %d %06x", name, bpp, videl.XSize,
			       videl.leftBorderSize, videl.rightBorderSize, videl.YSize,
			       videl.upperBorderSize, videl.lowerBorderSize,
			       (IoMem_ReadWord(0xff8210) & 0x3ff) + (IoMem_ReadWord(0xff820e) & 0x1ff),
			       IoMem_ReadByte(0xff8265) & 0x0f, videl.bUseSTShifter ? 1 : 0,
			       Video_GetScreenBaseAddr());
			for (int i = 0; i < 16; i++)
				printf(" %06x", ref_palette[i]);
			printf("\n");
		}
	}
	return 0;
}
