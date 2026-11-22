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
