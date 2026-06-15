class_name MenuCatalog
extends RefCounted

static func get_night_menu() -> Array[Dictionary]:
	return [
		{"id": "room", "name": "숙박실", "price": 18},
		{"id": "warm_bed", "name": "따뜻한 침대", "price": 24},
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
			combo["order_type"] = order_type
			combo["name"] = "%s + 숙박" % combo.get("name", "식사")
			combo["price"] = int(combo.get("price", 10)) + 16
			return combo
		_:
			var meal: Dictionary = KitchenUpgradeService.pick_food_order(view_id)
			meal["order_type"] = CustomerOrderTypes.Id.FOOD
			return meal
