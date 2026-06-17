class_name FurnitureInfoHelper
extends RefCounted

const _USER_DEF_IDS: Array[String] = ["chair", "waiting_chair", "bed", "cauldron"]


static func shows_user(def_id: String) -> bool:
	return def_id in _USER_DEF_IDS


static func format_customer_name(customer: CustomerEntity) -> String:
	if customer == null or not is_instance_valid(customer):
		return "없음"
	return "%s %s" % [CustomerPersonas.label_for(customer.persona), customer.customer_id]


static func find_customer_for_instance(instance: FurnitureInstance) -> CustomerEntity:
	if instance == null:
		return null
	for customer: CustomerEntity in CustomerService.get_active_customers():
		if not is_instance_valid(customer):
			continue
		if customer.view_id != instance.origin.view_id:
			continue
		if (
			customer.chair_instance_id == instance.instance_id
			or customer.waiting_chair_instance_id == instance.instance_id
			or customer.bed_instance_id == instance.instance_id
		):
			return customer
	return null


static func get_user_label(instance: FurnitureInstance) -> String:
	if instance == null:
		return ""
	if not shows_user(instance.def_id):
		return ""
	match instance.def_id:
		"chair", "waiting_chair", "bed":
			var customer: CustomerEntity = find_customer_for_instance(instance)
			if customer == null:
				return "없음"
			return format_customer_name(customer)
		"cauldron":
			return _get_cauldron_user_label()
		_:
			return ""


static func get_aesthetic_label(instance: FurnitureInstance) -> String:
	if instance == null:
		return "0.0"
	var score: float = FurnitureCatalog.aesthetic_score_for(instance.def_id)
	return "%+.1f" % score


static func get_panel_title(instance: FurnitureInstance) -> String:
	if instance == null:
		return "가구"
	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(instance.def_id)
	return definition.display_name


static func get_panel_text(instance: FurnitureInstance) -> String:
	if instance == null:
		return ""
	var lines: PackedStringArray = []
	if shows_user(instance.def_id):
		lines.append("사용자: %s" % get_user_label(instance))
	lines.append("미관: %s" % get_aesthetic_label(instance))
	return "\n".join(lines)


static func _get_cauldron_user_label() -> String:
	var innkeeper: InnkeeperEntity = StaffService.innkeeper
	if (
		is_instance_valid(innkeeper)
		and innkeeper.current_job != null
		and innkeeper.current_job.task == StaffTasks.Id.COOK
	):
		return "여관주인"
	var cooking_customer: CustomerEntity = KitchenService.get_primary_cooking_customer()
	if is_instance_valid(cooking_customer):
		return format_customer_name(cooking_customer)
	return "없음"
