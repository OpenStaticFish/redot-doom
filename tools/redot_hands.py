"""Redot-chan hand-only restyling; never edits the pinned Freedoom source art.

Authored grip axes keep fingers attached to the weapon while narrowing wrists.
Skin/sleeve palettes match the supplied warm-skinned, black/red-sleeved character.
Separate removal masks and replacement layers make the final composition testable.
"""
from __future__ import annotations

from dataclasses import dataclass
import math

from build_weapon_sprites import Raster

STYLE = "Redot-chan / warm porcelain skin, slender wrists, black sleeves, red cuffs"
SKIN = ["382b37", "84545d", "ae7277", "cf9290", "eeb0a4", "f7cab5", "ffdeca", "ffeddb"]
SLEEVE = ["10111a", "191821", "24212c", "312b38", "403644"]
CUFF = ["5a242b", "9e3436", "d95049", "f47b66"]


@dataclass(frozen=True)
class Grip:
    # Source-sprite coordinates, not the shared weapon-atlas coordinates.
    region: tuple[int, int, int, int]
    knuckles: tuple[float, float]
    wrist: tuple[float, float]
    width: float
    sleeve_at: float
    skin_only: bool = False


GRIPS = {
    "punga0": [Grip((0, 0, 96, 46), (62, 19), (27, 46), .82, 31, True)],
    "pungb0": [Grip((0, 0, 90, 32), (35, 24), (-10, 38), .82, 26, True),
                Grip((150, 0, 256, 32), (190, 18), (240, 40), .82, 35, True)],
    "pungc0": [Grip((0, 0, 110, 72), (44, 27), (104, 72), .80, 52, True)],
    "pungd0": [Grip((0, 0, 208, 96), (22, 16), (203, 94), .74, 36, True)],
    "pisga0": [Grip((0, 24, 82, 92), (41, 47), (41, 92), .84, 27)],
    "pisgb0": [Grip((0, 28, 82, 96), (41, 51), (41, 96), .84, 27)],
    "pisgc0": [Grip((0, 30, 84, 100), (42, 54), (42, 100), .84, 28)],
    "pisgd0": [Grip((0, 34, 84, 106), (42, 59), (42, 106), .84, 29)],
    "pisge0": [Grip((0, 37, 86, 120), (43, 72), (43, 120), .84, 30)],
    "shtga0": [Grip((0, 49, 18, 62), (12, 54), (1, 66), .88, 7)],
    "shtgb0": [Grip((57, 42, 88, 128), (81, 59), (58, 127), .87, 53)],
    "shtgc0": [Grip((59, 65, 93, 143), (84, 89), (63, 142), .87, 36)],
    "shtgd0": [Grip((70, 66, 108, 129), (87, 83), (88, 129), .84, 31)],
}


def rgba(hex_color: str) -> bytes:
    return bytes(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + b"\xff"


def is_skin(color: bytearray) -> bool:
    # The skin's brown ramp is distinct from grey guns, green barrel highlights
    # and red sights. Spatial profiles also exclude warm metal on other weapons.
    r, g, b, a = color
    return a > 0 and r >= g + 4 and g >= b + 4


def hand_layers(source: Raster, name: str) -> tuple[Raster, Raster]:
    """Return source-space removal mask and replacement, with no gun pixels."""
    mask = Raster(source.width, source.height, bytearray(len(source.pixels)))
    hands = Raster(source.width, source.height, bytearray(len(source.pixels)))
    metal_rows = []
    for y in range(source.height):
        metal = [x for x in range(source.width)
                 if (pixel := source.pixels[(y * source.width + x) * 4:(y * source.width + x) * 4 + 4])[3]
                 and max(pixel[:3]) > 31 and max(pixel[:3]) - min(pixel[:3]) <= 3]
        metal_rows.append((min(metal), max(metal)) if metal else None)
    for grip in GRIPS.get(name, []):
        left, top, right, bottom = grip.region
        selected = set()
        for y in range(top, min(bottom, source.height)):
            for x in range(left, min(right, source.width)):
                at = (y * source.width + x) * 4
                pixel = source.pixels[at:at + 4]
                if pixel[3] and (grip.skin_only or is_skin(pixel)):
                    selected.add((x, y))
        # Include hand shadows/outline so narrowing doesn't leave floating bits
        # of the old silhouette. Protect the gun's neutral-metal row envelope.
        if not grip.skin_only:
            for y in range(top, min(bottom, source.height)):
                neighbors = [row for row in metal_rows[max(0, y - 1):y + 2] if row]
                protected = (min(row[0] for row in neighbors) - 1,
                             max(row[1] for row in neighbors) + 1) if neighbors else None
                for x in range(left, min(right, source.width)):
                    at = (y * source.width + x) * 4
                    pixel = source.pixels[at:at + 4]
                    if pixel[3] and max(pixel[:3]) <= 31 and not (protected and protected[0] <= x <= protected[1]):
                        selected.add((x, y))
        for x, y in selected:
            at = (y * source.width + x) * 4
            mask.pixels[at:at + 4] = b"\xff" * 4

        ax, ay = grip.knuckles
        vx, vy = grip.wrist[0] - ax, grip.wrist[1] - ay
        length = math.hypot(vx, vy)
        ux, uy = vx / length, vy / length
        # Inverse nearest-neighbor sampling retains crisp pixel-art contours.
        # Constrain every replacement pixel to the original hand mask: the
        # barrel, grip, sights and original animation pivots cannot be touched.
        for x, y in sorted(selected):
            along = (x - ax) * ux + (y - ay) * uy
            across = (x - ax) * -uy + (y - ay) * ux
            width = grip.width - .06 * max(0, min(1, along / length))
            sx = round(ax + along * ux - across / width * uy)
            sy = round(ay + along * uy + across / width * ux)
            if (sx, sy) not in selected:
                continue
            at = (sy * source.width + sx) * 4
            red = source.pixels[at]
            # Suppress stock-art grain and vein-like detail while preserving
            # broad knuckle/finger shading and the gun's original lighting.
            neighborhood = [source.pixels[(ny * source.width + nx) * 4]
                            for ny in range(sy - 1, sy + 2) for nx in range(sx - 1, sx + 2)
                            if (nx, ny) in selected]
            shade = (sum(neighborhood) + red * 2) / (len(neighborhood) + 2)
            if along >= grip.sleeve_at + 2:
                palette = SLEEVE
                tone = max(0, min(1, shade / 235))
            elif along >= grip.sleeve_at:
                palette = CUFF
                tone = max(0, min(1, shade / 210))
            else:
                palette = SKIN
                tone = max(0, min(1, (shade - 8) / 200)) ** .65
                if red <= 23: tone = 0
            color = rgba(palette[round(tone * (len(palette) - 1))])
            dest = (y * source.width + x) * 4
            hands.pixels[dest:dest + 4] = color
    return mask, hands


def composite(source: Raster, mask: Raster, hands: Raster) -> Raster:
    result = Raster(source.width, source.height, bytearray(source.pixels), source.anchor)
    for at in range(0, len(result.pixels), 4):
        if mask.pixels[at + 3]: result.pixels[at:at + 4] = bytes(4)
        if hands.pixels[at + 3]: result.pixels[at:at + 4] = hands.pixels[at:at + 4]
    return result
