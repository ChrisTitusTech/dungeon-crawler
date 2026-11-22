class_name BattleFighterView
extends PanelContainer

@onready var _name_label: Label = %FighterName
@onready var _portrait: TextureRect = %Portrait
@onready var _hp_label: Label = %HealthLabel
@onready var _hp_bar: ProgressBar = %HealthBar


func show_fighter(fighter: BattleRules.Fighter, is_active: bool, accent: Color) -> void:
	_name_label.text = "%s%s" % ["› " if is_active else "", fighter.name]
	_name_label.modulate = accent if is_active else Color.WHITE
	_hp_label.text = "%d / %d HP" % [fighter.hp, fighter.max_hp]
	if fighter.guarding:
		_hp_label.text += " · Guard"
	_hp_bar.max_value = float(fighter.max_hp)
	_hp_bar.value = float(fighter.hp)
	_portrait.modulate = Color.WHITE if fighter.hp > 0 else Color(0.45, 0.45, 0.52)


func set_portrait(sprite: AtlasTexture) -> void:
	_portrait.texture = sprite
