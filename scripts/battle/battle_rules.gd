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
	var portrait: int = -1
	var level: int = 1
	var xp: int = 0
	var stat_points: int = 0
	var weapon: String
	var armor: String
	var weapon_bonus: int
	var armor_bonus: int
	var injuries: Dictionary[String, bool] = {}
	var skill: Dictionary
	var skill_ready: bool
	var wound: String

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


const POTION_HEAL := 9

var party: Array[Fighter]
var enemy: Fighter
var potions: int
var used_skill: bool = false
var outcome: Outcome = Outcome.IN_PROGRESS
var messages: PackedStringArray = []

var _initiative: Array[Fighter]
var _turn_index: int = 0
var _enemy_actions: int = 0


func _init(members: Array[Fighter], opponent: Fighter, supplies: int) -> void:
	party = members
	enemy = opponent
	potions = supplies
	_initiative = party.duplicate()
	_initiative.append(enemy)
	for fighter: Fighter in _initiative:
		fighter.guarding = false
		fighter.skill_ready = not fighter.skill.is_empty()
	_turn_index = _initiative.size() - 1
	_finish_action()
	_log("%s blocks your path." % enemy.name)


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
	return actor != null and actor.skill_ready and skill_target(actor) != null


func skill_target(actor: Fighter) -> Fighter:
	if actor.skill.get("hits", 1) > 0:
		return enemy
	return potion_target()


func use_command(command: Command) -> bool:
	var actor: Fighter = current_fighter()
	if actor == null or actor == enemy:
		return false

	match command:
		Command.ATTACK:
			_hit(actor, enemy)
		Command.SKILL:
			if not can_use_skill(actor):
				return false
			_use_skill(actor)
		Command.DEFEND:
			actor.guarding = true
			_log("%s braces for the next hit." % actor.name)
		Command.ITEM:
			var target: Fighter = potion_target()
			if potions <= 0 or target == null:
				return false
			potions -= 1
			var healed: int = mini(POTION_HEAL, target.max_hp - target.hp)
			target.hp += healed
			_log("%s gives %s a tonic for %d HP." % [actor.name, target.name, healed])
		Command.FLEE:
			outcome = Outcome.FLED
			_log("The party escapes.")
			return true
	_finish_action()
	return true


func _use_skill(actor: Fighter) -> void:
	actor.skill_ready = false
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


func take_enemy_turn() -> void:
	if current_fighter() != enemy:
		return
	var target: Fighter = enemy_target()
	if target != null:
		_enemy_actions += 1
		var wound: String = enemy.wound if _enemy_actions % 2 == 0 else ""
		_hit(enemy, target, 0, wound)
		_finish_action()


func enemy_target() -> Fighter:
	for member: Fighter in party:
		if member.hp > 0:
			return member
	return null


func _hit(attacker: Fighter, target: Fighter, bonus: int = 0, wound: String = "") -> void:
	var force: int = maxi(1, attacker.attack_power() + bonus - target.armor_bonus)
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
