extends Node

var _food_by_customer: Dictionary = {}


func reset_all() -> void:
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
		visual.queue_free()
