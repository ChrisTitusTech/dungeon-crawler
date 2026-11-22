# Roadmap

## Milestone 0: Foundation
Project setup, pinned Godot version, folder layout, input map, CI running tests and exports, and the design document in `docs/`.

**Complete.** The first Godot CI run on `main` passed the tests, launched the Linux build headlessly, and uploaded both Windows and Linux releases. [CI run](https://github.com/ChrisTitusTech/dungeon-crawler/actions/runs/44966164763)

## Milestone 1: Core prototype
One hand-built isometric dungeon with turn-stepped movement, field of view, a minimap, and visible enemies that patrol and pursue the party. Contact opens a separate turn-based battle with Attack, Defend, Item, and Flee. Prototype art includes joined stone walls and original party and enemy sprites.

**Complete.** A rendered playthrough cleared all four encounters and verified keyboard, gamepad, and mouse movement. All 11 GUT tests passed, and local Windows and Linux release exports succeeded.

## Milestone 2: Vertical slice (floor 1)
**Next.** Build one complete floor with procedural generation around a hand-crafted safe room and boss, a collapse timer, a party of up to four with one recruit, levelling, inventory and gear, injuries, saving and wipe reload, achievements with loot boxes, and the first announcer lines. Aim for a 30 to 60 minute playthrough to test the full loop.

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
9. [ ] `data-pipeline` for data-driven items, monsters, and skills.
10. [ ] `party-progression` for a party of four, stats, levelling, and recruits.
11. [ ] `inventory-gear` for inventory, equipment, and loot drops.
12. [ ] `injury-system` for body parts and persistent injuries.
13. [ ] `floor-generation` for seeded hybrid floors.
14. [ ] `safe-room-save` for safe rooms, save and load, and wipe reload.
15. [ ] `collapse-timer` for the floor turn budget and collapse.
16. [ ] `show-layer` for the event bus, achievements, loot boxes, and announcer.
17. [ ] `vertical-slice` for Floor 1 content, the boss, and the playtest.
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
