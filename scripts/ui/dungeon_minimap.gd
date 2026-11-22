class_name DungeonMinimap
extends Control

const SCALE := 2
const WALL := Color("#626f78")
const FLOOR := Color("#304b4f")
const VISIBLE := Color("#648f8c")
const PLAYER := Color("#8af3cc")
const ENEMY := Color("#f77e6e")

var _floor: DungeonFloor


func refresh(floor_state: DungeonFloor) -> void:
	_floor = floor_state
	queue_redraw()


func _draw() -> void:
	if _floor == null:
		return

	var origin: Vector2 = ((size - Vector2(_floor.size * SCALE)) / 2.0).floor()
	for cell: Vector2i in _floor.explored:
		var color: Color = WALL
		if _floor.is_walkable(cell):
			color = VISIBLE if _floor.visible.has(cell) else FLOOR
		draw_rect(Rect2(origin + Vector2(cell * SCALE), Vector2(SCALE, SCALE)), color)

	for enemy: DungeonFloor.Enemy in _floor.enemies:
		if _floor.visible.has(enemy.cell):
			draw_rect(Rect2(origin + Vector2(enemy.cell * SCALE), Vector2(SCALE, SCALE)), ENEMY)
	draw_rect(Rect2(origin + Vector2(_floor.player * SCALE) - Vector2.ONE, Vector2(4, 4)), PLAYER)
