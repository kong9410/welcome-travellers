class_name StaffJob
extends RefCounted

var task: StaffTasks.Id = StaffTasks.Id.COUNTER
var target_position: Vector2 = Vector2.ZERO
var customer: CustomerEntity = null
var waypoints: Array[Vector2] = []


func _init(
	p_task: StaffTasks.Id,
	p_target_position: Vector2,
	p_customer: CustomerEntity = null,
	p_waypoints: Array[Vector2] = []
) -> void:
	task = p_task
	target_position = p_target_position
	customer = p_customer
	waypoints = p_waypoints
