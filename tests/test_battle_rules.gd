extends GutTest


func test_speed_guard_and_healing_share_the_same_turn_order() -> void:
	var rook := BattleRules.Fighter.new("Rook", 20, 5, 10)
	var mira := BattleRules.Fighter.new("Mira", 14, 4, 12)
	var rat := BattleRules.Fighter.new("Rat", 16, 7, 6)
	var battle := BattleRules.new([rook, mira], rat, 1)

	assert_eq(battle.turn_order().map(func(fighter: BattleRules.Fighter) -> String: return fighter.name), ["Mira", "Rook", "Rat"])
	assert_false(battle.use_command(BattleRules.Command.ITEM), "A full-health party cannot spend a tonic.")
	assert_true(battle.use_command(BattleRules.Command.ATTACK))
	assert_eq(rat.hp, 12)
	assert_true(battle.use_command(BattleRules.Command.DEFEND))
	assert_true(rook.guarding)
	assert_false(battle.use_command(BattleRules.Command.FLEE), "Party commands wait for the enemy to act.")
	battle.take_enemy_turn()
	assert_eq(rook.hp, 16)
	assert_false(rook.guarding)
	assert_same(battle.current_fighter(), mira)
	assert_true(battle.use_command(BattleRules.Command.ITEM))
	assert_eq(rook.hp, 20)
	assert_eq(battle.potions, 0)
	assert_same(battle.current_fighter(), rook)


func test_victory_and_escape_end_the_battle_immediately() -> void:
	var fighter := BattleRules.Fighter.new("Rook", 18, 6, 10)
	var rat := BattleRules.Fighter.new("Rat", 5, 8, 6)
	var battle := BattleRules.new([fighter], rat, 1)

	assert_true(battle.use_command(BattleRules.Command.ATTACK))
	assert_eq(battle.outcome, BattleRules.Outcome.WON)
	assert_false(battle.use_command(BattleRules.Command.ATTACK))
	battle.take_enemy_turn()
	assert_eq(fighter.hp, 18)

	battle = BattleRules.new([fighter], BattleRules.Fighter.new("Guard", 20, 8, 6), 1)
	assert_true(battle.use_command(BattleRules.Command.FLEE))
	assert_eq(battle.outcome, BattleRules.Outcome.FLED)
	assert_eq(battle.enemy.hp, 20)
	assert_eq(battle.potions, 1)


func test_fallen_fighters_are_skipped_until_the_enemy_wins() -> void:
	var rook := BattleRules.Fighter.new("Rook", 4, 5, 12)
	var mira := BattleRules.Fighter.new("Mira", 4, 4, 9)
	var guard := BattleRules.Fighter.new("Guard", 26, 7, 14)
	var battle := BattleRules.new([rook, mira], guard, 1)

	battle.take_enemy_turn()
	assert_eq(rook.hp, 0)
	assert_same(battle.current_fighter(), mira)
	assert_null(battle.potion_target())
	assert_true(battle.use_command(BattleRules.Command.ATTACK))
	battle.take_enemy_turn()
	assert_eq(mira.hp, 0)
	assert_eq(battle.outcome, BattleRules.Outcome.LOST)
	assert_null(battle.current_fighter())
