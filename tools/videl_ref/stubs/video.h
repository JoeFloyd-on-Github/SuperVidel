/* Monitor codes as $FFFF8006 bits 7:6 (videl.c header comment, S035). */
#define FALCON_MONITOR_MONO 0x00
#define FALCON_MONITOR_RGB  0x40
#define FALCON_MONITOR_VGA  0x80
#define FALCON_MONITOR_TV   0xC0
extern bool bUseHighRes;
uint32_t Video_GetScreenBaseAddr(void);
