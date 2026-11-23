class_name DungeonGame
extends Control

const LAYOUT: DungeonLayout = preload("res://data/prototype_floor.tres")
const BATTLE_SCREEN := preload("res://scenes/battle.tscn")
const RUN_MENU := preload("res://scenes/campaign_menu.tscn")
const EQUIPMENT_SCREEN := preload("res://scenes/equipment.tscn")
const MOVEMENT: Dictionary[StringName, Vector2i] = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}
const MOVE_HINT := "WASD, arrows, or click adjacent"
const NO_SITE := Vector2i(-1, -1)

@export var prototype_mode: bool = false
@export var save_directory: String = "user://"
@export var accessibility_path: String = "user://accessibility.cfg"

@onready var _dungeon: DungeonView = $Dungeon
@onready var _interface: CanvasLayer = $Interface
@onready var _hud: Control = $Interface/HUD
@onready var _minimap: DungeonMinimap = %Minimap
@onready var _map_panel: PanelContainer = %MapPanel
@onready var _roster: Label = %Roster
@onready var _title: Label = %Title
@onready var _turn: Label = %Turn
@onready var _remaining: Label = %Remaining
@onready var _status: Label = %Status
@onready var _landmark_hint: Label = %LandmarkHint
@onready var _wait_button: Button = %Wait
@onready var _map_button: Button = %Map
@onready var _interact_button: Button = %Interact
@onready var _party_button: Button = %Party
@onready var _inventory_button: Button = %Inventory
@onready var _equipment_button: Button = %Equipment
@onready var _broadcast: PanelContainer = %Broadcast
@onready var _announcer: Label = %Announcer
@onready var _fade: SceneFade = $Transition/Fade
@onready var _audio: DungeonAudio = $Audio

var _floor: DungeonFloor
var _party: Array[BattleRules.Fighter] = []
var _tonics: int
var _battle: BattleView
var _run: CampaignRun
var _menu: CampaignMenu
var _equipment: EquipmentView
var _slot: int
var _checkpoint: Dictionary
var _menu_back: Callable
var _queued_move: Vector2i = NO_SITE
var _queued_use: bool
var _held_action: StringName
var _repeat: float
var _last_clock_usec: int = Time.get_ticks_usec()
var _quitting: bool
var _reduced_motion: bool
var _single_step: bool
var _using_gamepad: bool


func _ready() -> void:
	if get_parent() == get_tree().root:
		get_tree().auto_accept_quit = false
	_dungeon.movement_finished.connect(_on_movement_finished)
	_fade.finished.connect(_resume_scene_controls)
	_load_accessibility()
	_wait_button.pressed.connect(_take_turn.bind(Vector2i.ZERO))
	_map_button.pressed.connect(_toggle_minimap)
	if prototype_mode or "--prototype" in OS.get_cmdline_user_args():
		_start_floor()
		return
	_interact_button.pressed.connect(_interact)
	_party_button.pressed.connect(_show_party)
	_inventory_button.pressed.connect(_show_inventory)
	_equipment_button.pressed.connect(_show_equipment)
	_status.hide()
	_landmark_hint.show()
	for control: Control in [_interact_button, _party_button, _inventory_button, _equipment_button, _broadcast]:
		control.show()
	_menu = RUN_MENU.instantiate() as CampaignMenu
	_interface.add_child(_menu)
	_menu.option_chosen.connect(_audio.play_cue.bind(DungeonAudio.Cue.CONFIRM))
	_equipment = EQUIPMENT_SCREEN.instantiate() as EquipmentView
	_interface.add_child(_equipment)
	_equipment.option_chosen.connect(_audio.play_cue.bind(DungeonAudio.Cue.CONFIRM))
	_equipment.gear_changed.connect(_equipment_changed)
	_equipment.back_requested.connect(func() -> void: _menu_back.call())
	_show_slots()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready() and get_parent() == get_tree().root:
		_quit()


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	_audio.stop_playback()
	if DisplayServer.get_name() != "headless":
		# Godot releases stopped streams on the audio mix thread.
		await get_tree().create_timer(maxf(0.1, AudioServer.get_output_latency() * 2.0)).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if _quitting:
		return
	var now: int = Time.get_ticks_usec()
	_update_floor_clock((now - _last_clock_usec) / 1_000_000.0)
	_last_clock_usec = now
	if not _can_explore():
		_held_action = &""
		return
	if _single_step:
		return

	var pressed: StringName
	for action: StringName in MOVEMENT:
		if Input.is_action_just_pressed(action):
			_held_action = action
			_repeat = DungeonView.STEP_TIME
			_take_turn(MOVEMENT[action])
			return
		if pressed == &"" and Input.is_action_pressed(action):
			pressed = action
	if _held_action != &"" and Input.is_action_pressed(_held_action):
		pressed = _held_action
	if pressed != _held_action:
		_held_action = pressed
		_repeat = 0.0
	if pressed != &"" and not _dungeon.is_moving():
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = DungeonView.STEP_TIME
			_take_turn(MOVEMENT[pressed])


func _update_floor_clock(elapsed: float) -> void:
	if _run == null or _run.at_camp() or _run.completed or _menu_visible() or _fade.busy:
		return
	var previous_announcement: String = _run.announcement
	_run.elapse_floor_time(elapsed)
	var remaining: String = _run.floor_time_text()
	_turn.text = "Time left %s" % remaining
	if _battle != null:
		_battle.show_floor_clock(remaining)
	if previous_announcement != _run.announcement:
		_announcer.text = "System · %s" % _run.announcement
	if _run.seconds_left <= 0.0:
		if _battle != null:
			_battle.hold_controls()
			_dismiss_battle()
			_audio.play_track(DungeonAudio.Track.DUNGEON)
		_audio.play_cue(DungeonAudio.Cue.DEFEAT)
		_prompt_reload("The floor collapsed", "The last safe-room checkpoint is intact.")


func _input(event: InputEvent) -> void:
	if _fade.busy:
		get_viewport().set_input_as_handled()
		return
	var gamepad: bool = (event is InputEventJoypadButton and event.pressed
		or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var keyboard_or_mouse: bool = (event is InputEventKey or event is InputEventMouseButton) and event.pressed
	if not (gamepad or keyboard_or_mouse) or gamepad == _using_gamepad:
		return
	_using_gamepad = gamepad
	_interact_button.text = "Use [A]" if gamepad else "Use [E]"
	_party_button.text = "Party [Y]" if gamepad else "Party [C]"
	_inventory_button.text = "Pack [X]" if gamepad else "Pack [I]"
	_equipment_button.text = "Equipment" if gamepad else "Equipment [G]"
	_wait_button.text = "Wait [RB]" if gamepad else "Wait [Q]"
	_map_button.text = "Map [View]" if gamepad else "Map [M]"


func _unhandled_input(event: InputEvent) -> void:
	if _fade.busy:
		return
	if _menu_visible():
		if _menu_back.is_valid() and event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			_menu_back.call()
		return
	if not _can_explore():
		return
	if _run != null and event.is_action_pressed(&"interact"):
		_interact()
	elif _run != null and event.is_action_pressed(&"open_party"):
		_show_party()
	elif _run != null and event.is_action_pressed(&"open_inventory"):
		_show_inventory()
	elif _run != null and event.is_action_pressed(&"open_equipment"):
		_show_equipment()
	elif _run != null and event.is_action_pressed(&"pause"):
		_show_pause()
	elif event.is_action_pressed(&"toggle_minimap"):
		_toggle_minimap()
	elif event.is_action_pressed(&"wait_turn"):
		_take_turn(Vector2i.ZERO)
	elif event is InputEventMouseButton and event.is_action_pressed(&"select_tile"):
		var direction: Vector2i = _dungeon.cell_at_screen_position(event.position) - _floor.player
		if absi(direction.x) + absi(direction.y) != 1:
			return
		_take_turn(direction)
	elif _single_step:
		for action: StringName in MOVEMENT:
			if not event.is_action_pressed(action):
				continue
			if event is InputEventJoypadMotion and not Input.is_action_just_pressed_by_event(action, event):
				continue
			_take_turn(MOVEMENT[action])
			get_viewport().set_input_as_handled()
			break
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _can_explore() -> bool:
	return _floor != null and _floor.encounter == null and _battle == null and not _fade.busy and not _menu_visible()


func _menu_visible() -> bool:
	return _menu != null and (_menu.visible or _equipment.visible)


func _start_floor() -> void:
	_floor = DungeonFloor.new(LAYOUT.rows)
	_party = [
		BattleRules.Fighter.new("Rook", 22, 6, 9),
		BattleRules.Fighter.new("Mira", 17, 5, 13),
	]
	_tonics = 2
	_dungeon.load_floor(_floor, _party)
	_audio.play_track(DungeonAudio.Track.DUNGEON)
	_refresh_exploration(MOVE_HINT)


func _take_turn(direction: Vector2i) -> void:
	if not _can_explore():
		return
	if _dungeon.is_moving():
		_queued_move = direction
		return
	var previous: Vector2i = _floor.player
	if not _floor.take_turn(direction):
		return

	if _floor.player != previous:
		_audio.play_cue(DungeonAudio.Cue.STEP)
	var moving: bool = _dungeon.refresh(true)
	var notice: String = MOVE_HINT
	if not _floor.skirmish.is_empty():
		var first: String = CampaignRun.CONTENT.factions[_floor.skirmish[0].faction].name
		var second: String = CampaignRun.CONTENT.factions[_floor.skirmish[1].faction].name
		notice = "%s and %s clash nearby." % [first, second]
	_refresh_exploration(notice)
	if _floor.encounter != null and not moving:
		_open_battle(_floor.encounter.kind)


func _on_movement_finished() -> void:
	if _floor == null or (_run != null and _run.seconds_left <= 0.0):
		return
	var direction: Vector2i = _queued_move
	var use_landmark: bool = _queued_use
	_queued_move = NO_SITE
	_queued_use = false
	if _floor.encounter != null:
		_open_battle(_floor.encounter.kind)
	elif use_landmark:
		_interact()
	elif direction != NO_SITE:
		_take_turn(direction)
	elif _held_action != &"" and Input.is_action_pressed(_held_action):
		_repeat = DungeonView.STEP_TIME
		_take_turn(MOVEMENT[_held_action])


func _open_battle(enemy_kind: DungeonFloor.EnemyKind) -> void:
	_audio.play_cue(DungeonAudio.Cue.ENCOUNTER)
	_fade.change_scene(_begin_battle.bind(enemy_kind), true)


func _begin_battle(enemy_kind: DungeonFloor.EnemyKind) -> void:
	var opponent: BattleRules.Fighter
	if _run != null:
		opponent = CampaignRun.CONTENT.make_fighter(_run.enemy_id(enemy_kind))
		var encounter: DungeonFloor.Enemy = _floor.encounter
		if encounter != null and encounter.skirmish_wounds > 0:
			opponent.hp = maxi(1, opponent.max_hp - encounter.skirmish_wounds * 4)
			opponent.entrance = "%s is already wounded from a faction skirmish." % opponent.name
	else:
		var enemy_name: String = CampaignRun.CONTENT.foes[CampaignRun.ENEMY_IDS[enemy_kind]].name
		match enemy_kind:
			DungeonFloor.EnemyKind.RAT:
				opponent = BattleRules.Fighter.new(enemy_name, 13, 4, 7)
			DungeonFloor.EnemyKind.GUARD:
				opponent = BattleRules.Fighter.new(enemy_name, 25, 7, 11)
	_battle = BATTLE_SCREEN.instantiate() as BattleView
	_battle.reduced_motion = _reduced_motion
	_hud.hide()
	_dungeon.hide()
	_interface.add_child(_battle)
	_battle.finished.connect(_close_battle)
	var supplies: int = _run.count("tonic") if _run != null else _tonics
	_audio.play_track(DungeonAudio.Track.BATTLE)
	var floor_number: int = _run.floor_number if _run != null else 1
	_battle.start(BattleRules.new(_party, opponent, supplies), enemy_kind, _run != null, _audio, _fade.busy, floor_number)
	if _run != null:
		_battle.show_floor_clock(_run.floor_time_text())


func _close_battle(outcome: BattleRules.Outcome) -> void:
	_battle.hold_controls()
	_fade.change_scene(_resolve_battle.bind(outcome))


func _resolve_battle(outcome: BattleRules.Outcome) -> void:
	_tonics = _battle.rules.potions
	var used_skill: bool = _battle.rules.used_skill
	_dismiss_battle()

	if outcome == BattleRules.Outcome.LOST:
		if _run == null:
			_start_floor()
		else:
			_reload_checkpoint()
		return

	if _run != null:
		_run.settle_battle(_floor.encounter, outcome, _tonics, used_skill)
	_audio.play_track(DungeonAudio.Track.DUNGEON)
	_floor.resolve_encounter(outcome == BattleRules.Outcome.WON)
	_dungeon.refresh()
	var notice := "Enemy defeated." if outcome == BattleRules.Outcome.WON else "You fled. The enemy is still nearby."
	_refresh_exploration(notice)


func _dismiss_battle() -> void:
	_battle.hide()
	_battle.queue_free()
	_battle = null
	_dungeon.show()
	_hud.show()


func _resume_scene_controls() -> void:
	if _battle != null:
		_battle.release_controls()


func _refresh_exploration(notice: String) -> void:
	var health := PackedStringArray()
	for member: BattleRules.Fighter in _party:
		health.append("%s %d/%d" % [member.name, member.hp, member.max_hp])
	_roster.text = "  ·  ".join(health)
	_turn.text = "Turn %d" % _floor.turn
	_remaining.text = "%d foes left" % _floor.enemies.size()
	_status.text = "Dungeon clear." if _floor.enemies.is_empty() else notice
	if _run != null:
		_title.text = "Floor %d safe room" % _run.floor_number if _run.at_camp() else "Floor %d" % _run.floor_number
		_turn.text = "Time left %s" % _run.floor_time_text()
		_remaining.text = "Clock paused" if _run.at_camp() else "%d wins" % _run.victories
		_announcer.text = "Recover at the beds or table. The workbench, envoy, and contract board are inside." if _run.at_camp() else "System · %s" % _run.announcement
		_landmark_hint.text = _exploration_hint() if notice == MOVE_HINT else notice
		_interact_button.disabled = _interaction_cell() == NO_SITE
	_minimap.refresh(_floor)


func _toggle_minimap() -> void:
	_map_panel.visible = not _map_panel.visible


func _show_slots(message: String = "Choose a save slot to enter Floor 1.") -> void:
	_run = null
	_floor = null
	_dungeon.hide()
	_hud.hide()
	_audio.play_track(DungeonAudio.Track.REFUGE)
	var choices: Array[Dictionary] = []
	for slot: int in range(1, CampaignSave.SLOT_COUNT + 1):
		var saved: Dictionary = CampaignSave.read(save_directory, slot)
		if CampaignSave.exists(save_directory, slot):
			if not saved.is_empty():
				var suffix: String = "Cleared" if saved.get("completed", false) else "Continue"
				choices.append(CampaignMenu.choice("Slot %d · Floor %s · %s" % [
					slot, str(saved.get("floor_number", 1)), suffix], _continue_slot.bind(slot)))
			choices.append(CampaignMenu.choice("Replace slot %d" % slot, _confirm_replace.bind(slot)))
		else:
			choices.append(CampaignMenu.choice("Slot %d · New run" % slot, _new_slot.bind(slot)))
	choices.append(CampaignMenu.choice("Audio settings", _show_audio_settings))
	choices.append(CampaignMenu.choice("Accessibility", _show_accessibility))
	choices.append(CampaignMenu.choice("Quit game", _quit))
	_present("Dungeon Crawler", message, choices, false)


func _confirm_replace(slot: int) -> void:
	_present("Replace slot %d?" % slot, "A new run replaces this slot’s checkpoint.", [
		CampaignMenu.choice("Keep checkpoint", _show_slots),
		CampaignMenu.choice("Start a new run", _new_slot.bind(slot)),
	], false, _show_slots)


func _new_slot(slot: int) -> void:
	_fade.change_scene(_begin_slot.bind(slot))


func _begin_slot(slot: int) -> void:
	_slot = slot
	_open_run(CampaignRun.new(randi()))
	_save(true)


func _continue_slot(slot: int) -> void:
	_fade.change_scene(_load_slot.bind(slot))


func _load_slot(slot: int) -> void:
	var loaded: CampaignRun = CampaignRun.restore(CampaignSave.read(save_directory, slot))
	if loaded == null:
		_show_slots("That checkpoint could not be read. Choose another slot or replace it.")
		return
	_slot = slot
	_checkpoint = loaded.snapshot()
	_open_run(loaded)
	if loaded.completed:
		_show_summary()


func _open_run(run: CampaignRun) -> void:
	_run = run
	_party = run.party
	_dungeon.show()
	_hud.show()
	_hide_menu()
	_show_active_floor()


func _show_active_floor(notice: String = MOVE_HINT) -> void:
	_floor = _run.active_floor()
	_queued_move = NO_SITE
	_queued_use = false
	_audio.play_track(DungeonAudio.Track.REFUGE if _run.at_camp() else DungeonAudio.Track.DUNGEON)
	var map_size := Vector2(maxi(84, _floor.size.x), maxi(48, _floor.size.y))
	_minimap.custom_minimum_size = map_size
	_map_panel.offset_left = -map_size.x - 26
	_map_panel.offset_bottom = _map_panel.offset_top + map_size.y + 10
	_broadcast.offset_right = _map_panel.offset_left - 6
	_dungeon.load_floor(_floor, _party, _run)
	_refresh_exploration(notice)


func _save(checkpoint_in_refuge: bool = false) -> String:
	_checkpoint = _run.snapshot()
	if checkpoint_in_refuge:
		_checkpoint["in_refuge"] = true
	var error: Error = CampaignSave.write(save_directory, _slot, _checkpoint)
	if error != OK:
		push_warning("Floor %d checkpoint write failed: %s" % [_run.floor_number, error_string(error)])
		return "Checkpoint held in memory. Disk save failed."
	return "Checkpoint saved."


func _prompt_reload(title: String, detail: String) -> void:
	_present(title, detail, [CampaignMenu.choice("Reload checkpoint", func() -> void: _fade.change_scene(_reload_checkpoint))], false)


func _reload_checkpoint() -> void:
	var restored: CampaignRun = CampaignRun.restore(_checkpoint)
	restored.event_occurred.emit("reload")
	_open_run(restored)
	_refresh_exploration("Checkpoint restored.")


func _interaction_cell() -> Vector2i:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var cell: Vector2i = _floor.player + offset
		if not _floor.visible.has(cell):
			continue
		var terrain: String = _floor.terrain_at(cell)
		if _run.at_camp():
			if terrain == "d" or terrain in DungeonFloor.FIXTURES:
				return cell
			continue
		if terrain in [">", "D", "T"] or _run.fallen_gear.has(cell):
			return cell
		if terrain in ["c", "R", "P", "!"] and not _run.used_sites.has(cell):
			return cell
		var enemy: DungeonFloor.Enemy = _floor.enemy_at(cell)
		if enemy != null and (not enemy.hostile or enemy.kind == DungeonFloor.EnemyKind.MIMIC):
			return cell
	return NO_SITE


func _interact() -> void:
	if not _can_explore() or _run == null:
		return
	if _dungeon.is_moving():
		_queued_use = true
		return
	var cell: Vector2i = _interaction_cell()
	if cell == NO_SITE:
		return
	var terrain: String = _floor.terrain_at(cell)
	if _run.at_camp():
		_use_refuge_fixture(terrain)
		return
	if terrain == "D":
		_audio.play_cue(DungeonAudio.Cue.DOOR)
		_fade.change_scene(_enter_refuge)
		return
	if _run.fallen_gear.has(cell):
		_run.loot_gear(cell)
		_refresh_exploration("Recovered equipment.")
	else:
		match terrain:
			"c":
				_run.collect_cache(cell)
				_refresh_exploration("Supplies added to the pack.")
			"R":
				if _run.recruit(cell):
					_refresh_exploration("Sable joined the party.")
			"P":
				_rescue_pet(cell)
			"!":
				_show_broadcast(cell)
				return
			"T":
				_show_outpost(cell)
				return
			"m":
				var mimic: DungeonFloor.Enemy = _floor.enemy_at(cell)
				if mimic != null:
					_floor.encounter = mimic
					_open_battle(mimic.kind)
				return
			">":
				_use_stairs(cell)
				return
			_:
				var envoy: DungeonFloor.Enemy = _floor.enemy_at(cell)
				if envoy != null and not envoy.hostile:
					_present("Barrow Sentinel", "The sentinel lowers their spear in recognition of the truce.",
						[CampaignMenu.choice("Continue", _hide_menu)])
	_dungeon.refresh()


func _show_broadcast(cell: Vector2i) -> void:
	var offer: Dictionary = _run.broadcast_offer(cell)
	if offer.is_empty():
		return
	var cost: String = "Trade %d seconds · %s" % [offer.seconds, offer.prize]
	if _run.seconds_left <= offer.seconds:
		cost = "Need more than %d seconds" % offer.seconds
	_present(offer.name, offer.line, [
		CampaignMenu.choice(cost, _accept_broadcast.bind(cell), _run.seconds_left <= offer.seconds),
		CampaignMenu.choice("Leave the terminal", _hide_menu),
	])


func _show_outpost(cell: Vector2i) -> void:
	var factions: PackedStringArray = _floor.outpost_factions(cell)
	for index: int in factions.size():
		factions[index] = CampaignRun.CONTENT.factions[factions[index]].name
	var detail: String = "No patrol holds this post."
	if factions.size() == 1:
		detail = "Held by the %s." % factions[0]
	elif factions.size() > 1:
		detail = "Contested by %s." % " and ".join(factions)
	if _run.survey_outpost(cell):
		detail += "\n\nReport ready. Return to the Watch envoy."
	_present(CampaignRun.OUTPOSTS[_run.floor_number - 1], detail, [CampaignMenu.choice("Continue", _hide_menu)])


func _accept_broadcast(cell: Vector2i) -> void:
	if _run.accept_broadcast(cell):
		_hide_menu()
		_dungeon.refresh()
		_refresh_exploration("Sponsor supplies added to the pack.")


func _rescue_pet(cell: Vector2i) -> void:
	var notice: String
	if _run.party.size() >= CampaignRun.PARTY_LIMIT:
		notice = "Cinder needs an open party slot."
	elif _run.count("bandage") == 0:
		notice = "Cinder needs a bandage."
	elif _run.rescue_pet(cell):
		notice = "Cinder joined the party."
	else:
		return
	_refresh_exploration(notice)


func _use_stairs(cell: Vector2i) -> void:
	if not _run.can_escape(cell):
		_refresh_exploration("Defeat %s first." % _run.boss_name())
		return
	var options: Dictionary = _run.advancement_choices()
	if options.is_empty():
		_finish_stairs(cell)
		return
	var choices: Array[Dictionary] = []
	for id: String in options:
		var option: Dictionary = options[id]
		var unlocked: bool = _run.advancement_unlocked(option)
		var description: String = option.summary if unlocked else option.unlock
		choices.append(CampaignMenu.choice("%s · %s" % [option.name, description],
			_finish_stairs.bind(cell, id), not unlocked))
	choices.append(CampaignMenu.choice("Return to dungeon", _hide_menu))
	if _run.floor_number == 2:
		_present("Choose Rook's race", "The choice is permanent. Select a race to descend to Floor 3.", choices)
	else:
		_present("Choose Rook's class", "The choice is permanent. Select a class to finish the run.", choices)


func _finish_stairs(cell: Vector2i, choice_id: String = "") -> void:
	if not _run.escape(cell, choice_id):
		return
	if _run.completed:
		_show_summary(_save())
	else:
		_show_arrival()


func _exploration_hint() -> String:
	var site: Vector2i = _interaction_cell()
	if not _run.at_camp() and _run.fallen_gear.has(site):
		return "Use to recover equipment"
	match _floor.terrain_at(site):
		"D": return "Use to enter the safe room"
		"d": return "Use to return to Floor %d" % _run.floor_number
		"B": return "Use to rest and treat wounds"
		"F": return "Use to eat and restore HP"
		"L": return "Use to save and open the pack"
		"G": return "Use to speak with the Watch envoy"
		"W": return "Use the workbench to craft supplies"
		"A": return "Use the board to review guild contracts"
		"c": return "Use to take supplies"
		"m":
			if _floor.enemy_at(site) != null:
				return "Use to take supplies"
		"!": return "Use to hear the sponsor's offer"
		"T": return "Use to inspect the faction banner"
		"R": return "Use to talk to Sable"
		"P": return "Use a bandage to rescue Cinder"
		">": return "Use to descend" if _run.boss_defeated else "%s holds the stairs" % _run.boss_name()
	if _run.at_camp():
		return "Beds · table · chest · workbench · envoy · contract board"
	var enemy: DungeonFloor.Enemy = _floor.enemy_at(site)
	if enemy != null and not enemy.hostile:
		return "Use to speak with the sentinel"
	return "Find the stairs" if _run.boss_defeated else "Find %s" % _run.boss_name()


func _use_refuge_fixture(terrain: String) -> void:
	match terrain:
		"d":
			_audio.play_cue(DungeonAudio.Cue.DOOR)
			_fade.change_scene(_leave_refuge)
		"B":
			_run.rest()
			_audio.play_cue(DungeonAudio.Cue.HEAL)
			_refresh_exploration(_save_refuge_action("Party rested."))
		"F":
			_run.eat()
			_audio.play_cue(DungeonAudio.Cue.HEAL)
			_refresh_exploration(_save_refuge_action("Party ate a warm meal."))
		"L":
			_refresh_exploration(_save())
			_show_inventory()
		"G":
			_show_envoy()
		"W":
			_show_crafting()
		"A":
			_show_sponsors()


func _enter_refuge() -> void:
	if _run.enter_refuge():
		_show_active_floor(_save())


func _leave_refuge() -> void:
	_run.leave_refuge()
	_show_active_floor("Returned to Floor %d." % _run.floor_number)


func _show_arrival() -> void:
	var notice: String = "Reached Floor %d. %s" % [_run.floor_number, _save()]
	_audio.play_cue(DungeonAudio.Cue.DOOR)
	_fade.change_scene(func() -> void:
		_hide_menu()
		_show_active_floor(notice)
	)


func _save_refuge_action(message: String) -> String:
	var saved: String = _save()
	return message if saved == "Checkpoint saved." else saved


func _show_inventory() -> void:
	var choices: Array[Dictionary] = []
	var materials := PackedStringArray()
	var labels: Array = _run.inventory.keys()
	labels.sort()
	for item: String in labels:
		var definition: Dictionary = CampaignRun.CONTENT.items[item]
		var label: String = "%s ×%d" % [definition.name, _run.count(item)]
		if definition.has("loot"):
			choices.append(CampaignMenu.choice("Open %s" % label, _open_box.bind(item), not _run.at_camp()))
		elif definition.get("material", false):
			materials.append(label)
		else:
			choices.append(CampaignMenu.choice(label, _choose_item_target.bind(item)))
	choices.append(CampaignMenu.choice("Equipment", _show_equipment.bind(_show_inventory)))
	choices.append(CampaignMenu.choice("Back", _hide_menu))
	var detail := "Open reward boxes in the safe room. Select supplies or equipment to choose a party member."
	if not materials.is_empty():
		detail += "\n\nMaterials · " + ", ".join(materials)
	_present("Party pack", detail, choices)


func _show_equipment(back: Callable = Callable()) -> void:
	_menu_back = back if back.is_valid() else _hide_menu
	_menu.hide()
	_equipment.present(_run, _reduced_motion)


func _equipment_changed(member: BattleRules.Fighter) -> void:
	_refresh_exploration(_save() if _run.at_camp() else "Updated %s's equipment." % member.name)


func _show_crafting(message: String = "") -> void:
	var choices: Array[Dictionary] = []
	for recipe_id: String in CampaignRun.CONTENT.recipes:
		var recipe: Dictionary = CampaignRun.CONTENT.recipes[recipe_id]
		var ingredients := PackedStringArray()
		for item: String in recipe.ingredients:
			ingredients.append("%s %d/%d" % [CampaignRun.CONTENT.items[item].name,
				_run.count(item), recipe.ingredients[item]])
		var label := "%s ×%d · %s" % [CampaignRun.CONTENT.items[recipe.item].name, recipe.count, " + ".join(ingredients)]
		choices.append(CampaignMenu.choice(label, _craft.bind(recipe_id), not _run.can_craft(recipe_id)))
	choices.append(CampaignMenu.choice("Back", _hide_menu))
	var detail := "Supply caches contain bitterroot. Ashfang rats drop pelts and Barrow sentinels drop iron."
	if not message.is_empty():
		detail = message + "\n\n" + detail
	_present("Workbench", detail, choices)


func _craft(recipe_id: String) -> void:
	if _run.craft(recipe_id):
		var recipe: Dictionary = CampaignRun.CONTENT.recipes[recipe_id]
		var message: String = _save_refuge_action("Crafted %s ×%d." % [CampaignRun.CONTENT.items[recipe.item].name, recipe.count])
		_refresh_exploration(message)
		_show_crafting(message)


func _show_envoy(message: String = "") -> void:
	var faction: Dictionary = CampaignRun.CONTENT.factions["watch"]
	var truce: bool = _run.has_truce("watch")
	var detail := "%s standing · %d\n" % [faction.name, _run.reputation["watch"]]
	if truce:
		detail += "Sentinels honor your truce. %s still holds the stairs." % _run.boss_name()
	else:
		detail += "The Watch respects those who hunt Ashfang beasts. A gift of bandages can earn a truce."
	if not message.is_empty():
		detail += "\n\n" + message
	var choices: Array[Dictionary] = [
		CampaignMenu.choice("Offer %d bandages · +%d standing" % [faction.gift_cost, faction.gift_standing],
			_offer_watch_gift, truce or _run.count(faction.gift) < faction.gift_cost),
	]
	match _run.watch_job:
		CampaignRun.WatchJob.AVAILABLE:
			if _run.floor_number == 1:
				detail += "\n\nScout the Latchknife banner near the first chamber. Bring back a report for a bronze box and +8 Watch standing."
				choices.append(CampaignMenu.choice("Accept scouting job", _accept_watch_job))
		CampaignRun.WatchJob.SCOUTING:
			detail += "\n\nScouting job · Inspect the Latchknife banner in the first chamber."
		CampaignRun.WatchJob.REPORT_READY:
			choices.append(CampaignMenu.choice("Turn in scouting report", _report_watch_job))
		CampaignRun.WatchJob.PAID:
			detail += "\n\nScouting report turned in."
	choices.append(CampaignMenu.choice("Back", _hide_menu))
	_present("Watch envoy", detail, choices)


func _offer_watch_gift() -> void:
	if _run.offer_faction_gift("watch"):
		var message: String = _save_refuge_action("The Watch accepts the gift.")
		_refresh_exploration(message)
		_show_envoy(message)


func _accept_watch_job() -> void:
	if _run.accept_watch_job():
		_show_envoy(_save_refuge_action("Scouting job accepted."))


func _report_watch_job() -> void:
	if _run.report_watch_job():
		_show_envoy(_save_refuge_action("Earned a bronze box and +8 Watch standing."))


func _show_sponsors(message: String = "") -> void:
	var lines := PackedStringArray(["Victories · %d" % _run.victories])
	if not message.is_empty():
		lines.append(message)
	var choices: Array[Dictionary] = []
	for sponsor: String in CampaignRun.CONTENT.sponsors:
		var definition: Dictionary = CampaignRun.CONTENT.sponsors[sponsor]
		var status: String = _run.sponsor_contracts.get(sponsor, "Available" if _run.victories >= definition.victories else "%d victories required" % definition.victories)
		lines.append("%s · %s\n%s" % [definition.name, status.capitalize(), definition.terms])
		choices.append(CampaignMenu.choice("Accept %s" % definition.name, _accept_sponsor.bind(sponsor), not _run.can_accept_sponsor(sponsor)))
	choices.append(CampaignMenu.choice("Back", _hide_menu))
	_present("Guild contracts", "\n\n".join(lines), choices)


func _accept_sponsor(sponsor: String) -> void:
	if _run.accept_sponsor(sponsor):
		var message: String = _save_refuge_action("Contract accepted.")
		_refresh_exploration(message)
		_show_sponsors(message)


func _open_box(item: String) -> void:
	if _run.open_box(item):
		_refresh_exploration(_save())
		_show_inventory()


func _choose_item_target(item: String) -> void:
	var choices: Array[Dictionary] = []
	var definition: Dictionary = CampaignRun.CONTENT.items[item]
	for member: BattleRules.Fighter in _party:
		var disabled: bool = member.hp == 0
		if item == "tonic":
			disabled = disabled or member.hp >= member.max_hp
		elif item == "bandage":
			disabled = disabled or member.injuries.is_empty()
		elif definition.has("slot"):
			disabled = disabled or member.is_pet
		choices.append(CampaignMenu.choice("%s · %d/%d HP" % [member.name, member.hp, member.max_hp],
			_apply_item.bind(member, item), disabled))
	choices.append(CampaignMenu.choice("Back to pack", _show_inventory))
	_present(definition.name, definition.description, choices, true, _show_inventory)


func _apply_item(member: BattleRules.Fighter, item: String) -> void:
	var definition: Dictionary = CampaignRun.CONTENT.items[item]
	var applied: bool = _run.equip(member, item) if definition.has("slot") else _run.heal(member, item)
	if applied:
		_refresh_exploration(_save() if _run.at_camp() else "Used %s." % definition.name)
		_show_inventory()


func _show_party() -> void:
	var lines := PackedStringArray()
	var choices: Array[Dictionary] = []
	for member: BattleRules.Fighter in _party:
		var state: String = "Fallen" if member.hp == 0 else "%d/%d HP" % [member.hp, member.max_hp]
		lines.append("%s · Lv %d · %s · %d/%d XP" % [member.name, member.level, state, member.xp, member.level * 15])
		if member.id == "rook":
			lines.append(_rook_identity())
		if member.hp > 0:
			var stats: String = "ATK %d · SPD %d" % [member.attack_power(), member.initiative()]
			if member.is_pet:
				lines.append("Pet · %s · %s" % [member.skill.name, stats])
			else:
				var weapon: String = CampaignRun.CONTENT.items.get(member.weapon, {}).get("name", "Bare hands")
				var armor: String = CampaignRun.CONTENT.items.get(member.armor, {}).get("name", "No armor")
				lines.append("%s · %s · %s" % [weapon, armor, stats])
			if member.stat_points > 0:
				choices.append(CampaignMenu.choice("Train %s · %d available" % [member.name, member.stat_points],
					_show_training.bind(member)))
		if not member.injuries.is_empty() and member.hp > 0:
			lines.append("Injuries · %s" % ", ".join(member.injuries.keys()))
	lines.append("Achievements · %s" % (", ".join(_run.achievements) if not _run.achievements.is_empty() else "None yet"))
	for faction: String in _run.reputation:
		var standing: String = "Truce" if _run.has_truce(faction) else "Hostile"
		lines.append("%s · %d · %s" % [CampaignRun.CONTENT.factions[faction].name, _run.reputation[faction], standing])
	choices.append(CampaignMenu.choice("Equipment", _show_equipment.bind(_show_party)))
	choices.append(CampaignMenu.choice("Back", _hide_menu))
	_present("Party", "\n".join(lines), choices)


func _show_training(member: BattleRules.Fighter) -> void:
	_present("Train %s" % member.name, "Available stat points · %d" % member.stat_points, [
		CampaignMenu.choice("Attack +1", _train.bind(member, "power")),
		CampaignMenu.choice("Speed +1", _train.bind(member, "speed")),
		CampaignMenu.choice("Max HP +4", _train.bind(member, "health")),
		CampaignMenu.choice("Back to party", _show_party),
	], true, _show_party)


func _train(member: BattleRules.Fighter, stat: String) -> void:
	if member.spend_stat_point(stat):
		_refresh_exploration(_save() if _run.at_camp() else "Training applied.")
		_show_party()


func _show_pause() -> void:
	_present("Paused", "Use the safe room to record progress. Returning to the slot menu ends this session.", [
		CampaignMenu.choice("Resume", _hide_menu),
		CampaignMenu.choice("Audio settings", _show_audio_settings.bind(true)),
		CampaignMenu.choice("Accessibility", _show_accessibility.bind(true)),
		CampaignMenu.choice("Return to save slots", _show_slots),
	])


func _show_audio_settings(from_pause: bool = false) -> void:
	var back: Callable = _show_pause if from_pause else _show_slots
	_present("Audio settings", "Select a volume to cycle the level. Changes apply immediately.", [
		CampaignMenu.choice("Music volume · %d%%" % _audio.music_volume, _change_volume.bind(true, from_pause)),
		CampaignMenu.choice("Effects volume · %d%%" % _audio.effects_volume, _change_volume.bind(false, from_pause)),
		CampaignMenu.choice("Back", back),
	], true, back)


func _change_volume(music: bool, from_pause: bool) -> void:
	_audio.cycle_volume(music)
	_show_audio_settings(from_pause)


func _load_accessibility() -> void:
	var settings := ConfigFile.new()
	if settings.load(accessibility_path) == OK:
		_reduced_motion = settings.get_value("accessibility", "reduced_motion", false) == true
		_single_step = settings.get_value("accessibility", "single_step", false) == true
	_apply_accessibility()


func _apply_accessibility() -> void:
	_dungeon.reduced_motion = _reduced_motion
	_fade.reduced_motion = _reduced_motion
	_held_action = &""


func _show_accessibility(from_pause: bool = false, notice: String = "") -> void:
	var back: Callable = _show_pause if from_pause else _show_slots
	var detail := "Reduced motion skips scene fades, camera slides, and combat motion effects. One tile per press turns off held movement."
	if not notice.is_empty():
		detail += "\n\n" + notice
	_present("Accessibility", detail, [
		CampaignMenu.choice("Reduced motion · %s" % ("On" if _reduced_motion else "Off"),
			_toggle_accessibility.bind(true, from_pause)),
		CampaignMenu.choice("One tile per press · %s" % ("On" if _single_step else "Off"),
			_toggle_accessibility.bind(false, from_pause)),
		CampaignMenu.choice("Back", back),
	], true, back)


func _toggle_accessibility(motion: bool, from_pause: bool) -> void:
	if motion:
		_reduced_motion = not _reduced_motion
	else:
		_single_step = not _single_step
	_apply_accessibility()
	var settings := ConfigFile.new()
	settings.set_value("accessibility", "reduced_motion", _reduced_motion)
	settings.set_value("accessibility", "single_step", _single_step)
	var error: Error = settings.save(accessibility_path)
	var notice: String = "" if error == OK else "Settings applied for this session. Could not save them."
	_show_accessibility(from_pause, notice)


func _show_summary(notice: String = "") -> void:
	var detail := "%s fell. Your party reached the stairs with %s remaining.\n\nWins · %d\nAchievements · %s" % [
		_run.boss_name(), _run.floor_time_text(), _run.victories, ", ".join(_run.achievements)]
	detail += "\nRook · %s · %s" % [_rook_identity(), _party[0].skill.name]
	detail += "\n\nSystem · " + _run.announcement
	if not notice.is_empty():
		detail += "\n\n" + notice
	_present("Floor %d cleared" % _run.floor_number, detail,
		[CampaignMenu.choice("Return to save slots", _show_slots)], false)


func _rook_identity() -> String:
	var race: String = CampaignRun.CONTENT.races.get(_run.race_id, {}).get("name", "Human")
	var role: String = CampaignRun.CONTENT.classes.get(_run.class_id, {}).get("name", "Unclassed")
	return "%s · %s" % [race, role]


func _present(title: String, detail: String, choices: Array[Dictionary], dismissible: bool = true,
	back: Callable = Callable()) -> void:
	_menu_back = back if back.is_valid() or not dismissible else _hide_menu
	_equipment.hide()
	_menu.present(title, detail, choices)


func _hide_menu() -> void:
	_menu.hide()
	_equipment.hide()
