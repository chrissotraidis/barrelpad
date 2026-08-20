#!/usr/bin/env python3
"""Regression model for PAL VI and minimap offsets on native presentation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "patches" / "goldenballoon-ios-pal-viewport.patch"


def one_player_viewport(native: bool) -> tuple[int, int, int, int]:
    video_width = 320
    video_height = 264
    apply_pal_offsets = True

    if native and apply_pal_offsets:
        video_height = 240
        apply_pal_offsets = False

    half_width = video_width // 2
    half_height = video_height // 2
    if apply_pal_offsets:
        half_height = 145

    center_x = half_width
    center_y = half_height
    if apply_pal_offsets:
        center_y -= 18
        center_x -= 4

    return (
        center_x - half_width,
        240 - (center_y + half_height),
        center_x + half_width,
        240 - (center_y - half_height),
    )


def one_player_minimap(native: bool) -> tuple[int, int, int]:
    screen_x = 135
    screen_y = -98
    marker_x_adjustment = 0
    apply_pal_offsets = True

    if native:
        apply_pal_offsets = False

    if apply_pal_offsets:
        screen_y = int(screen_y * 1.2)
        screen_x -= 4
        marker_x_adjustment -= 4

    return screen_x, screen_y, marker_x_adjustment


def main() -> None:
    retail_pal = one_player_viewport(native=False)
    native_pal = one_player_viewport(native=True)
    retail_minimap = one_player_minimap(native=False)
    native_minimap = one_player_minimap(native=True)

    assert retail_pal == (-4, -32, 316, 258), retail_pal
    assert native_pal == (0, 0, 320, 240), native_pal
    assert retail_minimap == (131, -117, -4), retail_minimap
    assert native_minimap == (135, -98, 0), native_minimap

    scaled_gutter = 2796 * (320 - retail_pal[2]) / 320
    assert round(scaled_gutter) == 35, scaled_gutter
    scaled_minimap_drop = 1290 * (native_minimap[1] - retail_minimap[1]) / 240
    assert round(scaled_minimap_drop) == 102, scaled_minimap_drop

    patch = PATCH.read_text(encoding="utf-8")
    assert "videoHeight = SCREEN_HEIGHT;" in patch
    assert "applyPalViewportOffsets = FALSE;" in patch
    assert "posX -= 4;" in patch
    assert patch.count("if (applyPalViewportOffsets)") >= 6
    assert "applyPalMinimapOffsets = FALSE;" in patch
    assert patch.count("if (applyPalMinimapOffsets)") == 3

    print(
        "PAL native viewport: PASS "
        f"(retail={retail_pal}, native={native_pal}, "
        f"2796px gutter={scaled_gutter:.2f}px, "
        f"1290px minimap drop={scaled_minimap_drop:.2f}px)"
    )


if __name__ == "__main__":
    main()
