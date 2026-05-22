# `mob_ble` Bridge Behaviour Migration Strategy

**Date**: 2026-05-19 (Phase 3) / 2026-05-21 (final doc polish pass, concurrent with upstream patch migration PR)  
**Status**: Phase 1 + 2 + 3 complete (canonical `Mob.Ble.Bridge`; ... final hygiene landed). Publication-ready for `mix hex.publish`; Phase 4 future. The upstream `mob_dev`/`mob` patch migration (separate PR) is also complete as of 2026-05-21 (see its checklist). 
**Owner**: MeshX / mob integration maintainers  
**Related artifacts**: `docs/BLE_BRIDGE.md`, `docs/upstream_mob_migration_checklist.md`, `docs/remaining_items_audit.md`, `apps/mob_ble/mix.exs`, `apps/mob_ble/lib/mob/ble/mobile_bridge.ex`, `apps/meshx_transport_ble/lib/meshx_transport_ble/bridge.ex`

---

## Implementation Status (2026-05-19)

This document is a forward plan. The table tracks which sections have
landed vs. remain. Update on every PR that closes a row.

| Area | Status | Evidence |
| --- | --- | --- |
| `mob_ble` package scaffold (`Mob.Ble`, `MobileBridge`, `Diagnostics`, `CarrierRejectedError`) | ✅ Done | `apps/mob_ble/lib/mob/ble/*.ex` |
| Internal v1 wire decoder (`Mob.Ble.Internal.BridgeProtocol`) | ✅ Done | `apps/mob_ble/lib/mob/ble/internal/bridge_protocol.ex` |
| Canonical carrier ledger with evidence + upstream issue refs | ✅ Done | `apps/mob_ble/lib/mob/ble/internal/carrier_decision.ex` |
| `validate_config/1` + `assert_carrier!/1` enforced at `start_link` | ✅ Done | `mobile_bridge.ex` start_link path; tests in `mob_ble_test.exs` |
| `LocalIOSAdvertCarrierDecision` → thin facade over canonical ledger | ✅ Done | `apps/meshx_mobile_app/lib/.../local_ios_advert_carrier_decision.ex` |
| Android Kotlin sources moved to `priv/native/android/` | ✅ Done | `apps/mob_ble/priv/native/android/src/main/java/mob/ble/` |
| Android JNI C NIF + Gradle/CMake wired | ✅ Done | `apps/mob_ble/priv/native/android/jni/` |
| iOS Swift core (`MobBleBridge.swift`, `mob_ble_nif.m`) under `priv/native/ios/` | ✅ Done | `apps/mob_ble/priv/native/ios/` |
| iOS supporting protocol Swift vendoring (Frame, MessageEnvelope, FetchProtocol, …) | ✅ Done | 15 sanitized Swift sources in `apps/mob_ble/priv/native/ios/` (Frame, MessageEnvelope, MobFetchProtocol, MobFetchGatt, MobFetchGattResponder, Chunk, Fragment, BLAKE2s, Noise, SecureSession, MessageAdvertisement, MessageAdvertisementObserver, BLE, MobBleBridge, mob_ble_nif.m); included in `mix hex.build` tarball |
| `meshx_mobile_app` env-gated wiring (default `mob_ble` path) | ✅ Phase 2 complete | `app.ex` (defaults to mob_ble unless `MOB_BLE_TRANSPORT=0`; `Mob.Ble.SelfTest` wired; full docs + README polish); primary wiring test `mob_ble_transport_wiring_test.exs` |
| Plugin self-test (`Mob.Ble.SelfTest`) | ✅ Done | `apps/mob_ble/lib/mob/ble/self_test.ex` + test |
| `docs/BLE_BRIDGE.md` migration signpost block | ✅ Done | Top of `docs/BLE_BRIDGE.md` |
| **Bridge behaviour relocation** (`MeshxTransportBLE.Bridge` → `Mob.Ble.Bridge`) | ✅ Phase 1 complete | `apps/mob_ble/lib/mob/ble/bridge.ex` (rich canonical + CONTRACT SYNC); `MobileBridge` updated; tiny sync copy + marker in `apps/meshx_transport_ble/lib/.../bridge.ex` |
| **Drop `meshx_transport_ble` umbrella dep** from `mob_ble/mix.exs` | ✅ Phase 1 complete | Removed (no test-only dep needed; integration tests use local mock only). `mix hex.build` succeeds on dep axis for `mob_ble`. |
| `LICENSE` + `CHANGELOG.md` at `apps/mob_ble/` | ✅ Done (Phase 2) | Files present at root of package; referenced in `mix.exs` `:files` and `:docs` extras; included in `hex.build` tarball |
| Pre-existing `MobBle.Application` test conflicts (23 failures) | ✅ Done (Phase 2) | `Application.stop(:mob_ble)` in `test/test_helper.exs` makes lifecycle tests deterministic; no auto-start conflicts; full `mix test apps/mob_ble` passes |

**Phase 1 + Phase 2 deliverables achieved:** behaviour relocation + dep drop (P1); explicit umbrella dep hygiene in consumer + default path flip + SelfTest wiring + full docs/audit polish + LICENSE/CHANGELOG + test isolation (P2). `mix hex.build` for `mob_ble` succeeds cleanly (zero meshx_* runtime deps, complete metadata + file list). See "Build / Dependency / Hex Publication Implications" and updated audit files. Phase 3 covers coordinated release, changelogs, cutover comms, on-device validation of the new default, and Hex publication.

---

## Executive Summary

(The pre-Phase-1 state described in the original strategy: The `Bridge` behaviour lived in `meshx_transport_ble` as `MeshxTransportBLE.Bridge`. `MobileBridge` declared the MeshX behaviour and `mob_ble` had the hard dep.) Phase 1 moved canonical ownership + rich contract to `Mob.Ble.Bridge` inside `mob_ble` (with full hygiene); `MobileBridge` now uses the local behaviour; the runtime dep is eliminated.

This violates the strict "no meshx in plugin-owned sources" rule required for `mob_ble` to be a first-class, self-contained plugin for the `mob` framework.

**Goal**: Move canonical ownership of the behaviour (and its documented contract) to `mob_ble` (as `Mob.Ble.Bridge`) so that:

* `mob + mob_ble` users never need to know about, or depend on, `meshx_transport_ble`.
* `mob_ble` can be published to Hex independently (removing the last documented publication blocker).
* `MeshxTransportBLE` (and the MeshX ecosystem) retain full compatibility via identical callback signatures + explicit documentation.
* No runtime behaviour changes for any existing code.

The contract surface is tiny (3 callbacks + a stable inbound message convention), making a clean split with minimal duplication feasible and safe.

---

## Current State (Post-Phase 3 / Publication Ready)

All critical migration violations for `mob_ble` self-containment and Hex publication have been resolved. The table below captures the post-cutover reality (stale "problems" rows retired; only non-blocking MeshX-side notes remain). Phase 3 (release coordination, cutover announcement, evidence templates, Hex prep, on-device validation enablement, final hygiene) complete.

| Aspect                        | Current Reality (2026-05-19)                                                                 | Status / Risk                          |
|-------------------------------|----------------------------------------------------------------------------------|----------------------------------------|
| Behaviour definition          | Canonical: `Mob.Ble.Bridge` (apps/mob_ble/lib/mob/ble/bridge.ex) with rich moduledoc + inbound event contract. `MeshxTransportBLE.Bridge` is a thin CONTRACT-SYNC copy only. | ✅ Resolved (plugin hygiene) |
| Production impl declaration   | `MobileBridge` now declares `@behaviour Mob.Ble.Bridge` (primary); legacy `@behaviour MeshxTransportBLE.Bridge` retained only for exact MeshX compat in the sync copy. | ✅ Resolved (dual registration safe) |
| Runtime dependency            | `mob_ble/mix.exs` declares zero `meshx_*` runtime deps. Self-contained `mob` plugin. | ✅ Resolved |
| Hex publication               | Ready (0.1.0). `mix hex.build` from `apps/mob_ble/` succeeds cleanly (no umbrella-dep errors; full metadata, LICENSE, CHANGELOG, native sources, plugin manifest included). | ✅ Complete (Phase 3) |
| Documentation                 | `Mob.Ble.Bridge` + `mob_ble` README are the primary for `mob` users. `BLE_BRIDGE.md` and MeshX docs carry signposts + compat notes only. No plugin-owned MeshX prose. | ✅ Resolved (consumer clarity) |
| Event contract                | Owned by `Mob.Ble.Internal.BridgeProtocol` + `Mob.Ble.Bridge` moduledoc (canonical). MeshX adapter re-exports identical shapes. | ✅ Resolved (single source of truth) |
| Test cross-wiring             | `mob_ble` tests are isolated (use local mocks + `Application.stop` guard). MeshX-side wiring tests (`mob_ble_transport_wiring_test.exs`) and `mobile_bridge_test.exs` use the appropriate behaviour; no pollution of the published package. | ✅ Resolved (test isolation) |

Past failure modes to avoid (per workspace history) — all mitigated by CONTRACT SYNC, exhaustive greps, test guards, and explicit dual-behaviour compat layer:
- API drift between duplicated contracts
- Rename hygiene failures (lingering references after cutover)
- Documentation / code divergence
- Lifecycle / supervision surprises when ownership is unclear
- Test isolation problems with auto-started applications

(See "Risks & Mitigations" table below for the enforcement plan that was followed.)

---

## What Exactly Moves Where

### Moves to `mob_ble` (new canonical home)

**File**: `apps/mob_ble/lib/mob/ble/bridge.ex` (new)

```elixir
defmodule Mob.Ble.Bridge do
  @moduledoc """
  Behaviour for native/mobile BLE bridge implementations (canonical contract
  owned by the `mob_ble` plugin).

  Bridge implementations own platform-specific BLE details: scanning,
  advertising, GATT characteristics, MTU negotiation, background constraints,
  and mobile OS callbacks.

  They communicate with a transport adapter (e.g. `MeshxTransportBLE` when
  using the MeshX stack, or a future `mob`-native transport adapter) through
  a small message contract.

  ## Callbacks (outbound from adapter → bridge)

      @callback start_link(keyword()) :: GenServer.on_start()
      @callback send_frame(pid(), term(), binary(), keyword()) :: :ok | {:error, term()}
      @callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}

  ## Inbound events (bridge → event_target)

  The `event_target` (normally the transport adapter process, supplied via
  `bridge_opts`) must receive:

      {:ble_peer_up, peer_id :: binary(), metadata :: map()}
      {:ble_peer_down, peer_id :: binary()}
      {:ble_frame, peer_id :: binary(), frame :: binary()}

  `MobileBridge` (the production implementation) additionally decodes the
  native v1 JSON contract via `Mob.Ble.Internal.BridgeProtocol` before
  emitting the above tuples.

  See `Mob.Ble.MobileBridge` for the reference implementation and
  `Mob.Ble.Internal.BridgeProtocol` for the exact JSON shapes emitted by
  the Android/iOS native sides.
  """

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback send_frame(pid(), term(), binary(), keyword()) :: :ok | {:error, term()}
  @callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}
end
```

* `Mob.Ble.MobileBridge` will be updated to `@behaviour Mob.Ble.Bridge`.
* `bridge_module/0` continues to return the impl.
* `BridgeProtocol` + native Kotlin/Swift emitters stay exactly as-is (they are already self-contained).
* All carrier validation, NIF ownership, plugin manifest (`priv/mob_plugin.exs`), and `MobBle.Application` rules stay in `mob_ble`.

### Stays in (or is owned by) `meshx_transport_ble`

* `MeshxTransportBLE.Bridge` behaviour definition (unchanged file & module name).
* `MeshxTransportBLE`, `PortBridge`, `NoopBridge`, `BlueZBridge` and all their logic.
* The translation layer (`{:ble_*}` → `{:meshx_transport, :ble, ...}`).
* BlueZ executable and health-check tooling.
* All existing MeshX-specific tests, scripts (`ble_sender.exs` etc.), and documentation focused on the MeshX adapter.

**No rename** of the `meshx_transport_ble` package or its primary modules. The name accurately describes its role as the BLE transport adapter *for the MeshX stack*.

### Event shapes & wire protocol

* The `{:ble_peer_up, ...}` etc. tuples remain the stable handshake between **any** bridge and **any** adapter that speaks this contract.
* The v1 JSON wire format (and `BridgeProtocol` decoder) remains owned by `mob_ble` (correct, because the hardened native emitters live there).
* Desktop bridges (BlueZ via `PortBridge`) bypass the JSON path and emit the tuples directly — this is intentional and preserved.

---

## What `mob_ble` Will Own After Migration

* Public API surface for the BLE plugin: `Mob.Ble`, `Mob.Ble.MobileBridge`, `Mob.Ble.Bridge`, `bridge_module/0`, `carrier/0`, `validate_config/1`, `Diagnostics`, error types, carrier decision logic.
* Internal: `BridgeProtocol`, native asset build, plugin manifest, NIF glue.
* The **contract** that all `mob_ble`-compatible bridges must satisfy.

`mob_ble` will have **zero** runtime dependency on any `meshx_*` package.

---

## Compatibility Story for Existing MeshX Code

1. **Zero breaking changes** for MeshX consumers.
   - `MeshxTransportBLE.start_link(bridge: MyCustomBridge, ...)` continues to work.
   - Existing `@behaviour MeshxTransportBLE.Bridge` declarations and `@impl` tags in custom bridges remain valid.
   - `MeshxTransportBLE.BluezBridge`, `PortBridge`, etc. are untouched.

2. **Using the official mobile bridge from MeshX code** (already supported today, remains supported):
   ```elixir
   {:ok, ble} = MeshxTransportBLE.start_link(
     bridge: Mob.Ble.bridge_module(),
     bridge_opts: [local_name: "my-device"]
   )
   ```
   This works because the three callbacks have **identical** names, arities, and return types. The adapter performs only dynamic `module.fun` calls.

3. **Documentation-only compatibility**:
   - `MeshxTransportBLE.Bridge` moduledoc will state: "The callback signatures are identical to `Mob.Ble.Bridge` (owned by the `mob_ble` Hex package). Implement either; both are accepted by this adapter."
   - `BLE_BRIDGE.md` will lead with the `mob` / `mob_ble` path for mobile production use and treat the MeshX-named behaviour as the adapter contract for the MeshX ecosystem.

4. **No cross-package dependency required**:
   - `meshx_transport_ble` will **not** depend on `mob_ble`.
   - `mob_ble` will **not** depend on `meshx_transport_ble`.
   - This keeps both dependency graphs clean.

---

## Naming Recommendations

**Recommended**: `Mob.Ble.Bridge`

**Rationale**:
- Lives under the existing `Mob.Ble.*` namespace already used by `MobileBridge`, `carrier/0`, `Diagnostics`, etc.
- Returned value of the existing `bridge_module/0` is naturally "an implementation of `Mob.Ble.Bridge`".
- Short, unambiguous, and immediately discoverable in IEx / docs for anyone who has `mob_ble` in their deps.
- Matches the plugin's identity ("this is the BLE surface for mob").

**Alternatives considered and rejected for v1**:
- `Mob.Transport.Ble.Bridge` or `Mob.Ble.Transport.Bridge` — attractive for future symmetry (`mob_quic`, `mob_wifi`, ...), but speculative. Can be introduced later as an alias or nested module without breaking `Mob.Ble.Bridge`.
- Anything containing "Meshx" or "meshx" — forbidden by the self-contained rule.
- A brand-new tiny package (`mob_ble_behaviour`, `mob_transport_contracts`) — rejected (see below).

**Future-proofing note**: If the `mob` framework later defines a general `Mob.Transport` behaviour, `Mob.Ble.Bridge` can remain the BLE-specific detail (or be re-exported under a transport namespace in a minor release).

---

## New Small Packages Needed?

**None.**

The entire contract (behaviour + protocol decoder + reference implementation + native emitters) is < 300 LOC of Elixir + the existing native sources. It belongs inside `mob_ble`.

Creating a separate package at this stage would:
- Increase publication surface area
- Create a new "tiny dep" that every `mob_ble` user must understand
- Risk the exact documentation/code drift problems we are trying to prevent

Only reconsider if/when `mob` grows three or more transport plugins with shared bridge-style contracts.

---

## Phased Migration Plan

### Phase 1 — Canonical Contract in `mob_ble` (implement first; low blast radius)

1. Create `apps/mob_ble/lib/mob/ble/bridge.ex` with `Mob.Ble.Bridge` (full moduledoc as sketched above).
2. Change `MobileBridge`:
   - Replace `@behaviour MeshxTransportBLE.Bridge` with `@behaviour Mob.Ble.Bridge`.
   - Change all four `@impl` lines from `MeshxTransportBLE.Bridge` to `true` (or the new behaviour module).
   - Update moduledoc references.
3. Delete the `{:meshx_transport_ble, in_umbrella: true}` line from `apps/mob_ble/mix.exs`.
4. Add a **test-only** (optional) dep if the integration describe blocks are kept:
   ```elixir
   {:meshx_transport_ble, in_umbrella: true, only: :test, optional: true}
   ```
   Guard the "integration with the BLE transport adapter" describe block:
   ```elixir
   if Code.ensure_loaded?(MeshxTransportBLE) do
     describe "integration with the BLE transport adapter..." do ... end
   end
   ```
5. Update `mob_ble/README.md`, `mobile_bridge.ex` moduledoc, `application.ex` moduledoc, and any other comments that hard-link to the old behaviour name.
6. Update `BLE_BRIDGE.md` (or add a prominent "mob / mob_ble users" callout at the top) to point to `Mob.Ble.Bridge` as the production contract.
7. Add a machine-readable sync marker (comment block) in both behaviour files:
   ```
   # CONTRACT SYNC: Mob.Ble.Bridge <-> MeshxTransportBLE.Bridge
   # Any change to callbacks or documented inbound events MUST be mirrored.
   # Last synchronized: 2026-05-XX
   ```

**Deliverable of Phase 1**: `mix hex.build` (or `mix compile`) succeeds for `mob_ble` in isolation; `mix test apps/mob_ble` still passes (with guarded interop tests).

### Phase 2 — MeshX-side documentation & dep hygiene (immediately after Phase 1)

1. Add explicit dependency in `apps/meshx_mobile_app/mix.exs`:
   ```elixir
   {:meshx_transport_ble, in_umbrella: true},
   ```
   (Required because `app.ex` and the wiring test directly reference `MeshxTransportBLE` modules; it is no longer pulled transitively.)
2. Update `MeshxTransportBLE` moduledoc and `bridge.ex` with compatibility language (see above).
3. Update `docs/BLE_BRIDGE.md` structure:
   - New top section: "Production mobile path (recommended): `mob_ble` package".
   - Keep existing MeshX adapter details for custom / desktop / MeshX-only use.
4. Update any other references in `docs/`, `README.md` (root), scripts, and `meshx_runtime` comments.
5. Update `remaining_items_audit.md` and `upstream_mob_migration_checklist.md` to mark the `meshx_transport_ble` dep blocker as resolved for `mob_ble` publication.
6. (Optional) Add a tiny re-export shim inside `meshx_transport_ble` only if a strong product need appears later:
   ```elixir
   # Only for documentation / convenience in MeshX contexts that also pull mob_ble
   # (not a runtime dep)
   ```

**No behaviour or implementation changes in this phase.**

### Phase 3 — Publication & cutover communication

1. Release new `mob_ble` (version bump) with zero `meshx_*` runtime deps.
2. Release updated `meshx_transport_ble` (docs + mobile_app dep hygiene only; no behaviour change).
3. Update root `CHANGELOG.md`, `docs/`, and any release notes.
4. In the main mobile app and any example templates, keep current wiring (it already works) but add comments pointing to the new canonical docs.
5. Announce in relevant issues / PRs: "`mob_ble` is now fully self-contained for `mob` users."

### Phase 4 (future, non-blocking)

* If `mob` framework introduces a first-class pluggable transport abstraction, evaluate whether `Mob.Ble.Bridge` becomes a detail of a `Mob.Transport` contract or stays BLE-specific.
* Coordinated minor version bumps if callback signatures ever need to evolve (very unlikely; the contract has been stable through extensive hardware validation).

---

## Impact on Current `meshx_transport_ble` Consumers

* **MeshX application authors & custom bridge implementors**: Zero impact. Same modules, same behaviour name, same usage.
* **BlueZ / desktop users**: Unaffected.
* **meshx_mobile_app**: One-line `mix.exs` addition (explicit dep) + continued operation.
* **CI / release artifact generators**: May need to ensure `meshx_transport_ble` is explicitly listed where direct module references exist.
* **Hex consumers of `meshx_transport_ble`**: No change to their dependency tree.

**Positive impact**: `mob_ble` users (the growing `mob` plugin audience) get a dramatically cleaner dependency graph.

---

## Build / Dependency / Hex Publication Implications

* **Before**: `mob_ble` cannot be published cleanly while it carries an in-umbrella (or even published) `meshx_transport_ble` requirement.
* **After Phase 1**: `mix hex.build` on `mob_ble` succeeds with only legitimate dependencies (`mob`, `mob_dev` for build tooling, etc.). The "Remaining publication blocker" row in the audit is satisfied.
* **Transitive graph for a pure `mob` app**:
  ```
  my_mob_app
  ├── mob
  └── mob_ble          # ← clean, no meshx_transport_ble
  ```
* **Transitive graph for a MeshX + mobile app** (unchanged or slightly cleaner):
  ```
  meshx_mobile_app
  ├── meshx_runtime
  │   └── meshx_transport_ble
  ├── mob_ble          # now independent
  └── (explicit) meshx_transport_ble   # only because of direct references in app.ex
  ```
* Umbrella `mix.exs` and lockfiles require only normal cleanup on next `deps.get`.
* No changes to static NIF / driver tab / Android Gradle / iOS Swift compilation paths.

---

## Risks & Mitigations (explicitly addressing past failure modes)

| Risk                        | Likelihood | Mitigation (enforced in the plan) |
|-----------------------------|------------|-----------------------------------|
| Callback signature drift    | Medium     | CONTRACT SYNC comment block in both behaviour files + requirement that any signature change is a coordinated minor across both packages + reflection test (optional) in CI. |
| Documentation drift         | High       | One primary contract doc (`Mob.Ble.Bridge` moduledoc) + explicit "see also" links in BLE_BRIDGE.md and MeshX adapter docs. |
| Lingering `@behaviour Meshx...` references after cutover | High | Exhaustive grep (performed during this planning) + checklist in the implementation PR template. |
| Test isolation / app startup conflicts | Low (already addressed) | Retain the `Application.stop(:mob_ble)` pattern in `test_helper.exs`; guard cross-package tests. |
| Hex umbrella-dep errors during publication | Eliminated | Primary success criterion of Phase 1. |
| User confusion ("which Bridge do I implement?") | Medium     | Clear decision tree in BLE_BRIDGE.md and both READMEs: "Mobile production? Use `mob_ble` + `Mob.Ble.Bridge`. Writing a custom MeshX desktop transport? Use `MeshxTransportBLE.Bridge`." |
| Lifecycle / supervision surprises | Low        | Strategy explicitly reinforces the existing "bridge is owned by its starter" invariant already documented in `MobileBridge` and `MobBle.Application`. |

---

## Open Questions (for follow-up after Phase 1)

1. Should the stable `{:ble_peer_up, ...}` tuple tags be given a public typed surface (e.g. `Mob.Ble.Event.peer_up/2`) in a later minor, or remain an internal adapter/bridge handshake detail?
2. Will the `mob` framework (or `mob_dev`) ever supply a first-class transport adapter module so that pure `mob` + `mob_ble` apps never need to spell `MeshxTransportBLE` even in their host `on_start` code? (The bridge contract already enables this.)
3. Exact release train coordination with upstream `mob` / `mob_dev` releases and the current patch migration checklist.
4. Whether a back-compat alias or documentation shim should appear in a patch release of `meshx_transport_ble` for very old MeshX consumers.

---

## Code Sketches (for implementers)

### 1. New file: `apps/mob_ble/lib/mob/ble/bridge.ex`

(See the full module sketched in the "What Moves" section above. Copy the inbound event documentation from the current `MeshxTransportBLE` moduledoc and `BridgeProtocol`.)

### 2. Diff for `apps/mob_ble/lib/mob/ble/mobile_bridge.ex` (key lines only)

```diff
-  @behaviour MeshxTransportBLE.Bridge
+  @behaviour Mob.Ble.Bridge

   ...
-  @impl MeshxTransportBLE.Bridge
+  @impl true
   def start_link(opts) do
```

(Repeat for the three other `@impl` sites. All function heads and bodies are unchanged.)

### 3. Diff for `apps/mob_ble/mix.exs`

```diff
   defp deps do
     [
-      # Depends on the transport package that defines the Bridge behaviour.
-      # Hex publication will need the published package requirement once the
-      # transport package is split from this umbrella.
-      {:meshx_transport_ble, in_umbrella: true}
+      # Bridge behaviour is now defined locally as Mob.Ble.Bridge.
+      # No meshx_* runtime dependency (self-contained plugin requirement).
     ]
   end
```

### 4. Guarded interop test sketch (in `mobile_bridge_test.exs`)

```elixir
if Code.ensure_loaded?(MeshxTransportBLE) do
  describe "integration with the BLE transport adapter using Mob.Ble.bridge_module()" do
    # existing test body unchanged
  end
end
```

### 5. Example update to `docs/BLE_BRIDGE.md` (top of file)

```markdown
> **Production mobile path (recommended).** Depend on `mob_ble` and use
> `Mob.Ble.Bridge` / `Mob.Ble.MobileBridge`. See the `mob_ble` README and
> `Mob.Ble.Bridge` moduledoc.
>
> The `MeshxTransportBLE.Bridge` behaviour documented below is the
> equivalent contract for the MeshX transport adapter and for writing
> custom (e.g. desktop BlueZ) bridges.
```

---

**This document is the single source of truth for the migration.** Implementers should treat every section as requirements, not suggestions.

## Phase 1+2+3 Implementation Note (2026-05-19, updated)
Phase 1 changes (rich `Mob.Ble.Bridge` + MobileBridge hygiene + dep removal + CONTRACT SYNC markers in both behaviours + BLE_BRIDGE.md callout + internal docs + audit) executed cleanly with zero "meshx" prose violations in plugin-owned sources (exhaustive grep; only unavoidable `MeshxTransportBLE` identifiers in compat notes remain).

Phase 2 (MeshX-side): explicit `{:meshx_transport_ble, in_umbrella: true}` dep hygiene in `meshx_mobile_app/mix.exs` + `MeshxTransportBLE` docs + `app.ex` default flip (mob_ble on unless =0) + `Mob.Ble.SelfTest` wiring + primary wiring test promotion + README polish (stray row removal) + migration doc / audit updates (including marking LICENSE/CHANGELOG and test conflicts ✅). All via search_replace. `mix hex.build` from `apps/mob_ble/` clean.

Phase 3 (this closure pass): publication artifacts (trimmed announcement, evidence bundle + manifest + recipe), final hygiene sweeps (stale Current State table rows + "meshx" prose nits in plugin docs, status table updates), launch/CONTRIBUTING support, verification. Ready for `mix hex.publish` + first physical device runs under the new default.

Phase 3 complete (this pass + prior): changelogs, trimmed cutover announcement, on-device MOB_* launch forwarding, dedicated launch script + CONTRIBUTING updates, evidence bundle dir + manifest template + 5-step recipe, final prose hygiene + "meshx" sweep in plugin sources, migration doc/audit polish (Current State table + stale language retired), mix hex.build verification. See `/tmp/grok-impl-summary-2edba713.md` for the full artifact list, verification commands, and pre-publish checklist.

Open Questions and remaining Phase 4 items (publish + first device runs + upstream) tracked in the Implementation Summary and `docs/remaining_items_audit.md`.

End of strategy document.
