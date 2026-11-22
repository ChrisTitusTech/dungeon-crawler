# Technical Design

- **Engine:** Godot 4.7.2 stable, pinned (see [PREREQUISITES.md](../PREREQUISITES.md)). GDScript with static typing throughout.
- **Rendering:** 16x16 tiles, low internal resolution (for example 480x270) with integer scaling. `TileMapLayer` for maps.
- **Architecture:** game rules live in plain GDScript classes separate from scenes, so combat, simulation, and generation can be unit-tested and run headless. Scenes present state and send commands.
- **Data:** items, monsters, skills, recipes, factions, achievements, and announcer lines are data files (Godot `Resource` or JSON), not code. This is what makes 18 floors of content affordable.
- **Autoloads:** game state, save manager, event bus, audio, and scene transitions.
- **Events:** one event bus feeds achievements, viewer count, and the announcer, so new content only needs to listen for events.
- **Generation:** seeded generator that places hand-crafted room templates and connects them with procedural rooms and corridors, with a connectivity check.
- Godot input actions cover grid movement, tile selection, interaction, waiting, party, inventory, minimap, and pause. Movement uses WASD, arrow keys, the D-pad, or the left stick. The primary mouse button selects a tile. Menus use Godot's built-in UI actions and pointer input.
- GUT 9.7.1 runs headless tests. GitHub Actions runs the tests and exports both Windows and Linux releases.
- **Layout:** `scenes/`, `scripts/` (core, battle, world, sim, ui), `data/`, `assets/`, `tests/`, `docs/`.
