# Dungeon Crawler

Working title. A single-player 2D party RPG for Windows and Linux, built in Godot 4 with GDScript.

You are a contestant in a lethal, televised 18-floor dungeon run by a snarky System AI. Explore isometric floors with a party of up to four, fight visible enemies in JRPG-style menu battles, and survive each floor before it collapses. Factions, crafting, and body-part injuries run underneath.

## Status

**Milestones 0 and 1 are complete.** The Milestone 2 vertical slice is playable. Start in a safe room, recruit Sable, and defeat Sir Aldren, the Hollow Castellan, before Floor 1 collapses. A human pacing playtest is still open. [Roadmap](docs/roadmap.md)

## Documentation

- [Game design](docs/game-design.md): what the game is and how its systems work.
- [Technical design](docs/technical-design.md): engine, architecture, and project layout.
- [Roadmap](docs/roadmap.md): milestones, backlog, risks, and open questions.
- [Prerequisites](PREREQUISITES.md): tools to install and how to verify them.

## Getting started

Install the tools, then open `project.godot` in the editor or run `godot --editor --path .` from the repo root. Press F5 to run the project. [Prerequisites](PREREQUISITES.md)

### Play Floor 1

Choose one of three save slots. The safe room saves a checkpoint when you enter and offers a manual save, healing, and loot-box opening. The collapse clock advances with movement and waiting outside camp. A wipe or collapse restores the last checkpoint.

Party HP, injuries, and equipment carry between fights. The pack lets you use tonics, treat wounds, and equip loot. Spend earned stat points from the Party menu. Each fighter gets one use of their skill per battle. After defeating Sir Aldren, use the stairs to clear the floor.

| Action | Keyboard | Gamepad | Mouse |
| --- | --- | --- | --- |
| Move one tile | WASD or arrow keys | D-pad or left stick | Click an adjacent tile |
| Wait one turn | Q | Right shoulder button | Wait button |
| Use a nearby landmark or open camp | E | A | Use button |
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
