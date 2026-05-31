# MeshX Mobile BLE — Milestone Ledger (M1–M1865)

Running summary of the BLE transport, contract, and passive-inventory
work in `apps/mob_node/`. The landed milestones are tracked by
commit. Together they build a
hardware-validated, replay-deterministic foundation that future routing
and crypto work can sit on top of without changing the contract.

This is not a design document. It's a reference for "what's already
true and what isn't yet."

For the focused updated remaining-items audit covering the iOS responder
hardware proof, direct full-MX AUX boundary, upstream `mob_dev` / `mob_new`
PRs, and `--no-start` startup fix, see `docs/remaining_items_audit.md`.

## Milestones

| M | Commit | Title |
| --- | --- | --- |
| M1 | `e13fdda` | Android shell (Gradle, manifest, placeholder Activity) |
| M2 | `e13fdda` | Unified BLE adapter contract + v1 wire protocol |
| M3 | `e13fdda` | Android Kotlin BLE transport (scan + advertise) |
| M4 | `e13fdda` | On-device hardware validation (SM-T577U, Android 13) |
| M5 | `e13fdda` | Capture / replay tooling (JSONL, mix tasks) |
| M6 | `e13fdda` | Passive peer table over canonical events |
| M7 | `e13fdda` | Passive identity derivation from advertisement payloads |
| M8 | `08dc2dd` | Identity confidence + collision guards |
| M9 | `c816a7e` | Peer inventory view-model (pure-data summaries) |
| M10 | `9e775d8` | Passive presence lifecycle (active / stale / expired) |
| M11 | `620d177` | Passive churn event derivation between snapshots |
| M12 | `287364e` | Churn semantics hardening + initial M1–M12 ledger |
| M13 | `1d2dde3` | Passive peer capability advertisement |
| M14 | `5c74790` | Passive MeshX message envelope contract |
| M15 | `fbd1b27` | Passive message eligibility planner |
| M16 | `1e6b185` | Message attempt ledger / outbox planning |
| M17–M19 | `8fe6c02` | Dry-run dispatch, simulated transport, attempt outcomes |
| M20–M22 | `e756aa1` | Real Android BLE dispatch spike + hardware validation |
| M23–M27 | _working tree_ | M14 message advertisement send/receive path, canonical `received_message`, and Android-to-Android verifier; exact two-Android logcat proof still open |
| M26B | `6bc53d2` | Legacy Android compatibility beacon: compact 22-byte `received_message_beacon` proof for older BLE hardware without faking full-envelope delivery |
| M28 | `120a8c4` | Beacon resolution contract: pure `BeaconRef` + resolver outcomes for already-known, needs-fetch, malformed, and hash-mismatch cases |
| M29 | `deec583` | Beacon fetch request contract: unresolved legacy refs become bounded, deterministic, auditable fetch intents without transport |
| M30–M32 | `de72368` | Beacon fetch planning: deterministic candidate selection, immutable fetch attempts, and dry-run fetch outcomes |
| M33–M36 | `550df29` | Constrained beacon fetch transport: canonical request/response structs, bounded in-memory cache, fake exchange, and one-shot Android GATT spike |
| M37–M39 | `76fba80` | GATT fetch hardening: structured diagnostics, serialized client lifecycle, timeouts, LE transport preference, and two-direction hardware rerun |
| M40 | `3c4016e` | Standalone Android GATT interop harness: hardcoded service/characteristic, tiny read/write path, and platform-level 133 isolation |
| M41 | `bfe840a` | BLE transport decision ledger: GATT fetch blocked on SM-T577U/SM-T390, advertisement-first fallback strategy |
| M42–M45 | `8808622` | Advertisement-only local mesh mode: advert-only profile, beacon inbox, full-envelope inbox, and unified local snapshot |
| M50–M55 | `be9232d` | Opportunistic advertisement gossip: pure policy, suppression ledger, planned intents, and dry-run outcomes |
| M56–M58 | `147c69a` | Constrained advert gossip execution: canonical outcome event, Android legacy beacon dispatcher, and debug harness action |
| M59–M61 | `10467cf` | Advert gossip hardware proof: SM-T577U legacy beacon gossip observed by SM-T390 as canonical `received_message_beacon` |
| M62–M65 | `a446eb7` | Local inbox consumer surface: session snapshot exposes nearby full messages and unresolved beacon refs |
| M66 | `32f83a4` | Transport re-evaluation gate: keep GATT disabled until a known-good hardware pair proves standalone interop and constrained fetch |
| M67–M70 | `4447d58` | Replay-only multi-hop advert gossip simulation: TTL, loop suppression, provenance, deterministic delivery ledger |
| M71–M75 | `de8ccd2` | Advert gossip policy hardening: default TTL, max hops, neighbor cooldown, provenance validation, topology fixtures |
| M76–M80 | `981ddda` | Advert gossip scenario audits: JSON topology fixtures, expected summaries, and CLI audit task |
| M81–M85 | `b2a5e16` | Local inbox UX state read model: full messages, unresolved refs, gossiped refs, and stale refs |
| M86–M90 | `a6c1bab` | Local inbox persistence policy: durable snapshot contract, retention rules, and explicit excluded fields without storage behavior |
| M91–M95 | `9043310` | Local inbox trust classification: unsigned observations and untrusted refs surfaced explicitly without crypto behavior |
| M96–M100 | `e2f84aa` | Advert gossip release hardening: scenario audit is an explicit CI/release gate |
| M101–M105 | `bc95a00` | Local inbox product querying: filter/sort/detail/count helpers for nearby-message UX |
| M106–M110 | `2947b5f` | Local inbox durable store boundary: explicit CubDB save/load/delete for policy-approved snapshots |
| M111–M115 | `d0ac79a` | Durable local inbox restore: saved snapshots become queryable nearby-message read models |
| M116–M120 | `95ee167` | Local inbox resolution status: beacon refs become already-known, needs-fetch, stale, or unresolvable read-model states |
| M121–M125 | `214a897` | Local fetch intent projection: needs-fetch statuses become blocked, auditable BeaconFetchRequest intents |
| M126–M130 | `9403103` | Local inbox action summary: product/API counts, blockers, next actions, and optional blocked fetch intents |
| M131–M135 | `eba9b0d` | Foreground lifecycle profile: explicit support/non-support for manual foreground BLE versus background mobile behavior |
| M136–M140 | `9eb4785` | Platform parity status: Android validated paths and iOS unimplemented/unvalidated gaps exposed as data |
| M141–M145 | `04a2b30` | Hardware validation gates: passed/open proof gates for one-hop, full-envelope, GATT, multi-hop, and iOS parity |
| M146–M150 | `94193bb` | Project readiness audit: whole-project remaining work exposed as data with current evidence and remaining proof |
| M151–M155 | `6b80524` | Nearby Messages presenter: compact UX text exposes state, resolution, trust, and blockers |
| M156–M160 | `2296dd9` | Local readiness audit task: release/status gate for open project readiness items |
| M161–M165 | `fd145b6` | Opt-in local inbox session persistence: save live inbox snapshots and expose restored read models |
| M166–M170 | `0d84468` | Local security identity contract: auditable proof requirements for authorship, replay protection, and trust |
| M171–M175 | `b72f37b` | Local routing contract: auditable boundary between advert gossip replay and production routing |
| M176–M180 | `69482fb` | Background lifecycle contract: Android foreground-service, iOS background, restart, and background gossip requirements |
| M181–M185 | `bbf6979` | iOS parity contract: advert-only beacon/full-envelope implementation and validation requirements |
| M186–M190 | `c50ecfa` | Readiness audit JSON output: machine-readable release/status gate for open project items |
| M191–M195 | `e5fd86b` | Readiness audit artifact output: write machine-readable JSON manifests for release/CI archiving |
| M196–M200 | `47c8903` | Advert-only release criteria: explicit release boundary and remaining evidence for validated local mode |
| M201–M205 | `ad9b81f` | Nearby Messages product surface: grouped states, filter/sort affordances, and detail selection read model |
| M206–M210 | `52a7307` | Local inbox store maintenance: list saved snapshots and prune expired durable snapshots with injected clock |
| M211–M215 | `7bd5ec6` | Local trust policy gate: block trusted-message and delivery wording for unsigned BLE observations |
| M216–M220 | `7897f3c` | Local routing policy gate: allow nearby observation while blocking live routing and delivery claims |
| M221–M225 | `f359afe` | Local lifecycle policy gate: foreground/manual only, background and restart claims blocked |
| M226–M230 | `ace3a01` | iOS parity policy gate: shared contract only, iOS advert-only participation claims blocked |
| M231–M235 | `9438cc0` | Local release manifest: archive advert-only release boundary, readiness blockers, and policy gates |
| M236–M240 | `beaf83d` | Local release manifest CI gate: generate readiness/release manifests and assert blocked claims |
| M241–M245 | `df13870` | Local release evidence manifest: project hardware gates into release-candidate evidence requirements |
| M246–M250 | `531b424` | Local inbox native surface model: state filters, sort choices, rows, and detail panel data for Nearby Messages |
| M251–M255 | `be49403` | Local inbox persistence profile: explicit memory-only default and opt-in durable Session options |
| M256–M260 | `2cf9f3a` | Local security identity proof plan: map trust blockers to implementation gates and validation evidence |
| M261–M265 | `d54711b` | Local routing proof plan: map routing blockers to implementation gates, validation evidence, and hardware proof |
| M266–M270 | `030fef0` | Local lifecycle proof plan: map background lifecycle blockers to implementation gates and validation evidence |
| M271–M275 | `7caf977` | Local iOS parity proof plan: map iOS advert-only blockers to implementation gates and replay-normalized evidence |
| M276–M280 | `d184823` | Local project completion audit: map whole-project objective to artifacts, evidence, and open blockers |
| M281–M285 | `4bf4704` | Mob Nearby Messages controls: wire native local inbox surface into filters, sorting, rows, and detail selection |
| M286–M290 | `9efed0d` | Local inbox persistence lifecycle decision: keep memory-only default, allow opt-in durable snapshots, and gate production default persistence |
| M291–M295 | `d02c4ca` | Local security negative validation: block current unsigned adverts, beacon refs, gossip refs, stale refs, and passive labels from trusted claims |
| M296–M300 | `f013632` | Local routing negative validation: block peer inventory, stale next hops, replay gossip, missing ACK/retry, and one-hop hardware from routing claims |
| M301–M305 | `944fe45` | Local lifecycle negative validation: block foreground/manual evidence from background, restart, scheduled retry, and background gossip claims |
| M306–M310 | `596c05a` | Local iOS parity negative validation: block bridge shell and Android evidence from iOS advert-only parity claims |
| M311–M315 | `b7b3cc2` | Local release artifact bundle checklist: generated manifests, embedded audits, hardware attachments, and operator release-note constraints |
| M316–M320 | `8ab5e0e` | Nearby Messages state copy: centralized labels, badges, limitations, next actions, and blocked delivery claims for local inbox UX |
| M321–M325 | `a9b6d48` | Local persistence negative validation: block opt-in snapshots from default lifecycle, delivery-record, background-write, and raw-evidence claims |
| M326–M330 | `55b60d9` | Android two-device validation rerun: wake/settle harness fix, current full-envelope failure, and refreshed legacy-beacon success on SM-T577U/SM-T390 |
| M331–M335 | `a7f94be` | Current standalone GATT interop rerun: SM-T577U/SM-T390 still fail with Android status 133 before service discovery in both directions |
| M336–M340 | `bea244b` | Local BLE release evidence bundle: archive current Android hardware logs, readiness/release manifests, advert gossip audit, and operator wording notes |
| M341–M345 | `3e09b96` | Local inbox persistence operator controls: explicit status, save, restore, prune, and clear actions without default lifecycle persistence |
| M346–M350 | `3a68865` | Local security trust model: future trust states and required evidence gates without trusting current BLE observations |
| M351–M355 | `bdd71f2` | Local routing candidate table: deterministic direct-route candidates from peer observations without forwarding or routing claims |
| M356–M360 | `00a1463` | Nearby Messages UX acceptance gate: pure surface coverage checks with production UX blocked until on-device validation |
| M361–M365 | `fa6ceb7` | Local persistence acceptance gate: opt-in durable storage evidence with default lifecycle persistence blocked |
| M366–M370 | `1900d18` | Local security acceptance gate: unsigned local BLE observations remain untrusted until identity, authorship, replay, and beacon-auth gates pass |
| M371–M375 | `dc75be5` | Local routing acceptance gate: route candidates remain observation-only until route table, forwarding, delivery, and multi-hop hardware gates pass |
| M376–M380 | `c2a82a5` | Local lifecycle acceptance gate: foreground/manual BLE remains the only accepted lifecycle until background, restart, retry, and gossip gates pass |
| M381–M385 | `e239e6b` | Local iOS parity acceptance gate: iOS parity remains blocked until beacon/full-envelope implementation decisions and replay-normalized hardware proof exist |
| M386–M390 | `670fe06` | Release-candidate evidence review: operator hardware attachments and release-note wording become a pure review contract |
| M391–M395 | `d6e43d9` | Local security authorship proof boundary: domain-separated Ed25519 verification for full MessageEnvelope values without trust promotion |
| M396–M400 | `9990ccc` | Local security peer identity binding: supplied peer_id to Ed25519 key binding for authorship proofs without trust-store promotion |
| M401–M405 | `b5777ae` | Local security replay protection boundary: bounded in-memory replay guard for verified full-envelope proofs |
| M406–M410 | `96271b3` | Local trusted-message decision boundary: peer binding, authorship, replay, and explicit trust state for full envelopes without delivery claims |
| M411–M415 | `353fd6a` | Local beacon authentication boundary: legacy beacon refs authenticate only after matching a resolved trusted full envelope |
| M416–M420 | `e5d8853` | Local security canonical replay decision: replay-normalized ReceivedMessage events feed the trusted-message decision boundary with supplied proof inputs |
| M421–M425 | `95406f1` | Local operator trust policy boundary: explicit peer_id/key_id scoped trust feeds canonical replay decisions without persistent trust storage |
| M426–M430 | `ce61c83` | Local crypto negative validation: executable tamper, replay, key mismatch, blocked/revoked policy, and beacon-ref promotion cases |
| M431–M435 | `f90bec9` | Local security trust lifecycle plan: planned gates for persistent enrollment, key store, rotation, revocation, replay state, and release audit export |
| M436–M440 | `24c0a97` | Nearby Messages UX validation plan: target-device, state coverage, interaction, copy, and visual-density evidence gates |
| M441–M445 | `f764ac6` | Local persistence production lifecycle plan: default decision, migration, cleanup, writer, restore, and release evidence gates |
| M446–M450 | `366a76c` | Local lifecycle hardware validation plan: device matrix, app-backgrounding, restart, retry, and background gossip evidence gates |
| M451–M455 | `9db0523` | Local iOS parity hardware validation plan: iOS device matrix, beacon observe/gossip, capability, replay, and negative evidence gates |
| M456–M460 | `3079ae0` | Local routing hardware validation plan: route table, selection, forwarding, delivery, multi-hop, TTL/loop, and negative evidence gates |
| M461–M465 | `add407b` | Local security identity validation plan: peer enrollment, authorship, replay lifecycle, trust lifecycle, beacon auth, and negative evidence gates |
| M466–M470 | `69cb981` | Local fetch transport validation plan: candidate transport, standalone interop, constrained fetch, canonical replay, negative failure, and release evidence gates |
| M471–M475 | `226955b` | Whole-project prompt-to-artifact checklist: ten objective deliverables mapped to artifacts, commands, evidence, and missing proof |
| M476–M480 | `c8879b6` | Multi-hop advert gossip hardware validation plan: origin, relay, observer, replay normalization, TTL/suppression, negative, and release evidence gates |
| M481–M485 | `68d2d3d` | Nearby Messages UX copy hardening: native summary line, state-specific empty copy, and screen rendering of current local inbox counts |
| M486–M490 | `4995f55` | Local security fixture audit: inventory implementation-backed security fixture coverage against every validation-plan gate |
| M491–M495 | `9a087ed` | Local peer enrollment boundary: operator-supplied peer/key enrollment rejects passive BLE observations |
| M496–M500 | `51a7372` | Local trust lifecycle validation: supplied-policy key rotation and revocation fail-closed matrix |
| M501–M505 | `80fc4f9` | Local replay lifecycle policy: memory-only replay state, restart clearing, and executable lifecycle validation |
| M506–M510 | `91821f6` | Local security release evidence review: operator-reviewed package gate for authenticated/trusted wording |
| M511–M515 | `e26b41c` | Local security evidence manifest: archiveable security evidence, blocked claims, and review state |
| M516–M520 | `f29548b` | Nearby Messages UX evidence manifest: pure surface coverage, open on-device gates, and blocked claims |
| M521–M525 | `f32f498` | Local persistence evidence manifest: opt-in durable snapshots, memory-only default, and production lifecycle gates |
| M526–M530 | `ba9b760` | Local routing evidence manifest: route candidates, non-routing policy, hardware gates, and blocked claims |
| M531–M535 | `5a264be` | Local lifecycle evidence manifest: foreground/manual mode, open background gates, and blocked claims |
| M536–M540 | `1eb0148` | Local iOS parity evidence manifest: contract-only iOS mode, open hardware gates, and blocked parity claims |
| M541–M545 | `7ae6c8a` | Local full-message resolution evidence manifest: BeaconRef/fetch contracts, offline fetch evidence, and blocked transport gates |
| M546–M550 | `d1e63e2` | Local multi-hop hardware evidence manifest: replay evidence, one-hop hardware scope, and blocked physical multi-hop gates |
| M551–M555 | `7647e75` | Local release artifact bundle task: archive generated/open release-candidate artifact checklist directly |
| M556–M560 | `c6eb18d` | Local release candidate review task: validate operator hardware metadata and blocked-claim wording from JSON |
| M561–M565 | `16eb066` | Nearby Messages UX evidence review task: validate operator target-device UX metadata without delivery claims |
| M566–M570 | `06477e9` | Production persistence evidence review task: validate operator lifecycle metadata without enabling default persistence |
| M571–M575 | `856d915` | Production routing evidence review task: validate operator routing metadata without enabling forwarding |
| M576–M580 | `222cccb` | Lifecycle hardware evidence review task: validate operator lifecycle metadata without enabling background behavior |
| M581–M585 | `bdb7a3f` | iOS parity hardware evidence review task: validate operator iOS metadata without enabling iOS participation |
| M586–M590 | `45ac721` | Security release evidence review task: validate operator security metadata without enabling trust claims |
| M591–M595 | `0e333b2` | Full-resolution transport evidence review task: validate operator transport metadata without enabling resolution claims |
| M596–M600 | `deb613b` | Multi-hop hardware evidence review task: validate operator origin/relay/observer metadata without enabling multi-hop claims |
| M601–M605 | `06c6ddd` | Known-good transport evidence review task: validate operator transport decision metadata without enabling fetch claims |
| M606–M610 | `acc7db6` | iOS foreground legacy beacon observe path: decode MeshX manufacturer beacons into canonical `received_message_beacon` maps without hardware parity claims |
| M611–M615 | `b297185` | Swift legacy beacon parser fixtures: lock iOS 22-byte beacon reference parsing without adding hardware claims |
| M616–M620 | `68f8a7e` | iOS advert carrier decision ledger: separate foreground observe implementation from unselected beacon gossip emission carriers |
| M621–M625 | `ba9b1ee` | Whole-project blocker matrix: classify remaining completion work by hardware, transport, product, implementation, security, and release evidence blockers |
| M626–M630 | `decf2af` | Release blocker matrix artifact: expose the whole-project blocker matrix as an explicit release bundle artifact |
| M631–M635 | `8f8d7ec` | Release candidate blocker matrix review: require release candidates to reference the blocker matrix path |
| M636–M640 | `ec40da5` | Completion blocker matrix task: generate the whole-project blocker matrix as a standalone release artifact |
| M641–M645 | `9ca94be` | Release manifest blocker matrix command: require standalone blocker matrix generation in release command lists |
| M646–M650 | `6ab6f1b` | CI release blocker matrix artifact: generate blocker matrix in release CI and document it in release checklist |
| M651–M655 | `7220991` | Current GATT interop blocker rerun: archive fresh SM-T577U/SM-T390 status 133 evidence |
| M656–M660 | `80079e5` | Readiness evidence refresh: surface May 13 GATT blocker archive in readiness and release bundle docs |
| M661–M665 | `f020906` | Release bundle known-bad GATT archive: require current status 133 evidence in artifact criteria |
| M666–M670 | `c69f926` | Release CI artifact bundle command: generate and assert standalone release artifact bundle in CI |
| M671–M675 | `dc2436b` | Security evidence command gates: require authorship, canonical replay, and fixture audit tests in security manifest |
| M676–M680 | `dc2436b` | Security canonical replay plan reconciliation: remove stale missing-fixture wording from validation plan |
| M681–M685 | `fcfc4da` | Security lifecycle plan reconciliation: record memory-only replay and supplied trust lifecycle validation as implemented evidence |
| M686–M690 | `5a5a1b8` | Persistence evidence command gates: require direct store and durable snapshot restore tests in persistence manifest |
| M691–M695 | `bb4e006` | UX evidence command gates: require query, presenter, state-copy, resolution, and action-summary tests in UX manifest |
| M696–M700 | `9dda9f9` | Routing evidence command gates: require contract, policy, proof-plan, route-table, negative, production-review, and task tests in routing manifest |
| M701–M705 | `aba2cdd` | Lifecycle evidence command gates: require contract, policy, proof-plan, foreground profile, hardware review, negative, and task tests in lifecycle manifest |
| M706–M710 | `a0c561a` | iOS parity evidence command gates: require carrier, contract, policy, proof-plan, hardware review, negative, and task tests in iOS parity manifest |
| M711–M715 | `f3646ff` | Full-resolution evidence command gates: require resolver, fetch, transport-plan, review, known-good transport, and task tests in full-resolution manifest |
| M716–M720 | `f30f460` | Multi-hop hardware evidence command gates: require gossip audit, hardware plan, manifest, review, and task tests in multi-hop manifest |
| M721–M725 | `ca4e2f6` | Release artifact bundle command gates: expose generated/review artifact source commands as a single required command list |
| M726–M730 | `58ff870` | Release CI command-gate assertion: require generated artifact bundles to expose required command gates |
| M731–M735 | `2a816d7` | Release checklist command-gate note: document artifact bundle `required_commands` review in release checklist |
| M736–M740 | `726e1b1` | Completion audit command gates: require every evidence and review command in the whole-project completion audit |
| M741–M745 | `8f71d87` | Standalone completion audit task: generate archiveable whole-project completion audit artifacts |
| M746–M750 | `cf50fb5` | Release artifact checklist completion audit linkage: require standalone completion audit artifact in the human bundle checklist |
| M751–M755 | `bf05c3f` | Nearby Messages UX target-device review hardening: reject undeclared target-device evidence references |
| M756–M760 | `e1c1bbd` | Production persistence review gate-specific blockers: require lifecycle gate blocked-claim callouts |
| M761–M765 | `5f7f86f` | Security release review gate-specific blockers: require validation gate blocked-claim callouts |
| M766–M770 | `9f740ef` | Known-good transport review gate-specific blockers: require transport plan blocked-claim callouts |
| M771–M775 | `74244bf` | Production routing review gate-specific blockers: require routing plan blocked-claim callouts |
| M776–M780 | `136ed54` | Lifecycle hardware review gate-specific blockers: require lifecycle plan blocked-claim callouts |
| M781–M785 | `08330fc` | iOS parity hardware review gate-specific blockers: require iOS plan blocked-claim callouts |
| M786–M790 | `7292574` | Multi-hop hardware review gate-specific blockers: require physical role and replay blocker callouts |
| M791–M795 | `e055ea1` | Full-resolution transport review gate-specific blockers: require fetch and replay blocker callouts |
| M796–M800 | `ab93b1c` | Release candidate completion audit linkage: require standalone completion audit path in release review metadata |
| M801–M805 | `c76e287` | Release candidate review docs completion audit linkage: document completion audit path in operator input |
| M806–M810 | `79246c9` | Nearby Messages UX evidence review hardening: require supported evidence kinds and notes |
| M811–M815 | `d3fbabf` | Persistence production review hardening: require gate-specific evidence types |
| M816–M820 | `700d362` | Security release review hardening: require gate-specific evidence types |
| M821–M825 | `c8660ed` | Routing production review hardening: require gate-specific evidence types |
| M826–M830 | `4134492` | Lifecycle hardware review hardening: require gate-specific evidence types |
| M831–M835 | `59eaed9` | iOS parity hardware review hardening: require gate-specific evidence types |
| M836–M840 | `1bbd782` | Release candidate hardware evidence review hardening: require gate-specific evidence types |
| M841–M845 | `23ff201` | Completion audit prompt checklist regression hardening: require objective lockstep and per-item evidence |
| M846–M850 | `76b46e4` | Completion audit task prompt checklist summary: expose remaining objective IDs in text output |
| M851–M855 | `6ca44da` | Release artifact prompt checklist linkage: require completion audit objective-spine review |
| M856–M860 | `48c2d38` | Blocker matrix task objective summary: expose hardware-blocked and non-hardware objective IDs |
| M861–M865 | `4c65394` | Release artifact blocker matrix group linkage: require hardware/non-hardware objective review |
| M866–M870 | `ac70ed5` | Release candidate blocker matrix notes linkage: require operator notes to cite blocker matrix path |
| M871–M875 | `421f641` | Release candidate review path summary: expose operator note artifact anchors in text output |
| M876–M880 | `9bec48d` | Release manifest completion review summary: expose prompt checklist and blocker group counts |
| M881–M885 | `4d677b7` | Completion blocker next-action summary: expose recommended operator unblock action without closing gates |
| M886–M890 | `0a0fced` | Nearby Messages UX evidence template: generate incomplete operator input without approving claims |
| M891–M895 | `11c2c82` | Release UX template linkage: surface the Nearby Messages evidence template in release artifacts |
| M896–M900 | `214b166` | Release bundle UX operator workflow: document template generation and review steps |
| M901–M905 | `b0c1544` | UX review task template hint: print scaffold command when on-device evidence is open |
| M906–M910 | `eca72d4` | Completion audit UX template command: include scaffold command in top-level product UX checklist |
| M911–M915 | `93e8994` | Persistence production evidence template: generate incomplete operator input without enabling defaults |
| M916–M920 | `52f5bac` | Release persistence template linkage: surface production persistence scaffold in release artifacts |
| M921–M925 | `341318e` | Completion audit persistence template command: include scaffold command in top-level persistence checklist |
| M926–M930 | `819feb5` | Persistence review task template hint: print scaffold command when production evidence is open |
| M931–M935 | `7265496` | Security release evidence template: generate incomplete operator input without trusted-message claims |
| M936–M940 | `8a3f8aa` | Release security template linkage: surface security evidence scaffold in release artifacts |
| M941–M945 | `f3295b8` | Completion audit security template command: include scaffold command in top-level security checklist |
| M946–M950 | `6a1e64d` | Security review task template hint: print scaffold command when security evidence is open |
| M951–M955 | `6a64ba7` | Routing production evidence template: generate incomplete operator input without enabling routing |
| M956–M960 | `e744d5d` | Routing production review task template hint: print scaffold command when routing evidence is open |
| M961–M965 | `74faab3` | Lifecycle hardware evidence template: generate incomplete operator input without enabling background BLE |
| M966–M970 | `442e4fa` | Lifecycle hardware review task template hint: print scaffold command when lifecycle evidence is open |
| M971–M975 | `20f4b5a` | iOS parity hardware evidence template: generate incomplete operator input without enabling iOS parity |
| M976–M980 | `9ea2a2b` | iOS parity hardware review task template hint: print scaffold command when iOS evidence is open |
| M981–M985 | `84842a6` | Multi-hop hardware evidence template: generate incomplete operator input without claiming relay proof |
| M986–M990 | `9dde1db` | Multi-hop hardware review task template hint: print scaffold command when multi-hop evidence is open |
| M991–M995 | `12c1070` | Known-good transport evidence template: generate incomplete operator input without validating fetch transport |
| M996–M1000 | `e2eb1da` | Known-good transport review task template hint: print scaffold command when transport evidence is open |
| M1001–M1005 | `946b2bb` | Full-resolution transport evidence template: generate incomplete operator input without resolving beacon refs |
| M1006–M1010 | `e5aa2a1` | Full-resolution transport review task template hint: print scaffold command when transport evidence is open |
| M1011–M1015 | `7eaca31` | Release candidate evidence template: generate incomplete operator input without approving release claims |
| M1016–M1020 | `51f6859` | Release candidate review task template hint: print scaffold command when release evidence is open |
| M1021–M1025 | `68014c0` | Completion audit review-template coverage: require every operator review to list a scaffold command |
| M1026–M1030 | `d1149b3` | Completion audit template coverage summary: print scaffold coverage in plain-text audit output |
| M1031–M1035 | `34de1f2` | Release manifest template coverage summary: print scaffold coverage in plain-text release output |
| M1036–M1040 | `0793108` | Completion audit remaining-work summary: print hardware-blocked, no-new-hardware, and recommended-next lines |
| M1041–M1045 | `7c7207f` | Nearby Messages HomeScreen test coverage: add the required Mob surface control-state test |
| M1046–M1050 | `779c493` | Required command path guard: verify manifest-listed path-specific mix test commands point at checked-in tests |
| M1051–M1055 | `b2077db` | Release artifact command sync guard: prove required commands mirror generated artifact sources |
| M1056–M1060 | `d29ac5c` | Release manifest artifact-command guard: require every artifact command to appear in required commands |
| M1061–M1065 | `268391a` | Release manifest command-artifact guard: require artifact-producing commands to appear in required artifacts |
| M1066–M1070 | `4f88434` | Completion audit prompt-command guard: require every prompt checklist command to be top-level required |
| M1071–M1075 | `a537f3d` | Completion audit blocker partition guard: require prompt checklist objectives to match blocker matrix partitions |
| M1076–M1080 | `0d82b8a` | Completion audit recommended-next guard: require recommended action to target a no-new-hardware checklist objective |
| M1081–M1085 | `a548379` | Completion audit status-alignment guard: require prompt checklist statuses to match blocker matrix entries |
| M1086–M1090 | `d98ba57` | Completion audit count guard: derive blocked/partial/not-started counts from blocker matrix entries |
| M1091–M1095 | `389d1fb` | Completion audit claim-safety guard: keep completion claims false while open work remains |
| M1096–M1100 | `a4d4814` | Release manifest claim-alignment guard: tie release completion flag to embedded completion audit |
| M1101–M1105 | `767009f` | Release wording policy guard: keep blocked release wording aligned with policy gates |
| M1106–M1110 | `529da9f` | UX target-device evidence guard: require every declared target to have state and interaction evidence |
| M1111–M1115 | `f6937c8` | UX per-target coverage guard: require every target to cover all required states and interactions |
| M1116–M1120 | `bff4ed0` | UX visual-density target guard: require density review to name every declared target |
| M1121–M1125 | `45ea5a9` | UX copy-review target guard: require copy review to name every declared target |
| M1126–M1130 | `74c3a79` | UX target identity guard: reject duplicate target device ids in evidence review |
| M1131–M1135 | `058f800` | UX artifact identity guard: reject duplicate state and interaction artifact paths |
| M1136–M1140 | `6915372` | UX review artifact guard: keep copy and density review artifacts separate |
| M1141–M1145 | `25846e3` | UX relative artifact path guard: reject absolute or external evidence paths |
| M1146–M1150 | `079f7ea` | UX portable artifact path guard: reject Windows absolute evidence paths |
| M1151–M1155 | `35ef104` | UX review target identity guard: reject undeclared reviewed target devices |
| M1156–M1160 | `9140acc` | UX review target duplication guard: reject duplicate reviewed target devices |
| M1161–M1165 | `47cb3c7` | UX blocked-claim callout guard: reject duplicate or unsupported copy-review claims |
| M1166–M1170 | `b3b0ecc` | UX evidence coverage identity guard: reject duplicate target state/interaction coverage |
| M1171–M1175 | `b1429c6` | UX evidence domain guard: reject unsupported state and interaction values |
| M1176–M1180 | `2a1890a` | UX malformed evidence guard: fail closed on malformed evidence containers |
| M1181–M1185 | `b9f6a5c` | UX malformed review input guard: fail closed on non-map evidence input |
| M1186–M1190 | `6993430` | UX malformed JSON review guard: fail closed through JSON review wrapper |
| M1191–M1195 | `3546714` | UX review task malformed input guard: prove task fail-closed JSON shape handling |
| M1196–M1200 | `4b70a5a` | UX target evidence path identity guard: reject duplicate target evidence paths |
| M1201–M1205 | `0c0c05b` | UX state-interaction artifact guard: keep state and interaction artifacts separate |
| M1206–M1210 | `17393bf` | UX review-evidence artifact guard: keep review artifacts separate from evidence artifacts |
| M1211–M1215 | `c471b05` | UX artifact path trim guard: reject paths with leading or trailing whitespace |
| M1216–M1220 | `442bd86` | UX identity trim guard: reject target ids with leading or trailing whitespace |
| M1221–M1225 | `3167372` | UX evidence text trim guard: reject device metadata and notes with leading or trailing whitespace |
| M1226–M1230 | `82ec38a` | UX reviewed-target list guard: reject malformed reviewed target ids instead of dropping them |
| M1231–M1235 | `33d7cfc` | UX scalar field type guard: reject non-string evidence text and path fields |
| M1236–M1240 | `c320944` | UX reviewed-target container guard: reject non-list reviewed target containers |
| M1241–M1245 | `daa9795` | UX blocked-claim container guard: reject non-list blocked claim callouts |
| M1246–M1250 | `3582c11` | UX blocked-claim list guard: reject malformed blocked claim callout entries |
| M1251–M1255 | `38a16c7` | UX boolean field type guard: reject non-boolean review flags |
| M1256–M1260 | `379c05c` | UX allowed-wording type guard: reject non-string approved wording evidence |
| M1261–M1265 | `206bd54` | UX enum field type guard: reject malformed state, interaction, and evidence-kind values |
| M1266–M1270 | `d3ba7d9` | UX enum trim guard: reject enum values with leading or trailing whitespace |
| M1271–M1275 | `fa2f0c9` | UX blocked-claim trim guard: reject callouts with leading or trailing whitespace |
| M1276–M1280 | `1dc37e9` | UX allowed-wording trim guard: reject approved wording with leading or trailing whitespace |
| M1281–M1285 | `7365487` | UX top-level container guard: reject malformed evidence sections explicitly |
| M1286–M1290 | `fcea4bf` | UX evidence row object guard: reject malformed list entries explicitly |
| M1291–M1295 | `e648cf1` | UX review boolean presence guard: reject omitted review flags explicitly |
| M1296–M1300 | `1c2c47a` | UX review list presence guard: reject omitted reviewed-target and claim lists |
| M1301–M1305 | `94464a8` | UX allowed-wording presence guard: reject omitted approved wording explicitly |
| M1306–M1310 | `a8546a6` | UX top-level section presence guard: reject omitted evidence sections explicitly |
| M1311–M1315 | `70200d3` | UX JSON surface guard: keep internal review flags out of archiveable output |
| M1316–M1320 | `dd4f26e` | UX review artifact surface guard: keep internal flags out of written task output |
| M1321–M1325 | `554d186` | Persistence production gate presence guard: reject omitted evidence sections explicitly |
| M1326–M1330 | `1666ba1` | Persistence production gate object guard: reject malformed evidence sections explicitly |
| M1331–M1335 | `27f9082` | Persistence production blocked-claim list guard: reject malformed callout containers explicitly |
| M1336–M1340 | `fdfc92c` | Nearby Messages detail identifiers: expose full-message and beacon-ref detail lines explicitly |
| M1341–M1345 | `9b3c323` | Nearby Messages control summaries: expose active filter and sort descriptions |
| M1346–M1350 | `7f383ae` | Nearby Messages blocked-claim copy: expose per-state claim limits in rows and details |
| M1351–M1355 | `a67d337` | Nearby Messages acceptance gates: require control summaries and blocked-claim copy |
| M1356–M1360 | `b1a106d` | Nearby Messages UX manifest surface summary: archive control summaries and blocked-claim copy |
| M1361–M1365 | `31643ca` | Nearby Messages UX evidence task summary: print control and blocked-claim anchors |
| M1366–M1370 | `686566e` | Release UX artifact anchors: require control summaries and blocked-claim copy in release packaging |
| M1371–M1375 | `e1f7336` | Readiness UX summary anchors: record control summaries and blocked-claim copy in project gates |
| M1376–M1380 | `0b7df88` | UX evidence copy review anchors: require control summaries and per-state blocked-claim copy in operator review |
| M1381–M1385 | `9bc37a0` | UX evidence copy review test anchors: assert control summary and blocked-claim copy requirements |
| M1386–M1390 | `3cae72c` | UX review task copy anchors: keep operator template and task fixtures aligned with copy-review requirements |
| M1391–M1395 | `584cdb1` | UX evidence task copy-review summary: print control-summary and blocked-claim copy requirements |
| M1396–M1400 | `126ad36` | Release UX review artifact anchors: require control-summary and per-state blocked-claim copy in release packaging |
| M1401–M1405 | `febdef6` | UX review task copy summary: print captured warning, control-summary, and blocked-claim-copy flags |
| M1406–M1410 | `80d851a` | Persistence negative fixtures: attach implementation evidence to blocked persistence claims |
| M1411–M1415 | `090a8d0` | Persistence evidence manifest fixture summary: archive implementation-backed negative validation coverage |
| M1416–M1420 | `9cfb248` | Nearby Messages detail evidence manifest: archive selected detail rows for every local inbox state |
| M1421–M1425 | `9828db0` | Nearby Messages detail copy review: require selected detail-panel copy in UX evidence review |
| M1426–M1430 | `debcc28` | Nearby Messages UX coverage summary: archive target, state, interaction, copy, and density coverage counts |
| M1431–M1435 | `8e36dde` | Project UX readiness anchors: record detail evidence and coverage-summary review output in completion audits |
| M1436–M1440 | `bf16409` | Product UX blocker matrix anchors: require selected-detail and coverage-summary evidence in recommended action |
| M1441–M1445 | `10d458e` | Product UX validation plan artifact: emit archiveable on-device checklist before operator evidence review |
| M1446–M1450 | `6b0f533` | Persistence lifecycle plan artifact: emit archiveable production-default checklist before operator evidence review |
| M1451–M1455 | `65dfb17` | Security validation plan artifact: emit archiveable authenticated-security checklist before release evidence review |
| M1456–M1460 | `83cfe92` | Routing validation plan artifact: emit archiveable production-routing checklist before operator evidence review |
| M1461–M1465 | `4c33284` | Lifecycle validation plan artifact: emit archiveable mobile lifecycle checklist before hardware evidence review |
| M1466–M1470 | `3263590` | Release UX validation-plan anchor: include Nearby Messages checklist in release manifest artifacts |
| M1471–M1475 | `6c032fd` | Nearby Messages selected-detail UX review: require per-state selected-detail evidence |
| M1476–M1480 | `762390f` | Selected-detail UX artifact wording: name selected_detail_evidence in release artifacts |
| M1481–M1485 | `4810a04` | Release persistence lifecycle-plan anchor: include production-default checklist in release manifest artifacts |
| M1486–M1490 | `c587df0` | Release validation-plan anchors: include routing and security checklists in release manifest artifacts |
| M1491–M1495 | `ea365a0` | UX artifact bundle template anchor: split target-device scaffold from review output |
| M1496–M1500 | `a669600` | UX release guide evidence checklist: spell out target-device template fields |
| M1501–M1505 | `bd84564` | Release candidate UX review linkage: require Nearby Messages review artifact |
| M1506–M1510 | `8910cd9` | Release candidate UX coverage summary gate: require ready Nearby Messages review metadata |
| M1511–M1515 | `f5cc836` | Release candidate path consistency gate: require operator-note artifact paths to match top-level evidence paths |
| M1516–M1520 | `0e2cb9a` | Release candidate UX review identity gate: require canonical Nearby Messages review identity and blocked claim flags |
| M1521–M1525 | `4e0d295` | Release candidate persistence lifecycle gate: require memory-only default and blocked production-default persistence summary |
| M1526–M1530 | `5b86255` | Release candidate security review gate: require canonical security review summary with trusted claims blocked |
| M1531–M1535 | `b724d1f` | Release candidate routing review gate: require canonical routing review summary with routed claims blocked |
| M1536–M1540 | `4b01d76` | Release candidate lifecycle review gate: require canonical lifecycle review summary with background claims blocked |
| M1541–M1545 | `7caa748` | Release candidate iOS parity review gate: require canonical iOS parity review summary with parity claims blocked |
| M1546–M1550 | `ab3e2ba` | Release candidate full-resolution review gate: require canonical transport review summary with resolution claims blocked |
| M1551–M1555 | `07a4aa0` | Release candidate known-good transport review gate: require canonical transport prerequisite summary with transport claims blocked |
| M1556–M1560 | `f32f76c` | Release candidate multi-hop review gate: require canonical physical multi-hop summary with hardware proof claims blocked |
| M1561–M1565 | `1b1d670` | Nearby Messages selected-detail evidence kind: require screenshot/operator-note classification for selected-detail UX artifacts |
| M1566–M1570 | `3941901` | Nearby Messages interaction evidence kind: require screenshot/operator-note classification for interaction UX artifacts |
| M1571–M1575 | `5ed97c9` | Nearby Messages review artifact evidence kind: require screenshot/operator-note classification for copy and density review artifacts |
| M1576–M1580 | `e5b83da` | Nearby Messages UX validation plan evidence kind: require screenshot/operator-note classification in plan gates |
| M1581–M1585 | `2326af2` | Completion audit UX evidence kind: require classified Nearby Messages UX evidence in top-level blockers |
| M1586–M1590 | `de01541` | Production persistence decision outcome: require explicit memory-only/default lifecycle decision in persistence review |
| M1591–M1595 | `8fb5f71` | Completion audit persistence decision outcome: surface decision_outcome in top-level persistence blockers |
| M1596–M1600 | `a51f59e` | Security release metadata fail-closed parsing: reject unknown gates and non-boolean operator review flags |
| M1601–M1605 | `d32db1c` | Security release metadata container validation: reject malformed attachment container shapes |
| M1606–M1610 | `78a2f39` | Routing production metadata fail-closed parsing: reject missing and malformed gate sections |
| M1611–M1615 | `7b60cd0` | Lifecycle hardware metadata fail-closed parsing: reject missing and malformed gate sections |
| M1616–M1620 | `b8e1e01` | iOS parity metadata fail-closed parsing: reject missing and malformed gate sections |
| M1621–M1625 | `ae38e37` | Multi-hop hardware metadata fail-closed parsing: reject missing and malformed gate sections |
| M1626–M1630 | `0a1e141` | Known-good transport metadata fail-closed parsing: reject missing and malformed gate sections |
| M1631–M1635 | `71fb53b` | Full-resolution transport metadata fail-closed parsing: reject missing and malformed gate sections |
| M1636–M1640 | `04a6755` | Release candidate metadata container validation: reject malformed attachments and operator notes |
| M1641–M1645 | `f323d5b` | Nearby Messages selected-detail state copy: expose limitation, next action, and blocked claims for selected rows |
| M1646–M1650 | `0292d30` | Durable local inbox schema policy: restore JSON-decoded v1 snapshots and reject unsupported versions |
| M1651–M1655 | `9243517` | Beacon reference security risk: classify hash-only beacon refs as pointers, not authorship or trust evidence |
| M1656–M1660 | `a549d4a` | Local routing dry-run evidence: evaluate selected candidates without forwarding or delivery claims |
| M1661–M1665 | `ea07677` | Foreground manual lifecycle session evidence: record operator-run lifecycle actions without background claims |
| M1666–M1670 | `6c2b313` | iOS native source inventory: verify foreground beacon observe source markers without parity claims |
| M1671–M1675 | `4f49e72` | Release recent evidence inventory: archive latest no-new-hardware slices without completion claims |
| M1676–M1680 | `ebcf274` | Nearby Messages affordance review: summarize filters, sorting, selected details, and blocked-claim copy |
| M1681–M1685 | `d99538e` | Persistence default decision artifact: declare keep-memory-only as the current validated-mode default without production persistence claims |
| M1686–M1690 | `dfd2b67` | Routing default decision artifact: declare advert-only non-routing as the current validated-mode routing decision without forwarding claims |
| M1691–M1695 | `f6d6648` | Lifecycle default decision artifact: declare foreground/manual as the current validated-mode lifecycle without background claims |
| M1696–M1700 | `d0d2581` | Security default decision artifact: declare unsigned local observation as the current validated-mode trust decision without authenticated or trusted-message claims |
| M1701–M1705 | `45f0429` | Nearby Messages operator capture plan: archive target-device UX capture slots for states, interactions, selected details, copy review, and visual density |
| M1706–M1710 | `71bed30` | Persistence operator capture plan: archive production-default persistence capture slots for decision, migration, cleanup, writer, restore, and release evidence |
| M1711–M1715 | `48b6a2d` | Routing operator capture plan: archive production routing capture slots for route table, selection, forwarding, delivery, multi-hop, TTL, release, and negative evidence |
| M1716–M1720 | `275686f` | Lifecycle operator capture plan: archive lifecycle capture slots for target devices, foreground service, background BLE, restart, retry, background gossip, and negative evidence |
| M1721–M1725 | `2537be5` | Release operator capture plan: archive release-candidate capture slots for manifests, objective reviews, hardware attachments, operator notes, and final review |
| M1726–M1730 | `267168f` | Security operator capture plan: archive peer/key enrollment, authorship, replay, trust, canonical replay, beacon authentication, release, and negative evidence slots |
| M1731–M1735 | `2aa07fc` | iOS parity operator capture plan: archive target devices, canonical ingress, legacy beacon observe/gossip, full-envelope capability, replay, background boundary, and negative evidence slots |
| M1736–M1740 | `ad8f081` | Nearby Messages target-device scenario plan: archive state row, filter, sort, selected-detail, copy-review, and visual-density capture scenarios |
| M1741–M1745 | `61c0794` | Persistence default decision scenario plan: archive keep-memory-only and durable-default decision scenarios with required gates and blocked claims |
| M1746–M1750 | `e489c3a` | Security decision scenario plan: archive unsigned-observation and authenticated-trust scenarios with required gates and blocked claims |
| M1751–M1755 | `bd351cb` | Routing decision scenario plan: archive advert-only non-routing and production-routing scenarios with required gates and blocked claims |
| M1756–M1760 | `3f88bbb` | Lifecycle decision scenario plan: archive foreground/manual and background-lifecycle scenarios with required gates and blocked claims |
| M1761–M1765 | `7d69305` | iOS parity decision scenario plan: archive contract-only and advert-only participation scenarios with required gates and blocked claims |
| M1766–M1770 | _this commit_ | Nearby Messages UX decision scenario plan: archive pure-surface and production-UX promotion scenarios with required gates and blocked claims |
| M1771–M1775 | _this commit_ | Unsigned security evidence scope: archive current unsigned BLE observation boundaries without trusted-message claims |
| M1776–M1780 | _this commit_ | Selected-detail UX copy evidence: require limitation, next-action, and blocked-claim copy per selected detail artifact |
| M1781–M1785 | _this commit_ | Product UX audit copy anchors: name selected-detail copy fields in completion and readiness blockers |
| M1786–M1790 | _this commit_ | UX evidence task copy anchors: require task summary tests to print selected-detail copy field names |
| M1791–M1795 | `84954b0` | Completion audit open item output: print each remaining objective with status and missing-evidence count |
| M1796–M1800 | `34cae85` | Release docs completion audit output: require OPEN_ITEMS and OPEN_ITEM lines in release-candidate review docs |
| M1801–M1805 | `cdebd9d` | Release docs completion audit guard: test that release docs preserve OPEN_ITEMS and OPEN_ITEM review wording |
| M1806–M1810 | `658c87a` | Plain-text completion audit review artifact: require the non-JSON completion audit command in release command surfaces |
| M1811–M1815 | `d90889f` | CI plain-text completion audit check: capture non-JSON completion audit output and assert OPEN_ITEMS/OPEN_ITEM anchors |
| M1816–M1820 | `e88a1fc` | Release checklist plain-text completion audit archive: require the local release checklist to archive the non-JSON open-objective audit |
| M1821–M1825 | `9f4b067` | Release artifact bundle plain-text audit archive: make the bundle artifact and docs archive `tmp/local-completion-audit.txt` explicitly |
| M1826–M1830 | `392263f` | CI artifact-bundle audit archive guard: assert generated bundle required commands include the plain-text completion audit archive path |
| M1831–M1835 | `5070434` | Release manifest plain-text audit archive: expose the archived completion audit command and artifact in the release manifest |
| M1836–M1840 | `a488720` | Completion audit archive command alignment: require the top-level completion audit to list the plain-text archive command |
| M1841–M1845 | `88735af` | Ledger plain-text audit archive consistency: update earlier release-hardening notes to the archived command path |
| M1846–M1850 | `a9859e8` | Release candidate review plain-text audit path: require operator evidence to include the archived completion audit text path |
| M1851–M1855 | `8a786e2` | Operator capture plan plain-text audit path: require the release capture checklist to collect the archived completion audit text path |
| M1856–M1860 | `54dedac` | Release manifest embedded capture audit path guard: assert embedded operator capture plans expose the archived completion audit text slot |
| M1861–M1865 | `e82a7dd` | Release review audit wording guard: distinguish JSON and plain-text completion audit evidence in capture and bundle wording |

M1–M7 share a commit because that work was sequenced and validated
end-to-end before any of it landed. M8–M22 each got its own commit.
M23–M27 is the current working-tree pass until the Android-to-Android
proof lands.

## M1771-M1775 unsigned security evidence scope

M1771-M1775 adds an explicit `security_scope` section to
`LocalSecurityEvidenceManifest`. The scope records the current mode as
unsigned local BLE observations, lists implementation-backed boundaries such
as canonical replay ingress, local trust policy decision, beacon-reference
risk inventory, memory-only replay lifecycle policy, trust lifecycle
validation, and crypto-negative fixture inventory, and keeps the required
trusted-message gates explicit.

The manifest now states that authenticated peer identity, authorship proof,
peer binding, replay protection, trust lifecycle evidence, beacon-ref
full-envelope resolution, and operator-reviewed security release evidence are
required before trusted-message wording. It also records that current evidence
is not evidence of trusted messages, trusted delivery, authenticated BLE
hardware, durable trust/replay stores, beacon-ref authorship, or freshness.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no authenticated identity,
no routing, no persistence, no background operation, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M1776-M1780 selected-detail UX copy evidence

M1776-M1780 tightens `LocalInboxUxEvidenceReview` so each
`selected_detail_evidence` row must archive the selected-detail copy it claims
to capture. Every row now carries `limitation_copy`, `next_action_copy`, and
`blocked_claim_copy` alongside the target device, state, evidence kind,
artifact path, and notes.

The review rejects selected-detail rows that omit those copy fields, provide
non-string values, or include leading/trailing whitespace. The UX evidence
template now includes the fields explicitly, and the focused review tests prove
the archiveable JSON surface preserves the copy slots without enabling
delivery, trusted-delivery, routing, persistence, background, or release
claims.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1781-M1785 product UX audit copy anchors

M1781-M1785 aligns the project readiness, completion audit, blocker matrix,
and UX evidence manifest wording with the selected-detail evidence fields now
required by `LocalInboxUxEvidenceReview`. Product UX unblock text now names
`limitation_copy`, `next_action_copy`, and `blocked_claim_copy` instead of the
older generic selected-detail-copy phrase.

This keeps the operator-facing completion path tied to concrete archiveable
metadata fields: target-device evidence must still include evidence-kind
classification, state and interaction coverage, selected-detail copy fields,
coverage summary, copy review, and density review before product-facing
release wording can pass.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1786-M1790 UX evidence task copy anchors

M1786-M1790 updates the `mob.node.local_inbox.ux_evidence` task coverage
so its concise text output must include the concrete selected-detail evidence
field names now required by the review contract: `limitation_copy`,
`next_action_copy`, and `blocked_claim_copy`.

This keeps the command-line operator surface aligned with the manifest,
readiness, blocker matrix, and completion audit wording. The task still emits
metadata only; it does not inspect screenshots, drive devices, approve
production UX, or turn nearby observations into delivery, trust, routing,
persistence, background, or completion evidence.

## M1791-M1795 completion audit open item output

M1791-M1795 updates `mix mob.node.local_completion.audit --allow-open` so
the plain-text output lists every remaining whole-project objective directly.
The task now prints `OPEN_ITEMS 10` followed by one `OPEN_ITEM` line per
objective with the objective id, readiness status, and missing-evidence count.

This makes the non-JSON audit output answer "what remains?" without requiring
operators to open the full JSON artifact. The JSON artifact remains the
authoritative machine-readable claim gate, and completion remains blocked
while the ten objective items are partial or blocked.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1796-M1800 release docs completion audit output

M1796-M1800 aligns `docs/RELEASE.md` and
`docs/local_ble_release_artifact_bundle.md` with the updated completion audit
output. Release-candidate review instructions now require `OPEN_ITEMS 10` and
one `OPEN_ITEM objective=... status=... missing=...` line for each remaining
objective before accepting an advert-only release candidate.

This keeps the human release checklist tied to the same open-objective spine
as `LocalProjectCompletionAudit` and prevents the plain-text audit review from
collapsing the remaining work into counts only. The docs still describe the
advert-only mode as limited and keep whole-project completion blocked until
the missing hardware, transport, UX, persistence, security, routing,
lifecycle, iOS parity, and release evidence is real.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1801-M1805 release docs completion audit guard

M1801-M1805 adds a release CI regression test that reads `docs/RELEASE.md`
and `docs/local_ble_release_artifact_bundle.md` directly. The test requires
both human release documents to preserve the plain-text completion audit
review anchors: `OPEN_ITEMS 10`, `OPEN_ITEM`, and remaining-objective review
language. It also checks the artifact bundle doc keeps the concrete
`OPEN_ITEM objective=... status=... missing=...` line shape.

This turns the M1796-M1800 documentation requirement into an executable guard
so future edits cannot silently drop the open-objective release review while
the JSON completion audit still reports whole-project completion as false.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1806-M1810 plain-text completion audit review artifact

M1806-M1810 promotes the non-JSON completion audit review from a docs-only
instruction into the generated release command surface. `LocalReleaseArtifactBundle`
introduced a `completion_audit_plain_text_review` artifact for
`mix mob.node.local_completion.audit --allow-open`; later release-hardening
milestones aligned that artifact, the release manifest, and the whole-project
completion audit on the archived command
`mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt`.

The artifact requires `OPEN_ITEMS 10` and one
`OPEN_ITEM objective=... status=... missing=...` line for each remaining
objective. Focused release/completion tests assert the artifact count, command
surface, JSON output, and plain-text review criteria so release operators see
the open objective list without relying only on the JSON artifact.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1811-M1815 CI plain-text completion audit check

M1811-M1815 wires the plain-text completion audit review into GitHub Actions.
The local release-manifest generation step now runs
`mix mob.node.local_completion.audit --allow-open`, captures its stdout
to `tmp/ci-local-completion-audit.txt`, and asserts that the output includes
`OPEN_ITEMS 10`, the blocked `full_message_resolution` objective, and the
partial `release_hardening` objective.

The release CI regression test checks those workflow anchors so future CI
edits cannot silently drop the non-JSON completion audit review while the
release artifact bundle and release manifest still require it.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1816-M1820 release checklist plain-text completion audit archive

M1816-M1820 mirrors the CI plain-text completion audit gate in the local
release checklist. `docs/RELEASE.md` now requires release operators to archive
`mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt` beside the JSON completion audit and blocker
matrix artifacts.

The focused release CI regression test asserts that the local release document
continues to list this archive command. This keeps the open-objective
`OPEN_ITEMS`/`OPEN_ITEM` review visible in both CI and manual release review
without weakening the JSON whole-project completion gate.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1821-M1825 release artifact bundle plain-text audit archive

M1821-M1825 aligns the generated release artifact bundle with the manual
release checklist. The bundle's `completion_audit_plain_text_review` artifact
now writes to `tmp/local-completion-audit.txt` through
`mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt`, and its acceptance criteria require the
plain-text audit to be archived beside the JSON completion audit.

`docs/local_ble_release_artifact_bundle.md` now includes the same archive
command in its "Generate and archive" command block. The release artifact
bundle regression checks the archive path, source command, and required command
surface so the human bundle instructions cannot drift away from the generated
artifact contract.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1826-M1830 CI artifact-bundle audit archive guard

M1826-M1830 tightens the GitHub Actions release-manifest generation gate so CI
does more than capture `tmp/ci-local-completion-audit.txt` directly. The same
step now also checks the generated release artifact bundle's
`required_commands` list for `local-completion-audit.txt`, proving the
archive command remains part of the generated bundle contract.

The focused release CI regression test checks this workflow anchor beside the
existing release-manifest, blocked-routing, and whole-project-incomplete
assertions. This keeps CI, generated artifact metadata, and manual release
docs aligned on the same plain-text completion audit archive requirement.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1831-M1835 release manifest plain-text audit archive

M1831-M1835 aligns the generated local release manifest with the release
checklist, CI guard, and release artifact bundle. `LocalReleaseManifest` now
lists `mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt` in its required commands and adds a
`completion_audit_plain_text_review` required artifact for the archived
plain-text completion audit output.

The release manifest tests and mix-task JSON tests assert that the plain-text
artifact id and archive path remain present. This keeps release-candidate
metadata from relying only on the JSON completion audit while the whole-project
completion audit still reports open objectives.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1836-M1840 completion audit archive command alignment

M1836-M1840 aligns the top-level whole-project completion audit with the
release manifest and release artifact bundle. `LocalProjectCompletionAudit`
now lists `mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt` in its required commands so the audit itself
points operators to the archived plain-text `OPEN_ITEMS`/`OPEN_ITEM` review.

The completion audit regression tests and mix-task JSON tests now assert that
the archive path remains present in the required command list. This keeps the
prompt-to-artifact checklist, generated release metadata, and manual release
docs aligned on the same completion-audit archive surface.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1841-M1845 ledger plain-text audit archive consistency

M1841-M1845 updates earlier release-hardening ledger wording so it no longer
describes the plain-text completion audit artifact as stdout-only or
bare-command-only. The ledger now records the transition from the original
non-JSON command surface to the archived
`mix mob.node.local_completion.audit --allow-open | tee
tmp/local-completion-audit.txt` release evidence path.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1846-M1850 release candidate review plain-text audit path

M1846-M1850 adds the archived plain-text completion audit to the
release-candidate operator evidence review contract. The review input and
operator notes now require `completion_audit_plain_text_path` beside the JSON
`completion_audit_path`, and the non-JSON mix task summary reports whether the
operator notes include that archived text artifact.

The release artifact bundle's minimum input example now includes
`tmp/local-completion-audit.txt` at both the top level and in operator notes.
The review tests cover missing, malformed, non-relative, mismatched, template,
and complete-input behavior for the new field.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1851-M1855 operator capture plan plain-text audit path

M1851-M1855 aligns the operator capture plan with the release-candidate review
contract. The manifest-path capture section now includes
`completion_audit_plain_text_path`, so the operator checklist asks for the
archived `tmp/local-completion-audit.txt` artifact alongside the JSON
completion audit, release manifest, blocker matrix, readiness manifest, and
advert-gossip audit.

The operator capture plan regression checks that both completion audit paths
remain in the manifest-path section. This keeps the capture checklist from
under-specifying the release-candidate review input.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1856-M1860 release manifest embedded capture audit path guard

M1856-M1860 adds regression coverage for the release manifest's embedded
operator capture plan. Both the in-memory manifest test and the JSON mix-task
test now assert that the `manifest_paths` capture section includes
`completion_audit_plain_text_path`, preserving the archived
`tmp/local-completion-audit.txt` evidence slot in generated release metadata.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M1861-M1865 release review audit wording guard

M1861-M1865 updates release-candidate capture and artifact-bundle wording to
distinguish the JSON completion audit from the archived plain-text completion
audit. `LocalReleaseOperatorCapturePlan` now asks operators for both audit
paths explicitly, and `LocalReleaseArtifactBundle` acceptance criteria require
release notes to reference both JSON and plain-text completion audit evidence.

The focused capture-plan and artifact-bundle regressions assert the JSON and
plain-text wording anchors so future release-review copy cannot collapse the
two artifacts back into a single ambiguous "completion audit" path.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no delivery claim, no trusted-message claim, no routing, no persistence,
no background operation, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## Architecture invariants

These hold across every milestone and shouldn't be violated without
revisiting the contract:

1. **Transport adapters stay contract-thin.** Swift (iOS/macOS) and
   Kotlin (Android) emit v1 wire-format events and perform only
   transport-local decoding needed to turn MeshX manufacturer-data
   advertisements into canonical `received_message` JSON. Routing,
   retries, persistence, peer graph updates, and delivery semantics
   stay out of native code.

2. **`BridgeProtocol.decode/1` is the BEAM normalization point.**
   Every event reaching the Elixir runtime — live transport, replay,
   future NIF — passes through this function. Native receive tests use
   the same canonical event shape so Android/macOS log evidence can be
   replayed through the BEAM contract without a separate test-only
   decode path.

3. **`device_id` is transport-local; `peer_id` is mesh-stable.** iOS
   rotates peripheral UUIDs and Android randomizes MACs, so the runtime
   never trusts `device_id` as identity. `peer_id` derives passively
   from advertisement payloads (M7) or, eventually, from cryptographic
   evidence (reserved sources in `Identity.Claim`).

4. **`PeerTable` is monotonic.** Entries are never removed. Presence
   and churn are derived state, not lifecycle state — a peer that
   "left" is still in the table at `:expired`. This is what makes
   replay deterministic and reappearance trivial.

5. **Identity is sticky.** Once a device has a non-nil `peer_id`, a
   later name-less advertisement does not demote it; a later
   *different* name doesn't overwrite it — it bumps
   `identity_collision_count` and records the conflicting claim.
   First-wins beats last-wins for stability.

6. **All derived state is replay-deterministic.** Same capture →
   same `PeerTable` → same `PeerSummary` list → same churn diff,
   byte-identical. `now` is always an injected argument, never read
   from a clock.

7. **No new processes from M2 onward.** Everything beyond the
   `Session` GenServer (which long predates this work) is a pure
   module of functions over plain data.

8. **Closed atom taxonomies.** Error kinds, identity sources,
   presence states, churn-event kinds, lifecycle states — all
   defined as closed sets. No `String.to_atom/1` on untrusted input
   anywhere.

## Module map

```
Mob.Node.BLE
├── Adapter                 # @behaviour, event_message/1
├── BridgeProtocol          # v1 wire decode/encode (single normalization point)
├── Capabilities            # versioned %{version, roles, features}
├── Capture                 # logcat→JSONL helpers
├── Error                   # closed kind taxonomy
├── Event                   # sum type over canonical events
├── Events.*                # 8 canonical event structs
├── Identity                # advertisement→peer_id derivation
│   └── Claim               #   {peer_id, source} pair
├── Lifecycle               # bridge-side state FSM
├── PeerChurn               # diff over two PeerInventory snapshots
│   └── ChurnEvent          #   kind, summaries, presences, detected_at
├── PeerInventory           # view-model over PeerTable
│   └── PeerSummary         #   one logical peer (collapses rotations)
├── PeerTable               # device_id → Entry, monotonic, source of truth
│   └── Entry               #   sightings + identity + collision metadata
├── PresencePolicy          # pure derive/3 over (last_seen, now, policy)
├── MessageEnvelope         # M14 versioned message bytes
├── MessageAdvertisement    # MeshX manufacturer-data advert → received_message
└── Replay                  # JSONL → BridgeProtocol.decode/1 → target pid
```

## Public read API

A consumer (UI, IEx, log emitter, future JSON read endpoint) reads:

```elixir
table = Mob.Node.Session.snapshot(session).peers
now   = System.monotonic_time(:millisecond)

inventory = Mob.Node.BLE.PeerInventory.list(table, now: now)
# → [%PeerSummary{}] sorted by last_seen desc, display_name asc

churn = Mob.Node.BLE.PeerChurn.diff(previous_inventory, inventory, detected_at: now)
# → [%ChurnEvent{kind: :appeared | :became_stale | :expired | :reappeared
#                     | :identity_promoted | :identity_conflict | :collision_detected, …}]
```

Nothing else in the inventory/churn surface depends on `PeerTable`
internals.

## Churn event vocabulary (post-M12)

| Event | Means |
| --- | --- |
| `:appeared` | Peer not in previous snapshot |
| `:became_stale` | Presence `:active` → `:stale` |
| `:expired` | Presence `:active|:stale` → `:expired` |
| `:reappeared` | Presence `:expired` → not `:expired` (strict: stale→active alone does not qualify) |
| `:identity_promoted` | `previous.peer_id == nil`, `current.peer_id != nil` — gained stable identity |
| `:identity_conflict` | Snapshot-level identity mismatch (`previous.peer_id != current.peer_id`, both non-nil, or named→nil demotion) |
| `:collision_detected` | Underlying `PeerTable.Entry.identity_collision_count` increased between snapshots |

`:identity_conflict` and `:collision_detected` sit at different
layers and can co-occur:

- A peer's first conflicting advertisement on the same device_id
  produces `:collision_detected` (entry-level counter) but no
  `:identity_conflict` (summary's `peer_id` stays sticky).
- A grouping shift that changes the summary's `peer_id` produces
  `:identity_conflict` (snapshot-level mismatch) and may or may not
  also produce `:collision_detected`.

## Hardware validation provenance

The committed fixtures under `test/fixtures/captures/` include slices
of a real capture from a **Samsung SM-T577U** (Galaxy Tab Active 3) on
**Android 13 / API 33**, including the iOS MeshX iPad's `mob-ipad`
advertisement. Full validation ledger in
`docs/android_ble_validation.md`.

## M17–M19 outbox / dispatch pipeline

The send-side flow added in M17–M19 is purely offline. No wire ever
moves, but the whole pipeline is end-to-end testable:

```
MessageEnvelope.build/1            # M14 — versioned bytes contract
  → MessagePlanner.plan/3          # M15 — should this be attempted?
  → AttemptLedger.record/2         # M16 — immutable planned intents
  → Dispatcher.DryRun.dispatch/2   # M17 — :would_dispatch only
     or Transport.Simulated.dispatch/2  # M18 — fake delivery / failure
  → [%AttemptOutcome{kind: …}]     # M19 — closed-taxonomy outcomes
```

### `AttemptOutcome.kind` (closed set)

| kind | Who emits | Meaning |
| --- | --- | --- |
| `:planned` | `AttemptLedger` | recorded but not dispatched |
| `:would_dispatch` | `Dispatcher.DryRun` | accepted, no send |
| `:delivered_simulated` | `Transport.Simulated` | fake success |
| `:failed_simulated` | `Transport.Simulated` | fake failure (reason in field) |
| `:dispatched` | `Dispatcher.Android` (M20+) | **real** transport accepted the send — local stack only, peer reception not implied |
| `:failed` | `Dispatcher.Android` (M20+) | **real** transport rejected the send (e.g. `:bluetooth_off`, `:gatt_write_failed`, `:unauthorized`) |
| `:skipped` | any | caller-supplied `:skip?` matched |
| `:invalid_attempt` | any | attempt failed dispatcher validation |

### `AttemptOutcome.adapter` (closed set)

`:dry_run`, `:simulated`, plus reserved values `:ble_android` and
`:ble_ios` for the future real-transport adapters.

### Determinism

Every stage takes its clock (`now`, `planned_at`, `outcome_at`) and
id functions (`id_fun`) as arguments. The full pipeline is byte-
deterministic given fixed inputs — proven by `PipelineTest`. No
process state, no stored randomness, no implicit clock reads.

## M23–M27 message advertisement delivery

The current working tree extends the M20–M22 Android dispatch spike
from "local BLE stack accepted an advertisement" to "a complete M14
message envelope can be emitted over BLE advertisement and promoted by
a MeshX-capable observer into canonical `received_message` JSON."

Evidence ledger:

- `docs/android_ble_message_delivery_validation.md`
- `scripts/android_ble_message_delivery_two_device.sh`
- `scripts/audit_android_ble_message_delivery_completion.sh`
- `scripts/test_android_ble_message_delivery_two_device.sh`

Current proof state:

- Android Device A (`R52W90AW7EN`, Samsung SM-T577U, Android 13/API 33)
  emitted the 60-byte M14 envelope and logged
  `advertising_set_started`.
- A macOS CoreBluetooth MeshX observer logged canonical
  `received_message` with an envelope byte-for-byte equal to Android's
  emitted payload.
- The exact M26 Android-to-Android proof remains open because only one
  Android adb device is currently attached. The two-device verifier is
  ready and writes preflight artifacts, including a default
  `/tmp/mob-android-m26-*` directory when `--out-dir` is omitted.
  `--preflight-only` can record two-device adb/BLE/USB readiness before
  install or radio work, and `--wait-for-devices <seconds>` can wait for
  a just-attached observer before recording the artifact, but both modes
  deliberately leave M26 incomplete.
  Its `summary.json` includes the authoritative
  `m26_android_to_android_complete` gate plus
  `m26_completion_blockers` and `m26_completion_provenance`; the current
  live/preflight artifacts keep that gate false until two distinct
  Android adb devices produce the sender and observer logcat pair, or
  until verify-only is run over real captured Android logcat files with
  `repo_fixture_log_pair=false`, Android logcat timestamp/pid/tid/tag
  provenance, and explicit model/numeric API/BLE metadata for both
  Android roles. The latest live attempt artifact is
  `/tmp/mob-android-m26-live-attempt-latest/summary.json`; its audit
  result is `m26_android_to_android_complete=false` with blocker
  `expected exactly two attached adb devices, found 1`, and it records
  `R52W90AW7EN` as the only ready Android adb device. The latest
  readiness recheck artifact,
  `/tmp/mob-android-m26-readiness-current/summary.json`, records
  the same one-device blocker after `--wait-for-devices 30` with
  `adb_ready_device_count=1`,
  `adb_nonready_device_count=0`, `adb_mdns_service_count=0`, and
  `host_usb_android_candidate_count=1`. Live and preflight
  summaries also keep adb device
  inventory, `adb mdns services` output, and host USB Android-candidate
  evidence in the same artifact directory for audit, and preflight
  failures now echo the mDNS service count plus host USB Android-candidate
  count directly to stderr beside the generated summary paths. The
  completion audit also echoes the inventory log paths
  (`adb_devices_log`, `adb_mdns_log`, `host_usb_log`) plus
  `adb_ready_device_count`, `adb_nonready_device_count`,
  `adb_mdns_service_count`, and `host_usb_android_candidate_count` when
  it rejects an incomplete or otherwise invalid parsed summary object. A
  lower-level USB recheck also found only `SAMSUNG_Android` serial
  `R52W90AW7EN` with
  `UsbExclusiveOwner=adb`, so the current blocker is not an adb filter
  hiding a second Android USB candidate. A live `adb track-devices`
  watch likewise showed only `R52W90AW7EN device` and no device-change
  events during the 10-second watch window. Device A sender readiness was
  rechecked: package `dev.mob.mob` is installed on `R52W90AW7EN`, the
  device reports `android.hardware.bluetooth_le`, and
  `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, and `BLUETOOTH_CONNECT` are
  granted. The latest single-device sender regression emitted the
  60-byte scan-response M14 payload with matching `attempt_outcome`
  `message_id` / `target_device_ids`, and the latest single-device
  observer-readiness check logged `scan_start_result accepted=true`.
  These are readiness proofs only; they do not replace the missing
  second Android observer logcat. Live mode waits
  for Android Device B's accepted scan-start log before dispatch by
  default to avoid racing the observer startup.
  M26B adds a separate compatibility gate for older Android radios:
  a compact 22-byte legacy manufacturer-data beacon carries a protocol
  marker, envelope version, payload kind, message-id hash, and sender
  peer hash. It decodes to canonical `received_message_beacon`, never
  `received_message`, so the full M14 envelope contract remains intact.
  The SM-T577U to SM-T390 run at
  `/tmp/mob-android-m26b-legacy/summary.json` recorded
  `full_envelope_delivery_complete=false`,
  `legacy_beacon_delivery_complete=true`, a matching 22-byte beacon on
  both Android logcat streams, and no legacy-beacon blockers.
  Checked-in verifier fixtures and known synthetic fixture identities,
  including the checked-in observer fixture's fake top-level or raw
  transport metadata `received_device_id`, are supporting evidence only
  and are blocked by the completion audit.
  The packaged debug APK manifest was also audited: it contains the
  MeshX `MainActivity` plus AndroidX ProfileInstaller's
  `InitializationProvider` / `ProfileInstallReceiver`, and no Android
  services, foreground-service declarations, work schedulers, or service
  start/bind calls.

M23–M27 deliberately still does not add routing, gossip, retries,
persistence, crypto, handshake, background services, guaranteed
delivery, large payload fragmentation, ACKs, or peer graph mutation
from messages. That statement is scoped to the M23-M27 BLE advertisement
delivery path; pre-existing Swift core modules such as `Frame`,
`Fragment`, `Noise`, and `SecureSession` are outside this proof and are
not used by the message advertisement observer/dispatcher path.

## M28 beacon resolution contract

`received_message_beacon` is a reference, not message delivery. M28 adds
`Mob.Node.BLE.BeaconRef` and `Mob.Node.BLE.BeaconResolver`
so callers can make a pure decision from a beacon plus an in-memory
envelope cache:

```elixir
BeaconResolver.resolve(beacon_ref, envelopes)
# => {:already_known, %MessageEnvelope{}}
# => {:needs_fetch, %{message_id_hash: ..., sender_peer_hash: ...}}
# => {:unresolvable, reason}
```

This does not implement fetch transport, ACKs, routing, persistence,
crypto, fragmentation, or retry behavior. It only defines the contract
future fetch work must satisfy.

## M29 beacon fetch request contract

When `BeaconResolver.resolve/2` returns `{:needs_fetch, request}`, M29
turns that pure resolver request into `%BeaconFetchRequest{}` with a
bounded expiry, deterministic injectable `request_id`, optional
`requesting_peer_id`, explicit `candidate_source_peer_ids`, and reason
`:legacy_beacon_ref`.

This remains only an auditable intent. There is no fetch transport,
BLE connection, ACK, routing, persistence, crypto, retry loop, or
fragmentation behavior.

## M30-M32 beacon fetch planning

Legacy beacon fetch planning is now a pure pipeline:

```elixir
BeaconFetchPlanner.select(fetch_request, inventory)
  |> BeaconFetchAttemptLedger.record(fetch_request, planned_at: now)
  |> BeaconFetchDispatcher.DryRun.dispatch(outcome_at: now)
```

Candidate selection prefers active peers, source-peer hash matches,
MeshX-capable peers, stronger identity confidence, and most-recent
sightings with deterministic tie-breaks. The attempt ledger records
immutable `:planned` fetch intents, and the dry-run dispatcher emits
`:would_fetch`, `:skipped`, `:invalid_request`, or `:no_candidates`.

This still does not add fetch transport, BLE connections, ACKs, routing,
persistence, crypto, retries, fragmentation, or mobile native changes.

## M33-M36 constrained beacon fetch transport

Legacy beacon fetch now has a constrained contract and spike path:

```elixir
received_message_beacon
  |> BeaconResolver.resolve(inventory_or_cache)
  |> BeaconFetchRequest.from_resolver_result(...)
  |> BeaconFetchProtocol.request_from_fetch_request()
  |> BeaconFetchTransport.Fake.exchange(responder_cache, ...)
```

M33 defines canonical fetch request/response messages. M34 adds a
bounded in-memory `EnvelopeCache` keyed by `message_id_hash` with an
injectable clock and expiry policy. M35 adds a fake transport adapter
that simulates requester -> responder cache lookup -> response without
opening a transport.

M36 adds the smallest Android-side constrained BLE fetch spike behind a
GATT adapter boundary. It exposes one service with one write-only fetch
request characteristic and one read-only fetch response characteristic.
The debug harness can start one responder serving the fixed M14 fixture
or one requester fetching that envelope from one device address. There
are no retries, routing, gossip, ACKs, fragmentation, persistence,
crypto, background services, or multi-envelope sessions.

The legacy beacon remains a pointer/reference, not message delivery.
Full `received_message` delivery still belongs to full-envelope
advertisements or a successful fetch response carrying the canonical
M14 `MessageEnvelope`.

## M37-M39 constrained GATT fetch hardening

The Android GATT spike now emits phase-specific diagnostics for connect,
MTU request, service discovery, characteristic write/read, timeout,
disconnect, and close. Every client log includes model/API, adapter
state, target address, transport mode where relevant, and a closed
diagnostic reason such as `android_gatt_error`, `connection_timeout`,
or `missing_request_characteristic`.

The client path serializes one fetch at a time, prefers
`BluetoothDevice.TRANSPORT_LE` where available, schedules explicit
connect/service/MTU/read/write timeouts, and always closes the GATT
handle on terminal outcomes. The production `fetchOnce` path still does
not retry. The manual Android validation harness stops scan/advertise
activity before starting requester mode, and its small retry knob only
applies to failed fetch start attempts.

The May 12, 2026 hardware rerun did not retrieve a full envelope. Both
directions started the GATT responder and connectable fetch
advertisement, but both requester devices failed in the connect phase
with normalized reason `android_gatt_error` (`gatt_status=133`) before
service discovery. This remains incomplete hardware fetch proof, not a
protocol success claim.

## M40 standalone GATT interop harness

M40 adds an Android-only `PlainGattInteropHarness` isolated from the
MeshX envelope, fetch protocol, planner, ledger, replay system, and
legacy beacon path. It uses one hardcoded service UUID, one hardcoded
characteristic UUID, a two-byte server payload, and a two-byte client
write payload. Its log tag is `MobGattInterop`.

The May 12, 2026 two-direction hardware run reproduced Android
`gatt_status=133` before service discovery in both directions:

- SM-T577U / Android API 33 responder -> SM-T390 / Android API 28 requester:
  responder advertised successfully; requester failed at `interop_connect_result`
  with `gatt_reason: android_gatt_error`.
- SM-T390 / Android API 28 responder -> SM-T577U / Android API 33 requester:
  responder advertised successfully; requester failed at `interop_connect_result`
  with `gatt_reason: android_gatt_error`.

Because this minimal harness has no MeshX message, fetch contract, or
beacon logic in the path, the observed failure is transport/platform
level for this hardware pair, not a MeshX protocol failure.

## M41 BLE transport decision ledger

M41 marks GATT fetch experimental and disabled by default. The current
Android GATT fetch path remains available only through explicit debug
validation actions, and logs `fetch_gatt_experimental_warning` whenever
it is attempted on unvalidated hardware.

The decision ledger is now in `docs/ble_transport_strategy.md`. The
recommendation is:

- use advertisement-only legacy message beacons for old Android
  hardware;
- use full-envelope advertisements only where sender and observer
  capabilities are proven;
- keep the M33-M36 fake/offline fetch contracts and tests intact;
- keep the M40 standalone GATT harness as a diagnostic tool;
- defer GATT fetch until a known-good hardware pair validates connect,
  service discovery, characteristic write/read, and full-envelope parse.

## M1531-M1535 release candidate routing review gate

Release-candidate metadata must include the production routing review
artifact path and a canonical `LocalRoutingProductionEvidenceReview`
summary before the release-candidate review can become ready. The
summary must use review version `1`, boundary
`:production_routing_evidence_review`, status `:ready`, and
`production_routing_evidence_complete?` set to true while keeping route
table, route selection, forwarding, routed delivery, guaranteed
delivery, and multi-hop hardware claim flags false.

The `mob.node.local_release.candidate_review` task now prints a
`ROUTING_REVIEW` line so operators can see whether the release candidate
is preserving the no-routing boundary. This is release evidence
validation only. It does not add routing, forwarding, ACKs, retries,
delivery guarantees, hardware proof, or whole-project completion.

## M1536-M1540 release candidate lifecycle review gate

Release-candidate metadata must include the mobile lifecycle hardware
review artifact path and a canonical `LocalLifecycleHardwareEvidenceReview`
summary before the release-candidate review can become ready. The
summary must use review version `1`, boundary
`:mobile_ble_lifecycle_hardware_evidence_review`, status `:ready`, and
`lifecycle_hardware_evidence_complete?` set to true while keeping
Android foreground-service, Android background BLE, iOS background,
background BLE, restart, scheduled retry, background gossip, and
delivery claim flags false.

The `mob.node.local_release.candidate_review` task now prints a
`LIFECYCLE_REVIEW` line so operators can see whether the release
candidate is preserving the foreground/manual boundary. This is release
evidence validation only. It does not add a foreground service,
background BLE, restart behavior, scheduled retry, gossip execution,
delivery guarantees, hardware proof, or whole-project completion.

## M1541-M1545 release candidate iOS parity review gate

Release-candidate metadata must include the iOS parity hardware review
artifact path and a canonical `LocalIOSParityHardwareEvidenceReview`
summary before the release-candidate review can become ready. The
summary must use review version `1`, boundary
`:ios_advert_only_hardware_evidence_review`, status `:ready`, and
`ios_hardware_evidence_complete?` set to true while keeping iOS
participation, iOS hardware, legacy beacon observe/gossip, full-envelope
advert, background BLE, and parity claim flags false.

The `mob.node.local_release.candidate_review` task now prints an
`IOS_PARITY_REVIEW` line so operators can see whether the release
candidate is preserving the Android-only validated evidence boundary.
This is release evidence validation only. It does not add iOS scanning,
iOS advertising, iOS background BLE, replay fixtures, hardware proof,
parity support, or whole-project completion.

## M1546-M1550 release candidate full-resolution review gate

Release-candidate metadata must include the full-message-resolution
transport review artifact path and a canonical
`LocalFullMessageResolutionEvidenceReview` summary before the
release-candidate review can become ready. The summary must use review
version `1`, boundary `:full_message_resolution_transport_evidence_review`,
status `:ready`, and `full_resolution_transport_evidence_complete?` set
to true while keeping real fetch transport, full-message resolution,
known-good transport, GATT fetch success, message delivery, and trusted
message claim flags false.

The `mob.node.local_release.candidate_review` task now prints a
`FULL_RESOLUTION_REVIEW` line so operators can see whether unresolved
beacon refs are still being treated as pointers. This is release
evidence validation only. It does not add fetch transport, GATT success,
full envelope retrieval, message delivery, trust, hardware proof, or
whole-project completion.

## M1551-M1555 release candidate known-good transport review gate

Release-candidate metadata must include the known-good transport review
artifact path and a canonical `LocalKnownGoodTransportEvidenceReview`
summary before the release-candidate review can become ready. The
summary must use review version `1`, boundary
`:known_good_transport_evidence_review`, status `:ready`, and
`known_good_transport_evidence_complete?` set to true while keeping
known-good transport, GATT fetch success, full-message resolution, and
message delivery claim flags false.

The `mob.node.local_release.candidate_review` task now prints a
`KNOWN_GOOD_TRANSPORT_REVIEW` line so operators can see whether the
release candidate still treats SM-T577U/SM-T390 status 133 as known-bad
evidence rather than a validated transport. This is release evidence
validation only. It does not add standalone interop success, fetch
transport, GATT success, full envelope retrieval, delivery, hardware
proof, or whole-project completion.

## M1556-M1560 release candidate multi-hop review gate

Release-candidate metadata must include the physical multi-hop hardware
review artifact path and a canonical `LocalMultiHopHardwareEvidenceReview`
summary before the release-candidate review can become ready. The summary
must use review version `1`, boundary `:multi_hop_hardware_evidence_review`,
status `:ready`, and `multi_hop_hardware_evidence_complete?` set to true
while keeping multi-hop physical proof, multi-hop hardware gossip, routed
delivery, guaranteed delivery, trusted delivery, and background operation
claim flags false.

The `mob.node.local_release.candidate_review` task now prints a
`MULTI_HOP_REVIEW` line, and operator notes must cite the same
`multi_hop_review_path` as the top-level candidate metadata. This is release
evidence validation only. It does not add relay execution, routing, delivery
guarantees, trust, background behavior, hardware proof, or whole-project
completion.

## M1561-M1565 Nearby Messages selected-detail evidence kind

M1561-M1565 tightens `LocalInboxUxEvidenceReview` so
`selected_detail_evidence` rows must declare whether the attachment is a
`screenshot` or an `operator_note`, matching the existing `state_evidence`
classification. The template now exposes `evidence_kind` for every selected
detail state, and the review fails closed when the field is missing, malformed,
untrimmed, or outside the supported evidence kinds.

This makes selected-detail UX artifacts auditable as concrete screenshot or
operator-note evidence for full message, unresolved ref, gossiped ref, and
stale ref detail panels. It does not inspect pixels, render UI, approve
production UX, claim delivery, claim trust, claim routing, add background
behavior, or close whole-project completion.

## M1566-M1570 Nearby Messages interaction evidence kind

M1566-M1570 tightens `LocalInboxUxEvidenceReview` so `interaction_evidence`
rows must also declare whether each filter-change, sort-change, row-selection,
or detail-panel attachment is a `screenshot` or an `operator_note`. This aligns
interaction evidence with state and selected-detail evidence, and the review
fails closed when the field is missing, malformed, untrimmed, or unsupported.

The UX template and release artifact wording now make interaction evidence
classification explicit before a product UX review can become ready. This is
metadata hardening only: it does not drive devices, inspect screenshot pixels,
render UI, approve production UX, claim delivery, claim trust, claim routing,
add background behavior, or close whole-project completion.

## M1571-M1575 Nearby Messages review artifact evidence kind

M1571-M1575 tightens `LocalInboxUxEvidenceReview` so `copy_review` and
`visual_density_review` artifacts must declare whether the attachment is a
`screenshot` or an `operator_note`. This brings the copy-review and density
review artifacts into the same evidence-kind contract as state, interaction,
and selected-detail UX evidence.

The template now exposes `evidence_kind` in those review sections, and the
review fails closed when either field is missing, malformed, untrimmed, or
unsupported. This is metadata hardening only: it does not inspect screenshots,
render UI, approve production UX, claim delivery, claim trust, claim routing,
add background behavior, or close whole-project completion.

## M1576-M1580 Nearby Messages UX validation plan evidence kind

M1576-M1580 aligns `LocalInboxUxValidationPlan` with the evidence-review
schema by naming `evidence_kind` in the open plan gates for state coverage,
interaction coverage, copy review, and visual-density review. The plan now
requires screenshot/operator-note classification before on-device evidence can
support product-facing Nearby Messages UX wording.

The local release artifact guide now names `evidence_kind` for state evidence
as well, matching the already-classified interaction, selected-detail, copy,
and density review artifacts. This is validation-plan and documentation
alignment only: it does not inspect screenshot pixels, render UI, drive
devices, approve production UX, claim delivery, claim trust, claim routing,
add background behavior, or close whole-project completion.

## M1581-M1585 Completion audit UX evidence kind

M1581-M1585 aligns the whole-project completion audit, blocker matrix, UX
evidence manifest, and release artifact bundle with the Nearby Messages
`evidence_kind` contract. The top-level recommended product-UX action now
requires classified screenshot/operator-note evidence, and the required
evidence strings name state, interaction, selected-detail, copy-review, and
visual-density evidence classification instead of generic screenshots.

This is operator-facing audit wording and artifact-contract alignment only. It
does not attach UX evidence, inspect screenshot pixels, render UI, drive
devices, approve production UX, claim delivery, claim trust, claim routing,
add background behavior, or close whole-project completion.

## M1586-M1590 Production persistence decision outcome

M1586-M1590 tightens `LocalPersistenceProductionEvidenceReview` so the
`default_lifecycle_decision` gate must carry an explicit `decision_outcome`.
The accepted outcomes are `:keep_memory_only_default` and
`:promote_durable_default`, which keeps operator evidence from treating a
generic decision artifact as enough to satisfy the persistence policy gate.

The production persistence template now exposes `decision_outcome`, and the
persistence evidence manifest names the same field for the product/operator
decision artifact. This is review-contract hardening only: it does not enable
default durable persistence, migrate storage, schedule cleanup, write in the
background, restore on app start, claim delivery records, or close
whole-project completion.

## M1591-M1595 Completion audit persistence decision outcome

M1591-M1595 aligns `LocalProjectCompletionAudit`,
`LocalProjectCompletionBlockerMatrix`, and `LocalProjectReadiness` with the
production persistence review contract. The persistence remaining-work lane now
names `decision_outcome` explicitly, including the keep-memory-only versus
promote-durable-default decision before persistence claims can change.

This is top-level audit and readiness wording only. It does not enable default
durable persistence, migrate storage, schedule cleanup, write in the
background, restore on app start, claim delivery records, or close
whole-project completion.

## M1596-M1600 Security release metadata fail-closed parsing

M1596-M1600 hardens `LocalSecurityReleaseEvidenceReview` so malformed
operator security metadata fails closed. Unknown `plan_gate_ids` now produce
review errors instead of raising during evidence-type validation, and
`operator_reviewed?` must be a boolean instead of accepting arbitrary truthy
values.

This is release-evidence parser hardening only. It does not add key
persistence, trust persistence, replay persistence, encryption, fetch
transport, routing, background behavior, trusted-message wording, trusted
delivery, or whole-project completion.

## M1601-M1605 Security release metadata container validation

M1601-M1605 further hardens `LocalSecurityReleaseEvidenceReview` so malformed
security attachment container shapes fail closed. The top-level
`security_attachments` field must be a list, and each attachment's
`plan_gate_ids`, `evidence_types_by_gate`, and `blocked_claims_called_out`
fields must have the expected list/object/list shapes instead of being silently
collapsed.

This is release-evidence parser hardening only. It does not add key
persistence, trust persistence, replay persistence, encryption, fetch
transport, routing, background behavior, trusted-message wording, trusted
delivery, or whole-project completion.

## M1606-M1610 Routing production metadata fail-closed parsing

M1606-M1610 hardens `LocalRoutingProductionEvidenceReview` so operator routing
metadata fails closed when required gate sections are omitted, gate sections
are not objects, or `blocked_claims_called_out` is not a list. Malformed
metadata is now recorded as review errors instead of being silently treated as
empty evidence.

This is production-routing evidence parser hardening only. It does not add a
routing table, route selection, forwarding service, ACKs, retries, delivery
semantics, multi-hop hardware proof, BLE behavior, or whole-project
completion.

## M42-M45 advertisement-only local mesh mode

M42-M45 makes BLE advertisements the current first-class local transport
mode. The new advert-only profile explicitly supports legacy beacon
advertisements and full-envelope advertisements when capability-proven,
and explicitly excludes GATT fetch, ACKs, large payloads, retries, and
guaranteed delivery.

The local inbox is pure and in-memory:

- `BeaconInbox` records `received_message_beacon` references,
  deduplicated by `message_id_hash + sender_peer_hash`.
- `FullEnvelopeInbox` records canonical `ReceivedMessage` advertisement
  events, validates the embedded M14 envelope before insert, and
  deduplicates by `message_id`.
- `LocalInbox.snapshot/1` exposes one shape with full messages,
  unresolved beacon refs, and transport profile/capability notes.

Replay-driven tests cover the existing M26 full-envelope advertisement
fixture and an M26B-style legacy beacon fixture. This mode does not add
GATT, routing, persistence, ACKs, retries, crypto, background services,
or native Android/iOS behavior.

## M50-M55 opportunistic advertisement gossip

M50-M55 extends the advertisement-only model with a pure planning path
for re-advertising nearby message observations. It compounds the local
inbox without introducing a live BLE send path:

```
LocalInbox.snapshot/1
  -> AdvertGossipPlanner.plan/2
  -> AdvertGossipLedger.record/2
  -> AdvertGossipDispatcher.DryRun.dispatch/2
```

The policy is explicit and caller-owned:

- `AdvertGossipPolicy` bounds how often a seen message reference may be
  planned again and caps the number of intents per planning pass.
- `AdvertGossipLedger` is an in-memory suppression ledger keyed by
  `message_id_hash + sender_peer_hash`.
- `AdvertGossipPlanner` prefers full-message evidence over duplicate
  beacon refs, gossips unresolved refs as legacy beacons, and only plans
  full-envelope advertisements when the caller marks that capability as
  proven.
- `AdvertGossipDispatcher.DryRun` emits auditable `:would_gossip`,
  `:invalid_intent`, or `:no_candidates` outcomes without touching the
  radio.

This milestone intentionally adds no native BLE behavior, no GATT, no
routing, no persistence, no ACKs, no retries, no crypto, no background
service, and no guarantee that a planned gossip intent was transmitted.

## M56-M58 constrained advert gossip execution

M56-M58 adds the first live execution surface for advertisement gossip
without changing the protocol shape. The Elixir side now has
`AdvertGossipDispatcher.Android`, which accepts `AdvertGossipPlanner`
intents and produces canonical `AdvertGossipOutcome` events. The default
host behavior remains truthful: without an injected Android bridge,
legacy beacon gossip fails as `:native_bridge_unavailable`.

The Android side adds `BleAdvertGossipDispatcher`, isolated from the
older full-envelope `BleDispatcher` path. It accepts only the compact
legacy beacon fields already present in a gossip intent:

- `gossip_intent_id`
- `message_id_hash`
- `sender_peer_id_hash`
- `payload_kind`
- `envelope_version`

It builds the 22-byte `MB` legacy beacon payload and starts one bounded
legacy manufacturer-data advertisement. Android emits canonical
`advert_gossip_outcome` JSON and a diagnostic
`legacy_beacon_gossip_started` log line with the advertised beacon bytes.

Full-envelope gossip remains skipped even when capability-proven; that
path is deliberately reserved for a later milestone. M56-M58 adds no
GATT, routing, persistence, ACKs, retries, crypto, fragmentation,
background service, or peer-observed delivery claim.

## M59-M61 advert gossip hardware proof

On May 12, 2026, the constrained legacy-beacon gossip path was validated
on two Android devices:

- sender: Samsung SM-T577U, adb serial `R52W90AW7EN`;
- observer: Samsung SM-T390, adb serial `5200f354f4fb277f`.

Artifact directory:

```
/tmp/mob-android-m59-gossip-live
```

The sender was launched with `mob_gossip_legacy_beacon_test=true`.
Its logcat contains canonical execution evidence:

- `advert_gossip_outcome` with `kind: "gossiped"`,
  `advertise_as: "legacy_beacon_advert"`, and
  `gossip_intent_id: "gossip-spike-0"`;
- `legacy_beacon_gossip_started` with 22-byte beacon payload
  `TUIBAQEAvkXLJgW/Nr5+4cV2P8vIaw==`.

The observer was launched with `mob_start_scan=true`. Its logcat
contains `scan_start_result accepted=true` and 12 canonical
`received_message_beacon` events whose fields match the sender's
advertised beacon:

- `message_id_hash: "vkXLJgW/Nr4="`;
- `sender_peer_id_hash: "fuHFdj/LyGs="`;
- raw `beacon_payload: "TUIBAQEAvkXLJgW/Nr5+4cV2P8vIaw=="`.

The compact summary at
`/tmp/mob-android-m59-gossip-live/summary.json` records
`advert_gossip_hardware_complete=true`,
`observer_received_message_beacon_count=12`, and
`observer_matching_beacon_count=12`.

This proves one Android device can advertise a legacy MeshX message
beacon gossip reference and an older Android device can observe and
decode it into canonical `received_message_beacon` events. It does not
claim full message delivery, fetch resolution, ACK, routing,
persistence, retry, crypto, fragmentation, or background operation.

## M62-M65 local inbox consumer surface

M62-M65 exposes the advertisement-only local inbox through the existing
Mob session snapshot without adding a transport or persistence layer.
`Session` now owns a caller-local `LocalInbox`, ingests canonical
`ReceivedMessage` and `ReceivedMessageBeacon` events into it, and
includes `local_inbox: LocalInbox.snapshot/1` in every
`Session.snapshot/1` result.

The surface keeps the product distinction explicit:

- full `ReceivedMessage` events appear under `full_messages`;
- legacy beacon refs appear under `unresolved_beacon_refs`;
- beacon refs are rendered as nearby references, not delivered
  messages.

The Mob home screen now includes a compact read-only "Nearby Messages"
section that lists full entries and refs separately from the event log.
This remains in-memory only and adds no GATT, routing, persistence,
ACKs, retries, crypto, fragmentation, background services, or fetch
transport.

## M66 transport re-evaluation gate

M66 converts the open-ended "try GATT later" note into a concrete gate
in `docs/ble_transport_re_evaluation.md`.

The current attached Android pair is still:

- Samsung SM-T577U / Android API 33 / `R52W90AW7EN`;
- Samsung SM-T390 / Android API 28 / `5200f354f4fb277f`.

That pair is now validated for legacy beacon advertisement reception and
legacy beacon gossip, but it remains known-bad for GATT because M37-M40
proved `gatt_status=133` before service discovery in both the MeshX
fetch path and standalone GATT interop harness.

The gate requires a new known-good hardware pair to prove standalone
GATT connect, service discovery, characteristic discovery, one tiny
read/write, clean close, and then one constrained fetch that retrieves
and parses a full `MessageEnvelope`. Until that evidence exists, GATT
fetch remains experimental/disabled and advertisement-only local mesh
remains the validated local mode.

## M67-M70 replay-only multi-hop advert gossip simulation

M67-M70 adds `AdvertGossipSimulator`, a pure replay/simulation layer for
multi-hop advertisement gossip. It reuses the existing
`AdvertGossipPlanner`, `AdvertGossipLedger`, and `LocalInbox` contracts,
then feeds simulated canonical `received_message_beacon` events into
neighbor inboxes.

The simulator keeps gossip metadata out of the canonical beacon contract
and inside simulation provenance:

- origin node id;
- hop count;
- TTL remaining;
- path;
- delivery ledger entries for `:delivered`, `:suppressed_loop`,
  `:suppressed_seen`, and `:ttl_expired`.

Focused tests cover:

- a line topology where a beacon moves A -> B -> C;
- TTL stopping propagation before a later hop;
- triangle topology loop/duplicate suppression;
- deterministic delivery ledgers for identical inputs.

This milestone adds no Android/iOS changes, no BLE radio behavior, no
GATT, no live routing, no persistence, no ACKs, no retries, no crypto,
no fragmentation, and no background service.

## M71-M75 advert gossip policy hardening

M71-M75 tightens the replay-only advert gossip model before any future
hardware expansion. `AdvertGossipPolicy` now carries validated gossip
policy fields:

- `default_ttl`;
- `max_hops`;
- `neighbor_cooldown_ms`.

`AdvertGossipSimulator` enforces those rules and records closed outcome
kinds for policy decisions:

- `:suppressed_neighbor_cooldown`;
- `:max_hops_exceeded`;
- `:invalid_provenance`;
- existing `:delivered`, `:suppressed_loop`, `:suppressed_seen`, and
  `:ttl_expired`.

The simulator rejects malformed provenance before forwarding a ref.
Valid provenance requires a binary origin, non-negative hop count,
non-negative TTL, a non-empty binary path ending at the sender, and a
path length that matches the hop count.

Focused tests now cover line, triangle, partitioned, duplicate-origin /
duplicate-seen, neighbor-cooldown, default-TTL, malformed-provenance,
and deterministic-replay cases. This remains pure simulation only: no
Android/iOS changes, no BLE radio behavior, no GATT, no live routing, no
persistence, no ACKs, no retries, no crypto, no fragmentation, and no
background service.

## M76-M80 advert gossip scenario audits

M76-M80 adds an auditable fixture layer over the replay-only gossip
simulator. Scenario JSON files under
`apps/mob_node/test/fixtures/advert_gossip_scenarios/` define:

- named nodes;
- optional capture files used to seed a node inbox;
- topology links;
- rounds, TTL, round interval, and policy values;
- expected delivery counts, node beacon counts, and delivered paths.

`AdvertGossipScenario.run_file!/1` loads those fixtures, runs the
simulator, summarizes the delivery ledger, and reports exact mismatches.
The committed scenarios cover:

- `line_three_nodes`;
- `triangle_duplicate_seen`;
- `partitioned_four_nodes`.

The Mix task
`mix mob.node.advert_gossip.audit <file-or-directory>` runs the same
audit from the command line and exits nonzero on drift. This keeps future
gossip policy changes machine-checkable without touching BLE hardware.

## M81-M85 local inbox UX state read model

M81-M85 improves the product-facing local inbox surface without changing
transport behavior. `LocalInboxView` now projects
`LocalInbox.snapshot/1` into a stable `nearby_messages` list with
explicit item states:

- `:full_message`;
- `:unresolved_ref`;
- `:gossiped_ref` when replay/simulation provenance marks a ref as
  gossip-observed;
- `:stale_ref` when an injected `now` and stale window classify a ref
  as old.

The underlying canonical event contracts remain unchanged. Beacon inbox
entries only track observation source hints such as
`:ble_advertisement` and `:gossip_simulation`; they do not claim
delivery, authorship, resolution, or trust. The Mob home screen renders
the new state labels in the existing "Nearby Messages" section.

This milestone adds no persistence, routing, fetch transport, GATT,
ACKs, retries, crypto, fragmentation, background service, or native
Android/iOS behavior.

## M86-M90 local inbox persistence policy

M86-M90 defines the first storage boundary for the advertisement-only
local inbox without adding a storage engine. The new
`LocalInboxPersistencePolicy` turns a `LocalInbox.snapshot/1` value into
a JSON-safe durable snapshot candidate with an injected `persisted_at`
clock.

The policy preserves the existing product semantics:

- full messages may be persisted only as canonical M14
  `MessageEnvelope` wire bytes after re-encode/re-parse validation;
- legacy beacons persist as `:unresolved_beacon_ref` pointers, not as
  delivered messages;
- raw transport metadata is never persistable;
- source device ids are excluded by default and can only be included via
  an explicit diagnostic option;
- default retention is 7 days for full messages and 24 hours for beacon
  refs, measured from `last_seen_at`.

The detailed policy ledger is in
`docs/local_inbox_persistence_policy.md`. This milestone still adds no
DB/filesystem writes, migration, cleanup worker, background service,
routing, fetch transport, GATT, ACKs, retries, crypto, replay
protection, or Android/iOS native behavior.

## M91-M95 local inbox trust classification

M91-M95 makes the current security/identity limitation explicit in the
local inbox read model. `LocalInboxTrust` classifies each nearby message
view item as either:

- `:unsigned_observation` for full-envelope advertisements whose M14
  bytes are locally validated but not cryptographically authored; or
- `:untrusted_reference` for unresolved, gossiped, or stale legacy
  beacon refs where only hashes are present.

Every current local inbox entry reports `authorship: :unverified` and
`replay_protection: :none`. Full-envelope advertisements get
`integrity: :canonical_envelope_validated`; beacon refs get
`integrity: :hash_reference_only`. `LocalInbox.snapshot/1` now includes
`trust_evidence` beside `nearby_messages` so UI, storage, and future sync
consumers can avoid presenting passive BLE observations as trusted
messages.

The detailed policy ledger is in `docs/local_inbox_trust_policy.md`.
This milestone adds no crypto, signatures, authenticated identity
binding, trust store, replay protection, fetch transport, routing,
persistence, GATT, ACKs, retries, background service, or Android/iOS
native behavior.

## M96-M100 advert gossip release hardening

M96-M100 makes the replay-only advert gossip scenario audit an explicit
release and CI gate. The existing Mix task:

```bash
mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios
```

now runs in `.github/workflows/ci.yml` after the umbrella test suite and
is listed in `docs/RELEASE.md`. This keeps the committed line, triangle,
and partitioned replay scenarios from drifting silently when gossip
policy or simulator behavior changes.

This milestone adds no BLE behavior, no native Android/iOS behavior, no
GATT, no routing, no persistence, no ACKs, no retries, no crypto, no
background service, and no new hardware proof claim.

## M101-M105 local inbox product querying

M101-M105 adds a pure query layer over the advertisement-only local inbox
read model. `LocalInboxQuery` lets consumers filter nearby messages by
state, payload kind, source device id, or observation source; sort by
recency, age, state, payload kind, or RSSI; fetch a detail item by
`message_key`; and derive counts by state.

The Mob home screen now uses the query helper for its "Nearby Messages"
list and renders a compact count line for full messages, unresolved
refs, gossiped refs, and stale refs. This keeps product-facing filtering
and sorting out of the UI template while preserving the existing
read-only local inbox semantics.

This milestone adds no BLE behavior, no native Android/iOS behavior, no
GATT, no routing, no persistence, no ACKs, no retries, no crypto, no
background service, no resolution transport, and no new hardware proof
claim.

## M106-M110 local inbox durable store boundary

M106-M110 adds an explicit CubDB-backed persistence boundary for the
advertisement-only local inbox. `LocalInboxStore` saves only the
policy-approved durable snapshot produced by
`LocalInboxPersistencePolicy`; it does not persist raw BLE events, raw
transport metadata, in-memory inbox structs, or native adapter details.

The store API is deliberately caller-driven:

- `save/2` writes one named durable snapshot with an injected
  `persisted_at` clock;
- `load/1` returns the named snapshot or `:not_found`;
- `delete/1` removes one snapshot;
- `clear/0` removes local-inbox snapshots for tests and diagnostics.

This gives the app a real durable message/ref store boundary while
preserving the policy semantics: full messages remain canonical M14
envelope bytes, beacon refs remain unresolved references, and source
device ids remain opt-in diagnostic data. There is still no automatic
background writer, migration system, sync, routing, fetch transport,
GATT, ACKs, retries, crypto, replay protection, or Android/iOS native
behavior.

## M111-M115 durable local inbox restore

M111-M115 makes saved local inbox snapshots useful to read consumers.
`LocalInboxDurableSnapshot` restores a policy-approved durable snapshot
into a read model with `nearby_messages` and `trust_evidence`, so callers
can use `LocalInboxQuery` against a loaded snapshot without replaying raw
BLE events or reconstructing the live in-memory inbox.

The restore path validates the persisted full-envelope wire bytes by
parsing the canonical M14 `MessageEnvelope` and checking the persisted
message id, sender peer id, and recipient peer id. Legacy beacon refs are
restored as unresolved, gossiped, or stale reference items based on their
saved observation metadata and caller-injected staleness clock.

`LocalInboxStore.load_read_model/2` composes durable load plus restore.
Malformed durable snapshots fail explicitly instead of producing partial
UI state. This milestone adds no automatic save/restore lifecycle hook,
no raw event persistence, no routing, no fetch transport, no GATT, no
ACKs, no retries, no crypto, no replay protection, no background service,
and no Android/iOS native behavior.

## M116-M120 local inbox resolution status

M116-M120 exposes explicit message-resolution state for local inbox
consumers. `LocalInboxResolution` adapts `nearby_messages` into
`resolution_statuses`:

- full messages are `:full_envelope_present`;
- beacon refs matching a locally known full envelope are
  `:already_known`;
- unknown beacon refs are `:needs_fetch` with
  `fetch_transport_state: :not_validated`;
- stale refs become `:stale_needs_fetch`;
- malformed refs or hash mismatches are `:unresolvable`.

The implementation reuses the existing pure `BeaconResolver` contract
and never performs a fetch. `LocalInbox.snapshot/1` and restored durable
read models both include `resolution_statuses`, so UI/API consumers can
show whether a beacon ref points at a known envelope or still needs a
future validated transport.

This milestone adds no fetch transport, no GATT, no BLE connection, no
routing, no persistence changes, no ACKs, no retries, no crypto, no
replay protection, no background service, no delivery claim, and no
Android/iOS native behavior.

## M121-M125 local fetch intent projection

M121-M125 projects unresolved local inbox resolution statuses into
auditable fetch intents without dispatching them. `LocalInboxFetchIntents`
turns `:needs_fetch` and `:stale_needs_fetch` statuses into bounded
`BeaconFetchRequest` structs using the existing M29 request contract.

Each projected intent records:

- the `message_key` from the local inbox read model;
- the resolution state that caused the intent;
- `transport_state: :blocked_unvalidated`;
- the generated `BeaconFetchRequest`;
- notes including `:fetch_intent_only`, `:transport_not_validated`, and
  `:no_dispatch`.

Full messages, already-known refs, and unresolvable refs do not produce
fetch intents. Invalid TTL or request options fail explicitly rather than
emitting malformed intents. This is still a planning/read-model layer:
no fetch transport, no GATT, no BLE connection, no routing, no
persistence changes, no ACKs, no retries, no crypto, no replay
protection, no background service, no delivery claim, and no Android/iOS
native behavior.

## M126-M130 local inbox action summary

M126-M130 adds a product/API-facing action summary over the
advertisement-only local inbox read models. `LocalInboxActionSummary`
combines:

- nearby-message counts from `LocalInboxQuery`;
- resolution counts from `LocalInboxResolution`;
- blockers such as `:fetch_transport_not_validated`,
  `:fetch_intents_not_dispatched`, and `:unresolvable_refs_present`;
- next-action hints such as `:show_full_messages`,
  `:show_unresolved_refs`, `:review_fetch_intents`, and
  `:review_unresolvable_refs`;
- optional blocked fetch intents from `LocalInboxFetchIntents` when the
  caller supplies bounded fetch-intent options.

By default the summary does not generate fetch request ids. When fetch
intents are requested, they remain `transport_state:
:blocked_unvalidated` and include `:no_dispatch` notes. This milestone
adds no fetch transport, no GATT, no BLE connection, no routing, no
persistence changes, no ACKs, no retries, no crypto, no replay
protection, no background service, no delivery claim, and no Android/iOS
native behavior.

## M131-M135 foreground lifecycle profile

M131-M135 adds an explicit lifecycle capability profile for the current
validated mobile BLE mode. `LocalTransportLifecycleProfile` declares the
current support boundary:

- supports foreground scan;
- supports foreground advertise;
- supports manual harness validation;
- supports explicit start/stop;
- does not support Android foreground services;
- does not support Android or iOS background scan/advertise;
- does not support background fetch, background gossip, automatic
  restart, or scheduled retries.

`LocalInbox.snapshot/1` now includes `lifecycle_profile` beside the
transport profile and local inbox read models. This gives product UI,
docs, and release checks a concrete data source for "foreground/manual
only" rather than relying on prose.

This milestone adds no Android foreground service, no iOS background
mode, no native behavior, no scheduler, no retry loop, no background
gossip, no routing, no persistence changes, no fetch transport, no GATT,
no ACKs, no crypto, and no delivery claim.

## M136-M140 platform parity status

M136-M140 adds a platform parity matrix for the advertisement-only local
mesh. `LocalPlatformParity` records the current evidence status for
Android and iOS capabilities:

- Android legacy beacon observation is `:hardware_validated`;
- Android legacy beacon gossip is `:hardware_validated`;
- Android full-envelope advertisements are `:capability_proven_limited`;
- Android GATT fetch is `:blocked_current_hardware`;
- Android background BLE is `:not_implemented`;
- iOS legacy beacon observation is now `:hardware_validated`;
- iOS legacy beacon gossip is `:not_implemented`;
- iOS full-envelope advertisement participation is
  `:blocked_current_hardware` for direct AUX delivery on tested
  hardware;
- iOS GATT fetch is `:not_validated`;
- iOS background BLE is `:not_implemented`.

`LocalInbox.snapshot/1` now exposes this as `platform_parity` so product
UI, docs, release checks, or future read APIs can show where Android has
hardware proof and where iOS parity still needs implementation and
validation.

This milestone adds no native iOS behavior, no Android behavior, no BLE
radio work, no GATT, no fetch transport, no routing, no persistence
changes, no ACKs, no retries, no crypto, no background service, and no
new hardware proof claim.

## M141-M145 hardware validation gates

M141-M145 turns the remaining local BLE hardware proof boundaries into
machine-readable gates. `LocalHardwareValidationGates` records each gate
with a closed status, existing evidence, required evidence, and notes:

- Android one-hop legacy beacon gossip is `:passed`;
- Android full-envelope advert pair proof is `:partial`;
- known-good GATT fetch is `:blocked`;
- multi-hop advert gossip hardware proof is `:blocked`;
- iOS advert-only participation is now `:partial`, with iOS legacy
  beacon observation and Android fetch from iOS `MobFetchGattResponder`
  hardware evidence, while iOS-origin beacon gossip receipt, direct
  full-MX AUX delivery, background BLE, and replay-ledger gates remain
  open.

`LocalInbox.snapshot/1` now exposes this as `hardware_validation_gates`
beside the transport profile, lifecycle profile, platform parity, and
nearby-message read models. This gives UI, docs, and release checks a
single data source for what is actually hardware-proven versus what is
still replay-only, blocked on transport, or not implemented.

This milestone adds no hardware probing, no adb/logcat parsing, no
native behavior, no BLE radio work, no GATT, no fetch transport, no
routing, no persistence changes, no ACKs, no retries, no crypto, no
background service, and no new hardware proof claim.

## M146-M150 project readiness audit

M146-M150 turns the whole-project remaining-work list into an auditable
read model. `LocalProjectReadiness` records ten open completion areas:

- full message resolution;
- known-good transport validation;
- multi-hop hardware proof;
- product UX;
- persistence;
- security and identity;
- routing;
- background mobile lifecycle;
- iOS parity;
- release hardening.

Each item includes a current status, current evidence, remaining work,
and notes. This intentionally corrects stale blanket statements: for
example, local inbox persistence is now `:partial` because the
persistence policy, durable snapshot, CubDB store boundary, and durable
restore exist, but automatic app lifecycle storage is still open.

`LocalInbox.snapshot/1` exposes this as `project_readiness` so callers
can present what remains for the whole local BLE mesh project without
collapsing blocked hardware proof, partial product surfaces, and
not-started security/routing/background work into one vague backlog.

This milestone adds no transport behavior, no hardware probing, no
native behavior, no BLE radio work, no GATT, no routing, no persistence
changes, no ACKs, no retries, no crypto, no background service, and no
new hardware proof claim.

## M151-M155 nearby messages presenter

M151-M155 adds a compact UI presenter for the advertisement-only local
inbox. `LocalInboxPresenter.render_text/2` combines:

- nearby-message state counts from `LocalInboxQuery`;
- resolution counts and blockers from `LocalInboxActionSummary`;
- per-item resolution and fetch transport state;
- per-item trust classification;
- state labels for full messages, unresolved refs, gossiped refs, and
  stale refs.

The Mob home screen now delegates its "Nearby Messages" text to this
presenter, so the basic app surface reflects the newer read models
instead of only listing raw counts. This is still a compact read-only
surface; interactive filtering, sorting controls, and detail screens
remain future product UX work.

This milestone adds no transport behavior, no hardware probing, no
native BLE behavior, no GATT, no routing, no persistence changes, no
ACKs, no retries, no crypto, no background service, and no new hardware
proof claim.

## M156-M160 local readiness audit task

M156-M160 adds a Mix audit task for the local BLE mesh project readiness
read model:

```bash
mix mob.node.local_readiness.audit
mix mob.node.local_readiness.audit --allow-open
```

The default task is release-gate shaped: it prints every open readiness
item and exits nonzero while the project still has open work. The
`--allow-open` option is for development/status reporting, where the
same audit output is useful without failing the command.

This complements the advert gossip scenario audit. Scenario audit proves
the replay policy fixtures; local readiness audit prevents that green
signal from being mistaken for whole-project completion while full
message resolution, known-good transport, multi-hop hardware, security,
routing, background lifecycle, iOS parity, and release criteria remain
open.

This milestone adds no transport behavior, no hardware probing, no
native BLE behavior, no GATT, no routing, no persistence changes, no
ACKs, no retries, no crypto, no background service, and no new hardware
proof claim.

## M161-M165 opt-in local inbox session persistence

M161-M165 wires the existing durable local inbox store into
`Mob.Node.Session` behind explicit options:

- `persist_local_inbox?: true` saves the policy-approved
  `LocalInbox.snapshot/1` after received full-message or beacon events
  and when the session stops;
- `restore_local_inbox?: true` loads a saved durable read model at
  startup and exposes it as `restored_local_inbox`;
- `local_inbox_snapshot_id` scopes the durable snapshot key;
- `persisted_at_fun` keeps tests deterministic and avoids hidden clock
  reads in validation.

Persistence remains disabled by default. Restored data is exposed as a
read model and does not mutate the live in-memory `LocalInbox`, so a
fresh BLE session can distinguish current observations from prior saved
nearby-message state.

This milestone adds no transport behavior, no hardware probing, no
native BLE behavior, no GATT, no routing, no ACKs, no retries, no
crypto, no background service, no automatic default persistence, and no
new hardware proof claim.

## M166-M170 local security identity contract

M166-M170 adds `LocalSecurityIdentityContract`, a pure data contract for
the proof categories required before passive local BLE observations can
be presented as authenticated messages:

- authenticated peer identity;
- message authorship proof;
- replay protection;
- trust policy;
- beacon ref authentication or authenticated full-envelope resolution.

`LocalInbox.snapshot/1` exposes this as `security_identity_contract`
beside `trust_evidence`, and `LocalProjectReadiness` now marks
security/identity as `:partial` rather than not-started. The project has
a trust classifier and a proof contract, but still has no implementation
of signatures, authenticated peer identity, replay protection, or trust
transitions.

This milestone adds no crypto, no signatures, no key management, no
trust store, no replay protection implementation, no transport behavior,
no hardware probing, no native BLE behavior, no GATT, no routing, no
ACKs, no retries, no background service, and no new hardware proof claim.

## M171-M175 local routing contract

M171-M175 adds `LocalRoutingContract`, a pure data contract for the
missing production routing pieces beyond advert-only local observation:

- routing table;
- route selection;
- forwarding service;
- delivery semantics;
- loop and TTL hardware validation.

`LocalInbox.snapshot/1` exposes this as `routing_contract`, and
`LocalProjectReadiness` now marks routing as `:partial` rather than
not-started. Replay advert gossip policy, suppression, and topology
fixtures exist, but they are not a route table, route selector,
forwarding service, ACK/retry policy, or delivery guarantee.

This milestone adds no live routing, no forwarding service, no route
selection, no ACKs, no retries, no transport behavior, no hardware
probing, no native BLE behavior, no GATT, no crypto, no background
service, and no new hardware proof claim.

## M176-M180 background lifecycle contract

M176-M180 adds `LocalBackgroundLifecycleContract`, a pure data contract
for mobile BLE behavior beyond the current foreground/manual lifecycle:

- Android foreground service;
- Android background BLE policy;
- iOS background BLE policy;
- automatic restart;
- background gossip limits.

`LocalInbox.snapshot/1` exposes this as
`background_lifecycle_contract`, and `LocalProjectReadiness` now marks
background/mobile lifecycle as `:partial` rather than not-started. The
foreground/manual lifecycle profile still remains the only supported
mode; this contract records what must be implemented and hardware
validated before any background behavior is claimed.

This milestone adds no Android foreground service, no iOS background
mode, no automatic restart, no scheduled retry, no background gossip, no
native BLE behavior, no transport behavior, no routing, no ACKs, no
retries, no crypto, no GATT, and no new hardware proof claim.

## M181-M185 iOS parity contract

M181-M185 adds `LocalIOSParityContract`, a pure data contract for iOS
participation in the advertisement-only local mesh:

- canonical ingress through `BridgeProtocol`;
- legacy beacon observation;
- legacy beacon gossip;
- full-envelope advertisement participation;
- iOS hardware replay fixtures or validation ledgers.

`LocalInbox.snapshot/1` exposes this as `ios_parity_contract`, and
`LocalProjectReadiness` now marks iOS parity as `:partial` rather than
not-started. The iOS bridge shell and shared canonical contract exist,
but iOS advert-only beacon/full-envelope behavior is still not
implemented or hardware validated.

This milestone adds no native iOS behavior, no CoreBluetooth changes, no
BLE radio behavior, no transport behavior, no GATT, no routing, no ACKs,
no retries, no crypto, no background service, and no new hardware proof
claim.

## M186-M190 readiness audit JSON output

M186-M190 extends the local readiness audit task with machine-readable
JSON output:

```bash
mix mob.node.local_readiness.audit --allow-open --json
```

The JSON includes open, blocked, partial, and not-started counts plus
each open item with its id, status, current evidence, remaining work, and
notes. Default behavior remains release-gate shaped: without
`--allow-open`, the task still exits nonzero while any project readiness
item is open.

This milestone adds no new readiness claim, no transport behavior, no
hardware probing, no native BLE behavior, no GATT, no routing, no ACKs,
no retries, no crypto, no background service, and no new hardware proof
claim.

## M191-M195 readiness audit artifact output

M191-M195 extends the same readiness audit task with explicit JSON
artifact output:

```bash
mix mob.node.local_readiness.audit --allow-open --out tmp/readiness.json
```

The task writes the same machine-readable readiness manifest used by
`--json` to the requested path and creates parent directories as needed.
It can still print the human-readable summary at the same time, and the
default release-gate failure behavior remains unchanged unless
`--allow-open` is supplied.

This milestone adds no new readiness claim, no transport behavior, no
hardware probing, no native BLE behavior, no GATT, no routing, no ACKs,
no retries, no crypto, no background service, and no new hardware proof
claim.

## M196-M200 advert-only release criteria

M196-M200 adds `LocalReleaseCriteria`, a pure data boundary for the
currently validated advertisement-only local mesh mode. It separates a
constrained advert-only release from whole-project completion by
recording satisfied and limited criteria for:

- the advert-only transport profile;
- one-hop legacy beacon observation;
- full-envelope observation on capability-proven hardware;
- the Nearby Messages read surface;
- durable snapshot boundaries;
- readiness/audit artifacts;
- explicit non-goals.

`LocalInbox.snapshot/1` exposes this as `release_criteria` beside
`project_readiness`, hardware gates, platform parity, and the local
inbox read models. The snapshot can say the advert-only local mode is
releasable with limitations while `LocalProjectReadiness` still reports
the whole project as open. This keeps release wording constrained to
"messages seen nearby" and prevents legacy beacon refs from being
presented as guaranteed delivery or full message retrieval.

This milestone adds no new readiness claim for the whole project, no
transport behavior, no hardware probing, no native BLE behavior, no
GATT, no routing, no ACKs, no retries, no crypto, no background service,
and no new hardware proof claim.

## M201-M205 nearby messages product surface

M201-M205 adds `LocalInboxProductSurface`, a UI-ready read model over
`LocalInbox.snapshot/1`. It groups nearby observations into explicit
sections:

- full messages;
- unresolved refs;
- gossiped refs;
- stale refs.

The surface carries state counts, resolution/action summary,
available filter values, active filters, deterministic sort choice, and
optional selected-detail lookup by `message_key`. `LocalInboxPresenter`
now renders this surface as clearer sectioned text instead of a compact
token stream, while retaining the same blockers for unresolved beacon
refs and unvalidated fetch transport.

This advances the product UX boundary without changing the underlying
transport. Native UI controls can now bind to the grouped sections,
filter options, sort option, and selected-detail affordance instead of
reconstructing those concepts from raw inbox entries.

This milestone adds no transport behavior, no hardware probing, no
native BLE behavior, no GATT, no fetch dispatch, no routing, no ACKs, no
retries, no crypto, no persistence behavior, no background service, and
no new hardware proof claim.

## M206-M210 local inbox store maintenance

M206-M210 adds explicit maintenance operations to the caller-driven
durable local inbox store:

- `LocalInboxStore.list/1` returns saved snapshot summaries, including
  snapshot id, persisted timestamp, full-message count, beacon-ref count,
  computed expiry, and deterministic expired state;
- `LocalInboxStore.prune_expired/1` deletes only expired local-inbox
  snapshots and requires an injected `now` clock.

Expiry is derived from the persisted snapshot policy. A snapshot with
`:forever` retention is not pruned; otherwise the maximum configured
retention bounds how long the saved read model remains eligible. This
keeps cleanup explicit and testable while avoiding background behavior
or hidden clock reads.

This milestone adds no automatic default persistence, no migration
system, no scheduled cleanup worker, no sync, no transport behavior, no
hardware probing, no native BLE behavior, no GATT, no routing, no ACKs,
no retries, no crypto, no background service, and no new hardware proof
claim.

## M211-M215 local trust policy gate

M211-M215 adds `LocalTrustPolicy`, a pure policy layer over
`LocalInboxTrust` evidence. The existing trust classifier records what a
nearby item is; the new policy records what product/API surfaces may
claim:

- full-envelope adverts may be displayed as
  `:local_unsigned_message`;
- legacy beacon refs may be displayed as
  `:local_untrusted_reference`;
- current observations are never trusted messages;
- current observations never allow delivery wording.

`LocalInbox.snapshot/1` now exposes this as `trust_policy` beside
`trust_evidence` and `security_identity_contract`. This keeps the
advertisement-only local mode useful for "messages seen nearby" while
blocking stronger security language until authenticated peer identity,
message authorship proof, replay protection, and trust transitions are
implemented and validated.

This milestone adds no crypto, no signatures, no key management, no
replay protection implementation, no trust store, no trust transition,
no transport behavior, no hardware probing, no native BLE behavior, no
GATT, no routing, no ACKs, no retries, no persistence behavior, no
background service, and no new hardware proof claim.

## M216-M220 local routing policy gate

M216-M220 adds `LocalRoutingPolicy`, a pure claim policy for routing-
adjacent behavior in the advertisement-only local mode. The existing
`LocalRoutingContract` records what production routing still needs; the
new policy records what current product/API surfaces may claim:

- local nearby observation is allowed;
- advert gossip planning remains replay/dry-run or constrained advert
  behavior, not production route selection;
- route selection is blocked;
- forwarding service claims are blocked;
- ACK/retry delivery semantics are blocked;
- multi-hop hardware routing claims are blocked.

`LocalInbox.snapshot/1` now exposes this as `routing_policy` beside the
routing contract. This prevents replay gossip or one-hop beacon gossip
from being described as live mesh routing while still preserving the
validated "messages seen nearby" capability.

This milestone adds no live routing, no route table, no route selection,
no forwarding service, no ACKs, no retries, no transport behavior, no
hardware probing, no native BLE behavior, no GATT, no crypto, no
persistence behavior, no background service, and no new hardware proof
claim.

## M221-M225 local lifecycle policy gate

M221-M225 adds `LocalLifecyclePolicy`, a pure claim policy for mobile BLE
lifecycle behavior. The existing lifecycle profile says what the current
transport mode supports; the new policy says what product/API surfaces
may claim:

- foreground/manual scan and advertise operation is allowed;
- Android foreground-service BLE behavior is blocked;
- Android background BLE behavior is blocked;
- iOS background BLE behavior is blocked;
- automatic restart is blocked;
- scheduled retry is blocked;
- background gossip is blocked.

`LocalInbox.snapshot/1` now exposes this as `lifecycle_policy` beside
the foreground/manual lifecycle profile and background lifecycle
contract. This keeps current validation language limited to explicit
foreground/manual operation while making the missing platform lifecycle
work machine-readable.

This milestone adds no Android foreground service, no iOS background
mode, no automatic restart, no scheduler, no scheduled retry, no
background gossip, no native BLE behavior, no transport behavior, no
routing, no ACKs, no retries, no crypto, no persistence behavior, and no
new hardware proof claim.

## M226-M230 iOS parity policy gate

M226-M230 adds `LocalIOSParityPolicy`, a pure claim policy for iOS
participation in the advertisement-only local mesh. The existing
`LocalIOSParityContract` records missing implementation and evidence;
the new policy records what current product/API surfaces may claim:

- shared canonical ingress is contract-only;
- iOS legacy beacon observation now has foreground hardware evidence,
  but does not by itself allow broad iOS parity or delivery claims;
- iOS legacy beacon gossip is blocked;
- iOS full-envelope advert participation is blocked;
- iOS hardware replay fixtures are absent and blocked;
- iOS background BLE participation is blocked.

`LocalInbox.snapshot/1` now exposes this as `ios_parity_policy` beside
the iOS parity contract and platform parity matrix. This prevents
Android validation evidence from being reused as iOS proof while keeping
the shared canonical ingress requirement explicit for future iOS work.

This milestone adds no native iOS behavior, no CoreBluetooth changes, no
iOS scan/advertise behavior, no iOS hardware proof, no background mode,
no transport behavior, no GATT, no routing, no ACKs, no retries, no
crypto, no persistence behavior, and no new hardware proof claim.

## M231-M235 local release manifest

M231-M235 adds `LocalReleaseManifest` and the Mix task:

```bash
mix mob.node.local_release.manifest --json --out tmp/local-release.json
```

The manifest combines:

- advert-only release criteria;
- whole-project readiness counts and open items;
- trust, routing, lifecycle, and iOS parity policy gates;
- required release commands;
- required archive artifacts;
- allowed and blocked release wording.

This gives release packaging and operator docs one machine-readable
artifact for the validated advertisement-only local mode. The manifest
intentionally reports `whole_project_complete? = false` and keeps the
same blockers visible for full message resolution, known-good transport,
and multi-hop hardware proof.

This milestone adds no release claim for the whole project, no transport
behavior, no hardware probing, no native BLE behavior, no GATT, no
routing, no ACKs, no retries, no crypto, no persistence behavior, no
background service, and no new hardware proof claim.

## M236-M240 local release manifest CI gate

M236-M240 wires the mobile advert-only release artifacts into GitHub
Actions. The CI workflow now runs:

```bash
mix mob.node.local_readiness.audit --allow-open --out tmp/ci-local-readiness.json
mix mob.node.local_release.manifest --json --out tmp/ci-local-release.json
```

The step parses both JSON files and asserts the release manifest still
reports `whole_project_complete? = false` and
`routing_claims_allowed? = false`. This turns the advert-only release
boundary into a checked artifact instead of only a local operator
command.

This milestone adds no release claim for the whole project, no transport
behavior, no hardware probing, no native BLE behavior, no GATT, no
routing, no ACKs, no retries, no crypto, no persistence behavior, no
background service, and no new hardware proof claim.

## M241-M245 local release evidence manifest

M241-M245 adds `LocalReleaseEvidenceManifest`, a pure projection of
`LocalHardwareValidationGates` into release-candidate evidence
requirements. The manifest records:

- passed hardware gates and the claims they may support;
- open hardware gates and the evidence still required;
- whether the hardware evidence bundle is complete.

`LocalReleaseManifest` now embeds this as `hardware_evidence`, and the
release checklist requires operators to review it before publishing any
advert-only local release note. Today it records one passed gate
(`android_legacy_beacon_gossip_one_hop`) and four open gates:
Android-to-Android full-envelope advert proof, known-good GATT fetch,
multi-hop advert gossip hardware proof, and iOS advert-only
participation.

This milestone adds no hardware proof, no hardware probing, no transport
behavior, no native BLE behavior, no GATT, no routing, no ACKs, no
retries, no crypto, no persistence behavior, no background service, and
no new release claim for the whole project.

## M246-M250 local inbox native surface model

M246-M250 adds `LocalInboxNativeSurface`, a pure product view model over
`LocalInboxProductSurface`. It exposes:

- state filter controls for all, full messages, unresolved refs,
  gossiped refs, and stale refs;
- deterministic sort choices for recent, state, signal, kind, and
  oldest-first views;
- native-ready rows with title, subtitle, badge, source devices,
  selection state, stale state, and unresolved state;
- a detail panel that preserves the limitation for each item.

This is product-surface work only. The current Mob screen can still
render compact text, and interactive native controls remain future UI
implementation work. The model keeps legacy beacon refs as pointers and
does not upgrade any observation into delivery.

This milestone adds no hardware proof, no hardware probing, no transport
behavior, no native BLE behavior, no GATT, no routing, no ACKs, no
retries, no crypto, no persistence behavior, no background service, and
no new release claim for the whole project.

## M251-M255 local inbox persistence profile

M251-M255 adds `LocalInboxPersistenceProfile`, a pure runtime profile
for the advertisement-only local inbox persistence boundary. It makes
two modes explicit:

- `:memory_only`, the default, with no durable save triggers and no
  restore on start;
- `:opt_in_durable`, which maps to the existing Session options
  `persist_local_inbox?`, `restore_local_inbox?`, and
  `local_inbox_snapshot_id`.

The profile records save triggers for opt-in durable mode
(`:received_full_message`, `:received_message_beacon`, and
`:session_stop`), cleanup as caller-driven
`LocalInboxStore.prune_expired/1` with an injected clock, and unsupported
claims such as delivery guarantees, beacon resolution, background
cleanup, raw transport metadata storage, and crypto material storage.

This milestone adds no default durable lifecycle change, no migrations,
no scheduled cleanup worker, no background-safe writer, no hardware
proof, no hardware probing, no transport behavior, no native BLE
behavior, no GATT, no routing, no ACKs, no retries, no crypto, no
background service, and no new release claim for the whole project.

## M256-M260 local security identity proof plan

M256-M260 adds `LocalSecurityIdentityProofPlan`, a pure proof plan over
`LocalSecurityIdentityContract`. The plan maps every open security
identity requirement to concrete future gates and evidence:

- authenticated peer identity requires key material binding, device
  rotation survival, and negative passive-identity fixtures;
- message authorship requires a signature or equivalent proof bound to
  message id, sender, payload kind, payload bytes, and envelope version;
- replay protection requires a bounded replay window, seen-proof cache,
  duplicate rejection, and expiry rejection;
- trust policy requires explicit trusted, untrusted, blocked, revoked,
  and unknown transitions;
- beacon ref authentication requires either authenticated beacon
  pointers or resolution to a full authenticated envelope before trust
  evaluation.

The plan keeps `trusted_delivery_claims_allowed? = false` and records
that every gate is planned, not implemented. It exists to make the next
security work auditable without weakening the current advert-only trust
boundary.

This milestone adds no crypto, no signatures, no key management, no
trust store, no replay protection implementation, no trust transition,
no hardware proof, no hardware probing, no transport behavior, no native
BLE behavior, no GATT, no routing, no ACKs, no retries, no persistence
behavior, no background service, and no new release claim for the whole
project.

## M261-M265 local routing proof plan

M261-M265 adds `LocalRoutingProofPlan`, a pure proof plan over
`LocalRoutingContract`. It maps every open routing requirement to future
implementation gates and validation evidence:

- routing table work must define route keys, next-hop reachability,
  freshness, invalidation, and a boundary between local observations and
  forwardable routes;
- route selection must define destination lookup, candidate next-hop
  selection, deterministic tie-breaks, unreachable-peer handling, and
  TTL budget checks;
- forwarding service work must define bounded forward intents, a single
  forward execution boundary, lifecycle/cancellation, concurrency, and
  platform power limits;
- delivery semantics must define delivery class, ACK, retry, duplicate,
  expiry, and failure-surface policy before any delivery guarantee;
- loop/TTL hardware validation remains hardware-blocked until three or
  more physical participants produce origin, relay, and observer logs.

The plan keeps `routing_claims_allowed? = false` and records
multi-hop hardware routing as hardware-blocked. Replay advert gossip
remains useful simulation evidence, not production routing.

This milestone adds no live routing, no route table, no route selection,
no forwarding service, no delivery semantics, no hardware proof, no
hardware probing, no transport behavior, no native BLE behavior, no
GATT, no ACKs, no retries, no crypto, no persistence behavior, no
background service, and no new release claim for the whole project.

## M266-M270 local lifecycle proof plan

M266-M270 adds `LocalLifecycleProofPlan`, a pure proof plan over
`LocalBackgroundLifecycleContract`. It maps every open mobile lifecycle
requirement to future implementation gates and validation evidence:

- Android foreground service support requires manifest/service
  declaration, foreground-service permission, notification policy,
  bounded service lifecycle, explicit stop/close, and hardware
  backgrounding logs;
- Android background BLE policy requires scan/advertise policy,
  permission/notification behavior, battery and OS throttling bounds,
  and operator-visible status;
- iOS background BLE remains platform-blocked until capabilities,
  CoreBluetooth policy, bridge events, replay-normalized hardware
  capture, and OS constraint notes exist;
- automatic restart requires trigger, cancellation, backoff, operator
  status, and failure-surface policy without delivery claims;
- background gossip requires rate limits, TTL/loop policy, battery
  budget, platform constraints, and hardware validation without routing
  or delivery claims.

The plan keeps `background_claims_allowed? = false` and
`restart_claims_allowed? = false`. Foreground/manual BLE remains the
only validated lifecycle mode.

This milestone adds no Android foreground service, no iOS background
mode, no scheduler, no automatic restart, no scheduled retry, no
background gossip, no hardware proof, no hardware probing, no transport
behavior, no native BLE behavior, no GATT, no routing, no ACKs, no
retries, no crypto, no persistence behavior, no background service, and
no new release claim for the whole project.

## M271-M275 local iOS parity proof plan

M271-M275 adds `LocalIOSParityProofPlan`, a pure proof plan over
`LocalIOSParityContract`. It maps every open iOS advert-only parity
requirement to future implementation gates and validation evidence:

- canonical ingress requires iOS v1 wire event emission,
  `BridgeProtocol` normalization, `received_message_beacon` mapping,
  `received_message` mapping, and a legacy tuple retirement plan;
- legacy beacon observation requires an iOS scanner implementation,
  legacy beacon decode, canonical `received_message_beacon`, iOS
  device/version capture, and replay-normalized fixture evidence;
- legacy beacon gossip requires an iOS dispatcher, compact beacon
  payload encoder, adapter boundary isolation, observer capture, and an
  audit summary;
- full-envelope adverts require an iOS BLE capability probe, payload
  budget check, M14 encode/decode, canonical `received_message`, and a
  capability-proven hardware pair;
- hardware replay fixtures require raw iOS capture, device metadata,
  canonical JSONL fixture, replay test coverage, and validation ledger
  reference.

The plan keeps `ios_participation_claims_allowed? = false` and records
that Android hardware evidence cannot satisfy iOS parity gates.

This milestone adds no native iOS behavior, no CoreBluetooth changes, no
iOS scan/advertise behavior, no iOS hardware proof, no background mode,
no transport behavior, no GATT, no routing, no ACKs, no retries, no
crypto, no persistence behavior, no background service, and no new
release claim for the whole project.

## M276-M280 local project completion audit

M276-M280 adds `LocalProjectCompletionAudit`, a pure whole-project claim
gate. It maps the ten project-level objective items to their
`LocalProjectReadiness` status, required artifacts, current evidence,
missing evidence, and completion-claim status.

The audit records that:

- `whole_project_complete? = false`;
- `completion_claim_allowed? = false`;
- three items remain blocked: full message resolution, known-good
  transport validation, and multi-hop hardware proof;
- seven items remain partial: product UX, persistence,
  security/identity, routing, background mobile lifecycle, iOS parity,
  and release hardening;
- advertisement-only local mesh is the current validated mode, not
  whole-project completion.

`LocalReleaseManifest` now embeds a completion-audit summary alongside
release criteria, readiness, policy gates, and hardware evidence. That
keeps release-candidate packaging honest: the advert-only local mode can
be documented as "messages seen nearby" while the whole project remains
open until real transport, hardware, security, routing, lifecycle, iOS,
and release evidence closes the blockers.

This milestone adds no hardware proof, no transport behavior, no native
BLE behavior, no GATT, no routing, no ACKs, no retries, no crypto, no
persistence behavior, no background service, and no new release claim for
the whole project.

## M281-M285 Mob Nearby Messages controls

M281-M285 wires `LocalInboxNativeSurface` into `Mob.Node.HomeScreen`
instead of rendering only the compact text presenter. The Mob screen now
has local UI state for:

- nearby-message state filters;
- sort choice;
- selected nearby-message detail;
- rows that distinguish full messages, unresolved refs, gossiped refs,
  and stale refs;
- detail text that repeats the relevant limitation for the selected
  item.

This advances product UX without changing the validated transport
boundary. The screen is still driven entirely by the canonical local
inbox snapshot; selecting filters, sort options, and rows does not fetch,
route, persist, ACK, retry, encrypt, or claim delivery. Product UX
remains partial because the controls still need on-device visual and
operator-copy validation before being treated as a production surface.

This milestone adds no hardware proof, no transport behavior, no native
BLE behavior, no GATT, no routing, no ACKs, no retries, no crypto, no
persistence behavior, no background service, and no new release claim for
the whole project.

## M286-M290 local inbox persistence lifecycle decision

M286-M290 adds `LocalInboxPersistenceLifecycle`, a pure policy artifact
that records the persistence lifecycle decision for the validated
advert-only local mode:

- default app sessions remain memory-only;
- opt-in durable local inbox snapshots remain available through the
  existing Session persistence options;
- restore remains opt-in and read-model only;
- expired snapshot cleanup remains manual/caller-driven;
- durable persistence cannot become the default until migration,
  scheduled cleanup, background-safe write policy, and on-device restore
  validation exist.

This closes the open "decide the default" ambiguity without expanding
runtime behavior. Persistence remains partial because the production
default gate is intentionally blocked until the missing lifecycle
evidence exists. Durable snapshots remain local read models and do not
turn beacon refs into resolved messages or delivery proof.

This milestone adds no new storage behavior, no migrations, no scheduled
cleanup worker, no background-safe write loop, no hardware proof, no
transport behavior, no native BLE behavior, no GATT, no routing, no
ACKs, no retries, no crypto, no background service, and no new release
claim for the whole project.

## M291-M295 local security negative validation

M291-M295 adds `LocalSecurityIdentityNegativeValidation`, a pure negative
validation matrix for the current unsigned advertisement-only mode. It
records cases that must remain blocked from authenticated/trusted/delivery
claims:

- unsigned full-envelope adverts;
- hash-only legacy beacon refs;
- gossiped beacon refs;
- stale beacon refs;
- passive peer labels or advertised names.

Each case records the expected current presentation decision, blocked
claims, required future evidence, and notes. This strengthens the
security boundary without adding crypto: current local BLE observations
can be shown as nearby evidence, but they cannot be promoted to trusted
messages, authenticated peer identity, routed delivery, fresh messages,
or trusted delivery.

This milestone adds no crypto, no signatures, no key management, no
trust store, no replay protection, no fetch transport, no routing, no
persistence behavior, no ACKs, no retries, no background service, and no
new release claim for the whole project.

## M296-M300 local routing negative validation

M296-M300 adds `LocalRoutingNegativeValidation`, a pure negative
validation matrix for the current advert-only non-routing mode. It
records cases that must remain blocked from route-selection, forwarding,
delivery, or multi-hop hardware claims:

- passive peer inventory treated as a routing table;
- stale or unreachable next-hop candidates;
- replay advert gossip treated as production routing;
- missing ACK/retry policy treated as delivery semantics;
- two-device one-hop beacon gossip treated as multi-hop routing.

Each case records the expected current decision, blocked claims,
required future evidence, and notes. This strengthens the routing
boundary without adding routing behavior: current MeshX can show nearby
observations and replay/dry-run gossip policy, but it cannot claim
production route selection, live forwarding, ACK/retry delivery, or
multi-hop hardware routing.

This milestone adds no routing table, no route selection, no forwarding
service, no ACKs, no retries, no delivery semantics, no hardware proof,
no transport behavior, no persistence behavior, no crypto, no background
service, and no new release claim for the whole project.

## M301-M305 local lifecycle negative validation

M301-M305 adds `LocalLifecycleNegativeValidation`, a pure negative
validation matrix for the current foreground/manual BLE lifecycle. It
records cases that must remain blocked from background lifecycle claims:

- manual foreground scan/advertise treated as Android foreground service;
- Android background BLE claims without OS evidence;
- iOS bridge shell treated as iOS background BLE support;
- manual stop/start treated as automatic restart;
- foreground one-hop advert gossip treated as background gossip.

Each case records the expected current decision, blocked claims,
required future evidence, and notes. This strengthens the lifecycle
boundary without adding platform services: current MeshX can claim
foreground/manual BLE operation only, not Android foreground service, iOS
background behavior, automatic restart, scheduled retry, or background
gossip.

This milestone adds no Android foreground service, no iOS background
mode, no scheduler, no automatic restart, no scheduled retry, no
background gossip, no hardware proof, no transport behavior, no routing,
no ACKs, no retries, no crypto, no persistence behavior, and no new
release claim for the whole project.

## M306-M310 local iOS parity negative validation

M306-M310 adds `LocalIOSParityNegativeValidation`, a pure negative
validation matrix for the current partial iOS hardware-evidence state. It records
cases that must remain blocked from iOS advert-only parity claims:

- iOS bridge shell treated as hardware participation;
- Android beacon proof reused as iOS observe proof;
- missing iOS dispatcher treated as legacy beacon gossip;
- unproven iOS full-envelope advert capability;
- missing iOS replay fixture treated as validation evidence.

Each case records the expected current decision, blocked claims,
required future evidence, and notes. This strengthens the iOS parity
boundary without touching native code: shared contracts and bridge shells
remain useful structure, but iOS advert-only participation requires
implementation plus replay-normalized iOS hardware evidence.

This milestone adds no native iOS behavior, no CoreBluetooth scan or
advertise behavior, no iOS hardware proof, no replay fixture, no
transport behavior, no routing, no ACKs, no retries, no crypto, no
persistence behavior, no background service, and no new release claim for
the whole project.

## M311-M315 local release artifact bundle checklist

M311-M315 adds `LocalReleaseArtifactBundle`, a pure operator-facing
packaging contract for advert-only local release candidates. It lists:

- generated artifacts: readiness manifest, release manifest, advert
  gossip audit output;
- embedded artifacts: completion audit and hardware evidence manifest
  inside the release manifest;
- open operator attachments: hardware log bundle and operator release
  notes.

`LocalReleaseManifest` now embeds this artifact bundle checklist so the
machine-readable release artifact shows which files must be archived,
which attachments are still open, and which claims remain blocked. The
human checklist lives in `docs/local_ble_release_artifact_bundle.md` and
preserves the approved wording: MeshX can show "messages seen nearby"
from passive BLE advertisement observations.

This milestone adds no hardware proof, no artifact generator, no native
behavior, no transport behavior, no routing, no ACKs, no retries, no
crypto, no persistence behavior, no background service, and no new
release claim for the whole project.

## M316-M320 Nearby Messages state copy

M316-M320 adds `LocalInboxStateCopy`, a centralized state-copy contract
for the Mob Nearby Messages surface. It defines stable labels, short
labels, badges, state summaries, empty labels, detail titles,
limitations, next actions, severity, and explicit
`delivery_claim_allowed?` flags for:

- full messages;
- unresolved refs;
- gossiped refs;
- stale refs.

`LocalInboxProductSurface` now exposes this state copy, and
`LocalInboxNativeSurface` carries it into filters, rows, and detail panel
data. This keeps the user-facing distinction between full envelopes,
unresolved pointers, gossip observations, and stale refs consistent
without adding transport behavior.

This milestone adds no on-device UX proof, no native transport behavior,
no fetch transport, no routing, no ACKs, no retries, no crypto, no
persistence behavior, no background service, and no new release claim for
the whole project.

## M321-M325 local persistence negative validation

M321-M325 adds `LocalPersistenceNegativeValidation`, a pure negative
validation matrix for the current opt-in durable snapshot boundary. It
records cases that must remain blocked from persistence overclaims:

- opt-in snapshot treated as default app lifecycle persistence;
- persisted beacon ref treated as a delivery record or full message;
- manual prune treated as scheduled cleanup;
- foreground/session save hook treated as background-safe write;
- durable read-model snapshot treated as raw hardware evidence archive.

Each case records the expected current decision, blocked claims,
required future evidence, and notes. This strengthens the persistence
boundary without changing storage behavior: durable snapshots remain
policy-approved local read models, not delivery proof, raw evidence
archives, background lifecycle behavior, or default app persistence.

This milestone adds no migration system, no scheduled cleanup worker, no
background-safe writer, no default app persistence, no raw hardware
archive, no native transport behavior, no fetch transport, no routing,
no ACKs, no retries, no crypto, no background service, and no new release
claim for the whole project.

## M326-M330 Android two-device validation rerun

M326-M330 reruns the SM-T577U / SM-T390 hardware pair with both adb
devices attached:

- SM-T577U: `R52W90AW7EN`, Android 13 / API 33;
- SM-T390: `5200f354f4fb277f`, Android 9 / API 28.

The validation harness now wakes both devices, attempts to dismiss
keyguard, starts activities without blocking on `am start -W`, and waits
an observer-settle period after `scan_start_result accepted=true`. This
fixes a harness-level blocker observed on SM-T390 where Android accepted
the scan call but paused the unfiltered scan while the screen was off.

Current artifacts:

```text
/tmp/mob-android-m26-live-current/summary.json
/tmp/mob-android-m26b-legacy-current/summary.json
```

The full-envelope Android-to-Android proof remains incomplete:
`m26_android_to_android_complete=false` because SM-T390 still does not
log canonical `received_message` for the SM-T577U full-envelope advert.
The audit reports two ready adb devices and no preflight blocker, but
keeps `received_message_logged`, `observer_m14_consistent`,
`observer_mob_routing_metadata`, `payload_match`, and
`android_logcat_provenance` blockers.

The legacy beacon fallback proof passes again:
`legacy_beacon_delivery_complete=true`, `legacy_beacon_payload_match=true`,
and `legacy_beacon_completion_blockers=[]`. The observer logs canonical
`received_message_beacon` with the expected message hash, sender hash,
payload kind, envelope version, and raw BLE transport metadata.

This milestone adds no full-envelope Android-to-Android completion, no
real fetch transport, no GATT success, no multi-hop hardware proof, no
routing, no ACKs, no retries, no crypto, no persistence behavior, no
background service, and no new release claim for the whole project.

## M331-M335 Standalone GATT interop evidence refresh

M331-M335 reruns the standalone M40 GATT interop harness on the same
SM-T577U / SM-T390 hardware pair after the Android validation harness
learned to wake both devices and dismiss keyguard before BLE validation.
The rerun keeps the harness isolated from MeshX protocol behavior: no
`MessageEnvelope`, no beacon resolution, no planner, no replay, no
routing, no crypto, and no persistence.

Current artifacts:

```text
/tmp/mob-android-m40-current/adb-devices.txt
/tmp/mob-android-m40-current/sm-t577u-responder.log
/tmp/mob-android-m40-current/sm-t390-requester.log
/tmp/mob-android-m40-current/sm-t390-responder.log
/tmp/mob-android-m40-current/sm-t577u-requester.log
```

The SM-T577U -> SM-T390 direction starts connectable interop advertising
on SM-T577U, then SM-T390 attempts `TRANSPORT_LE` GATT connect to the
advertiser address. SM-T390 logs `interop_connect_result` with
`gatt_status=133`, normalized `gatt_reason="android_gatt_error"`,
`state_name="disconnected"`, and closes before service discovery.

The SM-T390 -> SM-T577U direction produces the same result in reverse:
SM-T390 starts connectable interop advertising, SM-T577U attempts
`TRANSPORT_LE` GATT connect, receives `gatt_status=133`, normalizes it
to `android_gatt_error`, disconnects, and closes before service
discovery.

This refresh confirms the current GATT blocker is not explained by the
prior screen-off/keyguard harness issue. The known-good transport gate
therefore remains blocked for this hardware pair, and beacon refs remain
unresolved pointers unless a different hardware pair or constrained
transport passes standalone connect, service discovery, characteristic
discovery, and tiny read/write before MeshX fetch behavior is claimed.

This milestone adds no GATT success, no real fetch transport, no beacon
resolution over hardware, no full-envelope Android-to-Android completion,
no multi-hop hardware proof, no routing, no ACKs, no retries, no crypto,
no persistence behavior, no background service, and no new release claim
for the whole project.

## M336-M340 Local BLE release evidence bundle

M336-M340 archives the current Android evidence for the validated
advertisement-only local mesh boundary under a run-specific artifact
directory:

```text
artifacts/local-ble/2026-05-12-sm-t577u-sm-t390/
```

The bundle includes:

- M26 full-envelope Android-to-Android evidence from
  `/tmp/mob-android-m26-live-current`, preserving the incomplete
  full-envelope outcome;
- M26B legacy-beacon evidence from
  `/tmp/mob-android-m26b-legacy-current`, preserving the passed
  `legacy_beacon_delivery_complete=true` proof;
- M40 standalone GATT interop evidence from
  `/tmp/mob-android-m40-current`, preserving the status 133 failures
  before service discovery in both directions;
- generated readiness and release manifests;
- deterministic advert gossip audit output;
- operator wording notes that allow "messages seen nearby" while blocking
  whole-project completion, delivery, trust, routing, background, iOS
  parity, and GATT fetch claims.

This turns volatile `/tmp` hardware captures into a durable local release
evidence bundle without changing runtime behavior or relaxing any open
readiness gate. The release manifest still reports the whole project as
incomplete, with full message resolution, known-good transport
validation, and multi-hop hardware proof blocked.

This milestone adds no new BLE behavior, no GATT success, no real fetch
transport, no beacon resolution over hardware, no full-envelope
Android-to-Android completion, no multi-hop hardware proof, no routing,
no ACKs, no retries, no crypto, no persistence behavior, no background
service, no iOS parity, and no new whole-project completion claim.

## M341-M345 local inbox persistence operator controls

M341-M345 adds `LocalInboxPersistenceOperator`, an explicit operator
control surface over the existing durable local inbox store. It exposes:

- status with an injected clock and deterministic expiry counts;
- save of a policy-approved durable snapshot;
- restore of a read-model snapshot;
- manual prune of expired snapshots;
- manual clear of one snapshot;
- manual clear of all local inbox snapshots.

`LocalInboxPersistenceLifecycle` now embeds these controls beside the
existing policy-level operator actions. `LocalProjectReadiness`,
`LocalProjectCompletionAudit`, and release criteria now distinguish
explicit operator controls from the still-open production-default
persistence requirements: migrations, scheduled cleanup execution,
background-safe writes, and on-device restore validation.

This advances the persistence item without changing the default app
lifecycle. Default sessions remain memory-only; opt-in durable snapshots
remain local read models. The controls do not persist raw transport
metadata, do not turn beacon refs into delivery records, do not schedule
cleanup, do not write in the background, and do not disable future opt-in
saves unless an operator chooses not to use them.

This milestone adds no default persistence, no migration system, no
scheduled cleanup worker, no background-safe write loop, no transport
behavior, no beacon resolution, no GATT, no routing, no ACKs, no retries,
no crypto, no background service, no iOS parity, and no new
whole-project completion claim.

## M346-M350 local security trust model

M346-M350 adds `LocalSecurityTrustModel`, a pure trust-transition model
for future authenticated local BLE message claims. It defines peer states
for `:unknown`, `:untrusted`, `:trusted`, `:blocked`, and `:revoked`,
then evaluates whether a full message or beacon ref has the required
evidence before trusted-message wording could ever be allowed.

Full messages require:

- authenticated peer identity;
- message authorship;
- replay protection;
- trusted peer state.

Beacon refs additionally require:

- full-envelope resolution;
- hash/sender binding.

Stale refs also require fresh-observation evidence. Blocked or revoked
peer states prevent trust even when synthetic proof flags are supplied.

`LocalInbox.snapshot/1` now exposes this model beside the existing
`LocalTrustPolicy`. `LocalSecurityIdentityProofPlan` points its trust
policy gate at the model, while `LocalProjectReadiness`,
`LocalProjectCompletionAudit`, and release criteria continue to mark
security identity as partial. The model is a gate over future evidence,
not a crypto implementation and not a trust store.

This milestone adds no authenticated peer identity, no signatures, no
key management, no replay-protection implementation, no trust store, no
real trust transition, no beacon resolution, no transport behavior, no
GATT, no routing, no ACKs, no retries, no persistence behavior, no
background service, no iOS parity, and no trusted-delivery claim.

## M351-M355 local routing candidate table

M351-M355 adds `LocalRoutingTable`, a pure candidate route table over
`PeerInventory.PeerSummary` observations. It derives direct-route
candidates from local peer observations and deterministically selects a
candidate for a destination peer when the observed peer is:

- named, not anonymous;
- active;
- not identity-contested;
- MeshX-capable;
- advertised or verified identity confidence.

Rejected candidates keep explicit blocker reasons such as
`:anonymous_peer`, `:not_active`, `:identity_contested`,
`:identity_not_usable`, and `:missing_mob_capability`. Missing
destinations produce an explicit `:no_observed_candidate` outcome. The
selector sorts deterministically by forwardability, identity confidence,
recency, RSSI, destination peer id, and target device ids.

`LocalProjectReadiness`, `LocalProjectCompletionAudit`, and release
criteria now record this route-candidate model while keeping routing
partial. The table is an observation read model and selector; it is not
a live routing table, forwarding service, delivery semantic, ACK/retry
system, or hardware multi-hop proof.

This milestone adds no live routing, no forwarding service, no route
execution, no ACKs, no retries, no delivery guarantee, no multi-hop
hardware proof, no background service, no persistence behavior, no
crypto, no GATT, no fetch transport, no iOS parity, and no routed
delivery claim.

## M356-M360 Nearby Messages UX acceptance gate

M356-M360 adds `LocalInboxUxAcceptance`, a pure acceptance contract for
the Mob Nearby Messages surface. It evaluates the existing
`LocalInboxNativeSurface` read model for:

- full, unresolved, gossiped, and stale state filters;
- recency, state, and signal sort controls;
- complete rows for each state with title, subtitle, metadata, and
  badge copy;
- detail panels that carry limitation and next-action copy while
  keeping `delivery_claim_allowed?` false;
- warning copy that blocks pointer, gossip, stale-ref, delivery, trust,
  and routing overclaims.

`LocalInbox.snapshot/1` now exposes `ux_acceptance` beside the local
read models so release/status consumers can see that pure surface
coverage is present while production UX remains blocked. The acceptance
snapshot always keeps the on-device validation gate blocked until
target hardware screenshots or operator notes are attached.

`LocalProjectReadiness`, `LocalProjectCompletionAudit`, and release
criteria now list this UX gate as evidence while keeping `product_ux`
partial. This improves the validation contract for the current
advertisement-only local mode without claiming that hardware UX review
has happened.

This milestone adds no transport behavior, no BLE scan/advertise
changes, no fetch, no routing, no ACKs, no retries, no persistence
behavior, no crypto, no background service, no iOS parity, and no
production UX claim.

## M361-M365 local persistence acceptance gate

M361-M365 adds `LocalPersistenceAcceptance`, a pure acceptance boundary
for the current local inbox persistence stack. It records that the
following opt-in persistence pieces are present:

- `LocalInboxPersistencePolicy` creates policy-approved durable
  snapshots;
- `LocalInboxStore` saves, loads, lists, deletes, and prunes those
  snapshots through the CubDB boundary;
- `LocalInboxDurableSnapshot` restores saved data into queryable
  nearby-message read models;
- `LocalInboxPersistenceOperator` exposes explicit status, save,
  restore, prune, clear-one, and clear-all actions;
- `LocalPersistenceNegativeValidation` keeps default lifecycle,
  background-write, delivery-record, and raw-evidence archive claims
  blocked.

The new acceptance snapshot keeps the
`:production_default_lifecycle` gate blocked until migration,
scheduled cleanup, background-safe write, operator storage controls,
and on-device restore evidence exist. `LocalInbox.snapshot/1` now
exposes this as `persistence_acceptance`, and readiness/release
manifests list it as evidence while keeping persistence partial.

This milestone adds no default app persistence, no scheduled cleanup
worker, no background write behavior, no migration system, no delivery
record, no raw hardware evidence archive, no beacon resolution, no
fetch, no routing, no ACKs, no retries, no crypto, no background
service, and no production persistence claim.

## M366-M370 local security acceptance gate

M366-M370 adds `LocalSecurityAcceptance`, a pure acceptance boundary for
local BLE security and identity claims. It combines:

- `LocalTrustPolicy` for current unsigned/untrusted presentation
  decisions;
- `LocalSecurityIdentityContract` and `LocalSecurityIdentityProofPlan`
  for future proof categories;
- `LocalSecurityTrustModel` for future trusted/blocked/revoked peer
  states;
- `LocalSecurityIdentityNegativeValidation` for current cases that must
  not become trusted/authenticated/delivered claims.

The acceptance snapshot marks current policy, future contract coverage,
future trust model, and negative validation as satisfied gates, while
keeping authenticated peer identity, message authorship, replay
protection, and beacon-ref authentication blocked. It explicitly keeps
authenticated identity, trusted message, trusted delivery, and replay
protection claims disallowed for current local BLE observations.

`LocalInbox.snapshot/1` now exposes this as `security_acceptance`
beside `trust_policy`, `security_identity_contract`, and
`security_trust_model`. Readiness and completion manifests list the new
acceptance gate while keeping `security_identity` partial.

This milestone adds no crypto, no signatures, no key management, no
authenticated peer identity, no authorship proof, no replay-protection
state, no trust store, no trust transition, no beacon authentication, no
fetch, no routing, no ACKs, no retries, no persistence behavior, no
background service, and no trusted-delivery claim.

## M371-M375 local routing acceptance gate

M371-M375 adds `LocalRoutingAcceptance`, a pure acceptance boundary for
local BLE routing claims. It combines:

- `LocalRoutingPolicy`, which allows nearby observation and keeps advert
  gossip planning simulation-only;
- `LocalRoutingTable`, which derives deterministic direct-route
  candidates while disabling routing, forwarding, and delivery claims;
- `LocalRoutingContract` and `LocalRoutingProofPlan`, which enumerate
  future production routing proof categories;
- `LocalRoutingNegativeValidation`, which blocks peer-inventory,
  stale-hop, replay-as-routing, missing ACK/retry, and one-hop-as
  multi-hop claims.

The acceptance snapshot marks observation policy, route-candidate table,
future routing contract coverage, and negative validation as satisfied
gates. It keeps production routing table, route selection, forwarding
service, delivery semantics, and loop/TTL multi-hop hardware validation
blocked. Route-selection, forwarding, routed-delivery, and multi-hop
hardware claims remain disallowed.

`LocalInbox.snapshot/1` now exposes this as `routing_acceptance` beside
the existing routing policy and contract. Readiness and completion
manifests list the new acceptance gate while keeping `routing` partial.

This milestone adds no production routing table, no live route
selection, no forwarding service, no route execution, no ACKs, no
retries, no delivery semantics, no multi-hop hardware proof, no
background service, no persistence behavior, no crypto, no fetch
transport, no iOS parity, and no routed-delivery claim.

## M376-M380 local lifecycle acceptance gate

M376-M380 adds `LocalLifecycleAcceptance`, a pure acceptance boundary
for mobile BLE lifecycle claims. It combines:

- `LocalTransportLifecycleProfile`, which supports foreground scan,
  foreground advertise, manual harness validation, and explicit
  start/stop;
- `LocalLifecyclePolicy`, which allows only foreground/manual operation
  and blocks background, restart, scheduled retry, and background gossip
  claims;
- `LocalBackgroundLifecycleContract` and `LocalLifecycleProofPlan`,
  which enumerate future Android/iOS/background proof categories;
- `LocalLifecycleNegativeValidation`, which blocks foreground harness
  evidence from becoming background, restart, scheduled retry, or
  background gossip claims.

The acceptance snapshot marks foreground/manual profile, lifecycle
policy, future lifecycle contract coverage, and negative validation as
satisfied gates. It keeps Android foreground service, Android
background BLE, iOS background BLE, automatic restart, background gossip,
and scheduled retry blocked. Background, restart, scheduled retry, and
background gossip claims remain disallowed.

`LocalInbox.snapshot/1` now exposes this as `lifecycle_acceptance`
beside the existing lifecycle profile, lifecycle policy, and background
lifecycle contract. Readiness and completion manifests list the new
acceptance gate while keeping `background_mobile_lifecycle` partial.

This milestone adds no Android foreground service, no Android
background scan/advertise, no iOS background scan/advertise, no
automatic restart, no scheduled retry, no background gossip, no
background forwarding, no background delivery, no BLE behavior changes,
no routing, no ACKs, no retries, no fetch, no persistence behavior, no
crypto, and no background-operation claim.

## M381-M385 local iOS parity acceptance gate

M381-M385 adds `LocalIOSParityAcceptance`, a pure acceptance boundary for
iOS advert-only local mesh participation. It combines:

- `LocalIOSParityPolicy`, which treats iOS as contract-only and blocks
  hardware participation claims;
- `LocalIOSParityContract` and `LocalIOSParityProofPlan`, which list
  future iOS implementation and replay-normalized hardware proof
  categories;
- `LocalIOSParityNegativeValidation`, which blocks bridge-shell,
  Android-evidence, missing-dispatcher, unproven-capability, and
  missing-replay-fixture claims.

The acceptance snapshot marks shared canonical contracts, future iOS
parity contract coverage, negative validation, and canonical ingress as
satisfied gates. It keeps legacy beacon observe, legacy beacon gossip,
full-envelope advert, hardware replay fixture, and iOS background BLE
blocked. iOS participation, iOS hardware, iOS parity, and iOS background
claims remain disallowed.

`LocalInbox.snapshot/1` now exposes this as `ios_parity_acceptance`
beside the existing iOS parity contract and policy. Readiness and
completion manifests list the new acceptance gate while keeping
`ios_parity` partial.

This milestone adds no iOS scanner, no iOS dispatcher, no iOS legacy
beacon observe behavior, no iOS beacon gossip, no iOS full-envelope
advert behavior, no iOS hardware capture, no iOS replay fixture, no iOS
background BLE behavior, no routing, no fetch, no ACKs, no retries, no
persistence behavior, no crypto, and no iOS parity claim.

## M386-M390 release-candidate evidence review

M386-M390 adds `LocalReleaseCandidateEvidenceReview`, a pure review
contract for advert-only local release-candidate evidence. It validates
operator-supplied manifest paths, hardware attachment metadata, approved
"messages seen nearby" wording, blocked-claim callouts, and open
hardware-gate callouts.

The review accepts concrete hardware attachment metadata only when it
includes device model, OS/API version, role, command or harness, summary
path, raw log path, and the hardware gates the attachment is intended to
support. Operator notes must use the approved advert-only wording, point
to the readiness and release manifests, call out every blocked claim, and
keep every open hardware gate visible.

`LocalReleaseArtifactBundle`, release criteria, readiness, completion
audit, and `docs/local_ble_release_artifact_bundle.md` now reference the
review contract. A ready review means the advert-only release-candidate
evidence is packaged consistently. It does not create hardware proof, pass
open hardware gates, enable fetch, enable routing, trust messages, add
background behavior, add iOS participation, or close whole-project
completion.

## M391-M395 local security authorship proof boundary

M391-M395 adds `LocalSecurityAuthorshipProof`, a pure authorship proof
boundary for full `MessageEnvelope` values. The module defines the
domain-separated bytes to sign, derives an Ed25519 key id from supplied
public key material, creates detached Ed25519 proofs for tests and future
fixtures, and verifies a proof only when the caller supplies public key
material.

The verifier binds the signature to the canonical encoded envelope bytes
and requires the proof signer to match `sender_peer_id`. Tampering with
the envelope, changing the signer, malformed signatures, and hash-only
beacon refs all fail. Beacon refs remain outside this authorship boundary
until they resolve to a full authenticated envelope.

`LocalSecurityAcceptance` now records this verifier boundary as satisfied
evidence while keeping authenticated identity, message authorship, replay
protection, and beacon authentication gates blocked. The reason is
deliberate: a verifier is not key management, not a trusted peer state,
not replay protection, not beacon authentication, and not trusted
delivery.

This milestone adds no key store, no trust store, no automatic trust
transition, no replay cache, no beacon-ref authentication, no BLE behavior,
no fetch, no routing, no persistence behavior, no background operation, and
no trusted-message or trusted-delivery claim.

## M396-M400 local security peer identity binding

M396-M400 adds `LocalSecurityPeerIdentityBinding`, a pure peer identity
binding boundary for local BLE security proofs. A binding records a
`peer_id`, supplied Ed25519 public key material, and the derived key id
used by `LocalSecurityAuthorshipProof`.

The binding verifier checks that a full `MessageEnvelope` sender matches
the bound peer id, the proof key id matches the bound public key, and the
authorship proof verifies against that key. It rejects mismatched keys,
mismatched peer ids, malformed binding material, and hash-only beacon refs.

`LocalSecurityAcceptance` now records this binding boundary as satisfied
evidence while keeping authenticated identity, message authorship, replay
protection, beacon authentication, trusted-message, and trusted-delivery
claims blocked. The boundary is supplied evidence only: it is not key
discovery, not a key store, not revocation, not a trust store, not replay
protection, and not delivery.

This milestone adds no BLE behavior, no key discovery, no persistent key
store, no trust transition, no revocation mechanism, no replay cache, no
beacon-ref authentication, no fetch, no routing, no background behavior,
and no trusted-message or trusted-delivery claim.

## M401-M405 local security replay protection boundary

M401-M405 adds `LocalSecurityReplayProtection`, a pure bounded replay
guard for verified full-envelope proofs. The guard records proof
fingerprints in memory, rejects duplicate proofs inside the replay window,
rejects expired envelopes, prunes old entries, and enforces a maximum
retained-entry count.

The replay fingerprint binds the canonical encoded `MessageEnvelope`,
proof key id, and proof signature. The guard only accepts full envelope
plus proof inputs; hash-only beacon refs remain outside this boundary
until they resolve to a full authenticated envelope.

`LocalSecurityAcceptance` now records this replay guard boundary as
satisfied evidence while keeping the future replay-protection requirement,
trust policy integration, beacon authentication, trusted-message, and
trusted-delivery claims blocked. The reason is deliberate: this is a pure
in-memory guard, not durable replay storage, not a trust transition, not
beacon authentication, and not a delivery proof.

This milestone adds no BLE behavior, no persistent replay cache, no key
store, no trust store, no revocation mechanism, no beacon-ref
authentication, no fetch, no routing, no background behavior, and no
trusted-message or trusted-delivery claim.

## M406-M410 local trusted-message decision boundary

M406-M410 adds `LocalSecurityTrustedMessageDecision`, a pure
full-envelope decision pipeline over the security boundaries introduced
in M391-M405. It combines:

- `LocalSecurityPeerIdentityBinding`;
- `LocalSecurityAuthorshipProof`;
- `LocalSecurityReplayProtection`;
- explicit peer trust state from the future trust model.

The decision can mark a full `MessageEnvelope` as a local trusted message
only when peer binding, authorship verification, replay protection, and a
trusted peer state are all present. Unknown or untrusted peers remain
untrusted; blocked or revoked peers stay blocked even with otherwise valid
proofs; duplicate replay evidence is rejected before trust can succeed
again.

The decision boundary does not authenticate hash-only beacon refs, does
not fetch full envelopes, and does not claim delivery. Even a trusted
local message decision keeps trusted-delivery, routed-delivery, and
guaranteed-delivery claims blocked.

This milestone adds no BLE behavior, no key discovery, no persistent key
store, no trust store, no revocation storage, no persistent replay cache,
no beacon-ref authentication, no fetch, no routing, no background
behavior, and no trusted-delivery claim.

## M411-M415 local beacon authentication boundary

M411-M415 adds `LocalSecurityBeaconAuthentication`, a pure pointer
authentication boundary for legacy beacon refs. A beacon ref authenticates
only when:

- the ref shape is valid;
- the ref matches a resolved full `MessageEnvelope`;
- the resolved envelope already has a trusted-message decision.

Hash-only beacon refs still cannot become trusted messages by themselves.
Hash mismatch, malformed refs, non-envelope inputs, and untrusted envelope
decisions all fail. Successful beacon authentication remains pointer
authentication only; trusted-delivery, routed-delivery, and
guaranteed-delivery claims stay blocked.

`LocalSecurityAcceptance` now records this beacon authentication boundary
as satisfied evidence while keeping future full integration gates open
until canonical replay fixtures and full-envelope resolution transport
evidence exist.

This milestone adds no BLE behavior, no fetch transport, no full-message
resolution proof, no key discovery, no persistent key store, no trust
store, no persistent replay cache, no routing, no background behavior, and
no trusted-delivery claim.

## M416-M420 local security canonical replay decision

M416-M420 adds `LocalSecurityCanonicalReplayDecision`, a pure boundary
that connects canonical replay ingress to the trusted-message decision
pipeline. It accepts only replay-normalized `ReceivedMessage` events and
requires the same supplied proof inputs as `LocalSecurityTrustedMessageDecision`:

- an Ed25519 authorship proof for the full `MessageEnvelope`;
- a supplied peer identity binding for the sender;
- bounded in-memory replay state;
- explicit caller peer trust state.

The boundary validates that the event's top-level canonical fields match
the embedded envelope and that any captured transport `message_payload`
matches `MessageEnvelope.encode/1`. It rejects malformed/mismatched
events, duplicate proofs, and legacy beacon refs. A trusted result remains
a local trusted-message decision only; trusted-delivery, routed-delivery,
and guaranteed-delivery claims stay blocked.

This closes the canonical replay integration for full-message trusted
decisions while keeping operator trust as an explicit supplied input. It
adds no key discovery, persistent trust store, persistent replay cache,
fetch transport, beacon resolution, routing, persistence, background
behavior, or trusted-delivery claim.

## M421-M425 local operator trust policy boundary

M421-M425 adds `LocalSecurityOperatorTrustPolicy`, a pure trust policy
boundary for supplied peer identity bindings. Trust entries are scoped to
both `peer_id` and Ed25519 `key_id`, so a peer id with different key
material does not inherit trust. The policy supports explicit operator
states:

- `:trusted`;
- `:untrusted`;
- `:blocked`;
- `:revoked`.

`LocalSecurityCanonicalReplayDecision` can now derive `peer_trust_state`
from this policy instead of taking only a raw caller option. A trusted
policy entry still is not enough by itself: the replay-normalized full
message must also pass authorship verification, peer/key binding, and
replay protection. Missing policy entries stay `:unknown`, while blocked
or revoked entries prevent trusted-message promotion.

This milestone adds no key discovery, persistent key store, persistent
trust store, key rotation, revocation sync, fetch transport, routing,
persistence, background behavior, or trusted-delivery claim.

## M426-M430 local crypto negative validation

M426-M430 adds `LocalSecurityCryptoNegativeValidation`, an executable
negative-validation boundary over supplied crypto and replay fixtures. The
boundary runs scenarios through `LocalSecurityCanonicalReplayDecision` and
records whether each case blocks trusted-message promotion and
trusted-delivery wording.

The required negative cases cover:

- tampered transport payload;
- signature mismatch after envelope mutation;
- peer/key binding mismatch;
- duplicate replay of the same signed proof;
- blocked peer policy;
- revoked peer policy;
- hash-only legacy beacon ref promotion.

These cases use the same canonical replay fixture shape, authorship proof,
peer/key binding, replay guard, and operator trust policy boundary as the
positive trusted-message path. Passing the matrix proves over-promotion is
blocked for these cases; it does not create a persistent trust store,
persistent replay cache, key discovery, key rotation, revocation sync,
fetch transport, routing, background behavior, or trusted-delivery claim.

## M431-M435 local security trust lifecycle plan

M431-M435 adds `LocalSecurityTrustLifecyclePlan`, a pure contract for the
remaining durable trust lifecycle work. The current trusted-message path
uses supplied key material, supplied operator trust policy, and in-memory
replay state. This milestone records what must exist before those supplied
inputs can become product trust lifecycle behavior:

- explicit operator key enrollment;
- persistent/platform-protected key and trust storage;
- key rotation without implicit trust transfer;
- block/revoke lifecycle and audit records;
- replay state lifecycle across memory, pruning, and restart policy;
- release audit export for trust lifecycle evidence.

The plan keeps persistent trust store, automatic key discovery, key
rotation, revocation sync, and trusted-delivery claims blocked. It adds no
storage, migration, key discovery, key rotation behavior, revocation sync,
fetch transport, routing, background behavior, or delivery claim.

## M436-M440 Nearby Messages UX validation plan

M436-M440 adds `LocalInboxUxValidationPlan`, a pure on-device validation
contract for the Mob Nearby Messages surface. The existing
`LocalInboxUxAcceptance` proves the read model exposes state filters,
sorting, rows, detail panels, and blocked-claim warnings. This milestone
defines the operator evidence that must be attached before the product UX
claim can close:

- target device matrix with model, OS/API, screen class, and build id;
- screenshots or notes for full message, unresolved ref, gossiped ref, and
  stale ref states;
- interaction coverage for filters, sorting, row selection, and detail
  panel;
- blocked-claim copy review for nearby/observed/ref wording;
- visual density review for row truncation, wrapping, tap target comfort,
  and warnings.

`LocalInboxUxAcceptance` now points its blocked on-device gate at this
plan. Production Nearby Messages UX remains blocked until those gates have
operator evidence. This milestone adds no UI automation, no device
control, no scanning, no advertising, no persistence, no routing, no
trusted-delivery claim, and no transport behavior.

## M441-M445 local persistence production lifecycle plan

M441-M445 adds `LocalPersistenceProductionLifecyclePlan`, a pure gate
checklist for the work required before opt-in durable snapshots can become
default app lifecycle persistence. The current default remains memory-only
and `LocalPersistenceAcceptance` still blocks the
`:production_default_lifecycle` gate.

The plan records six blocked gates:

- product decision and release wording for default lifecycle persistence;
- schema migration policy for durable snapshot versions;
- scheduled cleanup worker or lifecycle hook;
- background-safe writer behavior for mobile lifecycle transitions;
- on-device restore fixture for full, unresolved, gossiped, and stale
  nearby-message states;
- release artifact evidence and operator review.

`LocalPersistenceAcceptance`, `LocalProjectReadiness`, completion audit,
and release criteria now list the plan as evidence while keeping default
app persistence, background persistence, delivery records, full-message
resolution, and trusted-delivery claims blocked. This milestone adds no
migration system, cleanup worker, background writer, default restore,
storage behavior, fetch transport, routing, crypto, or delivery claim.

## M446-M450 local lifecycle hardware validation plan

M446-M450 adds `LocalLifecycleHardwareValidationPlan`, a pure evidence
checklist for future mobile BLE lifecycle claims. The current accepted mode
remains foreground/manual, and `LocalLifecycleAcceptance` still blocks
Android foreground-service BLE, Android/iOS background scan/advertise,
automatic restart, scheduled retry, background gossip, and background
delivery claims.

The plan records eight blocked gates:

- target device matrix with model, OS/API, BLE adapter state, battery
  policy, and build id;
- Android foreground-service backgrounding logs;
- Android background BLE policy and OS throttling evidence;
- iOS background BLE capability and hardware evidence;
- restart trigger and cancellation evidence;
- scheduled retry bounds and failure surfaces;
- background gossip rate limits, TTL/loop policy, and battery bounds;
- negative claim review tied to implementation-backed fixtures.

`LocalLifecycleAcceptance`, `LocalProjectReadiness`, completion audit, and
release criteria now list the plan as evidence while keeping all background
and restart behavior blocked. This milestone adds no Android foreground
service, no iOS background mode, no scheduler, no scan/advertise behavior,
no background gossip, no routing, no ACKs, no retries, no persistence
behavior, no crypto, and no background-operation claim.

## M451-M455 local iOS parity hardware validation plan

M451-M455 adds `LocalIOSParityHardwareValidationPlan`, a pure evidence
checklist for future iOS advert-only local mesh participation. iOS remains
contract-only today: shared canonical event shapes exist, but no native iOS
advert-only observe/gossip implementation or hardware capture is validated.

The plan records eight blocked gates:

- target iOS device matrix with model, iOS version, BLE state, permission
  state, foreground/background state, and build id;
- canonical ingress fixture for iOS-origin `received_message_beacon` and
  future `received_message` events;
- legacy beacon observe hardware capture;
- legacy beacon gossip hardware capture with a MeshX-capable observer;
- full-envelope advert capability probe or explicit negative capability
  ledger;
- replay-normalized hardware fixture or validation ledger;
- iOS foreground/background BLE boundary;
- negative claim review for bridge shell only, Android evidence reuse,
  missing dispatcher, unproven capability, and missing replay fixtures.

`LocalIOSParityAcceptance`, `LocalProjectReadiness`, completion audit, and
release criteria now list the plan as evidence while keeping iOS hardware
participation, advert-only validation, legacy beacon observe/gossip,
full-envelope advert, hardware replay fixture, iOS background BLE, and iOS
parity claims blocked. This milestone adds no iOS native BLE behavior, no
scan/advertise path, no hardware proof, no background mode, no fetch, no
routing, no ACKs, no retries, no persistence behavior, no crypto, and no
iOS parity claim.

## M456-M460 local routing hardware validation plan

M456-M460 adds `LocalRoutingHardwareValidationPlan`, a pure evidence
checklist for future production routing. The current mode remains
advertisement-only local observation: `LocalRoutingTable` produces
deterministic route candidates, but candidates are read-model entries, not
forwarding actions.

The plan records eight blocked gates:

- production route table state model;
- deterministic route selection;
- forwarding service boundary;
- delivery semantics policy;
- multi-hop hardware rig with origin, relay, and observer roles;
- TTL decrement, loop suppression, duplicate suppression, and expiry
  evidence;
- release artifact evidence and operator wording review;
- implementation-backed negative claim review.

`LocalRoutingAcceptance`, `LocalProjectReadiness`, completion audit, and
release criteria now list the plan as evidence while keeping route table,
route selection, forwarding, routed delivery, guaranteed delivery,
ACK-backed delivery, retry-backed delivery, and multi-hop hardware routing
claims blocked. This milestone adds no production routing table, no route
selection, no forwarding service, no delivery semantics, no hardware proof,
no scan/advertise behavior, no fetch, no persistence behavior, no crypto,
and no routing or delivery claim.

## M461-M465 local security identity validation plan

M461-M465 adds `LocalSecurityIdentityValidationPlan`, a pure evidence
checklist for future authenticated local BLE security claims. The current
security stack has pure boundaries for authorship proof, peer/key binding,
replay protection, operator trust policy, trusted-message decisions,
canonical replay, beacon authentication, trust lifecycle planning, and
crypto negative validation. Those boundaries still require supplied inputs
and do not create trusted-message or trusted-delivery claims.

The plan records eight blocked gates:

- peer key enrollment;
- authorship fixture matrix;
- replay state lifecycle;
- trust policy lifecycle;
- canonical replay integration;
- beacon-ref authentication integration;
- release artifact evidence;
- negative claim review.

`LocalSecurityAcceptance`, `LocalProjectReadiness`, completion audit, and
release criteria now list the plan as evidence while keeping authenticated
peer identity, authenticated message, trusted message, trusted delivery,
and fresh-message claims blocked. This milestone adds no key enrollment,
no persistent key store, no persistent trust store, no persistent replay
state, no full-envelope resolution transport, no routing, no ACKs, no
retries, no persistence behavior, no background behavior, and no
trusted-message or trusted-delivery claim.

## M466-M470 local fetch transport validation plan

M466-M470 adds `LocalFetchTransportValidationPlan`, a pure evidence
checklist for turning a legacy beacon ref into a full `MessageEnvelope`
through a real transport. The current stack already has `BeaconRef`,
`BeaconFetchRequest`, planning, dry-run dispatch, a fake/offline fetch
adapter, and GATT diagnostics, but no physical transport has retrieved a
full envelope from a beacon ref and replay-normalized it as resolved.

The plan records one satisfied gate and six blocked gates:

- current GATT blocker recorded;
- candidate transport decision;
- standalone interop matrix;
- constrained fetch exchange;
- canonical replay resolution;
- negative failure matrix;
- release artifact linkage.

`LocalProjectReadiness`, completion audit, hardware validation gates, and
release criteria now list the plan as evidence while keeping full message
resolution, known-good transport, message delivery, trusted delivery, and
whole-project completion claims blocked. GATT remains disabled by default
on the current SM-T577U/SM-T390 pair because the standalone interop
harness still fails with Android status 133 before service discovery.
This milestone adds no transport behavior, no BLE connection, no GATT
success, no fetch dispatch, no routing, no ACKs, no retries, no
persistence behavior, no crypto, no background behavior, and no full
message resolution claim.

## M471-M475 whole-project prompt-to-artifact checklist

M471-M475 extends `LocalProjectCompletionAudit` with two explicit
completion-audit surfaces:

- `deliverables`, restating the ten whole-project success criteria as
  concrete outcomes;
- `prompt_artifact_checklist`, mapping each numbered objective item to
  current evidence, required artifacts, verification commands, missing
  evidence, and the claim-blocking status.

`LocalReleaseManifest` now embeds both fields in its completion audit
summary so generated release artifacts carry the same requirement-level
map as the pure audit module. This makes `mix test`, readiness JSON,
release manifests, advert gossip audits, and `git diff --check` useful
evidence without letting any of them act as proxy completion signals.

The checklist still reports full message resolution, known-good transport,
and multi-hop hardware proof as blocked, and product UX, persistence,
security/identity, routing, lifecycle, iOS parity, and release hardening
as partial. This milestone adds no transport behavior, no BLE hardware
proof, no routing, no persistence behavior, no crypto, no background
behavior, no iOS implementation, and no completion claim.

## M476-M480 multi-hop advert gossip hardware validation plan

M476-M480 adds `LocalAdvertGossipHardwareValidationPlan`, a pure evidence
checklist for the physical multi-hop advert-gossip blocker. This is
separate from replay simulation and separate from future production
routing: replay fixtures prove deterministic gossip policy, while the
current Android hardware proof covers only one-hop legacy beacon gossip.

The plan records six blocked gates:

- three-role device matrix;
- origin/relay/observer capture;
- replay-normalized fixture;
- TTL and suppression evidence;
- one-hop negative review;
- release artifact linkage.

`LocalHardwareValidationGates`, `LocalProjectReadiness`, completion
audit, release criteria, and the prompt-to-artifact checklist now list the
plan as evidence while keeping multi-hop hardware gossip, multi-hop
hardware delivery, routed delivery, guaranteed delivery, background
operation, and whole-project completion claims blocked. This milestone
adds no BLE behavior, no relay execution, no routing, no ACKs, no retries,
no persistence behavior, no crypto, no background behavior, and no
multi-hop hardware proof claim.

## M481-M485 Nearby Messages UX copy hardening

M481-M485 improves the existing Mob Nearby Messages surface without
changing transport behavior. `LocalInboxNativeSurface` now exposes a
stable `summary_line` with full/ref/gossip/stale counts and an
`empty_label` that follows the selected state filter. `Mob.Node.HomeScreen`
renders the summary above the filter controls and uses the state-specific
empty copy instead of a generic empty message.

`LocalProjectReadiness`, completion audit, and release criteria now list
the summary and empty-state copy as current product UX evidence while
keeping production UX blocked on on-device validation. This milestone adds
no scan/advertise behavior, no fetch, no routing, no persistence behavior,
no crypto, no background behavior, and no production UX claim.

## M486-M490 Local security fixture audit

M486-M490 adds `LocalSecurityFixtureAudit`, a read-only inventory of the
implementation-backed security fixtures already present around the local BLE
security boundaries. It maps fixture coverage to every
`LocalSecurityIdentityValidationPlan` gate:

- supplied peer/key binding;
- authorship proof matrix;
- in-memory replay guard matrix;
- operator trust policy matrix;
- canonical replay security matrix;
- beacon pointer-authentication matrix;
- crypto negative claim matrix;
- release artifact review.

The audit distinguishes `:covered_current_boundary`, `:partial`, and
`:blocked` fixture groups. Canonical replay and the crypto negative matrix
are covered for the current pure boundary, while enrollment, authorship
expansion, replay/trust lifecycle, beacon resolution, and release artifacts
remain partial or blocked. `LocalSecurityAcceptance`, project readiness,
completion audit, and release criteria now list this fixture inventory as
security evidence while keeping authenticated peer identity, authenticated
message, trusted message, replay protection, and trusted delivery claims
blocked.

This milestone adds no key enrollment flow, no trust persistence, no replay
state persistence, no fetch transport, no routing, no ACKs, no retries, no
encryption, no background behavior, and no trusted-message or
trusted-delivery claim.

## M491-M495 Local peer enrollment boundary

M491-M495 adds `LocalSecurityPeerEnrollment`, a pure enrollment boundary
for operator-supplied Ed25519 public key material. Enrollment records a
peer id, key id, public key, optional label, enrolled timestamp, and
untrusted enrollment state. It can be converted into the existing
`LocalSecurityPeerIdentityBinding` for authorship verification, but it does
not by itself create trusted peer identity or trusted-message wording.

The boundary explicitly rejects passive BLE observations as enrollment
evidence. BLE names, device ids, sender/message hashes, and beacon refs
cannot enroll identity. `LocalSecurityAcceptance`, `LocalSecurityFixtureAudit`,
project readiness, completion audit, and release criteria now list this
operator-supplied enrollment boundary as current security evidence while
keeping persistent trust lifecycle, key rotation, revocation, beacon
resolution, trusted message, and trusted delivery open.

This milestone adds no key discovery, no persistent trust store, no key
rotation, no revocation sync, no replay persistence, no fetch transport, no
routing, no ACKs, no retries, no encryption, no background behavior, and no
trusted-message or trusted-delivery claim.

## M496-M500 Local trust lifecycle validation

M496-M500 adds `LocalSecurityTrustLifecycleValidation`, an executable
pure validation matrix for supplied operator trust policy lifecycle
semantics. The matrix covers:

- a new key for the same peer starts `:unknown`;
- old-key trust does not transfer to a successor key;
- successor-key trust requires an explicit operator policy entry;
- blocked keys fail closed;
- revoked keys fail closed;
- passive BLE observations cannot rotate or enroll keys.

`LocalSecurityTrustLifecyclePlan` embeds this validation snapshot beside
the persistent lifecycle gates. `LocalSecurityAcceptance`, fixture audit,
project readiness, completion audit, and release criteria now list the
fail-closed lifecycle validation as current security evidence. The evidence
is intentionally scoped to supplied in-memory policy semantics; persistent
trust storage, production key rotation, revocation sync, replay persistence,
trusted message, and trusted delivery remain open.

This milestone adds no persistent key store, no production rotation UX, no
revocation sync, no replay persistence, no fetch transport, no routing, no
ACKs, no retries, no encryption, no background behavior, and no
trusted-delivery claim.

## M501-M505 Local replay lifecycle policy

M501-M505 adds `LocalSecurityReplayLifecyclePolicy` and
`LocalSecurityReplayLifecycleValidation` for the current replay-protection
boundary. The policy explicitly states that replay state is memory-only and
cleared on process restart. Durable replay state, restart-surviving replay
protection, background replay claims, and trusted delivery remain blocked.

The validation matrix proves the current behavior:

- duplicate proofs are rejected inside one in-memory replay state;
- old seen entries are pruned by the configured replay window;
- a fresh state after restart has no durable seen entries;
- expired envelopes are rejected;
- beacon refs remain outside the full-envelope replay guard.

`LocalSecurityTrustLifecyclePlan` embeds this replay lifecycle validation,
and security acceptance, fixture audit, readiness, completion audit, and
release criteria expose it as current evidence. This closes the ambiguity
around replay lifecycle defaults without adding storage or expanding trust
claims.

This milestone adds no durable replay store, no restart restore, no
background replay behavior, no fetch transport, no routing, no ACKs, no
retries, no encryption, and no trusted-delivery claim.

## M506-M510 Local security release evidence review

M506-M510 adds `LocalSecurityReleaseEvidenceReview`, a pure packaging
review contract for local security evidence. The review requires:

- readiness, release, and security manifest paths;
- at least one security attachment;
- coverage for every `LocalSecurityIdentityValidationPlan` gate;
- blocked claim callouts for authenticated peer identity, authenticated
  message, trusted message, trusted delivery, and fresh-message wording;
- explicit operator review.

The review can report a package as `:ready`, but that only means the
security evidence is attached and operator-reviewed. It does not close the
underlying security validation gates or permit authenticated/trusted
wording. `LocalSecurityAcceptance`, fixture audit, project readiness,
completion audit, and release criteria now list this review boundary as
current evidence while keeping trusted-message and trusted-delivery claims
blocked.

This milestone adds no file reading, no persistent trust store, no durable
replay state, no full-envelope fetch transport, no routing, no ACKs, no
retries, no encryption, no background behavior, and no trusted-message or
trusted-delivery claim.

## M511-M515 Local security evidence manifest

M511-M515 adds `LocalSecurityEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_security.evidence --json --out tmp/local-security-evidence.json
```

The manifest packages the current local security evidence into an
archiveable artifact:

- `LocalSecurityIdentityValidationPlan` gates;
- `LocalSecurityFixtureAudit` coverage;
- `LocalSecurityAcceptance` claim gates;
- replay and trust lifecycle validation snapshots;
- `LocalSecurityReleaseEvidenceReview` status and missing operator review;
- blocked authenticated, trusted-message, trusted-delivery, freshness,
  guaranteed-delivery, and routed-delivery claims.

`LocalReleaseManifest` now embeds this as `security_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`security_evidence_manifest` artifact. This makes the security package part
of the normal release archive path while keeping
`security_evidence_complete?` false until operator review is attached and
the underlying security gates close.

This milestone adds no trusted-message wording, no trusted-delivery wording,
no persistent trust store, no durable replay state, no full-envelope fetch
transport, no routing, no ACKs, no retries, no encryption, and no background
behavior.

## M516-M520 Nearby Messages UX evidence manifest

M516-M520 adds `LocalInboxUxEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_inbox.ux_evidence --json --out tmp/local-inbox-ux-evidence.json
```

The manifest packages a deterministic Nearby Messages fixture surface that
covers:

- full message rows;
- unresolved beacon refs;
- gossiped beacon refs;
- stale beacon refs;
- state filters, sort choices, warnings, and the open on-device validation
  plan.

`LocalReleaseManifest` now embeds this as `ux_evidence`, and
`LocalReleaseArtifactBundle` lists the generated `ux_evidence_manifest`
artifact. This gives release review a concrete UX evidence artifact while
keeping `production_ux_claim_allowed?` false until target-device
screenshots or operator notes satisfy `LocalInboxUxValidationPlan`.

This milestone adds no UI device automation, no production UX claim, no
delivery claim, no trusted-delivery claim, no routing, no persistence, no
fetch transport, no ACKs, no retries, no encryption, and no background
behavior.

## M521-M525 Local persistence evidence manifest

M521-M525 adds `LocalPersistenceEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_persistence.evidence --json --out tmp/local-persistence-evidence.json
```

The manifest packages the current local inbox persistence boundary into an
archiveable release artifact:

- memory-only default app lifecycle;
- opt-in durable local inbox snapshots;
- operator persistence controls;
- `LocalPersistenceAcceptance` gate status;
- `LocalPersistenceProductionLifecyclePlan` blocked gates;
- negative validation for default, background, delivery-record, full
  resolution, and raw-evidence overclaims.

`LocalReleaseManifest` now embeds this as `persistence_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`persistence_evidence_manifest` artifact. This records that durable
snapshots exist for policy-approved local read models while
`production_default_persistence_allowed?` remains false until product
decision, migration, cleanup, lifecycle writer, on-device restore, and
release-evidence gates close.

This milestone adds no default app persistence, no scheduled cleanup worker,
no background persistence, no delivery record, no full-message resolution,
no routing, no fetch transport, no ACKs, no retries, no encryption, and no
background behavior.

## M526-M530 Local routing evidence manifest

M526-M530 adds `LocalRoutingEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_routing.evidence --json --out tmp/local-routing-evidence.json
```

The manifest packages current routing-adjacent evidence into an archiveable
release artifact:

- local observation and advert-gossip policy;
- deterministic route-candidate table fixture;
- `LocalRoutingAcceptance` gate status;
- `LocalRoutingContract` and `LocalRoutingProofPlan` open requirements;
- `LocalRoutingHardwareValidationPlan` blocked hardware gates;
- `LocalRoutingNegativeValidation` cases that block route selection,
  forwarding, ACK/retry delivery, and one-hop-as-multi-hop overclaims.

`LocalReleaseManifest` now embeds this as `routing_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`routing_evidence_manifest` artifact. This records that MeshX can derive
observation-only route candidates while `route_selection_claim_allowed?`,
`forwarding_claim_allowed?`, `routed_delivery_claim_allowed?`, and
`multi_hop_hardware_claim_allowed?` remain false.

This milestone adds no production routing table, no route selection policy,
no forwarding service, no routed delivery, no ACKs, no retries, no multi-hop
hardware routing proof, no persistence behavior, no fetch transport, no
encryption, and no background behavior.

## M531-M535 Local lifecycle evidence manifest

M531-M535 adds `LocalLifecycleEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_lifecycle.evidence --json --out tmp/local-lifecycle-evidence.json
```

The manifest packages current lifecycle evidence into an archiveable release
artifact:

- `LocalTransportLifecycleProfile` foreground/manual support and unsupported
  background behavior;
- `LocalLifecyclePolicy` claim gates;
- `LocalLifecycleAcceptance` foreground/manual acceptance status;
- `LocalBackgroundLifecycleContract` and `LocalLifecycleProofPlan` open
  requirements;
- `LocalLifecycleHardwareValidationPlan` blocked device-specific gates;
- `LocalLifecycleNegativeValidation` cases that block foreground-as-background,
  Android/iOS background BLE, automatic restart, scheduled retry, and
  background gossip overclaims.

`LocalReleaseManifest` now embeds this as `lifecycle_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`lifecycle_evidence_manifest` artifact. This records that MeshX's current BLE
lifecycle is foreground/manual while Android foreground-service,
Android/iOS background BLE, restart, scheduled retry, background gossip, and
background delivery claims remain false.

This milestone adds no Android foreground service, no iOS background BLE, no
automatic restart, no scheduled retry, no background gossip, no delivery claim,
no routing, no fetch transport, no ACKs, no retries, no persistence behavior,
no encryption, and no native Android/iOS behavior.

## M536-M540 Local iOS parity evidence manifest

M536-M540 adds `LocalIOSParityEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_ios_parity.evidence --json --out tmp/local-ios-parity-evidence.json
```

The manifest packages current iOS parity evidence into an archiveable release
artifact:

- `LocalIOSParityPolicy` contract-only claim gates;
- `LocalIOSParityAcceptance` contract-only acceptance status;
- `LocalIOSParityContract` and `LocalIOSParityProofPlan` open requirements;
- `LocalIOSParityHardwareValidationPlan` blocked iOS-specific hardware gates;
- `LocalIOSParityNegativeValidation` cases that block bridge-shell,
  Android-evidence, missing-dispatcher, unproven-capability, and missing replay
  fixture overclaims.

`LocalReleaseManifest` now embeds this as `ios_parity_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`ios_parity_evidence_manifest` artifact. This now records partial iOS
foreground observe/responder-fetch hardware evidence while iOS gossip, direct
full-envelope advert, hardware replay fixture, background BLE, and parity
claims remain false.

This milestone adds no iOS scanner, no iOS advertiser, no iOS legacy beacon
dispatcher, no iOS full-envelope advert path, no iOS background BLE, no
hardware proof, no routing, no fetch transport, no ACKs, no retries, no
persistence behavior, no encryption, and no native iOS behavior.

## M541-M545 Local full-message resolution evidence manifest

M541-M545 adds `LocalFullMessageResolutionEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_full_resolution.evidence --json --out tmp/local-full-resolution-evidence.json
```

The manifest packages current full-message-resolution evidence into an
archiveable release artifact:

- `BeaconRef` pointer/reference parsing;
- `BeaconResolver` outcomes for `:already_known`, `:needs_fetch`, and
  `:unresolvable`;
- `BeaconFetchRequest` bounded fetch-intent contract;
- `BeaconFetchPlanner`, `BeaconFetchAttemptLedger`, and
  `BeaconFetchDryRunDispatcher` planning evidence;
- `BeaconFetchProtocol`, `EnvelopeCache`, and `BeaconFetchTransport.Fake`
  offline/fake exchange evidence;
- `LocalFetchTransportValidationPlan` blocked real-transport gates.

`LocalReleaseManifest` now embeds this as `full_resolution_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`full_message_resolution_evidence_manifest` artifact. This records that
beacon refs remain unresolved pointers until a real transport retrieves and
parses a full `MessageEnvelope`. The manifest keeps
`real_fetch_transport_validated?`, `full_message_resolution_claim_allowed?`,
`message_delivery_claim_allowed?`, and `trusted_message_claim_allowed?` false.

This milestone adds no real fetch transport, no GATT success claim, no BLE
connection, no full-message resolution claim, no delivery claim, no routing,
no ACKs, no retries, no persistence behavior, no encryption, and no background
behavior.

## M546-M550 Local multi-hop hardware evidence manifest

M546-M550 adds `LocalMultiHopHardwareEvidenceManifest` and the Mix task:

```bash
mix mob.node.local_multi_hop_hardware.evidence --json --out tmp/local-multi-hop-hardware-evidence.json
```

The manifest packages current multi-hop evidence into an archiveable release
artifact:

- advert gossip replay fixtures for line, partitioned, and triangle
  topologies;
- the advert gossip scenario audit command;
- the current one-hop SM-T577U to SM-T390 legacy beacon gossip scope;
- `LocalAdvertGossipHardwareValidationPlan` origin, relay, observer,
  replay-normalization, TTL/suppression, one-hop negative, and release gates.

`LocalReleaseManifest` now embeds this as `multi_hop_hardware_evidence`, and
`LocalReleaseArtifactBundle` lists the generated
`multi_hop_hardware_evidence_manifest` artifact. This records that replay
fixtures and two-device hardware logs remain useful but insufficient: physical
multi-hop requires three or more roles, or an equivalent controlled rig, tied
to the same `message_id_hash` and `sender_peer_hash`. The manifest keeps
`multi_hop_physical_proof_present?`,
`multi_hop_hardware_gossip_claim_allowed?`,
`routed_delivery_claim_allowed?`, `guaranteed_delivery_claim_allowed?`, and
`background_operation_claim_allowed?` false.

This milestone adds no relay execution, no routing, no forwarding service, no
routed delivery, no guaranteed delivery, no ACKs, no retries, no fetch
transport, no persistence behavior, no encryption, no background behavior, and
no new hardware proof.

## M551-M555 Local release artifact bundle task

M551-M555 adds a dedicated Mix task for the release-candidate artifact bundle:

```bash
mix mob.node.local_release.artifact_bundle --json --out tmp/local-release-artifact-bundle.json
```

The bundle already existed as `LocalReleaseArtifactBundle` and was embedded in
`LocalReleaseManifest`. This milestone makes it directly archiveable as its
own release-hardening artifact, listing generated manifests, embedded gates,
the advert gossip audit output, and the still-open operator-supplied hardware
log bundle and release notes.

`LocalReleaseManifest` now lists the task in `required_commands`, and the
`artifact_bundle_checklist` required artifact points to the new direct command
instead of requiring operators to extract the embedded bundle from the release
manifest. `LocalProjectReadiness`, `LocalProjectCompletionAudit`, and
`LocalReleaseCriteria` reference the task as current release-hardening
evidence while keeping release hardening partial until fresh hardware
attachments and operator wording review are supplied.

This milestone adds no hardware evidence, no release approval, no transport
behavior, no routing, no delivery claim, no trust claim, no background behavior,
no iOS parity, and no whole-project completion claim.

## M556-M560 Local release candidate review task

M556-M560 adds a dedicated Mix task for `LocalReleaseCandidateEvidenceReview`:

```bash
mix mob.node.local_release.candidate_review --input artifacts/local-ble/<run-id>/evidence.json --json --out tmp/local-release-candidate-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing manifest paths, hardware attachments, and operator wording. With
`--input`, it parses JSON operator metadata for readiness/release manifest
paths, advert gossip audit output, hardware attachment metadata, approved
"messages seen nearby" wording, blocked-claim callouts, and open hardware gate
callouts.

`LocalReleaseCandidateEvidenceReview` now accepts string-keyed JSON maps in
addition to in-memory atom-keyed maps, so the same pure review boundary can be
used from tests, Mix tasks, and archived operator files. `LocalReleaseManifest`
lists the task in `required_commands` and required artifacts, and project
readiness/completion/release criteria reference the task as current
release-hardening evidence while keeping release hardening partial until real
operator attachments are supplied and reviewed.

This milestone adds no hardware evidence, no release approval, no transport
behavior, no routing, no delivery claim, no trust claim, no background behavior,
no iOS parity, and no whole-project completion claim.

## M561-M565 Nearby Messages UX evidence review task

M561-M565 adds `LocalInboxUxEvidenceReview` and a dedicated Mix task:

```bash
mix mob.node.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json
```

Without `--input`, the task reviews an empty UX evidence package and reports
the missing target devices, state evidence, interaction evidence, blocked-claim
copy review, and visual-density review. With `--input`, it parses JSON
operator metadata for:

- target device model, OS/API, screen class, build, and evidence path;
- full message, unresolved ref, gossiped ref, and stale ref screenshots or
  notes;
- filter change, sort change, row selection, and detail panel evidence;
- approved nearby/observed wording and blocked delivery/trust/routing/background
  claim callouts;
- row truncation, wrapping, tap target, detail readability, and densest-fixture
  visual-density review.

`LocalInboxUxEvidenceManifest`, `LocalReleaseManifest`, and
`LocalReleaseArtifactBundle` now list the UX review task as an archiveable
product-UX artifact. `LocalProjectReadiness` and
`LocalProjectCompletionAudit` point the remaining product-UX work at this
review, while keeping production UX, delivery, trusted delivery, routing, and
background claims blocked unless real on-device evidence is attached and
reviewed.

This milestone adds no screenshots by itself, no UI rendering proof, no
transport behavior, no delivery claim, no trust claim, no routing, no
persistence behavior, no background behavior, and no whole-project completion
claim.

## M566-M570 Production persistence evidence review task

M566-M570 adds `LocalPersistenceProductionEvidenceReview` and a dedicated Mix
task:

```bash
mix mob.node.local_persistence.production_review --input artifacts/local-ble/<run-id>/persistence/evidence.json --json --out tmp/local-persistence-production-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing production-default persistence lifecycle metadata. With `--input`, it
parses JSON operator metadata for every `LocalPersistenceProductionLifecyclePlan`
gate:

- default lifecycle product decision;
- durable snapshot schema migration policy;
- scheduled cleanup worker or lifecycle hook evidence;
- background-safe writer evidence;
- on-device restore fixture evidence;
- release artifact evidence.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for delivery records, trusted-message delivery, background
persistence, and full-message resolution. `LocalPersistenceEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the
production persistence review as an archiveable operator artifact.
`LocalProjectReadiness` and `LocalProjectCompletionAudit` point the remaining
persistence work at this review while keeping the current default mode
`memory_only`.

This milestone adds no default app persistence, no migration runner, no
scheduled cleanup worker, no background writer, no on-device restore proof, no
delivery record, no full-message resolution, no routing, no trust claim, and no
whole-project completion claim.

## M571-M575 Production routing evidence review task

M571-M575 adds `LocalRoutingProductionEvidenceReview` and a dedicated Mix task:

```bash
mix mob.node.local_routing.production_review --input artifacts/local-ble/<run-id>/routing/evidence.json --json --out tmp/local-routing-production-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing production routing evidence metadata. With `--input`, it parses JSON
operator metadata for every `LocalRoutingHardwareValidationPlan` gate:

- route table state model;
- deterministic route selection;
- forwarding service boundary;
- delivery semantics policy;
- multi-hop hardware rig;
- TTL, loop, and suppression evidence;
- release artifact evidence;
- negative claim review.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for route table, route selection, live forwarding, routed delivery,
guaranteed delivery, ACK-backed delivery, retry-backed delivery, and multi-hop
hardware routing. `LocalRoutingEvidenceManifest`, `LocalReleaseManifest`, and
`LocalReleaseArtifactBundle` now list the production routing review as an
archiveable operator artifact. `LocalProjectReadiness` and
`LocalProjectCompletionAudit` point the remaining routing work at this review
while keeping the current mode `advert_only_non_routing`.

This milestone adds no production routing table, no route selection policy, no
forwarding service, no routed delivery, no ACKs, no retries, no multi-hop
hardware proof, no background behavior, no trust claim, and no whole-project
completion claim.

## M576-M580 Lifecycle hardware evidence review task

M576-M580 adds `LocalLifecycleHardwareEvidenceReview` and a dedicated Mix task:

```bash
mix mob.node.local_lifecycle.hardware_review --input artifacts/local-ble/<run-id>/lifecycle/evidence.json --json --out tmp/local-lifecycle-hardware-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing mobile lifecycle hardware metadata. With `--input`, it parses JSON
operator metadata for every `LocalLifecycleHardwareValidationPlan` gate:

- target device matrix;
- Android foreground-service backgrounding;
- Android background BLE policy;
- iOS background BLE policy;
- restart and cancellation;
- scheduled retry bounds;
- background gossip limits;
- negative claim review.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for Android foreground service BLE, Android/iOS background scan and
advertise, automatic restart, scheduled retry, background gossip, and
background delivery. `LocalLifecycleEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the
lifecycle hardware review as an archiveable operator artifact.
`LocalProjectReadiness` and `LocalProjectCompletionAudit` point the remaining
lifecycle work at this review while keeping `foreground_manual` as the only
validated lifecycle mode.

This milestone adds no Android foreground service, no iOS background BLE, no
automatic restart, no scheduled retry, no background gossip, no background
delivery, no routing, no persistence behavior, no trust claim, and no
whole-project completion claim.

## M581-M585 iOS parity hardware evidence review task

M581-M585 adds `LocalIOSParityHardwareEvidenceReview` and a dedicated Mix task:

```bash
mix mob.node.local_ios_parity.hardware_review --input artifacts/local-ble/<run-id>/ios/evidence.json --json --out tmp/local-ios-parity-hardware-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing iOS advert-only hardware metadata. With `--input`, it parses JSON
operator metadata for every `LocalIOSParityHardwareValidationPlan` gate:

- target iOS device matrix;
- canonical ingress fixture;
- legacy beacon observe hardware;
- legacy beacon gossip hardware;
- full-envelope capability probe;
- hardware replay fixture;
- iOS background BLE boundary;
- negative claim review.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for iOS hardware participation, advert-only validation, legacy beacon
observe/gossip, full-envelope advert, full-message observation, hardware replay
fixture, background BLE, background scan/advertise, and parity claims.
`LocalIOSParityEvidenceManifest`, `LocalReleaseManifest`, and
`LocalReleaseArtifactBundle` now list the iOS hardware review as an
archiveable operator artifact. `LocalProjectReadiness` and
`LocalProjectCompletionAudit` point the remaining iOS parity work at this
review while keeping `contract_only` as the current iOS mode.

This milestone adds no iOS scanner, no iOS advertiser, no iOS legacy beacon
dispatcher, no iOS full-envelope advert path, no iOS background BLE, no
hardware proof, no routing, no fetch transport, no ACKs, no retries, no
persistence behavior, no encryption, no trust claim, and no native iOS
behavior.

## M586-M590 Security release evidence review task

M586-M590 adds a dedicated Mix task for `LocalSecurityReleaseEvidenceReview`:

```bash
mix mob.node.local_security.release_review --input artifacts/local-ble/<run-id>/security/evidence.json --json --out tmp/local-security-release-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing security release metadata. With `--input`, it parses JSON operator
metadata for:

- readiness, release, and security manifest paths;
- security attachments;
- `LocalSecurityIdentityValidationPlan` gate coverage;
- blocked authenticated/trusted/fresh-message claim callouts;
- explicit operator review.

`LocalSecurityReleaseEvidenceReview` now accepts string-keyed JSON metadata so
task input follows the same operator-supplied artifact path as UX,
persistence, routing, lifecycle, and iOS parity reviews. `LocalSecurityEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the security
release review as an archiveable operator artifact.

This milestone adds no key persistence, no trust persistence, no replay-state
persistence, no full-envelope fetch, no beacon authentication claim, no
authenticated peer claim, no trusted-message claim, no trusted-delivery claim,
no routing, no ACKs, no retries, and no crypto behavior.

## M591-M595 Full-resolution transport evidence review task

M591-M595 adds `LocalFullMessageResolutionEvidenceReview` and a dedicated Mix
task:

```bash
mix mob.node.local_full_resolution.transport_review --input artifacts/local-ble/<run-id>/full-resolution/evidence.json --json --out tmp/local-full-resolution-transport-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing full-resolution transport metadata. With `--input`, it parses JSON
operator metadata for every `LocalFetchTransportValidationPlan` gate:

- current GATT blocker record;
- candidate transport decision;
- standalone interop matrix;
- constrained fetch exchange;
- canonical replay resolution;
- negative failure matrix;
- release artifact linkage.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for full resolution, known-good transport, GATT fetch success,
message delivery, trusted/routed/background delivery, fake success, and
whole-project completion. `LocalFullMessageResolutionEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the
transport review as an archiveable operator artifact.

This milestone adds no real fetch transport, no GATT success claim, no
full-message resolution claim, no message delivery claim, no trusted-message
claim, no routing, no background behavior, no persistence behavior, no ACKs,
no retries, no fragmentation, and no crypto behavior.

## M596-M600 Multi-hop hardware evidence review task

M596-M600 adds `LocalMultiHopHardwareEvidenceReview` and a dedicated Mix task:

```bash
mix mob.node.local_multi_hop_hardware.review --input artifacts/local-ble/<run-id>/multi-hop/evidence.json --json --out tmp/local-multi-hop-hardware-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing physical multi-hop hardware metadata. With `--input`, it parses JSON
operator metadata for every `LocalAdvertGossipHardwareValidationPlan` gate:

- three-role device matrix;
- origin, relay, and observer capture;
- replay-normalized fixture;
- TTL and suppression evidence;
- one-hop negative review;
- release artifact linkage.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for multi-hop hardware gossip/delivery, routed delivery, guaranteed
delivery, trusted delivery, background operation, and whole-project
completion. `LocalMultiHopHardwareEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the
multi-hop hardware review as an archiveable operator artifact.

This milestone adds no radio relay execution, no scanner/advertiser changes,
no physical multi-hop proof, no routed delivery, no guaranteed delivery, no
trusted delivery, no background behavior, no persistence behavior, no ACKs, no
retries, and no crypto behavior.

## M601-M605 Known-good transport evidence review task

M601-M605 adds `LocalKnownGoodTransportEvidenceReview` and a dedicated Mix
task:

```bash
mix mob.node.local_known_good_transport.review --input artifacts/local-ble/<run-id>/transport/evidence.json --json --out tmp/local-known-good-transport-review.json
```

Without `--input`, the task reviews an empty evidence package and reports the
missing known-good transport metadata. With `--input`, it parses JSON operator
metadata for the prerequisite gates needed before any constrained fetch path can
be described as validated:

- candidate transport decision;
- standalone interop matrix;
- tiny read/write probe;
- known-bad pair separation;
- constrained fetch prerequisite;
- release artifact linkage.

Each gate requires an artifact path, summary, test command, and blocked-claim
callouts for known-good transport, transport validation, GATT fetch success,
full-message resolution, message delivery, trusted delivery, routed delivery,
and whole-project completion. The review embeds the current
`LocalFetchTransportValidationPlan` and `LocalHardwareValidationGates`
snapshots, keeps SM-T577U/SM-T390 Android status 133 as known-bad evidence, and
does not enable any fetch or delivery claims.

`LocalFullMessageResolutionEvidenceManifest`, `LocalReleaseManifest`,
`LocalReleaseArtifactBundle`, `LocalProjectReadiness`, and
`LocalProjectCompletionAudit` now list the known-good transport review as an
archiveable operator artifact for the transport blocker.

This milestone adds no BLE connections, no GATT success, no full fetch, no
full-message resolution, no message delivery, no trusted delivery, no routing,
no background behavior, no persistence behavior, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M606-M610 iOS foreground legacy beacon observe path

M606-M610 adds the smallest iOS-side advert-only observation implementation for
legacy beacon refs. The foreground CoreBluetooth scanner now inspects
manufacturer data for MeshX's 22-byte legacy beacon payload:

```text
MB | beacon_version | envelope_version | payload_kind | flags |
8-byte message_id_hash | 8-byte sender_peer_id_hash
```

When that payload is observed, `MobBLEBridge.swift` emits a v1
`received_message_beacon` wire map through `mob_ble_nif.m`, preserving the
same canonical ingress path used by Android and replay. The emitted event is a
beacon/ref event only; it is not a full `ReceivedMessage` and it does not
resolve the beacon into an envelope.

`LocalIOSParityEvidenceManifest`, `LocalPlatformParity`, and
`LocalProjectReadiness` now distinguish this foreground implementation evidence
from iOS hardware parity. iOS legacy beacon observation remains
`implemented_unvalidated`: hardware logs, replay-normalized iOS fixtures, and
operator review are still required before any iOS participation wording can be
accepted.

This milestone adds no iOS hardware proof, no iOS legacy beacon gossip
dispatcher, no full-envelope iOS advert, no background BLE behavior, no fetch
transport, no routing, no delivery, no persistence behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M611-M615 Swift legacy beacon parser fixtures

M611-M615 adds native Swift package coverage for the iOS foreground legacy
beacon observe path introduced in M606-M610. `MessageAdvertisementTests` now
pins the 22-byte MeshX beacon reference payload layout and verifies that the
Swift parser:

- accepts only MeshX company identifier `0xFFFF`;
- extracts `beacon_version`, `envelope_version`, `payload_kind`,
  `message_id_hash`, and `sender_peer_id_hash`;
- preserves raw beacon payload, manufacturer data, and reconstructed AD
  structure bytes;
- rejects wrong-company, truncated, and wrong-magic payloads.

Validation:

```bash
cd mob_node && xcrun swift test --filter MessageAdvertisementTests
cd mob_node && xcrun swift test
```

The full Swift package test suite now runs 25 tests. This milestone is parser
fixture hardening only: it adds no iOS hardware proof, no iOS beacon gossip, no
full-envelope advert behavior, no background behavior, no fetch transport, no
routing, no delivery, no persistence behavior, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M616-M620 iOS advert carrier decision ledger

M616-M620 adds `LocalIOSAdvertCarrierDecision`, a pure decision ledger for the
iOS advertisement carrier boundary. It now records the foreground
manufacturer-data legacy-beacon observe path as hardware-validated by the
2026-05-15 iPhone 13 / SM-T577U capture and foreground iOS MB beacon emission
as implemented but cross-radio unvalidated, while iOS legacy beacon gossip and
direct full-MX extended advertising remain blocked on tested iOS hardware.

The ledger distinguishes:

- `manufacturer_data_legacy_beacon_observe` as `hardware_validated`;
- `full_mx_extended_advert_observe` as `phy_blocked`;
- `manufacturer_data_legacy_beacon_emit` as `implemented_unvalidated`;
- `service_uuid_identity_advert` as `insufficient_for_beacon_ref`;
- `service_data_beacon_ref` as a future `candidate_unvalidated`; and
- `local_name_encoded_beacon_ref` as `rejected`.

`LocalIOSParityEvidenceManifest` now embeds this carrier decision so release
and readiness artifacts can show that iOS observe, foreground emit, and
autonomous gossip are separate claims. The current iOS emit carrier is
`:manufacturer_data_legacy_beacon_emit`, but iOS-origin cross-radio gossip proof
is still missing. iOS legacy beacon gossip claims remain blocked, direct
full-MX extended-advert receive remains blocked, and broad iOS parity claims
remain blocked until emission, full-envelope, background, and replay-normalized
evidence gates are satisfied.

This milestone adds no iOS beacon gossip dispatcher, no direct full-envelope
advert behavior, no background BLE behavior, no routing, no delivery, no
persistence behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M621-M625 whole-project blocker matrix

M621-M625 adds `LocalProjectCompletionBlockerMatrix`, a pure planning and
release-audit snapshot that classifies every still-open whole-project objective
by the kind of work that can unblock it:

- hardware evidence;
- transport selection;
- product decision;
- implementation;
- security design; and
- release evidence.

The matrix records which objectives cannot close without new device evidence:
full message resolution, known-good transport validation, physical multi-hop
hardware proof, and iOS parity. It also records which objectives can still
progress without new hardware evidence: product UX, persistence,
security/identity, routing, background lifecycle, and release hardening.

`LocalProjectCompletionAudit` and `LocalReleaseManifest` now include this
blocker matrix so release artifacts can distinguish true hardware blockers from
work that is waiting on product decisions, implementation, or per-candidate
evidence. Completion remains false: `completion_claim_allowed?` is still
`false`, and the readiness audit still reports open blocked and partial items.

This milestone adds no BLE behavior, no transport selection, no hardware proof,
no full-message resolution, no routing, no background behavior, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M626-M630 release blocker matrix artifact

M626-M630 promotes the whole-project blocker matrix from a completion audit
field to an explicit release-bundle artifact. `LocalReleaseArtifactBundle` now
includes `completion_blocker_matrix`, which is generated at:

```text
tmp/local-completion-blocker-matrix.json
```

`LocalReleaseManifest.required_artifacts` also lists the blocker matrix so
release-candidate packaging can point directly at the classification of
hardware-blocked, product-decision, implementation, security-design, transport,
and release-evidence work.

This is a packaging/evidence milestone only. It adds no BLE behavior, no
transport selection, no hardware proof, no full-message resolution, no routing,
no background behavior, no persistence behavior, no trusted-message behavior,
no ACKs, no retries, no fragmentation, and no crypto behavior.

## M631-M635 release candidate blocker matrix review

M631-M635 tightens `LocalReleaseCandidateEvidenceReview` so operator-supplied
release-candidate metadata must include `completion_blocker_matrix_path`. The
expected value points at the generated blocker matrix artifact:

```text
tmp/local-completion-blocker-matrix.json
```

This makes the blocker classification part of the reviewed release-candidate
evidence package, not only a listed bundle item. `docs/local_ble_release_artifact_bundle.md`
now also names the blocker matrix in the required release artifacts.

This milestone adds no BLE behavior, no transport selection, no hardware proof,
no full-message resolution, no routing, no background behavior, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M636-M640 completion blocker matrix task

M636-M640 adds a standalone Mix task for the blocker matrix:

```bash
mix mob.node.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json
```

The task emits `LocalProjectCompletionBlockerMatrix` directly so release
artifacts can archive the hardware, transport, product, implementation,
security-design, and release-evidence blocker classification without extracting
it from the larger release manifest. `LocalReleaseArtifactBundle` now treats
`completion_blocker_matrix` as a generated artifact, and
`LocalReleaseCandidateEvidenceReview` expects
`completion_blocker_matrix_path` to point to the generated JSON file.

This milestone adds no BLE behavior, no transport selection, no hardware proof,
no full-message resolution, no routing, no background behavior, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M641-M645 release manifest blocker matrix command

M641-M645 adds the standalone blocker matrix task to
`LocalReleaseManifest.required_commands`:

```bash
mix mob.node.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json
```

This keeps the release manifest command list aligned with the artifact bundle
and release-candidate review contract. It does not change any readiness status
or completion gate.

This milestone adds no BLE behavior, no transport selection, no hardware proof,
no full-message resolution, no routing, no background behavior, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M646-M650 CI release blocker matrix artifact

M646-M650 wires the standalone blocker matrix artifact into the release CI
step and human release checklist. The `Generate mobile local release manifests`
workflow step now emits:

```bash
mix mob.node.local_completion.blocker_matrix --json --out tmp/ci-local-completion-blocker-matrix.json
```

and asserts that `completion_claim_allowed?` remains false. `docs/RELEASE.md`
now lists the same blocker matrix artifact beside the readiness and release
manifest outputs for advert-only local release candidates.

This milestone adds no BLE behavior, no transport selection, no hardware proof,
no full-message resolution, no routing, no background behavior, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M651-M655 current GATT interop blocker rerun

M651-M655 archives a fresh May 13, 2026 standalone GATT interop rerun for
the current SM-T577U / SM-T390 hardware pair:

```text
artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/
```

The debug APK was rebuilt and installed on both devices before the rerun.
Both directions still fail before service discovery:

- SM-T577U advertiser -> SM-T390 requester: `gatt_status=133`,
  `gatt_reason="android_gatt_error"`.
- SM-T390 advertiser -> SM-T577U requester: `gatt_status=133`,
  `gatt_reason="android_gatt_error"`.

The rerun keeps the M66 known-good transport gate blocked for this hardware
pair. It does not change the advert-only validated mode, does not enable
GATT fetch, and does not claim full-message resolution from beacon refs.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-message behavior, no ACKs, no retries,
no fragmentation, and no crypto behavior.

## M656-M660 readiness evidence refresh

M656-M660 surfaces the May 13 standalone GATT blocker archive in the
machine-readable local readiness data and release artifact bundle docs:

```text
artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/
```

`LocalProjectReadiness` now records that the current SM-T577U / SM-T390
standalone interop rerun still fails with Android status 133 before service
discovery in both directions. The release artifact bundle doc distinguishes
the May 12 advert-only evidence bundle from the May 13 GATT blocker refresh.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-message behavior, no ACKs, no retries,
no fragmentation, and no crypto behavior.

## M661-M665 release bundle known-bad GATT archive

M661-M665 tightens the release artifact bundle checklist so the current
known-bad SM-T577U / SM-T390 standalone GATT archive remains attached or
linked during release review:

```text
artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/
```

The known-good transport review and hardware log bundle criteria now call out
that archive explicitly. This preserves the blocker evidence across release
candidates without turning the blocker into a transport success claim.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-message behavior, no ACKs, no retries,
no fragmentation, and no crypto behavior.

## M666-M670 release CI artifact bundle command

M666-M670 adds the standalone release artifact bundle command to the CI
release-manifest generation step and human release checklist:

```bash
mix mob.node.local_release.artifact_bundle --json --out tmp/ci-local-release-artifact-bundle.json
```

CI now decodes the generated bundle and asserts
`release_candidate_complete? == false`, keeping release-candidate completion
open until operator-supplied evidence is reviewed. `docs/RELEASE.md` now asks
operators to archive `tmp/local-release-artifact-bundle.json` beside the
readiness, blocker matrix, and release manifest outputs.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-message behavior, no ACKs, no retries,
no fragmentation, and no crypto behavior.

## M671-M675 security evidence command gates

M671-M675 adds explicit security test commands to
`LocalSecurityEvidenceManifest.required_commands` for:

```bash
mix test apps/mob_node/test/mob_node/ble/local_security_authorship_proof_test.exs
mix test apps/mob_node/test/mob_node/ble/local_security_canonical_replay_decision_test.exs
mix test apps/mob_node/test/mob_node/ble/local_security_fixture_audit_test.exs
```

This makes the release security manifest point directly at the full-envelope
authorship proof fixture, the canonical replay trusted-message decision fixture,
and the fixture inventory that represents every security validation plan gate.
The manifest still keeps authenticated, trusted, fresh-message, routed,
guaranteed, and trusted-delivery claims blocked.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-delivery behavior, no ACKs, no retries,
no fragmentation, and no crypto persistence behavior.

## M676-M680 security canonical replay plan reconciliation

M676-M680 reconciles the security validation plan with the implemented
authorship and canonical replay fixtures. `LocalSecurityIdentityValidationPlan`
no longer lists positive full-envelope authorship or positive canonical replay
trusted-message fixtures as missing. `LocalSecurityAuthorshipProofTest` covers
positive Ed25519 authorship plus tamper, signer mismatch, malformed signature,
and hash-only beacon-ref negatives. `LocalSecurityCanonicalReplayDecisionTest`
covers positive supplied proof/binding/replay/trust input plus mismatch,
duplicate, blocked-policy, and beacon-only negatives.

The gate remains blocked for release evidence and trusted-delivery wording.
The implemented decision is still a local trusted-message decision only; it is
not delivery, routing, beacon resolution, or persistent trust.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-delivery behavior, no ACKs, no retries,
no fragmentation, and no crypto persistence behavior.

## M681-M685 security lifecycle plan reconciliation

M681-M685 reconciles the security validation plan with the implemented
memory-only replay lifecycle and supplied trust lifecycle validations.
`LocalSecurityIdentityValidationPlan` no longer lists duplicate/expired/pruned/
restart replay fixtures or trust rotation/revocation fixtures as missing,
because `LocalSecurityReplayLifecycleValidationTest` and
`LocalSecurityTrustLifecycleValidationTest` already cover those current
boundaries.

The replay gate remains blocked on a durable replay-state product decision if
restart-surviving freshness is required. The trust gate remains blocked on a
durable trust lifecycle implementation or explicit non-durable product
decision. Both remain local security evidence only and do not enable trusted
delivery.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-delivery behavior, no ACKs, no retries,
no fragmentation, and no crypto persistence behavior.

## M686-M690 persistence evidence command gates

M686-M690 adds direct opt-in persistence test commands to
`LocalPersistenceEvidenceManifest.required_commands` for:

```bash
mix test apps/mob_node/test/mob_node/ble/local_inbox_store_test.exs
mix test apps/mob_node/test/mob_node/ble/local_inbox_durable_snapshot_test.exs
```

This makes the persistence evidence manifest point directly at durable snapshot
save/load/list/prune behavior and read-model restore for full messages,
unresolved refs, gossiped refs, and stale refs. The manifest still keeps
default app persistence, background persistence, delivery-record, full-message
resolution, and trusted-message-delivery claims blocked.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no default persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M691-M695 UX evidence command gates

M691-M695 adds direct Nearby Messages read-model and presentation command gates
to `LocalInboxUxEvidenceManifest.required_commands` for query, product surface,
presenter, state copy, resolution, and action summary tests.

This makes the UX evidence manifest point directly at the pure coverage for
full messages, unresolved refs, gossiped refs, stale refs, filtering, sorting,
details, state copy, resolution state, and blocked next actions. The manifest
still keeps production UX, delivery, trusted delivery, routing, and background
claims blocked until target-device screenshots or operator notes pass review.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no routing, no background behavior,
no persistence behavior, no trusted-message behavior, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M696-M700 routing evidence command gates

M696-M700 adds direct routing boundary command gates to
`LocalRoutingEvidenceManifest.required_commands` for contract, policy,
acceptance, proof-plan, route-candidate table, hardware validation, negative
validation, production evidence review, the manifest itself, and the routing
evidence/review mix tasks.

This makes the routing evidence manifest point directly at the pure coverage
that keeps current route candidates as observation-only read models. The
manifest still keeps route-table availability, route selection, forwarding,
routed delivery, guaranteed delivery, ACK/retry delivery, and multi-hop
hardware routing claims blocked until production routing and hardware evidence
pass review.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no live routing, no forwarding, no
background behavior, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M701-M705 lifecycle evidence command gates

M701-M705 adds direct foreground/manual lifecycle command gates to
`LocalLifecycleEvidenceManifest.required_commands` for the background lifecycle
contract, foreground/manual profile, lifecycle policy, acceptance, proof-plan,
hardware validation, hardware evidence review, negative validation, the
manifest itself, and the lifecycle evidence/review mix tasks.

This makes the lifecycle evidence manifest point directly at the pure coverage
that keeps the current mode foreground/manual only. The manifest still keeps
Android foreground-service BLE, Android/iOS background scan/advertise,
automatic restart, scheduled retry, retry-backed delivery, background gossip,
background forwarding, background delivery, and guaranteed delivery claims
blocked until device-specific hardware evidence passes review.

This milestone adds no BLE behavior, no transport selection, no hardware
success claim, no full-message resolution, no live routing, no forwarding, no
background service, no restart loop, no scheduled retry, no persistence
behavior, no trusted-message behavior, no ACKs, no retries, no fragmentation,
and no crypto behavior.

## M706-M710 iOS parity evidence command gates

M706-M710 adds direct iOS parity command gates to
`LocalIOSParityEvidenceManifest.required_commands` for carrier decision,
acceptance, contract, policy, proof-plan, hardware validation, hardware
evidence review, negative validation, the manifest itself, and the iOS parity
evidence/review mix tasks.

This makes the iOS parity evidence manifest point directly at the pure coverage
that keeps iOS in contract-only/foreground-observe-unvalidated mode. The
manifest still keeps iOS hardware participation, iOS advert-only validation,
iOS legacy beacon observe, iOS legacy beacon gossip, iOS full-envelope advert,
iOS hardware replay fixture, iOS background BLE, and iOS parity claims blocked
until iOS-specific hardware evidence passes review.

This milestone adds no BLE behavior, no iOS hardware success claim, no iOS
beacon emission carrier, no full-message resolution, no live routing, no
forwarding, no background service, no persistence behavior, no trusted-message
behavior, no ACKs, no retries, no fragmentation, and no crypto behavior.

## M711-M715 full-resolution evidence command gates

M711-M715 adds direct full-message resolution command gates to
`LocalFullMessageResolutionEvidenceManifest.required_commands` for beacon
resolver, fetch request, fetch planning, fake/offline fetch transport, real
fetch transport validation plan, full-resolution evidence manifest/review,
known-good transport review, and the full-resolution/known-good transport mix
tasks.

This makes the full-resolution evidence manifest point directly at the pure
coverage for BeaconRef -> BeaconFetchRequest -> planned/fake fetch behavior
while preserving the real transport blocker. The manifest still keeps full
message resolution, known-good transport, GATT fetch success, message delivery,
trusted delivery, routed delivery, background delivery, and whole-project
completion claims blocked until real hardware transport evidence passes review.

This milestone adds no BLE behavior, no new transport selection, no hardware
success claim, no full-message resolution, no GATT enablement, no live routing,
no forwarding, no background service, no persistence behavior, no trusted
message behavior, no ACKs, no retries, no fragmentation, and no crypto behavior.

## M716-M720 multi-hop hardware evidence command gates

M716-M720 adds direct physical multi-hop evidence command gates to
`LocalMultiHopHardwareEvidenceManifest.required_commands` for the advert gossip
scenario audit, multi-hop hardware validation plan, current hardware validation
gates, multi-hop evidence manifest/review, and the multi-hop evidence/review
mix tasks.

This makes the multi-hop hardware evidence manifest point directly at the pure
coverage that keeps replay topology proof separate from physical origin/relay/
observer proof. The manifest still keeps multi-hop hardware gossip, multi-hop
hardware delivery, routed delivery, guaranteed delivery, trusted delivery,
background operation, and whole-project completion claims blocked until three
physical roles or an equivalent controlled rig pass review.

This milestone adds no BLE behavior, no relay implementation, no routing, no
hardware success claim, no full-message resolution, no background service, no
persistence behavior, no trusted-message behavior, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M721-M725 release artifact bundle command gates

M721-M725 exposes `LocalReleaseArtifactBundle.required_commands/0` and embeds
that list in the bundle snapshot. The list is derived from every artifact source
that is a `mix` command, including readiness, release manifest, blocker matrix,
full-resolution, known-good transport, UX, lifecycle, multi-hop, iOS parity,
persistence, routing, security, and advert gossip audit.

This makes the release bundle command surface auditable without scraping each
artifact entry. Operator-supplied files remain open artifacts, and the bundle
still keeps release-candidate completion false until hardware logs, review
metadata, and release notes satisfy their gates.

This milestone adds no BLE behavior, no hardware success claim, no release
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M726-M730 release CI command-gate assertion

M726-M730 updates CI's local release manifest generation check so the generated
release artifact bundle must expose `required_commands` and include the release
manifest command. This keeps the release bundle's command-gate surface from
regressing while still asserting that release-candidate completion remains
false.

This milestone adds no BLE behavior, no hardware success claim, no release
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M731-M735 release checklist command-gate note

M731-M735 updates `docs/RELEASE.md` so release operators explicitly review
`tmp/local-release-artifact-bundle.json` for `required_commands`. The release
boundary text now records that the artifact bundle names generated files,
embedded sections, hardware attachments, blocked claims, and command gates.

This milestone adds no BLE behavior, no hardware success claim, no release
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M736-M740 completion audit command gates

M736-M740 expands `LocalProjectCompletionAudit.required_commands` so the
whole-project completion gate directly names every evidence and review command:
readiness, blocker matrix, full resolution, known-good transport, UX,
persistence, security, routing, lifecycle, iOS parity, multi-hop hardware,
release artifact bundle, release candidate review, release manifest, advert
gossip audit, format, and diff checks.

This keeps the top-level completion audit aligned with the per-area manifests
without changing any runtime behavior. Completion remains false while any
blocked or partial objective item remains open.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M741-M745 standalone completion audit task

M741-M745 adds `mix mob.node.local_completion.audit` as a standalone
whole-project completion audit artifact. The task supports `--allow-open`,
`--json`, and `--out`, exits nonzero by default while completion remains
blocked, and emits the same prompt-to-artifact checklist used by the embedded
release manifest completion audit.

The release manifest, release artifact bundle, CI release manifest generation
step, and release checklist now include
`tmp/local-completion-audit.json`. This gives operators a direct completion
audit artifact alongside readiness, blocker matrix, release manifest, and
artifact bundle outputs.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M746-M750 release artifact checklist completion audit linkage

M746-M750 updates the human release artifact checklist so it names
`tmp/local-completion-audit.json` as a required generated artifact alongside
the readiness audit, blocker matrix, release manifest, advert gossip audit,
and release artifact bundle JSON.

The checklist now calls out the standalone completion audit as the top-level
claim gate that must remain archived even when an advert-only release candidate
is allowed. It also instructs operators to review
`tmp/local-release-artifact-bundle.json` for its generated
`required_commands` list so readiness, completion, evidence, review, format,
and diff gates stay visible.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M751-M755 Nearby Messages UX target-device review hardening

M751-M755 tightens `LocalInboxUxEvidenceReview` so operator-supplied state and
interaction evidence must reference a declared target device from the UX
target-device matrix. Evidence rows with unknown `target_device_id` values now
keep the review open instead of satisfying the on-device UX gate.

This keeps Nearby Messages production UX evidence tied to concrete device
metadata and build identifiers. The review still does not inspect screenshot
pixels, drive devices, or turn UX evidence into delivery, routing, trust,
background, persistence, or completion evidence.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M756-M760 production persistence review gate-specific blockers

M756-M760 tightens `LocalPersistenceProductionEvidenceReview` so ready
production-default persistence metadata must call out the blocked claims for
each `LocalPersistenceProductionLifecyclePlan` gate, not only the shared
release-level blocked claims. Schema migration evidence must call out unsafe
upgrade and silent-loss risks, cleanup evidence must call out storage-growth
and background-persistence risks, and each other gate carries its own plan
blockers forward into review.

This keeps default persistence promotion tied to the actual lifecycle plan
risks while preserving the current memory-only default and opt-in durable
snapshot boundary.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M761-M765 security release review gate-specific blockers

M761-M765 tightens `LocalSecurityReleaseEvidenceReview` so operator-reviewed
security attachments must call out the blocked claims for every
`LocalSecurityIdentityValidationPlan` gate they claim to cover. A generic list
of authenticated/trusted/fresh-message blockers is no longer enough for a
ready package; peer enrollment evidence must call out trusted peer identity,
beacon-authentication evidence must call out trusted beacon refs, release
artifact evidence must call out guaranteed and routed delivery, and so on.

The review now exposes `required_gate_blocked_claims/0` for tests and task
fixtures, keeping the release package aligned with the validation plan while
still leaving authenticated, trusted-message, trusted-delivery, persistence,
routing, and completion claims blocked.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M766-M770 known-good transport review gate-specific blockers

M766-M770 tightens `LocalKnownGoodTransportEvidenceReview` so ready metadata
must include gate-specific transport blocked-claim callouts in addition to the
shared blocked claims. Candidate transport evidence must call out unvalidated
transport selection, standalone interop evidence must call out single-direction
interop, tiny probes must call out connect-without-read/write overclaims,
known-bad-pair separation must call out SM-T577U/SM-T390 status-133 reuse, and
fetch prerequisites must call out fetch-exchange overclaims.

The review now exposes `required_gate_blocked_claims/0` for operator fixtures
and task tests. It also carries matching `LocalFetchTransportValidationPlan`
blocked claims where the plan and review gates overlap. This strengthens the
known-good transport evidence package without validating GATT, fetching
envelopes, changing the advert-only mode, or closing the current
SM-T577U/SM-T390 transport blocker.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M771-M775 production routing review gate-specific blockers

M771-M775 tightens `LocalRoutingProductionEvidenceReview` so ready production
routing metadata must call out the blocked claims for each
`LocalRoutingHardwareValidationPlan` gate. Forwarding evidence must call out
background forwarding and routed-delivery blockers, release evidence must call
out routing-or-forwarding overclaims, and negative-claim evidence must keep
route selection, forwarding, and routed delivery blocked until implementation
fixtures exist.

The review now exposes `required_gate_blocked_claims/0` for operator fixtures
and task tests. This keeps production routing review aligned with the routing
hardware validation plan without enabling route tables, route selection,
forwarding, delivery semantics, multi-hop hardware routing, ACKs, or retries.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M776-M780 lifecycle hardware review gate-specific blockers

M776-M780 tightens `LocalLifecycleHardwareEvidenceReview` so ready lifecycle
metadata must call out the blocked claims for each
`LocalLifecycleHardwareValidationPlan` gate. Target-device evidence must still
call out background operation and iOS parity blockers, restart evidence must
call out operator-invisible restart, scheduled retry evidence must call out
retry-backed delivery, and background gossip evidence must call out background
forwarding and delivery.

The review now exposes `required_gate_blocked_claims/0` for operator fixtures
and task tests. This keeps lifecycle hardware review tied to device-specific
OS behavior without enabling foreground services, background BLE, restart,
scheduled retry, background gossip, delivery, ACKs, or retries.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M781-M785 iOS parity hardware review gate-specific blockers

M781-M785 tightens `LocalIOSParityHardwareEvidenceReview` so ready iOS
hardware metadata must call out gate-specific iOS blockers in addition to the
shared blocked claims. Device-matrix evidence must reject Android evidence
reuse, canonical ingress evidence must reject bridge-shell-only proof, beacon
gossip evidence must reject missing iOS dispatchers, full-envelope capability
evidence must reject unproven iOS payload capability, and replay evidence must
reject missing iOS replay fixtures.

The review now exposes `required_gate_blocked_claims/0` for operator fixtures
and task tests. It also carries matching `LocalIOSParityHardwareValidationPlan`
blocked claims. This keeps iOS parity review tied to iOS device evidence
instead of Android-only or contract-only proof, without adding iOS runtime
behavior or enabling iOS participation, full-envelope adverts, background BLE,
or parity claims.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M786-M790 multi-hop hardware review gate-specific blockers

M786-M790 tightens `LocalMultiHopHardwareEvidenceReview` so ready physical
multi-hop metadata must call out gate-specific blockers in addition to shared
multi-hop, routing, delivery, trust, background, and completion blockers. The
review now requires explicit callouts for two-device one-hop evidence promoted
as relay proof, missing relay-role capture, replay-only proof treated as
hardware, unbounded loop/duplicate behavior, one-hop-as-multi-hop, and release
overclaims.

The review exposes `required_gate_blocked_claims/0` for operator fixtures and
task tests, and still carries matching blockers from
`LocalAdvertGossipHardwareValidationPlan`. This keeps physical multi-hop
evidence separate from replay topology fixtures and one-hop Android hardware
success until real origin, relay, and observer captures exist.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M791-M795 full-resolution transport review gate-specific blockers

M791-M795 tightens `LocalFullMessageResolutionEvidenceReview` so ready
full-resolution metadata must call out gate-specific blockers in addition to
the shared transport, resolution, delivery, trust, routing, background, and
completion blockers. The review now requires explicit callouts for known-bad
GATT pair evidence promoted as success, unvalidated transport selection,
interop without fetch resolution, missing fetch exchange, hash-mismatch
resolution, unresolved refs promoted to success, and release overclaims.

The review exposes `required_gate_blocked_claims/0` for operator fixtures and
task tests, and still carries matching blockers from
`LocalFetchTransportValidationPlan`. This keeps beacon refs as pointers until
real hardware evidence retrieves and replay-parses a matching full
`MessageEnvelope`.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M796-M800 release candidate completion audit linkage

M796-M800 tightens `LocalReleaseCandidateEvidenceReview` so operator-supplied
release candidate metadata must include the JSON `completion_audit_path` in
generated artifact paths and operator notes. Later release-hardening milestones
add the archived plain-text `completion_audit_plain_text_path` beside it, so
both the machine-readable whole-project completion audit and human-readable
`OPEN_ITEMS`/`OPEN_ITEM` review remain required release-candidate evidence.

The review still supports advert-only local release candidates only. A ready
review means the operator attached the required artifact metadata and wording;
it does not close whole-project completion, full-resolution transport,
known-good transport, physical multi-hop hardware proof, iOS parity, routing,
trust, persistence lifecycle, background lifecycle, ACK, retry, fragmentation,
or crypto gates.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M801-M805 release candidate review docs completion audit linkage

M801-M805 documents the stricter `LocalReleaseCandidateEvidenceReview` input
shape in the release artifact bundle guide and updates the artifact acceptance
criteria so operator release notes must reference the readiness manifest, the
standalone completion audit, and the release manifest together. This keeps the
whole-project completion audit visible in the advert-only release-candidate
review path instead of leaving it as an implied checklist item.

The review still supports advert-only local release candidates only. A ready
review means the operator attached the required artifact metadata and wording;
it does not close whole-project completion, full-resolution transport,
known-good transport, physical multi-hop hardware proof, iOS parity, routing,
trust, persistence lifecycle, background lifecycle, ACK, retry, fragmentation,
or crypto gates.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M806-M810 Nearby Messages UX evidence review hardening

M806-M810 tightens `LocalInboxUxEvidenceReview` so operator-supplied Nearby
Messages state evidence must use a supported evidence kind:
`:screenshot` or `:operator_note`. State and interaction evidence must also
include notes, keeping release UX review metadata explicit enough to audit
without treating vague path references as product UX proof.

The review still does not inspect screenshot pixels, render UI, drive devices,
scan, advertise, fetch, route, persist, ACK, retry, encrypt, or run background
work. Ready UX metadata remains presentation evidence only; it does not allow
delivery, trusted delivery, routing, persistence, background, iOS parity,
full-message resolution, or whole-project completion claims.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M811-M815 persistence production review evidence-type hardening

M811-M815 tightens `LocalPersistenceProductionEvidenceReview` so each
production-default persistence gate must identify the expected evidence type:
product decision, migration test, cleanup test, lifecycle writer test,
on-device restore fixture, or release artifact review. This prevents a generic
artifact path and command from being treated as satisfying the wrong lifecycle
gate.

The review remains metadata-only. It does not save, restore, migrate, prune,
schedule cleanup, write in the background, resolve beacon refs, route, ACK,
retry, encrypt, authenticate, run mobile lifecycle hooks, or promote opt-in
durable snapshots to default app persistence.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M816-M820 security release review evidence-type hardening

M816-M820 tightens `LocalSecurityReleaseEvidenceReview` so every covered
security validation gate must declare the expected evidence type: peer key
enrollment fixture, authorship fixture matrix, replay lifecycle validation,
trust lifecycle validation, canonical replay decision fixture, beacon
authentication fixture, release artifact review, or crypto negative fixture
matrix. This prevents a generic security artifact from vaguely covering
authorship, replay, trust, beacon authentication, and negative-claim gates at
once.

The review remains metadata-only and keeps all authenticated/trusted wording
claims blocked. It does not persist keys, persist trust, persist replay state,
fetch envelopes, inspect hardware, route, ACK, retry, encrypt, run background
work, authenticate hash-only beacon refs, or turn trusted-message evidence into
trusted delivery.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M821-M825 routing production review evidence-type hardening

M821-M825 tightens `LocalRoutingProductionEvidenceReview` so every production
routing gate must declare the expected evidence type: route table state model,
route selection policy, forwarding service boundary, delivery semantics policy,
multi-hop hardware rig, TTL/loop suppression fixture, release artifact review,
or routing negative fixture matrix. This prevents route-candidate evidence or
generic artifacts from being treated as live forwarding or routed-delivery
evidence.

The review remains metadata-only and keeps all routing, forwarding, delivery,
ACK/retry, and multi-hop hardware claims blocked. It does not route, forward,
scan, advertise, persist, ACK, retry, fetch, encrypt, authenticate, run
background work, or promote replay gossip into production routing.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M826-M830 lifecycle hardware review evidence-type hardening

M826-M830 tightens `LocalLifecycleHardwareEvidenceReview` so every mobile
lifecycle gate must declare the expected evidence type: target device matrix,
Android foreground-service log, Android background policy fixture, iOS
background policy fixture, restart/cancellation fixture, scheduled retry
fixture, background gossip limits fixture, or lifecycle negative fixture
matrix. This keeps foreground/manual harness evidence from being reviewed as
background BLE, restart, scheduled retry, or background gossip evidence.

The review remains metadata-only and keeps foreground-service, background BLE,
restart, scheduled retry, background gossip, and delivery claims blocked. It
does not start services, request iOS background modes, schedule retries, scan,
advertise, gossip, route, persist, ACK, retry, fetch, encrypt, authenticate, or
run background work.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M881-M885 completion blocker next-action summary

M881-M885 adds a `next_action_summary` to
`LocalProjectCompletionBlockerMatrix`. The summary keeps the existing
hardware-blocked and no-new-hardware groups, but also exposes the current
recommended operator unblock action. The plain-text
`mix mob.node.local_completion.blocker_matrix` output now prints that
recommended next action, so a status check can answer what remains and what to
do next without reading the full JSON artifact.

The recommended action is planning evidence only. It does not close product UX
or hardware gates, and it keeps the whole-project completion claim blocked
until the required evidence reviews and hardware validations exist.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M886-M890 Nearby Messages UX evidence template

M886-M890 adds a `--template` mode to
`mix mob.node.local_inbox.ux_review`:

```bash
mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json
```

The template lists every required target-device UX metadata section for the
current Nearby Messages evidence review: target device, full/unresolved/
gossiped/stale state evidence, filter/sort/selection/detail interactions,
blocked-claim copy review, and visual-density review. Placeholder fields are
intentionally blank or false, so reviewing the generated template remains
`open` until an operator attaches real target-device screenshots or notes.

This milestone adds no screenshots by itself, no UI rendering proof, no
production UX approval, no BLE behavior, no hardware success claim, no
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M891-M895 release UX template linkage

M891-M895 threads the Nearby Messages UX evidence template command through the
release evidence surfaces. `LocalInboxUxEvidenceManifest` and
`LocalReleaseManifest` now list
`mix mob.node.local_inbox.ux_review --template --out <path>` alongside the
operator review command, and `LocalReleaseArtifactBundle` points the
`ux_evidence_review` artifact at the template-then-review flow.

This makes product-UX evidence collection discoverable from the release bundle
without treating the template as completed evidence. The template still
contains blank/false placeholders, and the UX review remains open until an
operator attaches real target-device screenshots or notes.

This milestone adds no screenshots by itself, no UI rendering proof, no
production UX approval, no BLE behavior, no hardware success claim, no
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M896-M900 release bundle UX operator workflow

M896-M900 updates `docs/local_ble_release_artifact_bundle.md` so the human
release checklist includes the Nearby Messages UX evidence template workflow:
generate the incomplete operator scaffold with
`mix mob.node.local_inbox.ux_review --template --out ...`, fill it with
real target-device screenshots or notes, then run the JSON review command.

The docs explicitly state that the generated template is not product-UX
approval and must remain open until real evidence is attached.

This milestone adds no screenshots by itself, no UI rendering proof, no
production UX approval, no BLE behavior, no hardware success claim, no
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M901-M905 UX review task template hint

M901-M905 updates the plain-text
`mix mob.node.local_inbox.ux_review` output so an open review prints the
template command for generating the operator metadata scaffold. Ready reviews
do not print the hint, and JSON output remains machine-readable review data.

This keeps the product-UX next step visible at the point of failure without
turning missing screenshots, notes, or density review into completed evidence.

This milestone adds no screenshots by itself, no UI rendering proof, no
production UX approval, no BLE behavior, no hardware success claim, no
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M906-M910 completion audit UX template command

M906-M910 adds the Nearby Messages UX evidence template command to the
top-level `LocalProjectCompletionAudit.required_commands` list and to the
`product_ux` prompt-artifact checklist. The completion audit now points to the
same scaffold-then-review flow as the release manifest and artifact bundle.

This keeps the whole-project audit aligned with the current product-UX
evidence workflow while preserving the open product-UX and completion gates.

This milestone adds no screenshots by itself, no UI rendering proof, no
production UX approval, no BLE behavior, no hardware success claim, no
completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M911-M915 persistence production evidence template

M911-M915 adds `LocalPersistenceProductionEvidenceReview.template_input/0` and
a `--template` mode to
`mix mob.node.local_persistence.production_review`. The generated JSON
lists every production-default persistence gate with the expected evidence
type and the `default_lifecycle_decision` `decision_outcome` slot, but leaves
artifact paths, summaries, commands, the decision outcome, and blocked-claim
callouts incomplete.

Reviewing the template remains open and keeps production-default persistence,
background persistence, delivery-record, and full-resolution claims blocked
until an operator supplies real lifecycle evidence.

This milestone adds no default persistence behavior, no storage migration, no
scheduled cleanup worker, no background writer, no on-device restore evidence,
no BLE behavior, no hardware success claim, no completion claim, no
full-message resolution, no routing, no forwarding, no background service, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M916-M920 release persistence template linkage

M916-M920 threads the production persistence evidence template command through
`LocalPersistenceEvidenceManifest`, `LocalReleaseManifest`, and
`LocalReleaseArtifactBundle`. Release artifacts now point the production
persistence review at the template-then-review flow, matching the UX evidence
scaffold pattern.

The scaffold remains incomplete by design and does not enable default app
persistence, background persistence, delivery-record wording, or full-message
resolution.

This milestone adds no default persistence behavior, no storage migration, no
scheduled cleanup worker, no background writer, no on-device restore evidence,
no BLE behavior, no hardware success claim, no completion claim, no
full-message resolution, no routing, no forwarding, no background service, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M921-M925 completion audit persistence template command

M921-M925 adds the production persistence evidence template command to
`LocalProjectCompletionAudit.required_commands` and to the `persistence`
prompt-artifact checklist. The whole-project completion audit now points to the
same persistence scaffold-then-review flow as the persistence manifest,
release manifest, and release artifact bundle.

This keeps persistence evidence collection discoverable from the top-level
audit without enabling production-default persistence or closing the
persistence gate.

This milestone adds no default persistence behavior, no storage migration, no
scheduled cleanup worker, no background writer, no on-device restore evidence,
no BLE behavior, no hardware success claim, no completion claim, no
full-message resolution, no routing, no forwarding, no background service, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M926-M930 persistence review task template hint

M926-M930 updates the plain-text
`mix mob.node.local_persistence.production_review` output so an open review
prints the template command for generating the production persistence metadata
scaffold. Ready reviews do not print the hint, and JSON output remains
machine-readable review data.

This keeps the persistence next step visible at the point of failure without
turning missing lifecycle artifacts into production-default persistence
evidence.

This milestone adds no default persistence behavior, no storage migration, no
scheduled cleanup worker, no background writer, no on-device restore evidence,
no BLE behavior, no hardware success claim, no completion claim, no
full-message resolution, no routing, no forwarding, no background service, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M931-M935 security release evidence template

M931-M935 adds `LocalSecurityReleaseEvidenceReview.template_input/0` and a
`--template` mode to `mix mob.node.local_security.release_review`. The
generated JSON lists every security validation gate with the expected evidence
type, but leaves manifest paths, attachment paths, blocked-claim callouts, and
operator review incomplete.

Reviewing the template remains open and keeps authenticated peer identity,
authenticated message, trusted message, trusted delivery, and freshness claims
blocked until an operator supplies real security evidence.

This milestone adds no key storage, no trust persistence, no replay-state
persistence, no authenticated/trusted claim approval, no BLE behavior, no
hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M936-M940 release security template linkage

M936-M940 threads the security release evidence template command through
`LocalSecurityEvidenceManifest`, `LocalReleaseManifest`, and
`LocalReleaseArtifactBundle`. Release artifacts now point the security release
review at the template-then-review flow, matching the UX and persistence
scaffold patterns.

The scaffold remains incomplete by design and does not enable authenticated
peer identity, authenticated message, trusted message, trusted delivery, or
fresh-message wording.

This milestone adds no key storage, no trust persistence, no replay-state
persistence, no authenticated/trusted claim approval, no BLE behavior, no
hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M941-M945 completion audit security template command

M941-M945 adds the local security release evidence template command to
`LocalProjectCompletionAudit.required_commands` and to the `security_identity`
prompt-artifact checklist. The whole-project completion audit now points to the
same security scaffold-then-review flow as the security manifest, release
manifest, and release artifact bundle.

This keeps security evidence collection discoverable from the top-level audit
without enabling authenticated or trusted wording.

This milestone adds no key storage, no trust persistence, no replay-state
persistence, no authenticated/trusted claim approval, no BLE behavior, no
hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M946-M950 security review task template hint

M946-M950 updates the plain-text
`mix mob.node.local_security.release_review` output so an open review
prints the template command for generating the security release evidence
metadata scaffold. Ready reviews do not print the hint, and JSON output remains
machine-readable review data.

This keeps the security next step visible at the point of failure without
turning missing security attachments into authenticated or trusted-message
evidence.

This milestone adds no key storage, no trust persistence, no replay-state
persistence, no authenticated/trusted claim approval, no BLE behavior, no
hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no ACKs, no retries, no
fragmentation, and no crypto behavior.

## M951-M955 routing production evidence template

M951-M955 adds `LocalRoutingProductionEvidenceReview.template_input/0` and
`mix mob.node.local_routing.production_review --template --out <path>`.
The generated JSON includes every production routing validation gate with its
expected evidence type, but leaves artifact paths, summaries, commands, and
blocked-claim callouts blank.

Reviewing the generated template remains `:open`; route table, route selection,
forwarding, routed delivery, guaranteed delivery, ACK/retry, and multi-hop
hardware routing claims all remain blocked. The routing scaffold is linked from
the routing evidence manifest, release manifest, release artifact bundle, and
whole-project completion audit so operators can produce auditable routing
metadata without accidentally claiming live routing.

This milestone adds no routing, no forwarding service, no live delivery, no
ACKs, no retries, no persistence, no BLE behavior, no hardware success claim,
no completion claim, no background service, no fragmentation, and no crypto
behavior.

## M956-M960 routing production review task template hint

M956-M960 updates the plain-text
`mix mob.node.local_routing.production_review` output so an open routing
review prints the template command for generating the production routing
evidence scaffold. Ready reviews do not print the hint, and JSON output remains
machine-readable review data.

This keeps the routing next step visible at the point of failure without
turning missing routing attachments into route-table, forwarding, routed
delivery, ACK/retry, or multi-hop hardware evidence.

This milestone adds no routing, no forwarding service, no live delivery, no
ACKs, no retries, no persistence, no BLE behavior, no hardware success claim,
no completion claim, no background service, no fragmentation, and no crypto
behavior.

## M961-M965 lifecycle hardware evidence template

M961-M965 adds `LocalLifecycleHardwareEvidenceReview.template_input/0` and
`mix mob.node.local_lifecycle.hardware_review --template --out <path>`.
The generated JSON covers every mobile lifecycle hardware validation gate with
the expected evidence type, but intentionally leaves artifact paths, summaries,
commands, and blocked-claim callouts blank.

Reviewing the generated template remains `:open`; Android foreground-service,
Android/iOS background BLE, restart, scheduled retry, background gossip, and
background delivery claims all remain blocked. The lifecycle scaffold is linked
from the lifecycle evidence manifest, release manifest, release artifact
bundle, and whole-project completion audit so operators can attach device
lifecycle evidence without converting foreground/manual validation into
background behavior claims.

This milestone adds no Android foreground service, no iOS background mode, no
background scanning, no background advertising, no restart automation, no
scheduled retries, no background gossip, no delivery guarantee, no persistence,
no BLE behavior change, no hardware success claim, no completion claim, no
fragmentation, and no crypto behavior.

## M966-M970 lifecycle hardware review task template hint

M966-M970 updates the plain-text
`mix mob.node.local_lifecycle.hardware_review` output so an open lifecycle
review prints the template command for generating the mobile lifecycle hardware
evidence scaffold. Ready reviews do not print the hint, and JSON output remains
machine-readable review data.

This keeps the lifecycle next step visible at the point of failure without
turning missing device logs into Android foreground-service, background BLE,
restart, retry, background gossip, or delivery evidence.

This milestone adds no Android foreground service, no iOS background mode, no
background scanning, no background advertising, no restart automation, no
scheduled retries, no background gossip, no delivery guarantee, no persistence,
no BLE behavior change, no hardware success claim, no completion claim, no
fragmentation, and no crypto behavior.

## M971-M975 iOS parity hardware evidence template

M971-M975 adds `LocalIOSParityHardwareEvidenceReview.template_input/0` and
`mix mob.node.local_ios_parity.hardware_review --template --out <path>`.
The generated JSON includes every iOS advert-only hardware validation gate with
the expected evidence type, but leaves artifact paths, summaries, commands, and
blocked-claim callouts blank.

Reviewing the generated template remains `:open`; iOS participation, iOS
hardware, legacy beacon observation, legacy beacon gossip, full-envelope advert,
background BLE, and parity claims all remain blocked. The scaffold is linked
from the iOS parity evidence manifest, release manifest, release artifact
bundle, and whole-project completion audit so Android advert-only evidence
cannot silently stand in for iOS hardware validation.

This milestone adds no iOS scanner behavior, no iOS advertiser behavior, no
iOS beacon gossip carrier, no iOS full-envelope advert, no iOS background BLE,
no replay fixture, no route, no fetch, no persistence, no BLE behavior change,
no hardware success claim, no completion claim, no fragmentation, and no crypto
behavior.

## M976-M980 iOS parity hardware review task template hint

M976-M980 updates the plain-text
`mix mob.node.local_ios_parity.hardware_review` output so an open iOS
parity review prints the template command for generating the iOS advert-only
hardware evidence scaffold. Ready reviews do not print the hint, and JSON output
remains machine-readable review data.

This keeps the iOS parity next step visible at the point of failure without
turning missing iOS captures into iOS participation, legacy beacon observe,
legacy beacon gossip, full-envelope advert, background BLE, or parity evidence.

This milestone adds no iOS scanner behavior, no iOS advertiser behavior, no
iOS beacon gossip carrier, no iOS full-envelope advert, no iOS background BLE,
no replay fixture, no route, no fetch, no persistence, no BLE behavior change,
no hardware success claim, no completion claim, no fragmentation, and no crypto
behavior.

## M981-M985 multi-hop hardware evidence template

M981-M985 adds `LocalMultiHopHardwareEvidenceReview.template_input/0` and
`mix mob.node.local_multi_hop_hardware.review --template --out <path>`.
The generated JSON includes every physical multi-hop hardware validation gate,
but leaves artifact paths, summaries, commands, and blocked-claim callouts
blank.

Reviewing the generated template remains `:open`; physical multi-hop proof,
multi-hop hardware gossip, routed delivery, guaranteed delivery, trusted
delivery, background operation, and completion claims all remain blocked. The
scaffold is linked from the multi-hop hardware evidence manifest, release
manifest, release artifact bundle, and whole-project completion audit so replay
fixtures and one-hop Android hardware evidence cannot silently stand in for
origin/relay/observer hardware proof.

This milestone adds no scan behavior, no advertise behavior, no relay
execution, no route, no fetch, no persistence, no ACKs, no retries, no
background operation, no trusted delivery, no physical multi-hop success claim,
no completion claim, no fragmentation, and no crypto behavior.

## M986-M990 multi-hop hardware review task template hint

M986-M990 updates the plain-text
`mix mob.node.local_multi_hop_hardware.review` output so an open multi-hop
hardware review prints the template command for generating the physical
multi-hop evidence scaffold. Ready reviews do not print the hint, and JSON
output remains machine-readable review data.

This keeps the physical multi-hop next step visible at the point of failure
without turning missing origin/relay/observer captures into multi-hop gossip,
routed delivery, guaranteed delivery, trusted delivery, background operation,
or completion evidence.

This milestone adds no scan behavior, no advertise behavior, no relay
execution, no route, no fetch, no persistence, no ACKs, no retries, no
background operation, no trusted delivery, no physical multi-hop success claim,
no completion claim, no fragmentation, and no crypto behavior.

## M991-M995 known-good transport evidence template

M991-M995 adds `LocalKnownGoodTransportEvidenceReview.template_input/0` and
`mix mob.node.local_known_good_transport.review --template --out <path>`.
The generated JSON includes every known-good constrained fetch transport gate,
but leaves artifact paths, summaries, commands, and blocked-claim callouts
blank.

Reviewing the generated template remains `:open`; known-good transport, GATT
fetch success, full-message resolution, message delivery, trusted delivery,
routed delivery, and completion claims all remain blocked. The scaffold is
linked from the full-message resolution evidence manifest, release manifest,
release artifact bundle, and whole-project completion audit so known-bad
SM-T577U/SM-T390 GATT evidence cannot silently stand in for a validated
transport.

This milestone adds no BLE connection behavior, no GATT fetch, no scan, no
advertise behavior, no real envelope retrieval, no route, no persistence, no
ACKs, no retries, no trusted delivery, no known-good transport claim, no
full-message resolution claim, no completion claim, no fragmentation, and no
crypto behavior.

## M996-M1000 known-good transport review task template hint

M996-M1000 updates the plain-text
`mix mob.node.local_known_good_transport.review` output so an open
known-good transport review prints the template command for generating the
transport evidence scaffold. Ready reviews do not print the hint, and JSON
output remains machine-readable review data.

This keeps the transport next step visible at the point of failure without
turning missing standalone interop or tiny read/write evidence into a
known-good transport, GATT fetch, full-message resolution, delivery, or
completion claim.

This milestone adds no BLE connection behavior, no GATT fetch, no scan, no
advertise behavior, no real envelope retrieval, no route, no persistence, no
ACKs, no retries, no trusted delivery, no known-good transport claim, no
full-message resolution claim, no completion claim, no fragmentation, and no
crypto behavior.

## M1001-M1005 full-resolution transport evidence template

M1001-M1005 adds `LocalFullMessageResolutionEvidenceReview.template_input/0`
and
`mix mob.node.local_full_resolution.transport_review --template --out <path>`.
The generated JSON includes every full-message-resolution transport validation
gate, but leaves artifact paths, summaries, commands, and blocked-claim
callouts blank.

Reviewing the generated template remains `:open`; real fetch transport,
full-message resolution, known-good transport, GATT fetch success, message
delivery, trust, routing, background delivery, guaranteed delivery, fake
success, and completion claims all remain blocked. The scaffold is linked from
the full-message resolution evidence manifest, release manifest, release
artifact bundle, and whole-project completion audit so beacon refs remain
pointers until real transport evidence retrieves and replay-parses the matching
`MessageEnvelope`.

This milestone adds no BLE connection behavior, no GATT fetch, no scan, no
advertise behavior, no real envelope retrieval, no route, no persistence, no
ACKs, no retries, no trusted delivery, no known-good transport claim, no
full-message resolution claim, no completion claim, no fragmentation, and no
crypto behavior.

## M1006-M1010 full-resolution transport review task template hint

M1006-M1010 updates the plain-text
`mix mob.node.local_full_resolution.transport_review` output so an open
full-resolution transport review prints the template command for generating the
full-message-resolution transport evidence scaffold. Ready reviews do not print
the hint, and JSON output remains machine-readable review data.

This keeps the real-fetch next step visible at the point of failure without
turning missing transport, constrained fetch, canonical replay, or negative
failure evidence into resolved-message, delivery, trust, routing, background
delivery, or completion claims.

This milestone adds no BLE connection behavior, no GATT fetch, no scan, no
advertise behavior, no real envelope retrieval, no route, no persistence, no
ACKs, no retries, no trusted delivery, no known-good transport claim, no
full-message resolution claim, no completion claim, no fragmentation, and no
crypto behavior.

## M1011-M1015 release candidate evidence template

M1011-M1015 adds `LocalReleaseCandidateEvidenceReview.template_input/0` and
`mix mob.node.local_release.candidate_review --template --out <path>`.
The generated JSON exposes required manifest paths, hardware attachment
metadata, gate evidence types, approved release wording, blocked-claim callouts,
and open-gate callouts, but intentionally leaves paths and operator-supplied
evidence blank.

Reviewing the generated template remains `:open`; whole-project completion,
guaranteed delivery, trusted delivery, authenticated delivery, routed delivery,
multi-hop hardware delivery, full-message resolution from beacon refs,
background mobile operation, and iOS advert-only participation claims all remain
blocked. The scaffold is linked from the release manifest, release artifact
bundle, and whole-project completion audit so release hardening has an
archiveable operator input shape without approving release wording.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1016-M1020 release candidate review task template hint

M1016-M1020 updates the plain-text
`mix mob.node.local_release.candidate_review` output so an open release
candidate review prints the template command for generating the release
candidate evidence scaffold. Ready reviews do not print the hint, and JSON
output remains machine-readable review data.

This keeps the release-hardening next step visible at the point of failure
without turning missing hardware attachments, generated manifests, or operator
notes into release approval, completion, delivery, trust, routing, multi-hop,
full-resolution, background, or iOS parity claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1021-M1025 completion audit review-template coverage

M1021-M1025 adds a `review_template_coverage` section to
`LocalProjectCompletionAudit.snapshot/0`. It records every operator review
surface, its required `--template` scaffold command, and its required
`--input --json --out` review command, then marks the pair covered only when
both commands are present in the top-level completion audit command list.

This makes template coverage an audit invariant rather than an informal
convention. It does not satisfy the evidence gates; it only prevents future
operator review surfaces from being added without an archiveable scaffold path.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1026-M1030 completion audit template coverage summary

M1026-M1030 updates the plain-text
`mix mob.node.local_completion.audit --allow-open` output so it prints the
operator review template coverage count:
`REVIEW_TEMPLATES covered=10/10 all_listed=true`. JSON output already carries
the full `review_template_coverage` structure.

This keeps scaffold coverage visible in terminal status output without requiring
operators to inspect the JSON artifact. It remains a workflow/audit signal only;
covered templates do not satisfy the underlying evidence gates.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1031-M1035 release manifest template coverage summary

M1031-M1035 updates the plain-text
`mix mob.node.local_release.manifest` output so it prints the embedded
completion audit's operator review template coverage:
`REVIEW_TEMPLATES covered=10/10 all_listed=true`.

This keeps scaffold coverage visible in release-manifest terminal output, not
only in the standalone completion audit or JSON artifacts. It remains a
workflow/audit signal only; covered templates do not satisfy evidence gates or
approve release claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1036-M1040 completion audit remaining-work summary

M1036-M1040 updates the plain-text
`mix mob.node.local_completion.audit --allow-open` output so the whole
project status command prints:

- `HARDWARE_BLOCKED 4 objectives=...`
- `NO_NEW_HARDWARE 6 objectives=...`
- `RECOMMENDED_NEXT objective=product_ux action=...`

This makes the completion audit directly answer what remains across the whole
project: full message resolution, known-good transport validation, multi-hop
hardware proof, and iOS parity remain hardware-blocked; product UX,
persistence, security/identity, routing, background/mobile lifecycle, and
release hardening can continue without new hardware. The recommended immediate
non-hardware action remains target-device UX evidence and UX review before
product-facing release wording.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1041-M1045 Nearby Messages HomeScreen test coverage

M1041-M1045 adds the `apps/mob_node/test/mob_node/home_screen_test.exs`
test file already listed by the Nearby Messages UX evidence manifest. The test
covers Mob HomeScreen initialization of the local inbox state filter, sort, and
detail selection, plus filter/sort/detail tap handling that changes only the
local view state.

This closes a workflow coverage gap between the UX evidence manifest's required
commands and the actual checked-in test suite. It remains pure UI-state
coverage; target-device screenshots/operator notes are still required before
production Nearby Messages UX claims can be made.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1046-M1050 required command path guard

M1046-M1050 adds `LocalRequiredCommandPathsTest`, a release-hardening guard that
collects `required_commands` from the completion audit, release manifest,
release artifact bundle, and local evidence manifests. Any path-specific
`mix test apps/.../*.exs` command must point at a checked-in test file from the
repository root.

This prevents release/evidence manifests from drifting into stale test-command
references like the missing HomeScreen test caught before M1041-M1045. The
guard validates command path existence only; it does not treat command presence
as proof that the underlying evidence gate is satisfied.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1051-M1055 release artifact command sync guard

M1051-M1055 adds a release artifact bundle assertion that
`LocalReleaseArtifactBundle.snapshot().required_commands` exactly mirrors the
generated artifact `source` commands and contains no duplicates. This keeps the
release artifact checklist auditable: adding, removing, or renaming a generated
artifact command must be reflected in the required command gate list.

This guard checks release checklist consistency only. It does not make operator
artifacts complete, satisfy hardware gates, or convert listed commands into
evidence that a blocked claim passed.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1056-M1060 release manifest artifact-command guard

M1056-M1060 adds a release manifest assertion that every `required_artifacts`
entry with a `mix ...` command is also covered by the manifest's
`required_commands` gate list. The guard caught and fixed a readiness artifact
drift: the required artifact now uses
`mix mob.node.local_readiness.audit --allow-open --json --out <path>`, and
the generic JSON readiness artifact command is listed in `required_commands`.

This keeps the release manifest's artifact checklist and command checklist in
sync. It remains checklist coverage only; running or listing the command does
not satisfy open hardware, UX, persistence, security, routing, lifecycle, iOS,
or release-candidate evidence gates.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1061-M1065 release manifest command-artifact guard

M1061-M1065 adds the inverse release manifest assertion: every artifact-producing
required command gate must also be represented by a `required_artifacts` entry.
The guard covers placeholder artifact commands such as `--out <path>` plus the
advert gossip audit scenario command, while leaving operational gates like
`mix test`, `mix format --check-formatted`, `git diff --check`, and concrete CI
output commands as command-only checks.

Together with M1056-M1060, this keeps the release manifest artifact checklist
and command checklist bidirectionally consistent without changing any runtime
behavior or evidence-gate status.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1066-M1070 completion audit prompt-command guard

M1066-M1070 adds a completion audit assertion that every verification command
listed in the prompt artifact checklist is also present in the top-level
`required_commands` list. This keeps the whole-project prompt-to-artifact map
actionable: each objective's checklist can point at specific commands without
drifting away from the audit's release command gate list.

The guard checks audit consistency only. It does not satisfy any blocked
hardware proof, production UX validation, production-default persistence,
security/trust, routing, lifecycle, iOS parity, or release-candidate evidence
gate.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1071-M1075 completion audit blocker partition guard

M1071-M1075 adds a completion audit assertion that the prompt artifact checklist
objective IDs exactly match the blocker matrix objective partitions. It also
asserts the hardware-blocked and no-new-hardware partitions are disjoint.

This keeps the audit's two primary planning views aligned: the objective-level
prompt-to-artifact checklist and the hardware/no-new-hardware remaining-work
summary. It remains a consistency guard only and does not close any evidence
gate.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1076-M1080 completion audit recommended-next guard

M1076-M1080 adds a completion audit assertion that
`blocker_matrix.next_action_summary.recommended_now` points at an objective that
is both present in the prompt artifact checklist and listed in the
no-new-hardware action set. The guard also requires the recommendation to carry
non-empty action text and required evidence.

This keeps the terminal `RECOMMENDED_NEXT` line tied to an auditable objective
instead of a free-floating planning string. It remains a consistency guard only;
it does not satisfy product UX evidence or any other completion gate.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1081-M1085 completion audit status-alignment guard

M1081-M1085 adds a completion audit assertion that each prompt artifact
checklist item's status matches the corresponding blocker matrix entry status.
This keeps the audit from reporting an objective as blocked in one view and
partial in another.

This is a consistency guard only. It does not change the current statuses:
full message resolution, known-good transport validation, and multi-hop
hardware proof remain blocked; product UX, persistence, security/identity,
routing, background/mobile lifecycle, iOS parity, and release hardening remain
partial.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1086-M1090 completion audit count guard

M1086-M1090 adds a completion audit assertion that the reported open, blocked,
partial, and not-started counts are derived from the blocker matrix entry
statuses. This keeps the concise audit summary tied to the detailed objective
matrix.

The derived counts remain unchanged: 10 open items, 3 blocked items, 7 partial
items, and 0 not-started items. Completion remains false.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1091-M1095 completion audit claim-safety guard

M1091-M1095 adds a completion audit assertion that completion claims remain
false while any objective remains blocked, partial, or not started. The current
audit still has open work, so both `whole_project_complete?` and
`completion_claim_allowed?` remain false.

This protects the top-level completion wording from drifting away from the
objective counts. It does not close any missing hardware, UX, persistence,
security, routing, lifecycle, iOS, or release evidence.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1096-M1100 release manifest claim-alignment guard

M1096-M1100 adds a release manifest assertion that the top-level
`whole_project_complete?` flag stays aligned with the embedded completion audit's
`whole_project_complete?` flag. The manifest can still report
`releasable_with_limitations?` for the validated advert-only local mode, but it
must not drift into a whole-project completion claim while the completion audit
remains false.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1101-M1105 release wording policy guard

M1101-M1105 adds a release manifest assertion that blocked release wording stays
aligned with the current policy gates. If trusted delivery, routing, background
mobile operation, or iOS advert-only participation remain blocked by policy, the
manifest must continue to list matching blocked wording for release review.

This protects the operator-facing release boundary from drifting into claims
that the gates still forbid. It does not change the validated advert-only local
mode or close any missing full-resolution transport, multi-hop hardware, iOS,
UX, persistence, security, routing, lifecycle, or release-candidate evidence.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1106-M1110 UX target-device evidence guard

M1106-M1110 tightens `LocalInboxUxEvidenceReview` so every declared target
device must have attached Nearby Messages state evidence and interaction
evidence. A UX evidence bundle can no longer list an additional phone, tablet,
or build in the target matrix without showing at least one state artifact and
one interaction artifact for that declared target.

This keeps the `product_ux` evidence gate from accepting target-device metadata
that is not represented by actual UX attachments. It still does not inspect
screenshot pixels, approve production UX claims, or turn Nearby Messages into
delivery evidence.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1111-M1115 UX per-target coverage guard

M1111-M1115 tightens `LocalInboxUxEvidenceReview` again so each declared target
device must cover every required Nearby Messages state and every required
interaction. A release candidate can no longer satisfy the UX gate by showing
all states on one device while only attaching a token screenshot or interaction
for another declared target.

This keeps the target-device UX evidence review aligned with the validation
plan's state coverage and interaction coverage gates. It remains a metadata
review only: it does not inspect screenshot pixels, approve production UX
claims, or create any delivery, trust, routing, background, persistence, iOS, or
transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1116-M1120 UX visual-density target guard

M1116-M1120 adds `target_device_ids_reviewed` to
`LocalInboxUxEvidenceReview` visual-density metadata and requires that list to
cover every declared target device. A UX evidence bundle can no longer pass
with state and interaction artifacts for each target while the visual-density
review only covers an unspecified or single target.

This keeps visual density evidence aligned with the target-device matrix. It
remains an operator metadata review only: it does not inspect screenshot pixels,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1121-M1125 UX copy-review target guard

M1121-M1125 adds `target_device_ids_reviewed` to
`LocalInboxUxEvidenceReview` copy-review metadata and requires that list to
cover every declared target device. A UX evidence bundle can no longer pass
with state, interaction, and density evidence for a target while blocked-claim
copy review only covers an unspecified or different target.

This keeps the blocked-claim copy review aligned with the target-device matrix.
It remains an operator metadata review only: it does not inspect screenshot
pixels, approve production UX claims, or add delivery, trust, routing,
background, persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1126-M1130 UX target identity guard

M1126-M1130 tightens `LocalInboxUxEvidenceReview` so the target-device matrix
rejects duplicate `device_id` values. State, interaction, copy-review, and
visual-density coverage all key off `device_id`, so duplicate target rows would
make the UX evidence bundle ambiguous.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1131-M1135 UX artifact identity guard

M1131-M1135 tightens `LocalInboxUxEvidenceReview` so state evidence and
interaction evidence reject duplicate `artifact_path` values. Each required UX
state and interaction now needs its own declared attachment path instead of
reusing one screenshot or note path across multiple evidence rows.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1136-M1140 UX review artifact guard

M1136-M1140 tightens `LocalInboxUxEvidenceReview` so the blocked-claim copy
review and visual-density review cannot point at the same artifact path. These
are separate UX evidence gates, so a release candidate must attach separate
review artifacts for copy/claim wording and visual-density checks.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1141-M1145 UX relative artifact path guard

M1141-M1145 tightens `LocalInboxUxEvidenceReview` so target-device evidence,
state evidence, interaction evidence, copy-review evidence, and visual-density
evidence must use release-relative artifact paths. Absolute paths, home-relative
paths, URL paths, `file:` paths, and parent-directory traversal stay open until
the evidence bundle is archive-relative and reproducible.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1146-M1150 UX portable artifact path guard

M1146-M1150 extends the UX artifact path guard to reject Windows drive-letter
and UNC absolute paths. Release-candidate UX evidence must stay portable and
archive-relative across platforms, not depend on an operator machine path.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1151-M1155 UX review target identity guard

M1151-M1155 tightens `LocalInboxUxEvidenceReview` so blocked-claim copy reviews
and visual-density reviews cannot name target device ids that are absent from
the declared target-device matrix. UX evidence must stay tied to the reviewed
device/build identities instead of silently accepting stray or mistyped device
ids.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1156-M1160 UX review target duplication guard

M1156-M1160 tightens `LocalInboxUxEvidenceReview` so blocked-claim copy reviews
and visual-density reviews cannot list the same reviewed target device id more
than once. Review target coverage must reflect distinct target devices, not
duplicate rows in operator-supplied metadata.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1161-M1165 UX blocked-claim callout guard

M1161-M1165 tightens `LocalInboxUxEvidenceReview` so the blocked-claim copy
review must call out exactly the supported blocked claims. Duplicate callouts
and unsupported claim names keep the evidence open instead of being accepted as
release-candidate wording review metadata.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1166-M1170 UX evidence coverage identity guard

M1166-M1170 tightens `LocalInboxUxEvidenceReview` so state evidence and
interaction evidence cannot include duplicate coverage for the same target
device and UX state or interaction. Distinct artifact paths no longer allow the
same target/state or target/interaction coverage row to be counted twice.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1171-M1175 UX evidence domain guard

M1171-M1175 tightens `LocalInboxUxEvidenceReview` so state evidence and
interaction evidence cannot name unsupported UX states or interactions.
Operator metadata must stay inside the Nearby Messages state and interaction
domains defined by the validation plan.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1176-M1180 UX malformed evidence guard

M1176-M1180 tightens `LocalInboxUxEvidenceReview` so malformed top-level
evidence containers and malformed evidence rows fail closed as open evidence
reviews instead of raising exceptions. Non-list evidence sections are treated
as missing, and non-map rows are converted into missing-field review entries.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1181-M1185 UX malformed review input guard

M1181-M1185 tightens `LocalInboxUxEvidenceReview` so a non-map top-level
evidence input fails closed through the empty evidence review path instead of
raising a function-clause error. Operator-supplied UX evidence remains an open
review until the required target device, state, interaction, copy, and density
metadata is supplied.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1186-M1190 UX malformed JSON review guard

M1186-M1190 aligns `LocalInboxUxEvidenceReview.json_review/1` with the
fail-closed top-level review contract. The JSON wrapper now explicitly accepts
malformed terms through its spec and has regression coverage proving non-map
input still returns machine-readable open evidence output.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1191-M1195 UX review task malformed input guard

M1191-M1195 adds task-level regression coverage for
`mix mob.node.local_inbox.ux_review --input <path> --json --out <path>`
when the decoded JSON evidence shape is malformed. The operator-facing task
continues to emit and archive machine-readable open evidence output instead of
promoting malformed metadata or crashing after decode.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1196-M1200 UX target evidence path identity guard

M1196-M1200 tightens `LocalInboxUxEvidenceReview` so declared target devices
cannot share the same target-level evidence path. The target-device matrix must
point each reviewed device/build identity at distinct archive evidence instead
of silently reusing one target directory for multiple target rows.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1201-M1205 UX state-interaction artifact guard

M1201-M1205 tightens `LocalInboxUxEvidenceReview` so state evidence and
interaction evidence cannot reuse the same artifact path. State coverage and
interaction coverage are distinct UX validation gates and must point at
separate archive artifacts.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1206-M1210 UX review-evidence artifact guard

M1206-M1210 tightens `LocalInboxUxEvidenceReview` so blocked-claim copy review
and visual-density review artifacts cannot reuse state or interaction evidence
artifact paths. Review artifacts and evidence artifacts are separate UX
validation records and must remain distinct inside the archive.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1211-M1215 UX artifact path trim guard

M1211-M1215 tightens `LocalInboxUxEvidenceReview` so target evidence paths,
state and interaction artifact paths, blocked-claim copy review paths, and
visual-density artifact paths must already be trim-stable. Leading or trailing
whitespace keeps the UX evidence package open instead of being silently
normalized during relative-path validation.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1216-M1220 UX identity trim guard

M1216-M1220 tightens `LocalInboxUxEvidenceReview` so target device ids, state
and interaction target references, and copy/density reviewed target ids must
already be trim-stable. Leading or trailing whitespace keeps the UX evidence
package open instead of producing ambiguous device coverage rows.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1221-M1225 UX evidence text trim guard

M1221-M1225 tightens `LocalInboxUxEvidenceReview` so target device metadata
and state/interaction evidence notes must already be trim-stable. Leading or
trailing whitespace keeps the UX evidence package open instead of relying on
presence checks to silently normalize operator-supplied evidence text.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1226-M1230 UX reviewed-target list guard

M1226-M1230 tightens `LocalInboxUxEvidenceReview` so copy and visual-density
reviewed target lists preserve malformed entries long enough to reject them.
Blank or non-string reviewed target ids now keep the UX evidence package open
instead of being silently dropped before target coverage checks run.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1231-M1235 UX scalar field type guard

M1231-M1235 tightens `LocalInboxUxEvidenceReview` so required target-device
metadata, artifact paths, review paths, target references, and evidence notes
must be strings when present. Non-string scalar values now keep the UX evidence
package open instead of satisfying presence checks by being non-nil.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1236-M1240 UX reviewed-target container guard

M1236-M1240 tightens `LocalInboxUxEvidenceReview` so copy and visual-density
`target_device_ids_reviewed` fields must be lists. Non-list reviewed-target
containers now keep the UX evidence package open instead of being normalized to
an empty list and reported only indirectly as missing target coverage.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1241-M1245 UX blocked-claim container guard

M1241-M1245 tightens `LocalInboxUxEvidenceReview` so copy-review
`blocked_claims_called_out` must be a list. Non-list blocked-claim containers
now keep the UX evidence package open instead of being normalized to an empty
list and reported only indirectly as missing blocked-claim coverage.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1246-M1250 UX blocked-claim list guard

M1246-M1250 tightens `LocalInboxUxEvidenceReview` so copy-review
`blocked_claims_called_out` entries must be non-empty strings or atoms. Blank
or malformed blocked-claim entries now keep the UX evidence package open
instead of being reported only through unsupported or missing claim coverage.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1251-M1255 UX boolean field type guard

M1251-M1255 tightens `LocalInboxUxEvidenceReview` so copy warning capture and
visual-density review flags must be booleans. Non-boolean review flags now keep
the UX evidence package open with explicit type errors instead of only producing
generic missing-review messages.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1256-M1260 UX allowed-wording type guard

M1256-M1260 tightens `LocalInboxUxEvidenceReview` so copy-review
`allowed_wording` must be a string. Non-string wording evidence now keeps the UX
evidence package open with an explicit type error before the exact approved
wording check runs.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1261-M1265 UX enum field type guard

M1261-M1265 tightens `LocalInboxUxEvidenceReview` so state, interaction, and
evidence-kind values must be strings or atoms before domain validation. Numeric
or otherwise malformed enum fields now keep the UX evidence package open with
explicit type errors instead of only producing unsupported-value messages.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1266-M1270 UX enum trim guard

M1266-M1270 tightens `LocalInboxUxEvidenceReview` so state, interaction, and
evidence-kind string values must not carry leading or trailing whitespace.
Whitespace-padded enum evidence now keeps the UX evidence package open with an
explicit trim error instead of only producing unsupported-value messages.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1271-M1275 UX blocked-claim trim guard

M1271-M1275 tightens `LocalInboxUxEvidenceReview` so copy-review
`blocked_claims_called_out` entries must not carry leading or trailing
whitespace. Whitespace-padded blocked-claim evidence now keeps the UX evidence
package open with an explicit trim error instead of only producing
unsupported-claim messages.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1276-M1280 UX allowed-wording trim guard

M1276-M1280 tightens `LocalInboxUxEvidenceReview` so copy-review
`allowed_wording` must not carry leading or trailing whitespace. Whitespace-
padded approved wording now keeps the UX evidence package open with an explicit
trim error before the exact approved-wording check is considered sufficient.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1281-M1285 UX top-level container guard

M1281-M1285 tightens `LocalInboxUxEvidenceReview` so top-level UX evidence
sections fail closed with explicit container-shape errors. `target_devices`,
`state_evidence`, and `interaction_evidence` must be lists, while `copy_review`
and `visual_density_review` must be objects. Malformed sections still also
produce the existing missing-evidence messages after being safely normalized.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1286-M1290 UX evidence row object guard

M1286-M1290 tightens `LocalInboxUxEvidenceReview` so malformed entries inside
the `target_devices`, `state_evidence`, and `interaction_evidence` lists fail
closed with explicit row-shape errors. Non-object rows still also produce the
existing missing-field messages after safe normalization.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1291-M1295 UX review boolean presence guard

M1291-M1295 tightens `LocalInboxUxEvidenceReview` so copy-review and visual
density boolean flags must be present explicitly. Omitted review flags now keep
the UX evidence package open with missing-field errors instead of being treated
the same as operator-supplied `false` values.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1296-M1300 UX review list presence guard

M1296-M1300 tightens `LocalInboxUxEvidenceReview` so copy-review and visual
density list fields must be present explicitly. Omitted reviewed-target lists
and blocked-claim callout lists now keep the UX evidence package open with
missing-field errors instead of being treated the same as operator-supplied
empty lists.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1301-M1305 UX allowed-wording presence guard

M1301-M1305 tightens `LocalInboxUxEvidenceReview` so copy-review
`allowed_wording` must be present explicitly. Omitted approved wording now keeps
the UX evidence package open with a missing-field error before the exact
approved-wording check reports the wording mismatch.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1306-M1310 UX top-level section presence guard

M1306-M1310 tightens `LocalInboxUxEvidenceReview` so omitted top-level UX
evidence sections fail closed with explicit missing-section errors. Missing
`target_devices`, `state_evidence`, `interaction_evidence`, `copy_review`, and
`visual_density_review` sections still normalize safely and continue producing
the existing downstream missing-evidence diagnostics.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1311-M1315 UX JSON surface guard

M1311-M1315 adds a regression guard for `LocalInboxUxEvidenceReview.json_review/1`
so internal validation flags used by the review engine stay out of the
archiveable JSON output. Operator-facing UX evidence JSON continues to expose
the reviewed evidence fields and claim gates without leaking presence or
container-validity implementation details.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1316-M1320 UX review artifact surface guard

M1316-M1320 adds a task-level regression guard for
`mix mob.node.local_inbox.ux_review --json --out <path>` so written UX
review artifacts do not expose internal validation flags. This keeps the
operator-facing artifact contract aligned with `LocalInboxUxEvidenceReview`'s
archiveable JSON surface.

This is an evidence-quality guard only. It does not inspect screenshots,
approve production UX claims, or add delivery, trust, routing, background,
persistence, iOS, or transport behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no persistence behavior, and no crypto behavior.

## M1321-M1325 persistence production gate presence guard

M1321-M1325 tightens `LocalPersistenceProductionEvidenceReview` so omitted
production-default persistence evidence gate sections fail closed with explicit
missing-section errors. Missing gate sections still normalize safely and
continue producing the existing field-level diagnostics for the production
lifecycle review.

This is an evidence-quality guard only. It does not enable default persistence,
migrations, cleanup workers, background writers, app-start restore, delivery
records, full-message resolution, routing, trust, crypto, or mobile lifecycle
behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1326-M1330 persistence production gate object guard

M1326-M1330 tightens `LocalPersistenceProductionEvidenceReview` so malformed
production-default persistence evidence gate sections fail closed with explicit
object-shape errors instead of raising. Malformed gate sections still normalize
safely and continue producing the existing field-level diagnostics for the
production lifecycle review.

This is an evidence-quality guard only. It does not enable default persistence,
migrations, cleanup workers, background writers, app-start restore, delivery
records, full-message resolution, routing, trust, crypto, or mobile lifecycle
behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1331-M1335 persistence production blocked-claim list guard

M1331-M1335 tightens `LocalPersistenceProductionEvidenceReview` so malformed
`blocked_claims_called_out` metadata fails closed with an explicit list-shape
diagnostic. The review keeps the internal container guard out of archiveable JSON
while preserving the existing missing-claim diagnostics.

This is an evidence-quality guard only. It does not enable default persistence,
migrations, cleanup workers, background writers, app-start restore, delivery
records, full-message resolution, routing, trust, crypto, or mobile lifecycle
behavior.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1336-M1340 Nearby Messages detail identifiers

M1336-M1340 expands the native Nearby Messages detail model so selected rows
carry explicit detail lines for full-message IDs, beacon message hashes, sender
IDs or sender hashes, recipients, source devices, RSSI, observation timing, and
`observed_via` provenance. The home screen renders those model-provided detail
lines directly, keeping the distinction between full envelope rows and
unresolved/gossiped/stale beacon refs visible in the product surface.

This is a product read-model and UX clarity change only. It does not resolve
beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt, authenticate,
scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1341-M1345 Nearby Messages control summaries

M1341-M1345 expands the native Nearby Messages surface with operator-readable
active filter and sort summaries. The home screen renders those summaries above
the state and sort controls so screenshots and review notes can show which rows
are visible and which ordering is active without relying on internal assigns.

This is a product read-model and UX clarity change only. It does not resolve
beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt, authenticate,
scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1346-M1350 Nearby Messages blocked-claim copy

M1346-M1350 expands the centralized Nearby Messages state copy with explicit
blocked claims for full-message rows, unresolved beacon refs, gossiped refs, and
stale refs. The native surface now carries those blocked claims on each row and
in the selected detail lines so product evidence can show the UI is preserving
the distinction between observation, pointer, gossip, and delivery/trust/routing
claims.

This is a product read-model and UX clarity change only. It does not resolve
beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt, authenticate,
scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1351-M1355 Nearby Messages acceptance gates

M1351-M1355 tightens `LocalInboxUxAcceptance` so the pure UX acceptance snapshot
requires active filter summaries, active sort summaries, per-row blocked-claim
copy, and selected-detail blocked-claim copy. The acceptance contract still keeps
the on-device validation gate blocked until target-device screenshots or
operator notes satisfy `LocalInboxUxValidationPlan`.

This is a product read-model and UX evidence-gate change only. It does not
resolve beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt,
authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1356-M1360 Nearby Messages UX manifest surface summary

M1356-M1360 expands `LocalInboxUxEvidenceManifest` so the archiveable surface
summary includes active filter and sort summaries, sort descriptions, and
per-row blocked-claim copy. This lets release review artifacts show the newer UX
evidence gates without reconstructing them from the native surface structs.

This is a UX evidence-manifest change only. It does not resolve beacon refs,
fetch envelopes, route, persist, ACK, retry, encrypt, authenticate, scan,
advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1361-M1365 Nearby Messages UX evidence task summary

M1361-M1365 updates the plain-text
`mix mob.node.local_inbox.ux_evidence` output so release logs show the
active filter summary, active sort summary, row blocked-claim coverage count,
and routing claim state. The JSON artifact already carries those fields; this
makes the non-JSON task output expose the same review anchors.

This is a UX evidence task-output change only. It does not resolve beacon refs,
fetch envelopes, route, persist, ACK, retry, encrypt, authenticate, scan,
advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1366-M1370 release UX artifact anchors

M1366-M1370 updates the release manifest and release artifact bundle so the
`ux_evidence_manifest` artifact explicitly requires archived active filter/sort
summaries and per-row blocked-claim copy. This keeps the release checklist
aligned with the strengthened Nearby Messages UX evidence surface.

This is a release evidence metadata change only. It does not resolve beacon
refs, fetch envelopes, route, persist, ACK, retry, encrypt, authenticate, scan,
advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1371-M1375 readiness UX summary anchors

M1371-M1375 updates `LocalProjectReadiness` and `LocalProjectCompletionAudit`
so the product UX item records the current pure surface anchors: active control
summaries, per-state blocked-claim copy, and archiveable UX manifest coverage.
The on-device validation requirement remains open.

This is a readiness and completion-audit metadata change only. It does not
resolve beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt,
authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1376-M1380 UX evidence copy review anchors

M1376-M1380 tightens `LocalInboxUxEvidenceReview` so the operator copy review
must explicitly capture filter/sort control summaries and per-state
blocked-claim copy before the Nearby Messages UX evidence can become ready.
The UX validation plan and evidence manifest now name those copy-review
artifacts as target-device evidence requirements.

This is still a pure evidence-contract change. It does not inspect screenshots,
drive devices, render UI, resolve beacon refs, fetch envelopes, route, persist,
ACK, retry, encrypt, authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1381-M1385 UX evidence copy review test anchors

M1381-M1385 adds executable coverage around the M1376-M1380 copy-review
requirements. `LocalInboxUxValidationPlanTest` now asserts that the
blocked-claim copy review gate requires filter/sort summaries and per-state
blocked-claim copy, while `LocalInboxUxEvidenceManifestTest` asserts those
requirements flow into the archiveable UX evidence manifest.

This is a test and progress-ledger change only. It does not inspect
screenshots, drive devices, render UI, resolve beacon refs, fetch envelopes,
route, persist, ACK, retry, encrypt, authenticate, scan, advertise, or run
background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1386-M1390 UX review task copy anchors

M1386-M1390 updates the `mob.node.local_inbox.ux_review` task tests so the
operator template path and complete input fixture include the control-summary
and per-state blocked-claim copy review booleans. The task tests also assert
that public copy-review fields remain visible while internal presence flags are
not emitted in JSON artifacts.

This is a task-test alignment change only. It does not inspect screenshots,
drive devices, render UI, resolve beacon refs, fetch envelopes, route, persist,
ACK, retry, encrypt, authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1391-M1395 UX evidence task copy-review summary

M1391-M1395 updates the plain-text
`mix mob.node.local_inbox.ux_evidence` output so it prints a
`UX_COPY_REVIEW` line with the blocked-claim copy review evidence requirement
and archive artifact purpose. This keeps non-JSON operator output aligned with
the control-summary and per-state blocked-claim copy gates already present in
the manifest JSON.

This is a task-summary change only. It does not inspect screenshots, drive
devices, render UI, resolve beacon refs, fetch envelopes, route, persist, ACK,
retry, encrypt, authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1396-M1400 release UX review artifact anchors

M1396-M1400 tightens `LocalReleaseArtifactBundle` so the operator-supplied
`ux_evidence_review` artifact acceptance criteria require control-summary copy
and per-state blocked-claim copy. This keeps release packaging aligned with the
Nearby Messages UX evidence review contract and prevents generic
blocked-claim wording from satisfying the product UX release artifact.

This is a release artifact metadata change only. It does not inspect
screenshots, drive devices, render UI, resolve beacon refs, fetch envelopes,
route, persist, ACK, retry, encrypt, authenticate, scan, advertise, or run
background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1401-M1405 UX review task copy summary

M1401-M1405 updates the plain-text
`mix mob.node.local_inbox.ux_review` output so it prints a
`LOCAL_INBOX_UX_COPY_REVIEW` line. The line records whether operator metadata
captured visible warning text, control summaries, and per-state blocked-claim
copy, plus the blocked-claim callout count.

This is a task-summary change only. It does not inspect screenshots, drive
devices, render UI, resolve beacon refs, fetch envelopes, route, persist, ACK,
retry, encrypt, authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1406-M1410 persistence negative fixtures

M1406-M1410 updates `LocalPersistenceNegativeValidation` so each blocked
persistence claim carries implementation evidence from the current persistence
lifecycle, profile, policy, and durable snapshot code. The fixtures prove that
the current app default remains memory-only, opt-in durable beacon refs persist
as unresolved pointers without envelope wires, cleanup is manual rather than
scheduled, foreground save hooks are not background-safe writes, and raw
transport metadata remains excluded from durable snapshots.

This is a pure validation-fixture change. It does not change persistence
defaults, save or restore data, migrate schemas, prune storage, schedule work,
start background services, resolve beacon refs, fetch envelopes, route, ACK,
retry, encrypt, authenticate, scan, advertise, or run background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1411-M1415 persistence evidence manifest fixture summary

M1411-M1415 updates `LocalPersistenceEvidenceManifest` so generated
persistence evidence includes a `negative_implementation_evidence` summary.
The summary records the negative validation case count, proves every case has
implementation-backed evidence, lists the source modules used by those
fixtures, and repeats the blocked persistence claims.

This is an archiveable evidence-manifest change only. It does not change
persistence defaults, save or restore data, migrate schemas, prune storage,
schedule work, start background services, resolve beacon refs, fetch
envelopes, route, ACK, retry, encrypt, authenticate, scan, advertise, or run
background work.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1416-M1420 Nearby Messages detail evidence manifest

M1416-M1420 updates `LocalInboxUxEvidenceManifest` so the archiveable
Nearby Messages UX manifest includes `detail_evidence` for each fixture
state: full message, unresolved ref, gossiped ref, and stale ref. Each entry
records the selected detail status, state, message key, detail title,
identifier lines, observed source, blocked delivery flag, blocked claims,
limitation presence, and next-action presence.

The `mob.node.local_inbox.ux_evidence` task now prints a
`UX_DETAIL_EVIDENCE` summary that states how many detail states are covered
and whether all selected details keep delivery claims blocked. This makes the
existing detail-panel acceptance easier to archive without changing the
surface behavior.

This is an evidence-manifest and task-output change only. It does not render
UI, drive devices, scan, advertise, fetch envelopes, resolve beacon refs,
route, ACK, retry, persist, encrypt, authenticate, run background work, or
approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1421-M1425 Nearby Messages detail copy review

M1421-M1425 tightens `LocalInboxUxEvidenceReview` so operator-supplied
Nearby Messages UX metadata must explicitly confirm selected detail-panel
copy was captured. The new `detail_panel_copy_captured` copy-review flag
keeps detail limitations, next actions, and blocked-claim copy attached to
the same operator review gate that already protects warnings, control
summaries, and per-state blocked claims.

The `mob.node.local_inbox.ux_review` task now prints
`detail_panel_copy_captured` in the copy-review summary, and the UX validation
plan plus evidence manifest wording now name selected detail limitations and
detail next actions as copy-review evidence. The review can become `ready`
only when this metadata is present and true, while production UX, delivery,
trust, routing, and background claims remain blocked.

This is an evidence-review and task-output change only. It does not render
UI, drive devices, scan, advertise, fetch envelopes, resolve beacon refs,
route, ACK, retry, persist, encrypt, authenticate, run background work, or
approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1426-M1430 Nearby Messages UX coverage summary

M1426-M1430 adds a `coverage_summary` to `LocalInboxUxEvidenceReview` so the
archiveable UX review output records target-device count, state evidence
count, interaction evidence count, copy-review target coverage, visual-density
target coverage, and whether every declared target device has complete state,
interaction, copy-review, and density-review coverage.

The `mob.node.local_inbox.ux_review` task now prints a
`LOCAL_INBOX_UX_COVERAGE` line alongside the existing status and copy-review
summary. This makes operator evidence coverage auditable without scraping the
full missing-reason list, while keeping the actual on-device evidence gate
open until screenshots or operator notes are supplied and reviewed.

This is an evidence-review and task-output change only. It does not render
UI, drive devices, scan, advertise, fetch envelopes, resolve beacon refs,
route, ACK, retry, persist, encrypt, authenticate, run background work, or
approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1431-M1435 project UX readiness anchors

M1431-M1435 updates the project-level readiness and whole-project completion
audit records so the `product_ux` item explicitly names the current Nearby
Messages UX evidence surface: selected detail evidence, selected detail-copy
review, `coverage_summary` review output, control summaries, and per-state
blocked-claim copy.

The product UX item remains `partial`. The updated audit language makes the
new evidence visible in readiness/completion artifacts while keeping the real
gate unchanged: target-device screenshots or operator notes still need to
satisfy `LocalInboxUxValidationPlan`, and `LocalInboxUxEvidenceReview` still
needs ready operator-supplied evidence before any production UX wording can be
accepted.

This is a readiness/audit wording change only. It does not render UI, drive
devices, scan, advertise, fetch envelopes, resolve beacon refs, route, ACK,
retry, persist, encrypt, authenticate, run background work, or approve
production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1436-M1440 product UX blocker matrix anchors

M1436-M1440 updates `LocalProjectCompletionBlockerMatrix` so the recommended
no-new-hardware action for `product_ux` matches the current Nearby Messages UX
evidence surface. The recommended action now requires target-device UX
evidence with selected-detail copy and a ready `LocalInboxUxEvidenceReview`
with `coverage_summary` coverage before any product-facing release wording.

The blocker matrix still keeps `product_ux` as `partial` and keeps
whole-project completion claims blocked. This change only aligns the planning
surface with the readiness and completion audit wording added in M1431-M1435;
it does not satisfy the target-device evidence gate.

This is a blocker-matrix wording and audit-surface change only. It does not
render UI, drive devices, scan, advertise, fetch envelopes, resolve beacon
refs, route, ACK, retry, persist, encrypt, authenticate, run background work,
or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1441-M1445 product UX validation plan artifact

M1441-M1445 adds `mix mob.node.local_inbox.ux_validation_plan` so the
Nearby Messages on-device UX validation checklist can be emitted and archived
directly before operator-supplied screenshots, notes, and UX review metadata
are attached. The task reports open gates for the target-device matrix, state
coverage, interaction coverage, blocked-claim copy review, and visual-density
review, while keeping production UX claims blocked.

`LocalInboxUxEvidenceManifest`, `LocalProjectCompletionAudit`, and
`LocalReleaseArtifactBundle` now list the validation-plan command as a
required product UX artifact. This makes the target-device checklist visible
in release and completion workflows without counting it as on-device evidence.

This is an artifact/task wiring change only. It does not render UI, drive
devices, scan, advertise, fetch envelopes, resolve beacon refs, route, ACK,
retry, persist, encrypt, authenticate, run background work, or approve
production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1446-M1450 persistence lifecycle plan artifact

M1446-M1450 adds `mix mob.node.local_persistence.lifecycle_plan` so the
production-default local inbox persistence checklist can be emitted and
archived directly before operator-supplied lifecycle evidence is reviewed.
The task reports the current `memory_only` default, six blocked lifecycle
gates, and the first missing decision evidence while keeping default
persistence claims blocked.

`LocalPersistenceEvidenceManifest`, `LocalProjectCompletionAudit`, and
`LocalReleaseArtifactBundle` now list the lifecycle-plan command as a required
persistence artifact. This makes the default-decision, schema-migration,
scheduled-cleanup, background-safe-writer, on-device-restore, and release
artifact gates visible in release and completion workflows without promoting
opt-in durable snapshots to production-default behavior.

This is an artifact/task wiring change only. It does not save, restore,
migrate, prune, schedule cleanup, write in the background, resolve beacon refs,
route, ACK, retry, encrypt, authenticate, run mobile lifecycle hooks, or
approve production-default persistence claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1451-M1455 security validation plan artifact

M1451-M1455 adds `mix mob.node.local_security.validation_plan` so the
authenticated local BLE security checklist can be emitted and archived
directly before operator-supplied release evidence is reviewed. The task
reports the current `unsigned_local_ble_observations` mode, eight blocked
security validation gates, and the first missing peer-key enrollment evidence
while keeping authenticated and trusted claims blocked.

`LocalSecurityEvidenceManifest`, `LocalProjectCompletionAudit`, and
`LocalReleaseArtifactBundle` now list the validation-plan command as a
required security artifact. This makes peer enrollment, authorship, replay
lifecycle, trust lifecycle, canonical replay, beacon authentication, release
evidence, and negative claim review gates visible in release and completion
workflows without promoting current BLE hashes to proof of authorship.

This is an artifact/task wiring change only. It does not create keys, persist
trust, persist replay state, fetch envelopes, route, ACK, retry, encrypt,
authenticate BLE observations, run background work, or approve trusted-message
or trusted-delivery claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1456-M1460 routing validation plan artifact

M1456-M1460 adds `mix mob.node.local_routing.validation_plan` so the
production routing hardware validation checklist can be emitted and archived
directly before operator-supplied routing evidence is reviewed. The task
reports the current `advert_only_non_routing` mode, eight blocked routing
validation gates, and the first missing route-table evidence while keeping
route selection, forwarding, and routed-delivery claims blocked.

`LocalRoutingEvidenceManifest`, `LocalProjectCompletionAudit`, and
`LocalReleaseArtifactBundle` now list the validation-plan command as a
required routing artifact. This makes route table, deterministic selection,
forwarding, delivery semantics, multi-hop hardware, TTL/loop, release
evidence, and negative claim review gates visible in release and completion
workflows without turning route candidates into forwarding behavior.

This is an artifact/task wiring change only. It does not route, forward, scan,
advertise, persist, ACK, retry, fetch, encrypt, authenticate, run background
work, or approve route-selection, forwarding, routed-delivery, ACK/retry, or
multi-hop hardware routing claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no forwarding, no
multi-hop hardware claim, no full-message resolution claim, no background
operation claim, no iOS parity claim, no production-default persistence
behavior, and no crypto behavior.

## M1461-M1465 lifecycle validation plan artifact

M1461-M1465 adds `mix mob.node.local_lifecycle.validation_plan` so the
mobile BLE lifecycle hardware validation checklist can be emitted and archived
directly before operator-supplied lifecycle evidence is reviewed. The task
reports the current `foreground_manual` mode, eight blocked lifecycle gates,
and the first missing target-device matrix evidence while keeping Android
foreground-service, Android background BLE, iOS background BLE, restart,
scheduled retry, background gossip, and background delivery claims blocked.

`LocalLifecycleEvidenceManifest`, `LocalProjectCompletionAudit`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now list the
validation-plan command as a required lifecycle artifact. This makes target
device matrix, foreground service, background BLE policy, restart and
cancellation, scheduled retry bounds, background gossip limits, and negative
claim review gates visible in release and completion workflows without
starting services or changing mobile lifecycle behavior.

This is an artifact/task wiring change only. It does not start Android
services, request iOS background modes, schedule retries, scan, advertise,
gossip, route, persist, ACK, retry, fetch, encrypt, authenticate, run
background work, or approve background lifecycle wording.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no forwarding, no
multi-hop hardware claim, no full-message resolution claim, no background
operation claim, no iOS parity claim, no production-default persistence
behavior, and no crypto behavior.

## M1466-M1470 release UX validation-plan anchor

M1466-M1470 threads `mix mob.node.local_inbox.ux_validation_plan` through
`LocalReleaseManifest.required_commands` and adds a `ux_validation_plan`
required artifact beside the existing Nearby Messages UX evidence and review
artifacts. This aligns the release manifest with the completion audit,
`LocalInboxUxEvidenceManifest`, and `LocalReleaseArtifactBundle` so every
release checklist can archive the target-device UX validation checklist before
operator screenshots, notes, and review metadata are considered.

This is a release-artifact wiring change only. It does not render UI, drive
devices, scan, advertise, fetch envelopes, resolve beacon refs, route, ACK,
retry, persist, encrypt, authenticate, run background work, or approve
production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1471-M1475 Nearby Messages selected-detail UX review

M1471-M1475 strengthens `LocalInboxUxEvidenceReview` with an explicit
`selected_detail_evidence` section. Operator UX metadata must now attach a
selected-detail screenshot or note for each Nearby Messages state: full
message, unresolved ref, gossiped ref, and stale ref. The review also exposes
`selected_detail_evidence_count` and
`all_target_devices_have_selected_detail_coverage?` in `coverage_summary`, and
the `mob.node.local_inbox.ux_review` task prints those counts in the
plain-text coverage line.

This turns the existing selected-detail copy blocker into a concrete
prompt-to-artifact requirement. A single boolean copy review is no longer
enough; every target device must provide selected-detail evidence for every
local inbox state before the UX review can become ready.

This is a metadata review-contract change only. It does not render UI, drive
devices, inspect screenshot pixels, scan, advertise, fetch envelopes, resolve
beacon refs, route, ACK, retry, persist, encrypt, authenticate, run background
work, or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1476-M1480 selected-detail UX artifact wording

M1476-M1480 threads the explicit `selected_detail_evidence` review section into
Nearby Messages UX artifact wording. `LocalInboxUxEvidenceManifest`,
`LocalReleaseManifest`, and `LocalReleaseArtifactBundle` now name selected-detail
metadata alongside target-device, state, interaction, copy, and density
evidence. Release artifact acceptance criteria also call out
`coverage_summary` selected-detail coverage so operator review output can be
checked directly.

This aligns the release artifact checklist with the strengthened UX review
contract from M1471-M1475. Operator evidence must now include per-state
selected-detail artifacts or notes instead of relying on a generic detail-panel
copy checkbox.

This is an artifact wording and checklist change only. It does not render UI,
drive devices, inspect screenshot pixels, scan, advertise, fetch envelopes,
resolve beacon refs, route, ACK, retry, persist, encrypt, authenticate, run
background work, or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1481-M1485 release persistence lifecycle-plan anchor

M1481-M1485 threads `mix mob.node.local_persistence.lifecycle_plan` through
`LocalReleaseManifest.required_commands` and adds a
`production_persistence_lifecycle_plan` required artifact beside the existing
persistence evidence and production-review artifacts. This aligns the release
manifest with `LocalPersistenceEvidenceManifest` and `LocalReleaseArtifactBundle`
so every release checklist can archive the production-default persistence
checklist before operator evidence is reviewed.

`LocalReleaseCriteria` now also names the lifecycle-plan command in the durable
snapshot boundary evidence list. This keeps memory-only default policy, opt-in
durable snapshots, migration, cleanup, writer, restore, and release-evidence
gates visible without promoting durable snapshots to default app persistence.

This is a release-artifact wiring change only. It does not save, restore,
migrate, prune, schedule cleanup, write in the background, resolve beacon refs,
route, ACK, retry, persist by default, encrypt, authenticate, or approve
production-default persistence claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1486-M1490 release validation-plan anchors

M1486-M1490 threads `mix mob.node.local_routing.validation_plan` and
`mix mob.node.local_security.validation_plan` through
`LocalReleaseManifest.required_commands`, and adds `routing_validation_plan`
and `security_validation_plan` required artifacts beside the existing routing
and security evidence/review artifacts. This aligns the release manifest with
`LocalRoutingEvidenceManifest`, `LocalSecurityEvidenceManifest`,
`LocalProjectCompletionAudit`, and `LocalReleaseArtifactBundle` so release
checklists archive the standalone routing and security validation plans before
operator evidence is reviewed.

`LocalReleaseCriteria` now also names both validation-plan commands in release
audit evidence. This keeps production-routing and authenticated-security gates
visible in the advert-only release boundary while preserving current blocked
routing, forwarding, trusted-message, and trusted-delivery claims.

This is a release-artifact wiring change only. It does not route, forward,
scan, advertise, persist, ACK, retry, fetch, encrypt, authenticate, run
background work, or approve route-selection, forwarding, routed-delivery,
authenticated-message, trusted-message, or trusted-delivery claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no forwarding, no
multi-hop hardware claim, no full-message resolution claim, no background
operation claim, no iOS parity claim, no production-default persistence
behavior, and no crypto behavior.

## M1491-M1495 UX artifact bundle template anchor

M1491-M1495 splits the Nearby Messages UX operator scaffold into its own
`ux_evidence_template` artifact inside `LocalReleaseArtifactBundle`. The bundle
now separately requires:

```sh
mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json
mix mob.node.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json
```

This aligns the release artifact bundle with `LocalInboxUxEvidenceManifest`
and `LocalReleaseManifest`, which already named the UX template separately from
the final review artifact. Operators can now archive the incomplete
target-device scaffold before adding screenshots or notes for full, unresolved,
gossiped, stale, selected-detail, copy-review, and density-review coverage.

This is a release-artifact packaging change only. It does not render UI, drive
devices, inspect screenshots, scan, advertise, fetch envelopes, resolve beacon
refs, route, ACK, retry, persist, encrypt, authenticate, run background work,
or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1496-M1500 UX release guide evidence checklist

M1496-M1500 tightens `docs/local_ble_release_artifact_bundle.md` so the
operator-facing release guide spells out every Nearby Messages UX template
section that must be filled before review: `target_devices`, `state_evidence`,
`interaction_evidence`, `selected_detail_evidence`, `copy_review`, and
`visual_density_review`. The guide now explicitly calls out full, unresolved,
gossiped, and stale state coverage for both row and selected-detail evidence.

The guide also names the required `coverage_summary` result from
`mix mob.node.local_inbox.ux_review --input ... --json --out ...`, including
state, interaction, selected-detail, copy-review, and density coverage before
product-facing Nearby Messages wording can be accepted.

This is an operator documentation change only. It does not render UI, drive
devices, inspect screenshots, scan, advertise, fetch envelopes, resolve beacon
refs, route, ACK, retry, persist, encrypt, authenticate, run background work,
or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1501-M1505 release candidate UX review linkage

M1501-M1505 tightens `LocalReleaseCandidateEvidenceReview` so advert-only
release-candidate evidence must include `ux_review_path` at the top level and
inside operator notes. This makes `tmp/local-inbox-ux-review.json` a required
release-candidate anchor beside readiness, completion audit, blocker matrix,
release manifest, and advert-gossip audit artifacts.

The release-candidate Mix task now prints `ux_review=true|false` in
`OPERATOR_NOTE_PATHS`, the release artifact bundle notes the UX review path in
the candidate template and operator-note criteria, and the release bundle guide
shows `ux_review_path` in the minimum review input shape. A ready release
candidate must therefore reference the reviewed Nearby Messages target-device
UX artifact before product-facing wording is accepted.

This is release evidence wiring only. It does not inspect screenshots, render
UI, drive devices, scan, advertise, fetch envelopes, resolve beacon refs, route,
ACK, retry, persist, encrypt, authenticate, run background work, or approve
production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M1526-M1530 release candidate security review gate

M1526-M1530 tightens `LocalReleaseCandidateEvidenceReview` so advert-only
release-candidate metadata must include the security release review artifact
path and a canonical `LocalSecurityReleaseEvidenceReview` summary. The summary
must be ready, identify the `local_security_release_evidence_review` boundary,
mark the security release evidence package complete, and keep authenticated
peer identity, authenticated message, trusted message, and trusted delivery
claims explicitly false.

Operator notes now cite the same `security_review_path` as the top-level
release-candidate input, and the release-candidate task prints a
`SECURITY_REVIEW` line beside persistence, UX, and artifact-path linkage. The
release bundle guide includes the security review summary in the minimum input
shape so release candidates cannot imply authenticated or trusted delivery
without carrying the blocked security review decision.

This is release evidence validation only. It does not create keys, persist
trust, persist replay state, authenticate live BLE observations, validate
trusted delivery, resolve beacon refs, fetch envelopes, route, ACK, retry,
encrypt payloads, validate hardware, or close whole-project completion.

## M1521-M1525 release candidate persistence lifecycle gate

M1521-M1525 tightens `LocalReleaseCandidateEvidenceReview` so advert-only
release-candidate metadata must include the generated persistence lifecycle
plan path and a summary of the production-default persistence plan. The summary
must preserve the current `memory_only` default, show opt-in durable snapshots
as available, keep `production_default_persistence_allowed?` and
`default_lifecycle_claim_allowed?` false, and report every production-default
persistence gate as blocked.

Operator notes now cite the same `persistence_lifecycle_plan_path` as the
top-level evidence input, and the release-candidate task prints a
`PERSISTENCE_LIFECYCLE` line beside UX and artifact-path linkage. The release
bundle guide includes the persistence lifecycle summary in the minimum input
shape so release candidates cannot imply default durable storage without
carrying the blocked lifecycle decision.

This is release evidence validation only. It does not enable default
persistence, write snapshots automatically, schedule cleanup, migrate data,
restore on app restart, run background writers, resolve beacon refs, create
delivery records, route, ACK, retry, encrypt, authenticate, validate hardware,
or close whole-project completion.

## M1516-M1520 release candidate UX review identity gate

M1516-M1520 tightens `LocalReleaseCandidateEvidenceReview` so the supplied UX
summary has to carry the canonical Nearby Messages review identity, not only
ready-looking coverage booleans. Release-candidate UX metadata now requires
`review_version: 1`, the `nearby_messages_on_device_ux_evidence` boundary,
`on_device_ux_evidence_complete?: true`, and explicit false delivery, trusted
delivery, routing, and production-UX claim flags from the UX review output.

The release-candidate template and release bundle guide now show those fields
beside the existing UX review path and coverage summary. This keeps the
release candidate linked to the `LocalInboxUxEvidenceReview` contract while
still avoiding file reads, screenshot inspection, UI automation, or any
promotion of UX evidence into delivery proof.

This is release evidence validation only. It does not create target-device UX
evidence, inspect screenshots, approve product UX, scan, advertise, fetch,
resolve beacon refs, route, ACK, retry, persist, encrypt, authenticate, run
background work, validate iOS parity, or close whole-project completion.

## M1511-M1515 release candidate path consistency gate

M1511-M1515 tightens `LocalReleaseCandidateEvidenceReview` so operator notes
must not only cite the required release artifacts, but cite the same artifacts
as the top-level release-candidate evidence input. The readiness manifest,
completion audit, completion blocker matrix, release manifest, and UX review
paths now fail the review when an operator-note value drifts from the
corresponding top-level path.

The release bundle guide now calls out this exact path-matching requirement
beside the minimum review input. This keeps release-candidate notes anchored to
the archived evidence bundle instead of allowing stale copied paths to satisfy
the presence checks.

This is release evidence validation only. It does not inspect hardware logs,
screenshots, or artifact contents, and it does not approve product UX,
whole-project completion, full-message resolution, routing, GATT fetch,
multi-hop hardware delivery, persistence, crypto, iOS parity, or background
mobile operation.

## M1506-M1510 release candidate UX coverage summary gate

M1506-M1510 tightens `LocalReleaseCandidateEvidenceReview` again so a bare
`ux_review_path` is not enough for release-candidate readiness. Operator
metadata must now include a `ux_review` summary with `status: :ready`, a
positive `target_device_count`, and true coverage flags for state coverage,
interaction coverage, selected-detail coverage, copy review, and visual-density
review.

The release-candidate Mix task now prints `UX_REVIEW status=... targets=...`
with selected-detail coverage, `LocalReleaseArtifactBundle` names the ready UX
review summary in candidate-template and operator-note criteria, and the
release bundle guide includes the required `ux_review` summary shape. This
keeps product-facing Nearby Messages wording tied to a reviewed target-device
UX artifact instead of only to a path string.

This is release evidence validation only. It does not inspect screenshots,
render UI, drive devices, scan, advertise, fetch envelopes, resolve beacon
refs, route, ACK, retry, persist, encrypt, authenticate, run background work,
or approve production UX claims.

This milestone adds no hardware evidence, no release approval, no completion
claim, no delivery claim, no trust claim, no routing, no multi-hop hardware
claim, no full-message resolution claim, no background operation claim, no iOS
parity claim, no production-default persistence behavior, and no crypto
behavior.

## M876-M880 release manifest completion review summary

M876-M880 updates the plain-text
`mix mob.node.local_release.manifest` output so it reports the embedded
completion review counts: prompt checklist size, hardware-blocked objective
count, and no-new-hardware objective count. The JSON release manifest already
embeds the completion audit and blocker matrix; this makes the non-JSON release
summary expose the same completion-review shape.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M871-M875 release candidate review path summary

M871-M875 updates the plain-text
`mix mob.node.local_release.candidate_review` output so it reports whether
operator notes include the required readiness, completion audit, blocker
matrix, and release manifest paths. The JSON review already carries the
operator notes struct; this makes the non-JSON status output show the release
artifact anchors that prevent advert-only release notes from skipping open
completion evidence.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M866-M870 release candidate blocker matrix notes linkage

M866-M870 tightens `LocalReleaseCandidateEvidenceReview` so operator release
notes must cite `completion_blocker_matrix_path` alongside readiness,
completion audit, and release manifest paths. This keeps the hardware-blocked
versus no-new-hardware objective split visible in the release-note review, not
only in the top-level artifact bundle.

The review remains metadata-only and still cannot close hardware, transport,
delivery, routing, trust, persistence, lifecycle, iOS parity, or release gates.
This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M861-M865 release artifact blocker matrix group linkage

M861-M865 tightens the release artifact bundle checklist so the standalone
completion blocker matrix artifact must expose the plain-text
`HARDWARE_BLOCKED` and `NO_NEW_HARDWARE` objective groups. The human bundle
docs now call out the same review requirement, keeping physical blockers
separate from product, planning, and release-evidence work during advert-only
release packaging.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M856-M860 blocker matrix task objective summary

M856-M860 updates the plain-text
`mix mob.node.local_completion.blocker_matrix` output so it reports the
objective IDs in each planning lane: hardware-blocked objectives and objectives
that can still progress without new hardware. The JSON matrix already carries
these lists; the text summary now makes the same distinction visible during
operator status checks.

The blocker matrix remains planning evidence only. It does not close hardware,
transport, delivery, routing, trust, persistence, lifecycle, iOS parity, or
release gates. This milestone adds no BLE behavior, no hardware success claim,
no completion claim, no full-message resolution, no routing, no forwarding, no
background service, no persistence behavior, no trusted-message behavior, no
ACKs, no retries, no fragmentation, and no crypto behavior.

## M851-M855 release artifact prompt checklist linkage

M851-M855 tightens the release artifact bundle checklist so the standalone
completion audit artifact must expose both the full JSON
`prompt_artifact_checklist` and the plain-text `PROMPT_CHECKLIST` objective
spine. The human release bundle docs now call out the same requirement, so an
advert-only release candidate cannot archive the completion audit file while
skipping review of the ordered remaining-objective map.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M846-M850 completion audit task prompt checklist summary

M846-M850 updates the plain-text
`mix mob.node.local_completion.audit --allow-open` output so it reports
the `prompt_artifact_checklist` count and ordered objective IDs. The JSON
artifact already carries the full checklist; this makes the non-JSON operator
summary show the same canonical remaining-work spine without requiring a full
JSON inspection.

The task still fails by default while completion is blocked and still requires
`--allow-open` for status/reporting use. This milestone adds no BLE behavior,
no hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no persistence behavior, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no crypto
behavior.

## M841-M845 completion audit prompt checklist regression hardening

M841-M845 tightens `LocalProjectCompletionAuditTest` so the
`prompt_artifact_checklist` must stay in exact objective order with
`items`, and every checklist entry must carry a prompt requirement,
current evidence, required artifacts, missing evidence, and verification
commands. This keeps the machine-readable "what remains" answer aligned
with the whole-project completion audit instead of allowing a stale or
partial prompt checklist to drift from the canonical objective list.

The audit still reports whole-project completion as false and keeps every
blocked or partial objective open. This milestone adds no BLE behavior, no
hardware success claim, no completion claim, no full-message resolution, no
routing, no forwarding, no background service, no persistence behavior, no
trusted-message behavior, no ACKs, no retries, no fragmentation, and no
crypto behavior.

## M836-M840 release candidate hardware attachment evidence-type hardening

M836-M840 tightens `LocalReleaseCandidateEvidenceReview` so every hardware
attachment cited in an advert-only local release candidate must declare the
expected evidence type for each hardware gate it references. The required
release gate evidence types are explicit: Android legacy beacon gossip
summary, Android full-envelope advert summary, standalone GATT interop log,
multi-hop hardware log, and iOS advert-only hardware log.

The review still only validates operator-supplied metadata shape and wording.
It keeps whole-project completion false, keeps open hardware gates open, and
prevents a generic log attachment from standing in for a gate-specific hardware
evidence record.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

## M831-M835 iOS parity hardware review evidence-type hardening

M831-M835 tightens `LocalIOSParityHardwareEvidenceReview` so every iOS parity
hardware gate must declare the expected evidence type: target iOS device
matrix, canonical ingress fixture, legacy beacon observe hardware, legacy
beacon gossip hardware, full-envelope capability probe, hardware replay
fixture, iOS background BLE boundary, or iOS parity negative fixture matrix.
This keeps Android evidence, bridge-shell structure, and generic artifacts from
being reviewed as iOS advert-only participation proof.

The review remains metadata-only and keeps iOS participation, iOS hardware,
legacy beacon observe/gossip, full-envelope advert, background BLE, and iOS
parity claims blocked. It does not add an iOS scanner, advertiser, dispatcher,
background BLE mode, replay fixture, route, fetch, persistence, ACK, retry,
encryption, authentication, or hardware claim.

This milestone adds no BLE behavior, no hardware success claim, no completion
claim, no full-message resolution, no routing, no forwarding, no background
service, no persistence behavior, no trusted-message behavior, no ACKs, no
retries, no fragmentation, and no crypto behavior.

### What M17–M19 deliberately didn't do

At that stage there was no real BLE send; the simulated transport was
the only delivery path. It added no queue, retry, persistence, crypto,
handshake, or Android/iOS changes. M20-M27 now exercise the real
Android BLE path while preserving the same
`[Attempt] -> [AttemptOutcome]` contract shape and `adapter:
:ble_android` outcome evidence. Android's verifier-facing
`attempt_outcome` JSON now carries the same core provenance:
`attempt_id`, base64 `message_id`, `target_peer_id`,
`target_device_ids`, `kind`, `reason`, `adapter`, and `outcome_at_ms`.
Before touching the radio, Android dispatch also rejects attempts whose
caller `messageId` disagrees with the M14 envelope or whose non-broadcast
envelope recipient disagrees with `targetPeerId`.

## Behavior NOT implemented yet

Items deliberately deferred. Stating them here so future PRs don't
accidentally claim them as already-landed BLE transport behavior:

- **Routing.** No multi-hop forwarding, no mesh topology, no path
  selection. The runtime sees peers; it doesn't route through them.
- **Crypto transport.** No Noise handshake on the wire, no session
  keys, no AEAD-encrypted payloads. The `Identity.Claim` schema
  reserves `:fingerprint` and `:signed_identity` source values for
  this work but no code path produces them today.
- **Active handshake.** `Mob.Node.BLE.Events.PeerAuthenticated`
  exists in the contract but no bridge emits it. The iOS Swift Noise
  harness is wired into the simulator build but not surfaced through
  the NIF.
- **Automatic persistence integration.** M106-M110 adds an explicit
  durable local-inbox snapshot store, but there is still no automatic
  write loop, background writer, migration system, cleanup worker, or
  sync. The peer table, inventory, presence, churn lists, and active
  local inbox still live in memory and reset with the BEAM unless a
  caller explicitly saves a policy-approved local inbox snapshot.
- **Reconnect orchestration.** No exponential backoff, no retry
  policy, no "I haven't seen this peer in N seconds, attempt to
  reconnect." The runtime observes; it doesn't act.
- **Background services.** No Android foreground service, no iOS
  background mode wiring, no sustained scanning across app
  backgrounding. The bring-up app scans while it's open and stops
  when it isn't.
- **Connection-state lifecycle on Android.** `ConnectionStateChanged`
  is in the canonical contract but Kotlin doesn't emit it. The
  Android transport is scan + advertise only.
- **UI formatting / LiveView.** `PeerSummary` is plain data. No
  template, no time-since-now rendering, no badge styling. UI
  consumers own all formatting.
- **`DeviceLost` emission.** The event type exists; Android's
  staleness window for lost-device pruning is not implemented.
  Today's "lost" semantic comes from `:expired` in `PresencePolicy`.
- **JSON read API endpoint.** The shape is ready; no HTTP surface
  yet.
- **Multi-transport.** Only BLE today. Adding WiFi Direct / LAN
  would mean a second transport adapter implementing
  `BLE.Adapter` — but the namespacing would need a rename.

## Test inventory

- Elixir full umbrella and targeted BLE suites are tracked by the latest
  regression pass below.
- Android Gradle full and targeted BLE unit tests are tracked by the
  latest regression pass below.
- Swift package coverage is tracked by the latest package or targeted
  regression pass below.
- M23–M27 Android-to-macOS delivery proof:
  `docs/android_ble_message_delivery_validation.md`
- M23–M27 two-Android verifier fixtures:
  `scripts/test_android_ble_message_delivery_two_device.sh`
- M23–M27 M26 completion gate:
  `scripts/audit_android_ble_message_delivery_completion.sh`; the gate
  checks summary state, required device metadata, the complete current
  validation schema, self-identifying `summary_json` provenance,
  an existing `summary_markdown` ledger artifact, distinct role log files,
  and explicit logcat-capture success for both roles;
  rejects checked-in fixture logs, exact fixture-content copies, and known
  synthetic fixture identities, plus copied or renamed summaries whose
  embedded `summary_json` does not match the audited path or whose
  `summary_markdown` file is missing; and re-runs the two-device verifier
  over the referenced sender/observer logs.
- Latest M23-M27 regression pass, 2026-05-12: full umbrella `mix test`
  passed with 509 tests and 11 properties, Elixir BLE targeted suites
  passed with 84 tests, Android Gradle unit tests passed, targeted
  Android BLE class filters passed through `testDebugUnitTest`, Swift
  `MessageAdvertisementTests` passed with 5 tests, and the two-device
  verifier fixture suite, shell syntax checks, and ShellCheck passed.
  Latest focused non-goal recheck: `mix test
  apps/mob_node/test/mob_node/ble/peer_table_test.exs`
  passed with 26 tests and proves `ReceivedMessage` does not create or
  mutate peer graph entries.
  Latest focused receive/replay recheck: `mix test
  apps/mob_node/test/mob_node/ble/message_advertisement_test.exs
  apps/mob_node/test/mob_node/ble/replay_test.exs
  apps/mob_node/test/mob_node/ble/bridge_protocol_test.exs`
  passed with 54 tests and covers M23/M24 message advertisement decode,
  tagged malformed-advert errors, raw payload preservation, and replay
  of canonical `received_message` fixtures without hardware.
  Latest focused M24 wire-contract recheck: `mix test
  apps/mob_node/test/mob_node/ble/android_wire_format_test.exs`
  passed with 4 tests and covers the `received_message` fixture's
  required fields, embedded M14 envelope, and raw BLE transport metadata.
  Latest focused Swift/macOS M23/M24 recheck: `xcrun swift test --filter
  MessageAdvertisementTests` passed with 5 tests and covers M14 fixture
  parsing, every canonical `received_message` JSON-line field, raw
  transport metadata, escaped string fields, and tagged malformed
  message-advertisement errors.
  Latest focused Android M24/M25 recheck: `./gradlew --no-daemon
  testDebugUnitTest --tests dev.mob.mob.ble.MobMessageAdvertisementTest
  --tests dev.mob.mob.ble.MobMessageEnvelopeTest --tests
  dev.mob.mob.ble.BleDispatcherTest --tests
  dev.mob.mob.ble.BleScannerTest --tests dev.mob.mob.ble.BleEventTest`
  passed with `BUILD SUCCESSFUL` and covers M14 envelope payload shape,
  dispatcher outcome preservation, no-truncation budget behavior, scanner
  message promotion, every canonical Android `received_message` JSON
  field, raw transport metadata, and BLE event wire JSON.
- Current preflight artifact includes full adb inventory fields
  (`adb_inventory_device_count`, `adb_ready_device_count`,
  `adb_nonready_device_count`, `adb_inventory`) so non-ready adb rows do
  not disappear from the M26 blocker evidence.
- Live M26 summaries now include the same parsed adb inventory fields,
  and the completion audit requires live summaries to show both sender
  and observer as ready adb `device` rows in the summary and in the
  referenced `adb-devices.txt` file.
- M20–M22 on-device dispatch validation pass: `docs/android_ble_dispatch_validation.md`
- Real-hardware on-device validation pass: `docs/android_ble_validation.md`

Run:

```bash
cd apps/mob_node
mix test                          # Elixir, full suite
cd android && ./gradlew test      # Kotlin, JVM unit tests
cd ../../../mob_node
xcrun swift test                  # Swift package tests
```
