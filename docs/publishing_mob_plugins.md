# Publishing the `mob_*` transport plugins to Hex

Status as of this writing: none of `mob_transport`, `mob_ble`, `mob_cellular`,
`mob_wifi`, `mob_mesh` are on Hex yet (`mob` itself is). All five carry
publish-grade metadata (version, description, `source_url`, Apache-2.0 licence,
links, `files`, CHANGELOG/LICENSE/README).

## The one gotcha: publish from a STANDALONE clone, not from the umbrella

`mob_cellular`, `mob_wifi`, and `mob_mesh` resolve their `mob_transport`
dependency conditionally:

```elixir
defp transport_dep do
  if File.exists?(Path.expand("../mob_transport/mix.exs", __DIR__)),
    do: [{:mob_transport, in_umbrella: true}],   # inside this umbrella
    else: [...]                                   # standalone
end
```

Inside the umbrella, `../mob_transport/mix.exs` exists, so the dep resolves to
`in_umbrella: true`. **`mix hex.publish` rejects `in_umbrella`, `git:` and
`path:` deps.** So you must publish each package from a *standalone* checkout
(a fresh `git clone` of the package repo, outside `apps/`), where the sibling
isn't present and `transport_dep/0` takes the `else` branch.

Always inspect the built tarball's deps before pushing:

```sh
mix hex.build            # then check the printed "Dependencies" list
# or: mix hex.build && tar -xzOf <pkg>-<ver>.tar metadata.config | grep -A20 requirements
```

## Publish order

`mob_transport` is the shared contract, so it goes first; `mob_mesh` is last
because it has a hard runtime dependency on `Mob.Transport.Adapter`.

1. **`mob_transport` 0.1.0** — deps are `telemetry` only (+ dev tools).
   Publishable now. Publish first.
2. **`mob_ble` 0.1.0** — no `mob_*` deps at all (self-contained, defines its own
   `Mob.Ble.Bridge`). Publishable now, independent of step 1.
3. **`mob_cellular` 0.2.0** and **`mob_wifi` 0.2.0** — structural
   `Mob.Transport` conformance, *no* hard dep (the consumer supplies
   `mob_transport`). From a standalone clone `transport_dep/0` → `[]`, so the
   tarball declares no `mob_transport` dep. Publishable after/independent of
   step 1.
   - Optional: once `mob_transport` is on Hex, change the `else` branch to
     `{:mob_transport, "~> 0.1"}` for ecosystem discoverability.
4. **`mob_mesh` 0.1.0** — BLOCKED until step 1 lands on Hex. Mesh calls
   `Mob.Transport.Adapter.{start_link,send_frame,stop}` at runtime, and its
   standalone `else` branch is currently `{:mob_transport, github: ...}` — a
   **git dep hex.publish will reject**. After `mob_transport` is published,
   change that `else` branch to `{:mob_transport, "~> 0.1"}`, commit, then
   publish.

## Per-package checklist (run in the standalone clone)

```sh
mix deps.get
mix compile --warnings-as-errors
mix test
mix hex.build           # verify deps list has NO in_umbrella/git/path entries
mix docs                # optional, confirms ex_doc builds
mix hex.publish         # requires `mix hex.user auth` / HEX_API_KEY
git tag v<version> && git push --tags
```

## Notes

- `mob_transport` has 2 tests (`AdapterTest` / `SupervisorTest`) that can flake
  under heavy *concurrent umbrella* load but pass cleanly in isolation
  (`cd apps/mob_transport && mix test` → 25/25). Not a publish blocker.
- Bump versions per package on subsequent releases; keep CHANGELOG entries in
  sync (each repo has its own CHANGELOG.md).
