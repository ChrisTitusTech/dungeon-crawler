class_name FloorOneGenerator
extends RefCounted

const VERSION := 2
const WIDTH := 118
const HEIGHT := 84
const LEGACY_DOOR := Vector2i(13, 21)
const ENTRY := [
	"###########",
	"#t.......t#",
	"#.........#",
	"#..DS......",
	"#.........#",
	"#.........#",
	"###########",
]
const ARENA := [
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

var _terrain := PackedByteArray()
var _rooms: Array[Rect2i] = []
var _random := RandomNumberGenerator.new()


func generate(floor_seed: int) -> DungeonLayout:
	_random.seed = floor_seed
	_terrain.resize(WIDTH * HEIGHT)
	_terrain.fill("#".unicode_at(0))
	_rooms.clear()
	var entry := Vector2i(3, _random.randi_range(14, HEIGHT - 21))
	var arena := Vector2i(101, _random.randi_range(9, HEIGHT - 18))
	_stamp(entry, ENTRY)
	_rooms.append(Rect2i(entry, Vector2i(11, 7)))
	_place_rooms(_random.randi_range(18, 24))
	_connect_rooms()
	_stamp(arena, ARENA)
	var arena_door: Vector2i = arena + Vector2i(0, 4)
	var approach: Vector2i = _rooms[1].get_center()
	for room: Rect2i in _rooms:
		var center: Vector2i = room.get_center()
		if center.distance_squared_to(arena_door) < approach.distance_squared_to(arena_door):
			approach = center
	var threshold: Vector2i = arena_door + Vector2i.LEFT
	_tunnel(approach, threshold)
	_put(threshold, ".")
	_place_encounters()

	var layout := DungeonLayout.new()
	layout.refuge_door = entry + Vector2i(3, 3)
	for y: int in HEIGHT:
		layout.rows.append(_terrain.slice(y * WIDTH, (y + 1) * WIDTH).get_string_from_ascii())
	return layout


static func legacy(floor_seed: int) -> DungeonLayout:
	var layout: DungeonLayout = LegacyFloorOneGenerator.new().generate(floor_seed)
	var row: String = layout.rows[LEGACY_DOOR.y]
	layout.rows[LEGACY_DOOR.y] = row.left(LEGACY_DOOR.x) + "D" + row.substr(LEGACY_DOOR.x + 1)
	layout.refuge_door = LEGACY_DOOR
	return layout


func _place_rooms(target: int) -> void:
	for attempt: int in 900:
		if _rooms.size() >= target + 1:
			break
		var size := Vector2i(_random.randi_range(7, 15), _random.randi_range(6, 11))
		var origin := Vector2i(_random.randi_range(18, 98 - size.x),
			_random.randi_range(3, HEIGHT - size.y - 3))
		var candidate := Rect2i(origin, size)
		if _rooms.any(func(room: Rect2i) -> bool: return candidate.grow(2).intersects(room)):
			continue
		_rooms.append(candidate)
		var chamfer: int = _random.randi_range(0, 2)
		for y: int in size.y:
			for x: int in size.x:
				var edge_x: int = mini(x, size.x - x - 1)
				var edge_y: int = mini(y, size.y - y - 1)
				if edge_x + edge_y >= chamfer:
					_put(origin + Vector2i(x, y), ".")


func _connect_rooms() -> void:
	var joined: Array[int] = [0]
	var links := {}
	while joined.size() < _rooms.size():
		var best := Vector2i(-1, -1)
		var score: float = INF
		for first: int in joined:
			for second: int in range(1, _rooms.size()):
				if joined.has(second):
					continue
				var distance: float = _rooms[first].get_center().distance_to(_rooms[second].get_center())
				var candidate: float = distance * _random.randf_range(0.8, 1.2)
				if candidate < score:
					score = candidate
					best = Vector2i(first, second)
		_link(best.x, best.y)
		links[Vector2i(mini(best.x, best.y), maxi(best.x, best.y))] = true
		joined.append(best.y)

	var extra: int = _random.randi_range(4, 9)
	for attempt: int in 90:
		if extra == 0:
			break
		var first: int = _random.randi_range(1, _rooms.size() - 2)
		var second: int = _random.randi_range(first + 1, _rooms.size() - 1)
		var key := Vector2i(first, second)
		if links.has(key) or _rooms[first].get_center().distance_squared_to(_rooms[second].get_center()) > 34 * 34:
			continue
		_link(first, second)
		links[key] = true
		extra -= 1


func _link(first: int, second: int) -> void:
	var start: Vector2i = _rooms[first].get_center()
	if first == 0:
		start.x = _rooms[0].end.x - 1
	_tunnel(start, _rooms[second].get_center())


func _tunnel(start: Vector2i, end: Vector2i) -> void:
	if _random.randf() < 0.5:
		var x: int = _random.randi_range(mini(start.x, end.x), maxi(start.x, end.x))
		var a := Vector2i(x, start.y)
		var b := Vector2i(x, end.y)
		_carve(start, a)
		_carve(a, b)
		_carve(b, end)
	else:
		var y: int = _random.randi_range(mini(start.y, end.y), maxi(start.y, end.y))
		var a := Vector2i(start.x, y)
		var b := Vector2i(end.x, y)
		_carve(start, a)
		_carve(a, b)
		_carve(b, end)


func _carve(start: Vector2i, end: Vector2i) -> void:
	var point: Vector2i = start
	var step: Vector2i = (end - start).sign()
	while point != end:
		if _terrain[point.y * WIDTH + point.x] == "#".unicode_at(0):
			_put(point, ".")
		point += step


func _place_encounters() -> void:
	var first_room: int = 1
	for index: int in range(1, _rooms.size()):
		var entry: Vector2i = _rooms[0].get_center()
		if entry.distance_squared_to(_rooms[index].get_center()) < entry.distance_squared_to(_rooms[first_room].get_center()):
			first_room = index
	for index: int in range(1, _rooms.size()):
		var room: Rect2i = _rooms[index]
		var center: Vector2i = room.get_center()
		if index == first_room:
			_put(center, "R")
			_put(center + Vector2i(2, -1), "r")
			_put(center + Vector2i(2, 1), "k")
			_put(center + Vector2i(-2, 1), "!")
			continue
		var count: int = _random.randi_range(0, 2)
		for enemy: int in count:
			var cell: Vector2i = center + Vector2i(_random.randi_range(-1, 1), enemy * 2 - 1)
			var roll: float = _random.randf()
			_put(cell, "r" if roll < 0.5 else ("g" if roll < 0.75 else "k"))
		if count == 0 or _random.randf() < 0.48:
			_put(room.position + Vector2i(2, 1), "c")


func _stamp(origin: Vector2i, rows: Array) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			_put(origin + Vector2i(x, y), row[x])


func _put(cell: Vector2i, glyph: String) -> void:
	_terrain[cell.y * WIDTH + cell.x] = glyph.unicode_at(0)
