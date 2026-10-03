# Pickup source art

These 21 frames are from **Freedoom 0.13.0**, Copyright © 2001–2024 Contributors
to the Freedoom project, distributed under **BSD-3-Clause**. The complete
upstream license is in `COPYING.txt`; the contributor list is in `CREDITS`.

Source: https://github.com/freedoom/freedoom/tree/v0.13.0/sprites

`tools/build_pickup_sprites.py` crops transparent margins and composes the
frames into bottom-aligned atlases. It preserves their original colors,
proportions and transparency, and produces aspect-preserving HUD thumbnails.

The runtime uses appropriate object sizes, gentle animation for armor/keys/
soul orbs, and original soft ground-contact shadows. Supply boxes and weapons
rest on the floor. The source PNGs are included for fully offline rebuilding;
`--fetch` is only needed to refresh the pinned source through the GitHub CLI.
