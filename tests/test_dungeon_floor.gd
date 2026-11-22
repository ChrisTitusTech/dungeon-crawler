extends GutTest


func test_valid_move_and_wait_each_advance_one_world_turn() -> void:
	var floor_state := DungeonFloor.new(PackedStringArray([
		"#######",
		"#S#..r#",
		"#.....#",
		"#######",
	]))
	var enemy: DungeonFloor.Enemy = floor_state.enemies[0]
	var spawn: Vector2i = enemy.cell

	assert_false(floor_state.take_turn(Vector2i.RIGHT))
	assert_false(floor_state.take_turn(Vector2i(1, 1)))
	assert_eq(floor_state.turn, 0)
	assert_eq(enemy.cell, spawn)

	assert_true(floor_state.take_turn(Vector2i.DOWN))
	assert_eq(floor_state.player, Vector2i(1, 2))
	assert_ne(enemy.cell, spawn)
	assert_eq(floor_state.turn, 1)
	assert_true(floor_state.take_turn())
	assert_eq(floor_state.player, Vector2i(1, 2))
	assert_eq(floor_state.turn, 2)


func test_walls_block_sight_and_explored_tiles_stay_mapped() -> void:
	var floor_state := DungeonFloor.new(PackedStringArray([
		"##################",
		"#S.t.............#",
		"#.+..............#",
		"##################",
	]))
	var entrance := Vector2i(1, 1)
	assert_false(floor_state.is_walkable(Vector2i(3, 1)), "A torch occupies a wall cell.")
	assert_true(floor_state.is_walkable(Vector2i(2, 2)), "Doorway thresholds are passable.")
	assert_true(floor_state.visible.has(Vector2i(3, 1)), "The blocking wall itself is visible.")
	assert_false(floor_state.visible.has(Vector2i(4, 1)), "The tile behind the wall is hidden.")
	floor_state.take_turn(Vector2i.DOWN)
	for step: int in 8:
		floor_state.take_turn(Vector2i.RIGHT)
	assert_false(floor_state.visible.has(entrance))
	assert_true(floor_state.explored.has(entrance))


func test_flee_keeps_the_enemy_and_victory_removes_it() -> void:
	var floor_state := DungeonFloor.new(PackedStringArray([
		"########",
		"#Sr....#",
		"#......#",
		"########",
	]))
	var enemy: DungeonFloor.Enemy = floor_state.enemies[0]

	assert_true(floor_state.take_turn(Vector2i.RIGHT))
	assert_same(floor_state.encounter, enemy)
	assert_eq(floor_state.player, Vector2i(1, 1))
	assert_false(floor_state.take_turn(), "Battle freezes exploration turns.")

	floor_state.resolve_encounter(false)
	assert_true(floor_state.take_turn())
	assert_eq(enemy.cell, Vector2i(2, 1))
	assert_null(floor_state.encounter, "The party has a turn to move away.")
	assert_true(floor_state.take_turn())
	assert_same(floor_state.encounter, enemy, "The enemy can chase into the party.")

	floor_state.resolve_encounter(true)
	assert_null(floor_state.encounter)
	assert_true(floor_state.enemies.is_empty())


func test_diagonal_wall_corner_is_visible_but_blocks_the_floor_beyond_it() -> void:
	var floor_state := DungeonFloor.new(PackedStringArray([
		"#####",
		"#S#.#",
		"###.#",
		"#...#",
		"#####",
	]))

	assert_true(floor_state.visible.has(Vector2i(2, 2)), "The solid wall joint is visible.")
	assert_false(floor_state.visible.has(Vector2i(3, 3)), "The corner still blocks sight into the next room.")


func test_neutral_enemy_yields_the_corridor_without_initiating_battle() -> void:
	var floor_state := DungeonFloor.new(PackedStringArray(["#######", "#Sg...#", "#######"]))
	var sentinel: DungeonFloor.Enemy = floor_state.enemies[0]
	sentinel.hostile = false
	assert_true(floor_state.take_turn(Vector2i.RIGHT))
	assert_eq(floor_state.player, Vector2i(2, 1))
	assert_eq(sentinel.cell, Vector2i(1, 1))
	assert_true(floor_state.take_turn(Vector2i.RIGHT))
	assert_true(floor_state.take_turn())
	assert_eq(sentinel.cell, Vector2i(2, 1))
	assert_null(floor_state.encounter)
