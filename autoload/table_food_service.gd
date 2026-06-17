extends Node

var _food_by_customer: Dictionary = {}
var selected_food: TableFoodVisual = null


func reset_all() -> void:
	clear_food_selection()
	for customer_id: String in _food_by_customer.keys():
		_clear_food_for_customer_id(customer_id)


func place_food(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.chair_instance_id == "":
		return

	clear_food(customer)

	var food_position: Vector2 = InnLayoutHelper.get_table_food_position(
		customer.view_id,
		customer.chair_instance_id
	)
	if food_position == Vector2.ZERO:
		return

	var view: ViewRoot = ViewManager.get_view(customer.view_id)
	if view == null:
		return

	var visual := TableFoodVisual.new()
	visual.global_position = food_position
	visual.setup(customer)
	view.entity_layer.add_child(visual)
	_food_by_customer[customer.customer_id] = visual


func clear_food(customer: CustomerEntity) -> void:
	if customer == null or customer.customer_id == "":
		return
	_clear_food_for_customer_id(customer.customer_id)


func _clear_food_for_customer_id(customer_id: String) -> void:
	if not _food_by_customer.has(customer_id):
		return
	var visual: Node = _food_by_customer[customer_id]
	_food_by_customer.erase(customer_id)
	if is_instance_valid(visual):
		if selected_food == visual:
			clear_food_selection()
		visual.queue_free()


func try_select_at(world_position: Vector2, view_id: ViewIds.Id) -> bool:
	var food: TableFoodVisual = _find_food_at(world_position, view_id)
	if food == null:
		clear_food_selection()
		return false
	select_food(food)
	return true


func select_food(food: TableFoodVisual) -> void:
	if selected_food == food:
		return
	clear_food_selection()
	selected_food = food
	if is_instance_valid(selected_food):
		selected_food.set_selected(true)


func clear_food_selection() -> void:
	if is_instance_valid(selected_food):
		selected_food.set_selected(false)
	selected_food = null


func _find_food_at(world_position: Vector2, view_id: ViewIds.Id) -> TableFoodVisual:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return null
	var closest_food: TableFoodVisual = null
	var closest_distance: float = INF
	for value in _food_by_customer.values():
		var food := value as TableFoodVisual
		if not is_instance_valid(food):
			continue
		if food.get_parent() != view.entity_layer:
			continue
		if not food.contains_world_point(world_position):
			continue
		var distance: float = food.global_position.distance_to(world_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_food = food
	return closest_food
