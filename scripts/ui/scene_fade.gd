class_name SceneFade
extends ColorRect

signal finished

const INK := Color("#10151f")
const ENCOUNTER_INK := Color("#20283b")

var busy: bool = false


func change_scene(swap: Callable, encounter: bool = false) -> void:
	if busy:
		return
	if DisplayServer.get_name() == "headless":
		swap.call()
		finished.emit()
		return
	busy = true
	color = ENCOUNTER_INK if encounter else INK
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.18 if encounter else 0.15)
	fade.tween_callback(swap)
	fade.tween_property(self, "modulate:a", 0.0, 0.22)
	fade.tween_callback(_finish)


func _finish() -> void:
	busy = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	finished.emit()
