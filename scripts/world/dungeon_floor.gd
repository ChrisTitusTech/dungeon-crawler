class_name DungeonFloor
extends RefCounted

enum EnemyKind { RAT, GUARD, BOSS, GOBLIN, SLIME, SPIDER, SKELETON, MIMIC, GARGOYLE }

class Enemy:
	var kind: EnemyKind
	var cell: Vector2i
	var home: Vector2i
	var patrol_end: Vector2i
	var hostile: bool = true
	var faction: String
	var rival: String
	var endurance: int = 2
	var skirmish_wounds: int

	func _init(enemy_kind: EnemyKind, spawn: Vector2i) -> void:
		kind = enemy_kind
		cell = spawn
		home = spawn
		patrol_end = spawn


const SIGHT_RADIUS := 7
const CHASE_RADIUS := 6
const SKIRMISH_RADIUS_SQUARED := 36
const STATIONARY := [EnemyKind.BOSS, EnemyKind.MIMIC, EnemyKind.GARGOYLE]
const OUTPOST_RADIUS_SQUARED := 25
const SPAWNS: Dictionary[String, EnemyKind] = {
	"r": EnemyKind.RAT, "g": EnemyKind.GUARD, "b": EnemyKind.BOSS,
	"k": EnemyKind.GOBLIN, "o": EnemyKind.SLIME, "s": EnemyKind.SPIDER,
	"u": EnemyKind.SKELETON, "m": EnemyKind.MIMIC, "v": EnemyKind.GARGOYLE,
}
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const FIXTURES := ["B", "F", "L", "G", "W", "A"]

var size: Vector2i
var player: Vector2i
var turn: int = 0
var safe_room: Rect2i
var sight_radius := SIGHT_RADIUS
var enemies: Array[Enemy] = []
var encounter: Enemy
var visible: Dictionary[Vector2i, bool] = {}
var explored: Dictionary[Vector2i, bool] = {}
var skirmish: Array[Enemy] = []

var _rows: PackedStringArray
var _reprieved_enemy: Enemy


func _init(rows: PackedStringArray, sanctuary: Rect2i = Rect2i(), vision: int = SIGHT_RADIUS) -> void:
	_rows = rows
	safe_room = sanctuary
	sight_radius = vision
	size = Vector2i(rows[0].length(), rows.size())
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			var glyph: String = rows[y][x]
			if glyph == "S":
				player = cell
			elif SPAWNS.has(glyph):
				enemies.append(Enemy.new(SPAWNS[glyph], cell))

	for enemy: Enemy in enemies:
		for direction: Vector2i in CARDINALS:
			var endpoint: Vector2i = enemy.home + direction
			if not safe_room.has_point(endpoint) and is_walkable(endpoint) and enemy_at(endpoint) == null:
				enemy.patrol_end = endpoint
				break
	_update_visibility()


func terrain_at(cell: Vector2i) -> String:
	return _rows[cell.y][cell.x] if Rect2i(Vector2i.ZERO, size).has_point(cell) else "#"


func is_walkable(cell: Vector2i) -> bool:
	var terrain: String = terrain_at(cell)
	return terrain != "#" and terrain != "t" and terrain not in FIXTURES


func is_wall(cell: Vector2i) -> bool:
	var terrain: String = terrain_at(cell)
	return terrain == "#" or terrain == "t"


func enemy_at(cell: Vector2i) -> Enemy:
	for enemy: Enemy in enemies:
		if enemy.cell == cell:
			return enemy
	return null


func take_turn(direction: Vector2i = Vector2i.ZERO) -> bool:
	if encounter != null or absi(direction.x) + absi(direction.y) > 1:
		return false

	var destination: Vector2i = player + direction
	if not is_walkable(destination):
		return false

	var occupant: Enemy = enemy_at(destination)
	if occupant != null and not occupant.hostile:
		occupant.cell = player
		occupant = null

	turn += 1
	skirmish.clear()
	encounter = occupant
	if encounter == null:
		player = destination
		var fighting: Dictionary[Enemy, bool] = _resolve_skirmishes()
		_advance_enemies(fighting)
		_update_visibility()
	_reprieved_enemy = null
	return true


func resolve_encounter(won: bool) -> void:
	if won:
		enemies.erase(encounter)
	else:
		_reprieved_enemy = encounter
	encounter = null


func restore_checkpoint(position: Vector2i, steps: int, positions: Dictionary, visited: Array) -> void:
	player = position
	turn = steps
	skirmish.clear()
	for index: int in range(enemies.size() - 1, -1, -1):
		var enemy: Enemy = enemies[index]
		if positions.has(enemy.home):
			enemy.cell = positions[enemy.home]
		else:
			enemies.remove_at(index)
	explored.clear()
	for cell: Vector2i in visited:
		explored[cell] = true
	_update_visibility()


func outpost_factions(post: Vector2i) -> PackedStringArray:
	var factions := PackedStringArray()
	for enemy: Enemy in enemies:
		if enemy.faction.is_empty() or enemy.kind in STATIONARY or factions.has(enemy.faction):
			continue
		if post.distance_squared_to(enemy.cell) <= OUTPOST_RADIUS_SQUARED and _has_line_of_sight(post, enemy.cell):
			factions.append(enemy.faction)
	return factions


func _resolve_skirmishes() -> Dictionary[Enemy, bool]:
	var fighting: Dictionary[Enemy, bool] = {}
	var defeated: Array[Enemy] = []
	for enemy: Enemy in enemies:
		if fighting.has(enemy) or not _can_skirmish(enemy):
			continue
		for direction: Vector2i in CARDINALS:
			var other: Enemy = enemy_at(enemy.cell + direction)
			if other == null or fighting.has(other) or not _can_skirmish(other) or not _are_rivals(enemy, other):
				continue
			fighting[enemy] = true
			fighting[other] = true
			if skirmish.is_empty():
				skirmish = [enemy, other]
			for fighter: Enemy in [enemy, other]:
				fighter.skirmish_wounds += 1
				if fighter.skirmish_wounds >= fighter.endurance:
					defeated.append(fighter)
			break
	for enemy: Enemy in defeated:
		enemies.erase(enemy)
	return fighting


func _can_skirmish(enemy: Enemy) -> bool:
	return (not enemy.faction.is_empty() and enemy.kind not in STATIONARY and enemy != _reprieved_enemy
		and player.distance_squared_to(enemy.cell) <= SKIRMISH_RADIUS_SQUARED
		and _has_line_of_sight(player, enemy.cell))


func _are_rivals(enemy: Enemy, other: Enemy) -> bool:
	return enemy.rival == other.faction or other.rival == enemy.faction


func _advance_enemies(fighting: Dictionary[Enemy, bool]) -> void:
	for enemy: Enemy in enemies:
		if enemy == _reprieved_enemy or enemy.kind in STATIONARY or fighting.has(enemy):
			continue

		var goal: Vector2i = enemy.patrol_end if enemy.cell == enemy.home else enemy.home
		var radius: int = 9 if enemy.kind == EnemyKind.SPIDER else CHASE_RADIUS
		if enemy.hostile and not safe_room.has_point(player) and enemy.cell.distance_squared_to(player) <= radius * radius:
			if _has_line_of_sight(enemy.cell, player):
				goal = player

		var next: Vector2i = _step_toward(enemy.cell, goal, enemy.hostile)
		if next == player:
			encounter = enemy
			return
		enemy.cell = next


func _step_toward(origin: Vector2i, goal: Vector2i, hostile: bool) -> Vector2i:
	var next: Vector2i = origin
	var best_distance: int = origin.distance_squared_to(goal)
	for direction: Vector2i in CARDINALS:
		var step: Vector2i = origin + direction
		if step == player and not hostile:
			continue
		var distance: int = step.distance_squared_to(goal)
		if distance < best_distance and not safe_room.has_point(step) and terrain_at(step) != "D" and is_walkable(step) and enemy_at(step) == null:
			next = step
			best_distance = distance
	return next


func _update_visibility() -> void:
	visible.clear()
	for y: int in range(maxi(0, player.y - sight_radius), mini(size.y, player.y + sight_radius + 1)):
		for x: int in range(maxi(0, player.x - sight_radius), mini(size.x, player.x + sight_radius + 1)):
			var cell := Vector2i(x, y)
			if player.distance_squared_to(cell) <= sight_radius * sight_radius:
				if _has_line_of_sight(player, cell):
					visible[cell] = true
					explored[cell] = true


func _has_line_of_sight(origin: Vector2i, target: Vector2i) -> bool:
	var cell: Vector2i = origin
	var span: Vector2i = (target - origin).abs()
	var step := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var error: int = span.x - span.y
	while cell != target:
		var previous: Vector2i = cell
		var doubled_error: int = 2 * error
		if doubled_error > -span.y:
			error -= span.y
			cell.x += step.x
		if doubled_error < span.x:
			error += span.x
			cell.y += step.y

		# A ray cannot pass diagonally between two touching walls.
		if cell.x != previous.x and cell.y != previous.y:
			if not is_walkable(Vector2i(cell.x, previous.y)) and not is_walkable(Vector2i(previous.x, cell.y)):
				return cell == target and not is_walkable(cell)
		if cell != target and not is_walkable(cell):
			return false
	return true
