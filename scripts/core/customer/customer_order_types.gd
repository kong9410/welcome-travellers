class_name CustomerOrderTypes
extends RefCounted

enum Id {
	FOOD,
	LODGING,
	FOOD_AND_LODGING,
}

const LABELS: Dictionary = {
	Id.FOOD: "Food",
	Id.LODGING: "Lodging",
	Id.FOOD_AND_LODGING: "Lodging & Food",
}

static func label_for(order_type: Id) -> String:
	return LABELS.get(order_type, "Unknown")


static func color_for(order_type: Id) -> Color:
	match order_type:
		Id.FOOD:
			return DarkFantasyPalette.guest_food
		Id.LODGING:
			return DarkFantasyPalette.guest_lodging
		Id.FOOD_AND_LODGING:
			return DarkFantasyPalette.guest_combo
		_:
			return Color(0.72, 0.72, 0.72, 0.95)


static func needs_food(order_type: Id) -> bool:
	return order_type == Id.FOOD or order_type == Id.FOOD_AND_LODGING


static func needs_lodging(order_type: Id) -> bool:
	return order_type == Id.LODGING or order_type == Id.FOOD_AND_LODGING
