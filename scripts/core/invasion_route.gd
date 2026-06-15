class_name InvasionRoute
extends RefCounted

var route_id: String = "default_outside_entry"
var spawn_view_id: ViewIds.Id = ViewIds.Id.OUTSIDE
var spawn_world_position: Vector2 = Vector2(64.0, 288.0)
var door_coord: GridCoord = GridCoord.new(2, 9, ViewIds.Id.OUTSIDE)
var entry_view_id: ViewIds.Id = ViewIds.Id.INN_F1
var entry_world_position: Vector2 = Vector2(160.0, 288.0)


func duplicate_route() -> InvasionRoute:
	var copy := InvasionRoute.new()
	copy.route_id = route_id
	copy.spawn_view_id = spawn_view_id
	copy.spawn_world_position = spawn_world_position
	copy.door_coord = door_coord.duplicate_coord()
	copy.entry_view_id = entry_view_id
	copy.entry_world_position = entry_world_position
	return copy


func to_dict() -> Dictionary:
	return {
		"route_id": route_id,
		"spawn_view_id": spawn_view_id,
		"spawn_world_position": {
			"x": spawn_world_position.x,
			"y": spawn_world_position.y,
		},
		"door_coord": {
			"x": door_coord.x,
			"y": door_coord.y,
			"view_id": door_coord.view_id,
		},
		"entry_view_id": entry_view_id,
		"entry_world_position": {
			"x": entry_world_position.x,
			"y": entry_world_position.y,
		},
	}
