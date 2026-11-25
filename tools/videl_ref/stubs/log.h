/* Minimal stand-in for Hatari's log.h. */
#define LOG_TRACE(...) do{}while(0)
#define LOG_TRACE_LEVEL(...) 0
#define LOG_DEBUG 0
static inline void Log_Printf(int l, const char *f, ...){(void)l;(void)f;}
