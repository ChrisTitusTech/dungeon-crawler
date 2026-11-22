# PC handoff

## Open the project on the new PC

Install Git, Git LFS, and Godot 4.7.2 stable. Install matching export templates if this PC will build releases. [Prerequisites](../PREREQUISITES.md)

```sh
git lfs install
git clone --branch main https://github.com/ChrisTitusTech/dungeon-crawler.git
cd dungeon-crawler
git lfs pull
```

For an existing clone, switch to `main`, run `git pull --ff-only origin main`, then run `git lfs pull`. Open `project.godot` in Godot and press F5. From a terminal, use `godot_console` on Windows and `godot` on Linux.

```sh
godot --headless --import
godot --headless --script res://addons/gut/gut_cmdln.gd -gexit
```

The suite has 25 tests at handoff. Windows and Linux exports are available from successful `main` workflow runs. Download `dungeon-crawler-builds` and extract the platform archive with the executable and its `.pck` together. The editor can regenerate `.godot/` and `build/` locally. [GitHub Actions](https://github.com/ChrisTitusTech/dungeon-crawler/actions/workflows/ci.yml)

## Carry over a playtest save

Save in the safe room and close the game on both PCs before copying files. Back up any destination slots you want to keep. Copy the `floor-one-<slot>.save` files you want to resume and `audio-settings.cfg` if you want the same volume settings.

| OS | Godot user data directory |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\Dungeon Crawler\` |
| Linux | `${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Dungeon Crawler/` |

The files live outside the Git checkout. Old turn-based checkpoints start with 30 minutes when first loaded. New checkpoints preserve the time remaining when they were saved.

## Resume Milestone 3

Milestones 0 through 2 are complete. Floor 1 is playable from the entry door through Sir Aldren and the stairs. The stairs record the clear and show a summary. Milestone 3 has a first pass of faction reputation, refuge crafting and guild contracts, original audio, smooth held movement, and side-view battles with a torchlit vault backdrop. [Roadmap](roadmap.md)

For the first playtest on the new PC, start a fresh slot, hold a direction along an open corridor, and enter a battle. Check that the camera follows without a stop at each tile, the opposing formations and combat readouts fit, and the clock continues to run. Enter the safe room, confirm the clock pauses, and reload the slot to check that the time was saved.

The next floor progression work starts at `DungeonGame._interact()` and `CampaignRun.escape()`. Floor 1 currently ends the run at the stairs. The next milestone needs a floor transition that carries the party and inventory forward, initializes the next floor with a fresh countdown, and saves which floor to restore. The roadmap tracks the remaining demo work. [Technical design](technical-design.md)
