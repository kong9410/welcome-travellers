class_name KitchenUpgradeService
extends RefCounted

const KITCHEN_DEF_IDS = [
	"hearth",
	"bread_oven",
	"prep_table",
	"cauldron",
	"pantry_shelf",
	"pot_rack",
]

const QUALITY_BONUS: Dictionary = {
	"hearth": 0.05,
	"bread_oven": 0.06,
	"prep_table": 0.04,
	"cauldron": 0.04,
	"pantry_shelf": 0.05,
	"pot_rack": 0.03,
}

const FOOD_MENU = [
	{"id": "plain_stew", "name": "간단한 스튜", "price": 8, "unlock_furniture": ""},
	{"id": "hearth_stew", "name": "석화로 스튜", "price": 12, "unlock_furniture": "hearth"},
	{"id": "broth", "name": "뼈 육수탕", "price": 10, "unlock_furniture": "hearth"},
	{"id": "bread", "name": "갓 구운 빵", "price": 6, "unlock_furniture": "bread_oven"},
	{"id": "meat_pie", "name": "고기 파이", "price": 14, "unlock_furniture": "bread_oven"},
	{"id": "roast", "name": "구운 로스트", "price": 16, "unlock_furniture": "prep_table"},
	{"id": "house_ale", "name": "하우스 에일", "price": 8, "unlock_furniture": "cauldron"},
	{"id": "cheese_board", "name": "치즈 안주", "price": 11, "unlock_furniture": "pantry_shelf"},
	{"id": "smoked_platter", "name": "훈제 모둠", "price": 15, "unlock_furniture": "pot_rack"},
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
