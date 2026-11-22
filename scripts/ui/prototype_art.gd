class_name PrototypeArt
extends RefCounted

const FRAME_SIZE := 48
const ATLAS := preload("res://assets/prototype_actors.png")
const ROOK := 0
const MIRA := 1
const RAT := 2
const GUARD := 3


static func region(index: int) -> Rect2:
	return Rect2(index * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)


static func icon(index: int) -> AtlasTexture:
	var sprite := AtlasTexture.new()
	sprite.atlas = ATLAS
	sprite.region = region(index)
	sprite.filter_clip = true
	return sprite


static func enemy_icon(kind: DungeonFloor.EnemyKind) -> int:
	return RAT if kind == DungeonFloor.EnemyKind.RAT else GUARD
