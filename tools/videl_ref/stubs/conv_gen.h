/* Minimal stand-in for Hatari's conv_gen.h. */
static inline void ConvGen_SetSize(int w,int h,bool f){(void)w;(void)h;(void)f;}
static inline void ConvGen_SetPaletteColor(int i,int r,int g,int b){extern uint32_t ref_palette[256]; ref_palette[i]=(r<<16)|(g<<8)|b;}
static inline void ConvGen_Convert(uint32_t a,uint8_t*p,int xs,int ys,int bpp,int nl,int hs,int l,int r,int u,int lo){(void)a;(void)p;(void)xs;(void)ys;(void)bpp;(void)nl;(void)hs;(void)l;(void)r;(void)u;(void)lo;}
