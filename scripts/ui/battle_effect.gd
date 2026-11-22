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
	_effect.tween_method(_animate, 0.0, 1.0, 0.37)


func _animate(progress: float) -> void:
	_progress = progress
	queue_redraw()


func _draw() -> void:
	if _progress >= 1.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.59)
	var tint: Color = [Color("#ffe1af"), Color("#b9adff"), Color("#94d9f4"), Color("#91f0ac")][_kind]
	tint.a = 1.0 - _progress
	match _kind:
		Kind.HIT, Kind.SKILL:
			var offset: float = _progress * 6.0
			draw_polyline(PackedVector2Array([center + Vector2(-15 + offset, 10), center + Vector2(1 + offset, 0),
				center + Vector2(17 + offset, -13)]), tint, 2.0)
		Kind.GUARD:
			draw_arc(center, 11 + _progress * 4.0, 0.0, TAU, 12, tint, 2.0)
		Kind.HEAL:
			for x: float in [-11.0, 13.0]:
				var rise: Vector2 = center + Vector2(x, -_progress * 16.0)
				draw_line(rise - Vector2(0, 3), rise + Vector2(0, 3), tint)
				draw_line(rise - Vector2(3, 0), rise + Vector2(3, 0), tint)
	for spark: int in 6:
		var angle: float = float(spark) * TAU / 6.0 + 0.2
		var point: Vector2 = (center + Vector2.from_angle(angle) * (8.0 + _progress * 15.0)).round()
		draw_rect(Rect2(point, Vector2(2, 2)), tint)
	if not _label.is_empty():
		var text_position := Vector2(0, maxi(11, roundi(center.y - 9.0 - _progress * 18.0)))
		var shadow := Color(0.04, 0.05, 0.09, tint.a)
		draw_string(ThemeDB.fallback_font, text_position + Vector2(1, 1), _label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, shadow)
		draw_string(ThemeDB.fallback_font, text_position, _label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, tint)
