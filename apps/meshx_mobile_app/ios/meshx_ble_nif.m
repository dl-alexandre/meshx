#include "erl_nif.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern void meshx_ble_start_scan(void);
extern void meshx_ble_start_advertising(const char *local_name);
extern void meshx_ble_stop(void);
extern void meshx_ble_send_ping(const char *peer_id, const uint8_t *payload, int32_t payload_len);

static ErlNifMutex *owner_mutex = NULL;
static ErlNifPid owner_pid;
static int owner_set = 0;

static ERL_NIF_TERM atom(ErlNifEnv *env, const char *name) {
    return enif_make_atom(env, name);
}

static ERL_NIF_TERM ok(ErlNifEnv *env) {
    return atom(env, "ok");
}

static int set_owner(ErlNifEnv *env, ERL_NIF_TERM owner) {
    ErlNifPid pid;
    if (!enif_get_local_pid(env, owner, &pid)) {
        return 0;
    }

    enif_mutex_lock(owner_mutex);
    owner_pid = pid;
    owner_set = 1;
    enif_mutex_unlock(owner_mutex);
    return 1;
}

static char *copy_string_arg(ErlNifEnv *env, ERL_NIF_TERM term) {
    ErlNifBinary bin;
    if (!enif_inspect_iolist_as_binary(env, term, &bin)) {
        return NULL;
    }

    char *copy = (char *)malloc(bin.size + 1);
    if (copy == NULL) {
        return NULL;
    }

    memcpy(copy, bin.data, bin.size);
    copy[bin.size] = '\0';
    return copy;
}

static ERL_NIF_TERM binary_string(ErlNifEnv *env, const char *value) {
    size_t len = strlen(value);
    ERL_NIF_TERM out;
    unsigned char *data = enif_make_new_binary(env, len, &out);
    memcpy(data, value, len);
    return out;
}

static ERL_NIF_TERM binary_bytes(ErlNifEnv *env, const uint8_t *value, uint32_t len) {
    ERL_NIF_TERM out;
    unsigned char *data = enif_make_new_binary(env, len, &out);
    if (len > 0 && value != NULL) {
        memcpy(data, value, len);
    } else if (len > 0) {
        memset(data, 0, len);
    }
    return out;
}

static ERL_NIF_TERM packet_type(ErlNifEnv *env, int32_t type) {
    switch (type) {
        case 1: return atom(env, "data");
        case 2: return atom(env, "ack");
        case 3: return atom(env, "gossip");
        case 4: return atom(env, "control");
        case 5: return atom(env, "fragment");
        default: return atom(env, "unknown");
    }
}

static void send_event(ErlNifEnv *env, ERL_NIF_TERM event) {
    enif_mutex_lock(owner_mutex);
    if (!owner_set) {
        enif_mutex_unlock(owner_mutex);
        return;
    }

    ErlNifPid pid = owner_pid;
    enif_mutex_unlock(owner_mutex);

    ERL_NIF_TERM msg = enif_make_tuple3(
        env,
        atom(env, "Elixir.MeshxMobileApp.NativeBridge"),
        atom(env, "bridge_event"),
        event
    );

    enif_send(NULL, &pid, env, msg);
}

void meshx_ble_emit_status(const char *status) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM event = enif_make_tuple2(env, atom(env, "status"), binary_string(env, status));
    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_connected(const char *peer_id) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM event = enif_make_tuple2(env, atom(env, "connected"), binary_string(env, peer_id));
    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_disconnected(const char *peer_id) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM event = enif_make_tuple2(env, atom(env, "disconnected"), binary_string(env, peer_id));
    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_received(const char *peer_id, int32_t type, uint32_t msg_id, uint32_t byte_count) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM packet = enif_make_new_map(env);
    enif_make_map_put(env, packet, atom(env, "type"), packet_type(env, type), &packet);
    enif_make_map_put(env, packet, atom(env, "msg_id"), enif_make_uint(env, msg_id), &packet);
    enif_make_map_put(env, packet, atom(env, "bytes"), enif_make_uint(env, byte_count), &packet);

    ERL_NIF_TERM event = enif_make_tuple3(
        env,
        atom(env, "received"),
        binary_string(env, peer_id),
        packet
    );

    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_received_message_beacon(
    const char *device_id,
    int32_t rssi,
    int32_t beacon_version,
    int32_t envelope_version,
    const char *payload_kind,
    const uint8_t *message_id_hash,
    const uint8_t *sender_peer_id_hash,
    const uint8_t *advertisement,
    uint32_t advertisement_len,
    const uint8_t *beacon_payload,
    uint32_t beacon_payload_len,
    const uint8_t *manufacturer_data,
    uint32_t manufacturer_data_len,
    uint32_t company_identifier
) {
    ErlNifEnv *env = enif_alloc_env();

    ERL_NIF_TERM metadata = enif_make_new_map(env);
    enif_make_map_put(env, metadata, atom(env, "transport"), binary_string(env, "ble_ios_advertisement"), &metadata);
    enif_make_map_put(env, metadata, atom(env, "source_event"), binary_string(env, "advertisement_received"), &metadata);
    enif_make_map_put(env, metadata, atom(env, "received_device_id"), binary_string(env, device_id), &metadata);
    enif_make_map_put(env, metadata, atom(env, "advertisement"), binary_bytes(env, advertisement, advertisement_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "beacon_payload"), binary_bytes(env, beacon_payload, beacon_payload_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "manufacturer_data"), binary_bytes(env, manufacturer_data, manufacturer_data_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "company_identifier"), enif_make_uint(env, company_identifier), &metadata);
    enif_make_map_put(env, metadata, atom(env, "ad_type"), enif_make_uint(env, 0xFF), &metadata);

    ERL_NIF_TERM event = enif_make_new_map(env);
    enif_make_map_put(env, event, atom(env, "v"), enif_make_uint(env, 1), &event);
    enif_make_map_put(env, event, atom(env, "event"), binary_string(env, "received_message_beacon"), &event);
    enif_make_map_put(env, event, atom(env, "beacon_version"), enif_make_int(env, beacon_version), &event);
    enif_make_map_put(env, event, atom(env, "envelope_version"), enif_make_int(env, envelope_version), &event);
    enif_make_map_put(env, event, atom(env, "payload_kind"), binary_string(env, payload_kind), &event);
    enif_make_map_put(env, event, atom(env, "message_id_hash"), binary_bytes(env, message_id_hash, 8), &event);
    enif_make_map_put(env, event, atom(env, "sender_peer_id_hash"), binary_bytes(env, sender_peer_id_hash, 8), &event);
    enif_make_map_put(env, event, atom(env, "received_device_id"), binary_string(env, device_id), &event);
    enif_make_map_put(env, event, atom(env, "received_at"), enif_make_int64(env, enif_monotonic_time(ERL_NIF_MSEC)), &event);
    enif_make_map_put(env, event, atom(env, "rssi"), enif_make_int(env, rssi), &event);
    enif_make_map_put(env, event, atom(env, "raw_transport_metadata"), metadata, &event);

    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_received_message(
    const char *device_id,
    int32_t rssi,
    int64_t received_at_ms,
    const uint8_t *message_id,
    uint32_t message_id_len,
    const char *sender_peer_id,
    const char *recipient_peer_id,
    const uint8_t *envelope,
    uint32_t envelope_len,
    const uint8_t *advertisement,
    uint32_t advertisement_len,
    const uint8_t *message_payload,
    uint32_t message_payload_len,
    const uint8_t *manufacturer_data,
    uint32_t manufacturer_data_len,
    uint32_t company_identifier
) {
    ErlNifEnv *env = enif_alloc_env();

    ERL_NIF_TERM metadata = enif_make_new_map(env);
    enif_make_map_put(env, metadata, atom(env, "transport"), binary_string(env, "ble_ios_advertisement"), &metadata);
    enif_make_map_put(env, metadata, atom(env, "source_event"), binary_string(env, "advertisement_received"), &metadata);
    enif_make_map_put(env, metadata, atom(env, "received_device_id"), binary_string(env, device_id), &metadata);
    enif_make_map_put(env, metadata, atom(env, "advertisement"), binary_bytes(env, advertisement, advertisement_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "message_payload"), binary_bytes(env, message_payload, message_payload_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "manufacturer_data"), binary_bytes(env, manufacturer_data, manufacturer_data_len), &metadata);
    enif_make_map_put(env, metadata, atom(env, "company_identifier"), enif_make_uint(env, company_identifier), &metadata);
    enif_make_map_put(env, metadata, atom(env, "ad_type"), enif_make_uint(env, 0xFF), &metadata);

    ERL_NIF_TERM recipient_term =
        (recipient_peer_id == NULL) ? atom(env, "nil") : binary_string(env, recipient_peer_id);

    ERL_NIF_TERM event = enif_make_new_map(env);
    enif_make_map_put(env, event, atom(env, "v"), enif_make_uint(env, 1), &event);
    enif_make_map_put(env, event, atom(env, "event"), binary_string(env, "received_message"), &event);
    enif_make_map_put(env, event, atom(env, "message_id"), binary_bytes(env, message_id, message_id_len), &event);
    enif_make_map_put(env, event, atom(env, "sender_peer_id"), binary_string(env, sender_peer_id), &event);
    enif_make_map_put(env, event, atom(env, "recipient_peer_id"), recipient_term, &event);
    enif_make_map_put(env, event, atom(env, "received_device_id"), binary_string(env, device_id), &event);
    enif_make_map_put(env, event, atom(env, "received_at"), enif_make_int64(env, received_at_ms), &event);
    enif_make_map_put(env, event, atom(env, "rssi"), enif_make_int(env, rssi), &event);
    enif_make_map_put(env, event, atom(env, "envelope"), binary_bytes(env, envelope, envelope_len), &event);
    enif_make_map_put(env, event, atom(env, "raw_transport_metadata"), metadata, &event);

    send_event(env, event);
    enif_free_env(env);
}

void meshx_ble_emit_error(const char *message) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM event = enif_make_tuple2(env, atom(env, "error"), binary_string(env, message));
    send_event(env, event);
    enif_free_env(env);
}

static ERL_NIF_TERM nif_start_scan(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 1 || !set_owner(env, argv[0])) {
        return enif_make_badarg(env);
    }

    meshx_ble_start_scan();
    return ok(env);
}

static ERL_NIF_TERM nif_start_advertising(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 2 || !set_owner(env, argv[0])) {
        return enif_make_badarg(env);
    }

    char *local_name = copy_string_arg(env, argv[1]);
    if (local_name == NULL) {
        return enif_make_badarg(env);
    }

    meshx_ble_start_advertising(local_name);
    free(local_name);
    return ok(env);
}

static ERL_NIF_TERM nif_stop(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 1 || !set_owner(env, argv[0])) {
        return enif_make_badarg(env);
    }

    meshx_ble_stop();
    return ok(env);
}

static ERL_NIF_TERM nif_send_ping(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 3 || !set_owner(env, argv[0])) {
        return enif_make_badarg(env);
    }

    char *peer_id = copy_string_arg(env, argv[1]);
    if (peer_id == NULL) {
        return enif_make_badarg(env);
    }

    ErlNifBinary payload;
    if (!enif_inspect_iolist_as_binary(env, argv[2], &payload)) {
        free(peer_id);
        return enif_make_badarg(env);
    }

    meshx_ble_send_ping(peer_id, payload.data, (int32_t)payload.size);
    free(peer_id);
    return ok(env);
}

static ErlNifFunc nif_funcs[] = {
    {"start_scan", 1, nif_start_scan, 0},
    {"start_advertising", 2, nif_start_advertising, 0},
    {"stop", 1, nif_stop, 0},
    {"send_ping", 3, nif_send_ping, 0}
};

static int nif_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
    (void)env;
    (void)priv;
    (void)info;
    owner_mutex = enif_mutex_create("meshx_ble_owner_mutex");
    return owner_mutex == NULL ? 1 : 0;
}

ERL_NIF_INIT(meshx_ble_nif, nif_funcs, nif_load, NULL, NULL, NULL)
