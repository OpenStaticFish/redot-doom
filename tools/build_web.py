#!/usr/bin/env python3
"""Release web export + precompressed, fingerprinted Railway deployment bundle."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def engine_path() -> str:
    requested = os.environ.get("REDOT_BIN")
    candidates = [requested] if requested else ["redot", "godot4", "godot"]
    for name in candidates:
        if name and (path := shutil.which(name)):
            return path
    raise SystemExit("Install Redot/Godot and its matching web export templates, or set REDOT_BIN.")


def fingerprint(version: str) -> str:
    digest = hashlib.sha256(version.encode())
    paths = [ROOT / name for name in ("project.godot", "export_presets.cfg", "LICENSE", "LICENSING.md", "tools/build_web.py")]
    for folder in ("assets", "scripts", "scenes", "shaders", "web", "deploy"):
        paths.extend(path for path in (ROOT / folder).rglob("*") if path.is_file())
    for path in sorted(paths):
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


def copy_legal(public: Path) -> None:
    legal = public / "legal"
    legal.mkdir(exist_ok=True)
    sources = {"MIT.txt": ROOT / "LICENSE", "LICENSING.md": ROOT / "LICENSING.md", "ASSET-CREDITS.md": ROOT / "assets/CREDITS.md"}
    for bundle in ("weapons", "pickups", "presentation"):
        for path in (ROOT / "assets" / bundle / "freedoom").iterdir():
            if path.name.lower().startswith(("copying", "credits", "license", "authors")):
                sources[f"freedoom-{bundle}-{path.name}"] = path
    for path in (ROOT / "web/engine-notices").glob("*.txt"):
        sources[f"redot-{path.name}"] = path
    for name, path in sources.items():
        shutil.copyfile(path, legal / name)
    sections = "\n".join(f'<h2>{html.escape(name)}</h2><pre>{html.escape(path.read_text())}</pre>' for name, path in sources.items())
    (public / "credits.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>DEAD SIGNAL — Credits &amp; licenses</title><style>body{max-width:900px;margin:40px auto;padding:0 20px;background:#09090b;color:#eee;font:15px/1.6 system-ui}'
        'a{color:#ff6a42}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:13px/1.6 ui-monospace,monospace}h2{margin-top:36px}</style>'
        '<a href="/">← Back to the game</a><h1>Credits &amp; licenses</h1>' + sections + '</html>\n'
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--debug", action="store_true", help="Use a debug template for browser diagnostics.")
    args = parser.parse_args()
    engine = engine_path()
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    build_root = ROOT / "build"
    build_root.mkdir(exist_ok=True)
    (build_root / ".gdignore").touch()
    subprocess.run([engine, "--quiet", "--headless", "--editor", "--import", "--path", str(ROOT)], check=True)
    build_id = fingerprint(version + ("-debug" if args.debug else "-release"))
    output = build_root / "web" / build_id
    public = output / "public"
    public.mkdir(parents=True, exist_ok=True)
    exported = public / f"dead-signal-{build_id}.html"
    subprocess.run([engine, "--quiet", "--headless", "--path", str(ROOT), "--export-debug" if args.debug else "--export-release", "Web", str(exported)], check=True)
    (public / "index.html").write_bytes(exported.read_bytes())
    shutil.copyfile(ROOT / "icon.svg", public / "favicon.svg")
    copy_legal(public)
    for path in (ROOT / "deploy").iterdir():
        if path.is_file():
            shutil.copyfile(path, output / path.name)
    runtime = [path for path in public.iterdir() if path.suffix in (".wasm", ".pck", ".js")]
    if not any(path.suffix == ".wasm" for path in runtime) or not any(path.suffix == ".pck" for path in runtime):
        raise SystemExit("Export did not produce both a WebAssembly engine and a game pack.")
    sizes = {}
    for path in runtime:
        raw = path.read_bytes()
        compressed = gzip.compress(raw, compresslevel=9, mtime=0)
        path.with_name(path.name + ".gz").write_bytes(compressed)
        sizes[path.name] = {"bytes": len(raw), "gzip_bytes": len(compressed), "sha256": hashlib.sha256(raw).hexdigest()}
    manifest = {"build_id": build_id, "engine": version, "debug": args.debug, "assets": sizes}
    (output / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (build_root / "web-path").write_text(str(output.relative_to(ROOT)) + "\n")
    raw_size = sum(item["bytes"] for item in sizes.values())
    wire_size = sum(item["gzip_bytes"] for item in sizes.values())
    print(f"Runtime: {raw_size / 1048576:.2f} MiB → {wire_size / 1048576:.2f} MiB gzip ({100 * (1 - wire_size / raw_size):.1f}% smaller)")
    print(f"Railway bundle: {output.relative_to(ROOT)}")
    print("Deploy with: railway up \"$(cat build/web-path)\" --path-as-root --service web --environment production")


if __name__ == "__main__":
    main()
