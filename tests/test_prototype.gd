extends GutTest

const GAME := preload("res://scenes/main.tscn")


func test_projected_tile_centers_resolve_to_the_original_grid() -> void:
	var game: DungeonGame = add_child_autofree(GAME.instantiate()) as DungeonGame
	var view: DungeonView = game.get_node("Dungeon")
	var tiles: TileMapLayer = view.get_node("Tiles")
	await wait_process_frames(1)

	var spawn := Vector2i(4, 4)
	for direction: Vector2i in DungeonFloor.CARDINALS:
		var cell: Vector2i = spawn + direction
		var projected: Vector2 = tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
		assert_eq(view.cell_at_screen_position(projected), cell)


func test_battle_buttons_take_the_party_back_to_a_changed_dungeon() -> void:
	var game: DungeonGame = add_child_autofree(GAME.instantiate()) as DungeonGame
	var wait_button: Button = game.get_node("%Wait")
	var hud: Control = game.get_node("Interface/HUD")
	var map_panel: PanelContainer = game.get_node("%MapPanel")
	var map_button: Button = game.get_node("%Map")
	var remaining: Label = game.get_node("%Remaining")

	map_button.pressed.emit()
	assert_false(map_panel.visible)
	map_button.pressed.emit()
	assert_true(map_panel.visible)

	for turn: int in 3:
		wait_button.pressed.emit()
	var battle: BattleView = game.get_node_or_null("Interface/Battle") as BattleView
	assert_not_null(battle, "The rat catches a party that waits three turns.")
	if battle == null:
		return
	assert_false(hud.visible)
	var flee: Button = battle.get_node("%Flee")
	var proceed: Button = battle.get_node("%Continue")
	flee.pressed.emit()
	assert_eq(battle.rules.outcome, BattleRules.Outcome.FLED)
	proceed.pressed.emit()
	await wait_process_frames(1)
	assert_true(hud.visible)
	assert_eq(remaining.text, "4 foes left")

	wait_button.pressed.emit()
	wait_button.pressed.emit()
	battle = game.get_node_or_null("Interface/Battle") as BattleView
	assert_not_null(battle, "The same rat can initiate a new battle.")
	if battle == null:
		return
	var attack: Button = battle.get_node("%Attack")
	var item: Button = battle.get_node("%Item")
	assert_false(attack.disabled)
	assert_true(item.disabled)
	attack.pressed.emit()
	attack.pressed.emit()
	assert_true(attack.disabled, "Inputs are locked during the enemy turn.")
	await wait_until(func() -> bool: return not attack.disabled, 1.5)
	assert_false(item.disabled)
	item.pressed.emit()
	assert_eq(battle.rules.potions, 1)
	attack.pressed.emit()
	assert_eq(battle.rules.outcome, BattleRules.Outcome.WON)
	proceed = battle.get_node("%Continue")
	proceed.pressed.emit()
	assert_true(hud.visible)
	assert_eq(remaining.text, "3 foes left")
	var roster: Label = game.get_node("%Roster")
	assert_string_contains(roster.text, "Rook 22/22")
