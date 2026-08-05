# Reference checkouts

Do not commit ROMs or large third-party trees.

```sh
../scripts/clone-refs.sh
```

Expected local (gitignored) entries:

| Path | Purpose |
|---|---|
| `spaghettipad/` | Apple-port pattern reference |
| `diddy-kong-racing/` | Upstream decomp (pinned in docs/DEPENDENCIES.md) |
| `goldenballoon/` | Native DKR host (pinned) |
| `*.v64` / `*.z64` | Local ROM only — never commit |

Pins and setup: [docs/DEPENDENCIES.md](../docs/DEPENDENCIES.md).
