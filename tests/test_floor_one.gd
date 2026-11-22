extends GutTest

const GAME := preload("res://scenes/main.tscn")

var _directory: String


func before_each() -> void:
	_directory = "user://floor-one-test-%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(_directory), OK)


func after_each() -> void:
	for file: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(file))
	DirAccess.remove_absolute(_directory)


func test_seed_repeats_and_rooms_stay_connected() -> void:
	var generator := FloorOneGenerator.new()
	var layout: DungeonLayout = generator.generate(73)
	assert_eq(generator.generate(73).rows, layout.rows)
	assert_ne(generator.generate(74).rows, layout.rows)

	var enemy_counts := {}
	for seed: int in range(16):
		layout = generator.generate(seed)
		var floor_state := DungeonFloor.new(layout.rows, layout.safe_room)
		var visited := _reachable(floor_state)
		var walkable: int = 0
		var markers := {"S": 0, "D": 0, "R": 0, ">": 0, "b": 0}
		for y: int in floor_state.size.y:
			for x: int in floor_state.size.x:
				var cell := Vector2i(x, y)
				if floor_state.is_walkable(cell):
					walkable += 1
				var glyph: String = floor_state.terrain_at(cell)
				if markers.has(glyph):
					markers[glyph] += 1
		assert_eq(visited.size(), walkable, "Seed %d has a connected floor." % seed)
		assert_eq(markers, {"S": 1, "D": 1, "R": 1, ">": 1, "b": 1})
		assert_eq(floor_state.size, Vector2i(118, 84))
		assert_eq(floor_state.terrain_at(layout.refuge_door), "D")
		enemy_counts[floor_state.enemies.size()] = true
	assert_gt(enemy_counts.size(), 1, "Seeds vary the number of encounters.")


func test_show_rewards_gear_and_camp_treatment() -> void:
	var run := CampaignRun.new(42)
	var recruit_cell: Vector2i = _find(run.floor, "R")
	assert_true(run.recruit(recruit_cell))
	assert_false(run.recruit(recruit_cell))
	assert_eq(run.party.size(), 3)
	assert_true(run.achievements.has("One More Seat"))
	assert_true(run.enter_refuge())
	assert_true(run.open_box("bronze_box"))
	assert_true(run.equip(run.party[0], "iron_blade"))
	assert_eq(run.party[0].attack_power(), 10)
	run.party[0].earn_experience(15)
	assert_eq(run.party[0].level, 2)
	assert_true(run.party[0].spend_stat_point("speed"))
	assert_eq(run.party[0].initiative(), 10)
	run.party[0].hp -= 3
	run.party[0].injuries["arms"] = true
	assert_eq(run.party[0].attack_power(), 9)
	assert_true(run.heal(run.party[0], "bandage"))
	assert_eq(run.party[0].attack_power(), 11)
	run.party[0].injuries["legs"] = true
	run.party[1].hp = 0
	run.rest()
	assert_eq(run.party[0].hp, run.party[0].max_hp)
	assert_true(run.party[0].injuries.is_empty())
	assert_eq(run.party[1].hp, 0)


func test_skill_is_spent_and_injuries_affect_combat() -> void:
	var mira: BattleRules.Fighter = CampaignRun.CONTENT.make_fighter("mira")
	var guard: BattleRules.Fighter = CampaignRun.CONTENT.make_fighter("guard")
	var battle := BattleRules.new([mira], guard, 1)
	assert_true(battle.use_command(BattleRules.Command.SKILL))
	assert_eq(guard.hp, guard.max_hp - mira.power - 3)
	assert_true(guard.injuries.has("legs"))
	assert_eq(guard.initiative(), guard.speed - 3)
	battle.take_enemy_turn()
	assert_false(battle.use_command(BattleRules.Command.SKILL))
	assert_true(battle.use_command(BattleRules.Command.ATTACK))
	battle.take_enemy_turn()
	assert_true(mira.injuries.has("arms"))
	assert_eq(mira.attack_power(), mira.power - 2)


func test_checkpoint_overwrite_and_slot_isolation() -> void:
	var run := CampaignRun.new(83)
	assert_true(run.enter_refuge())
	assert_eq(CampaignSave.write(_directory, 1, run.snapshot()), OK)
	var foe: DungeonFloor.Enemy = run.floor.enemies[0]
	run.settle_battle(foe, BattleRules.Outcome.WON, 2)
	run.floor.encounter = foe
	run.floor.resolve_encounter(true)
	run.party[0].injuries["torso"] = true
	run.turns_left -= 17
	assert_eq(CampaignSave.write(_directory, 1, run.snapshot()), OK)
	assert_eq(CampaignSave.write(_directory, 2, CampaignRun.new(84).snapshot()), OK)

	var loaded: CampaignRun = CampaignRun.restore(CampaignSave.read(_directory, 1))
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.seed, 83)
	assert_eq(loaded.turns_left, CampaignRun.TURN_BUDGET - 17)
	assert_true(loaded.at_camp())
	assert_true(loaded.party[0].injuries.has("torso"))
	assert_eq(loaded.count("bronze_box"), 1)
	assert_true(loaded.achievements.has("First Blood"))
	assert_false(loaded.floor.enemies.any(func(enemy: DungeonFloor.Enemy) -> bool: return enemy.home == foe.home))
	assert_eq(CampaignSave.read(_directory, 2).seed, 84)
	var older: Dictionary = CampaignRun.new(83, 1).snapshot()
	for field: String in ["layout_version", "in_refuge", "refuge_player"]:
		older.erase(field)
	older.erase("announcement_event")
	older["announcement"] = "Archived boss victory line."
	older["boss_defeated"] = true
	var renamed: CampaignRun = CampaignRun.restore(older)
	assert_not_null(renamed)
	if renamed != null:
		assert_string_contains(renamed.announcement, "Sir Aldren")
		assert_true(renamed.at_camp())
		assert_eq(renamed.floor.size, Vector2i(77, 47))
		assert_eq(renamed.floor.player, renamed.refuge_door)
	var invalid: Dictionary = loaded.snapshot()
	invalid["inventory"] = {"unknown": 1}
	assert_null(CampaignRun.restore(invalid))


func test_collapse_reloads_the_actual_camp_checkpoint() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	var menu: CampaignMenu = game.get_node("Interface/CampaignMenu")
	var choices: VBoxContainer = menu.get_node("%Choices")
	var heading: Label = menu.get_node("%Heading")
	var slot: Button = choices.get_child(0)
	slot.pressed.emit()
	assert_false(menu.visible, "A new run starts at the dungeon-side door.")
	assert_false(CampaignSave.read(_directory, 1).is_empty())
	game._run.turns_left = 1
	game._take_turn(Vector2i.ZERO)
	assert_eq(heading.text, "The floor collapsed")
	var reload_button: Button = choices.get_child(0)
	reload_button.pressed.emit()
	assert_true(game._run.at_camp())
	assert_eq(game._run.turns_left, CampaignRun.TURN_BUDGET)
	assert_false(menu.visible)
	game._interact()
	assert_false(game._run.at_camp())
	game._take_turn(Vector2i.ZERO)
	game._interact()
	assert_true(game._run.at_camp())
	assert_eq(CampaignSave.read(_directory, 1).turns_left, CampaignRun.TURN_BUDGET - 1)
	await wait_process_frames(1)


func test_refuge_door_round_trip_and_furnishings() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	game._new_slot(1)
	var dungeon: DungeonFloor = game._floor
	var original_position: Vector2i = dungeon.player
	var explored: Dictionary = dungeon.explored.duplicate()
	var enemy: DungeonFloor.Enemy = dungeon.enemies[0]
	var enemy_cell: Vector2i = enemy.cell
	var member: BattleRules.Fighter = game._party[0]
	member.hp = 1
	member.injuries["arms"] = true
	game._party[1].hp = 0

	game._interact()
	assert_true(game._run.at_camp())
	assert_same(game._floor, game._run.refuge)
	assert_false(game._menu.visible)
	_walk_straight(game, Vector2i(11, 3))
	game._interact()
	assert_eq(member.hp, 1 + ceili(member.max_hp * 0.5))
	assert_true(member.injuries.has("arms"), "A meal restores health.")
	_walk_straight(game, Vector2i(5, 3))
	game._interact()
	assert_eq(member.hp, member.max_hp)
	assert_true(member.injuries.is_empty(), "Rest treats wounds.")
	assert_eq(game._party[1].hp, 0, "Recovery never revives fallen members.")
	assert_eq(CampaignSave.read(_directory, 1).refuge_player, Vector2i(5, 3))

	_walk_straight(game, Vector2i(8, 7))
	game._interact()
	assert_same(game._floor, dungeon)
	assert_eq(dungeon.player, original_position)
	assert_eq(dungeon.explored, explored)
	assert_eq(enemy.cell, enemy_cell)
	assert_eq(dungeon.turn, 0)
	assert_eq(game._run.turns_left, CampaignRun.TURN_BUDGET)
	await wait_process_frames(1)


func test_party_wipe_restores_saved_health_and_supplies() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	game._new_slot(1)
	game._hide_menu()
	for member: BattleRules.Fighter in game._party:
		member.hp = 1
	game._floor.encounter = game._floor.enemies[0]
	game._open_battle(game._floor.encounter.kind)
	var battle: BattleView = game._battle
	var defend: Button = battle.get_node("%Defend")
	var delay: Timer = battle.get_node("EnemyDelay")
	for action: int in 10:
		if battle.rules.outcome == BattleRules.Outcome.LOST:
			break
		if battle.rules.current_fighter() == battle.rules.enemy:
			delay.stop()
			delay.timeout.emit()
		else:
			defend.pressed.emit()
	assert_eq(battle.rules.outcome, BattleRules.Outcome.LOST)
	var reload_button: Button = battle.get_node("%Continue")
	assert_eq(reload_button.text, "Reload checkpoint")
	reload_button.pressed.emit()
	assert_true(game._run.at_camp())
	assert_eq(game._party[0].hp, game._party[0].max_hp)
	assert_eq(game._run.count("tonic"), 4)
	await wait_process_frames(1)


func test_exit_requires_a_boss_victory_and_the_stairs() -> void:
	var run := CampaignRun.new(4)
	var stairs: Vector2i = _find(run.floor, ">")
	assert_false(run.escape(stairs))
	var boss_cell: Vector2i = _find(run.floor, "b")
	run.settle_battle(run.floor.enemy_at(boss_cell), BattleRules.Outcome.WON, 2)
	assert_true(run.boss_defeated)
	assert_false(run.escape(stairs))
	run.floor.player = stairs
	assert_true(run.escape(stairs))
	assert_true(run.completed)
	assert_true(run.achievements.has("Still Standing"))


func _find(floor_state: DungeonFloor, marker: String) -> Vector2i:
	for y: int in floor_state.size.y:
		for x: int in floor_state.size.x:
			if floor_state.terrain_at(Vector2i(x, y)) == marker:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _walk_straight(game: DungeonGame, target: Vector2i) -> void:
	for step: int in absi(target.x - game._floor.player.x):
		game._take_turn(Vector2i(signi(target.x - game._floor.player.x), 0))
	for step: int in absi(target.y - game._floor.player.y):
		game._take_turn(Vector2i(0, signi(target.y - game._floor.player.y)))
	assert_eq(game._floor.player, target)


func _reachable(floor_state: DungeonFloor) -> Dictionary:
	var pending: Array[Vector2i] = [floor_state.player]
	var visited := {floor_state.player: true}
	var index: int = 0
	while index < pending.size():
		var cell: Vector2i = pending[index]
		index += 1
		for direction: Vector2i in DungeonFloor.CARDINALS:
			var next: Vector2i = cell + direction
			if floor_state.is_walkable(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	return visited
