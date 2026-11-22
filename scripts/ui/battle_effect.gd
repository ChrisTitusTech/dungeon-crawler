class_name BattleEffect
extends Control

enum Kind { HIT, SKILL, GUARD, HEAL }

var _kind: Kind
var _progress: float = 1.0
var _label: String
var _effect: Tween


func burst(kind: Kind, label: String) -> void:
	if _effect != null and _effect.is_valid():
		_effect.kill()
	_kind = kind
	_label = label
	_animate(0.0)
	_effect = create_tween()
	_effect.tween_method(_animate, 0.0, 1.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate(progress: float) -> void:
	_progress = progress
	queue_redraw()


func _draw() -> void:
	if _progress >= 1.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.59)
	var tint: Color = [Color("#ffe1af"), Color("#b9adff"), Color("#94d9f4"), Color("#91f0ac")][_kind]
	tint.a = pow(1.0 - _progress, 1.45)
	var wake: Color = Color(tint, tint.a * 0.30)
	match _kind:
		Kind.HIT, Kind.SKILL:
			var sweep: float = lerpf(-2.42, -0.66, _progress)
			var origin: Vector2 = center + Vector2(0, 11)
			var radius: float = 18.0 + _progress * 6.0
			draw_arc(origin, radius, sweep - 1.2, sweep, 20, wake, 6.0, true)
			draw_arc(origin, radius, sweep - 1.08, sweep, 20, tint, 2.3, true)
			if _kind == Kind.SKILL:
				draw_arc(origin, radius + 5.0, sweep - 0.85, sweep + 0.2, 16, wake, 2.3, true)
		Kind.GUARD:
			for ring: int in range(2):
				var radius: float = 11.0 + _progress * 9.0 + ring * 4.0
				draw_arc(center, radius, 0.0, TAU, 32, tint if ring == 0 else wake, 1.8, true)
		Kind.HEAL:
			for mote: int in range(7):
				var orbit: float = mote * TAU / 7.0 + _progress * 2.3
				var rise: Vector2 = center + Vector2(cos(orbit) * 14.0, sin(orbit) * 5.0 - _progress * (12.0 + mote))
				draw_circle(rise, 1.5 + 0.55 * (mote % 2), tint, true, -1.0, true)
	if _kind != Kind.HEAL:
		for spark: int in range(9):
			var angle: float = spark * TAU / 9.0 + 0.2
			var direction: Vector2 = Vector2.from_angle(angle)
			var point: Vector2 = center + direction * (6.0 + _progress * (14.0 + (spark % 3) * 5.0))
			draw_line(point - direction * (4.0 - 2.0 * _progress), point, tint, 1.3, true)
	if not _label.is_empty():
		var text_position := Vector2(0, maxi(12, roundi(center.y - 10.0 - _progress * 22.0)))
		var shadow := Color(0.04, 0.05, 0.09, tint.a)
		draw_string(ThemeDB.fallback_font, text_position + Vector2(1, 1), _label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, shadow)
		draw_string(ThemeDB.fallback_font, text_position, _label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, tint)
