# Research: Hex packages for a MeshX hardware farm

Date: 2026-05-27

## Summary

I did not find a turnkey Hex package that is specifically a multi-user mobile
hardware test farm. The useful Hex ecosystem pieces are adjacent libraries:
fleet/device connection, job orchestration, Phoenix UI, distributed agents,
supervised OS process execution, Apple-device helpers, and low-level hardware
I/O.

## Candidate Packages

| Area | Package | Fit |
| --- | --- | --- |
| Job queue / run scheduler | [`oban`](https://hex.pm/packages/oban) | Persistent run queue, retries, uniqueness, scheduled jobs, operator-triggered jobs. |
| Job dashboard | [`oban_web`](https://hex.pm/packages/oban_web) | Useful if Oban Pro is acceptable; otherwise build a LiveView run dashboard. |
| Embedded/fleet inspiration | [`nerves`](https://hex.pm/packages/nerves), [`nerves_hub_link`](https://hex.pm/packages/nerves_hub_link), [`nerves_hub_cli`](https://hex.pm/packages/nerves_hub_cli) | Strong precedent for device identity, fleet grouping, firmware/app rollout, and device presence, but not a generic phone/tablet lab farm. |
| IoT device SDK | [`astarte_device`](https://hex.pm/packages/astarte_device) | Relevant if lab agents should speak to an IoT platform; less direct for adb/devicectl orchestration. |
| Apple device tooling | [`orchard`](https://hex.pm/packages/orchard), [`apple_developer`](https://hex.pm/packages/apple_developer) | Potential helpers for iOS device/simulator management and Apple Developer API concerns. Needs vetting due young/low-download packages. |
| External commands | [`muontrap`](https://hex.pm/packages/muontrap), [`ex_cmd`](https://hex.pm/packages/ex_cmd), [`erlexec`](https://hex.pm/packages/erlexec) | Running `adb`, `xcrun devicectl`, logcat capture, long-lived subprocesses, cancellation, and cleanup. |
| Distributed agents | [`libcluster`](https://hex.pm/packages/libcluster), [`horde`](https://hex.pm/packages/horde) | Lab host discovery and distributed process/registry patterns if agents run as clustered BEAM nodes. |
| BLE / serial hardware | [`blue_heron`](https://hex.pm/packages/blue_heron), [`circuits_uart`](https://hex.pm/packages/circuits_uart) | Useful for lab-side BLE adapters, serial rigs, power controllers, or non-phone hardware. Not a substitute for Android/iOS radio behavior. |
| UI / observability | [`phoenix`](https://hex.pm/packages/phoenix), [`phoenix_live_dashboard`](https://hex.pm/packages/phoenix_live_dashboard) | Multi-user dashboard, live run logs, node/VM health, and operator workflows. |

## Architectural Takeaway

Build the hardware farm as an application, not a library adoption. The likely
stack is Phoenix + Postgres + Oban for the coordinator, plus a supervised agent
per lab host. Keep `adb`, `xcrun`, power control, BLE adapters, and log capture
behind explicit driver modules so the coordinator manages reservations and
evidence without depending on one host's local tooling.

## Watch Outs

- Hex has good primitives but not a Sauce Labs / Firebase Test Lab equivalent
  for Elixir.
- Young Apple-device packages may help, but the hard part is still reliable
  physical-device state: pairing, permissions, app installation, awake state,
  Bluetooth reset, and log capture.
- NervesHub is highly relevant as a design reference for fleet/device identity,
  but MeshX lab phones/tablets are not Nerves devices unless you add dedicated
  Nerves lab controllers.
- For command execution, prefer a supervised process wrapper over raw
  `System.cmd/3`, because failed jobs must clean up child processes and log
  streams.
