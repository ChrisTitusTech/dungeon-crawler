class_name LegacyFloorOneGenerator
extends RefCounted

# The original generation order reconstructs the enemy and map coordinates in older saves.
const WIDTH := 77
const HEIGHT := 47
const SAFE := 4
const BOSS := 7
const SAFE_TEMPLATE := [
	"###########",
	"#t.......t#",
	"#.........#",
	"#....S.....",
	"#.........#",
	"#.........#",
	"###########",
]
const BOSS_TEMPLATE := [
	"#############",
	"#t.........t#",
	"#...........#",
	"#..#.....#..#",
	"....b......>#",
	"#..#.....#..#",
	"#...........#",
	"#t.........t#",
	"#############",
]
const CONNECTIONS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7),
	Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 11),
	Vector2i(1, 5), Vector2i(5, 9), Vector2i(2, 6), Vector2i(6, 10),
]

var _cells := PackedByteArray()
var _rooms: Array[Rect2i] = []
var _random := RandomNumberGenerator.new()


func generate(floor_seed: int) -> DungeonLayout:
	_random.seed = floor_seed
	_cells.resize(WIDTH * HEIGHT)
	_cells.fill("#".unicode_at(0))
	_rooms.clear()
	for index: int in 12:
		_rooms.append(_make_room(index))
	for edge: Vector2i in CONNECTIONS:
		_connect_rooms(edge.x, edge.y)
	for edge: Vector2i in [Vector2i(1, 6), Vector2i(5, 10)]:
		if _random.randf() < 0.5:
			_connect_rooms(edge.x, edge.y)

	_place_content()
	var layout := DungeonLayout.new()
	for y: int in HEIGHT:
		layout.rows.append(_cells.slice(y * WIDTH, (y + 1) * WIDTH).get_string_from_ascii())
	layout.safe_room = _rooms[SAFE].grow(-1)
	return layout


func _make_room(index: int) -> Rect2i:
	if index == SAFE:
		return _stamp(Vector2i(3, 18), SAFE_TEMPLATE)
	if index == BOSS:
		return _stamp(Vector2i(61, 17), BOSS_TEMPLATE)

	@warning_ignore("integer_division")
	var sector := Vector2i(index % 4 * 18, index / 4 * 14)
	var width: int = _random.randi_range(8, 12)
	var height: int = _random.randi_range(7, 9)
	var room := Rect2i(sector + Vector2i(_random.randi_range(3, 5), _random.randi_range(3, 5)),
		Vector2i(width, height))
	for y: int in range(room.position.y, room.end.y):
		for x: int in range(room.position.x, room.end.x):
			_put(Vector2i(x, y), ".")
	return room


func _stamp(origin: Vector2i, template: Array) -> Rect2i:
	for y: int in template.size():
		var row: String = template[y]
		for x: int in row.length():
			_put(origin + Vector2i(x, y), row[x])
	return Rect2i(origin, Vector2i(template[0].length(), template.size()))


func _connect_rooms(first: int, second: int) -> void:
	var a: Vector2i = _rooms[first].get_center()
	var b: Vector2i = _rooms[second].get_center()
	if first == SAFE:
		a = Vector2i(_rooms[SAFE].end.x - 1, a.y)
	if second == BOSS:
		b = Vector2i(_rooms[BOSS].position.x, b.y)
	var bend := Vector2i(b.x, a.y) if _random.randf() < 0.5 else Vector2i(a.x, b.y)
	if first == SAFE or second == BOSS:
		var middle_x: int = (a.x + b.x) >> 1
		_carve(a, Vector2i(middle_x, a.y))
		_carve(Vector2i(middle_x, a.y), Vector2i(middle_x, b.y))
		_carve(Vector2i(middle_x, b.y), b)
	else:
		_carve(a, bend)
		_carve(bend, b)


func _carve(start: Vector2i, end: Vector2i) -> void:
	var point: Vector2i = start
	var step: Vector2i = (end - start).sign()
	while point != end:
		_put(point, ".")
		point += step
	_put(end, ".")


func _place_content() -> void:
	for index: int in _rooms.size():
		if index == SAFE or index == BOSS:
			continue
		var room: Rect2i = _rooms[index]
		var center: Vector2i = room.get_center()
		var encounter_count: int = 1 if index in [0, 1, 5, 8] else 2
		for offset: int in encounter_count:
			var kind := "r" if index in [0, 1, 5, 8] or _random.randf() < 0.55 else "g"
			_put(center + Vector2i(_random.randi_range(-1, 1), (offset * 2) - 1), kind)
		_put(room.position + Vector2i(1, 1), "R" if index == 5 else "c")


func _put(cell: Vector2i, glyph: String) -> void:
	_cells[cell.y * WIDTH + cell.x] = glyph.unicode_at(0)
