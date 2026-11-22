class_name BattleFighterView
extends Control

const CONTACT_TIME := 0.17

@onready var _name_label: Label = %FighterName
@onready var _hp_label: Label = %HealthLabel
@onready var _hp_bar: ProgressBar = %HealthBar
@onready var _effects: BattleEffect = %Effects
@onready var _tag: PanelContainer = %Tag

var _model: String
var _facing: float = 1.0
var _elapsed: float
var _alive: bool = true
var _accent: Color
var _active: bool
var _guarding: bool
var _sprite_size: float
var _pose_offset := Vector2.ZERO
var _strike: float
var _brace: float
var _recoil: float
var _fall: float
var _cast_light: float
var _pose_tween: Tween
var _health_tween: Tween
var _health_ready: bool
var _reaction_tween: Tween


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
	elif absf(_hp_bar.value - fighter.hp) > 0.01:
		if _health_tween != null and _health_tween.is_valid():
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(_hp_bar, "value", float(fighter.hp), 0.20)
	if fighter.hp == 0 and _alive:
		_fall = 1.0
		if _health_ready and DisplayServer.get_name() != "headless":
			_fall = 0.0
			var defeat: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			defeat.tween_property(self, "_fall", 1.0, 0.36)
	_health_ready = true
	_alive = fighter.hp > 0
	_guarding = fighter.guarding
	_accent = accent
	_active = is_active and _alive
	queue_redraw()


func set_model(model: String, opposing: bool, sprite_size: float) -> void:
	_model = model
	_facing = 1.0 if opposing else -1.0
	_sprite_size = sprite_size
	_effects.position = Vector2(-sprite_size * 0.56, -sprite_size * 0.9)
	_effects.size = Vector2(sprite_size * 1.12, sprite_size)
	if opposing:
		_tag.offset_left = -100.0
		_tag.offset_right = 100.0
	_elapsed = float(posmod(model.hash(), 12)) * 0.37


func _process(delta: float) -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	if _alive:
		_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _model.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, _sprite_size * 0.33, Color(0.02, 0.03, 0.05, 0.40), true, -1.0, true)
	if _active:
		draw_arc(Vector2.ZERO, _sprite_size * 0.34, 0.0, TAU, 40, Color(_accent, 0.68), 1.3, true)
	draw_set_transform(Vector2.ZERO)
	var feet: Vector2 = _pose_offset + Vector2(-_facing * (_recoil * 8.0 + _fall * 13.0), _fall * 1.0)
	var tilt: float = -_facing * (_fall * 1.30 + _recoil * 0.14)
	var tint: Color = Color(1.0 + _recoil * 0.34, 1.0 + _recoil * 0.18, 1.0)
	tint = tint.lerp(Color(0.50, 0.53, 0.61, 0.72), _fall)
	var brace: float = maxf(_brace, 0.55 if _guarding else 0.0)
	var pose := ActorArt.Pose.new(_elapsed * 4.4, absf(_pose_offset.x) / 50.0, _strike, brace)
	ActorArt.draw(self, _model, feet, _sprite_size, _facing, pose, tint, tilt)
	if _cast_light > 0.01:
		var halo := Color(0.73, 0.67, 1.0, _cast_light * 0.74)
		var center: Vector2 = feet + Vector2(_facing * _sprite_size * 0.24, -_sprite_size * 0.52)
		draw_arc(center, 6.0 + _cast_light * 8.0, _elapsed * 8.0, _elapsed * 8.0 + 4.8, 24, halo, 1.6, true)


func perform(command: BattleRules.Command) -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	var reach := Vector2.ZERO
	var attack: float = 0.0
	var guard: float = 0.0
	var light: float = 0.0
	match command:
		BattleRules.Command.ATTACK:
			reach = Vector2(23.0 * _facing, -2)
			attack = 1.0
		BattleRules.Command.SKILL:
			reach = Vector2(15.0 * _facing, -6)
			attack = 0.78
			light = 1.0
		BattleRules.Command.DEFEND:
			reach = Vector2(-4.0 * _facing, 2)
			guard = 1.0
		BattleRules.Command.ITEM:
			reach = Vector2(3.0 * _facing, -1)
			light = 0.75
		BattleRules.Command.FLEE:
			reach = Vector2(-22.0 * _facing, -3)
	_pose_tween = create_tween()
	if attack > 0.0:
		_pose_tween.tween_property(self, "_strike", -0.60, 0.09)
		_pose_tween.parallel().tween_property(self, "_pose_offset", -reach * 0.22, 0.09)
		_pose_tween.tween_property(self, "_strike", attack, 0.08).set_trans(Tween.TRANS_QUAD)
		_pose_tween.parallel().tween_property(self, "_pose_offset", reach, 0.08).set_trans(Tween.TRANS_QUAD)
		_pose_tween.parallel().tween_property(self, "_cast_light", light, 0.08)
	else:
		_pose_tween.tween_property(self, "_pose_offset", reach, CONTACT_TIME)
		_pose_tween.parallel().tween_property(self, "_brace", guard, CONTACT_TIME)
		_pose_tween.parallel().tween_property(self, "_cast_light", light, CONTACT_TIME)
	_pose_tween.tween_property(self, "_pose_offset", Vector2.ZERO, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(self, "_strike", 0.0, 0.24)
	_pose_tween.parallel().tween_property(self, "_brace", 0.0, 0.24)
	_pose_tween.parallel().tween_property(self, "_cast_light", 0.0, 0.24)


func impact(kind: BattleEffect.Kind, label: String) -> void:
	_effects.burst(kind, label)
	if kind not in [BattleEffect.Kind.HIT, BattleEffect.Kind.SKILL]:
		return
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	_recoil = 1.0
	_reaction_tween = create_tween()
	_reaction_tween.tween_property(self, "_recoil", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
