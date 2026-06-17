class_name KitchenUpgradeService
extends RefCounted

const KITCHEN_DEF_IDS = [
	"cauldron",
]

const QUALITY_BONUS: Dictionary = {
	"cauldron": 0.04,
}

const FOOD_MENU = [
	{
		"id": "bread",
		"name": "빵",
		"food_type": "bread",
		"difficulty": 1,
		"price": 1,
		"ingredient_cost": 1,
		"unlock_furniture": "",
	},
	{
		"id": "basic_meal",
		"name": "기본음식",
		"food_type": "basic",
		"difficulty": 2,
		"price": 3,
		"ingredient_cost": 2,
		"unlock_furniture": "",
	},
]

const MAX_QUALITY_BONUS: float = 0.32


static func is_kitchen_furniture(def_id: String) -> bool:
	return def_id in KITCHEN_DEF_IDS


static func get_installed_kitchen_defs(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Array[String]:
	var installed: Array[String] = []
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		if instance.def_id in KITCHEN_DEF_IDS and instance.def_id not in installed:
			installed.append(instance.def_id)
	return installed


static func has_kitchen(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	return not get_installed_kitchen_defs(view_id).is_empty()


static func get_satisfaction_bonus(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> float:
	var bonus: float = 0.0
	for def_id: String in get_installed_kitchen_defs(view_id):
		bonus += float(QUALITY_BONUS.get(def_id, 0.0))
	return minf(bonus, MAX_QUALITY_BONUS)


static func get_unlocked_food_menu(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Array[Dictionary]:
	var installed: Array[String] = get_installed_kitchen_defs(view_id)
	var unlocked: Array[Dictionary] = []
	for item: Dictionary in FOOD_MENU:
		var required: String = item.get("unlock_furniture", "")
		if required == "" or required in installed:
			unlocked.append(item.duplicate())
	return unlocked


static func pick_food_order(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Dictionary:
	var unlocked: Array[Dictionary] = get_unlocked_food_menu(view_id)
	if unlocked.is_empty():
		return FOOD_MENU[0].duplicate()
	return unlocked[randi() % unlocked.size()].duplicate()


static func get_kitchen_summary(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> String:
	var installed: Array[String] = get_installed_kitchen_defs(view_id)
	if installed.is_empty():
		return "주방 가구 없음 — 기본 메뉴만 제공"
	var unlocked_count: int = get_unlocked_food_menu(view_id).size()
	return "주방 Lv.%d | 메뉴 %d종 | 품질 +%.0f%%" % [
		installed.size(),
		unlocked_count,
		get_satisfaction_bonus(view_id) * 100.0,
	]
