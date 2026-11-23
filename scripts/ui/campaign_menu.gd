class_name CampaignMenu
extends Control

signal option_chosen

@onready var _heading: Label = %Heading
@onready var _detail: Label = %Detail
@onready var _scroll: ScrollContainer = %Scroll
@onready var _choices: VBoxContainer = %Choices


static func choice(label: String, run: Callable, disabled: bool = false) -> Dictionary:
	return {"label": label, "run": run, "disabled": disabled}


static func link_buttons(buttons: Array[Button], vertical: bool) -> void:
	for index: int in buttons.size():
		var button: Button = buttons[index]
		var previous: NodePath = button.get_path_to(buttons[posmod(index - 1, buttons.size())])
		var next: NodePath = button.get_path_to(buttons[(index + 1) % buttons.size()])
		if vertical:
			button.focus_neighbor_top = previous
			button.focus_neighbor_bottom = next
		else:
			button.focus_neighbor_left = previous
			button.focus_neighbor_right = next


func present(heading: String, detail: String, choices: Array[Dictionary]) -> void:
	var focus_index: int = -1
	var focused: Control = get_viewport().gui_get_focus_owner()
	if visible and _heading.text == heading and focused != null and focused.get_parent() == _choices:
		focus_index = focused.get_index()
	_heading.text = heading
	_detail.text = detail
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

	var enabled: Array[Button] = []
	var preferred: Button
	for entry: Dictionary in choices:
		var button := Button.new()
		button.text = entry.label
		button.disabled = entry.disabled
		button.custom_minimum_size.y = 25
		button.pressed.connect(_choose.bind(entry.run))
		_choices.add_child(button)
		if not button.disabled:
			enabled.append(button)
		if button.get_index() == focus_index and not button.disabled:
			preferred = button
	_scroll.scroll_vertical = 0
	link_buttons(enabled, true)
	show()
	if preferred != null:
		preferred.grab_focus()
	elif not enabled.is_empty():
		enabled[0].grab_focus()


func _choose(action: Callable) -> void:
	option_chosen.emit()
	action.call()
