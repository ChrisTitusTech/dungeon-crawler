class_name CampaignRun
extends RefCounted

signal event_occurred(event: String)

const CONTENT: CampaignContent = preload("res://data/floor_one_content.tres")
const REFUGE_LAYOUT: DungeonLayout = preload("res://data/safe_room.tres")
const TURN_BUDGET := 720
const PARTY_LIMIT := 4
const BOSS_ID := "warden"
const ENEMY_IDS := ["rat", "guard", BOSS_ID]
const WARNINGS := {100: "warning", 40: "urgent", 10: "critical"}

var seed: int
var floor: DungeonFloor
var refuge: DungeonFloor
var refuge_door: Vector2i
var party: Array[BattleRules.Fighter] = []
var inventory: Dictionary[String, int] = {}
var used_sites: Dictionary[Vector2i, bool] = {}
var fallen_gear: Dictionary[Vector2i, Array] = {}
var achievements := PackedStringArray()
var announcement: String:
	get:
		return CONTENT.show[_announcement_event].line
var turns_left: int = TURN_BUDGET
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


func pass_turn() -> void:
	if at_camp():
		return
	turns_left -= 1
	if WARNINGS.has(turns_left):
		event_occurred.emit(WARNINGS[turns_left])


func count(item: String) -> int:
	return inventory.get(item, 0)


func add_item(item: String, quantity: int = 1) -> void:
	inventory[item] = count(item) + quantity


func spend_item(item: String) -> void:
	if count(item) > 1:
		inventory[item] -= 1
	else:
		inventory.erase(item)


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


func settle_battle(enemy: DungeonFloor.Enemy, outcome: BattleRules.Outcome, potions: int) -> void:
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
	victories += 1
	if victories == 1:
		event_occurred.emit("first_blood")
	elif victories == 3:
		event_occurred.emit("three_wins")
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
		"seed": seed, "player": floor.player, "turn": floor.turn, "turns_left": turns_left,
		"layout_version": _layout_version, "in_refuge": _in_refuge, "refuge_player": refuge.player,
		"enemies": enemies, "explored": floor.explored.keys(), "party": members,
		"inventory": inventory.duplicate(), "used_sites": used_sites.duplicate(),
		"fallen_gear": fallen_gear.duplicate(true), "achievements": achievements.duplicate(),
		"announcement": announcement, "announcement_event": _announcement_event, "victories": victories,
		"boss_defeated": boss_defeated, "completed": completed,
	}


static func restore(data: Dictionary) -> CampaignRun:
	var fields := {
		"seed": TYPE_INT, "player": TYPE_VECTOR2I, "turn": TYPE_INT, "turns_left": TYPE_INT,
		"enemies": TYPE_DICTIONARY, "explored": TYPE_ARRAY, "party": TYPE_ARRAY,
		"inventory": TYPE_DICTIONARY, "used_sites": TYPE_DICTIONARY, "fallen_gear": TYPE_DICTIONARY,
		"achievements": TYPE_PACKED_STRING_ARRAY, "announcement": TYPE_STRING,
		"victories": TYPE_INT, "boss_defeated": TYPE_BOOL, "completed": TYPE_BOOL,
	}
	if not _matches(data, fields) or data.party.is_empty() or data.party.size() > PARTY_LIMIT:
		return null

	var layout_version: Variant = data.get("layout_version", 1)
	if not layout_version is int or layout_version not in [1, FloorOneGenerator.VERSION]:
		return null
	var run := CampaignRun.new(data.seed, layout_version)
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
	if data.turn < 0 or data.turns_left <= 0 or data.turns_left > TURN_BUDGET:
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
	run.turns_left = data.turns_left
	run.victories = data.victories
	run.boss_defeated = data.boss_defeated
	run.completed = data.completed
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


func _on_show_event(event: String) -> void:
	var definition: Dictionary = CONTENT.show.get(event, {})
	if definition.has("line"):
		_announcement_event = event
	if definition.has("achievement") and not achievements.has(definition.achievement):
		achievements.append(definition.achievement)
		if definition.has("box"):
			add_item(definition.box)
