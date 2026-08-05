# Target status

Last updated: 2026-08-05

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | Golden Balloon WebGPU; headless+input script; N64 intro / menus |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass*** | **pass** | WebGPU on sim GPU; Rareware intro; touch overlay compiled in |
| iPad Simulator | **pass** | **pass** | **pass** | **pass*** | **pass** | Same binary; tablet layout helpers; intro render |

\* Touch overlay is built into the iOS app and initialized on window create. Virtual joystick + DKR key map unit-tested. Full physical-thumb Grand Prix not claimed.

Statuses: `pending` → `wip` → `pass` / `fail` / `blocked`.
