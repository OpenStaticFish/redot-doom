#!/usr/bin/env python3
"""Offline hand-mask, palette, geometry and untouched-gun asset regressions."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_weapon_sprites import FRAMES, SOURCE, read_png
from redot_hands import CUFF, GRIPS, SKIN, SLEEVE, composite, hand_layers, rgba


class PlayerHandAssets(unittest.TestCase):
    def test_visible_hand_coverage(self):
        expected = {name for weapon, (frames, _) in FRAMES.items()
                    if weapon in ("fist", "pistol", "shotgun") for name in frames}
        self.assertEqual(set(GRIPS), expected)

    def test_all_authored_poses(self):
        palette = {rgba(color) for color in SKIN + SLEEVE + CUFF}
        for name in GRIPS:
            with self.subTest(frame=name):
                source = read_png(SOURCE / (name + ".png"))
                before = bytes(source.pixels)
                mask, hands = hand_layers(source, name)
                result = composite(source, mask, hands)
                self.assertEqual(bytes(source.pixels), before, "source raster must not be mutated")
                original_count = sum(bool(mask.pixels[i + 3]) for i in range(0, len(before), 4))
                slim_count = sum(bool(hands.pixels[i + 3]) for i in range(0, len(before), 4))
                self.assertGreater(original_count, slim_count)
                self.assertGreater(slim_count, 0)
                for at in range(0, len(before), 4):
                    if mask.pixels[at + 3]:
                        self.assertNotEqual(before[at + 3], 0, "no edits outside the original hands")
                    else:
                        self.assertEqual(result.pixels[at:at + 4], source.pixels[at:at + 4], "weapon pixels are untouched")
                    if hands.pixels[at + 3]:
                        self.assertNotEqual(mask.pixels[at + 3], 0, "replacement must not overlap weapon metal")
                        self.assertIn(bytes(hands.pixels[at:at + 4]), palette)
                mask2, hands2 = hand_layers(source, name)
                self.assertEqual(mask.pixels, mask2.pixels, "mask is deterministic")
                self.assertEqual(hands.pixels, hands2.pixels, "palette/geometry is deterministic")

    def test_hidden_hands_and_muzzle_flashes(self):
        for bodies, flashes in FRAMES.values():
            for name in bodies + flashes:
                if name in GRIPS: continue
                with self.subTest(frame=name):
                    source = read_png(SOURCE / (name + ".png"))
                    mask, hands = hand_layers(source, name)
                    self.assertFalse(any(mask.pixels))
                    self.assertFalse(any(hands.pixels))
                    self.assertEqual(composite(source, mask, hands).pixels, source.pixels)


if __name__ == "__main__":
    unittest.main()
