# Target status

Last updated: 2026-08-05 (DKR game boot on all targets)

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | Input script reaches CAUTION menu; DKR frames |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | Documents ROM → autoplay → DKR; Game Select + touch overlay; before/after differ |
| iPad Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | Autoplay DKR title (START/OPTIONS) + tablet touch; `touch action=A/B/R` |

## Boot contract (iOS)

With `Documents/diddy-kong-racing.v64` present (or `MDKR_ROM` set), ChimpPad sets
`MDKR_APP_AUTOPLAY=1` and boots the game via AppHost (touch remains active).
`scripts/run-ios-sim.sh` installs the ROM and exports `SIMCTL_CHILD_MDKR_*` env.
