# Game Design

Working title: TBD. All names, characters, and setting are original IP; Dungeon Crawler Carl, Caves of Qud, and Dwarf Fortress are tonal and mechanical references only.

## Overview

Build a commercial single-player 2D party RPG in Godot (GDScript) for Windows and Linux. The party must survive an 18-floor dungeon run by a snarky System AI. The isometric exploration view shows enemies on the grid, and touching one opens a separate JRPG-style menu battle. A light Dwarf Fortress-style simulation (factions, crafting, body-part injuries) runs underneath.

Approach: prove the core loop in a one-floor vertical slice, widen to a three-floor demo, ship to Steam Early Access, then add floors and systems until all 18 floors are done for 1.0.

## Prototype status

Milestones 0 and 1 are complete. Rook and Mira can explore a hand-built dungeon with fog of war and a minimap, then fight four encounters using Attack, Defend, Item, and Flee. HP and tonics carry between fights. A party wipe restarts the test map.

Milestone 2 is complete. Rook and Mira can recruit Sable, return through a dungeon door to a separate safe room, and use the stairs after defeating Sir Aldren, the Hollow Castellan. Beds heal and treat wounds, meals restore some HP, and the chest saves progress and opens loot boxes. A new floor starts with a 30-minute collapse countdown. The broader pacing target includes time spent in safe rooms and menus. [Roadmap](roadmap.md)

## Key decisions

| Area | Decision |
| --- | --- |
| View | 2D isometric projection of a square tile grid |
| Combat | Turn-based menu battles on a separate battle screen |
| Encounters | Enemies visible on the map; contact starts the battle |
| Party | Up to 4: a created main character plus recruits and pets found in the dungeon |
| Class and race | Chosen on later floors, not at character creation |
| Dungeons | Hybrid: hand-crafted safe rooms, bosses, and story beats; procedural everything else |
| Structure | 18 floors, persistent campaign |
| Death | Party-member death is permanent; a full wipe reloads the last safe room |
| Dungeon systems | System AI announcer, floor collapse timers, loot boxes, achievements, guild contracts, safe rooms |
| Simulation | Factions, crafting, injuries. No digging or destructible terrain |
| Art | Isometric stonework, articulated 2D actors, and illustrated battle backgrounds |
| UI | Minimap; keyboard and mouse plus gamepad |
| Platforms | Windows and Linux, single-player |
| Engine | Latest stable Godot 4.x at project start, GDScript |
| Release | One-floor vertical slice first, then Steam Early Access, then 1.0 |

## Core loop

1. Enter a floor from a safe room.
2. Explore, fight, loot, and deal with factions while the floor's collapse timer runs.
3. Earn loot boxes through achievements and unlock guild contracts through victories.
4. Return to safe rooms to save, heal, open boxes, craft, and manage the party.
5. Beat the floor boss or find the stairs before the floor collapses.
6. Descend; repeat with new systems unlocking on set floors.

## Exploration

- Tile-based movement on a grid. Enemies on the map advance when the party acts. The collapse countdown runs in real time during exploration and combat.
- Field of view and fog of war; explored tiles stay on the minimap.
- Visible enemies patrol, chase, flee, or fight each other according to faction relations.
- Interactables: doors, chests, traps, crafting stations, NPCs, stairs.
- Approaching an enemy from behind or unseen grants an opening advantage in battle; being ambushed gives the enemy one.
- Name beasts by a distinctive trait and recognizable creature type, as in Ashfang Dire Rat. Name humanoid enemies by their posting or allegiance and role, as in Barrow Sentinel. Give bosses a personal name and medieval rank, with an epithet for introductions and lore. Floor 1 introduces Sir Aldren as the Hollow Castellan.

## Battle

- Side-view battles place party sprites on the right and opponents on the left, with a dungeon backdrop and individual health readouts. Floor 1 encounters have one enemy. Later encounters can use groups of up to roughly six enemies.
- Turn order by a speed stat, shown as a visible timeline.
- Commands: Attack, Skill, Item, Defend, Swap/Flee. Attacks and skills can target a body part.
- Resources: HP, a skill resource (mana or stamina by class), and status effects.
- Outcomes: victory (XP and drops), flee (return to the map with the enemy still there), or wipe (reload the last safe room).

## Party and progression

- The main character starts as an unclassed human with basic stats.
- Rook chooses a race at the end of Floor 2. Lantern Elves see farther, Flint Orcs gain health and attack, Hearth Halflings gain health and speed, and Cinder Drakekin scales absorb damage alongside worn armor. Human and Stonekin remain available. A Barrow Watch truce unlocks Gloamkin.
- Rook chooses a class at the end of Floor 3. The class roster follows the twelve base classes in the 2024 D&D rules. Every race can choose any class. Each class has a signature skill adapted to this game's turn order, health, and injury rules. The choice is saved with the completed demo. [D&D Free Rules: Character Classes](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes)
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
- **Guild contracts.** Victories unlock offers at the refuge contract board. Each accepted contract pays a one-time reward when the party wins a battle under its terms.
- **Broadcast terminals.** Each floor has a one-time offer for supplies. Accepting it charges 60, 90, or 120 seconds depending on the floor. An offer is disabled if the charge would empty the clock.
- **Collapse timer.** Each floor starts with 30 minutes. The timer pauses in the safe room and campaign menus. Warnings trigger at five minutes, two minutes, and 30 seconds. At zero, the party can reload its last checkpoint with the saved time remaining.
- **Safe rooms:** hand-crafted hubs with save point, bed, shop, crafting stations, box opening, and roster management.

## Factions

- On Floor 1, the Ashfang Brood and Barrow Watch are rivals. Hunting Ashfang beasts improves Watch standing, and the Watch envoy accepts bandages. Sentinels yield the way and patrol peacefully once a truce is earned. Sir Aldren guards the stairs independently of the truce.
- The Watch envoy offers a job to scout the Latchknife Outpost on Floor 1. Returning with the report grants a bronze box and increases Watch standing.
- Outpost banners report which patrols hold or contest local territory. Adjacent rival patrols can skirmish in sight of the party. Survivors carry their wounds into later encounters.
- Each floor hosts two to four factions (monster tribes, adventuring companies, dungeon wardens) with a relation matrix toward each other and the party.
- Reputation changes through kills, quests, gifts, and betrayals. It controls hostility, shop access, recruits, and some quest lines.
- Factions act on the map: they hold territory, patrol, and fight rivals, so the floor changes while the player explores.

## Crafting and items

- Recipes combine monster parts, scavenged materials, and loot at themed stations (workbench, alchemy, kitchen).
- Outputs: consumables, gear upgrades, injury treatments, traps, and explosives.
- Gear has slots, rarity tiers, and a small number of affixes. Recipes are learned from boxes, NPCs, and experimentation.

## World structure

- 18 floors grouped into themed tiers of three, each tier adding new tilesets, enemies, factions, and one new system or twist.
- The opening vault has Latchknife Goblins salvaging the rooms between Ashfang and Watch patrols. Snareweaver Spiders hunt from farther away in the Silkspire Galleries, where Amber Slimes absorb damage and Prize Mimics pose as supply chests. The armored Tithe Ossuary inhabits the keep on Floor 3, where Gutter Gargoyles stand guard.
- Per floor: procedural layout stitched around hand-crafted rooms (safe rooms, boss arena, story rooms). A seed per floor is stored in the save, so a reload restores the same floor.
- Early Access ships the first tiers; later tiers arrive in updates.

## Save system

- Automatic save on entering a safe room, plus manual save inside one. No saving in the field.
- A wipe reloads the last safe-room save. Multiple save slots per campaign.
- Saves are versioned so Early Access updates can migrate old saves.
