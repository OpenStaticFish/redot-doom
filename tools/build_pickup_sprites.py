#!/usr/bin/env python3
"""Build classic pickup atlases and HUD icons from Freedoom 0.13.0 art.

The included sources make normal rebuilding offline and stdlib-only.
--fetch downloads the pinned source PNGs and BSD license through gh.
"""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import subprocess

from build_weapon_sprites import Raster, read_png, RELEASE
from build_ui_art import put, rect, text_mask

ASSETS = Path(__file__).resolve().parents[1] / "assets"
ROOT = ASSETS / "pickups"
SOURCE = ROOT / "freedoom"
KEYCARD_SOURCE = ROOT / "keycards"

PICKUPS = {
    "medkit": {"frames": ["media0"], "width": 0.85},
    "stim": {"frames": ["stima0"], "width": 0.38},
    "armor": {"frames": ["arm1a0", "arm1b0"], "width": 0.85, "fps": 3.0},
    "bullets": {"frames": ["ammoa0"], "width": 0.62},
    "shells": {"frames": ["sboxa0"], "width": 0.80},
    "rockets": {"frames": ["broka0"], "width": 1.0},
    "cells": {"frames": ["celpa0"], "width": 0.72},
    "bluekey": {"frames": ["bluecard0", "bluecard1"], "source": "keycards", "width": 0.72, "fps": 4.0, "lift": 0.10, "bob": 0.025},
    "redkey": {"frames": ["redcard0", "redcard1"], "source": "keycards", "width": 0.72, "fps": 4.0, "lift": 0.10, "bob": 0.025},
    "mega": {"frames": ["soula0", "soulb0", "soulc0", "sould0"], "width": 0.78, "fps": 6.0, "lift": 0.24, "bob": 0.05},
    "suit": {"frames": ["suita0"], "width": 0.62},
    "shotgun": {"frames": ["shota0"], "width": 1.35},
    "chaingun": {"frames": ["mguna0"], "width": 1.35},
    "launcher": {"frames": ["launa0"], "width": 1.45},
    "plasma": {"frames": ["plasa0"], "width": 1.35},
}


def fetch_sources() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    files = [("sprites/" + name + ".png", name + ".png")
             for info in PICKUPS.values() if info.get("source", "freedoom") == "freedoom" for name in info["frames"]]
    files += [("COPYING.adoc", "COPYING.txt"), ("CREDITS", "CREDITS")]

    def download(entry: tuple[str, str]) -> None:
        upstream, local = entry
        result = subprocess.run(
            ["gh", "api", f"repos/freedoom/freedoom/contents/{upstream}?ref={RELEASE}"],
            capture_output=True, check=True)
        info = json.loads(result.stdout)
        data = base64.b64decode(info["content"])
        blob = b"blob " + str(len(data)).encode() + b"\0" + data
        if hashlib.sha1(blob).hexdigest() != info["sha"]:
            raise ValueError(f"Source integrity mismatch: {upstream}")
        (SOURCE / local).write_bytes(data)

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(download, files))
    print(f"Fetched {len(files) - 2} Freedoom {RELEASE} pickup frames and license/credits")


def crop(source: Raster, bounds: list[int]) -> Raster:
    x, y, width, height = bounds
    result = Raster(width, height, bytearray(width * height * 4))
    result.paste(source, -x, -y)
    return result


def thumbnail(source: Raster) -> Raster:
    scale = min(1.0, 28 / source.width, 28 / source.height)
    width, height = max(1, round(source.width * scale)), max(1, round(source.height * scale))
    image = Raster(width, height, bytearray(width * height * 4))
    for y in range(height):
        for x in range(width):
            sx, sy = min(source.width - 1, int(x / scale)), min(source.height - 1, int(y / scale))
            src = (sy * source.width + sx) * 4
            dst = (y * width + x) * 4
            image.pixels[dst:dst + 4] = source.pixels[src:src + 4]
    icon = Raster(32, 32, bytearray(32 * 32 * 4))
    icon.paste(image, (32 - width) // 2, (32 - height) // 2)
    return icon


def build_keycards() -> None:
    """Original horizontal access cards, shared by the world and HUD icons."""
    KEYCARD_SOURCE.mkdir(parents=True, exist_ok=True)
    for name, accent, light in (("blue", (40, 104, 183, 255), (131, 214, 255, 255)),
                                ("red", (177, 51, 40, 255), (255, 161, 124, 255))):
        for frame in range(2):
            card = Raster(64, 40, bytearray(64 * 40 * 4))
            # Clipped corners, a bright upper bevel and darker lower metal edge.
            rect(card, 4, 5, 56, 30, "77858a")
            rect(card, 6, 3, 52, 34, "bcc4bd")
            rect(card, 6, 3, 52, 1, "e3e5cf")
            rect(card, 4, 5, 1, 29, "dae0ce")
            rect(card, 59, 6, 1, 29, "3b4c54")
            rect(card, 6, 36, 52, 2, "475960")
            rect(card, 8, 6, 48, 4, "1b282f")
            rect(card, 7, 11, 50, 10, accent)
            for x, y in text_mask(name.upper(), 1, 64, 40, 11, 13):
                put(card, x, y, (235, 241, 222, 255))
            # Gold contact chip, etched traces, security number and barcode.
            rect(card, 9, 24, 12, 8, "765a31")
            rect(card, 10, 24, 10, 7, "d3b77b")
            rect(card, 13, 24, 1, 7, "866844")
            rect(card, 17, 24, 1, 7, "866844")
            rect(card, 10, 27, 10, 1, "866844")
            for x, y in text_mask("09", 1, 64, 40, 30, 24):
                put(card, x, y, (48, 64, 72, 255))
            for x in (28, 30, 33, 34, 37, 41, 43, 46, 47, 50, 54):
                rect(card, x, 33, 1, 2, "344950")
            rect(card, 49, 24, 7, 7, "34434c")
            rect(card, 51, 26, 3, 3, light if frame else accent)
            card.save(KEYCARD_SOURCE / (name + "card" + str(frame) + ".png"))


def build_pickups() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    build_keycards()
    metadata = {"source": "Freedoom " + RELEASE, "pickups": {}}
    for kind, profile in PICKUPS.items():
        source_dir = profile.get("source", "freedoom")
        originals = [read_png(ROOT / source_dir / (name + ".png")) for name in profile["frames"]]
        source_bounds = [frame.bounds() for frame in originals]
        frames = [crop(frame, bounds) for frame, bounds in zip(originals, source_bounds)]
        width = max(frame.width for frame in frames)
        height = max(frame.height for frame in frames)
        atlas = Raster(width * len(frames), height, bytearray(width * len(frames) * height * 4))
        origins = []
        for i, frame in enumerate(frames):
            # All poses share a bottom-center anchor, so flashing sprites never
            # jump sideways or clip into the floor as the frame changes.
            at = ((width - frame.width) // 2, height - frame.height)
            origins.append(list(at))
            atlas.paste(frame, i * width + at[0], at[1])
        atlas.save(ROOT / (kind + ".png"))
        thumbnail(frames[0]).save(ASSETS / "sprites" / (kind + ".png"))
        metadata["pickups"][kind] = {
            "size": [width, height], "frames": profile["frames"],
            "source_bounds": source_bounds, "origins": origins,
            "source_dir": source_dir,
            "width": profile["width"], "fps": profile.get("fps", 0.0),
            "lift": profile.get("lift", 0.0), "bob": profile.get("bob", 0.0),
        }
        print(f"{kind:9s}: {width}x{height}, {len(frames)} frames, width {profile['width']:.2f}m")
    (ROOT / "art.gd").write_text(
        "# Generated by tools/build_pickup_sprites.py. Do not hand-edit.\n"
        "extends RefCounted\n\nconst ART = " + json.dumps(metadata, indent=4) + "\n")
    # An original soft contact shadow, used as a horizontal, alpha-blended quad.
    shadow = Raster(64, 64, bytearray(64 * 64 * 4))
    for y in range(64):
        for x in range(64):
            radius = math.hypot((x - 31.5) / 30, (y - 31.5) / 30)
            alpha = round(max(0.0, 1.0 - radius) ** 1.5 * 100)
            i = (y * 64 + x) * 4
            shadow.pixels[i:i + 4] = bytes([0, 0, 0, alpha])
    shadow.save(ROOT / "shadow.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="Fetch pinned source PNGs using gh")
    args = parser.parse_args()
    if args.fetch:
        fetch_sources()
    build_pickups()
