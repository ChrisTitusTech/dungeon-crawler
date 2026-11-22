class_name DungeonMinimap
extends Control

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

	var tile: float = minf(2.0, minf(size.x / _floor.size.x, size.y / _floor.size.y))
	var origin: Vector2 = ((size - Vector2(_floor.size) * tile) / 2.0).floor()
	for cell: Vector2i in _floor.explored:
		var color: Color = WALL
		if _floor.is_walkable(cell):
			color = VISIBLE if _floor.visible.has(cell) else FLOOR
			if _floor.terrain_at(cell) in ["D", "d"]:
				color = Color("#448078")
			elif _floor.terrain_at(cell) == ">":
				color = Color("#e8c07b")
		draw_rect(Rect2(origin + Vector2(cell) * tile, Vector2.ONE * tile), color)

	for enemy: DungeonFloor.Enemy in _floor.enemies:
		if _floor.visible.has(enemy.cell):
			draw_rect(Rect2(origin + Vector2(enemy.cell) * tile, Vector2.ONE * tile), ENEMY)
	draw_rect(Rect2(origin + Vector2(_floor.player) * tile - Vector2.ONE, Vector2.ONE * (tile + 2)), PLAYER)
