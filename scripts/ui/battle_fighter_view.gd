class_name BattleFighterView
extends Control

@onready var _name_label: Label = %FighterName
@onready var _portrait: TextureRect = %Portrait
@onready var _hp_label: Label = %HealthLabel
@onready var _hp_bar: ProgressBar = %HealthBar
@onready var _effects: BattleEffect = %Effects
@onready var _tag: PanelContainer = %Tag

var _portrait_id: int
var _sprite: AtlasTexture
var _facing: float = 1.0
var _elapsed: float
var _alive: bool = true
var _accent: Color
var _active: bool
var _sprite_size: float
var _portrait_origin: Vector2
var _pose_offset := Vector2.ZERO
var _pose_tween: Tween
var _health_tween: Tween
var _health_ready: bool
var _flash: Tween
var _monster_kind: DungeonFloor.EnemyKind


func show_fighter(fighter: BattleRules.Fighter, is_active: bool, accent: Color) -> void:
	_name_label.text = "%s%s" % ["› " if is_active else "", fighter.name]
	_name_label.modulate = accent if is_active else Color.WHITE
	_hp_label.text = "%d / %d HP" % [fighter.hp, fighter.max_hp]
	if fighter.guarding:
		_hp_label.text += " · Guard"
	elif not fighter.injuries.is_empty():
		_hp_label.text += " · Injured"
	_hp_bar.max_value = float(fighter.max_hp)
	if not _health_ready or DisplayServer.get_name() == "headless":
		_hp_bar.value = float(fighter.hp)
		_health_ready = true
	elif absf(_hp_bar.value - fighter.hp) > 0.01:
		if _health_tween != null and _health_tween.is_valid():
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(_hp_bar, "value", float(fighter.hp), 0.17)
	_alive = fighter.hp > 0
	_portrait.modulate = Color.WHITE if fighter.hp > 0 else Color(0.45, 0.45, 0.52)
	_accent = accent
	_active = is_active and _alive
	queue_redraw()


func set_portrait(index: int, opposing: bool, sprite_size: float) -> void:
	_portrait_id = index
	_sprite = PrototypeArt.icon(index)
	_portrait.texture = _sprite
	_portrait.flip_h = not opposing
	_facing = 1.0 if opposing else -1.0
	_sprite_size = sprite_size
	var foot_line: float = 0.82 if index == PrototypeArt.RAT else 0.9
	_portrait_origin = Vector2(-sprite_size * 0.5, -sprite_size * foot_line)
	_portrait.position = _portrait_origin
	_portrait.size = Vector2.ONE * sprite_size
	_effects.position = _portrait_origin
	_effects.size = _portrait.size
	if opposing:
		_tag.offset_left = -102.0
		_tag.offset_right = 102.0
	_elapsed = index * 0.7


func set_monster_shape(kind: DungeonFloor.EnemyKind) -> void:
	_monster_kind = kind
	_portrait.hide()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	_elapsed += delta
	var bob: float = sin(_elapsed * 4.3) * 0.85 if _alive else 0.0
	_portrait.position = _portrait_origin + _pose_offset + Vector2(0.0, bob)
	if PrototypeArt.has_monster_shape(_monster_kind):
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.23))
	draw_circle(Vector2.ZERO, _sprite_size * 0.33, Color(0.025, 0.032, 0.047, 0.5), true, -1.0, true)
	if _active:
		draw_arc(Vector2.ZERO, _sprite_size * 0.31, 0.0, TAU, 36, _accent, 1.4, true)
	draw_set_transform(Vector2.ZERO)
	if PrototypeArt.has_monster_shape(_monster_kind):
		PrototypeArt.draw_monster(self, _monster_kind, _pose_offset, _sprite_size,
			_portrait.modulate * _portrait.self_modulate)


func perform(command: BattleRules.Command) -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	var reach: Vector2
	match command:
		BattleRules.Command.ATTACK: reach = Vector2(14 * _facing, -2)
		BattleRules.Command.SKILL: reach = Vector2(10 * _facing, -6)
		BattleRules.Command.DEFEND: reach = Vector2(-4 * _facing, 3)
		BattleRules.Command.ITEM: reach = Vector2(1 * _facing, -4)
		BattleRules.Command.FLEE: reach = Vector2(-14 * _facing, -2)
	_sprite.region = PrototypeArt.region(_portrait_id, PrototypeArt.ACTION)
	_pose_tween = create_tween()
	_pose_tween.tween_property(self, "_pose_offset", reach, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "_pose_offset", Vector2.ZERO, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_callback(_idle_pose)


func impact(kind: BattleEffect.Kind, label: String) -> void:
	_effects.burst(kind, label)
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_portrait.self_modulate = Color(1.35, 1.27, 1.18) if kind == BattleEffect.Kind.HIT else Color(1.18, 1.19, 1.34)
	_flash = create_tween()
	_flash.tween_property(_portrait, "self_modulate", Color.WHITE, 0.15)


func _idle_pose() -> void:
	_sprite.region = PrototypeArt.region(_portrait_id)
