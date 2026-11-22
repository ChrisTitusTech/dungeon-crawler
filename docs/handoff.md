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

Windows and Linux exports are available from successful `main` workflow runs. Download `dungeon-crawler-builds` and extract the platform archive with the executable and its `.pck` together. The editor can regenerate `.godot/` and `build/` locally. [GitHub Actions](https://github.com/ChrisTitusTech/dungeon-crawler/actions/workflows/ci.yml)

## Carry over a playtest save

Save in the safe room and close the game on both PCs before copying files. Back up any destination slots you want to keep. Copy the `floor-one-<slot>.save` files you want to resume and `audio-settings.cfg` if you want the same volume settings.

| OS | Godot user data directory |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\Dungeon Crawler\` |
| Linux | `${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Dungeon Crawler/` |

The files live outside the Git checkout. Checkpoints preserve the current floor, time remaining, party, and advancement choices. Saves made before the twelve-class roster are incompatible. Use **Replace slot** to start fresh.

## Resume Milestone 3

Milestones 0 through 2 are complete. Milestone 3 has a first pass of faction reputation, refuge crafting and guild contracts, original audio, smooth held movement, and side-view battles with a torchlit vault backdrop. Each floor's stairs unlock after its boss falls. Floors 2 and 3 checkpoint on arrival in the refuge, and Floor 3 records the clear and shows the summary. [Roadmap](roadmap.md)

For the first playtest on the new PC, start a fresh slot, hold a direction along an open corridor, and enter a battle. Check that the camera follows without a stop at each tile, the opposing formations and combat readouts fit, and the clock continues to run. Enter the safe room, confirm the clock pauses, and reload the slot to check that the time was saved.

For the progression playtest, rescue Cinder on Floor 2, then use the stairs after each boss. Check that party state and supplies carry forward, the new clock starts on leaving the safe room, and reloading preserves the pet and selected race or class. The later floors reuse Floor 1 art and audio. The roadmap tracks the remaining demo work. [Technical design](technical-design.md)
