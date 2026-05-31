# PR: mob_* plugin cutover, parity hardening, and the RT-01 reliability harness

Branch: `codex/mob-ble-cutover-publish-prep` → `master` (29 commits).

## Summary
Converts the `mob_*` transport plugins to standalone submodules on the canonical
`Mob.Transport` contract, closes the pure-code "bitchat feature-parity" gaps
(channels, fragmentation bounds, retry jitter), stands up a deterministic,
self-diagnosing **RT-01 locked-delivery hardware harness**, and uses it to
*measure* the one remaining headline gap (locked/background BLE receive) — with
the fix designed and ready to validate in one run. Also folds in the upstream
`mob`/`mob_dev` patch migration and iOS/Swift BLE changes carried on this branch.

## 1. Transport plugins → submodules + canonical `Mob.Transport`
- `mob_ble`, `mob_transport`, `mob_cellular`, `mob_mesh`, `mob_wifi` are now git
  submodules (GitHub treated as canonical), pinned + tracked in the umbrella.
- Reworked the plugins to the canonical `Mob.Transport`:
  - `mob_cellular` / `mob_wifi`: **structural** conformance (no `@behaviour`,
    no hard `mob_transport` dep) → standalone-publishable like `mob_ble`;
    `transport_dep/0` resolves the sibling only inside the umbrella.
  - `mob_mesh`: keeps the real dep (uses `Mob.Transport.Adapter` at runtime),
    sibling-or-source resolvable; `credo` env aligned.
  - `mob_wifi` bridge emits canonical bare-tuple transport events.
- Umbrella compiles clean (`--warnings-as-errors` for `mob_*`); all reworked
  plugins' tests green.

## 2. Protocol / runtime parity hardening (pure code)
- **Channels (#7):** `Packet.channel_id` + `@flag_channel`; cleartext
  length-prefixed `Framing` segment (default `""` = byte-identical legacy frame);
  `Router.subscribe/2 channels:` + receive-side filtering. Wire round-trip +
  backward-compat tested.
- **Fragmentation (#6):** verified real (auto-fragment > MTU, reassembly);
  **bounded `FragmentBuffer`** — reassembly TTL + entry cap + evict telemetry.
- **Acks/retry (#5):** verified delivery+read receipts + bounded exponential
  retry already exist; **added equal jitter** to the backoff. Removed dead
  `Outbox.retryable/1`.
- **Multi-hop/TTL (#2):** verified (mesh `ttl: 8`, decrement + path loop-guard +
  dedup).

## 3. RT-01 reliability program (locked-phone BLE delivery)
- Android launch-extra wiring `mob_rt_event_log` / `mob_rt_run_id`.
- Analyzer (`mix mob.node.rt01.analyze`): **strict sustained-receive gate**
  (pass requires receive after the threshold, not an opening burst),
  **capture-coverage guard**, and post-unlock-resume metrics.
- **Hardware harness** `scripts/android/rt01-sustained.sh`: deterministic
  instrumented sender (`mob.ble.SustainedAdvertiseDriver`) + real-app locked
  receiver, fast-abort + per-device BLE diagnostics, analyzer-aligned live counter.
- **Result:** deterministically measured that locked receive does **not** sustain
  (root cause: `BleScanner` did `startScan(null, …)` — Android halts unfiltered
  scans on screen-off). Lever #1 (blanket `ScanFilter`) tried + reverted
  (regressed awake receive). Fix levers 2a (FGS-owned scan) / 2b (beacon-matched
  filter) designed in `docs/rt01_locked_receive_fix*.md`, ready for one-run
  validation.

## 4. Publishing prep
- `docs/publishing_mob_plugins.md`: Hex publish order + the in-umbrella/git-dep
  gotcha (publish from standalone clones; `mob_transport` first; `mob_mesh` last).
  Nothing published yet (gated on parity).

## 5. Carried on this branch (not part of the above workstream)
- Upstream `mob` / `mob_dev` patch migration (patches removed; lock bumps; docs).
- iOS/Swift BLE changes (`Mob.Node` fetch GATT / observer / secure session)
  and the harness model.
- `fix(store): release CubDB lock on DB shutdown`.

## Not in this PR / follow-ups
- **#1 locked receive** — fix designed (lever 2a/2b), needs on-device validation.
- **#8 adaptive power** — deferred to the hardware phase.
- **iOS RT-01** + the real device matrix (Pixel/iPhone) — untested.
- **`mix hex.publish`** — pending bitchat parity.

## Validation notes
Pure-code changes verified by compile + unit tests (run components in isolation;
the full umbrella `mix test` is slow/flaky in some sandboxes — `mob_transport`'s
2 async tests flake under concurrent load but pass 25/0 isolated). RT-01 changes
validated on attached Samsung tablets (T390/T577U) via the harness.
