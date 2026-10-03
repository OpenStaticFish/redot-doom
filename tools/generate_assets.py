#!/usr/bin/env python3
"""DEAD SIGNAL art and audio. Deterministic; Python stdlib only.

Run from anywhere: python3 tools/generate_assets.py
Presentation uses included BSD-licensed Freedoom art plus original UI, sky,
lighting and synthesized audio. All included art rebuilds fully offline.
"""
from pathlib import Path
import math
import random
import struct
import wave
import zlib
from build_weapon_sprites import build_weapons
from build_pickup_sprites import build_pickups
from build_world_art import build_world
from build_ui_art import build_ui
from build_redot_chan import build_portraits

ROOT = Path(__file__).resolve().parents[1] / "assets"
RNG = random.Random(1993)


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(color, amount):
    c = rgb(color) if isinstance(color, str) else color
    return tuple(max(0, min(255, int(v * amount))) for v in c[:3]) + (c[3],)


class Canvas:
    def __init__(self, w, h, color=(0, 0, 0, 0)):
        self.w, self.h = w, h
        c = rgb(color) if isinstance(color, str) else color
        self.data = bytearray(c * (w * h))

    def pixel(self, x, y, color):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            c = rgb(color) if isinstance(color, str) else color
            self.data[(y * self.w + x) * 4:(y * self.w + x) * 4 + 4] = bytes(c)

    def rect(self, x, y, w, h, color):
        c = rgb(color) if isinstance(color, str) else color
        for py in range(max(0, int(y)), min(self.h, int(y + h))):
            for px in range(max(0, int(x)), min(self.w, int(x + w))):
                self.pixel(px, py, c)

    def line(self, x0, y0, x1, y1, color, width=1):
        steps = max(abs(int(x1 - x0)), abs(int(y1 - y0)), 1)
        for i in range(steps + 1):
            t = i / steps
            self.rect(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), width, width, color)

    def poly(self, pts, color):
        for y in range(max(0, int(min(p[1] for p in pts))), min(self.h, int(max(p[1] for p in pts)) + 1)):
            cuts = []
            for i, (x1, y1) in enumerate(pts):
                x2, y2 = pts[(i + 1) % len(pts)]
                if (y1 <= y < y2) or (y2 <= y < y1):
                    cuts.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
            cuts.sort()
            for a, b in zip(cuts[::2], cuts[1::2]):
                self.rect(math.ceil(a), y, math.floor(b) - math.ceil(a) + 1, 1, color)

    def ellipse(self, x, y, w, h, color):
        for py in range(max(0, int(y)), min(self.h, int(y + h + 1))):
            for px in range(max(0, int(x)), min(self.w, int(x + w + 1))):
                if ((px - x - w / 2) / max(w / 2, .1)) ** 2 + ((py - y - h / 2) / max(h / 2, .1)) ** 2 <= 1:
                    self.pixel(px, py, color)

    def bevel(self, x, y, w, h, color):
        self.rect(x, y, w, h, color)
        self.line(x, y, x + w - 1, y, shade(color, 1.5))
        self.line(x, y, x, y + h - 1, shade(color, 1.25))
        self.line(x, y + h - 1, x + w - 1, y + h - 1, shade(color, .4))
        self.line(x + w - 1, y, x + w - 1, y + h - 1, shade(color, .5))

    def noise(self, amount=12, transparent=False):
        for i in range(0, len(self.data), 4):
            if self.data[i + 3] == 0 or (transparent and RNG.random() > .3):
                continue
            n = RNG.randrange(-amount, amount + 1)
            for k in range(3):
                self.data[i + k] = max(0, min(255, self.data[i + k] + n))

    def paste(self, other, x, y):
        for py in range(other.h):
            for px in range(other.w):
                i = (py * other.w + px) * 4
                if other.data[i + 3]:
                    self.pixel(x + px, y + py, tuple(other.data[i:i + 4]))

    def save(self, path):
        path = ROOT / path
        path.parent.mkdir(parents=True, exist_ok=True)
        def chunk(name, data):
            return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data) & 0xffffffff)
        rows = b"".join(b"\0" + bytes(self.data[y * self.w * 4:(y + 1) * self.w * 4]) for y in range(self.h))
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def textures():
    c = Canvas(64, 64, "#41484b")
    for x in range(0, 64, 16):
        c.bevel(x, 0, 16, 64, "#505456")
        c.rect(x + 3, 5, 9, 48, "#373d40")
        c.line(x + 4, 6, x + 4, 51, "#727577")
        for y in (3, 59):
            c.rect(x + 7, y, 2, 2, "#a4a39a")
    c.rect(0, 53, 64, 5, "#242b2d")
    c.line(0, 52, 63, 52, "#949385")
    c.noise(8)
    c.save("textures/metal.png")

    c = Canvas(64, 64, "#312a24")
    for y in range(0, 64, 16):
        for x in range(-16 if y % 32 else 0, 64, 32):
            base = shade("#805d4a", RNG.uniform(.75, 1.15))
            c.bevel(x + 1, y + 1, 30, 14, base)
            c.line(x + 4, y + 4, x + 26, y + 3, shade(base, 1.1))
            if RNG.random() < .6:
                c.line(x + 15, y + 3, x + 12, y + 10, shade(base, .5))
    c.noise(10)
    c.save("textures/brick.png")

    c = Canvas(64, 64, "#514b40")
    for y in range(0, 64, 32):
        c.bevel(1, y + 1, 62, 30, "#676255")
        c.rect(5, y + 5, 54, 21, "#615c51")
        for x in (4, 58):
            c.rect(x, y + 3, 2, 2, "#beb19a")
    for _ in range(15):
        x, y = RNG.randrange(64), RNG.randrange(64)
        c.line(x, y, x + RNG.randrange(-5, 6), y + RNG.randrange(3, 9), "#34332d")
    c.noise(14)
    c.save("textures/concrete.png")

    c = Canvas(64, 64, "#42352b")
    for x in range(0, 64, 8):
        c.bevel(x, 0, 8, 64, "#72513c")
        c.rect(x + 2, 0, 2, 64, "#34302b")
    c.rect(0, 10, 64, 7, "#2a2925")
    c.line(0, 9, 63, 9, "#aa7950")
    c.rect(0, 48, 64, 6, "#2a2925")
    c.line(0, 47, 63, 47, "#aa7950")
    for _ in range(70):
        c.rect(RNG.randrange(64), RNG.randrange(64), 2, RNG.randrange(1, 5), "#9c5930")
    c.noise(10)
    c.save("textures/rust.png")

    for name, accent in (("door", "#ffb049"), ("door_blue", "#4da2ff"), ("door_red", "#e54534"), ("secret", "#616153")):
        c = Canvas(64, 64, "#222b2c")
        c.bevel(3, 0, 58, 64, "#64645a")
        for y in range(3, 61, 8):
            c.bevel(7, y, 50, 7, "#40494a")
            c.rect(9, y + 2, 46, 2, "#576161")
        c.rect(0, 0, 5, 64, "#191f23")
        c.rect(59, 0, 5, 64, "#191f23")
        c.rect(6, 3, 3, 58, accent)
        c.rect(55, 3, 3, 58, accent)
        c.bevel(24, 26, 16, 13, "#1d262a")
        c.rect(27, 29, 10, 4, accent)
        c.rect(29, 35, 6, 2, "#a8aaa0")
        c.noise(7)
        c.save(f"textures/{name}.png")

    c = Canvas(64, 64, "#2b2e2e")
    for y in (0, 32):
        for x in (0, 32):
            c.bevel(x, y, 32, 32, "#55594e")
            c.line(x + 2, y + 2, x + 29, y + 2, "#6d6b5b")
            for sx, sy in ((3, 3), (28, 28)):
                c.rect(x + sx, y + sy, 2, 2, "#262b29")
    c.noise(9)
    c.save("textures/floor.png")
    c = Canvas(64, 64, "#101b1d")
    for i in range(0, 64, 8):
        c.rect(i, 0, 3, 64, "#535d59")
        c.rect(0, i, 64, 3, "#535d59")
        c.line(i, 0, i, 63, "#93927a")
        c.line(0, i, 63, i, "#93927a")
    c.noise(5)
    c.save("textures/grate.png")
    c = Canvas(64, 64, "#34352f")
    for i in range(0, 64, 16):
        c.rect(i, 0, 2, 64, "#151c1c")
        c.rect(0, i, 64, 2, "#151c1c")
        c.rect(i + 3, 4, 10, 2, "#494d40")
    c.noise(8)
    c.save("textures/ceiling.png")
    c = Canvas(64, 64, "#23292a")
    c.bevel(4, 9, 56, 46, "#434b49")
    c.rect(9, 14, 46, 36, "#111e22")
    for y in (17, 27, 37):
        c.bevel(12, y, 40, 8, "#b69d68")
        c.rect(14, y + 2, 36, 4, "#f6dc99")
        c.line(16, y + 2, 48, y + 2, "#fff4c5")
    c.noise(4)
    c.save("textures/light.png")
    c = Canvas(64, 64, "#594032")
    c.noise(22)
    for _ in range(60):
        x, y = RNG.randrange(64), RNG.randrange(64)
        c.ellipse(x, y, 3, 2, "#302b29")
        c.pixel(x + 1, y, "#9a7654")
    c.save("textures/rock.png")

    for name, base, bright in (("lava", "#8b2316", "#ffbc3e"), ("acid", "#234527", "#9ce64f")):
        c = Canvas(64, 64, base)
        for y in range(64):
            for x in range(64):
                v = math.sin(x * .22 + math.sin(y * .2) * 2) + math.cos(y * .27 + math.sin(x * .21))
                c.pixel(x, y, shade(bright, .4 + max(0, v) * .29))
        c.noise(10)
        c.save(f"textures/{name}.png")

    c = Canvas(64, 64, "#211e1b")
    c.bevel(2, 2, 60, 60, "#59574d")
    c.bevel(9, 8, 46, 28, "#152527")
    for y in range(12, 31, 4):
        c.rect(13, y, RNG.randrange(12, 37), 1, "#69b4a6")
    c.rect(13, 14, 5, 3, "#b6efc6")
    c.bevel(10, 41, 44, 14, "#252c2b")
    for y in (43, 48):
        for x in range(13, 51, 5):
            c.rect(x, y, 3, 3, "#899186")
    c.noise(6)
    c.save("textures/computer.png")

    c = Canvas(64, 64, "#292b25")
    c.bevel(5, 5, 54, 54, "#565d4e")
    c.bevel(13, 16, 38, 32, "#181f19")
    c.rect(18, 20, 28, 7, "#aade70")
    # EXIT, deliberately drawn as pixels.
    glyphs = [ [7,4,6,4,7], [5,5,2,5,5], [7,2,2,2,7], [7,2,2,2,2] ]
    for k, rows in enumerate(glyphs):
        for y, row in enumerate(rows):
            for x in range(3):
                if row & (1 << (2 - x)):
                    c.rect(18 + k * 7 + x * 2, 32 + y * 2, 2, 2, "#aade70")
    c.save("textures/exit.png")

    c = Canvas(256, 128, "#1b1018")
    for y in range(128):
        c.rect(0, y, 256, 1, (int(40 + y * .65), int(24 + y * .2), int(36 + y * .16), 255))
    c.ellipse(178, 18, 36, 36, "#d36439")
    for layer, color in ((0, "#442b2e"), (1, "#261d25"), (2, "#18191e")):
        pts = [(0, 128)]
        for x in range(0, 257, 8):
            pts.append((x, 72 + layer * 13 + RNG.randrange(-16, 14)))
        pts.append((256, 128))
        c.poly(pts, color)
    for _ in range(40):
        c.pixel(RNG.randrange(256), RNG.randrange(50), "#ad7665")
    c.save("textures/sky.png")


def demon(kind, frame):
    c = Canvas(64, 80)
    armor = {"thrall": "#5c725e", "ember": "#aa5230", "brute": "#97393e", "warden": "#697382"}[kind]
    skin = {"thrall": "#ba9571", "ember": "#b76e44", "brute": "#bf6459", "warden": "#a1887b"}[kind]
    dark, light = shade(armor, .45), shade(armor, 1.5)
    if frame == 7:
        c.ellipse(7, 64, 52, 14, "#591f20")
        c.poly([(9, 70), (16, 60), (33, 62), (55, 70), (55, 75), (12, 77)], dark)
        c.ellipse(23, 64, 16, 10, skin)
        c.rect(24, 67, 5, 2, "#ffad35")
        c.rect(14, 72, 30, 3, armor)
        c.noise(8, True)
        return c
    dy = 1 if frame == 2 else 0
    if frame >= 5:
        dy = 13 if frame == 5 else 28
    walk = 3 if frame == 1 else (-3 if frame == 2 else 0)
    bulky = kind in ("brute", "warden")
    left, right = (12, 52) if bulky else (17, 47)
    c.ellipse(10, 72, 44, 7, (0, 0, 0, 95))
    c.poly([(21, 49 + dy), (30, 50 + dy), (29, 69 + walk + dy), (18, 73 + walk + dy), (17, 69 + walk + dy)], dark)
    c.poly([(34, 50 + dy), (43, 49 + dy), (47, 69 - walk + dy), (34, 72 - walk + dy), (34, 67 - walk + dy)], armor)
    c.rect(18, 69 + walk + dy, 12, 7, "#252d2d")
    c.rect(34, 69 - walk + dy, 14, 7, "#252d2d")
    c.line(19, 69 + walk + dy, 28, 69 + walk + dy, "#919183")
    c.line(35, 69 - walk + dy, 45, 69 - walk + dy, "#919183")
    c.poly([(left, 27 + dy), (23, 22 + dy), (41, 22 + dy), (right, 28 + dy), (43, 52 + dy), (21, 52 + dy)], dark)
    c.poly([(left + 3, 27 + dy), (25, 24 + dy), (39, 24 + dy), (right - 4, 29 + dy), (40, 49 + dy), (23, 49 + dy)], armor)
    c.poly([(24, 26 + dy), (37, 26 + dy), (40, 39 + dy), (23, 37 + dy)], light)
    c.rect(25, 28 + dy, 13, 3, shade(armor, 1.8))
    c.rect(22, 47 + dy, 21, 5, "#242a2a")
    c.rect(30, 47 + dy, 5, 5, "#ae9764")
    # Arms and gauntlets; the attack pose reaches toward the player.
    ay = 34 if frame != 3 else 25
    c.poly([(left, 27 + dy), (left - 6, ay + dy), (left - 4, 49 + dy), (left + 3, 49 + dy), (left + 5, 33 + dy)], armor)
    c.poly([(right - 3, 28 + dy), (right + 5, ay + dy), (right + 6, 48 + dy), (right - 1, 51 + dy), (right - 6, 34 + dy)], armor)
    c.ellipse(left - 5, 44 + dy, 8, 8, skin)
    c.ellipse(right - 2, 43 + dy, 8, 8, skin)
    c.line(left - 3, 32 + dy, left - 3, 42 + dy, light, 2)
    c.line(right + 1, 32 + dy, right + 2, 42 + dy, light, 2)
    c.poly([(24, 10 + dy), (39, 10 + dy), (42, 17 + dy), (38, 27 + dy), (31, 30 + dy), (23, 24 + dy), (21, 17 + dy)], shade(skin, .6))
    c.poly([(25, 12 + dy), (36, 11 + dy), (39, 17 + dy), (36, 25 + dy), (29, 26 + dy), (24, 22 + dy)], skin)
    c.rect(26, 13 + dy, 10, 3, shade(skin, 1.4))
    c.rect(24, 18 + dy, 6, 3, "#25201f")
    c.rect(34, 18 + dy, 6, 3, "#25201f")
    eye = "#eefeaa" if kind == "thrall" else "#ffc33f"
    c.rect(25, 19 + dy, 4, 1, eye)
    c.rect(35, 19 + dy, 4, 1, eye)
    c.rect(30, 20 + dy, 3, 4, shade(skin, .6))
    c.rect(28, 25 + dy, 9, 2, "#311d1b")
    c.rect(29, 25 + dy, 6, 1, "#ded2aa")
    if kind == "thrall":
        c.poly([(22, 13 + dy), (25, 7 + dy), (37, 7 + dy), (41, 14 + dy)], "#43584f")
        c.rect(23, 12 + dy, 18, 4, "#7d8b76")
        c.poly([(13, 42 + dy), (41, 38 + dy), (48, 44 + dy), (17, 49 + dy)], "#252c2d")
        c.rect(18, 42 + dy, 24, 3, "#8b9290")
        c.rect(23, 47 + dy, 6, 8, "#514538")
    else:
        c.poly([(23, 14 + dy), (15, 3 + dy), (21, 6 + dy), (28, 13 + dy)], "#cab18b")
        c.poly([(38, 14 + dy), (48, 3 + dy), (41, 6 + dy), (34, 13 + dy)], "#cab18b")
        for x in (left, right - 3):
            c.poly([(x, 27 + dy), (x - 3, 18 + dy), (x + 5, 25 + dy)], "#d8b389")
        if kind == "warden":
            c.bevel(23, 29 + dy, 18, 15, "#434d61")
            c.ellipse(27, 31 + dy, 10, 10, "#cf5033")
            c.ellipse(29, 33 + dy, 6, 6, "#ffc977")
            c.rect(5, 36 + dy, 15, 15, "#31394b")
            c.rect(8, 37 + dy, 6, 14, "#8a939a")
            c.rect(6, 49 + dy, 11, 4, "#ef883d")
    if frame == 3:
        c.ellipse(3 if kind == "thrall" else 40, 34 + dy, 20, 20, "#ea6b28")
        c.ellipse(7 if kind == "thrall" else 44, 38 + dy, 12, 12, "#ffe8a8")
    if frame == 4 or frame >= 5:
        c.rect(28, 22 + dy, 3, 13, "#a32525")
        c.rect(33, 30 + dy, 9, 5, "#981e26")
    c.noise(8, True)
    return c


def sprites():
    for kind in ("thrall", "ember", "brute", "warden"):
        sheet = Canvas(64 * 8, 80)
        for frame in range(8):
            sheet.paste(demon(kind, frame), frame * 64, 0)
        sheet.save(f"sprites/{kind}.png")

    for kind in ("barrel", "lamp", "torch", "gore"):
        c = Canvas(40, 64)
        if kind == "barrel":
            c.ellipse(5, 52, 30, 7, (0, 0, 0, 120))
            c.rect(6, 16, 28, 38, "#4d6048")
            c.rect(9, 16, 7, 36, "#82905d")
            c.rect(29, 16, 4, 36, "#263c34")
            c.ellipse(6, 11, 28, 10, "#809075")
            c.ellipse(9, 13, 22, 5, "#3c4e40")
            c.rect(6, 24, 28, 3, "#292d29")
            c.rect(6, 44, 28, 3, "#292d29")
            c.ellipse(15, 30, 12, 12, "#c8b86a")
            c.poly([(21, 31), (17, 38), (25, 38)], "#283c31")
            c.rect(20, 36, 3, 5, "#283c31")
        elif kind == "gore":
            c.ellipse(2, 53, 36, 9, "#59201e")
            c.poly([(8, 55), (11, 45), (22, 48), (35, 59), (9, 61)], "#827559")
            c.rect(13, 49, 11, 6, "#9d3226")
        else:
            c.bevel(15, 34, 10, 27, "#393e37")
            c.bevel(9, 58, 22, 4, "#6a6b55")
            if kind == "lamp":
                c.bevel(8, 16, 24, 23, "#343d39")
                c.rect(10, 19, 20, 15, "#ffb963")
                c.rect(13, 20, 14, 12, "#fff0b0")
                c.rect(10, 27, 20, 2, "#c18849")
            else:
                c.poly([(12, 35), (9, 24), (17, 13), (20, 2), (25, 18), (32, 24), (28, 35)], "#bc4b27")
                c.poly([(16, 34), (14, 25), (20, 12), (27, 25), (24, 34)], "#ffbc49")
                c.poly([(19, 34), (17, 27), (21, 20), (25, 28), (23, 34)], "#fff2bb")
        c.noise(5, True)
        c.save(f"sprites/{kind}.png")

    for kind, colors in (("fireball", ("#b52c21", "#f7a13b", "#fff2ac")), ("plasmabolt", ("#244fbc", "#5ed6ea", "#d5ffff")), ("explosion", ("#8f211c", "#ec7725", "#fff1b5"))):
        c = Canvas(64, 64)
        c.ellipse(3, 3, 58, 58, colors[0])
        for i in range(12):
            angle = i * math.tau / 12
            c.poly([(32, 32), (32 + math.cos(angle) * 31, 32 + math.sin(angle) * 31), (32 + math.cos(angle + .22) * 23, 32 + math.sin(angle + .22) * 23)], colors[1])
        c.ellipse(14, 12, 37, 40, colors[1])
        c.ellipse(23, 21, 21, 24, colors[2])
        c.noise(10, True)
        c.save(f"sprites/{kind}.png")


def weapons():
    build_weapons()
    build_pickups()


def portraits():
    sheet = Canvas(32 * 5, 32)
    for f in range(5):
        c = Canvas(32, 32, "#2b2825")
        c.poly([(6, 7), (12, 3), (24, 4), (29, 11), (26, 26), (20, 30), (11, 27), (6, 18)], "#664934")
        c.poly([(10, 8), (23, 7), (26, 12), (24, 24), (20, 27), (13, 24), (9, 17)], "#c49c73")
        c.rect(10, 10, 14, 3, "#e0b98d")
        c.poly([(6, 10), (8, 4), (12, 2), (24, 3), (27, 7), (23, 8), (12, 7)], "#4a4839")
        c.rect(9, 14, 7, 2, "#46382e")
        c.rect(20, 14, 6, 2, "#46382e")
        c.rect(11, 15, 3, 1, "#d6d3b3")
        c.rect(21, 15, 3, 1, "#d6d3b3")
        c.line(17, 14, 16, 20, "#886144")
        c.rect(15, 23, 8, 2, "#50392c")
        if f > 0:
            c.rect(23, 11, 2, 7 + f * 2, "#9e332a")
            c.rect(10, 20, f * 2, 2, "#914132")
        if f > 2:
            c.rect(8, 13, 7, 5, "#6a3930")
            c.rect(15, 23, 7, 3, "#b12123")
        if f == 4:
            c.line(10, 15, 14, 17, "#291d1c")
            c.line(10, 17, 14, 15, "#291d1c")
            c.line(20, 15, 24, 17, "#291d1c")
            c.line(20, 17, 24, 15, "#291d1c")
        c.noise(4)
        sheet.paste(c, f * 32, 0)
    sheet.save("ui/faces.png")


SR = 22050


def save_wav(name, samples):
    path = ROOT / "audio" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = bytearray()
    for v in samples:
        data.extend(struct.pack("<h", int(max(-1, min(1, v)) * 30000)))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def audio():
    for name, duration in (("pistol", .22), ("shotgun", .55), ("chaingun", .15), ("launcher", .6), ("plasma", .18), ("explosion", .8), ("door", .65), ("hurt", .25), ("growl", .7), ("death", .7), ("pickup", .25), ("key", .4), ("menu", .09), ("empty", .09), ("fist", .18), ("hit", .16)):
        samples = []
        filtered = 0
        for i in range(int(SR * duration)):
            t = i / SR
            p = t / duration
            n = RNG.uniform(-1, 1)
            filtered = filtered * .7 + n * .3
            if name in ("pickup", "key", "menu"):
                freq = 660 if name == "menu" else (440 + int(p * 4) * 220)
                v = math.sin(t * math.tau * freq) * (1 - p) ** 2 * .28
            elif name == "empty":
                v = (n * .8 + math.sin(t * 1800) * .2) * math.exp(-t * 65) * .4
            elif name in ("growl", "death", "hurt"):
                freq = (80 if name == "growl" else 130) * (1 - p * .55)
                v = (math.sin(t * math.tau * freq + math.sin(t * 41) * 1.9) * .4 + filtered * .7) * math.sin(p * math.pi) * .6
            elif name == "door":
                v = (filtered * .55 + math.sin(t * math.tau * 52) * .2 + math.sin(t * math.tau * 103) * .1) * math.sin(p * math.pi) * .7
            elif name == "plasma":
                v = math.sin(math.tau * (1900 * t - 2600 * t * t)) * math.exp(-p * 6) * .4 + n * math.exp(-p * 14) * .2
            else:
                decay = 11 if name in ("pistol", "chaingun", "hit", "fist") else 6
                freq = 95 if name != "explosion" else 55
                v = (filtered * 1.8 + n * .25 + math.sin(t * math.tau * freq * (1 - p * .5)) * .48) * math.exp(-p * decay)
            samples.append(v)
        save_wav(name, samples)

    # Sixteen bars of original synth-metal: minor-key bass, lead, kick and snare.
    bpm = 112
    beat = 60 / bpm
    duration = beat * 64
    notes = [40, 40, 43, 40, 46, 45, 43, 38, 40, 40, 47, 46, 43, 45, 38, 39]
    samples = []
    for i in range(int(SR * duration)):
        t = i / SR
        step = int(t / (beat / 2))
        local = t % (beat / 2)
        midi = notes[step % len(notes)]
        freq = 440 * 2 ** ((midi - 69) / 12)
        bass = math.tanh((math.sin(t * math.tau * freq) + .35 * math.sin(t * math.tau * freq * 2)) * 2) * .14 * math.exp(-local * 5)
        lead_midi = [64, 67, 71, 70, 67, 66, 62, 63][int(t / beat) % 8]
        lf = 440 * 2 ** ((lead_midi - 69) / 12)
        lead = (math.sin(t * math.tau * lf) + .3 * math.sin(t * math.tau * lf * 2)) * .032 * math.exp(-(t % beat) * 3)
        drum = t % beat
        kick = math.sin(math.tau * (58 * drum + 7 * (1 - math.exp(-drum * 35)))) * math.exp(-drum * 22) * .28
        snare_t = (t + beat) % (beat * 2)
        snare = RNG.uniform(-1, 1) * math.exp(-snare_t * 30) * .14
        hat_t = t % (beat / 2)
        hat = RNG.uniform(-1, 1) * math.exp(-hat_t * 100) * .04
        samples.append(bass + lead + kick + snare + hat)
    save_wav("music", samples)


if __name__ == "__main__":
    textures()
    weapons()
    build_world()
    build_ui()
    build_portraits()
    audio()
    print(f"Generated DEAD SIGNAL art and audio in {ROOT}")
