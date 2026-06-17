class_name TableFoodVisual
extends Node2D

var customer_id: String = ""
var order: Dictionary = {}
var maker_id: String = ""
var maker_label: String = "알 수 없음"
var maker_cooking_level: int = 0
var is_selected: bool = false


func _ready() -> void:
	TopdownDepthSort.apply_for_foot(self, TopdownDepthSort.FOOD_OFFSET)
	queue_redraw()


func setup(customer: CustomerEntity) -> void:
	if customer == null:
		return
	customer_id = customer.customer_id
	order = customer.order.duplicate(true)
	maker_id = str(order.get("maker_id", ""))
	maker_label = str(order.get("maker_label", "알 수 없음"))
	maker_cooking_level = int(order.get("maker_cooking_level", 0))
	queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func contains_world_point(world_position: Vector2) -> bool:
	return Rect2(Vector2(-14.0, -14.0), Vector2(28.0, 28.0)).has_point(to_local(world_position))


func get_status_panel_title() -> String:
	return "음식"


func get_status_panel_text() -> String:
	var quality_label: String = "미정"
	if order.has("quality"):
		quality_label = FoodQuality.label_for(FoodQuality.from_value(order.get("quality")))

	var lines: PackedStringArray = []
	lines.append("음식: %s" % order.get("name", "식사"))
	lines.append("분류: %s" % _food_type_label())
	lines.append("난이도: %d" % int(order.get("difficulty", 2)))
	lines.append("품질: %s" % quality_label)
	lines.append("만든이: %s" % maker_label)
	if maker_cooking_level > 0:
		lines.append("제작 당시 요리레벨: %d" % maker_cooking_level)
	if customer_id != "":
		lines.append("대상 손님: %s" % customer_id)
	return "\n".join(lines)


func _food_type_label() -> String:
	match str(order.get("food_type", "")):
		"bread":
			return "빵"
		"basic":
			return "기본음식"
		"premium":
			return "고급음식"
		_:
			return "기타"


func _draw() -> void:
	if is_selected:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, DarkFantasyPalette.brass_bright, 2.0)

	var texture: Texture2D = FoodItemSpriteDrawer.texture_for_food_type(str(order.get("food_type", "")))
	if texture != null:
		FoodItemSpriteDrawer.draw_item(self, texture)
		return

	var plate := DarkFantasyPalette.plate
	var rim := DarkFantasyPalette.iron_rim
	var meal := DarkFantasyPalette.stew
	var garnish := DarkFantasyPalette.herb
	draw_circle(Vector2.ZERO, 8.0, plate, true)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, rim, 1.5, true)
	draw_circle(Vector2(-1.0, 1.0), 5.0, meal, true)
	draw_circle(Vector2(3.0, -2.0), 2.0, garnish, true)
