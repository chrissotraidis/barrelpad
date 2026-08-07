#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct SDL_Window;

void BarrelPad_OnWindowCreated(struct SDL_Window *window);
int BarrelPad_TouchControlsAvailable(void);
void BarrelPad_InitializeTouchControls(void);
void BarrelPad_SetTouchControlsEnabled(int enabled);
void BarrelPad_SetGameplayActive(int active);
void BarrelPad_SetMenuVisible(int visible);
float BarrelPad_RecommendedMenuScale(void);
void BarrelPad_BeginTouchLayoutEditing(void);

/* Runtime logging helper used by shell and tests. */
void BarrelPad_Log(const char *fmt, ...);

#ifdef __cplusplus
}
#endif
