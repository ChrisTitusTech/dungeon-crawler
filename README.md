# Dungeon Crawler

Working title. A single-player 2D party RPG for Windows and Linux, built in Godot 4 with GDScript.

You are a contestant in a lethal, televised 18-floor dungeon run by a snarky System AI. Explore isometric floors with a party of up to four, fight visible enemies in JRPG-style menu battles, and survive each floor before it collapses. Factions, crafting, and body-part injuries run underneath.

## Status

**Milestones 0 through 2 are complete.** Start beside the safe-room door, recruit Sable, and defeat Sir Aldren, the Hollow Castellan, before Floor 1 collapses. Milestone 3 expands the campaign systems and builds toward the three-floor demo. [Roadmap](docs/roadmap.md)

## Documentation

- [Game design](docs/game-design.md): what the game is and how its systems work.
- [Technical design](docs/technical-design.md): engine, architecture, and project layout.
- [Roadmap](docs/roadmap.md): milestones, backlog, risks, and open questions.
- [Prerequisites](PREREQUISITES.md): tools to install and how to verify them.

## Getting started

Install the tools, then open `project.godot` in the editor or run `godot --editor --path .` from the repo root. Press F5 to run the project. [Prerequisites](PREREQUISITES.md)

### Play Floor 1

Choose one of three save slots. New runs generate a 118×84 dungeon with varied rooms, paths, and encounters. Use the marked dungeon door to enter the separate safe-room map. Walk to a bed to fully heal standing party members and treat wounds, or use the dining table to restore up to half their maximum HP.

Entering the safe room saves a checkpoint. Use the chest to save again or open reward boxes. Use the interior door to return to the dungeon tile you left. The collapse clock advances with movement and waiting on the dungeon floor. A wipe or collapse returns the party to its last safe-room checkpoint.

Party HP, injuries, and equipment carry between fights. The pack lets you use tonics, treat wounds, and equip loot. Spend earned stat points from the Party menu. Each fighter gets one use of their skill per battle. After defeating Sir Aldren, use the stairs to clear the floor.

| Action | Keyboard | Gamepad | Mouse |
| --- | --- | --- | --- |
| Move one tile | WASD or arrow keys | D-pad or left stick | Click an adjacent tile |
| Wait one turn | Q | Right shoulder button | Wait button |
| Use a door, furnishing, or other landmark | E | A | Use button |
| Open party and training | C | Y | Party button |
| Open inventory | I | X | Pack button |
| Toggle minimap | M | Back / View | Map button |
| Choose a battle command | Arrow keys and Enter | D-pad and A | Click a command |
| Pause | P | Start / Menu | |

Movement follows the diagonal tile edges of the isometric view.

Fleeing leaves the enemy on the map and gives the party one turn to move away. To revisit the original hand-built prototype, run `godot --path . -- --prototype`.

### Run tests

From the repo root, import the project and run the GUT suite.

```sh
godot --headless --import
godot --headless --script res://addons/gut/gut_cmdln.gd -gexit
```

On Windows, use `godot_console` to see command output and exit codes.

### Export builds

In the editor, select **Project > Export** and choose **Windows Desktop** or **Linux**. To export from the terminal, create the `build/windows` and `build/linux` output directories, then run these commands from the repo root.

```sh
godot --headless --export-release "Windows Desktop" build/windows/dungeon-crawler.exe
godot --headless --export-release Linux build/linux/dungeon-crawler.x86_64
```

GitHub Actions runs the tests on pushes and pull requests, then uploads both release builds as artifacts. [CI workflow](.github/workflows/ci.yml)
