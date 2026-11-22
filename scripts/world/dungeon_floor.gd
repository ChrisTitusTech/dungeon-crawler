class_name DungeonFloor
extends RefCounted

enum EnemyKind { RAT, GUARD, BOSS }

class Enemy:
	var kind: EnemyKind
	var cell: Vector2i
	var home: Vector2i
	var patrol_end: Vector2i

	func _init(enemy_kind: EnemyKind, spawn: Vector2i) -> void:
		kind = enemy_kind
		cell = spawn
		home = spawn
		patrol_end = spawn


const SIGHT_RADIUS := 7
const CHASE_RADIUS := 6
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var size: Vector2i
var player: Vector2i
var turn: int = 0
var safe_room: Rect2i
var enemies: Array[Enemy] = []
var encounter: Enemy
var visible: Dictionary[Vector2i, bool] = {}
var explored: Dictionary[Vector2i, bool] = {}

var _rows: PackedStringArray
var _reprieved_enemy: Enemy


func _init(rows: PackedStringArray, sanctuary: Rect2i = Rect2i()) -> void:
	_rows = rows
	safe_room = sanctuary
	size = Vector2i(rows[0].length(), rows.size())
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			match rows[y][x]:
				"S": player = cell
				"r": enemies.append(Enemy.new(EnemyKind.RAT, cell))
				"g": enemies.append(Enemy.new(EnemyKind.GUARD, cell))
				"b": enemies.append(Enemy.new(EnemyKind.BOSS, cell))

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
	return terrain != "#" and terrain != "t"


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

	turn += 1
	encounter = enemy_at(destination)
	if encounter == null:
		player = destination
		_advance_enemies()
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


func _advance_enemies() -> void:
	for enemy: Enemy in enemies:
		if enemy == _reprieved_enemy or enemy.kind == EnemyKind.BOSS:
			continue

		var goal: Vector2i = enemy.patrol_end if enemy.cell == enemy.home else enemy.home
		if not safe_room.has_point(player) and enemy.cell.distance_squared_to(player) <= CHASE_RADIUS * CHASE_RADIUS:
			if _has_line_of_sight(enemy.cell, player):
				goal = player

		var next: Vector2i = _step_toward(enemy.cell, goal)
		if next == player:
			encounter = enemy
			return
		enemy.cell = next


func _step_toward(origin: Vector2i, goal: Vector2i) -> Vector2i:
	var next: Vector2i = origin
	var best_distance: int = origin.distance_squared_to(goal)
	for direction: Vector2i in CARDINALS:
		var step: Vector2i = origin + direction
		var distance: int = step.distance_squared_to(goal)
		if distance < best_distance and not safe_room.has_point(step) and is_walkable(step) and enemy_at(step) == null:
			next = step
			best_distance = distance
	return next


func _update_visibility() -> void:
	visible.clear()
	for y: int in range(maxi(0, player.y - SIGHT_RADIUS), mini(size.y, player.y + SIGHT_RADIUS + 1)):
		for x: int in range(maxi(0, player.x - SIGHT_RADIUS), mini(size.x, player.x + SIGHT_RADIUS + 1)):
			var cell := Vector2i(x, y)
			if player.distance_squared_to(cell) <= SIGHT_RADIUS * SIGHT_RADIUS:
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
