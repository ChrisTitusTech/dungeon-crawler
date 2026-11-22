class_name CampaignContent
extends Resource

@export var heroes: Dictionary
@export var foes: Dictionary
@export var items: Dictionary
@export var skills: Dictionary
@export var show: Dictionary
@export var factions: Dictionary
@export var recipes: Dictionary
@export var sponsors: Dictionary


func make_fighter(id: String) -> BattleRules.Fighter:
	var definition: Dictionary = heroes.get(id, foes.get(id, {}))
	var fighter := BattleRules.Fighter.new(definition.name, definition.hp, definition.power, definition.speed)
	fighter.id = id
	fighter.portrait = definition.portrait
	fighter.wound = definition.get("wound", "")
	fighter.skill = skills.get(definition.get("skill", ""), {})
	return fighter
