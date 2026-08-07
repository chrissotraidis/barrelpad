#!/usr/bin/env python3
"""Idempotently ensure platform_ios_touch_set exists in goldenballoon sources."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "sources" / "goldenballoon"
os_h = SRC / "platform" / "platform_os.h"
sdl = SRC / "platform" / "platform_sdl_min.c"
if not os_h.is_file() or not sdl.is_file():
    print(f"missing platform files under {SRC}", file=sys.stderr)
    sys.exit(1)

os_text = os_h.read_text()
if "platform_ios_touch_set" not in os_text:
    needle = "void         platform_pad_stick(int port, int *sx, int *sy);\n"
    insert = (
        needle
        + "/* BarrelPad iOS: direct P1 pad injection (N64 button bits + ±80 stick). */\n"
        + "void         platform_ios_touch_set(unsigned int buttons, int stick_x, "
        + "int stick_y, int enabled);\n"
    )
    if needle not in os_text:
        print("platform_os.h: cannot find pad_stick decl", file=sys.stderr)
        sys.exit(1)
    os_h.write_text(os_text.replace(needle, insert, 1))
    print("[BarrelPad] declared platform_ios_touch_set in platform_os.h")
else:
    print("[BarrelPad] platform_os.h already has platform_ios_touch_set")

sdl_text = sdl.read_text()
changed = False

if "s_iosTouchSource" not in sdl_text:
    m = re.search(r"static Uint8 s_keyboardDown\[SDL_NUM_SCANCODES\];\n", sdl_text)
    if not m:
        print("platform_sdl_min.c: cannot find s_keyboardDown", file=sys.stderr)
        sys.exit(1)
    block = (
        m.group(0)
        + "/* BarrelPad iOS touch pad — merged into P1 like the browser touch path. */\n"
        + "static struct pad_state s_iosTouchSource;\n"
        + "static int s_iosTouchEnabled;\n"
    )
    sdl_text = sdl_text[: m.start()] + block + sdl_text[m.end() :]
    changed = True
    print("[BarrelPad] added s_iosTouchSource state")

FUNC = r"""
void platform_ios_touch_set(unsigned int buttons, int stick_x, int stick_y, int enabled) {
    static unsigned int s_lastLoggedButtons = 0xFFFFFFFFu;
    static int s_lastLoggedEnabled = -1;
    s_iosTouchEnabled = enabled ? 1 : 0;
    if (!enabled) {
        s_iosTouchSource.buttons = 0;
        s_iosTouchSource.stick_x = 0;
        s_iosTouchSource.stick_y = 0;
        s_iosTouchSource.present = 0;
        if (s_lastLoggedEnabled != 0) {
            fprintf(stderr, "[BarrelPad] ios_touch disabled\n");
            s_lastLoggedEnabled = 0;
            s_lastLoggedButtons = 0;
        }
        return;
    }
    if (stick_x < -80) stick_x = -80;
    if (stick_x > 80) stick_x = 80;
    if (stick_y < -80) stick_y = -80;
    if (stick_y > 80) stick_y = 80;
    s_iosTouchSource.buttons = buttons;
    s_iosTouchSource.stick_x = stick_x;
    s_iosTouchSource.stick_y = stick_y;
    s_iosTouchSource.present = 1;
    if (s_lastLoggedEnabled != 1 || s_lastLoggedButtons != buttons) {
        fprintf(stderr,
                "[BarrelPad] ios_touch set buttons=0x%04x stick=%d,%d\n",
                buttons, stick_x, stick_y);
        s_lastLoggedEnabled = 1;
        s_lastLoggedButtons = buttons;
    }
}

/* Diagnostic: MDKR_IOS_FORCE_PAD=start|a|0xNNNN holds buttons after delay. */
static void ios_force_pad_apply(void) {
    static int s_loaded = 0;
    static unsigned int s_forceButtons = 0;
    static int s_forceDelayFrames = 120;
    static int s_forceHoldFrames = 180;
    static int s_forceAge = 0;
    if (!s_loaded) {
        const char *spec = getenv("MDKR_IOS_FORCE_PAD");
        s_loaded = 1;
        if (spec == NULL || spec[0] == '\0') {
            return;
        }
        if (strcmp(spec, "start") == 0 || strcmp(spec, "START") == 0) {
            s_forceButtons = N64_START;
        } else if (strcmp(spec, "a") == 0 || strcmp(spec, "A") == 0) {
            s_forceButtons = N64_A;
        } else if (spec[0] == '0' && (spec[1] == 'x' || spec[1] == 'X')) {
            s_forceButtons = (unsigned int)strtoul(spec, NULL, 16);
        } else {
            s_forceButtons = (unsigned int)strtoul(spec, NULL, 0);
        }
        const char *delay = getenv("MDKR_IOS_FORCE_PAD_DELAY");
        const char *hold = getenv("MDKR_IOS_FORCE_PAD_HOLD");
        if (delay && delay[0]) s_forceDelayFrames = atoi(delay);
        if (hold && hold[0]) s_forceHoldFrames = atoi(hold);
        fprintf(stderr,
                "[BarrelPad] ios_force_pad buttons=0x%04x delay=%d hold=%d\n",
                s_forceButtons, s_forceDelayFrames, s_forceHoldFrames);
    }
    if (s_forceButtons == 0) {
        return;
    }
    s_forceAge++;
    if (s_forceAge < s_forceDelayFrames) {
        return;
    }
    if (s_forceAge > s_forceDelayFrames + s_forceHoldFrames) {
        if (s_iosTouchSource.buttons & s_forceButtons) {
            s_iosTouchSource.buttons &= ~s_forceButtons;
            fprintf(stderr, "[BarrelPad] ios_force_pad release 0x%04x\n",
                    s_forceButtons);
        }
        return;
    }
    if ((s_iosTouchSource.buttons & s_forceButtons) != s_forceButtons) {
        s_iosTouchEnabled = 1;
        s_iosTouchSource.buttons |= s_forceButtons;
        s_iosTouchSource.present = 1;
        fprintf(stderr, "[BarrelPad] ios_force_pad press 0x%04x age=%d\n",
                s_forceButtons, s_forceAge);
    }
}

static void ios_touch_merge(const struct pad_state *touch, struct pad_state *p) {
    unsigned int buttons = touch->buttons;
    int stickX = touch->stick_x;
    int stickY = touch->stick_y;
    if (stickX < -24) buttons |= N64_DL;
    if (stickX >  24) buttons |= N64_DR;
    if (stickY < -24) buttons |= N64_DD;
    if (stickY >  24) buttons |= N64_DU;
    p->buttons |= buttons;
    if (abs(stickX) > abs(p->stick_x)) p->stick_x = stickX;
    if (abs(stickY) > abs(p->stick_y)) p->stick_y = stickY;
    if (touch->present) {
        p->present = 1;
    }
}
"""

if "void platform_ios_touch_set" not in sdl_text:
    anchor = "static void input_clear_game_sources(void)"
    if anchor not in sdl_text:
        anchor = "static void input_capture_live(uint64_t target_tick)"
    if anchor not in sdl_text:
        print("platform_sdl_min.c: cannot find insert anchor", file=sys.stderr)
        sys.exit(1)
    sdl_text = sdl_text.replace(anchor, FUNC + "\n" + anchor, 1)
    changed = True
    print("[BarrelPad] inserted platform_ios_touch_set + ios_touch_merge")
elif "ios_force_pad_apply" not in sdl_text:
    pat = re.compile(
        r"void platform_ios_touch_set\(unsigned int buttons, int stick_x, "
        r"int stick_y, int enabled\) \{.*?\n"
        r"static void ios_touch_merge\(const struct pad_state \*touch, "
        r"struct pad_state \*p\) \{.*?\n\}",
        re.S,
    )
    if pat.search(sdl_text):
        sdl_text = pat.sub(FUNC.strip(), sdl_text, count=1)
        changed = True
        print("[BarrelPad] upgraded platform_ios_touch_set + force pad")
    else:
        print("[BarrelPad] platform_ios_touch_set present (left as-is)")
else:
    print("[BarrelPad] platform_ios_touch_set already current")

MERGE = """#if defined(__APPLE__)
            /* BarrelPad: merge iOS touch pad into P1 after keyboard/controller. */
            if (port == 0) {
                ios_force_pad_apply();
                if (s_iosTouchEnabled) {
                    ios_touch_merge(&s_iosTouchSource, &live);
                }
            }
#endif
"""
# Prefer upgraded merge block
if "ios_force_pad_apply()" not in sdl_text:
    old_merge = """#if defined(__APPLE__)
            /* BarrelPad: merge iOS touch pad into P1 after keyboard/controller. */
            if (port == 0 && s_iosTouchEnabled) {
                ios_touch_merge(&s_iosTouchSource, &live);
            }
#endif
"""
    if old_merge in sdl_text:
        sdl_text = sdl_text.replace(old_merge, MERGE, 1)
        changed = True
        print("[BarrelPad] upgraded ios_touch_merge call site with force pad")
    elif "ios_touch_merge(&s_iosTouchSource" not in sdl_text:
        needle = (
            "            if (s_gc[port] != NULL) {\n"
            "                gc_read(&s_controllerSource[port], &live);\n"
            "            }\n"
        )
        if needle not in sdl_text:
            print("platform_sdl_min.c: cannot find gc_read call site", file=sys.stderr)
            sys.exit(1)
        sdl_text = sdl_text.replace(needle, needle + MERGE, 1)
        changed = True
        print("[BarrelPad] wired ios_touch_merge into input_capture_live")
    else:
        print("[BarrelPad] ios_touch_merge present without force pad upgrade path")
else:
    print("[BarrelPad] ios_force_pad_apply already wired")

if changed:
    sdl.write_text(sdl_text)
    print("[BarrelPad] wrote", sdl)
else:
    print("[BarrelPad] platform_sdl_min.c unchanged")
