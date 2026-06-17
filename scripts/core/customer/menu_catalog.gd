class_name MenuCatalog
extends RefCounted

static func get_night_menu() -> Array[Dictionary]:
	return [
		{"id": "room", "name": "숙박실", "price": 8},
	] as Array[Dictionary]


static func pick_service_request(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Dictionary:
	var order_types: Array[CustomerOrderTypes.Id] = [
		CustomerOrderTypes.Id.FOOD,
		CustomerOrderTypes.Id.FOOD_AND_LODGING,
	]
	var order_type: CustomerOrderTypes.Id = order_types[randi() % order_types.size()]
	return _build_service_order(order_type, view_id)


static func _build_service_order(order_type: CustomerOrderTypes.Id, view_id: ViewIds.Id) -> Dictionary:
	match order_type:
		CustomerOrderTypes.Id.FOOD_AND_LODGING:
			var combo: Dictionary = KitchenUpgradeService.pick_food_order(view_id)
			var food_price: int = int(combo.get("price", 3))
			var ingredient_cost: int = int(combo.get("ingredient_cost", 1))
			var lodging_price: int = 8
			combo["order_type"] = order_type
			combo["name"] = "%s + 숙박" % combo.get("name", "식사")
			combo["food_price"] = food_price
			combo["ingredient_cost"] = ingredient_cost
			combo["lodging_price"] = lodging_price
			combo["price"] = food_price + lodging_price
			return combo
		_:
			var meal: Dictionary = KitchenUpgradeService.pick_food_order(view_id)
			meal["order_type"] = CustomerOrderTypes.Id.FOOD
			meal["food_price"] = int(meal.get("price", 3))
			meal["ingredient_cost"] = int(meal.get("ingredient_cost", 1))
			meal["lodging_price"] = 0
			return meal
