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
	run.seconds_left -= 17.5
	assert_eq(CampaignSave.write(_directory, 1, run.snapshot()), OK)
	assert_eq(CampaignSave.write(_directory, 2, CampaignRun.new(84).snapshot()), OK)

	var loaded: CampaignRun = CampaignRun.restore(CampaignSave.read(_directory, 1))
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.seed, 83)
	assert_eq(loaded.seconds_left, 1782.5)
	assert_true(loaded.at_camp())
	assert_true(loaded.party[0].injuries.has("torso"))
	assert_eq(loaded.count("bronze_box"), 1)
	assert_true(loaded.achievements.has("First Blood"))
	assert_false(loaded.floor.enemies.any(func(enemy: DungeonFloor.Enemy) -> bool: return enemy.home == foe.home))
	assert_eq(CampaignSave.read(_directory, 2).seed, 84)
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
	assert_eq(game._turn.text, "Time left 30:00")
	game._take_turn(Vector2i.ZERO)
	assert_eq(game._run.seconds_left, 1800.0, "Waiting a turn does not spend time by itself.")
	game._update_floor_clock(1500.5)
	assert_eq(game._turn.text, "Time left 05:00")
	assert_string_contains(game._announcer.text, "Five minutes")
	game._show_pause()
	game._update_floor_clock(100.0)
	assert_eq(game._run.seconds_left, 299.5)
	game._hide_menu()
	game._update_floor_clock(299.5)
	assert_eq(heading.text, "The floor collapsed")
	var reload_button: Button = choices.get_child(0)
	reload_button.pressed.emit()
	assert_true(game._run.at_camp())
	assert_eq(game._run.seconds_left, 1800.0)
	assert_false(menu.visible)
	game._update_floor_clock(60.0)
	assert_eq(game._run.seconds_left, 1800.0, "The safe room pauses the countdown.")
	game._interact()
	assert_false(game._run.at_camp())
	game._update_floor_clock(1.5)
	game._interact()
	assert_true(game._run.at_camp())
	assert_eq(CampaignSave.read(_directory, 1).seconds_left, 1798.5)
	await wait_process_frames(1)


func test_floor_can_collapse_during_battle() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	game._new_slot(1)
	game._floor.encounter = game._floor.enemies[0]
	game._open_battle(game._floor.encounter.kind)
	game._update_floor_clock(1770.0)
	var clock: Label = game._battle.get_node("%FloorClock")
	assert_eq(clock.text, "Time left 00:30")
	game._update_floor_clock(30.0)
	assert_null(game._battle)
	var heading: Label = game._menu.get_node("%Heading")
	assert_eq(heading.text, "The floor collapsed")
	var choices: VBoxContainer = game._menu.get_node("%Choices")
	var reload_button: Button = choices.get_child(0)
	reload_button.pressed.emit()
	assert_true(game._run.at_camp())
	assert_null(game._run.floor.encounter)
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
	assert_eq(game._run.seconds_left, 1800.0)
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
	assert_eq(run.floor_number, 2)
	assert_false(run.completed)
	assert_true(run.achievements.has("Still Standing"))


func test_later_floors_have_connected_routes_and_their_own_bosses() -> void:
	for number: int in [2, 3]:
		var run := CampaignRun.new(42, number)
		var floor_state: DungeonFloor = run.floor
		var visited: Dictionary = _reachable(floor_state)
		assert_true(visited.has(run.refuge_door))
		assert_eq(floor_state.terrain_at(run.refuge_door), "D")
		assert_true(visited.has(_find(floor_state, ">")))
		for enemy: DungeonFloor.Enemy in floor_state.enemies:
			assert_true(visited.has(enemy.cell))
		assert_eq(floor_state.enemy_at(_find(floor_state, "b")).kind, DungeonFloor.EnemyKind.BOSS)


func test_stairs_save_the_next_floor_and_the_final_clear() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	game._new_slot(1)
	var member: BattleRules.Fighter = game._party[0]
	member.hp = 12
	member.injuries["arms"] = true
	game._run.reputation["watch"] = 30
	game._run.sponsor_contracts["lanternwrights"] = "active"
	game._run.add_item("iron_blade")
	assert_true(game._run.equip(member, "iron_blade"))
	var heading: Label = game._menu.get_node("%Heading")
	var choices: VBoxContainer = game._menu.get_node("%Choices")
	var boss_names: Array[String] = ["Sir Aldren", "Marshal Ysra", "Lord Veyr"]
	for number: int in range(1, 4):
		var run: CampaignRun = game._run
		var stairs: Vector2i = _find(run.floor, ">")
		var boss: DungeonFloor.Enemy = run.floor.enemy_at(_find(run.floor, "b"))
		run.seconds_left = 23.5
		run.floor.encounter = boss
		game._open_battle(boss.kind)
		assert_eq(game._battle.rules.enemy.name, boss_names[number - 1])
		game._close_battle(BattleRules.Outcome.WON)
		run.floor.restore_checkpoint(stairs, 5, run.snapshot().enemies, [])
		run.used_sites[Vector2i.ZERO] = true
		run.fallen_gear[Vector2i.ZERO] = ["iron_blade"]
		var party: Array = run.snapshot().party
		var pack: Dictionary = run.inventory.duplicate()
		var standing: Dictionary = run.reputation.duplicate()
		game._interact()
		var saved: Dictionary = CampaignSave.read(_directory, 1)
		if number < CampaignRun.LAST_FLOOR:
			assert_eq(saved.floor_number, number + 1)
			assert_true(saved.in_refuge)
			assert_false(saved.boss_defeated)
			assert_eq(saved.turn, 0)
			assert_eq(saved.seconds_left, 1800.0)
			assert_eq(saved.party, party)
			assert_eq(saved.inventory, pack)
			assert_eq(saved.reputation, standing)
			assert_eq(saved.sponsor_contracts["lanternwrights"], "fulfilled")
			assert_true(saved.used_sites.is_empty())
			assert_true(saved.fallen_gear.is_empty())
			game._load_slot(1)
			assert_eq(game._run.floor_number, number + 1)
			assert_true(game._run.at_camp())
			game._interact()
			assert_same(game._floor, game._run.floor)
			assert_eq(game._title.text, "Floor %d" % (number + 1))
			game._update_floor_clock(1800.0)
			var reload_button: Button = choices.get_child(0)
			reload_button.pressed.emit()
			assert_eq(game._run.floor_number, number + 1)
			assert_eq(game._run.seconds_left, 1800.0)
			game._interact()
		else:
			assert_true(saved.completed)
			assert_eq(saved.floor_number, 3)
			game._load_slot(1)
			assert_eq(heading.text, "Floor 3 cleared")
			assert_eq(game._run.seconds_left, 23.5)
			assert_has(game._run.achievements, "Past the Regent")
	await wait_process_frames(1)


func test_truce_changes_enemy_behaviour_and_survives_a_checkpoint() -> void:
	var run := CampaignRun.new(83)
	var rat: DungeonFloor.Enemy
	var sentinel: DungeonFloor.Enemy
	var boss: DungeonFloor.Enemy
	for enemy: DungeonFloor.Enemy in run.floor.enemies:
		match enemy.kind:
			DungeonFloor.EnemyKind.RAT: rat = enemy
			DungeonFloor.EnemyKind.GUARD: sentinel = enemy
			DungeonFloor.EnemyKind.BOSS: boss = enemy
	assert_not_null(sentinel)
	if sentinel == null:
		return
	assert_true(sentinel.hostile)
	assert_false(run.offer_faction_gift("watch"), "The envoy is in the safe room.")
	run.settle_battle(rat, BattleRules.Outcome.WON, run.count("tonic"))
	assert_eq(run.reputation["watch"], -14)
	assert_eq(run.reputation["ashfang"], -73)
	assert_eq(run.count("ashfang_pelt"), 1)
	assert_true(run.enter_refuge())
	assert_true(run.offer_faction_gift("watch"))
	assert_eq(run.count("bandage"), 0)
	assert_false(sentinel.hostile)
	assert_true(boss.hostile)
	assert_false(run.offer_faction_gift("watch"))

	var restored: CampaignRun = CampaignRun.restore(run.snapshot())
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.reputation, run.reputation)
		assert_false(restored.floor.enemy_at(sentinel.cell).hostile)


func test_recipes_consume_materials_and_produce_usable_equipment() -> void:
	var run := CampaignRun.new(83)
	run.add_item("iron_blade")
	run.add_item("iron_scrap")
	assert_false(run.can_craft("temper_blade"))
	assert_true(run.enter_refuge())
	assert_false(run.craft("temper_blade"))
	assert_eq(run.count("iron_blade"), 1, "An incomplete recipe spends nothing.")
	run.add_item("iron_scrap")
	assert_true(run.craft("temper_blade"))
	assert_eq(run.count("iron_scrap"), 0)
	assert_eq(run.count("iron_blade"), 0)
	assert_true(run.equip(run.party[0], "tempered_blade"))
	assert_eq(run.party[0].attack_power(), 12)


func test_refuge_workbench_and_envoy_can_be_used_from_the_map() -> void:
	var game: DungeonGame = GAME.instantiate() as DungeonGame
	game.save_directory = _directory
	add_child_autofree(game)
	game._new_slot(1)
	game._interact()
	game._run.add_item("ashfang_pelt", 2)
	_walk_straight(game, Vector2i(4, 6))
	game._interact()
	var heading: Label = game._menu.get_node("%Heading")
	var choices: VBoxContainer = game._menu.get_node("%Choices")
	assert_eq(heading.text, "Workbench")
	var craft_button: Button = choices.get_child(0)
	assert_false(craft_button.disabled)
	craft_button.pressed.emit()
	assert_eq(game._run.count("bandage"), 4)
	game._hide_menu()

	_walk_straight(game, Vector2i(4, 5))
	_walk_straight(game, Vector2i(13, 5))
	_walk_straight(game, Vector2i(13, 4))
	game._interact()
	assert_eq(heading.text, "Watch envoy")
	var offer: Button = choices.get_child(0)
	offer.pressed.emit()
	assert_true(game._run.has_truce("watch"))
	assert_eq(CampaignSave.read(_directory, 1).reputation["watch"], 0)
	game._hide_menu()

	_walk_straight(game, Vector2i(9, 4))
	_walk_straight(game, Vector2i(9, 2))
	game._run.victories = 2
	game._interact()
	assert_eq(heading.text, "Guild contracts")
	var contract: Button = choices.get_child(0)
	assert_false(contract.disabled)
	var locked_contract: Button = choices.get_child(1)
	assert_true(locked_contract.disabled)
	contract.pressed.emit()
	assert_eq(CampaignSave.read(_directory, 1).sponsor_contracts["lanternwrights"], "active")
	await wait_process_frames(1)


func test_guild_contract_rewards_require_their_conditions() -> void:
	var run := CampaignRun.new(83)
	var rat: DungeonFloor.Enemy = run.floor.enemy_at(_find(run.floor, "r"))
	assert_eq(rat.kind, DungeonFloor.EnemyKind.RAT)
	assert_false(run.can_accept_sponsor("lanternwrights"))
	run.victories = 5
	assert_false(run.accept_sponsor("lanternwrights"))
	assert_true(run.enter_refuge())
	assert_true(run.accept_sponsor("lanternwrights"))
	assert_true(run.accept_sponsor("hammer_crown"))
	run.leave_refuge()

	run.settle_battle(rat, BattleRules.Outcome.FLED, 4, true)
	assert_eq(run.victories, 5)
	assert_eq(run.sponsor_contracts["hammer_crown"], "active")
	run.settle_battle(rat, BattleRules.Outcome.WON, 3, false)
	assert_eq(run.victories, 6)
	assert_eq(run.sponsor_contracts["lanternwrights"], "active")
	assert_eq(run.sponsor_contracts["hammer_crown"], "active")
	var tonics: int = run.count("tonic")
	run.settle_battle(rat, BattleRules.Outcome.WON, tonics, true)
	assert_eq(run.victories, 7)
	assert_eq(run.sponsor_contracts["lanternwrights"], "fulfilled")
	assert_eq(run.sponsor_contracts["hammer_crown"], "fulfilled")
	assert_eq(run.count("tonic"), tonics + 4)
	assert_eq(run.count("hide_coat"), 1)
	run.settle_battle(rat, BattleRules.Outcome.WON, run.count("tonic"), true)
	assert_eq(run.count("hide_coat"), 1, "A fulfilled contract pays once.")
	assert_true(run.enter_refuge())
	var restored: CampaignRun = CampaignRun.restore(run.snapshot())
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.victories, run.victories)
		assert_eq(restored.sponsor_contracts, run.sponsor_contracts)


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
