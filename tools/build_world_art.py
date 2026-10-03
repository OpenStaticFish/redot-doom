#!/usr/bin/env python3
"""Build enemy, scenery, effect, texture and portrait art from Freedoom 0.13.0.

Sources and BSD license are included under assets/presentation/freedoom.
Normal builds are offline and require only Python's standard library.
"""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

from build_weapon_sprites import Raster, read_png, RELEASE
from build_pickup_sprites import crop

ASSETS = Path(__file__).resolve().parents[1] / "assets"
ROOT = ASSETS / "presentation"
SOURCE = ROOT / "freedoom"
ACTORS = {
    # POSS L is the settled corpse. M starts the separate, upright gib sequence.
    "thrall": {"prefix": "poss", "walk": "abcd", "attack": "efg", "pain": "h", "death": "ijkl"},
    "ember": {"prefix": "troo", "walk": "abcd", "attack": "efg", "pain": "h", "death": "ijklm"},
    "brute": {"prefix": "boss", "walk": "abcd", "attack": "efg", "pain": "h", "death": "ijklmno"},
    "warden": {"prefix": "cybr", "walk": "abcd", "attack": "efg", "pain": "h", "death": "ijklmnop"},
}
SHEETS = {
    "barrel": {"files": ["bar1a0", "bar1b0"], "height": 1.7, "fps": 4.0},
    "lamp": {"files": ["tlmpa0", "tlmpb0", "tlmpc0", "tlmpd0"], "height": 2.3, "fps": 5.0},
    "torch": {"files": ["treda0", "tredb0", "tredc0", "tredd0"], "height": 2.3, "fps": 7.0},
    "gore": {"files": ["possl0"], "height": 0.18, "fps": 0.0},
    "fireball": {"files": ["bal1a0", "bal1b0"], "fps": 10.0},
    "hellbolt": {"files": ["bal7a1a5", "bal7b1b5"], "fps": 10.0},
    "plasma": {"files": ["plssa0", "plssb0"], "fps": 14.0},
    "rocket": {"files": ["misla1"], "fps": 0.0},
    "explosion": {"files": ["bexpa0", "bexpb0", "bexpc0", "bexpd0", "bexpe0"], "fps": 14.0},
    "blood": {"files": ["bluda0", "bludb0", "bludc0"], "fps": 12.0},
    "spark": {"files": ["puffa0", "puffb0", "puffc0", "puffd0"], "fps": 14.0},
    "smoke": {"files": ["puffa0", "puffb0", "puffc0", "puffd0"], "fps": 10.0},
    "plasma_hit": {"files": ["plsea0", "plseb0", "plsec0", "plsed0", "plsee0"], "fps": 16.0},
}
TEXTURES = {
    "metal": "patches/wall00_1.png", "brick": "patches/stonew1.png",
    "concrete": "patches/wall01_1.png", "rust": "patches/wall02_1.png",
    "door": "patches/door2_1.png", "door_track": "patches/doortrak.png",
    "floor": "flats/floor4_8.png", "grate": "flats/ceil5_2.png",
    "ceiling": "flats/ceil3_5.png", "rock": "flats/floor6_1.png",
    "computer": "patches/comp02_2.png",
}
EXTRA_PATCHES = ["wall00_1", "wall00_3", "wall01_1", "wall02_2", "wall03_4", "door3_4", "door9_1", "comp01_1", "comp02_7", "exit1", "exit_grn", "sky1", "sky2"]
FACES = [f"stfst{health}{look}" for health in range(5) for look in range(3)] + [f"stfouch{health}" for health in range(5)] + ["stfdead0"]


def api(path: str) -> dict:
    for attempt in range(3):
        result = subprocess.run(["gh", "api", path], capture_output=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
        if attempt < 2:
            time.sleep(attempt + 1)
    raise RuntimeError(f"Could not fetch {path}: {result.stderr.decode().strip()}")


def actor_files(paths: list[str], profile: dict) -> list[str]:
    letters = "".join(profile[key] for key in ("walk", "attack", "pain", "death"))
    pattern = re.compile(r"^sprites/" + profile["prefix"] + "([" + letters + r"])[0-8](?:[a-z][0-8])?\.png$")
    return sorted(path for path in paths if pattern.match(path))


def fetch_sources() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    tree = api(f"repos/freedoom/freedoom/git/trees/{RELEASE}?recursive=1")
    paths = [item["path"] for item in tree["tree"] if item["type"] == "blob"]
    files = set(TEXTURES.values())
    files.update("patches/" + name + ".png" for name in EXTRA_PATCHES)
    files.update("graphics/" + name + ".png" for name in FACES)
    files.update("sprites/" + name + ".png" for sheet in SHEETS.values() for name in sheet["files"])
    files.update(f"flats/{name}{i}.png" for name, count in (("lava", 4), ("nukage", 3)) for i in range(1, count + 1))
    for profile in ACTORS.values():
        files.update(actor_files(paths, profile))
    files.update(["COPYING.adoc", "CREDITS", "buildcfg.txt"])

    def download(path: str) -> None:
        local = SOURCE / ("COPYING.txt" if path == "COPYING.adoc" else path)
        if local.exists():
            return
        info = api(f"repos/freedoom/freedoom/contents/{path}?ref={RELEASE}")
        data = base64.b64decode(info["content"])
        blob = b"blob " + str(len(data)).encode() + b"\0" + data
        if hashlib.sha1(blob).hexdigest() != info["sha"]:
            raise ValueError(f"Source integrity mismatch: {path}")
        local.parent.mkdir(parents=True, exist_ok=True)
        local.write_bytes(data)

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(download, sorted(files)))
    print(f"Freedoom {RELEASE}: {len(files)} source files available")


def offsets() -> dict[str, tuple[int, int]]:
    result = {}
    for line in (SOURCE / "buildcfg.txt").read_text().splitlines():
        fields = line.split(";", 1)[0].split()
        if len(fields) >= 3:
            try:
                result[fields[0].lower()] = (int(fields[1]), int(fields[2]))
            except ValueError:
                pass
    return result


def make_sheet(name: str, files: list[str], bottom: bool = False, centered_x: dict | None = None) -> tuple[dict, list[Raster]]:
    originals = [read_png(SOURCE / path) for path in files]
    bounds = [image.bounds() for image in originals]
    images = [crop(image, rect) for image, rect in zip(originals, bounds)]
    width = max(image.width for image in images)
    height = max(image.height for image in images)
    if centered_x is not None:
        half = max(max(pivot - rect[0], rect[0] + rect[2] - pivot)
                   for rect, pivot in zip(bounds, [centered_x.get(Path(path).stem, (raw.width // 2, 0))[0] for path, raw in zip(files, originals)]))
        width = half * 2 + 2
    columns = min(8, len(files))
    rows = (len(files) + columns - 1) // columns
    atlas = Raster(width * columns, height * rows, bytearray(width * columns * height * rows * 4))
    placements = []
    for i, image in enumerate(images):
        x = (width - image.width) // 2
        if centered_x is not None:
            pivot = centered_x.get(Path(files[i]).stem, (originals[i].width // 2, 0))[0]
            x = width // 2 - pivot + bounds[i][0]
        y = height - image.height if bottom else (height - image.height) // 2
        placements.append([x, y])
        atlas.paste(image, (i % columns) * width + x, (i // columns) * height + y)
    atlas.save(ROOT / (name + ".png"))
    return {"size": [width, height], "columns": columns, "rows": rows,
            "files": files, "source_bounds": bounds, "origins": placements}, images


def build_actors() -> dict:
    paths = [str(path.relative_to(SOURCE)) for path in (SOURCE / "sprites").glob("*.png")]
    pivots = offsets()
    result = {}
    for kind, profile in ACTORS.items():
        files = actor_files(paths, profile)
        sheet, cropped = make_sheet(kind, files, bottom=True, centered_x=pivots)
        rotations = {}
        for i, path in enumerate(files):
            stem = Path(path).stem
            suffix = stem[len(profile["prefix"]):]
            letter, rotation = suffix[0], int(suffix[1])
            if rotation == 0:
                rotations[letter] = [[i, False] for _ in range(8)]
            else:
                rotations.setdefault(letter, [None] * 8)[rotation - 1] = [i, False]
                if len(suffix) == 4:
                    rotations[letter][int(suffix[3]) - 1] = [i, True]
        poses = {}
        for state in ("walk", "attack", "pain", "death"):
            poses[state] = []
            for letter in profile[state]:
                if letter not in rotations or any(frame is None for frame in rotations[letter]):
                    raise ValueError(f"Missing directional pose: {kind} {letter}")
                poses[state].append(rotations[letter])
        first_index = poses["walk"][0][0][0]
        corpse_index = poses["death"][-1][0][0]
        # A terminal pose must be a collapsed silhouette, not the beginning of
        # an alternate death/gib sequence. Catch art-mapping mistakes at build time.
        if cropped[corpse_index].height > cropped[first_index].height * 0.6:
            raise ValueError(f"Terminal corpse is still upright: {kind} {files[corpse_index]}")
        sheet.update({"poses": poses, "ready_height": cropped[first_index].height,
                      "corpse_file": files[corpse_index],
                      "death_fps": 9.0, "walk_fps": 7.0})
        result[kind] = sheet
        print(f"{kind}: {len(files)} authored frames, 8 directions")
    return result


def build_faces() -> dict:
    files = ["graphics/" + name + ".png" for name in FACES]
    sheet, images = make_sheet("portraits", files)
    sheet["ready"] = [[FACES.index(f"stfst{health}{look}") for look in range(3)] for health in range(5)]
    sheet["hurt"] = [FACES.index(f"stfouch{health}") for health in range(5)]
    sheet["dead"] = FACES.index("stfdead0")
    return sheet


def build_textures() -> dict:
    for name, path in TEXTURES.items():
        read_png(SOURCE / path).save(ASSETS / "textures" / (name + ".png"))
    base = read_png(SOURCE / TEXTURES["door"])
    for name, accent in (("door", (202, 156, 82)), ("door_blue", (69, 156, 223)), ("door_red", (215, 70, 49))):
        image = Raster(base.width, base.height, bytearray(base.pixels))
        band_width = max(4, base.width // 24)
        for y in range(base.height):
            for x in list(range(4, 4 + band_width)) + list(range(base.width - 4 - band_width, base.width - 4)):
                i = (y * base.width + x) * 4
                factor = 0.85 if (y // 8) % 2 == 0 else 0.5
                image.pixels[i:i + 4] = bytes([int(c * factor) for c in accent] + [255])
        image.save(ASSETS / "textures" / (name + ".png"))
    animated = {}
    for kind, prefix, count in (("lava", "lava", 4), ("acid", "nukage", 3)):
        frames = []
        for i in range(1, count + 1):
            name = kind + "_" + str(i - 1)
            read_png(SOURCE / f"flats/{prefix}{i}.png").save(ASSETS / "textures" / (name + ".png"))
            frames.append(name)
        read_png(SOURCE / f"flats/{prefix}1.png").save(ASSETS / "textures" / (kind + ".png"))
        animated[kind] = frames
    return animated


def build_world() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    metadata = {"source": "Freedoom " + RELEASE, "actors": build_actors(), "sheets": {},
                "portraits": build_faces(), "animated_textures": build_textures()}
    for kind, profile in SHEETS.items():
        bottom = "height" in profile
        sheet, _ = make_sheet(kind, ["sprites/" + name + ".png" for name in profile["files"]], bottom=bottom)
        sheet.update({key: value for key, value in profile.items() if key != "files"})
        metadata["sheets"][kind] = sheet
    (ROOT / "art.gd").write_text(
        "# Generated by tools/build_world_art.py. Do not hand-edit.\n"
        "extends RefCounted\n\nconst ART = " + json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="Fetch the pinned source art with gh")
    parser.add_argument("--sources-only", action="store_true", help="Download without rebuilding presentation art")
    args = parser.parse_args()
    if args.fetch:
        fetch_sources()
    if not args.sources_only:
        build_world()
