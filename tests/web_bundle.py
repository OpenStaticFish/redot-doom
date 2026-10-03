"""Inspect the real release pack, hashed runtime, compression and license bundle."""
from pathlib import Path
import gzip
import hashlib
import json
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


def pack_paths(data: bytes) -> set[str]:
    magic, version = struct.unpack_from("<II", data)
    if magic != 0x43504447 or version not in (2, 3):
        raise ValueError(f"Unsupported PCK header: {magic:x}, version {version}")
    cursor = struct.unpack_from("<Q", data, 32)[0] if version == 3 else 96
    count = struct.unpack_from("<I", data, cursor)[0]
    cursor += 4
    paths = set()
    for _ in range(count):
        size = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        paths.add(data[cursor:cursor + size].rstrip(b"\0").decode())
        cursor += size + 16 + 16 + 4  # offset/size, MD5, flags
    return paths


class WebBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.output = ROOT / (ROOT / "build/web-path").read_text().strip()
        cls.public = cls.output / "public"
        cls.manifest = json.loads((cls.output / "build-manifest.json").read_text())
        cls.pack = next(cls.public.glob("*.pck"))
        cls.paths = pack_paths(cls.pack.read_bytes())

    def test_only_game_resources_are_in_pack(self) -> None:
        forbidden = ("tests/", "tools/", "web/", "deploy/", "build/", "/freedoom/", "/redot_hands/", "reference.png")
        for name in self.paths:
            self.assertFalse(any(part in name for part in forbidden), name)
        self.assertLess(self.pack.stat().st_size, 5 * 1024 * 1024, "unexpected source-art/developer resource bloat")

    def test_dynamic_resources_and_scripts_are_exported(self) -> None:
        for folder, suffix in (("audio", "wav"), ("textures", "png"), ("weapons", "png"), ("pickups", "png"), ("presentation", "png")):
            for path in (ROOT / "assets" / folder).glob(f"*.{suffix}"):
                self.assertIn(path.relative_to(ROOT).as_posix() + ".import", self.paths)
        self.assertIn("assets/ui/redot_chan/portraits.png.import", self.paths)
        for path in (ROOT / "scripts").glob("*.gd"):
            self.assertIn(path.relative_to(ROOT).with_suffix(".gdc").as_posix(), self.paths)
        self.assertIn("scenes/main.tscn.remap", self.paths)
        self.assertIn("shaders/portrait_blend.gdshader", self.paths)

    def test_fingerprints_and_compression_match(self) -> None:
        for name, metadata in self.manifest["assets"].items():
            self.assertIn(self.manifest["build_id"], name)
            raw = (self.public / name).read_bytes()
            compressed = (self.public / (name + ".gz")).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), metadata["sha256"])
            self.assertEqual(gzip.decompress(compressed), raw)
            self.assertEqual(len(compressed), metadata["gzip_bytes"])
        shell = (self.public / "index.html").read_text()
        self.assertIn(self.manifest["build_id"], shell)
        self.assertNotIn("$GODOT_", shell)
        self.assertFalse(self.manifest["debug"], "production must use a release template")

    def test_full_window_canvas_keeps_retro_viewport(self) -> None:
        shell = (self.public / "index.html").read_text()
        config = re.search(r"new Engine\((\{[^\n]+\})\)", shell)
        self.assertIsNotNone(config)
        self.assertEqual(json.loads(config.group(1))["canvasResizePolicy"], 2)
        project = (ROOT / "project.godot").read_text()
        self.assertIn("window/size/viewport_width=480", project)
        self.assertIn("window/size/viewport_height=270", project)
        self.assertIn('window/stretch/mode="viewport"', project)
        self.assertIn('window/stretch/aspect="keep"', project)

    def test_auto_start_has_no_launch_gate(self) -> None:
        shell = (self.public / "index.html").read_text()
        self.assertNotIn('id="play"', shell)
        self.assertNotIn("Connect &amp; play", shell)
        self.assertIn("async function startGame()", shell)
        self.assertIn("      startGame();", shell)
        self.assertIn('id="retry" type="button" hidden', shell)

    def test_notices_and_static_host_configuration(self) -> None:
        legal = self.public / "legal"
        self.assertEqual((legal / "MIT.txt").read_bytes(), (ROOT / "LICENSE").read_bytes())
        for bundle in ("weapons", "pickups", "presentation"):
            self.assertTrue(any(legal.glob(f"freedoom-{bundle}-COPYING*")))
        self.assertTrue((legal / "redot-LICENSE.txt").is_file())
        self.assertTrue((legal / "redot-COPYRIGHT.txt").is_file())
        self.assertTrue((self.public / "credits.html").is_file())
        config = (self.output / "default.conf.template").read_text()
        self.assertIn("listen ${PORT}", config)
        self.assertIn("gzip_static on", config)
        self.assertIn("immutable", config)
        self.assertIn("/healthz", config)


if __name__ == "__main__":
    unittest.main()
