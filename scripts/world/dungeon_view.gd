class_name DungeonView
extends Node2D

signal movement_finished

const PARTY_MARK := Color(0.47, 0.88, 0.78, 0.72)
const ENEMY_MARK := Color(0.98, 0.55, 0.43, 0.7)
const STEP_TIME := 0.13
const STONE_COLORS := [Color("#5e6069"), Color("#665776"), Color("#46616a")]
const PARTY_OFFSETS := [Vector2(7, 8), Vector2(-12, 2), Vector2(22, -4), Vector2(-25, -6)]
const FOOTPRINT_POINTS := [Vector2.ZERO, Vector2(-4, 0), Vector2(4, 0), Vector2(0, -2), Vector2(0, 2)]
const TILE_TOP := Vector2(0, -8)
const TILE_LEFT := Vector2(-16, 0)
const TILE_RIGHT := Vector2(16, 0)
const TILE_BOTTOM := Vector2(0, 8)

@onready var _tiles: TileMapLayer = $Tiles
@onready var _camera: Camera2D = $Camera
@onready var _ground: Node2D = $Ground

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
var _moving: bool
var _ambient_time: float
var _stone_color: Color = STONE_COLORS[0]
var _torch_glow: GradientTexture2D
var _ambient_frame: int
var _party_facing: float = 1.0
var _clash_turn: int = -1
var _clash_started: float


func _ready() -> void:
	_ground.draw.connect(_draw_ground)
	get_viewport().size_changed.connect(_ground.queue_redraw)
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	falloff.colors = PackedColorArray([Color("#ffcd84"), Color(0.98, 0.51, 0.22, 0.27), Color(0.79, 0.32, 0.16, 0)])
	_torch_glow = GradientTexture2D.new()
	_torch_glow.gradient = falloff
	_torch_glow.width = 128
	_torch_glow.height = 128
	_torch_glow.fill = GradientTexture2D.FILL_RADIAL
	_torch_glow.fill_from = Vector2(0.5, 0.5)
	_torch_glow.fill_to = Vector2(1, 0.5)


func load_floor(floor_state: DungeonFloor, party: Array[BattleRules.Fighter], campaign: CampaignRun = null) -> void:
	_floor = floor_state
	_party = party
	_campaign = campaign
	_stone_color = Color("#706150") if campaign != null and campaign.at_camp() else STONE_COLORS[0]
	if campaign != null and not campaign.at_camp():
		_stone_color = STONE_COLORS[campaign.floor_number - 1]
	_moving = false
	_clash_turn = -1
	_player_cell = floor_state.player
	_enemy_cells.clear()
	_visible_cells.clear()
	_paint_order.clear()
	refresh()


func refresh(animate: bool = false) -> bool:
	if not _floor.skirmish.is_empty() and _clash_turn != _floor.turn:
		_clash_turn = _floor.turn
		_clash_started = _ambient_time
	_player_from = _player_cell
	_player_cell = _floor.player
	if _player_from != _player_cell:
		_party_facing = _facing(_player_from, _player_cell)
	_enemy_from = _enemy_cells.duplicate()
	_enemy_cells.clear()
	_previous_visibility = _visible_cells
	_visible_cells = _floor.visible.duplicate()
	var moving: bool = _player_from != _player_cell
	for enemy: DungeonFloor.Enemy in _floor.enemies:
		_enemy_cells[enemy] = enemy.cell
		if _enemy_from.get(enemy, enemy.cell) != enemy.cell:
			moving = moving or _visible_cells.has(enemy.cell) or _previous_visibility.has(_enemy_from[enemy])

	_refresh_tiles()
	if animate and moving and DisplayServer.get_name() != "headless":
		_moving = true
		_set_step_progress(0.0)
		return true
	_set_step_progress(1.0)
	return false


func is_moving() -> bool:
	return _moving


func _refresh_tiles() -> void:
	if _paint_order.size() != _floor.explored.size():
		_paint_order = _floor.explored.keys()
		_paint_order.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
			var left_depth: int = left.x + left.y
			var right_depth: int = right.x + right.y
			return left.x < right.x if left_depth == right_depth else left_depth < right_depth
		)
	_ground.queue_redraw()


func _draw_ground() -> void:
	var window: Rect2 = _view_bounds()
	for cell: Vector2i in _paint_order:
		var center: Vector2 = _tiles.map_to_local(cell)
		if not window.has_point(center) or _floor.is_wall(cell):
			continue
		var shade: Color = _tile_color(cell)
		var seam: Color = shade.darkened(0.28)
		var points := PackedVector2Array([center + TILE_TOP, center + TILE_RIGHT,
			center + TILE_BOTTOM, center + TILE_LEFT])
		_ground.draw_colored_polygon(points, seam)
		for index: int in points.size():
			points[index] = points[index].lerp(center, 0.06)
		_ground.draw_colored_polygon(points, shade)
		_ground.draw_line(points[3], points[0], shade.lightened(0.14), 0.65, true)
		_ground.draw_line(points[0], points[1], shade.lightened(0.075), 0.65, true)
		if _visible_cells.has(cell) and posmod(cell.x * 7 + cell.y * 11, 9) < 3:
			_ground.draw_polyline(PackedVector2Array([center + Vector2(-8, 1), center + Vector2(-3, -1),
				center + Vector2(0, 0), center + Vector2(5, -2)]), seam.lightened(0.08), 0.7, true)


func _tile_color(cell: Vector2i) -> Color:
	var variant: float = float(posmod(cell.x * 31 + cell.y * 17 + cell.x * cell.y, 13)) / 13.0
	var stone: Color = _stone_color.lightened(variant * 0.13)
	return stone if _visible_cells.has(cell) else stone.lerp(Color("#131822"), 0.67)


func _view_bounds() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size + Vector2(112, 112)
	return Rect2(_camera.position - viewport_size * 0.5, viewport_size)


func _set_step_progress(progress: float) -> void:
	_step_progress = progress
	_camera.position = _project_step(_player_from, _player_cell)
	_camera.force_update_scroll()
	queue_redraw()


func _process(delta: float) -> void:
	if _floor == null or not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	_ambient_time += delta
	if _moving:
		var progress: float = _step_progress + delta / STEP_TIME
		_set_step_progress(minf(progress, 1.0))
		if progress >= 1.0:
			_moving = false
			movement_finished.emit()
			# Carry the unused part of this frame into a chained step.
			if _moving:
				_set_step_progress(minf(progress - 1.0, 1.0))
	var frame: int = floori(_ambient_time * 30.0)
	if frame != _ambient_frame:
		_ambient_frame = frame
		queue_redraw()


func cell_at_screen_position(screen_position: Vector2) -> Vector2i:
	var local_position: Vector2 = _tiles.get_global_transform_with_canvas().affine_inverse() * screen_position
	return _tiles.local_to_map(local_position)


func _draw() -> void:
	if _floor == null:
		return

	# The leader's marker follows the step. Each companion is sorted at their own feet.
	var party_depth: Vector2i = _draw_depth(_player_from, _player_cell)
	var party_center: Vector2 = _project_step(_player_from, _player_cell)
	var party_depths: Dictionary[Vector2i, Array] = _party_placements(party_center)
	var enemy_depths: Dictionary[Vector2i, DungeonFloor.Enemy] = {}
	for enemy: DungeonFloor.Enemy in _floor.enemies:
		var origin: Vector2i = _enemy_from.get(enemy, enemy.cell)
		if _visible_cells.has(enemy.cell) or (is_moving() and _previous_visibility.has(origin)):
			enemy_depths[_draw_depth(origin, enemy.cell)] = enemy
	var view: Rect2 = _view_bounds()
	for cell: Vector2i in _visible_cells:
		var center: Vector2 = _tiles.map_to_local(cell)
		if view.has_point(center) and _floor.terrain_at(cell) == "t":
			var pulse: float = sin(_ambient_time * 6.0 + center.x) * 0.035
			draw_texture_rect(_torch_glow, Rect2(center - Vector2(57, 28), Vector2(114, 55)), false,
				Color(1.0, 0.91, 0.76, 0.25 + pulse))
	for cell: Vector2i in _paint_order:
		if not view.has_point(_tiles.map_to_local(cell)):
			continue
		_draw_cell(cell)
		if cell == party_depth:
			_draw_outline(party_center, Vector2(14, 7), PARTY_MARK)
		for actor: Dictionary in party_depths.get(cell, []):
			_draw_actor(actor.feet, actor.model, actor.height, _party_facing,
				_pose(_player_from != _player_cell, actor.slot))
		var enemy: DungeonFloor.Enemy = enemy_depths.get(cell)
		if enemy != null:
			_draw_enemy(enemy)
	_draw_skirmish()


func _draw_skirmish() -> void:
	if _floor.skirmish.is_empty() or _clash_turn != _floor.turn:
		return
	var progress: float = (_ambient_time - _clash_started) / 0.35
	if progress >= 1.0:
		return
	var first: Vector2 = _tiles.map_to_local(_floor.skirmish[0].cell)
	var second: Vector2 = _tiles.map_to_local(_floor.skirmish[1].cell)
	var center: Vector2 = first.lerp(second, 0.5) - Vector2(0, 14)
	var spark := Color(1.0, 0.70, 0.39, 1.0 - progress)
	for ray: int in range(5):
		var direction: Vector2 = Vector2.from_angle(ray * TAU / 5.0 + 0.3)
		var tip: Vector2 = center + direction * lerpf(3.0, 13.0, progress)
		draw_line(tip - direction * 4.0, tip, spark, 1.4, true)


func _draw_cell(cell: Vector2i) -> void:
	var center: Vector2 = _tiles.map_to_local(cell)
	var terrain: String = _floor.terrain_at(cell)
	var is_visible: bool = _floor.visible.has(cell)

	if _floor.is_wall(cell):
		_draw_wall(cell, center)
		if terrain == "t" and is_visible:
			_draw_torch(center - Vector2(0, 13))
		return

	if terrain == "+":
		var threshold := Color(0.83, 0.67, 0.42, 0.82 if is_visible else 0.36)
		_draw_outline(center, Vector2(13, 6), threshold)
	if not is_visible:
		return

	if _campaign != null:
		_draw_landmark(cell, center, terrain)


func _party_placements(center: Vector2) -> Dictionary[Vector2i, Array]:
	var tiles: Dictionary[Vector2i, Array] = {}
	var slot: int = 0
	for index: int in _party.size():
		var member: BattleRules.Fighter = _party[index]
		if member.hp == 0:
			continue
		var model: String = ActorArt.model(member, "rook" if index == 0 else "mira")
		var height: float = 36.0 if slot == 0 else 32.0
		if member.is_pet:
			height = 27.0
		var feet: Vector2 = _party_feet(center, PARTY_OFFSETS[slot])
		var tile: Vector2i = _tiles.local_to_map(feet)
		if not tiles.has(tile):
			tiles[tile] = []
		tiles[tile].append({"feet": feet, "model": model, "height": height, "slot": slot})
		slot += 1
	for actors: Array in tiles.values():
		actors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.feet.y < right.feet.y)
	return tiles


func _party_feet(center: Vector2, offset: Vector2) -> Vector2:
	# Walk the offset out from the leader so a companion cannot skip over a wall.
	var samples: int = maxi(1, ceili(offset.length() / 2.0))
	var feet: Vector2 = center
	for step: int in range(1, samples + 1):
		var candidate: Vector2 = center + offset * (float(step) / samples)
		if not _has_party_footing(candidate):
			break
		feet = candidate
	return feet


func _has_party_footing(feet: Vector2) -> bool:
	for point: Vector2 in FOOTPRINT_POINTS:
		var tile: Vector2i = _tiles.local_to_map(feet + point)
		if not _floor.is_walkable(tile) or not _floor.explored.has(tile):
			return false
	return true


func _draw_enemy(enemy: DungeonFloor.Enemy) -> void:
	var origin: Vector2i = _enemy_from.get(enemy, enemy.cell)
	var center: Vector2 = _project_step(origin, enemy.cell)
	var was_visible: bool = _previous_visibility.has(origin)
	var opacity: float = lerpf(float(was_visible), float(_visible_cells.has(enemy.cell)), _step_progress)
	if enemy.kind == DungeonFloor.EnemyKind.MIMIC:
		_draw_chest(center)
		return
	var accent: Color = ENEMY_MARK if enemy.hostile else PARTY_MARK
	accent.a *= opacity
	_draw_outline(center, Vector2(12, 6), accent)
	var model: String = _campaign.enemy_id(enemy.kind) if _campaign != null else CampaignRun.ENEMY_IDS[enemy.kind]
	var facing: float = _facing(origin, enemy.cell) if origin != enemy.cell else _facing(enemy.cell, _player_cell)
	_draw_actor(center + Vector2(0, 4), model, 48.0 if enemy.kind == DungeonFloor.EnemyKind.BOSS else 36.0,
		facing, _pose(origin != enemy.cell, enemy.home.x), opacity)


func _pose(moved: bool = false, offset: int = 0) -> ActorArt.Pose:
	if moved and _step_progress < 1.0:
		return ActorArt.Pose.new((float(_floor.turn % 2) + _step_progress) * PI + offset * 0.75, 1.0)
	return ActorArt.Pose.new(_ambient_time * 4.0 + offset * 0.75)


func _facing(from: Vector2i, to: Vector2i) -> float:
	var horizontal: float = _tiles.map_to_local(to).x - _tiles.map_to_local(from).x
	return -1.0 if horizontal < 0.0 else 1.0


func _draw_depth(origin: Vector2i, destination: Vector2i) -> Vector2i:
	return origin if _step_progress < 0.5 and _floor.explored.has(origin) else destination


func _project_step(origin: Vector2i, destination: Vector2i) -> Vector2:
	return _tiles.map_to_local(origin).lerp(_tiles.map_to_local(destination), _step_progress)


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
				_draw_actor(center + Vector2(0, 3), "guard", 34.0, 1.0, _pose(false, 3))
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
			_draw_actor(center + Vector2(0, 3), "sable", 33.0, 1.0, _pose(false, 1))
		elif terrain == "P":
			_draw_outline(center, Vector2(10, 5), PARTY_MARK)
			_draw_actor(center + Vector2(0, 3), "cinder", 27.0, 1.0, _pose(false, 2))
		elif terrain == "!":
			_draw_outline(center, Vector2(10, 5), Color("#b39df4"))
			draw_rect(Rect2(center + Vector2(-5, -12), Vector2(10, 9)), Color("#514071"))
			draw_rect(Rect2(center + Vector2(-3, -10), Vector2(6, 4)), Color("#b39df4"))
		elif terrain == "T":
			var pennant := Color("#b6a3f7")
			draw_line(center + Vector2(0, 3), center + Vector2(0, -18), Color("#b39163"), 1.8, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(1, -18),
				center + Vector2(13, -15), center + Vector2(1, -9)]), pennant)


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


func _draw_wall(cell: Vector2i, center: Vector2) -> void:
	var rise := Vector2(0, 15)
	var top: Vector2 = center - rise
	var shade: Color = _tile_color(cell)
	var near: Vector2 = center + TILE_BOTTOM
	var left: Vector2 = center + TILE_LEFT
	var right: Vector2 = center + TILE_RIGHT
	draw_colored_polygon(PackedVector2Array([left - rise, near - rise, near, left]), shade.darkened(0.37))
	draw_colored_polygon(PackedVector2Array([near - rise, right - rise, right, near]), shade.darkened(0.53))
	draw_colored_polygon(PackedVector2Array([top + TILE_TOP, top + TILE_RIGHT,
		top + TILE_BOTTOM, top + TILE_LEFT]), shade.darkened(0.13))
	draw_line(left - rise, near - rise, shade.lightened(0.12), 0.75, true)
	draw_line(near - rise, right - rise, shade.lightened(0.035), 0.75, true)
	if _visible_cells.has(cell):
		var grout: Color = shade.darkened(0.69)
		draw_polyline(PackedVector2Array([left - rise * 0.49, near - rise * 0.49, right - rise * 0.49]), grout, 0.9, true)
		var joint: Vector2 = left.lerp(near, 0.45)
		draw_line(joint - rise, joint - rise * 0.50, grout, 0.75, true)
		joint = near.lerp(right, 0.56)
		draw_line(joint - rise * 0.50, joint, grout, 0.75, true)


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


func _draw_actor(feet: Vector2, model: String, sprite_size: float, facing: float,
	pose: ActorArt.Pose, opacity: float = 1.0) -> void:
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, sprite_size * 0.28, Color(0.04, 0.05, 0.08, 0.52 * opacity), true, -1.0, true)
	ActorArt.draw(self, model, feet, sprite_size, facing, pose, Color(1, 1, 1, opacity))
