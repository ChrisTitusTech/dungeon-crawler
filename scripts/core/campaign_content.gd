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
@export var races: Dictionary
@export var classes: Dictionary
@export var broadcasts: Dictionary


func make_fighter(id: String) -> BattleRules.Fighter:
	var definition: Dictionary = heroes.get(id, foes.get(id, {}))
	var fighter := BattleRules.Fighter.new(definition.name, definition.hp, definition.power, definition.speed)
	fighter.id = id
	fighter.is_pet = definition.get("pet", false)
	fighter.wound = definition.get("wound", "")
	fighter.natural_armor = definition.get("armor", 0)
	fighter.entrance = definition.get("entrance", "")
	fighter.skill = skills.get(definition.get("skill", ""), {})
	return fighter
