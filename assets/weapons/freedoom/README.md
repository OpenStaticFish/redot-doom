# First-person weapon source art

These 30 PNG frames are from **Freedoom 0.13.0**, distributed under the
**BSD-3-Clause license**. Copyright © 2001–2024 Contributors to the Freedoom
project. The full upstream license is in `COPYING.txt`; contributors are
listed in `CREDITS`.

Source: https://github.com/freedoom/freedoom/tree/v0.13.0/sprites
Authored frame offsets: the matching upstream `buildcfg.txt`, included here.

`tools/build_weapon_sprites.py` composes the PNGs into aligned RGBA atlases in
`assets/weapons/`, retaining the original proportions, colors, transparency,
and per-frame origins. DEAD SIGNAL positions these atlases below the aiming
area and uses the original recoil, pump, punch, and muzzle-flash poses.

The `gh` CLI is only needed for an explicit `--fetch` of the pinned upstream
source files. The included sources can be rebuilt completely offline.
