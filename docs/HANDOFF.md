# Handoff / status

**Date:** 2026-08-05  
**Repo:** `/Users/chrissotraidis/GitHub/chimppad`

## What works

- `docs/` skeleton (architecture, dependencies, build, ROM policy, status, evidence, issues, handoff).
- `.gitignore` protects ROM, assets, build trees.
- `ref/diddy-kong-racing` cloned and pinned (`c669570…`).
- `ref/goldenballoon` cloned and pinned (`6fc93d8…`) as the native game host.
- `ref/spaghettipad` retained as Apple-port reference.
- Local US 1.1 V64 ROM present under `ref/` (gitignored; not committed).

## What does not work yet

- ChimpPad app targets not yet built/launched.
- Touch control implementation not yet landed.
- No multi-target play evidence yet.

## Next highest-priority task

1. Build Golden Balloon on macOS with the local ROM; capture launch/render/input evidence.
2. Scaffold ChimpPad iOS shell + DKR touch mapping; Simulator smokes one device at a time.
3. Keep docs current; focused commits.

## How to resume

1. Read this file, then [ARCHITECTURE.md](ARCHITECTURE.md) and [DEPENDENCIES.md](DEPENDENCIES.md).
2. Follow [BUILDING.md](BUILDING.md).
3. Check [STATUS.md](STATUS.md) and [EVIDENCE.md](EVIDENCE.md) before re-running smokes.
4. Never commit or redistribute the ROM ([ROM_POLICY.md](ROM_POLICY.md)).
