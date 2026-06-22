# Claude Code — mob mesh

Use the shared agent guides in this repo (not generic Elixir defaults alone):

- **[AGENTS.md](AGENTS.md)** — umbrella layout, mandatory `mix mob.node.guardrails`, production wiring contracts
- **[apps/mob_node/AGENTS.md](apps/mob_node/AGENTS.md)** — MobNode BLE, session, chat, deploy, pitfalls

Before changing router/BLE/chat wiring, run guardrails and extend the tests listed in `AGENTS.md`.