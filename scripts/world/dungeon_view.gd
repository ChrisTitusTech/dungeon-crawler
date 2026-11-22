class_name DungeonView
extends Node2D

signal movement_finished

const STONE := preload("res://assets/tactics_stone.png")
const STONE_TILE_SIZE := 32
const WALL_OFFSET := Vector2(16, 16)
const WALL_CONNECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const REMEMBERED := Color(0.46, 0.49, 0.58)
const PARTY_MARK := Color(0.47, 0.88, 0.78, 0.72)
const ENEMY_MARK := Color(0.98, 0.55, 0.43, 0.7)
const STEP_TIME := 0.13

@onready var _tiles: TileMapLayer = $Tiles
@onready var _camera: Camera2D = $Camera

var _floor: DungeonFloor
var _party: Array[BattleRules.Fighter]
var _campaign: CampaignRun
var _paint_order: Array[Vector2i] = []
var _player_cell: Vector2i
var _player_from: Vector2i
var _enemy_cells: Dictionary[DungeonFloor.Enemy, Vector2i] = {}
var _enemy_from: Dictionary[DungeonFloor.Enemy, Vector2i] = {}
var _previous_visibility: Dictionary[Vector2i, bool] = {}
var _visible_cells: Dictionary[Vector2i, bool] = {}
var _step_progress: float = 1.0
var _movement: Tween
var _ambient_time: float
var _ambient_frame: int


func load_floor(floor_state: DungeonFloor, party: Array[BattleRules.Fighter], campaign: CampaignRun = null) -> void:
	_floor = floor_state
	_party = party
	_campaign = campaign
	if _movement != null and _movement.is_valid():
		_movement.kill()
	_movement = null
	_player_cell = floor_state.player
	_enemy_cells.clear()
	_visible_cells.clear()
	_tiles.clear()
	refresh()


func refresh(animate: bool = false) -> bool:
	_player_from = _player_cell
	_player_cell = _floor.player
	_enemy_from = _enemy_cells.duplicate()
	_enemy_cells.clear()
	_previous_visibility = _visible_cells
	_visible_cells = _floor.visible.duplicate()
	var moving: bool = _player_from != _player_cell
	for enemy: DungeonFloor.Enemy in _floor.enemies:
		_enemy_cells[enemy] = enemy.cell
		if _enemy_from.get(enemy, enemy.cell) != enemy.cell:
			moving = moving or _visible_cells.has(enemy.cell) or _previous_visibility.has(_enemy_from[enemy])

	_paint_order = _floor.explored.keys()
	_paint_order.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		var left_depth: int = left.x + left.y
		var right_depth: int = right.x + right.y
		return left.x < right.x if left_depth == right_depth else left_depth < right_depth
	)
	for cell: Vector2i in _floor.explored:
		if not _floor.is_wall(cell):
			var variant: int = (cell.x * 31 + cell.y * 17 + cell.x * cell.y * 7) % 7
			var atlas_cell := Vector2i(variant if variant <= 2 else 0, 0)
			var shading: int = 0 if _floor.visible.has(cell) else 1
			_tiles.set_cell(cell, 0, atlas_cell, shading)
	if animate and moving and DisplayServer.get_name() != "headless":
		_set_step_progress(0.0)
		_movement = create_tween()
		_movement.tween_method(_set_step_progress, 0.0, 1.0, STEP_TIME)
		_movement.finished.connect(_finish_movement)
		return true
	_set_step_progress(1.0)
	return false


func is_moving() -> bool:
	return _movement != null


func _set_step_progress(progress: float) -> void:
	_step_progress = progress
	_camera.position = _project_step(_player_from, _player_cell)
	_camera.force_update_scroll()
	queue_redraw()


func _finish_movement() -> void:
	_movement = null
	movement_finished.emit()


func _process(delta: float) -> void:
	if _floor == null or not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	_ambient_time += delta
	var frame: int = floori(_ambient_time * 12.0)
	if frame != _ambient_frame:
		_ambient_frame = frame
		queue_redraw()


func cell_at_screen_position(screen_position: Vector2) -> Vector2i:
	var local_position: Vector2 = _tiles.get_global_transform_with_canvas().affine_inverse() * screen_position
	return _tiles.local_to_map(local_position)


func _draw() -> void:
	if _floor == null:
		return

	# Actors use the near or far tile for occlusion as they cross the midpoint.
	var party_depth: Vector2i = _draw_depth(_player_from, _player_cell)
	var enemy_depths: Dictionary[Vector2i, DungeonFloor.Enemy] = {}
	for enemy: DungeonFloor.Enemy in _floor.enemies:
		var origin: Vector2i = _enemy_from.get(enemy, enemy.cell)
		if _visible_cells.has(enemy.cell) or (is_moving() and _previous_visibility.has(origin)):
			enemy_depths[_draw_depth(origin, enemy.cell)] = enemy
	var viewport_size: Vector2 = get_viewport_rect().size + Vector2(112, 112)
	var view := Rect2(_camera.position - viewport_size * 0.5, viewport_size)
	for cell: Vector2i in _paint_order:
		if not view.has_point(_tiles.map_to_local(cell)):
			continue
		_draw_cell(cell)
		if cell == party_depth:
			_draw_party()
		var enemy: DungeonFloor.Enemy = enemy_depths.get(cell)
		if enemy != null:
			_draw_enemy(enemy)


func _draw_cell(cell: Vector2i) -> void:
	var center: Vector2 = _tiles.map_to_local(cell)
	var terrain: String = _floor.terrain_at(cell)
	var is_visible: bool = _floor.visible.has(cell)

	if _floor.is_wall(cell):
		var tint: Color = Color.WHITE if is_visible else REMEMBERED
		var region: Rect2 = _wall_region(cell)
		draw_texture_rect_region(STONE, Rect2(center - WALL_OFFSET, region.size), region, tint)
		if terrain == "t" and is_visible:
			_draw_torch(center - Vector2(0, 8))
		return

	if terrain == "+":
		var threshold := Color(0.83, 0.67, 0.42, 0.82 if is_visible else 0.36)
		_draw_outline(center, Vector2(13, 6), threshold)
	if not is_visible:
		return

	if _campaign != null:
		_draw_landmark(cell, center, terrain)


func _draw_party() -> void:
	var center: Vector2 = _project_step(_player_from, _player_cell)
	_draw_outline(center, Vector2(14, 7), PARTY_MARK)
	var standing: int = 0
	for index: int in _party.size():
		var member: BattleRules.Fighter = _party[index]
		if member.hp == 0:
			continue
		var portrait: int = member.portrait if member.portrait >= 0 else mini(index, PrototypeArt.MIRA)
		var offset := Vector2(standing * -7 + 6, standing * -3 + 4)
		_draw_actor(center + offset, portrait, 34.0 if standing == 0 else 28.0, _stride(_player_from != _player_cell, standing))
		standing += 1


func _draw_enemy(enemy: DungeonFloor.Enemy) -> void:
	var origin: Vector2i = _enemy_from.get(enemy, enemy.cell)
	var center: Vector2 = _project_step(origin, enemy.cell)
	var opacity: float = 1.0 if _visible_cells.has(enemy.cell) else 1.0 - _step_progress
	var accent: Color = ENEMY_MARK if enemy.hostile else PARTY_MARK
	accent.a *= opacity
	_draw_outline(center, Vector2(12, 6), accent)
	_draw_actor(center + Vector2(0, 4), PrototypeArt.enemy_icon(enemy.kind),
		48.0 if enemy.kind == DungeonFloor.EnemyKind.BOSS else 35.0,
		_stride(origin != enemy.cell), opacity)


func _stride(moved: bool, offset: int = 0) -> int:
	if moved and _step_progress < 1.0:
		return PrototypeArt.STRIDE_A + ((floori(_step_progress * 4.0) + offset + _floor.turn) % 2)
	return PrototypeArt.IDLE


func _draw_depth(origin: Vector2i, destination: Vector2i) -> Vector2i:
	return origin if _step_progress < 0.5 and _floor.explored.has(origin) else destination


func _project_step(origin: Vector2i, destination: Vector2i) -> Vector2:
	return _tiles.map_to_local(origin).lerp(_tiles.map_to_local(destination), _step_progress).round()


func _draw_landmark(cell: Vector2i, center: Vector2, terrain: String) -> void:
	if terrain == "D" or terrain == "d":
		_draw_refuge_door(center)
		return
	if _campaign.at_camp():
		match terrain:
			"B": _draw_bed(center)
			"F": _draw_dining_table(center)
			"L": _draw_chest(center)
			"G":
				_draw_outline(center, Vector2(10, 5), PARTY_MARK)
				_draw_actor(center + Vector2(0, 3), PrototypeArt.GUARD, 33.0)
			"W": _draw_workbench(center)
			"A": _draw_sponsor_board(center)
		return
	if _campaign.fallen_gear.has(cell):
		_draw_outline(center, Vector2(8, 4), Color("#c89b66"))
	if terrain == ">" or terrain == "S":
		var color := Color("#e8c07b") if terrain == ">" else PARTY_MARK
		for offset: int in [-2, 1, 4]:
			draw_line(center + Vector2(-6, offset), center + Vector2(6, offset), color)
	elif not _campaign.used_sites.has(cell):
		if terrain == "c":
			_draw_chest(center)
		elif terrain == "R":
			_draw_outline(center, Vector2(10, 5), PARTY_MARK)
			_draw_actor(center + Vector2(0, 3), PrototypeArt.SABLE, 31.0)


func _draw_refuge_door(center: Vector2) -> void:
	var outline := PackedVector2Array([
		center + Vector2(-8, 4), center + Vector2(-8, -11), center + Vector2(-4, -16),
		center + Vector2(4, -16), center + Vector2(8, -11), center + Vector2(8, 4)])
	draw_colored_polygon(outline, Color("#4a6664"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6, 3), center + Vector2(-6, -10), center + Vector2(-3, -13),
		center + Vector2(3, -13), center + Vector2(6, -10), center + Vector2(6, 3)]), Color("#875d3c"))
	for offset: int in [-3, 0, 3]:
		draw_line(center + Vector2(offset, -10), center + Vector2(offset, 3), Color("#503b33"))
	draw_circle(center + Vector2(3, -4), 1.5, Color("#f0c97c"))
	_draw_outline(center + Vector2(0, 4), Vector2(9, 3), PARTY_MARK)


func _draw_bed(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12, -2), center + Vector2(-2, -7),
		center + Vector2(12, 0), center + Vector2(12, 4),
		center + Vector2(2, 9), center + Vector2(-12, 2)]), Color("#5b4236"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-11, -3), center + Vector2(-2, -7),
		center + Vector2(11, 0), center + Vector2(2, 5)]), Color("#5d7880"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10, -3), center + Vector2(-2, -7),
		center + Vector2(3, -4), center + Vector2(-5, 0)]), Color("#e0d2ac"))


func _draw_dining_table(center: Vector2) -> void:
	for leg: Vector2 in [Vector2(-10, -2), Vector2(0, 3), Vector2(12, -2)]:
		draw_line(center + leg, center + leg + Vector2(0, 6), Color("#5a4036"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13, -4), center + Vector2(-1, -10),
		center + Vector2(13, -3), center + Vector2(1, 3)]), Color("#a37951"))
	draw_circle(center + Vector2(-4, -4), 3.0, Color("#ded4ae"))
	draw_circle(center + Vector2(4, -3), 3.0, Color("#ded4ae"))
	draw_circle(center + Vector2(-4, -4), 1.5, Color("#893e37"))
	draw_circle(center + Vector2(4, -3), 1.5, Color("#893e37"))
	for bowl: int in 2:
		var rise: float = fposmod(_ambient_time * 0.8 + bowl * 0.53, 1.0)
		var steam := Vector2(bowl * 8 - 4 + roundf(sin(rise * TAU)), -6 - roundf(rise * 7))
		draw_rect(Rect2(center + steam, Vector2(1, 2)), Color(0.91, 0.87, 0.77, 0.48 * (1.0 - rise)))


func _draw_chest(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-5, -4), Vector2(10, 6)), Color("#5c4034"))
	draw_line(center + Vector2(-5, -4), center + Vector2(5, -4), Color("#ebbb74"))


func _draw_workbench(center: Vector2) -> void:
	var top := PackedVector2Array([center + Vector2(-12, -4), center + Vector2(-1, -9),
		center + Vector2(12, -3), center + Vector2(1, 3)])
	for leg: Vector2 in [Vector2(-10, -2), Vector2(0, 3), Vector2(10, -2)]:
		draw_line(center + leg, center + leg + Vector2(0, 6), Color("#523c30"), 2.0)
	draw_colored_polygon(top, Color("#8e673f"))
	draw_line(center + Vector2(-5, -5), center + Vector2(3, -2), Color("#463a31"), 2.0)
	draw_rect(Rect2(center + Vector2(1, -6), Vector2(5, 3)), Color("#b1b0a6"))


func _draw_sponsor_board(center: Vector2) -> void:
	for x: int in [-7, 7]:
		draw_line(center + Vector2(x, -14), center + Vector2(x, 5), Color("#533c32"), 2.0)
	draw_rect(Rect2(center + Vector2(-9, -14), Vector2(18, 12)), Color("#966b44"))
	for x: int in [-6, 2]:
		draw_rect(Rect2(center + Vector2(x, -12), Vector2(4, 7)), Color("#e5d0a4"))


func _wall_region(cell: Vector2i) -> Rect2:
	var connections: int = 0
	for index: int in WALL_CONNECTIONS.size():
		var neighbor: Vector2i = cell + WALL_CONNECTIONS[index]
		if _floor.explored.has(neighbor) and _floor.is_wall(neighbor):
			connections |= 1 << index

	# The floor variants occupy the first row. The next four rows store the wall masks.
	var atlas_cell := Vector2(connections & 3, 1 + (connections >> 2))
	return Rect2(atlas_cell * STONE_TILE_SIZE, Vector2.ONE * STONE_TILE_SIZE)


func _draw_outline(center: Vector2, radii: Vector2, color: Color) -> void:
	var top := Vector2(0, -radii.y)
	var right := Vector2(radii.x, 0)
	var points := PackedVector2Array([center + top, center + right, center - top, center - right, center + top])
	draw_polyline(points, color)


func _draw_torch(center: Vector2) -> void:
	var phase: float = _ambient_time * 9.0 + center.x * 0.056 + center.y * 0.09
	var flicker: float = sin(phase)
	var glow: Vector2 = center + Vector2(0, -3)
	draw_circle(glow, 12 + flicker, Color(0.95, 0.52, 0.17, 0.085))
	draw_circle(glow, 7, Color(1.0, 0.62, 0.25, 0.16 + flicker * 0.028))
	draw_rect(Rect2(center + Vector2(-2, 0), Vector2(4, 4)), Color("#4c3440"))
	var flame := PackedVector2Array([center + Vector2(-3, 0), center + Vector2(-2, -4),
		center + Vector2(roundf(flicker), -7 - roundf(flicker)), center + Vector2(3, -2), center + Vector2(2, 1)])
	draw_colored_polygon(flame, Color("#f4953b"))
	draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 3)), Color("#ffe2a1"))
	var spark: float = fposmod(phase / TAU, 1.0)
	draw_rect(Rect2(center + Vector2(roundf(flicker * 2), -8 - roundf(spark * 9)), Vector2.ONE),
		Color(1.0, 0.68, 0.36, 0.72 * (1.0 - spark)))


func _draw_actor(feet: Vector2, index: int, sprite_size: float, pose: int = PrototypeArt.IDLE, opacity: float = 1.0) -> void:
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 8, Color(0.04, 0.05, 0.08, 0.5 * opacity))
	draw_set_transform(Vector2.ZERO)
	var anchor: float = 0.82 if index == PrototypeArt.RAT else 0.89
	var bob: float = roundf(sin(_ambient_time * 4.0 + index * 0.9) * 0.6) if pose == PrototypeArt.IDLE else 0.0
	var position_offset := Vector2(sprite_size * 0.5, sprite_size * anchor + bob)
	var rect := Rect2((feet - position_offset).round(), Vector2.ONE * sprite_size)
	draw_texture_rect_region(PrototypeArt.ATLAS, rect, PrototypeArt.region(index, pose), Color(1, 1, 1, opacity), false, true)
