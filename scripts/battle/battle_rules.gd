class_name BattleRules
extends RefCounted

enum Command { ATTACK, DEFEND, ITEM, FLEE }
enum Outcome { IN_PROGRESS, WON, FLED, LOST }

class Fighter:
	var name: String
	var max_hp: int
	var hp: int
	var power: int
	var speed: int
	var guarding: bool = false

	func _init(fighter_name: String, health: int, attack_power: int, initiative: int) -> void:
		name = fighter_name
		max_hp = health
		hp = health
		power = attack_power
		speed = initiative


const POTION_HEAL := 9

var party: Array[Fighter]
var enemy: Fighter
var potions: int
var outcome: Outcome = Outcome.IN_PROGRESS
var messages: PackedStringArray = []

var _initiative: Array[Fighter]
var _turn_index: int = 0


func _init(members: Array[Fighter], opponent: Fighter, supplies: int) -> void:
	party = members
	enemy = opponent
	potions = supplies
	_initiative = party.duplicate()
	_initiative.append(enemy)
	_initiative.sort_custom(func(left: Fighter, right: Fighter) -> bool:
		return left.speed > right.speed
	)
	for fighter: Fighter in _initiative:
		fighter.guarding = false
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


func use_command(command: Command) -> bool:
	var actor: Fighter = current_fighter()
	if actor == null or actor == enemy:
		return false

	match command:
		Command.ATTACK:
			_hit(actor, enemy)
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


func take_enemy_turn() -> void:
	if current_fighter() != enemy:
		return
	for member: Fighter in party:
		if member.hp > 0:
			_hit(enemy, member)
			_finish_action()
			return


func _hit(attacker: Fighter, target: Fighter) -> void:
	var power: int = ceili(attacker.power / 2.0) if target.guarding else attacker.power
	var damage: int = mini(power, target.hp)
	target.guarding = false
	target.hp -= damage
	_log("%s hits %s for %d." % [attacker.name, target.name, damage])
	if target.hp == 0:
		_log("%s goes down." % target.name)


func _finish_action() -> void:
	if enemy.hp == 0:
		outcome = Outcome.WON
		return
	if not party.any(func(member: Fighter) -> bool: return member.hp > 0):
		outcome = Outcome.LOST
		return

	_turn_index = (_turn_index + 1) % _initiative.size()
	while _initiative[_turn_index].hp == 0:
		_turn_index = (_turn_index + 1) % _initiative.size()
	_initiative[_turn_index].guarding = false


func _log(message: String) -> void:
	messages.append(message)
	if messages.size() > 2:
		messages.remove_at(0)
