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

const CUSTOMER_LABELS: Dictionary = {
	Id.FOOD: "식사 손님",
	Id.LODGING: "숙박 손님",
	Id.FOOD_AND_LODGING: "숙박+식사 손님",
}

static func label_for(order_type: Id) -> String:
	return LABELS.get(order_type, "Unknown")


static func customer_label_for(order_type: Id) -> String:
	return CUSTOMER_LABELS.get(order_type, "손님")


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
