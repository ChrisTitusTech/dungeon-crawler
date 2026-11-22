class_name CampaignMenu
extends Control

@onready var _heading: Label = %Heading
@onready var _detail: Label = %Detail
@onready var _scroll: ScrollContainer = %Scroll
@onready var _choices: VBoxContainer = %Choices


static func choice(label: String, run: Callable, disabled: bool = false) -> Dictionary:
	return {"label": label, "run": run, "disabled": disabled}


func present(heading: String, detail: String, choices: Array[Dictionary]) -> void:
	_heading.text = heading
	_detail.text = detail
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

	var first: Button
	for entry: Dictionary in choices:
		var button := Button.new()
		button.text = entry.label
		button.disabled = entry.disabled
		button.custom_minimum_size.y = 25
		button.pressed.connect(entry.run)
		_choices.add_child(button)
		if first == null and not button.disabled:
			first = button
	_scroll.scroll_vertical = 0
	show()
	if first != null:
		first.grab_focus()
