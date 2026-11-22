class_name DungeonGame
extends Control

const LAYOUT: DungeonLayout = preload("res://data/prototype_floor.tres")
const BATTLE_SCREEN := preload("res://scenes/battle.tscn")
const MOVEMENT: Dictionary[StringName, Vector2i] = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}
const MOVE_HINT := "WASD, arrows, or click adjacent"

@onready var _dungeon: DungeonView = $Dungeon
@onready var _interface: CanvasLayer = $Interface
@onready var _hud: Control = $Interface/HUD
@onready var _minimap: DungeonMinimap = %Minimap
@onready var _map_panel: PanelContainer = %MapPanel
@onready var _roster: Label = %Roster
@onready var _turn: Label = %Turn
@onready var _remaining: Label = %Remaining
@onready var _status: Label = %Status
@onready var _wait_button: Button = %Wait
@onready var _map_button: Button = %Map

var _floor: DungeonFloor
var _party: Array[BattleRules.Fighter] = []
var _tonics: int
var _battle: BattleView


func _ready() -> void:
	_wait_button.pressed.connect(_take_turn.bind(Vector2i.ZERO))
	_map_button.pressed.connect(_toggle_minimap)
	_start_floor()


func _process(_delta: float) -> void:
	if _battle != null:
		return

	if Input.is_action_just_pressed(&"toggle_minimap"):
		_toggle_minimap()
	for action: StringName in MOVEMENT:
		if Input.is_action_just_pressed(action):
			_take_turn(MOVEMENT[action])
			return
	if Input.is_action_just_pressed(&"wait_turn"):
		_take_turn(Vector2i.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if _battle == null and event is InputEventMouseButton and event.is_action_pressed(&"select_tile"):
		var direction: Vector2i = _dungeon.cell_at_screen_position(event.position) - _floor.player
		if absi(direction.x) + absi(direction.y) == 1:
			_take_turn(direction)
			get_viewport().set_input_as_handled()


func _start_floor() -> void:
	_floor = DungeonFloor.new(LAYOUT.rows)
	_party = [
		BattleRules.Fighter.new("Rook", 22, 6, 9),
		BattleRules.Fighter.new("Mira", 17, 5, 13),
	]
	_tonics = 2
	_dungeon.load_floor(_floor, _party)
	_refresh_exploration(MOVE_HINT)


func _take_turn(direction: Vector2i) -> void:
	if _battle != null or not _floor.take_turn(direction):
		return

	_dungeon.refresh()
	_refresh_exploration(MOVE_HINT)
	if _floor.encounter != null:
		_open_battle(_floor.encounter.kind)


func _open_battle(enemy_kind: DungeonFloor.EnemyKind) -> void:
	var opponent: BattleRules.Fighter
	match enemy_kind:
		DungeonFloor.EnemyKind.RAT:
			opponent = BattleRules.Fighter.new("Cinder rat", 13, 4, 7)
		DungeonFloor.EnemyKind.GUARD:
			opponent = BattleRules.Fighter.new("Vault guard", 25, 7, 11)
	_battle = BATTLE_SCREEN.instantiate() as BattleView
	_hud.hide()
	_dungeon.hide()
	_interface.add_child(_battle)
	_battle.finished.connect(_close_battle)
	_battle.start(BattleRules.new(_party, opponent, _tonics), enemy_kind)


func _close_battle(outcome: BattleRules.Outcome) -> void:
	_tonics = _battle.rules.potions
	_battle.hide()
	_battle.queue_free()
	_battle = null
	_dungeon.show()
	_hud.show()

	if outcome == BattleRules.Outcome.LOST:
		_start_floor()
		return

	_floor.resolve_encounter(outcome == BattleRules.Outcome.WON)
	_dungeon.refresh()
	var notice := "Enemy defeated." if outcome == BattleRules.Outcome.WON else "You fled. The enemy is still nearby."
	_refresh_exploration(notice)


func _refresh_exploration(notice: String) -> void:
	var health := PackedStringArray()
	for member: BattleRules.Fighter in _party:
		health.append("%s %d/%d" % [member.name, member.hp, member.max_hp])
	_roster.text = "  ·  ".join(health)
	_turn.text = "Turn %d" % _floor.turn
	_remaining.text = "%d foes left" % _floor.enemies.size()
	_status.text = "Dungeon clear." if _floor.enemies.is_empty() else notice
	_minimap.refresh(_floor)


func _toggle_minimap() -> void:
	_map_panel.visible = not _map_panel.visible
