#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct SDL_Window;

void ChimpPad_OnWindowCreated(struct SDL_Window *window);
int ChimpPad_TouchControlsAvailable(void);
void ChimpPad_InitializeTouchControls(void);
void ChimpPad_SetTouchControlsEnabled(int enabled);
void ChimpPad_SetGameplayActive(int active);
void ChimpPad_SetMenuVisible(int visible);
float ChimpPad_RecommendedMenuScale(void);
void ChimpPad_BeginTouchLayoutEditing(void);

/* Runtime logging helper used by shell and tests. */
void ChimpPad_Log(const char *fmt, ...);

#ifdef __cplusplus
}
#endif
