/* Minimal stand-in for Hatari's ioMem.h: 16 MB big-endian I/O image. */
#define SIZE_BYTE 1
#define SIZE_WORD 2
#define SIZE_LONG 4
extern uint8_t IoMem[0x1000000];
extern uint32_t IoAccessCurrentAddress, IoAccessBaseAddress;
extern int nIoMemAccessSize;
static inline uint8_t IoMem_ReadByte(uint32_t a){return IoMem[a&0xffffff];}
static inline uint16_t IoMem_ReadWord(uint32_t a){a&=0xffffff;return (IoMem[a]<<8)|IoMem[a+1];}
static inline uint32_t IoMem_ReadLong(uint32_t a){return ((uint32_t)IoMem_ReadWord(a)<<16)|IoMem_ReadWord(a+2);}
static inline void IoMem_WriteByte(uint32_t a,uint8_t v){IoMem[a&0xffffff]=v;}
static inline void IoMem_WriteWord(uint32_t a,uint16_t v){a&=0xffffff;IoMem[a]=v>>8;IoMem[a+1]=v;}
static inline void IoMem_WriteLong(uint32_t a,uint32_t v){IoMem_WriteWord(a,v>>16);IoMem_WriteWord(a+2,v);}
