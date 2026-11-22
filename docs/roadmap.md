# Roadmap

## Milestone 0: Foundation
Project setup, pinned Godot version, folder layout, input map, CI running tests and exports, and the design document in `docs/`.

## Milestone 1: Core prototype
Grid movement, field of view, minimap, one hand-made test map, visible enemies, and a transition into a working battle screen with attack, defend, item, and flee. Placeholder art.

## Milestone 2: Vertical slice (floor 1)
One complete floor: procedural generation around a hand-crafted safe room and boss, collapse timer, party of up to 4 with one recruit, levelling, inventory and gear, injuries, save and wipe-reload, achievements with loot boxes, and first announcer lines. Goal: a 30 to 60 minute playable that shows whether the game is fun.

## Milestone 3: Systems and demo (floors 1 to 3)
Factions and reputation, crafting, viewers and sponsors, race and class selection, pets, full gamepad support, first pass on real art and audio, settings and accessibility options. Ends in a public demo and Steam page.

## Milestone 4: Early Access (floors 1 to 6)
Two full tiers of content, balance pass, save migration, tutorialisation, Steam integration (achievements, cloud saves), Steam Deck check, and launch.

## Milestone 5: Early Access updates (floors 7 to 15)
One tier per major update, each with new enemies, factions, sponsors, and a system twist, guided by player feedback.

## Milestone 6: 1.0 (floors 16 to 18)
Final tier, ending, full balance and polish pass, localisation readiness, and release.

## Backlog

Ordered work items up to the demo:

1. `project-setup` is complete. The Godot project, folder layout, input map, and Git rules are in place.
2. `ci-pipeline` has GUT tests and a GitHub Actions workflow for tests and exports. The first hosted run is pending.
3. `design-docs`: write the spec to `docs/` (done).
4. `grid-exploration`: grid movement, turn stepping, camera, test map.
5. `fov-minimap`: field of view, fog of war, minimap.
6. `map-enemies`: visible enemies with simple AI and battle triggers.
7. `battle-core`: battle rules engine with tests.
8. `battle-ui`: battle scene, menus, timeline.
9. `data-pipeline`: data-driven items, monsters, skills.
10. `party-progression`: party of 4, stats, levelling, recruits.
11. `inventory-gear`: inventory, equipment, loot drops.
12. `injury-system`: body parts and persistent injuries.
13. `floor-generation`: seeded hybrid floor generator.
14. `safe-room-save`: safe rooms, save/load, wipe reload.
15. `collapse-timer`: floor turn budget and collapse.
16. `show-layer`: event bus, achievements, loot boxes, announcer.
17. `vertical-slice`: floor 1 content, boss, and playtest.
18. `factions`: factions and reputation.
19. `crafting`: recipes and stations.
20. `viewers-sponsors`: viewer count and sponsors.
21. `race-class`: race and class selection, pets.
22. `demo-release`: floors 2 and 3, art and audio pass, demo and Steam page.

## Risks and open questions

- **Scope is the main risk.** 18 floors with simulation systems is a multi-year project for a small team. The milestones are ordered so that each one is shippable and the game can be judged after Milestone 2.
- **Art and audio source** is undecided: commissioned, made in-house, or licensed packs restyled to the palette. Placeholders are used until Milestone 3.
- **Title, setting, and tone bible** are still needed, including the System AI's voice. Humour depends on the writing, so writing needs budgeted time.
- **Battle pacing:** separate battle screens can make frequent fights tedious. Visible enemies, fleeing, and fast animations mitigate this; the vertical slice must test it.
- **Simulation versus readability:** factions and injuries must produce outcomes the player can see and understand, or they are wasted work.
- **Exact floors for race and class choice**, the party-death rules for the main character, and the timer length are tuning values to settle during the slice.
