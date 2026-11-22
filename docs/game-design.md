# Game Design

Working title: TBD. All names, characters, and setting are original IP; Dungeon Crawler Carl, Caves of Qud, and Dwarf Fortress are tonal and mechanical references only.

## Overview

Build a commercial single-player 2D party RPG in Godot (GDScript) for Windows and Linux. The player is a contestant in a lethal, televised 18-floor dungeon run by a snarky System AI. Exploration is top-down and tile-based with visible enemies; touching one opens a separate JRPG-style menu battle. A light Dwarf Fortress-style simulation (factions, crafting, body-part injuries) runs underneath.

Approach: prove the core loop in a one-floor vertical slice, widen to a three-floor demo, ship to Steam Early Access, then add floors and systems until all 18 floors are done for 1.0.

## Key decisions

| Area | Decision |
| --- | --- |
| View | Top-down, tile/grid-based, in the style of Caves of Qud |
| Combat | Turn-based menu battles on a separate battle screen |
| Encounters | Enemies visible on the map; contact starts the battle |
| Party | Up to 4: a created main character plus recruits and pets found in the dungeon |
| Class and race | Chosen on later floors, not at character creation |
| Dungeons | Hybrid: hand-crafted safe rooms, bosses, and story beats; procedural everything else |
| Structure | 18 floors, persistent campaign |
| Death | Party-member death is permanent; a full wipe reloads the last safe room |
| Show framing | System AI announcer, floor collapse timers, loot boxes, achievements, viewers and sponsors, safe rooms |
| Simulation | Factions, crafting, injuries. No digging or destructible terrain |
| Art | 16x16 pixel sprites with a Qud-like limited palette |
| UI | Minimap; keyboard and mouse plus gamepad |
| Platforms | Windows and Linux, single-player |
| Engine | Latest stable Godot 4.x at project start, GDScript |
| Release | One-floor vertical slice first, then Steam Early Access, then 1.0 |

## Core loop

1. Enter a floor from a safe room.
2. Explore, fight, loot, and deal with factions while the floor's collapse timer runs.
3. Earn achievements, which award loot boxes; build viewer count, which attracts sponsors.
4. Return to safe rooms to save, heal, open boxes, craft, and manage the party.
5. Beat the floor boss or find the stairs before the floor collapses.
6. Descend; repeat with new systems unlocking on set floors.

## Exploration

- Tile-based movement on a grid. The world is turn-stepped: enemies and the collapse timer advance when the party acts, so the player can always stop and think.
- Field of view and fog of war; explored tiles stay on the minimap.
- Visible enemies patrol, chase, flee, or fight each other according to faction relations.
- Interactables: doors, chests, traps, crafting stations, NPCs, stairs.
- Approaching an enemy from behind or unseen grants an opening advantage in battle; being ambushed gives the enemy one.

## Battle

- Separate battle scene with the party on one side and up to roughly six enemies on the other.
- Turn order by a speed stat, shown as a visible timeline.
- Commands: Attack, Skill, Item, Defend, Swap/Flee. Attacks and skills can target a body part.
- Resources: HP, a skill resource (mana or stamina by class), and status effects.
- Outcomes: victory (XP, drops, viewer gain), flee (return to the map with the enemy still there), or wipe (reload the last safe room).

## Party and progression

- The main character starts as an unclassed human with basic stats.
- Race is chosen at the end of floor 2 and class at the end of floor 3 (tunable), from options shaped by how the player has played so far.
- Recruits and pets join through story beats, faction reputation, or rescue. The roster can exceed 4, with extras waiting in safe rooms.
- Levels grant stat points; skills level through use.
- Dead members are gone for good, with their gear dropped where they fell.

## Injuries

- Each combatant has body parts: head, torso, arms, legs (variants for non-humanoid monsters).
- Parts can be bruised, bleeding, broken, or lost, each with a concrete effect (for example a broken arm disables two-handed weapons).
- Injuries persist after battle and need items, crafting, or safe-room treatment. Severe ones leave permanent scars with small trade-offs.

## Show layer

- **System AI:** announcer text for achievements, deaths, floor events, and taunts. It is written content triggered by game events, not generated at runtime.
- **Achievements and loot boxes:** achievements grant boxes in tiers (bronze through to legendary); boxes open only in safe rooms.
- **Viewers and sponsors:** viewer count rises with risky, stylish, or funny play. Thresholds unlock sponsors, who send targeted gifts with strings attached.
- **Collapse timer:** each floor has a turn budget. Warnings escalate, and anything still on the floor at zero dies.
- **Safe rooms:** hand-crafted hubs with save point, bed, shop, crafting stations, box opening, and roster management.

## Factions

- Each floor hosts two to four factions (monster tribes, contestant groups, show staff) with a relation matrix toward each other and the party.
- Reputation changes through kills, quests, gifts, and betrayals. It controls hostility, shop access, recruits, and some quest lines.
- Factions act on the map: they hold territory, patrol, and fight rivals, so the floor changes while the player explores.

## Crafting and items

- Recipes combine monster parts, scavenged materials, and loot at themed stations (workbench, alchemy, kitchen).
- Outputs: consumables, gear upgrades, injury treatments, traps, and explosives.
- Gear has slots, rarity tiers, and a small number of affixes. Recipes are learned from boxes, NPCs, and experimentation.

## World structure

- 18 floors grouped into themed tiers of three, each tier adding new tilesets, enemies, factions, and one new system or twist.
- Per floor: procedural layout stitched around hand-crafted rooms (safe rooms, boss arena, story rooms). A seed per floor is stored in the save, so a reload restores the same floor.
- Early Access ships the first tiers; later tiers arrive in updates.

## Save system

- Automatic save on entering a safe room, plus manual save inside one. No saving in the field.
- A wipe reloads the last safe-room save. Multiple save slots per campaign.
- Saves are versioned so Early Access updates can migrate old saves.
