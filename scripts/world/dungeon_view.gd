class_name DungeonView
extends Node2D

const STONE := preload("res://assets/tactics_stone.png")
const STONE_TILE_SIZE := 32
const WALL_OFFSET := Vector2(16, 16)
const WALL_CONNECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const REMEMBERED := Color(0.46, 0.49, 0.58)
const PARTY_MARK := Color(0.47, 0.88, 0.78, 0.72)
const ENEMY_MARK := Color(0.98, 0.55, 0.43, 0.7)

@onready var _tiles: TileMapLayer = $Tiles
@onready var _camera: Camera2D = $Camera

var _floor: DungeonFloor
var _party: Array[BattleRules.Fighter]
var _campaign: CampaignRun


func load_floor(floor_state: DungeonFloor, party: Array[BattleRules.Fighter], campaign: CampaignRun = null) -> void:
	_floor = floor_state
	_party = party
	_campaign = campaign
	_tiles.clear()
	refresh()


func refresh() -> void:
	_camera.position = _tiles.map_to_local(_floor.player)
	for cell: Vector2i in _floor.explored:
		if _floor.is_walkable(cell):
			var variant: int = (cell.x * 31 + cell.y * 17 + cell.x * cell.y * 7) % 7
			var atlas_cell := Vector2i(variant if variant <= 2 else 0, 0)
			var shading: int = 0 if _floor.visible.has(cell) else 1
			_tiles.set_cell(cell, 0, atlas_cell, shading)
	queue_redraw()


func cell_at_screen_position(screen_position: Vector2) -> Vector2i:
	var local_position: Vector2 = _tiles.get_global_transform_with_canvas().affine_inverse() * screen_position
	return _tiles.local_to_map(local_position)


func _draw() -> void:
	if _floor == null:
		return

	# Nearer walls and figures cover those behind them in the projected view.
	for depth: int in _floor.size.x + _floor.size.y - 1:
		var start: int = maxi(0, depth - _floor.size.y + 1)
		var end: int = mini(depth + 1, _floor.size.x)
		for x: int in range(start, end):
			var cell := Vector2i(x, depth - x)
			if _floor.explored.has(cell):
				_draw_cell(cell)


func _draw_cell(cell: Vector2i) -> void:
	var center: Vector2 = _tiles.map_to_local(cell)
	var terrain: String = _floor.terrain_at(cell)
	var is_visible: bool = _floor.visible.has(cell)

	if not _floor.is_walkable(cell):
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
	if cell == _floor.player:
		_draw_outline(center, Vector2(14, 7), PARTY_MARK)
		var standing: int = 0
		for member: BattleRules.Fighter in _party:
			if member.hp == 0:
				continue
			var portrait: int = member.portrait if member.portrait >= 0 else mini(standing, PrototypeArt.MIRA)
			var offset := Vector2(standing * -7 + 6, standing * -3 + 4)
			_draw_actor(center + offset, portrait, 34.0 if standing == 0 else 28.0)
			standing += 1
		return

	var enemy: DungeonFloor.Enemy = _floor.enemy_at(cell)
	if enemy != null:
		_draw_outline(center, Vector2(12, 6), ENEMY_MARK)
		_draw_actor(center + Vector2(0, 4), PrototypeArt.enemy_icon(enemy.kind),
			48.0 if enemy.kind == DungeonFloor.EnemyKind.BOSS else 35.0)


func _draw_landmark(cell: Vector2i, center: Vector2, terrain: String) -> void:
	if _campaign.fallen_gear.has(cell):
		_draw_outline(center, Vector2(8, 4), Color("#c89b66"))
	if terrain == ">" or terrain == "S":
		var color := Color("#e8c07b") if terrain == ">" else PARTY_MARK
		for offset: int in [-2, 1, 4]:
			draw_line(center + Vector2(-6, offset), center + Vector2(6, offset), color)
	elif not _campaign.used_sites.has(cell):
		if terrain == "c":
			draw_rect(Rect2(center + Vector2(-5, -4), Vector2(10, 6)), Color("#5c4034"))
			draw_line(center + Vector2(-5, -4), center + Vector2(5, -4), Color("#ebbb74"))
		elif terrain == "R":
			_draw_outline(center, Vector2(10, 5), PARTY_MARK)
			_draw_actor(center + Vector2(0, 3), PrototypeArt.SABLE, 31.0)


func _wall_region(cell: Vector2i) -> Rect2:
	var connections: int = 0
	for index: int in WALL_CONNECTIONS.size():
		var neighbor: Vector2i = cell + WALL_CONNECTIONS[index]
		if _floor.explored.has(neighbor) and not _floor.is_walkable(neighbor):
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
	var glow: Vector2 = center + Vector2(0, -3)
	draw_circle(glow, 10, Color(0.95, 0.52, 0.17, 0.09))
	draw_circle(glow, 6, Color(1.0, 0.62, 0.25, 0.18))
	draw_rect(Rect2(center + Vector2(-2, 0), Vector2(4, 4)), Color("#4c3440"))
	var flame := PackedVector2Array([center + Vector2(-3, 0), center + Vector2(-2, -4),
		center + Vector2(0, -7), center + Vector2(3, -2), center + Vector2(2, 1)])
	draw_colored_polygon(flame, Color("#f4953b"))
	draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 3)), Color("#ffe2a1"))


func _draw_actor(feet: Vector2, index: int, sprite_size: float) -> void:
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 8, Color(0.04, 0.05, 0.08, 0.5))
	draw_set_transform(Vector2.ZERO)
	var anchor: float = 0.82 if index == PrototypeArt.RAT else 0.89
	var position_offset := Vector2(sprite_size * 0.5, sprite_size * anchor)
	var rect := Rect2((feet - position_offset).round(), Vector2.ONE * sprite_size)
	draw_texture_rect_region(PrototypeArt.ATLAS, rect, PrototypeArt.region(index), Color.WHITE, false, true)
