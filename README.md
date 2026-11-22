# Dungeon Crawler

Working title. A single-player 2D party RPG for Windows and Linux, built in Godot 4 with GDScript.

Your party must survive an 18-floor dungeon run by a snarky System AI. Explore isometric floors with a party of up to four, fight visible enemies in JRPG-style menu battles, and survive each floor before it collapses. Factions, crafting, and body-part injuries run underneath.

## Status

**Milestones 0 through 2 are complete.** Milestone 3 is in progress. The campaign runs through three floors, each with its own layout and boss. Floor 1 has faction reputation, crafting, guild contracts, and the first art and audio pass. [Roadmap](docs/roadmap.md)

## Documentation

- [PC handoff](docs/handoff.md) covers cloning, restoring local saves, and picking up Milestone 3.
- [Game design](docs/game-design.md) describes the game and its systems.
- [Technical design](docs/technical-design.md) explains the architecture and project layout.
- [Roadmap](docs/roadmap.md) tracks milestones and open work.
- [Prerequisites](PREREQUISITES.md) lists the tools needed on Windows and Linux.

## Getting started

Install the tools, then open `project.godot` in the editor or run `godot --editor --path .` from the repo root. Press F5 to run the project. [Prerequisites](PREREQUISITES.md)

### Play the campaign

Choose one of three save slots. New runs generate a 118×84 dungeon with varied rooms, paths, and encounters. Use the marked dungeon door to enter the separate safe-room map. Walk to a bed to fully heal standing party members and treat wounds, or use the dining table to restore up to half their maximum HP.

Entering the safe room saves a checkpoint. Use the chest to save again or open reward boxes. Use the interior door to return to the dungeon tile you left. Each floor starts with 30 minutes. The countdown runs during exploration and battle, even while you stand still, and pauses in the safe room and campaign menus. A wipe or collapse lets you reload your last safe-room checkpoint with its saved time remaining.

At the workbench, turn pelts, iron scrap, and bitterroot into supplies or a Tempered Longsword. Hunting Ashfang beasts or offering bandages to the Watch envoy can earn a truce with Barrow Sentinels. Visit the refuge contract board to see guild offers and their battle conditions. The two Floor 1 contracts unlock after two and five victories.

Party HP, injuries, and equipment carry between fights. The pack lets you use tonics, treat wounds, and equip loot. Spend earned stat points from the Party menu. Each fighter gets one use of their skill per battle. Recruit Sable before leaving Floor 1. Look for Cinder, a wounded Ashfang rat, in the upper gallery on Floor 2. Rescue Cinder with a bandage and an open party slot.

After defeating each boss, use the stairs. Floors 2 and 3 start at a safe-room checkpoint with a fresh 30-minute countdown. Choose Rook's race at the Floor 2 stairs. A Watch truce unlocks an extra race. At the Floor 3 stairs, choose any of the twelve base classes. Each has its own combat skill. Choosing the class finishes the run.

The vault has goblin salvage crews. The Bell Galleries have deep amber slimes, long-ranging spiders, and some very hungry prize chests. The Tithe Keep is guarded by armored skeletons and stone gargoyles. Each floor has a broadcast terminal that trades supplies for time on the collapse clock.

The expanded floors use a new checkpoint format. Choose **Replace slot** to start a new run in a slot occupied by an older save.

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

Movement follows the diagonal tile edges of the isometric view. Hold a direction for continuous movement. Battles place the party on the right and the enemy on the left in a torchlit vault.

The game opens in a 1280×720 window. The 640×360 game canvas scales in whole steps to preserve sharp pixel art.

The save-slot and pause menus offer separate music and effects volume controls.

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
