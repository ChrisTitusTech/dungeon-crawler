# Technical Design

## Implemented through Milestone 1

- The project pins Godot 4.7.2 stable and uses statically typed GDScript. [Prerequisites](../PREREQUISITES.md)
- A 480×270 viewport with integer scaling draws the exploration grid as 32×16 isometric diamonds. `TileMapLayer` draws the flagstone floor. The dungeon view draws joined walls, torches, and 48-pixel character sprites in depth order.
- `DungeonFloor` owns movement, field of view, explored cells, and enemy AI. `BattleRules` resolves initiative and combat. `DungeonGame` carries party HP and tonics between the exploration and battle scenes.
- A Godot `Resource` defines the hand-built test floor. The movement map supports keyboard, gamepad, and mouse. Battle menus use built-in UI actions and pointer input.
- GUT 9.7.1 covers project setup, dungeon rules, combat rules, and scene integration. GitHub Actions runs the tests and exports Windows and Linux release builds. [CI workflow](../.github/workflows/ci.yml)
- The repository keeps scenes in `scenes/`, game and presentation code in `scripts/`, and content in `data/` and `assets/`. Tests and design documents live in `tests/` and `docs/`.

## Planned architecture

- Move items, monsters, skills, recipes, factions, achievements, and announcer lines into Godot `Resource` or JSON data files as their systems are built.
- Use a seeded generator to connect hand-crafted room templates with procedural rooms and corridors, then check connectivity.
- Introduce autoloads for game state, saving, events, audio, and scene transitions as those systems come online. Route achievement, viewer, and announcer updates through one event bus.
