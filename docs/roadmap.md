# Roadmap

## Milestone 0: Foundation
Project setup, pinned Godot version, folder layout, input map, CI running tests and exports, and the design document in `docs/`.

**Complete.** The first Godot CI run on `main` passed the tests, launched the Linux build headlessly, and uploaded both Windows and Linux releases. [CI run](https://github.com/ChrisTitusTech/dungeon-crawler/actions/runs/44966164763)

## Milestone 1: Core prototype
One hand-built isometric dungeon with turn-stepped movement, field of view, a minimap, and visible enemies that patrol and pursue the party. Contact opens a separate turn-based battle with Attack, Defend, Item, and Flee. Prototype art includes joined stone walls and original party and enemy sprites.

**Complete.** A rendered playthrough cleared all four encounters and verified keyboard, gamepad, and mouse movement. All 11 GUT tests passed, and local Windows and Linux release exports succeeded.

## Milestone 2: Vertical slice (floor 1)
**Playable.** Floor 1 has a seeded layout, a hand-built safe room and boss chamber, a 420-turn collapse clock, one recruit, levelling and stat allocation, gear, persistent injuries, versioned checkpoints, and achievements with loot boxes and announcer lines.

A rendered playthrough recruited Sable, opened both box tiers, defeated the Floor 1 boss, descended, and reopened the cleared save. Verify the 30 to 60 minute pacing target in a human playtest before closing this milestone.

## Milestone 3: Systems and demo (floors 1 to 3)
**Planned.** Factions and reputation, crafting, viewers and sponsors, race and class selection, pets, full gamepad support, production art and audio pass, settings and accessibility options. Ends in a public demo and Steam page.

## Milestone 4: Early Access (floors 1 to 6)
**Planned.** Two full tiers of content, balance pass, save migration, tutorialisation, Steam integration (achievements, cloud saves), Steam Deck check, and launch.

## Milestone 5: Early Access updates (floors 7 to 15)
**Planned.** One tier per major update, each with new enemies, factions, sponsors, and a system twist, guided by player feedback.

## Milestone 6: 1.0 (floors 16 to 18)
**Planned.** Final tier, ending, full balance and polish pass, localisation readiness, and release.

## Backlog

Work items in order through the demo.

1. [x] `project-setup` establishes the Godot project, folder layout, input map, and Git rules.
2. [x] `ci-pipeline` runs the GUT tests and publishes both release builds as workflow artifacts.
3. [x] `design-docs` records the game design, technical design, and roadmap in `docs/`.
4. [x] `grid-exploration` adds turn-stepped movement, a following camera, and the test map.
5. [x] `fov-minimap` adds field of view, fog of war, and a minimap.
6. [x] `map-enemies` adds visible enemies that patrol, pursue the party, and start battles on contact.
7. [x] `battle-core` adds a tested turn-based rules engine.
8. [x] `battle-ui` adds a separate battle scene, command menu, and turn order.
9. [x] `data-pipeline` defines Floor 1 items, monsters, skills, rewards, and announcer lines in a Godot resource.
10. [x] `party-progression` adds a four-member capacity, one recruit, XP, levels, and spendable stat points.
11. [x] `inventory-gear` adds the pack, weapon and armor slots, supply caches, and loot drops.
12. [x] `injury-system` adds persistent body-part wounds, combat penalties, bandages, and camp treatment.
13. [x] `floor-generation` builds connected seeded layouts around authored safe and boss rooms.
14. [x] `safe-room-save` adds three versioned slots, manual and entry saves, and checkpoint reload after a wipe.
15. [x] `collapse-timer` tracks turns outside camp and reloads the checkpoint after collapse.
16. [x] `show-layer` connects run events to achievements, loot boxes, and written announcer lines.
17. [ ] `vertical-slice` has playable Floor 1 content and a verified boss clear. Human pacing playtest remains open.
18. [ ] `factions` for faction behaviour and reputation.
19. [ ] `crafting` for recipes and stations.
20. [ ] `viewers-sponsors` for viewer count and sponsors.
21. [ ] `race-class` for race and class selection and pets.
22. [ ] `demo-release` for Floors 2 and 3, the art and audio pass, the demo, and the Steam page.

## Risks and open questions

- **Scope is the main risk.** 18 floors with simulation systems is a multi-year project for a small team. The milestones are ordered so that each one is shippable and the game can be judged after Milestone 2.
- **Production art and audio** remain open. The prototype uses an adapted stone atlas and original character sprites. [Texture credits](../assets/tactics_stone.LICENSE.txt)
- **Title, setting, and tone bible** are still needed, including the System AI's voice. Humour depends on the writing, so writing needs budgeted time.
- **Battle pacing:** separate battle screens can make frequent fights tedious. Visible enemies, fleeing, and fast animations mitigate this; the vertical slice must test it.
- **Simulation versus readability:** factions and injuries must produce outcomes the player can see and understand, or they are wasted work.
- **Exact floors for race and class choice**, the party-death rules for the main character, and the timer length are tuning values to settle during the slice.
