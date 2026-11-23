class_name BattleRules
extends RefCounted

enum Command { ATTACK, DEFEND, ITEM, FLEE, SKILL }
enum Outcome { IN_PROGRESS, WON, FLED, LOST }

class Fighter:
	var name: String
	var max_hp: int
	var hp: int
	var power: int
	var speed: int
	var guarding: bool = false
	var id: String
	var is_pet: bool
	var level: int = 1
	var xp: int = 0
	var stat_points: int = 0
	var weapon: String
	var armor: String
	var weapon_bonus: int
	var armor_bonus: int
	var natural_armor: int
	var injuries: Dictionary[String, bool] = {}
	var skill: Dictionary
	var wound: String
	var entrance: String

	func _init(fighter_name: String, health: int, attack_power: int, initiative: int) -> void:
		name = fighter_name
		max_hp = health
		hp = health
		power = attack_power
		speed = initiative

	func attack_power() -> int:
		return maxi(1, power + weapon_bonus - (2 if injuries.has("arms") else 0))

	func initiative() -> int:
		return speed - (2 if injuries.has("head") else 0) - (3 if injuries.has("legs") else 0)

	func earn_experience(amount: int) -> void:
		if hp == 0:
			return
		xp += amount
		while xp >= level * 15:
			xp -= level * 15
			level += 1
			stat_points += 1
			max_hp += 4
			hp += 4
			power += 1

	func spend_stat_point(stat: String) -> bool:
		if hp == 0 or stat_points == 0:
			return false
		match stat:
			"power": power += 1
			"speed": speed += 1
			"health":
				max_hp += 4
				hp += 4
			_: return false
		stat_points -= 1
		return true


class EnemyHit:
	var target: Fighter
	var previous_hp: int

	func _init(member: Fighter) -> void:
		target = member
		previous_hp = member.hp


const POTION_HEAL := 9
const SKILL_COOLDOWN_TURNS := 10

var party: Array[Fighter]
var enemy: Fighter
var potions: int
var used_skill: bool = false
var outcome: Outcome = Outcome.IN_PROGRESS
var messages: PackedStringArray = []

var _initiative: Array[Fighter]
var _turn_index: int = 0
var _enemy_actions: int = 0
var _completed_turns: int = 0
var _skill_ready_after: Dictionary[Fighter, int] = {}
var _recent_impact: Dictionary[Fighter, int] = {}
var _last_enemy_target: Fighter
var _target_random := RandomNumberGenerator.new()


func _init(members: Array[Fighter], opponent: Fighter, supplies: int) -> void:
	party = members
	enemy = opponent
	potions = supplies
	_target_random.randomize()
	_initiative = party.duplicate()
	_initiative.append(enemy)
	for fighter: Fighter in _initiative:
		fighter.guarding = false
	_turn_index = _initiative.size() - 1
	_finish_action()
	_log(enemy.entrance if not enemy.entrance.is_empty() else "%s blocks your path." % enemy.name)


func current_fighter() -> Fighter:
	return _initiative[_turn_index] if outcome == Outcome.IN_PROGRESS else null


func turn_order() -> Array[Fighter]:
	var order: Array[Fighter] = []
	if outcome == Outcome.IN_PROGRESS:
		for offset: int in _initiative.size():
			var fighter: Fighter = _initiative[(_turn_index + offset) % _initiative.size()]
			if fighter.hp > 0:
				order.append(fighter)
	return order


func potion_target() -> Fighter:
	var target: Fighter
	var most_missing: int = 0
	for member: Fighter in party:
		var missing: int = member.max_hp - member.hp
		if member.hp > 0 and missing > most_missing:
			target = member
			most_missing = missing
	return target


func can_use_skill(actor: Fighter) -> bool:
	return (actor != null and not actor.skill.is_empty()
		and skill_cooldown_remaining(actor) == 0 and skill_target(actor) != null)


func skill_cooldown_remaining(actor: Fighter) -> int:
	return maxi(0, _skill_ready_after.get(actor, 0) - _completed_turns)


func skill_target(actor: Fighter) -> Fighter:
	if actor.skill.get("hits", 1) > 0:
		return enemy
	return potion_target()


func use_command(command: Command) -> bool:
	var actor: Fighter = current_fighter()
	if actor == null or actor == enemy:
		return false

	var previous_enemy_hp: int = enemy.hp
	var healed: int = 0
	match command:
		Command.ATTACK:
			_hit(actor, enemy)
		Command.SKILL:
			if not can_use_skill(actor):
				return false
			healed = _use_skill(actor)
		Command.DEFEND:
			actor.guarding = true
			_log("%s braces for the next hit." % actor.name)
		Command.ITEM:
			var target: Fighter = potion_target()
			if potions <= 0 or target == null:
				return false
			potions -= 1
			healed = mini(POTION_HEAL, target.max_hp - target.hp)
			target.hp += healed
			_log("%s gives %s a tonic for %d HP." % [actor.name, target.name, healed])
		Command.FLEE:
			outcome = Outcome.FLED
			_log("The party escapes.")
			return true
	var impact: int = previous_enemy_hp - enemy.hp + healed
	if impact > 0:
		_recent_impact[actor] = _recent_impact.get(actor, 0) + impact
	_completed_turns += 1
	_finish_action()
	return true


func _use_skill(actor: Fighter) -> int:
	# The cooldown starts after the turn spent using the skill.
	_skill_ready_after[actor] = _completed_turns + 1 + SKILL_COOLDOWN_TURNS
	used_skill = true
	var skill: Dictionary = actor.skill
	for hit: int in int(skill.get("hits", 1)):
		if enemy.hp == 0:
			break
		_hit(actor, enemy, skill.get("bonus", 0), skill.get("wound", ""))
	if skill.get("guard", false):
		actor.guarding = true
		_log("%s braces for the next hit." % actor.name)
	var healing: int = skill.get("heal", 0)
	if healing > 0:
		var ally: Fighter = actor if skill.get("heal_self", false) else potion_target()
		if ally != null and ally.hp < ally.max_hp:
			var restored: int = mini(healing, ally.max_hp - ally.hp)
			ally.hp += restored
			_log("%s restores %d HP to %s." % [actor.name, restored, ally.name])
			return restored
	return 0


func take_enemy_turn() -> EnemyHit:
	if current_fighter() != enemy:
		return null
	var target: Fighter = _pick_enemy_target()
	if target == null:
		return null
	var hit := EnemyHit.new(target)
	_enemy_actions += 1
	var wound: String = enemy.wound if _enemy_actions % 2 == 0 else ""
	_hit(enemy, target, 0, wound)
	_last_enemy_target = target
	_recent_impact.clear()
	_completed_turns += 1
	_finish_action()
	return hit


func _pick_enemy_target() -> Fighter:
	var candidates: Array[Fighter] = []
	var weights := PackedFloat32Array()
	for member: Fighter in party:
		if member.hp <= 0:
			continue
		var injury_pressure: float = 5.0 * (1.0 - float(member.hp) / member.max_hp)
		var recent_impact: float = minf(12.0, 0.6 * _recent_impact.get(member, 0))
		var weight: float = 10.0 + injury_pressure + recent_impact
		if member.guarding:
			weight *= 0.55
		if member == _last_enemy_target:
			weight *= 0.5
		candidates.append(member)
		weights.append(weight)
	return null if candidates.is_empty() else candidates[_target_random.rand_weighted(weights)]


func _hit(attacker: Fighter, target: Fighter, bonus: int = 0, wound: String = "") -> void:
	var force: int = maxi(1, attacker.attack_power() + bonus - target.armor_bonus - target.natural_armor)
	if target.injuries.has("torso"):
		force += 2
	var was_guarding: bool = target.guarding
	var damage: int = mini(ceili(force / 2.0) if was_guarding else force, target.hp)
	target.guarding = false
	target.hp -= damage
	_log("%s hits %s for %d." % [attacker.name, target.name, damage])
	if target.hp == 0:
		_log("%s goes down." % target.name)
	elif not was_guarding and not wound.is_empty() and not target.injuries.has(wound):
		target.injuries[wound] = true
		_log("%s suffers a %s injury." % [target.name, wound])


func _finish_action() -> void:
	if enemy.hp == 0:
		outcome = Outcome.WON
		return
	if not party.any(func(member: Fighter) -> bool: return member.hp > 0):
		outcome = Outcome.LOST
		return

	_advance_initiative()
	while _initiative[_turn_index].hp == 0:
		_advance_initiative()
	_initiative[_turn_index].guarding = false


func _advance_initiative() -> void:
	_turn_index += 1
	if _turn_index == _initiative.size():
		_turn_index = 0
		_initiative.sort_custom(func(left: Fighter, right: Fighter) -> bool:
			if left.initiative() == right.initiative():
				return left.name < right.name
			return left.initiative() > right.initiative()
		)


func _log(message: String) -> void:
	messages.append(message)
	if messages.size() > 2:
		messages.remove_at(0)
