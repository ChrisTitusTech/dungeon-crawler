class_name CampaignRun
extends RefCounted

signal event_occurred(event: String)

const CONTENT: CampaignContent = preload("res://data/floor_one_content.tres")
const REFUGE_LAYOUT: DungeonLayout = preload("res://data/safe_room.tres")
const FLOOR_TIME_SECONDS := 30 * 60
const LEGACY_TURN_BUDGET := 720
const PARTY_LIMIT := 4
const BOSS_ID := "warden"
const ENEMY_IDS := ["rat", "guard", BOSS_ID]
const WARNINGS := {30: "critical", 120: "urgent", 300: "warning"}

var seed: int
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
var _announcement_event: String = "intro"
var _layout_version: int
var _in_refuge: bool = false


func _init(floor_seed: int, layout_version: int = FloorOneGenerator.VERSION) -> void:
	seed = floor_seed
	_layout_version = layout_version
	var layout: DungeonLayout = FloorOneGenerator.legacy(seed) if layout_version == 1 else FloorOneGenerator.new().generate(seed)
	floor = DungeonFloor.new(layout.rows, layout.safe_room)
	refuge_door = layout.refuge_door
	refuge = DungeonFloor.new(REFUGE_LAYOUT.rows)
	party = [CONTENT.make_fighter("rook"), CONTENT.make_fighter("mira")]
	inventory = {"tonic": 4, "bandage": 2}
	for faction: String in CONTENT.factions:
		reputation[faction] = CONTENT.factions[faction].initial
	_update_hostility()
	event_occurred.connect(_on_show_event)
	event_occurred.emit("intro")


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
	return CONTENT.foes[BOSS_ID].name


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
	if member.hp == 0 or count(item) == 0 or not definition.has("slot"):
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


func recruit(cell: Vector2i) -> bool:
	if party.size() >= PARTY_LIMIT or used_sites.has(cell) or floor.terrain_at(cell) != "R":
		return false
	party.append(CONTENT.make_fighter("sable"))
	used_sites[cell] = true
	event_occurred.emit("recruit")
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

	var reward: Dictionary = CONTENT.foes[ENEMY_IDS[enemy.kind]]
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
		event_occurred.emit("warden")


func escape(exit_cell: Vector2i) -> bool:
	var distance: Vector2i = (floor.player - exit_cell).abs()
	if not boss_defeated or completed or distance.x + distance.y > 1 or floor.terrain_at(exit_cell) != ">":
		return false
	completed = true
	event_occurred.emit("escape")
	return true


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
		"seed": seed, "player": floor.player, "turn": floor.turn, "seconds_left": seconds_left,
		"layout_version": _layout_version, "in_refuge": _in_refuge, "refuge_player": refuge.player,
		"enemies": enemies, "explored": floor.explored.keys(), "party": members,
		"inventory": inventory.duplicate(), "used_sites": used_sites.duplicate(),
		"reputation": reputation.duplicate(),
		"sponsor_contracts": sponsor_contracts.duplicate(),
		"fallen_gear": fallen_gear.duplicate(true), "achievements": achievements.duplicate(),
		"announcement": announcement, "announcement_event": _announcement_event, "victories": victories,
		"boss_defeated": boss_defeated, "completed": completed,
	}


static func restore(data: Dictionary) -> CampaignRun:
	var fields := {
		"seed": TYPE_INT, "player": TYPE_VECTOR2I, "turn": TYPE_INT,
		"enemies": TYPE_DICTIONARY, "explored": TYPE_ARRAY, "party": TYPE_ARRAY,
		"inventory": TYPE_DICTIONARY, "used_sites": TYPE_DICTIONARY, "fallen_gear": TYPE_DICTIONARY,
		"achievements": TYPE_PACKED_STRING_ARRAY, "announcement": TYPE_STRING,
		"victories": TYPE_INT, "boss_defeated": TYPE_BOOL, "completed": TYPE_BOOL,
	}
	if not _matches(data, fields) or data.party.is_empty() or data.party.size() > PARTY_LIMIT:
		return null
	var saved_time: Variant = data.get("seconds_left")
	if not data.has("seconds_left"):
		var legacy_turns: Variant = data.get("turns_left")
		if not legacy_turns is int or legacy_turns <= 0 or legacy_turns > LEGACY_TURN_BUDGET:
			return null
		# Old checkpoints had no elapsed time to restore.
		saved_time = FLOOR_TIME_SECONDS
	if not (saved_time is float or saved_time is int) or not is_finite(saved_time) or saved_time <= 0 or saved_time > FLOOR_TIME_SECONDS:
		return null

	var layout_version: Variant = data.get("layout_version", 1)
	if not layout_version is int or layout_version not in [1, FloorOneGenerator.VERSION]:
		return null
	var run := CampaignRun.new(data.seed, layout_version)
	var saved_contracts: Variant = data.get("sponsor_contracts", {})
	if not saved_contracts is Dictionary:
		return null
	for sponsor: Variant in saved_contracts:
		if not CONTENT.sponsors.has(sponsor) or saved_contracts[sponsor] not in ["active", "fulfilled"]:
			return null
		run.sponsor_contracts[sponsor] = saved_contracts[sponsor]
	var standing: Variant = data.get("reputation", {})
	if not standing is Dictionary:
		return null
	for faction: Variant in standing:
		if not CONTENT.factions.has(faction) or not standing[faction] is int or absi(standing[faction]) > 100:
			return null
		run.reputation[faction] = standing[faction]
	if not run.floor.is_walkable(data.player):
		return null
	var camp_state: Variant = data.get("in_refuge", layout_version == 1 and not data.completed)
	var camp_cell: Variant = data.get("refuge_player", run.refuge.player)
	if not camp_state is bool or not camp_cell is Vector2i or not run.refuge.is_walkable(camp_cell):
		return null
	var dungeon_cell: Vector2i = data.player
	if not data.has("in_refuge") and layout_version == 1 and not data.completed:
		if not run.floor.safe_room.has_point(dungeon_cell):
			return null
		dungeon_cell = run.refuge_door
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
	run.floor.restore_checkpoint(dungeon_cell, data.turn, data.enemies, data.explored)
	run.refuge.restore_checkpoint(camp_cell, 0, {}, [])
	run._in_refuge = camp_state
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
	run.inventory.assign(data.inventory)
	run.used_sites.assign(data.used_sites)
	run.fallen_gear.assign(data.fallen_gear)
	run.achievements = data.achievements.duplicate()
	run._announcement_event = _saved_announcement_event(data)
	if not data.has("seconds_left") and WARNINGS.values().has(run._announcement_event):
		run._announcement_event = "warden" if data.boss_defeated else "intro"
	run.seconds_left = saved_time
	run.victories = data.victories
	run.boss_defeated = data.boss_defeated
	run.completed = data.completed
	run._update_hostility()
	return run


static func _saved_announcement_event(data: Dictionary) -> String:
	var stored: Variant = data.get("announcement_event")
	if stored is String and CONTENT.show.has(stored):
		return stored
	# Older checkpoints stored the written line instead of an event key.
	for event: String in CONTENT.show:
		if CONTENT.show[event].line == data.announcement:
			return event
	if data.completed:
		return "escape"
	return "warden" if data.boss_defeated else "intro"


static func _matches(data: Dictionary, fields: Dictionary) -> bool:
	for key: String in fields:
		if typeof(data.get(key)) != fields[key]:
			return false
	return true


func _shift_reputation(faction: String, amount: int) -> void:
	reputation[faction] = clampi(reputation[faction] + amount, -100, 100)


func _update_hostility() -> void:
	for enemy: DungeonFloor.Enemy in floor.enemies:
		var faction: String = CONTENT.foes[ENEMY_IDS[enemy.kind]].faction
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
