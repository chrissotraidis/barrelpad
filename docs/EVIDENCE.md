# Test evidence ledger

Append-only style entries. Agent scratch holds raw logs/screenshots; durable
summaries live here and under `docs/evidence/` when intentionally committed
(no ROM bytes).

## Template

```text
### YYYY-MM-DD — <target>
- Commands:
- Logs: {SCRATCH}/...
- Screenshots:
- Gameplay checks:
- Outcome: pass | fail | blocked
- Notes:
```

## Entries

### 2026-08-05 — bootstrap
- Commands: clone decomp + goldenballoon; create docs skeleton
- Outcome: docs/ref setup only; no play smoke yet
