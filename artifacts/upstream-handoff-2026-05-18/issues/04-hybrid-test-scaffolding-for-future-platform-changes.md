---
title: "BLE: Keep hybrid direct-MX + MB test scaffolding as a low-cost re-validation path for future iOS releases"
repo: "GenericJam/mob_dev"
labels: ["ble", "testing", "ios"]
---

## Summary

As part of the 2026-05 carrier decision work, MeshX introduced two durable instrumented test classes and supporting production hooks:

- `IOSAuxFullMxAdvertSmokeTest` (Android side emitter of hybrid MB cue + direct-MX service-data full envelope)
- `IOSHybridDirectMxReceiveTest` (Android side observer + correlation logic)

These tests, together with the iOS harness `--meshx-auto-direct-mx-hybrid-advertise` flag and the `BleScanner` / `BleDispatcher` hybrid correlation paths (`recentMBBeacons`, `onDirectMxServiceDataWithMagicReceived`, `HYBRID_SUCCESS` etc. markers), form a self-contained evidence bundle that can re-validate the direct carrier shape cheaply.

## Current status

The direct carrier is rejected for production on current iOS stacks. The tests are intentionally kept (they assert the expected negative outcome for iOS while still exercising the correlation logic).

## Request

Please treat the hybrid/MB+service-data scaffolding in the mob bridge (Android scanner/dispatcher + any corresponding iOS responder bits) as **intentionally retained test / future-proofing code**, not dead code to be removed.

When a future iOS release relaxes the foreground manufacturer-data or custom service-data restrictions, the same test pair + harness flags can be used for rapid positive validation without re-implementing the plumbing.

Cross-reference the two open PRs for the build side:
- GenericJam/mob_dev#6
- GenericJam/mob_new#5

The test surface is small, well-documented in the test Javadocs, and already wired into the release artifact bundle expectations.

This avoids a future "we threw away the direct path code" situation when the platform limitation eventually moves.
