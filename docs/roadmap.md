# Roadmap

## Milestone 0: Foundation
Project setup, pinned Godot version, folder layout, input map, CI running tests and exports, and the design document in `docs/`.

**Complete.** The first Godot CI run on `main` passed the tests, launched the Linux build headlessly, and uploaded both Windows and Linux releases. [CI run](https://github.com/ChrisTitusTech/dungeon-crawler/actions/runs/44966164763)

## Milestone 1: Core prototype
One hand-built isometric dungeon with turn-stepped movement, field of view, a minimap, and visible enemies that patrol and pursue the party. Contact opens a separate turn-based battle with Attack, Defend, Item, and Flee. Prototype art includes joined stone walls and original party and enemy sprites.

**Complete.** A rendered playthrough cleared all four encounters and verified keyboard, gamepad, and mouse movement. All 11 GUT tests passed, and local Windows and Linux release exports succeeded.

## Milestone 2: Vertical slice (floor 1)
**Complete.** Floor 1 has a 118×84 seeded layout with variable room placement, corridor loops, and encounter counts. A door leads to a separate walkable safe room with beds, a dining table, and a save chest. The floor has a 30-minute collapse countdown, one recruit, levelling and stat allocation, gear, persistent injuries, versioned checkpoints, and achievements with loot boxes and announcer lines.

A rendered playthrough used the safe-room doors, beds, dining table, and chest, then defeated the Floor 1 boss and reopened the cleared save. The 30 to 60 minute session target includes time spent in the refuge and menus.

## Milestone 3: Systems and demo (floors 1 to 3)
**In progress.** The demo has faction reputation, contested outposts, patrol skirmishes, a Watch scouting job, refuge crafting, and two guild contracts. The first art and audio pass adds continuous held movement, a side-view battle formation against a torchlit vault, combat effects, scene fades, original music and sound effects, and audio settings. Boss stairs connect all three floors. Rook chooses a race after Floor 2 and a class after Floor 3, and the party can rescue Cinder on Floor 2. Full gamepad support, broader accessibility options, distinct art and audio for Floors 2 and 3, and the public demo remain open. [PC handoff](handoff.md)

## Milestone 4: Early Access (floors 1 to 6)
**Planned.** Two full tiers of content, balance pass, save migration, tutorialisation, Steam integration (achievements, cloud saves), Steam Deck check, and launch.

## Milestone 5: Early Access updates (floors 7 to 15)
**Planned.** One tier per major update, each with new enemies, factions, guild contracts, and a system twist, guided by player feedback.

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
15. [x] `collapse-timer` counts down 30 minutes of exploration and combat and offers to reload the checkpoint after collapse.
16. [x] `show-layer` connects run events to achievements, loot boxes, and written announcer lines.
17. [x] `vertical-slice` delivers a playable Floor 1 with a verified boss clear and completed save reload.
18. [x] `factions` adds rival reputation, a Watch truce and scouting job, and outposts whose control reflects local patrols and skirmishes.
19. [x] `crafting` adds the refuge workbench with three recipes that use materials from enemies and supply caches.
20. [x] `guild-contracts` adds two refuge board contracts that unlock at two and five victories and pay one-time rewards.
21. [x] `floor-one-polish` smooths held movement and adds a dungeon backdrop and opposing battle formations.
22. [x] `race-class` adds seven ancestries, twelve base classes with individual skills, and a recruitable pet.
23. [ ] `demo-release` for Floors 2 and 3, their art and audio, the demo, and the Steam page.

## Risks and open questions

- **Scope is the main risk.** 18 floors with simulation systems is a multi-year project for a small team. The milestones are ordered so that each one is shippable and the game can be judged after Milestone 2.
- **Production art and audio** remain open. The demo now uses articulated 2D characters, distinct boss silhouettes, and an illustrated arena. Dedicated arena art and audio for each floor remain open.
- **Title, setting, and tone bible** are still needed, including the System AI's voice. Humour depends on the writing, so writing needs budgeted time.
- **Battle pacing:** separate battle screens can make frequent fights tedious. Visible enemies, fleeing, and fast animations mitigate this; the vertical slice must test it.
- **Simulation versus readability:** factions and injuries must produce outcomes the player can see and understand, or they are wasted work.
- **Exact floors for race and class choice**, the party-death rules for the main character, and the timer length are tuning values to settle during the slice.
