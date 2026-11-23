class_name EquipmentView
extends Control

signal back_requested
signal gear_changed(member: BattleRules.Fighter)
signal option_chosen

const MODEL := preload("res://scenes/battle_fighter.tscn")
const SLOT_NAMES: Dictionary[String, String] = {"weapon": "Weapon", "armor": "Chest armor"}

@onready var _members: HBoxContainer = %Members
@onready var _stage: Control = %Stage
@onready var _weapon: Button = %Weapon
@onready var _armor: Button = %Armor
@onready var _stats: Label = %Stats
@onready var _grid: GridContainer = %Grid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _item_name: Label = %ItemName
@onready var _detail: Label = %Detail
@onready var _apply: Button = %Apply
@onready var _back: Button = %Back

var _run: CampaignRun
var _member: BattleRules.Fighter
var _preview: BattleFighterView
var _slot: String
var _item: String


func _ready() -> void:
	_preview = MODEL.instantiate() as BattleFighterView
	_stage.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_preview.anchor_top = 0.78
	_preview.anchor_bottom = 0.78
	_preview.get_node("%Tag").hide()
	_stage.move_child(_preview, 1)
	for slot: String in SLOT_NAMES:
		var button: Button = _slot_button(slot)
		var icon := GearIcon.new()
		icon.kind = slot
		_add_tile_content(button, icon, SLOT_NAMES[slot])
		button.pressed.connect(_select_slot.bind(slot))
	_armor.focus_neighbor_left = _armor.get_path_to(_weapon)
	_weapon.focus_neighbor_top = _weapon.get_path_to(_armor)
	_apply.pressed.connect(_apply_selection)
	_back.pressed.connect(func() -> void:
		option_chosen.emit()
		back_requested.emit()
	)


func present(run: CampaignRun, reduced_motion: bool) -> void:
	_run = run
	_preview.reduced_motion = reduced_motion
	_clear(_members)
	for member: BattleRules.Fighter in run.party:
		var tab := Button.new()
		tab.text = member.name
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void:
			option_chosen.emit()
			_select_member(member)
		)
		_members.add_child(tab)
		tab.focus_neighbor_bottom = tab.get_path_to(_armor)
	_show_pack()
	_scroll.scroll_vertical = 0
	show()
	_select_member(run.party[0])
	(_members.get_child(0) as Button).grab_focus()


func _select_member(member: BattleRules.Fighter) -> void:
	_member = member
	_slot = ""
	_item = ""
	_preview.set_model(ActorArt.model(member, "rook"), false, 145.0)
	_preview.show_fighter(member, false, Color.WHITE)
	_update_character()
	_update_selection()


func _show_pack() -> void:
	_clear(_grid)
	var items: Array[String] = _run.inventory.keys()
	items.sort()
	for item: String in items:
		var definition: Dictionary = CampaignRun.CONTENT.items.get(item, {})
		if definition.is_empty():
			continue
		var cell: Button = _new_cell()
		var icon := GearIcon.new()
		icon.kind = definition.get("slot", "material")
		if item in ["tonic", "bandage"]:
			icon.kind = item
		elif definition.has("loot"):
			icon.kind = "loot"
		elif definition.get("bonus", 0) >= 4:
			icon.modulate = Color("#efd6ad")
		_add_tile_content(cell, icon, "×%d" % _run.count(item))
		cell.tooltip_text = "%s ×%d\n%s" % [definition.name, _run.count(item), definition.get("description", "")]
		cell.set_meta("item", item)
		cell.pressed.connect(_select_item.bind(item))
	var capacity: int = maxi(12, ceili(float(_grid.get_child_count()) / _grid.columns) * _grid.columns)
	for index: int in range(_grid.get_child_count(), capacity):
		_new_cell().disabled = true


func _new_cell() -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(41, 43)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.toggle_mode = true
	_grid.add_child(cell)
	return cell


func _add_tile_content(button: Button, icon: GearIcon, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	button.add_child(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_top: float = 8.0 if button == _weapon or button == _armor else 3.0
	icon.set_anchor_and_offset(SIDE_LEFT, 0.5, -12)
	icon.set_anchor_and_offset(SIDE_RIGHT, 0.5, 12)
	icon.offset_top = icon_top
	icon.offset_bottom = icon_top + 24
	button.add_child(label)
	label.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0)
	label.set_anchor_and_offset(SIDE_TOP, 1.0, -16)
	label.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -2)


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _slot_button(slot: String) -> Button:
	return _weapon if slot == "weapon" else _armor


func _equipped(slot: String) -> String:
	return _member.weapon if slot == "weapon" else _member.armor


func _update_character() -> void:
	for index: int in _run.party.size():
		(_members.get_child(index) as Button).set_pressed_no_signal(_run.party[index] == _member)
	for slot: String in SLOT_NAMES:
		var button: Button = _slot_button(slot)
		var item: String = _equipped(slot)
		var definition: Dictionary = CampaignRun.CONTENT.items.get(item, {})
		button.tooltip_text = "%s · %s" % [SLOT_NAMES[slot], definition.get("name", "Empty")]
		(button.get_child(0) as GearIcon).modulate.a = 0.4 if item.is_empty() else 1.0
	_stats.text = "Lv %d   ·   %d ATK   ·   %d Armor" % [_member.level, _member.attack_power(),
		_member.armor_bonus + _member.natural_armor]
	if _member.is_pet or _member.hp == 0:
		_stats.text += "   ·   " + ("Fallen" if _member.hp == 0 else "Pet")


func _select_slot(slot: String) -> void:
	option_chosen.emit()
	_slot = slot
	_item = ""
	_update_selection()


func _select_item(item: String) -> void:
	option_chosen.emit()
	_item = item
	_slot = CampaignRun.CONTENT.items[item].get("slot", "")
	_update_selection()


func _update_selection() -> void:
	_weapon.set_pressed_no_signal(_slot == "weapon")
	_armor.set_pressed_no_signal(_slot == "armor")
	var pack_buttons: Array[Button] = []
	for cell: Button in _grid.get_children():
		var item: String = cell.get_meta("item", "") if cell.has_meta("item") else ""
		if item.is_empty():
			continue
		pack_buttons.append(cell)
		cell.set_pressed_no_signal(not _item.is_empty() and _item == item)
		var slot: String = CampaignRun.CONTENT.items.get(item, {}).get("slot", "")
		cell.modulate = Color.WHITE if _slot.is_empty() or slot == _slot else Color(0.66, 0.72, 0.74)

	_apply.disabled = true
	_apply.text = "Equip"
	var eligible: bool = not _member.is_pet and _member.hp > 0
	if not _item.is_empty():
		var definition: Dictionary = CampaignRun.CONTENT.items[_item]
		_item_name.text = "%s ×%d" % [definition.name, _run.count(_item)]
		_detail.text = definition.get("description", "Crafting material")
		if not _slot.is_empty():
			var equipped: String = _equipped(_slot)
			if _item == equipped:
				_detail.text += "\nAlready equipped"
			elif not equipped.is_empty():
				_detail.text += "\nReplaces %s" % CampaignRun.CONTENT.items[equipped].name
			_apply.disabled = not eligible or _item == equipped
	elif not _slot.is_empty():
		var definition: Dictionary = CampaignRun.CONTENT.items.get(_equipped(_slot), {})
		_item_name.text = SLOT_NAMES[_slot]
		_detail.text = "Empty · Choose compatible gear from the pack." if definition.is_empty() else "%s\n%s" % [definition.name, definition.description]
		_apply.text = "Unequip to pack"
		_apply.disabled = not eligible or definition.is_empty()
	else:
		_item_name.text = _member.name
		_detail.text = "Select a gear slot or an item in the pack."
	if not eligible and not _slot.is_empty():
		_detail.text = "Pets cannot equip gear." if _member.is_pet else "Fallen party members cannot change gear."
	_link_pack_focus(pack_buttons)


func _link_pack_focus(buttons: Array[Button]) -> void:
	if buttons.is_empty():
		_armor.focus_neighbor_right = _armor.get_path_to(_back)
		_weapon.focus_neighbor_right = _weapon.get_path_to(_back)
		return
	var last: int = buttons.size() - 1
	var last_row: int = last - last % _grid.columns
	_armor.focus_neighbor_right = _armor.get_path_to(buttons[0])
	_weapon.focus_neighbor_right = _weapon.get_path_to(buttons[last_row])
	for row_start: int in range(0, buttons.size(), _grid.columns):
		var first: Button = buttons[row_start]
		first.focus_neighbor_left = first.get_path_to(_armor if row_start == 0 else _weapon)
	for index: int in range(last_row, buttons.size()):
		var button: Button = buttons[index]
		button.focus_neighbor_bottom = NodePath() if _apply.disabled else button.get_path_to(_apply)


func _apply_selection() -> void:
	if _apply.disabled:
		return
	var changed: bool = _run.unequip(_member, _slot) if _item.is_empty() else _run.equip(_member, _item)
	if changed:
		option_chosen.emit()
		gear_changed.emit(_member)
		_item = ""
		_show_pack()
		_update_character()
		_update_selection()
		_slot_button(_slot).grab_focus()


class GearIcon extends Control:
	var kind: String

	func _draw() -> void:
		var silver := Color("#a8bcc9")
		var gold := Color("#e0aa66")
		var shade := Color("#713f36")
		match kind:
			"weapon":
				draw_colored_polygon(PackedVector2Array([Vector2(5, 15), Vector2(16, 4), Vector2(22, 2),
					Vector2(20, 8), Vector2(9, 19)]), silver)
				draw_line(Vector2(5, 17), Vector2(20, 4), Color("#e8f5e7"), 1.2, true)
				draw_line(Vector2(4, 13), Vector2(11, 20), gold, 2.6, true)
				draw_line(Vector2(7, 17), Vector2(3, 21), shade.lightened(0.22), 3.0, true)
			"armor":
				draw_colored_polygon(PackedVector2Array([Vector2(3, 6), Vector2(8, 3), Vector2(12, 7),
					Vector2(16, 3), Vector2(21, 6), Vector2(23, 13), Vector2(18, 13),
					Vector2(18, 21), Vector2(6, 21), Vector2(6, 13), Vector2(1, 13)]), silver)
				draw_line(Vector2(7, 15), Vector2(17, 15), Color("#546680"), 2.5, true)
				draw_line(Vector2(6, 18), Vector2(18, 18), gold, 1.0, true)
			"tonic":
				draw_rect(Rect2(9, 3, 6, 7), silver)
				draw_circle(Vector2(12, 15), 7, Color("#72b4a5"), true, -1.0, true)
				draw_circle(Vector2(10, 13), 2, Color("#bce9c9"), true, -1.0, true)
			"bandage":
				draw_rect(Rect2(4, 6, 16, 13), Color("#e5d8a8"))
				draw_line(Vector2(12, 8), Vector2(12, 17), shade, 2, true)
				draw_line(Vector2(8, 12.5), Vector2(16, 12.5), shade, 2, true)
			"loot":
				draw_rect(Rect2(3, 6, 18, 14), shade)
				draw_rect(Rect2(3, 6, 18, 6), gold)
				draw_rect(Rect2(10, 11, 4, 4), Color("#f5dc92"))
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(5, 5), Vector2(17, 3),
					Vector2(21, 12), Vector2(15, 21), Vector2(5, 19), Vector2(2, 11)]), Color("#779e88"))
				draw_line(Vector2(5, 5), Vector2(17, 3), Color("#b8c891"), 1.5, true)
