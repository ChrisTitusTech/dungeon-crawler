# Technical Design

## Implemented through Milestone 1

- The project pins Godot 4.7.2 stable and uses statically typed GDScript. [Prerequisites](../PREREQUISITES.md)
- A 640×360 logical canvas opens in a 1280×720 window. The tile map converts grid positions to 32×16 isometric diamonds. The dungeon view draws beveled stone tiles, raised walls, torchlight, and actors in depth order.
- `DungeonFloor` owns movement, field of view, explored cells, and enemy AI. `BattleRules` resolves initiative and combat. `DungeonGame` carries party HP and tonics between the exploration and battle scenes.
- A Godot `Resource` defines the hand-built test floor. The movement map supports keyboard, gamepad, and mouse. Battle menus use built-in UI actions and pointer input.
- GUT 9.7.1 covers project setup, dungeon rules, combat rules, and scene integration. GitHub Actions runs the tests and exports Windows and Linux release builds. [CI workflow](../.github/workflows/ci.yml)
- The repository keeps scenes in `scenes/`, game and presentation code in `scripts/`, and content in `data/` and `assets/`. Tests and design documents live in `tests/` and `docs/`.

## Floor 1 vertical slice

- `FloorOneGenerator` uses the run seed to place varied chambers on a 168×118 map, connect them with a route network, and add optional loops and encounters. Authored templates anchor the entry and boss chamber. The safe room has its own layout and movement state.
- `CampaignRun` owns party progression, the inventory, explored sites, the collapse clock, and show events. `DungeonGame` advances the clock using elapsed real time during exploration and combat. `CampaignContent` loads heroes, enemies, items, skills, reward tables, and announcer lines from a Godot resource.
- `CampaignSave` stores a versioned snapshot per slot under `user://`. Checkpoints record the floor, seed, dungeon return tile, safe-room position, party, inventory, enemies, explored cells, and remaining seconds. Collapse and party wipes restore the latest checkpoint.

## Milestone 3 systems in progress

- Floors 2 and 3 use authored layouts with their own bosses. The Silkspire Galleries have 870 walkable tiles across exhibit halls and side galleries. The Tithe Keep has 1,106 walkable tiles across its processional hall, barracks, and outer wings. `CampaignRun.escape()` swaps the dungeon and refuge after the current boss is beaten and the player uses the stairs. Party state, inventory, reputation, and contracts carry forward. The next floor starts at its refuge with a full clock and fresh enemies, fog of war, and loot sites. `DungeonGame` saves on arrival and records a completed run at the end of Floor 3.
- The Floor 1 catalog defines rival factions, truce thresholds, recipes, material drops, and guild contracts with victory thresholds. `CampaignRun` applies reputation to live dungeon enemies and records victories and contract status in checkpoints.
- The refuge positions the workbench, Watch envoy, and contract board as physical interactions. The workbench checks all ingredients before spending them. Each active contract pays once when a victory meets its terms.
- `DungeonView` advances the camera and actor positions on the same step clock. Holding a direction chains steps while carrying forward the unused fraction of the frame. The ground redraws when visibility changes. Exploration and combat draw the same articulated models from `ActorArt`. Combat adds windup, recovery, recoil, guard, and defeat poses over the arena, with command input locked during feedback. [Arena artwork](../assets/battle_arena.webp)
- `DungeonAudio` crossfades original exploration, refuge, and battle loops, plays matching cues, and stores separate music and effects levels under `user://`. The audio assets use Git LFS.

## Planned architecture

- Extend faction behaviour and the data catalog for later floors.
- Promote run-level state and services to autoloads as the campaign grows across floors.
