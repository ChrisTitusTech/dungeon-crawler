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


func test_cleric_heals_the_most_injured_standing_ally() -> void:
	var cleric := BattleRules.Fighter.new("Cleric", 24, 5, 14)
	cleric.skill = CampaignRun.CONTENT.skills["sanctuary_light"]
	var ally := BattleRules.Fighter.new("Ally", 28, 6, 10)
	var fallen := BattleRules.Fighter.new("Fallen", 30, 9, 12)
	fallen.hp = 0
	var foe := BattleRules.Fighter.new("Rat", 24, 5, 4)
	var battle := BattleRules.new([cleric, ally, fallen], foe, 0)
	assert_false(battle.use_command(BattleRules.Command.SKILL), "A heal needs a living, injured target.")
	ally.hp = 4
	assert_true(battle.use_command(BattleRules.Command.SKILL))
	assert_eq(ally.hp, 24)
	assert_eq(foe.hp, foe.max_hp)
	assert_eq(fallen.hp, 0)
	assert_eq(battle.potions, 0)
	assert_eq(battle.skill_cooldown_remaining(cleric), 10)


func test_skills_recharge_independently_after_ten_completed_turns() -> void:
	var mira: BattleRules.Fighter = CampaignRun.CONTENT.make_fighter("mira")
	var sable: BattleRules.Fighter = CampaignRun.CONTENT.make_fighter("sable")
	var foe := BattleRules.Fighter.new("Guard", 100, 1, 4)
	var battle := BattleRules.new([mira, sable], foe, 0)

	assert_true(battle.use_command(BattleRules.Command.SKILL))
	assert_eq(battle.skill_cooldown_remaining(mira), 10)
	assert_true(battle.use_command(BattleRules.Command.SKILL), "Sable can use her own skill while Mira's recharges.")
	assert_eq(battle.skill_cooldown_remaining(mira), 9)
	assert_eq(battle.skill_cooldown_remaining(sable), 10)
	battle.take_enemy_turn()
	assert_false(battle.use_command(BattleRules.Command.SKILL))
	assert_false(battle.use_command(BattleRules.Command.ITEM))
	assert_eq(battle.skill_cooldown_remaining(mira), 8, "Rejected commands do not advance combat.")

	for remaining: int in range(7, -1, -1):
		if battle.current_fighter() == foe:
			battle.take_enemy_turn()
		else:
			assert_true(battle.use_command(BattleRules.Command.DEFEND))
		assert_eq(battle.skill_cooldown_remaining(mira), remaining)
		assert_eq(battle.skill_cooldown_remaining(sable), remaining + 1)
		assert_eq(battle.can_use_skill(mira), remaining == 0)

	battle.take_enemy_turn()
	assert_same(battle.current_fighter(), mira)
	assert_true(battle.use_command(BattleRules.Command.SKILL), "Mira can use Hamstring again in the same fight.")
	assert_eq(battle.skill_cooldown_remaining(mira), 10)
	var next_battle := BattleRules.new([mira, sable], BattleRules.Fighter.new("Rat", 20, 1, 4), 0)
	assert_true(next_battle.can_use_skill(mira), "A new fight starts with the skill ready.")


func test_fighter_skill_stops_at_the_killing_blow() -> void:
	var fighter := BattleRules.Fighter.new("Fighter", 26, 5, 12)
	fighter.skill = CampaignRun.CONTENT.skills["twin_cut"]
	var foe := BattleRules.Fighter.new("Sentinel", 9, 4, 8)
	var battle := BattleRules.new([fighter], foe, 0)
	assert_true(battle.use_command(BattleRules.Command.SKILL))
	assert_eq(battle.outcome, BattleRules.Outcome.WON)
	assert_eq(battle.messages.size(), 2)
	assert_string_contains(battle.messages[0], "4")
	assert_string_contains(battle.messages[1], "goes down")
