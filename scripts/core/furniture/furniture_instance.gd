class_name FurnitureInstance
extends RefCounted

var instance_id: String = ""
var def_id: String = ""
var origin: GridCoord = GridCoord.new()
var rotation_steps: int = 0


func _init(
	p_instance_id: String = "",
	p_def_id: String = "",
	p_origin: GridCoord = GridCoord.new(),
	p_rotation_steps: int = 0
) -> void:
	instance_id = p_instance_id
	def_id = p_def_id
	origin = p_origin.duplicate_coord()
	rotation_steps = p_rotation_steps


func get_occupied_cells() -> Array[GridCoord]:
	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
	return FurnitureFootprint.get_occupied_cells(origin, definition.footprint, rotation_steps)


func duplicate_instance() -> FurnitureInstance:
	return FurnitureInstance.new(instance_id, def_id, origin, rotation_steps)


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"def_id": def_id,
		"x": origin.x,
		"y": origin.y,
		"view_id": origin.view_id,
		"rotation_steps": rotation_steps,
	}


static func from_dict(data: Dictionary) -> FurnitureInstance:
	var view_id: ViewIds.Id = data.get("view_id", ViewIds.Id.OUTSIDE) as ViewIds.Id
	var origin := GridCoord.new(data.get("x", 0), data.get("y", 0), view_id)
	return FurnitureInstance.new(
		data.get("instance_id", ""),
		data.get("def_id", "chair"),
		origin,
		data.get("rotation_steps", 0)
	)
