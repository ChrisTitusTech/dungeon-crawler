class_name BattleView
extends Control

signal finished(outcome: BattleRules.Outcome)

const FIGHTER_CARD := preload("res://scenes/battle_fighter.tscn")
const PARTY_PORTRAITS: Array[int] = [PrototypeArt.ROOK, PrototypeArt.MIRA]
const PARTY_ACCENT := Color("#8af3cc")
const ENEMY_ACCENT := Color("#fa987e")
const ACTION_CUES := [DungeonAudio.Cue.HIT, DungeonAudio.Cue.GUARD, DungeonAudio.Cue.HEAL,
	DungeonAudio.Cue.RETREAT, DungeonAudio.Cue.SKILL]

@onready var _timeline: Label = %Timeline
@onready var _fighters: HBoxContainer = %Fighters
@onready var _log: Label = %BattleLog
@onready var _commands: HBoxContainer = %Commands
@onready var _attack: Button = %Attack
@onready var _skill: Button = %Skill
@onready var _defend: Button = %Defend
@onready var _item: Button = %Item
@onready var _flee: Button = %Flee
@onready var _continue: Button = %Continue
@onready var _enemy_delay: Timer = $EnemyDelay

var rules: BattleRules
var _party_cards: Array[BattleFighterView] = []
var _enemy_card: BattleFighterView
var _uses_checkpoint: bool
var _audio: DungeonAudio
var _controls_held: bool
var _animating: bool
var _result_cue_played: bool


func _ready() -> void:
	_attack.pressed.connect(_choose.bind(BattleRules.Command.ATTACK))
	_skill.pressed.connect(_choose.bind(BattleRules.Command.SKILL))
	_defend.pressed.connect(_choose.bind(BattleRules.Command.DEFEND))
	_item.pressed.connect(_choose.bind(BattleRules.Command.ITEM))
	_flee.pressed.connect(_choose.bind(BattleRules.Command.FLEE))
	_continue.pressed.connect(_finish)
	_enemy_delay.timeout.connect(_enemy_turn)


func start(battle: BattleRules, enemy_kind: DungeonFloor.EnemyKind, uses_checkpoint: bool = false,
	audio: DungeonAudio = null, hold_controls: bool = false) -> void:
	rules = battle
	_uses_checkpoint = uses_checkpoint
	_audio = audio
	_controls_held = hold_controls
	for index: int in rules.party.size():
		var fighter: BattleRules.Fighter = rules.party[index]
		var portrait: int = fighter.portrait if fighter.portrait >= 0 else PARTY_PORTRAITS[index % PARTY_PORTRAITS.size()]
		var card: BattleFighterView = _add_card(portrait)
		_party_cards.append(card)
	_enemy_card = _add_card(PrototypeArt.enemy_icon(enemy_kind), true)
	_render()


func release_controls() -> void:
	if _controls_held:
		_controls_held = false
		_render()


func hold_controls() -> void:
	_controls_held = true
	_lock_commands()
	_continue.disabled = true


func _add_card(portrait: int, opposing: bool = false) -> BattleFighterView:
	var card: BattleFighterView = FIGHTER_CARD.instantiate() as BattleFighterView
	_fighters.add_child(card)
	card.set_portrait(portrait, opposing)
	return card


func _choose(command: BattleRules.Command) -> void:
	if _controls_held or _animating:
		return
	var actor: BattleRules.Fighter = rules.current_fighter()
	var target: BattleRules.Fighter = rules.enemy
	match command:
		BattleRules.Command.ITEM: target = rules.potion_target()
		BattleRules.Command.DEFEND: target = actor
		BattleRules.Command.FLEE: target = null
	var previous_hp: int = target.hp if target != null else 0
	if rules.use_command(command):
		_present_action(command, actor, target, previous_hp)


func _enemy_turn() -> void:
	if _controls_held or _animating or rules.current_fighter() != rules.enemy:
		return
	var target: BattleRules.Fighter = rules.enemy_target()
	if target == null:
		return
	var previous_hp: int = target.hp
	rules.take_enemy_turn()
	_present_action(BattleRules.Command.ATTACK, rules.enemy, target, previous_hp)


func _finish() -> void:
	if not _controls_held and not _animating and rules.outcome != BattleRules.Outcome.IN_PROGRESS:
		finished.emit(rules.outcome)


func _present_action(command: BattleRules.Command, actor: BattleRules.Fighter,
	target: BattleRules.Fighter, previous_hp: int) -> void:
	if DisplayServer.get_name() == "headless":
		_render()
		return
	_animating = true
	_lock_commands()
	_card_for(actor).perform(command)
	await get_tree().create_timer(0.105).timeout
	if _audio != null:
		_audio.play_cue(ACTION_CUES[command])
	if target != null:
		var kind := BattleEffect.Kind.HIT
		var amount: int = target.hp - previous_hp
		var label: String = "%+d" % amount
		match command:
			BattleRules.Command.SKILL: kind = BattleEffect.Kind.SKILL
			BattleRules.Command.ITEM: kind = BattleEffect.Kind.HEAL
			BattleRules.Command.DEFEND:
				kind = BattleEffect.Kind.GUARD
				label = "Guard"
		_card_for(target).impact(kind, label)
	_update_fighters(actor)
	await get_tree().create_timer(0.205).timeout
	_animating = false
	_render()


func _card_for(fighter: BattleRules.Fighter) -> BattleFighterView:
	return _enemy_card if fighter == rules.enemy else _party_cards[rules.party.find(fighter)]


func _lock_commands() -> void:
	for button: Button in [_attack, _skill, _defend, _item, _flee]:
		button.disabled = true


func _update_fighters(actor: BattleRules.Fighter) -> void:
	for index: int in rules.party.size():
		var member: BattleRules.Fighter = rules.party[index]
		_party_cards[index].show_fighter(member, member == actor, PARTY_ACCENT)
	_enemy_card.show_fighter(rules.enemy, rules.enemy == actor, ENEMY_ACCENT)
	_log.text = "\n".join(rules.messages)


func _render() -> void:
	var actor: BattleRules.Fighter = rules.current_fighter()
	_update_fighters(actor)
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

	var can_act: bool = not _controls_held and not resolved and actor != rules.enemy
	_attack.disabled = not can_act
	_skill.visible = rules.party.any(func(member: BattleRules.Fighter) -> bool: return not member.skill.is_empty())
	_skill.disabled = not can_act or not actor.skill_ready
	_skill.text = actor.skill.get("name", "Skill") if can_act else "Skill"
	_skill.tooltip_text = actor.skill.get("name", "") + " · Once per fight" if can_act else ""
	_defend.disabled = not can_act
	_flee.disabled = not can_act
	_item.disabled = not can_act or rules.potions == 0 or rules.potion_target() == null
	_item.text = "Item (%d)" % rules.potions
	_continue.visible = resolved
	_continue.disabled = _controls_held
	_continue.text = "Back to dungeon"
	if rules.outcome == BattleRules.Outcome.LOST:
		_continue.text = "Reload checkpoint" if _uses_checkpoint else "Retry floor"
	_commands.visible = not resolved

	if _controls_held:
		return
	if resolved:
		if not _result_cue_played and _audio != null:
			if rules.outcome == BattleRules.Outcome.WON:
				_audio.play_cue(DungeonAudio.Cue.VICTORY)
			elif rules.outcome == BattleRules.Outcome.LOST:
				_audio.play_cue(DungeonAudio.Cue.DEFEAT)
			_result_cue_played = true
		_continue.grab_focus()
	elif not can_act:
		_enemy_delay.start()
	else:
		var focused: Button = get_viewport().gui_get_focus_owner() as Button
		if focused == null or focused.disabled:
			_attack.grab_focus()
