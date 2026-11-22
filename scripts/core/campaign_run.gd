class_name CampaignRun
extends RefCounted

signal event_occurred(event: String)

const CONTENT: CampaignContent = preload("res://data/floor_one_content.tres")
const REFUGE_LAYOUT: DungeonLayout = preload("res://data/safe_room.tres")
const FLOOR_TIME_SECONDS := 30 * 60
const PARTY_LIMIT := 4
const PET_ID := "cinder"
const BOSS_ID := "warden"
const ENEMY_IDS := ["rat", "guard", BOSS_ID, "goblin", "slime", "spider", "skeleton", "mimic", "gargoyle"]
const FLOOR_BOSSES := [BOSS_ID, "marshal", "regent"]
const LAST_FLOOR := 3
const LATER_LAYOUTS: Dictionary[int, DungeonLayout] = {
	2: preload("res://data/floor_2_layout.tres"),
	3: preload("res://data/floor_3_layout.tres"),
}
const WARNINGS := {30: "critical", 120: "urgent", 300: "warning"}

var seed: int
var floor_number: int
var floor: DungeonFloor
var refuge: DungeonFloor
var refuge_door: Vector2i
var party: Array[BattleRules.Fighter] = []
var inventory: Dictionary[String, int] = {}
var reputation: Dictionary[String, int] = {}
var sponsor_contracts: Dictionary[String, String] = {}
var used_sites: Dictionary[Vector2i, bool] = {}
var fallen_gear: Dictionary[Vector2i, Array] = {}
var achievements := PackedStringArray()
var announcement: String:
	get:
		return CONTENT.show[_announcement_event].line
var seconds_left: float = FLOOR_TIME_SECONDS
var victories: int = 0
var boss_defeated: bool = false
var completed: bool = false
var race_id: String
var class_id: String
var _announcement_event: String = "intro"
var _in_refuge: bool = false


func _init(floor_seed: int, starting_floor: int = 1) -> void:
	seed = floor_seed
	floor_number = starting_floor
	party = [CONTENT.make_fighter("rook"), CONTENT.make_fighter("mira")]
	inventory = {"tonic": 4, "bandage": 2}
	for faction: String in CONTENT.factions:
		reputation[faction] = CONTENT.factions[faction].initial
	event_occurred.connect(_on_show_event)
	_load_floor()


func _load_floor() -> void:
	var layout: DungeonLayout
	if floor_number == 1:
		layout = FloorOneGenerator.new().generate(seed)
	else:
		layout = LATER_LAYOUTS[floor_number]
	var vision: int = DungeonFloor.SIGHT_RADIUS + CONTENT.races.get(race_id, {}).get("sight", 0)
	floor = DungeonFloor.new(layout.rows, layout.safe_room, vision)
	refuge_door = layout.refuge_door
	refuge = DungeonFloor.new(REFUGE_LAYOUT.rows)
	_update_hostility()
	event_occurred.emit("intro" if floor_number == 1 else "intro_%d" % floor_number)


func at_camp() -> bool:
	return _in_refuge


func active_floor() -> DungeonFloor:
	return refuge if _in_refuge else floor


func enter_refuge() -> bool:
	var distance: Vector2i = (floor.player - refuge_door).abs()
	if _in_refuge or floor.encounter != null or distance.x + distance.y > 1:
		return false
	_in_refuge = true
	return true


func leave_refuge() -> void:
	_in_refuge = false


func boss_name() -> String:
	return CONTENT.foes[enemy_id(DungeonFloor.EnemyKind.BOSS)].name


func enemy_id(kind: DungeonFloor.EnemyKind) -> String:
	return FLOOR_BOSSES[floor_number - 1] if kind == DungeonFloor.EnemyKind.BOSS else ENEMY_IDS[kind]


func elapse_floor_time(seconds: float) -> void:
	if at_camp() or completed or seconds_left <= 0.0:
		return
	var previous: float = seconds_left
	seconds_left = maxf(0.0, previous - seconds)
	for threshold: int in WARNINGS:
		if previous > threshold and seconds_left <= threshold:
			event_occurred.emit(WARNINGS[threshold])
			break


func floor_time_text() -> String:
	var display_seconds: int = ceili(seconds_left)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [display_seconds / 60, display_seconds % 60]


func count(item: String) -> int:
	return inventory.get(item, 0)


func add_item(item: String, quantity: int = 1) -> void:
	inventory[item] = count(item) + quantity


func spend_item(item: String, quantity: int = 1) -> void:
	if count(item) > quantity:
		inventory[item] -= quantity
	else:
		inventory.erase(item)


func has_truce(faction: String) -> bool:
	var definition: Dictionary = CONTENT.factions[faction]
	return definition.has("truce") and reputation[faction] >= definition.truce


func offer_faction_gift(faction: String) -> bool:
	var definition: Dictionary = CONTENT.factions.get(faction, {})
	if not at_camp() or not definition.has("gift") or has_truce(faction):
		return false
	if count(definition.gift) < definition.gift_cost:
		return false
	spend_item(definition.gift, definition.gift_cost)
	_shift_reputation(faction, definition.gift_standing)
	_update_hostility()
	return true


func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = CONTENT.recipes.get(recipe_id, {})
	if not at_camp() or recipe.is_empty():
		return false
	for item: String in recipe.ingredients:
		if count(item) < recipe.ingredients[item]:
			return false
	return true


func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = CONTENT.recipes[recipe_id]
	for item: String in recipe.ingredients:
		spend_item(item, recipe.ingredients[item])
	add_item(recipe.item, recipe.count)
	return true


func can_accept_sponsor(sponsor: String) -> bool:
	var definition: Dictionary = CONTENT.sponsors.get(sponsor, {})
	return at_camp() and not definition.is_empty() and victories >= definition.victories and not sponsor_contracts.has(sponsor)


func accept_sponsor(sponsor: String) -> bool:
	if not can_accept_sponsor(sponsor):
		return false
	sponsor_contracts[sponsor] = "active"
	return true


func rest() -> void:
	if not at_camp():
		return
	for member: BattleRules.Fighter in party:
		if member.hp > 0:
			member.hp = member.max_hp
			member.injuries.clear()


func eat() -> void:
	if not at_camp():
		return
	for member: BattleRules.Fighter in party:
		if member.hp > 0:
			member.hp = mini(member.max_hp, member.hp + ceili(member.max_hp * 0.5))


func equip(member: BattleRules.Fighter, item: String) -> bool:
	var definition: Dictionary = CONTENT.items.get(item, {})
	if member.hp == 0 or member.is_pet or count(item) == 0 or not definition.has("slot"):
		return false
	spend_item(item)
	if definition.slot == "weapon":
		if not member.weapon.is_empty():
			add_item(member.weapon)
		member.weapon = item
		member.weapon_bonus = definition.bonus
	else:
		if not member.armor.is_empty():
			add_item(member.armor)
		member.armor = item
		member.armor_bonus = definition.bonus
	return true


func heal(member: BattleRules.Fighter, item: String) -> bool:
	if member.hp == 0 or count(item) == 0:
		return false
	if item == "bandage" and not member.injuries.is_empty():
		member.injuries.erase(member.injuries.keys()[0])
	elif item == "tonic" and member.hp < member.max_hp:
		member.hp = mini(member.hp + BattleRules.POTION_HEAL, member.max_hp)
	else:
		return false
	spend_item(item)
	return true


func open_box(item: String) -> bool:
	var definition: Dictionary = CONTENT.items.get(item, {})
	if not at_camp() or count(item) == 0 or not definition.has("loot"):
		return false
	spend_item(item)
	for reward: String in definition.loot:
		add_item(reward)
	return true


func collect_cache(cell: Vector2i) -> void:
	if used_sites.has(cell) or floor.terrain_at(cell) != "c":
		return
	used_sites[cell] = true
	add_item("tonic", 2)
	add_item("bandage")
	add_item("bitterroot")
	if posmod(cell.x, 3) == 0:
		add_item("hide_coat")


func broadcast_offer(cell: Vector2i) -> Dictionary:
	var distance: Vector2i = (floor.player - cell).abs()
	if at_camp() or completed or floor.encounter != null or distance.x + distance.y > 1:
		return {}
	if floor.terrain_at(cell) != "!" or used_sites.has(cell):
		return {}
	return CONTENT.broadcasts[floor_number]


func accept_broadcast(cell: Vector2i) -> bool:
	var offer: Dictionary = broadcast_offer(cell)
	if offer.is_empty() or seconds_left <= offer.seconds:
		return false
	used_sites[cell] = true
	elapse_floor_time(offer.seconds)
	for item: String in offer.reward:
		add_item(item, offer.reward[item])
	return true


func recruit(cell: Vector2i) -> bool:
	if party.size() >= PARTY_LIMIT or used_sites.has(cell) or floor.terrain_at(cell) != "R":
		return false
	party.append(CONTENT.make_fighter("sable"))
	used_sites[cell] = true
	event_occurred.emit("recruit")
	return true


func rescue_pet(cell: Vector2i) -> bool:
	var distance: Vector2i = (floor.player - cell).abs()
	if at_camp() or floor.encounter != null or distance.x + distance.y > 1:
		return false
	if floor.terrain_at(cell) != "P" or used_sites.has(cell) or party.size() >= PARTY_LIMIT or count("bandage") == 0:
		return false
	spend_item("bandage")
	party.append(CONTENT.make_fighter(PET_ID))
	used_sites[cell] = true
	event_occurred.emit("rescue_pet")
	return true


func loot_gear(cell: Vector2i) -> void:
	for item: String in fallen_gear.get(cell, []):
		add_item(item)
	fallen_gear.erase(cell)


func settle_battle(enemy: DungeonFloor.Enemy, outcome: BattleRules.Outcome, potions: int, used_skill: bool = false) -> void:
	var used_tonic: bool = count("tonic") > potions
	inventory.erase("tonic")
	if potions > 0:
		add_item("tonic", potions)
	var dropped: Array = fallen_gear.get(enemy.cell, [])
	for member: BattleRules.Fighter in party:
		if member.hp == 0:
			for item: String in [member.weapon, member.armor]:
				if not item.is_empty():
					dropped.append(item)
			member.weapon = ""
			member.armor = ""
			member.weapon_bonus = 0
			member.armor_bonus = 0
	if not dropped.is_empty():
		fallen_gear[enemy.cell] = dropped
	if outcome != BattleRules.Outcome.WON:
		return

	var foe_id: String = enemy_id(enemy.kind)
	var reward: Dictionary = CONTENT.foes[foe_id]
	for member: BattleRules.Fighter in party:
		member.earn_experience(reward.xp)
	add_item(reward.drop)
	add_item(reward.material)
	_shift_reputation(reward.faction, -8)
	_shift_reputation(CONTENT.factions[reward.faction].rival, 4)
	_update_hostility()
	victories += 1
	if victories == 1:
		event_occurred.emit("first_blood")
	elif victories == 3:
		event_occurred.emit("three_wins")
	_fulfill_sponsors(used_tonic, used_skill)
	if enemy.kind == DungeonFloor.EnemyKind.BOSS:
		boss_defeated = true
		event_occurred.emit(foe_id)


func can_escape(exit_cell: Vector2i) -> bool:
	var distance: Vector2i = (floor.player - exit_cell).abs()
	if not boss_defeated or completed or at_camp() or floor.encounter != null or seconds_left <= 0.0:
		return false
	return distance.x + distance.y <= 1 and floor.terrain_at(exit_cell) == ">"


func advancement_choices() -> Dictionary:
	if floor_number == 2:
		return CONTENT.races
	if floor_number == 3:
		return CONTENT.classes
	return {}


func advancement_unlocked(choice: Dictionary) -> bool:
	match choice.get("requires", ""):
		"truce": return has_truce("watch")
		"": return true
	return false


func escape(exit_cell: Vector2i, choice_id: String = "") -> bool:
	if not can_escape(exit_cell):
		return false
	var choices: Dictionary = advancement_choices()
	if not choices.is_empty():
		if not choices.has(choice_id) or not advancement_unlocked(choices[choice_id]):
			return false
		var choice: Dictionary = choices[choice_id]
		var rook: BattleRules.Fighter = party[0]
		var health: int = choice.get("hp", 0)
		rook.max_hp += health
		if rook.hp > 0:
			rook.hp += health
		rook.power += choice.get("power", 0)
		rook.speed += choice.get("speed", 0)
		if floor_number == 2:
			race_id = choice_id
			rook.natural_armor = choice.get("armor", 0)
		else:
			class_id = choice_id
			rook.skill = CONTENT.skills[choice.skill]
	event_occurred.emit("escape" if floor_number == 1 else "escape_%d" % floor_number)
	if floor_number == LAST_FLOOR:
		completed = true
	else:
		_advance_floor()
	return true


func _advance_floor() -> void:
	floor_number += 1
	boss_defeated = false
	seconds_left = FLOOR_TIME_SECONDS
	used_sites.clear()
	fallen_gear.clear()
	_in_refuge = true
	_load_floor()


func snapshot() -> Dictionary:
	var enemies := {}
	for enemy: DungeonFloor.Enemy in floor.enemies:
		enemies[enemy.home] = enemy.cell
	var members: Array[Dictionary] = []
	for member: BattleRules.Fighter in party:
		members.append({
			"id": member.id, "hp": member.hp, "max_hp": member.max_hp,
			"power": member.power, "speed": member.speed, "level": member.level, "xp": member.xp,
			"stat_points": member.stat_points,
			"weapon": member.weapon, "armor": member.armor, "injuries": member.injuries.duplicate(),
		})
	return {
		"seed": seed, "floor_number": floor_number, "player": floor.player,
		"turn": floor.turn, "seconds_left": seconds_left,
		"in_refuge": _in_refuge, "refuge_player": refuge.player,
		"enemies": enemies, "explored": floor.explored.keys(), "party": members,
		"inventory": inventory.duplicate(), "used_sites": used_sites.duplicate(),
		"reputation": reputation.duplicate(),
		"sponsor_contracts": sponsor_contracts.duplicate(),
		"fallen_gear": fallen_gear.duplicate(true), "achievements": achievements.duplicate(),
		"announcement_event": _announcement_event, "victories": victories,
		"boss_defeated": boss_defeated, "completed": completed,
		"race_id": race_id, "class_id": class_id,
	}


static func restore(data: Dictionary) -> CampaignRun:
	var fields := {
		"seed": TYPE_INT, "floor_number": TYPE_INT, "player": TYPE_VECTOR2I, "turn": TYPE_INT,
		"in_refuge": TYPE_BOOL, "refuge_player": TYPE_VECTOR2I,
		"enemies": TYPE_DICTIONARY, "explored": TYPE_ARRAY, "party": TYPE_ARRAY,
		"inventory": TYPE_DICTIONARY, "used_sites": TYPE_DICTIONARY, "fallen_gear": TYPE_DICTIONARY,
		"reputation": TYPE_DICTIONARY, "sponsor_contracts": TYPE_DICTIONARY,
		"achievements": TYPE_PACKED_STRING_ARRAY, "announcement_event": TYPE_STRING,
		"victories": TYPE_INT, "boss_defeated": TYPE_BOOL, "completed": TYPE_BOOL,
		"race_id": TYPE_STRING, "class_id": TYPE_STRING,
	}
	if not _matches(data, fields) or data.party.is_empty() or data.party.size() > PARTY_LIMIT:
		return null
	var saved_time: Variant = data.get("seconds_left")
	if not (saved_time is float or saved_time is int) or not is_finite(saved_time) or saved_time <= 0 or saved_time > FLOOR_TIME_SECONDS:
		return null
	if data.floor_number < 1 or data.floor_number > LAST_FLOOR or not CONTENT.show.has(data.announcement_event):
		return null
	if data.completed and (data.floor_number != LAST_FLOOR or not data.boss_defeated or data.in_refuge):
		return null
	var has_race: bool = CONTENT.races.has(data.race_id)
	var has_class: bool = CONTENT.classes.has(data.class_id)
	if (data.floor_number == 3 and not has_race) or (data.floor_number < 3 and data.race_id != ""):
		return null
	if (data.completed and not has_class) or (not data.completed and data.class_id != ""):
		return null
	var run := CampaignRun.new(data.seed, data.floor_number)
	run.race_id = data.race_id
	var race: Dictionary = CONTENT.races.get(run.race_id, {})
	run.floor.sight_radius += race.get("sight", 0)
	var saved_contracts: Dictionary = data.sponsor_contracts
	for sponsor: Variant in saved_contracts:
		if not CONTENT.sponsors.has(sponsor) or saved_contracts[sponsor] not in ["active", "fulfilled"]:
			return null
		run.sponsor_contracts[sponsor] = saved_contracts[sponsor]
	var standing: Dictionary = data.reputation
	for faction: Variant in standing:
		if not CONTENT.factions.has(faction) or not standing[faction] is int or absi(standing[faction]) > 100:
			return null
		run.reputation[faction] = standing[faction]
	if not run.floor.is_walkable(data.player) or not run.refuge.is_walkable(data.refuge_player):
		return null
	for cell: Variant in data.explored:
		if not cell is Vector2i or not Rect2i(Vector2i.ZERO, run.floor.size).has_point(cell):
			return null
	for cell: Variant in data.enemies.values():
		if not cell is Vector2i or not run.floor.is_walkable(cell) or run.floor.safe_room.has_point(cell):
			return null
	for item: Variant in data.inventory:
		if not CONTENT.items.has(item) or not data.inventory[item] is int or data.inventory[item] <= 0:
			return null
	if data.turn < 0:
		return null
	run.floor.restore_checkpoint(data.player, data.turn, data.enemies, data.explored)
	run.refuge.restore_checkpoint(data.refuge_player, 0, {}, [])
	run._in_refuge = data.in_refuge
	run.party.clear()
	var member_fields := {
		"id": TYPE_STRING, "hp": TYPE_INT, "max_hp": TYPE_INT, "power": TYPE_INT,
		"level": TYPE_INT, "xp": TYPE_INT, "speed": TYPE_INT, "stat_points": TYPE_INT,
		"weapon": TYPE_STRING, "armor": TYPE_STRING, "injuries": TYPE_DICTIONARY,
	}
	for saved: Variant in data.party:
		if not saved is Dictionary or not _matches(saved, member_fields) or not CONTENT.heroes.has(saved.id):
			return null
		if saved.hp < 0 or saved.hp > saved.max_hp or saved.max_hp <= 0 or saved.level <= 0 or saved.xp < 0:
			return null
		var member: BattleRules.Fighter = CONTENT.make_fighter(saved.id)
		member.hp = saved.hp
		member.max_hp = saved.max_hp
		member.power = saved.power
		member.speed = saved.speed
		member.level = saved.level
		member.xp = saved.xp
		member.stat_points = saved.stat_points
		member.weapon = saved.weapon
		member.armor = saved.armor
		member.weapon_bonus = CONTENT.items.get(member.weapon, {}).get("bonus", 0)
		member.armor_bonus = CONTENT.items.get(member.armor, {}).get("bonus", 0)
		member.injuries.assign(saved.injuries)
		run.party.append(member)
	if run.party[0].id != "rook":
		return null
	run.party[0].natural_armor = race.get("armor", 0)
	run.class_id = data.class_id
	if not run.class_id.is_empty():
		run.party[0].skill = CONTENT.skills[CONTENT.classes[run.class_id].skill]
	run.inventory.assign(data.inventory)
	run.used_sites.assign(data.used_sites)
	run.fallen_gear.assign(data.fallen_gear)
	run.achievements = data.achievements.duplicate()
	run._announcement_event = data.announcement_event
	run.seconds_left = saved_time
	run.victories = data.victories
	run.boss_defeated = data.boss_defeated
	run.completed = data.completed
	run._update_hostility()
	return run


static func _matches(data: Dictionary, fields: Dictionary) -> bool:
	for key: String in fields:
		if typeof(data.get(key)) != fields[key]:
			return false
	return true


func _shift_reputation(faction: String, amount: int) -> void:
	reputation[faction] = clampi(reputation[faction] + amount, -100, 100)


func _update_hostility() -> void:
	for enemy: DungeonFloor.Enemy in floor.enemies:
		var faction: String = CONTENT.foes[enemy_id(enemy.kind)].faction
		enemy.hostile = enemy.kind == DungeonFloor.EnemyKind.BOSS or not has_truce(faction)


func _fulfill_sponsors(used_tonic: bool, used_skill: bool) -> void:
	for sponsor: String in sponsor_contracts:
		if sponsor_contracts[sponsor] != "active":
			continue
		var definition: Dictionary = CONTENT.sponsors[sponsor]
		var condition_met: bool = (definition.condition == "no_tonic" and not used_tonic) or (definition.condition == "skill" and used_skill)
		if condition_met:
			sponsor_contracts[sponsor] = "fulfilled"
			for item: String in definition.gift:
				add_item(item, definition.gift[item])
			event_occurred.emit("sponsor_fulfilled")


func _on_show_event(event: String) -> void:
	var definition: Dictionary = CONTENT.show.get(event, {})
	if definition.has("line"):
		_announcement_event = event
	if definition.has("achievement") and not achievements.has(definition.achievement):
		achievements.append(definition.achievement)
		if definition.has("box"):
			add_item(definition.box)
