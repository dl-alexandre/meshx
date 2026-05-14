%% meshx_ble_nif.erl — iOS BLE NIF stub for the Mob app.
%% The native implementation is linked statically into the iOS binary.
-module(meshx_ble_nif).

-export([start_scan/1, start_advertising/2, stop/1, send_ping/3]).
-nifs([start_scan/1, start_advertising/2, stop/1, send_ping/3]).
-on_load(init/0).

init() -> erlang:load_nif("meshx_ble_nif", 0).

start_scan(_Owner) -> erlang:nif_error(not_loaded).
start_advertising(_Owner, _LocalName) -> erlang:nif_error(not_loaded).
stop(_Owner) -> erlang:nif_error(not_loaded).
send_ping(_Owner, _PeerId, _Payload) -> erlang:nif_error(not_loaded).
