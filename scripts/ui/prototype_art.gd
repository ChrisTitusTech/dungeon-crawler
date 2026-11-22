class_name PrototypeArt
extends RefCounted

const FRAME_SIZE := 48
const ATLAS := preload("res://assets/prototype_actors.png")
const ROOK := 0
const MIRA := 1
const RAT := 2
const GUARD := 3
const SABLE := 4
const CASTELLAN := 5
const IDLE := 0
const STRIDE_A := 1
const STRIDE_B := 2
const ACTION := 3


static func region(index: int, pose: int = IDLE) -> Rect2:
	return Rect2(index * FRAME_SIZE, pose * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)


static func icon(index: int, pose: int = IDLE) -> AtlasTexture:
	var sprite := AtlasTexture.new()
	sprite.atlas = ATLAS
	sprite.region = region(index, pose)
	sprite.filter_clip = true
	return sprite


static func enemy_icon(kind: DungeonFloor.EnemyKind) -> int:
	if kind == DungeonFloor.EnemyKind.BOSS:
		return CASTELLAN
	return RAT if kind == DungeonFloor.EnemyKind.RAT else GUARD


static func has_monster_shape(kind: DungeonFloor.EnemyKind) -> bool:
	return kind >= DungeonFloor.EnemyKind.GOBLIN


static func draw_monster(canvas: CanvasItem, kind: DungeonFloor.EnemyKind, feet: Vector2,
	sprite_size: float, tint: Color) -> void:
	canvas.draw_set_transform(feet, 0.0, Vector2.ONE * sprite_size / 32.0)
	var ink := Color("#151824") * tint
	match kind:
		DungeonFloor.EnemyKind.GOBLIN:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-5, -13),
				Vector2(5, -13), Vector2(8, 0)]), Color("#6b4253") * tint)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10, -22), Vector2(10, -22),
				Vector2(5, -15), Vector2(0, -12), Vector2(-5, -15)]), Color("#92aa6d") * tint)
			canvas.draw_rect(Rect2(-4, -19, 8, 2), ink)
			canvas.draw_line(Vector2(5, -8), Vector2(13, -13), Color("#c6bfab") * tint, 2.0)
		DungeonFloor.EnemyKind.SLIME:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -1), Vector2(-10, -9),
				Vector2(-5, -15), Vector2(6, -16), Vector2(11, -10), Vector2(14, -1)]), Color("#b76b35") * tint)
			canvas.draw_line(Vector2(-5, -12), Vector2(4, -14), Color("#f7d774") * tint, 2.0)
			canvas.draw_circle(Vector2(5, -6), 3, Color("#783b2c") * tint)
		DungeonFloor.EnemyKind.SPIDER:
			for side: int in [-1, 1]:
				for leg: int in range(4):
					var knee := Vector2(side * (9 + leg), -11 + leg * 2)
					canvas.draw_polyline(PackedVector2Array([Vector2(0, -6), knee,
						knee + Vector2(3 * side, 5)]), Color("#b69987") * tint, 1.6)
			canvas.draw_circle(Vector2(0, -7), 6, Color("#754759") * tint)
			canvas.draw_rect(Rect2(-4, -6, 8, 2), Color("#f4b3a4") * tint)
		DungeonFloor.EnemyKind.SKELETON:
			var bone := Color("#d9c9a7") * tint
			canvas.draw_line(Vector2(-5, 0), Vector2(0, -13), bone, 2.5)
			canvas.draw_line(Vector2(5, 0), Vector2(0, -13), bone, 2.5)
			for rib: int in range(3):
				canvas.draw_rect(Rect2(-6, -15 + rib * 3, 12, 1.5), bone)
			canvas.draw_rect(Rect2(-5, -25, 10, 9), bone)
			canvas.draw_rect(Rect2(-3, -22, 6, 2), ink)
		DungeonFloor.EnemyKind.MIMIC:
			canvas.draw_rect(Rect2(-11, -8, 22, 8), Color("#87583d") * tint)
			canvas.draw_rect(Rect2(-11, -14, 22, 7), ink)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, -14), Vector2(-8, -21),
				Vector2(10, -17), Vector2(11, -14)]), Color("#c89554") * tint)
			for tooth: int in [-8, -4, 0, 4, 8]:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(tooth - 1, -14),
					Vector2(tooth + 2, -14), Vector2(tooth, -10)]), Color("#f8ddab") * tint)
		DungeonFloor.EnemyKind.GARGOYLE:
			var slate := Color("#69768a") * tint
			for side: int in [-1, 1]:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(2 * side, -5),
					Vector2(13 * side, -23), Vector2(14 * side, -10), Vector2(7 * side, -12)]), slate)
			canvas.draw_rect(Rect2(-6, -12, 12, 12), Color("#8597a5") * tint)
			canvas.draw_rect(Rect2(-5, -19, 10, 8), slate)
			canvas.draw_rect(Rect2(-3, -16, 6, 2), Color("#f7c28f") * tint)
	canvas.draw_set_transform(Vector2.ZERO)
