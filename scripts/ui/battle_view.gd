class_name BattleView
extends Control

signal finished(outcome: BattleRules.Outcome)

const FIGHTER_CARD := preload("res://scenes/battle_fighter.tscn")
const PARTY_PORTRAITS: Array[int] = [PrototypeArt.ROOK, PrototypeArt.MIRA]
const PARTY_ACCENT := Color("#8af3cc")
const ENEMY_ACCENT := Color("#fa987e")

@onready var _timeline: Label = %Timeline
@onready var _fighters: HBoxContainer = %Fighters
@onready var _log: Label = %BattleLog
@onready var _commands: HBoxContainer = %Commands
@onready var _attack: Button = %Attack
@onready var _defend: Button = %Defend
@onready var _item: Button = %Item
@onready var _flee: Button = %Flee
@onready var _continue: Button = %Continue
@onready var _enemy_delay: Timer = $EnemyDelay

var rules: BattleRules
var _party_cards: Array[BattleFighterView] = []
var _enemy_card: BattleFighterView


func _ready() -> void:
	_attack.pressed.connect(_choose.bind(BattleRules.Command.ATTACK))
	_defend.pressed.connect(_choose.bind(BattleRules.Command.DEFEND))
	_item.pressed.connect(_choose.bind(BattleRules.Command.ITEM))
	_flee.pressed.connect(_choose.bind(BattleRules.Command.FLEE))
	_continue.pressed.connect(_finish)
	_enemy_delay.timeout.connect(_enemy_turn)


func start(battle: BattleRules, enemy_kind: DungeonFloor.EnemyKind) -> void:
	rules = battle
	for index: int in rules.party.size():
		var card: BattleFighterView = _add_card(PARTY_PORTRAITS[index % PARTY_PORTRAITS.size()])
		_party_cards.append(card)
	_enemy_card = _add_card(PrototypeArt.enemy_icon(enemy_kind))
	_render()


func _add_card(portrait: int) -> BattleFighterView:
	var card: BattleFighterView = FIGHTER_CARD.instantiate() as BattleFighterView
	_fighters.add_child(card)
	card.set_portrait(PrototypeArt.icon(portrait))
	return card


func _choose(command: BattleRules.Command) -> void:
	if rules.use_command(command):
		_render()


func _enemy_turn() -> void:
	rules.take_enemy_turn()
	_render()


func _finish() -> void:
	finished.emit(rules.outcome)


func _render() -> void:
	var actor: BattleRules.Fighter = rules.current_fighter()
	for index: int in rules.party.size():
		var member: BattleRules.Fighter = rules.party[index]
		_party_cards[index].show_fighter(member, member == actor, PARTY_ACCENT)
	_enemy_card.show_fighter(rules.enemy, rules.enemy == actor, ENEMY_ACCENT)
	_log.text = "\n".join(rules.messages)

	var resolved: bool = rules.outcome != BattleRules.Outcome.IN_PROGRESS
	if resolved:
		match rules.outcome:
			BattleRules.Outcome.WON: _timeline.text = "Victory"
			BattleRules.Outcome.FLED: _timeline.text = "Escaped"
			BattleRules.Outcome.LOST: _timeline.text = "Party down"
	else:
		var names := PackedStringArray()
		for fighter: BattleRules.Fighter in rules.turn_order():
			names.append(fighter.name)
		_timeline.text = "Turn order   %s" % "  ›  ".join(names)

	var can_act: bool = not resolved and actor != rules.enemy
	_attack.disabled = not can_act
	_defend.disabled = not can_act
	_flee.disabled = not can_act
	_item.disabled = not can_act or rules.potions == 0 or rules.potion_target() == null
	_item.text = "Item (%d)" % rules.potions
	_continue.visible = resolved
	_continue.text = "Retry floor" if rules.outcome == BattleRules.Outcome.LOST else "Back to dungeon"
	_commands.visible = not resolved

	if resolved:
		_continue.grab_focus()
	elif not can_act:
		_enemy_delay.start()
	else:
		var focused: Button = get_viewport().gui_get_focus_owner() as Button
		if focused == null or focused.disabled:
			_attack.grab_focus()
