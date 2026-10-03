#!/usr/bin/env python3
"""Adapt the supplied Rune Redot-chan expression sheet into compact HUD portraits.

Run once with --reference /path/to/sheet.png; subsequent rebuilds are offline.
Preserves the reference's hair, headset, ear pieces, clip, collar and expressions.
Uses connected-background removal rather than treating white hair as background.
"""
from __future__ import annotations

import argparse
from collections import deque
import json
from pathlib import Path

from build_weapon_sprites import Raster, read_png
from build_pickup_sprites import crop

ROOT = Path(__file__).resolve().parents[1] / "assets" / "ui" / "redot_chan"
TILE = (42, 44)
# Hand-aligned face/head crops from the supplied 850x601 six-expression sheet.
CROPS = {
    "calm": [77, 58, 190, 208],
    "happy": [324, 39, 192, 218],
    "hurt": [583, 35, 186, 228],
    "tired": [77, 306, 190, 231],
    "panic": [305, 286, 198, 251],
    "confident": [563, 300, 191, 238],
}
# Shared eye-line/head scale prevents a reaction from jumping across its frame.
EYES = {
    "calm": (155, 169), "happy": (423, 173), "hurt": (704, 159),
    "tired": (151, 423), "panic": (406, 408), "confident": (698, 434),
}
EYE_ANCHOR = (21, 25)
HEAD_SCALE = 0.19


def remove_background(image: Raster) -> None:
    """Flood only near-white pixels connected to the outside of a crop."""
    def white(x: int, y: int) -> bool:
        offset = (y * image.width + x) * 4
        rgb = image.pixels[offset:offset + 3]
        return min(rgb) >= 244 and max(rgb) - min(rgb) <= 10
    queue = deque()
    seen = set()
    for x in range(image.width):
        queue.extend(((x, 0), (x, image.height - 1)))
    for y in range(image.height):
        queue.extend(((0, y), (image.width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not (0 <= x < image.width and 0 <= y < image.height):
            continue
        seen.add((x, y))
        if not white(x, y):
            continue
        offset = (y * image.width + x) * 4
        image.pixels[offset:offset + 4] = bytes(4)
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))


def reduce(image: Raster, width: int, height: int) -> Raster:
    """Alpha-aware area sampling with a small palette, avoiding white fringes."""
    result = Raster(width, height, bytearray(width * height * 4))
    for y in range(height):
        y0, y1 = int(y * image.height / height), int((y + 1) * image.height / height)
        for x in range(width):
            x0, x1 = int(x * image.width / width), int((x + 1) * image.width / width)
            rgb = [0, 0, 0]
            total = max(1, (x1 - x0) * (y1 - y0))
            opaque = 0
            for sy in range(y0, y1):
                for sx in range(x0, x1):
                    offset = (sy * image.width + sx) * 4
                    if image.pixels[offset + 3]:
                        opaque += 1
                        for c in range(3): rgb[c] += image.pixels[offset + c]
            if opaque / total < 0.35:
                continue
            offset = (y * width + x) * 4
            # Preserve the art's warm skin and cool hair rather than quantizing
            # everything into the orange interface palette.
            color = [max(0, min(255, round(value / opaque / 8) * 8)) for value in rgb]
            result.pixels[offset:offset + 4] = bytes(color + [255])
    return result


def portrait(image: Raster, name: str) -> Raster:
    remove_background(image)
    small = reduce(image, round(image.width * HEAD_SCALE), round(image.height * HEAD_SCALE))
    result = Raster(*TILE, bytearray(TILE[0] * TILE[1] * 4))
    eye_x, eye_y = EYES[name]
    crop_x, crop_y = CROPS[name][:2]
    at_x = round(EYE_ANCHOR[0] - (eye_x - crop_x) * small.width / image.width)
    at_y = round(EYE_ANCHOR[1] - (eye_y - crop_y) * small.height / image.height)
    result.paste(small, at_x, at_y)
    return result


def focused_portrait(calm: Raster) -> Raster:
    """Combat-ready adaptation: two open amber eyes, firm brows, closed mouth."""
    # Keep the idle head/body position so repeated fire doesn't shift the icon.
    result = Raster(*TILE, bytearray(calm.pixels))
    colors = {
        "s": (248, 208, 192, 255), "d": (120, 56, 64, 255),
        "w": (248, 240, 224, 255), "o": (232, 80, 16, 255),
        "g": (255, 160, 48, 255), "p": (72, 32, 32, 255),
    }
    # Pixel-authored over the sheet's relaxed eyes, preserving the head/clothes.
    for x, rows in ((16, ["ddsss", "swddd", "swopw", "ssogs"]),
                    (24, ["sssdd", "dddws", "wopws", "sgoss"])):
        for dy, row in enumerate(rows):
            for dx, value in enumerate(row):
                at = ((23 + dy) * TILE[0] + x + dx) * 4
                result.pixels[at:at + 4] = bytes(colors[value])
    for dy, row in enumerate(["ssssss", "ssddds", "ssssss"]):
        for dx, value in enumerate(row):
            at = ((28 + dy) * TILE[0] + 20 + dx) * 4
            result.pixels[at:at + 4] = bytes(colors[value])
    return result


def build_portraits(reference: Path | None = None) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    stored = ROOT / "reference.png"
    if reference is not None:
        stored.write_bytes(reference.read_bytes())
    source = read_png(stored)
    if source.width != 850 or source.height != 601:
        raise ValueError("The supplied Redot-chan sheet must be 850x601")
    names = list(CROPS)
    frames = [portrait(crop(source, bounds), name) for name, bounds in CROPS.items()]
    defeated = Raster(*TILE, bytearray(frames[names.index("tired")].pixels))
    for i in range(0, len(defeated.pixels), 4):
        if defeated.pixels[i + 3]:
            rgb = defeated.pixels[i:i + 3]
            gray = sum(rgb) / 3
            for c in range(3):
                defeated.pixels[i + c] = round((rgb[c] * 0.3 + gray * 0.7) * 0.58)
    names.append("defeated")
    frames.append(defeated)
    names.append("focused")
    frames.append(focused_portrait(frames[names.index("calm")]))
    atlas = Raster(TILE[0] * len(frames), TILE[1], bytearray(TILE[0] * len(frames) * TILE[1] * 4))
    for i, frame in enumerate(frames):
        atlas.paste(frame, i * TILE[0], 0)
    atlas.save(ROOT / "portraits.png")
    metadata = {"size": list(TILE), "columns": len(frames), "rows": 1,
                "expressions": {name: index for index, name in enumerate(names)},
                 "source_crops": CROPS,
                 "eye_anchor": list(EYE_ANCHOR), "source_eyes": EYES,
                 "credit": "User-supplied Redot-chan concept 2.0 / DLC 2 sheet, signed Rune"}
    (ROOT / "art.gd").write_text("# Generated by tools/build_redot_chan.py.\nextends RefCounted\n\nconst ART = " + json.dumps(metadata, indent=2) + "\n")
    print(f"Built {len(frames)} Redot-chan portrait reactions from the supplied art sheet")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, help="Path to the user-provided expression sheet")
    args = parser.parse_args()
    build_portraits(args.reference)
