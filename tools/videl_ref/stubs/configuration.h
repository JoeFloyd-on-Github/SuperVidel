/* Minimal stand-in for Hatari's configuration.h. */
#define MONITOR_TYPE_MONO 0
#define MONITOR_TYPE_RGB 1
#define MONITOR_TYPE_VGA 2
#define MONITOR_TYPE_TV 3
#define MACHINE_FALCON 4
typedef struct { struct { int bAllowOverscan; int nMonitorType; } Screen; struct { int nMachineType; } System; } CNF_PARAMS;
extern CNF_PARAMS ConfigureParams;
