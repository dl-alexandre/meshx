// driver_tab_android.c — Static NIF table for meshx_mobile_app.
//
// Generated variant of deps/mob/android/jni/driver_tab_android.c with the
// project NIF `meshx_ble_nif` (c_src/meshx_ble_nif.c) added. CMakeLists.txt
// prefers priv/generated/driver_tab_android.c over the stock mob one when
// it exists, so this file is what wires the BLE NIF into the static table.
//
// Link BEFORE libbeam.a to override the built-in driver_tab.

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

// crypto.c's ERL_NIF_INIT(crypto,...) generates: crypto_nif_init.
void *crypto_nif_init(void);

// mob_nif.c's ERL_NIF_INIT(mob_nif,...) generates: mob_nif_nif_init
void *mob_nif_nif_init(void);

// c_src/meshx_ble_nif.c — compiled with -DSTATIC_ERLANG_NIF_LIBNAME=meshx_ble_nif
// so ERL_NIF_INIT(meshx_ble_nif,...) emits: meshx_ble_nif_nif_init
void *meshx_ble_nif_nif_init(void);

ErtsStaticNif erts_static_nif_tab[] = {
    {prim_tty_nif_init,     0, THE_NON_VALUE, NULL},
    {erl_tracer_nif_init,   0, THE_NON_VALUE, NULL},
    {prim_buffer_nif_init,  0, THE_NON_VALUE, NULL},
    {prim_file_nif_init,    0, THE_NON_VALUE, NULL},
    {zlib_nif_init,         0, THE_NON_VALUE, NULL},
    {zstd_nif_init,         0, THE_NON_VALUE, NULL},
    {prim_socket_nif_init,  0, THE_NON_VALUE, NULL},
    {prim_net_nif_init,     0, THE_NON_VALUE, NULL},
    {asn1rt_nif_nif_init,   1, THE_NON_VALUE, NULL},
    {crypto_nif_init,       1, THE_NON_VALUE, NULL},
    {mob_nif_nif_init,      0, THE_NON_VALUE, NULL},
    {meshx_ble_nif_nif_init, 0, THE_NON_VALUE, NULL},
    {NULL,                  0, THE_NON_VALUE, NULL}
};
