# DEAD SIGNAL

**Three sectors. Six weapons. One way out.**

A complete, original Doom-inspired single-player FPS built in **Redot 26.2 / Godot 4.3+**. The classic look comes from a 480×270 framebuffer, nearest-neighbor pixel textures, animated billboard monsters, hand-drawn bitmap text, a chunky status bar, distance shading, and an optional CRT/palette filter.

**Source code:** [MIT](LICENSE). **Artwork:** [mixed licensing](LICENSING.md),
including BSD-licensed Freedoom assets and a Redot-chan portrait license still to
be confirmed. Contributions: [CONTRIBUTING.md](CONTRIBUTING.md).

## Play

Open `project.godot` in Redot or Godot 4 and press **F6 on `scenes/main.tscn`**, or **F5** to run the project. From a terminal:

```sh
./launch.sh
# Start fullscreen:
./launch.sh --fullscreen
```

The Bash launcher detects Redot or Godot, imports the assets, and starts the game. You can invoke it by its full path from any directory. You can also launch directly with `redot --path .` or `godot --path .`.

Choose **Enter the Facility**, then a difficulty. **Marine** is the standard experience. **Explorer** halves incoming damage; **Nightmare** increases it. Find the keycards, open the marked gates, and use the glowing **EXIT** switch. In the final sector, defeat the Warden first.

| Control | Action |
|---|---|
| W / A / S / D | Move / strafe |
| Mouse / left and right arrows | Turn |
| Shift | Run |
| Left mouse / Ctrl | Fire (hold for automatic fire) |
| 1–6 / mouse wheel | Choose weapon |
| E / Space | Open doors, search secret walls, use exit |
| Tab | Automap; movement remains active |
| Escape / P | Pause / resume |
| F5 / F9 | Quicksave / quickload |
| F11 | Toggle fullscreen |

Classic rules: horizontal mouse aim, vertical auto-aim, no jumping, no magazines or reloads. Armor absorbs part of incoming damage. Hazard suits protect against acid and lava for 30 seconds. Explosive barrels damage nearby monsters **and you**. Strange walls may hide secret supplies.

### Browser build

**Play online:** https://web-production-2bbe1.up.railway.app

The web edition requires a current **desktop WebGL 2 browser, keyboard and mouse**.
Opening the link loads straight into the game's title screen; there is no extra
launch button. Browser audio unlocks on your first click or keypress. Choose a
difficulty in the game. There are no touch controls. The game occupies the entire
browser window, without a surrounding
header, footer or embedded-player frame. The 16:9 view scales without stretching
or cropping; other window shapes use letterboxing. Use **P** or Escape to pause,
the small Fullscreen control on the title/pause screens to hide browser chrome,
and the pause menu to save/load. Losing mouse capture or switching tabs
pauses automatically. Saves use this browser's IndexedDB storage; clearing site
data deletes them, and private browsing may not retain them.

To build a release export, install matching Redot/Godot web export templates:

```sh
./export-web.sh
# Or choose another engine executable:
REDOT_BIN=godot ./export-web.sh
```

The reproducible deployment bundle is written to `build/web/<build-id>/`; the
current path is recorded in `build/web-path`. Old builds are left intact rather
than deleting local files. The bundle includes Nginx, Railway healthcheck config,
credits and original third-party notices. Refresh `web/engine-notices/` if you
change the runtime version. Generated exports are excluded from Git.

Deploy **only the generated bundle**, not the source tree:

```sh
# Confirm the intended Railway project/environment before deploying:
railway status --json
railway up "$(cat build/web-path)" --path-as-root --service web --environment production
railway domain --service web --port 8080
```

The game remains at 480×270 internally, even in fullscreen. Single-threaded WASM
avoids SharedArrayBuffer/cross-origin-isolation requirements. WebAudio sample
playback reduces audio latency; desktop playback is unchanged. Cached glyphs
preserve every original bitmap-font pixel, but a rendered regression workload
uses **188 instead of 2,626 draw submissions**. Exploration updates once per
visited tile and animated floor textures update at their authored 3-fps cadence.
The initial engine + game download is about **10.3 MiB with gzip**, down from
38.4 MiB uncompressed; fingerprinted files cache across visits and HTML revalidates
on updates. Source-art bundles, reference sheets, hand-authoring layers and tests
are excluded from the playable pack. No accounts or backend database are needed.

## Campaign

1. **The Silent Foundry** — deserted techbase, blue-key hunt, shotgun armory, secret supply room.
2. **Waste Cathedral** — brick-and-steel containment complex, acid channels, two-stage key progression, rotary cannon and rockets.
3. **The Black Heart** — open-sky infernal reactor, lava trenches, plasma rifle, multi-phase Warden boss, and ending.

Weapons: iron fist, service pistol, pump shotgun, rotary cannon, rocket launcher, arc plasma rifle. Enemies: possessed thralls, projectile-throwing embers, armored brutes, and the Warden. Enemies see/hear the player, navigate around walls, and open unlocked doors. Levels include kill/item/secret totals and completion times.

Inventory carries between sectors; keycards reset. Each sector starts with an autosave. Death offers a sector-start checkpoint retry. Manual saves restore position, inventory, enemies, pickups, doors, barrels, exploration, and campaign statistics. Saves and settings are stored in the engine's `user://` directory, outside the source project.

## Options

The in-game options menu includes music/SFX volumes, mouse sensitivity, always-run, crosshair, and CRT filtering. Settings persist between launches. Menus support both mouse and keyboard.

## Assets and credits

The game uses detailed **BSD-licensed Freedoom 0.13.0 artwork** for weapons, pickups, enemies, scenery, effects and world textures. The player portrait adapts your supplied **Redot-chan concept 2.0 / DLC 2 expression sheet**, signed **Rune**; the reference is retained in `assets/ui/redot_chan/`. The sky, lighting panels, bitmap font, contact shadows, Redot-inspired logo/HUD/menu artwork, exit switch, sound effects and synth-metal soundtrack are original. Freedoom source art, licenses and credits are included in `assets/weapons/freedoom/`, `assets/pickups/freedoom/` and `assets/presentation/freedoom/`.

Enemy presentation includes **221 authored frames and eight-way rotations**, with proper walk/attack/hurt/death poses and grounded corpses. Normal soldier deaths end on the fallen-body sprite rather than the start of a separate gib animation. Blue/red access credentials are original horizontal keycards, with matching world and HUD artwork. Industrial doors have textured rails, recessed key readers and access-status lights; secret walls remain concealed. Scenery, explosions, projectiles, acid and lava animate. First-person weapons remain low on screen, and supplies rest on the floor.

Visible first-person hands match Redot-chan: slimmer hands/wrists, warm pale skin, black sleeves and red cuffs. All **13 visible-hand poses** (fists, pistol and shotgun, including punching/recoil/pumping) use the same style. Heavy weapons naturally obscure the hands. Original gun/flash pixels and animation origins are preserved; the hand-only masks/replacement layers are retained in `assets/weapons/redot_hands/`. Pinned Freedoom source PNGs remain unmodified.

The HUD and every menu use Redot's **#FF3B0A orange / #09090B near-black / white** branding, outlined cards and pixel-grid motifs. Redot-chan's portrait reacts to health, pickups, damage, death and victory; **shooting does not change the face**. Pickup reactions hold for **1.6 seconds** and damage for **1.4 seconds**. Head/eye alignment and **0.22-second eased crossfades** avoid jumping or snapping, including interrupted transitions. Shooting cannot interrupt pickup/damage reactions; death and critical-health warnings take priority. Pausing preserves reaction holds; starting, retrying, loading or changing sectors clears them. Screen flashes remain brief and do not control portrait timing.

The deterministic asset generator requires only the Python standard library:

```sh
python3 tools/generate_assets.py
redot --headless --editor --import --path .
```

Generated PNG and WAV files are included, so Python is not needed to play. See `assets/CREDITS.md`.

To rebuild individual presentation assets, fully offline:

```sh
python3 tools/build_weapon_sprites.py
python3 tools/build_pickup_sprites.py
python3 tools/build_world_art.py
python3 tools/build_ui_art.py
python3 tools/build_redot_chan.py
redot --headless --editor --import --path .
```

## Project layout

- `scenes/main.tscn` — launch scene
- `scripts/game.gd` — session flow, saves, settings, effects
- `scripts/campaign.gd` — editable handcrafted room layouts and encounters
- `scripts/level.gd` — batched textured geometry, collision, navigation, exploration
- `scripts/player.gd`, `arsenal.gd` — movement, inventory, weapon behavior
- `scripts/enemy.gd`, `projectile.gd`, `barrel.gd` — combat actors
- `scripts/door.gd`, `pickup.gd` — world interactions
- `scripts/prop.gd` — grounded animated scenery
- `scripts/hud.gd`, `pixel_font.gd`, `brand_theme.gd` — Redot-branded pixel UI and menus
- `scripts/redot_portrait.gd` — event-driven portrait holds, priorities and continuous blends
- `scripts/weapon_view.gd` — weapon-specific viewmodel placement and animation
- `scripts/audio.gd` — soundtrack and pooled sound playback
- `scripts/browser_support.gd` — browser lifecycle/web-shell bridge
- `shaders/retro.gdshader` — optional palette, scanline, vignette treatment
- `shaders/portrait_blend.gdshader` — tiny alpha-correct portrait compositor
- `tools/generate_assets.py` — reproducible original art/audio
- `tools/build_weapon_sprites.py` — offline weapon atlas builder and optional pinned upstream fetch
- `tools/redot_hands.py` — hand-only character palette, silhouette and sleeve adaptation
- `tools/build_pickup_sprites.py` — offline pickup/animation/HUD-icon builder
- `tools/build_world_art.py` — directional enemy, scenery, effect and texture builder
- `tools/build_ui_art.py` — Redot-inspired logo/HUD/menu/exit-switch artwork
- `tools/build_redot_chan.py` — offline expression-sheet adaptation
- `export_presets.cfg`, `web/shell.html` — single-threaded web export and branded loader
- `tools/build_web.py`, `deploy/` — fingerprinted/precompressed static Railway bundle

## Verification

```sh
redot --headless --editor --import --path .
redot --headless --path . --script res://tests/smoke.gd -- --test
```

The integration suite checks key progression in every level, movement and door collision, combat, pickups, armor, enemy AI, pause, automap, save/load, inventory carryover, projectiles, barrel explosions, hazards, checkpoint retry, and campaign completion. `--test` disables gameplay autosaves and mouse capture.

Pickup-specific regressions cover all 15 item types, authored sprite colors and transparency, grounded geometry, animation, full-capacity rejection, collection rewards and sprite/shadow save-state consistency:

```sh
redot --headless --path . --script res://tests/pickups.gd -- --test
```

For a labeled in-world pickup showcase:

```sh
redot --path . --script res://tests/capture_pickups.gd -- --test --capture-dir=/tmp/opencode
```

The native-rendered weapon regression checks untouched gun/flash color/transparency fidelity, explicit hand-layer composition, slimmer silhouettes and consistent skin/sleeve/cuff palettes. It verifies that all six weapons leave the aiming area clear during idle, firing, pumping/punching, movement and switching, and captures a weapon overview. Offline Python tests also check source immutability and deterministic masks/geometry:

```sh
python3 tests/weapon_hands.py
redot --path . --script res://tests/weapon_visual.gd -- --test --capture-dir=/tmp/opencode
```

Presentation regressions validate authored enemy/scenery/effect/portrait frames, eight-way enemy views, corpse restoration, key-reader indicators, secret-wall concealment and large-text menu layouts:

```sh
redot --headless --path . --script res://tests/presentation.gd -- --test
redot --path . --script res://tests/capture_presentation.gd -- --test --capture-dir=/tmp/opencode
```

Live-death/keycard regressions kill all four enemy types through their actual physics-driven death sequence, verify collapsed silhouettes and save/load, and check card proportions and access credentials:

```sh
redot --headless --path . --script res://tests/death_and_keycards.gd -- --test
# Also capture native-rendered corpses and card/HUD views:
redot --path . --script res://tests/death_and_keycards.gd -- --test --capture --capture-dir=/tmp/opencode
```

For rendered screenshots, supply an existing output directory:

```sh
redot --path . --script res://tests/capture.gd -- --test --capture-dir=/tmp/opencode
```

Redot UI regressions cover every pickup/weapon event, extended/repeated reaction holds, priority, pause/resume, interrupted easing, lifecycle resets and all menu layouts. Native-rendered checks also validate exact portrait colors/alpha and halfway/interrupt crossfades:

```sh
redot --headless --path . --script res://tests/redot_ui.gd -- --test
redot --path . --script res://tests/redot_ui.gd -- --test --capture --capture-dir=/tmp/opencode
# Add --animate to capture a 30-fps sequence of the actual HUD reactions.
```

Web-export and rendering-optimization checks:

```sh
./export-web.sh
python3 tests/web_bundle.py
redot --path . --script res://tests/pixel_font.gd
redot --path . --script res://tests/performance.gd -- --test
# Browser integration checks (Bun, Playwright and an installed Chrome):
cd tests/browser
bun install
bun run test https://web-production-2bbe1.up.railway.app
```

Set `CHROME_BIN` to use a specific Chromium/Chrome executable and `CAPTURE_DIR` to
choose screenshot output (defaults to `/tmp/opencode`). Browser checks cover real
WASM startup, keyboard menus, pointer capture/loss, firing/WebAudio, automap,
fullscreen, IndexedDB saves across reloads, responsive layout and console errors.
The Python bundle audit checks actual PCK contents, dynamic resource availability,
license inclusion and gzip/hash integrity. Font checks compare rendered pixels to
the original implementation; performance results depend on renderer and hardware.
