#!/usr/bin/env python3
"""Build aligned Freedoom weapon atlases with Redot-chan's matching hands.

Python standard library only. Source PNGs and their BSD-3-Clause license are
included in assets/weapons/freedoom, so normal rebuilding is fully offline.
Use --fetch to refresh the pinned upstream sources with the GitHub CLI.
"""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zlib

ROOT = Path(__file__).resolve().parents[1] / "assets" / "weapons"
SOURCE = ROOT / "freedoom"
RELEASE = "v0.13.0"
CANVAS = (320, 200)
FRAMES = {
    "fist": (["punga0", "pungb0", "pungc0", "pungd0"], []),
    "pistol": (["pisga0", "pisgb0", "pisgc0", "pisgd0", "pisge0"], ["pisfa0"]),
    "shotgun": (["shtga0", "shtgb0", "shtgc0", "shtgd0"], ["shtfa0", "shtfb0"]),
    "chaingun": (["chgga0", "chggb0"], ["chgfa0", "chgfb0"]),
    "launcher": (["misga0", "misgb0"], ["misfa0", "misfb0", "misfc0", "misfd0"]),
    "plasma": (["plsga0", "plsgb0"], ["plsfa0", "plsfb0"]),
}


@dataclass
class Raster:
    width: int
    height: int
    pixels: bytearray
    anchor: tuple[int, int] = (0, 0)

    def paste(self, other: Raster, x: int, y: int) -> None:
        for sy in range(other.height):
            for sx in range(other.width):
                dx, dy = x + sx, y + sy
                if not (0 <= dx < self.width and 0 <= dy < self.height):
                    continue
                source = (sy * other.width + sx) * 4
                if other.pixels[source + 3]:
                    dest = (dy * self.width + dx) * 4
                    self.pixels[dest:dest + 4] = other.pixels[source:source + 4]

    def bounds(self) -> list[int]:
        points = [(i % self.width, i // self.width)
                  for i in range(self.width * self.height) if self.pixels[i * 4 + 3]]
        if not points:
            return [0, 0, 0, 0]
        x, y = min(p[0] for p in points), min(p[1] for p in points)
        return [x, y, max(p[0] for p in points) - x + 1, max(p[1] for p in points) - y + 1]

    def save(self, path: Path) -> None:
        def chunk(tag: bytes, data: bytes) -> bytes:
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
        rows = b"".join(b"\0" + self.pixels[y * self.width * 4:(y + 1) * self.width * 4]
                        for y in range(self.height))
        path.write_bytes(b"\x89PNG\r\n\x1a\n"
                         + chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0))
                         + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def read_png(path: Path) -> Raster:
    """Decode non-interlaced PNG; retain Doom's grAb animation-origin chunk."""
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {path}")
    chunks: dict[bytes, bytes] = {}
    cursor = 8
    while cursor < len(data):
        length = struct.unpack_from(">I", data, cursor)[0]
        tag = data[cursor + 4:cursor + 8]
        payload = data[cursor + 8:cursor + 8 + length]
        chunks[tag] = chunks.get(tag, b"") + payload
        cursor += length + 12
    width, height, depth, kind, _, _, interlace = struct.unpack(">IIBBBBB", chunks[b"IHDR"])
    if interlace or depth not in (1, 2, 4, 8):
        raise ValueError(f"Unsupported PNG encoding: {path}")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[kind]
    stride = (width * channels * depth + 7) // 8
    bpp = max(1, (channels * depth + 7) // 8)
    raw = zlib.decompress(chunks[b"IDAT"])
    palette = chunks.get(b"PLTE", b"")
    alpha = chunks.get(b"tRNS", b"")
    previous = bytearray(stride)
    rgba = bytearray(width * height * 4)

    def paeth(a: int, b: int, c: int) -> int:
        p = a + b - c
        distances = abs(p - a), abs(p - b), abs(p - c)
        return (a, b, c)[distances.index(min(distances))]

    for y in range(height):
        offset = y * (stride + 1)
        mode = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        for i in range(stride):
            left = row[i - bpp] if i >= bpp else 0
            above = previous[i]
            corner = previous[i - bpp] if i >= bpp else 0
            predictors = [0, left, above, (left + above) // 2, paeth(left, above, corner)]
            row[i] = (row[i] + predictors[mode]) & 255
        for x in range(width):
            if kind == 3:
                index = (row[x * depth // 8] >> (8 - depth - (x * depth % 8))) & ((1 << depth) - 1)
                color = palette[index * 3:index * 3 + 3] + bytes([alpha[index] if index < len(alpha) else 255])
            elif kind == 6:
                color = row[x * 4:x * 4 + 4]
            elif kind == 2:
                color = row[x * 3:x * 3 + 3] + b"\xff"
            elif kind == 4:
                color = bytes([row[x * 2]] * 3 + [row[x * 2 + 1]])
            else:
                value = row[x]
                color = bytes([value, value, value, 255])
            rgba[(y * width + x) * 4:(y * width + x) * 4 + 4] = color
        previous = row
    anchor = struct.unpack(">ii", chunks[b"grAb"]) if b"grAb" in chunks else (0, 0)
    return Raster(width, height, rgba, anchor)


def fetch_sources() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    names = [frame + ".png" for bodies, flashes in FRAMES.values() for frame in bodies + flashes]
    files = [("sprites/" + name, name) for name in names]
    files += [("COPYING.adoc", "COPYING.txt"), ("CREDITS", "CREDITS"), ("buildcfg.txt", "buildcfg.txt")]

    def download(entry: tuple[str, str]) -> None:
        upstream, local = entry
        response = subprocess.run(
            ["gh", "api", f"repos/freedoom/freedoom/contents/{upstream}?ref={RELEASE}"],
            capture_output=True, check=True)
        info = json.loads(response.stdout)
        data = base64.b64decode(info["content"])
        blob = b"blob " + str(len(data)).encode() + b"\0" + data
        if hashlib.sha1(blob).hexdigest() != info["sha"]:
            raise ValueError(f"Source integrity mismatch: {upstream}")
        (SOURCE / local).write_bytes(data)

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(download, files))
    print(f"Fetched {len(names)} Freedoom {RELEASE} weapon frames and license/credits")


def build_weapons() -> None:
    from redot_hands import GRIPS, STYLE, SKIN, SLEEVE, CUFF, composite, hand_layers

    metadata = {"source": "Freedoom " + RELEASE, "canvas": list(CANVAS),
                "hand_style": STYLE, "hand_palettes": {"skin": SKIN, "sleeve": SLEEVE, "cuff": CUFF},
                "weapons": {}}
    hand_root = ROOT / "redot_hands"
    hand_root.mkdir(parents=True, exist_ok=True)
    offsets = source_offsets()
    for weapon, (bodies, flashes) in FRAMES.items():
        bounds = []
        flash_bounds = []
        body_origins = []
        flash_origins = []
        has_hands = any(frame in GRIPS for frame in bodies)
        hand_mask = Raster(CANVAS[0] * len(bodies), CANVAS[1], bytearray(CANVAS[0] * len(bodies) * CANVAS[1] * 4))
        hand_sheet = Raster(hand_mask.width, hand_mask.height, bytearray(len(hand_mask.pixels)))
        for category, frames in (("", bodies), ("_flash", flashes)):
            if not frames:
                continue
            atlas = Raster(CANVAS[0] * len(frames), CANVAS[1], bytearray(CANVAS[0] * len(frames) * CANVAS[1] * 4))
            for index, name in enumerate(frames):
                source = read_png(SOURCE / (name + ".png"))
                pose = Raster(*CANVAS, bytearray(CANVAS[0] * CANVAS[1] * 4))
                # Shared 320x200 coordinates retain the authored pose/emitter
                # alignment. Buildcfg overrides PNG grAb, as in the upstream build.
                anchor = offsets.get(name, source.anchor)
                (body_origins if not category else flash_origins).append([-anchor[0], -anchor[1]])
                if not category and name in GRIPS:
                    mask, hands = hand_layers(source, name)
                    # Clip a pose before atlas placement, including the punch
                    # whose source forearm extends past the 320-pixel canvas.
                    mask_pose = Raster(*CANVAS, bytearray(CANVAS[0] * CANVAS[1] * 4))
                    hand_pose = Raster(*CANVAS, bytearray(CANVAS[0] * CANVAS[1] * 4))
                    mask_pose.paste(mask, -anchor[0], -anchor[1])
                    hand_pose.paste(hands, -anchor[0], -anchor[1])
                    hand_mask.paste(mask_pose, index * CANVAS[0], 0)
                    hand_sheet.paste(hand_pose, index * CANVAS[0], 0)
                    source = composite(source, mask, hands)
                pose.paste(source, -anchor[0], -anchor[1])
                atlas.paste(pose, index * CANVAS[0], 0)
                (bounds if not category else flash_bounds).append(pose.bounds())
            atlas.save(ROOT / (weapon + category + ".png"))
        if has_hands:
            hand_mask.save(hand_root / (weapon + "_mask.png"))
            hand_sheet.save(hand_root / (weapon + ".png"))
        metadata["weapons"][weapon] = {"body_bounds": bounds, "flash_bounds": flash_bounds,
                                          "body_origins": body_origins, "flash_origins": flash_origins,
                                          "hand_layer": "redot_hands/" + weapon if has_hands else "",
                                          "hand_mask": "redot_hands/" + weapon + "_mask" if has_hands else "",
                                          "body_frames": bodies, "flash_frames": flashes}
        print(f"{weapon:9s}: ready {bounds[0]}, {len(bodies)} body / {len(flashes)} flash frames")
    # GDScript metadata is exportable without a special non-resource file filter.
    (ROOT / "frames.gd").write_text(
        "# Generated by tools/build_weapon_sprites.py. Do not hand-edit.\n"
        "extends RefCounted\n\nconst ART = " + json.dumps(metadata, indent=4) + "\n")


def source_offsets() -> dict[str, tuple[int, int]]:
    names = {frame for bodies, flashes in FRAMES.values() for frame in bodies + flashes}
    offsets = {}
    for line in (SOURCE / "buildcfg.txt").read_text().splitlines():
        fields = line.split(";", 1)[0].split()
        if len(fields) >= 3 and fields[0].lower() in names:
            offsets[fields[0].lower()] = (int(fields[1]), int(fields[2]))
    return offsets


def inspect_sources() -> None:
    for weapon, (bodies, flashes) in FRAMES.items():
        for name in bodies + flashes:
            frame = read_png(SOURCE / (name + ".png"))
            print(f"{weapon:9s} {name}: {frame.width}x{frame.height}, origin {frame.anchor}, bounds {frame.bounds()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="Fetch pinned source frames using gh")
    parser.add_argument("--inspect", action="store_true", help="Inspect source bounds without rebuilding atlases")
    args = parser.parse_args()
    if args.fetch:
        fetch_sources()
    if args.inspect:
        inspect_sources()
    else:
        build_weapons()
