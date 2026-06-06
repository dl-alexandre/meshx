// driver_tab_meshx_ios.c — Static NIF table for MeshxMobileApp.

#include <stddef.h>

typedef struct { void* de; int flags; } ErtsStaticDriver;
#define THE_NON_VALUE ((unsigned long)0)
typedef struct {
    void* (*nif_init)(void);
    int   is_builtin;
    unsigned long nif_mod;
    void* entry;
} ErtsStaticNif;

typedef struct { void* de; int flags; } ErlDrvEntryStub;
extern ErlDrvEntryStub inet_driver_entry;
extern ErlDrvEntryStub ram_file_driver_entry;

ErtsStaticDriver driver_tab[] = {
    {&inet_driver_entry, 0},
    {&ram_file_driver_entry, 0},
    {NULL, 0}
};

void erts_init_static_drivers(void) {}

void *prim_tty_nif_init(void);
void *erl_tracer_nif_init(void);
void *prim_buffer_nif_init(void);
void *prim_file_nif_init(void);
void *zlib_nif_init(void);
void *zstd_nif_init(void);
void *prim_socket_nif_init(void);
void *prim_net_nif_init(void);
void *asn1rt_nif_nif_init(void);
void *crypto_nif_init(void);
void *mob_nif_nif_init(void);
void *mob_ble_nif_nif_init(void);

#ifdef MOB_STATIC_SQLITE_NIF
void *sqlite3_nif_nif_init(void);
#endif

ErtsStaticNif erts_static_nif_tab[] = {
    {prim_tty_nif_init,       0, THE_NON_VALUE, NULL},
    {erl_tracer_nif_init,     0, THE_NON_VALUE, NULL},
    {prim_buffer_nif_init,    0, THE_NON_VALUE, NULL},
    {prim_file_nif_init,      0, THE_NON_VALUE, NULL},
    {zlib_nif_init,           0, THE_NON_VALUE, NULL},
    {zstd_nif_init,           0, THE_NON_VALUE, NULL},
    {prim_socket_nif_init,    0, THE_NON_VALUE, NULL},
    {prim_net_nif_init,       0, THE_NON_VALUE, NULL},
    {asn1rt_nif_nif_init,     1, THE_NON_VALUE, NULL},
    {crypto_nif_init,         1, THE_NON_VALUE, NULL},
    {mob_nif_nif_init,        0, THE_NON_VALUE, NULL},
    {mob_ble_nif_nif_init,    0, THE_NON_VALUE, NULL},
#ifdef MOB_STATIC_SQLITE_NIF
    {sqlite3_nif_nif_init,    0, THE_NON_VALUE, NULL},
#endif
    {NULL,                    0, THE_NON_VALUE, NULL}
};
