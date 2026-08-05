#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/* On iOS: if MDKR_ROM is unset, look under the app Documents container for a
 * DKR ROM (*.v64 / *.z64 / *.n64), prefer diddy-kong-racing.v64. When found,
 * sets MDKR_ROM (and MDKR_APP_AUTOPLAY=1 if not already set) so the interactive
 * AppHost boots into the game with touch controls still active.
 * Returns 1 if a ROM path was resolved, 0 otherwise. */
int ChimpPad_PrepareIosRomBoot(void);

/* Returns the last resolved absolute ROM path (or NULL). */
const char *ChimpPad_ResolvedRomPath(void);

#ifdef __cplusplus
}
#endif
