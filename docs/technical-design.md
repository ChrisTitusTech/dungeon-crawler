# Technical Design

## Implemented through Milestone 1

- The project pins Godot 4.7.2 stable and uses statically typed GDScript. [Prerequisites](../PREREQUISITES.md)
- A 480×270 viewport with integer scaling draws the exploration grid as 32×16 isometric diamonds. `TileMapLayer` draws the flagstone floor. The dungeon view draws joined walls, torches, and 48-pixel character sprites in depth order.
- `DungeonFloor` owns movement, field of view, explored cells, and enemy AI. `BattleRules` resolves initiative and combat. `DungeonGame` carries party HP and tonics between the exploration and battle scenes.
- A Godot `Resource` defines the hand-built test floor. The movement map supports keyboard, gamepad, and mouse. Battle menus use built-in UI actions and pointer input.
- GUT 9.7.1 covers project setup, dungeon rules, combat rules, and scene integration. GitHub Actions runs the tests and exports Windows and Linux release builds. [CI workflow](../.github/workflows/ci.yml)
- The repository keeps scenes in `scenes/`, game and presentation code in `scripts/`, and content in `data/` and `assets/`. Tests and design documents live in `tests/` and `docs/`.

## Floor 1 vertical slice

- `FloorOneGenerator` uses the run seed to place varied chambers on a 118×84 map, connect them with a route network, and add optional loops and encounters. Authored templates anchor the entry and boss chamber. The safe room has its own layout and movement state.
- `CampaignRun` owns party progression, the inventory, explored sites, the collapse clock, and show events. `CampaignContent` loads heroes, enemies, items, skills, reward tables, and announcer lines from a Godot resource.
- `CampaignSave` stores a versioned snapshot per slot under `user://`. Checkpoints record the layout version, seed, dungeon return tile, safe-room position, party, inventory, enemies, explored cells, and clock. Existing slots keep the original layout with a doorway to the new safe room. Collapse and party wipes restore the latest checkpoint, and a Floor 1 clear records the completed run.

## Planned architecture

- Extend the data catalog with recipes, factions, and content for later floors.
- Promote run-level state and services to autoloads as the campaign grows across floors. Extend the existing event routing to viewers and sponsors.
