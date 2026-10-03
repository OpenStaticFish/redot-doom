#!/usr/bin/env python3
"""Redot-inspired black/orange UI, pixel-grid branding and exit-switch artwork."""
from pathlib import Path
import random
import re

from build_weapon_sprites import Raster

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
RNG = random.Random(9009)


def color(value: str) -> tuple[int, int, int, int]:
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def put(image: Raster, x: int, y: int, rgba) -> None:
    if 0 <= x < image.width and 0 <= y < image.height:
        at = (y * image.width + x) * 4
        image.pixels[at:at + 4] = bytes(rgba)


def rect(image: Raster, x: int, y: int, width: int, height: int, rgba) -> None:
    if isinstance(rgba, str):
        rgba = color(rgba)
    for py in range(max(0, y), min(image.height, y + height)):
        for px in range(max(0, x), min(image.width, x + width)):
            put(image, px, py, rgba)


def bevel(image: Raster, x: int, y: int, width: int, height: int) -> None:
    rect(image, x, y, width, 1, "68726d")
    rect(image, x, y, 1, height, "4d5956")
    rect(image, x, y + height - 1, width, 1, "080d10")
    rect(image, x + width - 1, y, 1, height, "0d1417")


def metal(width: int, height: int, base: int = 36) -> Raster:
    image = Raster(width, height, bytearray(width * height * 4))
    for y in range(height):
        for x in range(width):
            grain = RNG.randrange(-3, 4)
            value = base + grain + (2 if y % 3 == 0 else 0)
            put(image, x, y, (value - 5, value + 2, value + 3, 255))
    return image


def glyphs() -> dict:
    script = (ROOT / "scripts" / "pixel_font.gd").read_text()
    return {letter: [int(n) for n in rows.split(",")]
            for letter, rows in re.findall(r'"(.)":\s*\[([0-9,\s]+)\]', script)}


def text_mask(text: str, scale: int, width: int, height: int, x: int, y: int) -> set[tuple[int, int]]:
    alphabet = glyphs()
    mask = set()
    for letter in text:
        for py, bits in enumerate(alphabet[letter]):
            for px in range(5):
                if bits & (1 << (4 - px)):
                    mask.update((x + px * scale + dx, y + py * scale + dy)
                                for dx in range(scale) for dy in range(scale))
        x += 6 * scale
    return {(px, py) for px, py in mask if 0 <= px < width and 0 <= py < height}


def build_ui() -> None:
    (ASSETS / "ui").mkdir(parents=True, exist_ok=True)
    panel = Raster(128, 64, bytearray(128 * 64 * 4))
    rect(panel, 0, 0, 128, 64, "121216")
    for y in range(5, 64, 8):
        for x in range(5, 128, 8):
            put(panel, x, y, color("252126"))
    panel.save(ASSETS / "ui" / "panel.png")

    status = Raster(480, 46, bytearray(480 * 46 * 4))
    rect(status, 0, 0, 480, 46, "09090b")
    rect(status, 0, 0, 480, 1, "ff3b0a")
    rect(status, 0, 1, 480, 2, "3c170f")
    slots = [0, 80, 165, 208, 291, 399, 480]
    for left, right in zip(slots, slots[1:]):
        rect(status, left + 3, 5, right - left - 6, 37, "121216")
        rect(status, left + 3, 5, right - left - 6, 1, "29292f")
        rect(status, left + 3, 41, right - left - 6, 1, "29292f")
        rect(status, left + 2, 6, 1, 35, "29292f")
        rect(status, right - 3, 6, 1, 35, "29292f")
        rect(status, left + 5, 14, right - left - 10, 1, "222228")
    status.save(ASSETS / "ui" / "status.png")

    logo = Raster(416, 64, bytearray(416 * 64 * 4))
    mask = text_mask("DEAD SIGNAL", 6, 416, 64, 13, 7)
    for x, y in mask:
        put(logo, x + 2, y + 3, (75, 21, 10, 255))
    for x, y in mask:
        level = (y - 7) / 42
        rgb = [255, int(199 - level * 140), int(178 - level * 168)]
        put(logo, x, y, (*rgb, 255))
    logo.save(ASSETS / "ui" / "logo.png")

    background = Raster(480, 270, bytearray(480 * 270 * 4))
    rect(background, 0, 0, 480, 270, "09090b")
    # The website's orange pixel-field motif, adapted to the game's framebuffer.
    for y in range(3, 270, 6):
        for x in range(3, 480, 6):
            left = max(0, 1 - ((x / 230) ** 2 + ((y - 70) / 160) ** 2))
            right = max(0, 1 - (((x - 460) / 250) ** 2 + ((y - 210) / 150) ** 2))
            intensity = max(left, right) * RNG.uniform(0.1, 0.6)
            if intensity > 0.07:
                rect(background, x, y, 2, 2, (int(110 * intensity), int(29 * intensity), int(10 * intensity), 255))
    background.save(ASSETS / "ui" / "brand_background.png")

    switch = metal(128, 128, 43)
    bevel(switch, 2, 2, 124, 124)
    rect(switch, 12, 12, 104, 104, "172126")
    bevel(switch, 12, 12, 104, 104)
    rect(switch, 23, 25, 82, 44, "0e1c19")
    bevel(switch, 21, 23, 86, 48)
    for x, y in text_mask("EXIT", 3, 128, 128, 29, 34):
        put(switch, x, y, color("bded99"))
    rect(switch, 32, 82, 64, 22, "2c473b")
    bevel(switch, 32, 82, 64, 22)
    for x in range(36, 93, 8):
        rect(switch, x, 85, 4, 13, "80b374")
    for x, y in ((6, 6), (119, 6), (6, 119), (119, 119)):
        rect(switch, x, y, 3, 3, "a7aa93")
    switch.save(ASSETS / "textures" / "exit.png")
    print("Built Redot-inspired orange-gradient logo, pixel-grid background and black HUD/menu panels")


if __name__ == "__main__":
    build_ui()
