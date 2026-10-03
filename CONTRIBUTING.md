# Contributing to DEAD SIGNAL

Bug reports, ideas and pull requests are welcome.

## Repository access

- Organization members in **OpenStaticFish/redot-doom-contributors** have Write
  access to this repository: they can push branches, manage issues and merge pull
  requests without a required approval. Review is encouraged, not mandatory.
- People outside the organization have public Read access only. They can open
  issues, fork the repository and submit pull requests, but cannot push to this
  repository or merge changes themselves.
- Organization owners manage access. Add new organization members to the
  `redot-doom-contributors` team if they should contribute directly. GitHub does
  not automatically add new organization members to a repository-scoped team.
- Other organization repositories keep their existing permissions. Do not grant
  outside collaborators Write access as a shortcut for reviewing their PRs.

## External contribution workflow

1. Open an issue for bugs or discuss substantial changes before implementing them.
2. Fork `OpenStaticFish/redot-doom` and create a focused branch in your fork.
3. Make changes against `master`, following the surrounding GDScript/Python style.
4. Run the relevant checks below and include screenshots for visual changes.
5. Open a pull request from your fork to this repository's `master` branch.

Include your Redot/Godot version, operating system, reproduction steps and expected
behavior when reporting bugs. Never upload credentials, saves or private logs.

## Development and verification

Open `project.godot` in Redot 26.2 / Godot 4.3+ and run `scenes/main.tscn`, or use
`./launch.sh`. Included assets mean Python is not required to play.

```sh
redot --headless --editor --import --path .
python3 tests/weapon_hands.py
redot --headless --path . --script res://tests/smoke.gd -- --test
redot --headless --path . --script res://tests/pickups.gd -- --test
redot --headless --path . --script res://tests/presentation.gd -- --test
redot --headless --path . --script res://tests/death_and_keycards.gd -- --test
redot --headless --path . --script res://tests/redot_ui.gd -- --test
```

`--test` disables gameplay autosaves and mouse capture. Native-rendered weapon/UI
checks require a display; see [README.md](README.md#verification). Python asset
builders use the standard library and the included, pinned sources.

## Licensing and safe review

Original code contributions are accepted under MIT. Keep third-party credits and
license notices intact. New artwork must have an explicit redistribution license
and attribution; do not assume an image found online is free to reuse. See
[LICENSING.md](LICENSING.md), especially the unresolved Redot-chan artwork license.

Treat fork code as untrusted. Do not run it with secrets or a write-capable token.
If Actions workflows are added, external fork workflows require a maintainer's
approval; repository workflows default to a read-only token and cannot approve
PRs on behalf of contributors. Do not use `pull_request_target` to execute code
from an untrusted fork.
