extends Node

const FURNITURE_WEIGHT: float = 2.0


func get_region_aesthetics(view_id: ViewIds.Id, region_id: int) -> float:
	if region_id == RoomRegionService.NO_REGION:
		return 0.0
	var tile_count: int = RoomRegionService.get_region_coords(view_id, region_id).size()
	if tile_count <= 0:
		return 0.0
	return get_region_aesthetics_total(view_id, region_id) / float(tile_count)


func get_region_aesthetics_total(view_id: ViewIds.Id, region_id: int) -> float:
	if region_id == RoomRegionService.NO_REGION:
		return 0.0
	var total: float = 0.0
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		var instance_region_id: int = RoomRegionService.get_region_id_for_furniture(instance)
		if instance_region_id != region_id:
			continue
		total += FurnitureCatalog.aesthetic_score_for(instance.def_id) * FURNITURE_WEIGHT
	total += FilthService.get_region_filth_total(view_id, region_id)
	return total


func get_region_aesthetics_label(view_id: ViewIds.Id, region_id: int) -> String:
	if region_id == RoomRegionService.NO_REGION:
		return "없음"
	var score: float = get_region_aesthetics(view_id, region_id)
	return "%+.2f" % score


func get_aesthetics_at_world_position(view_id: ViewIds.Id, world_position: Vector2) -> float:
	var region_id: int = RoomRegionService.get_region_id_for_world_position(view_id, world_position)
	return get_region_aesthetics(view_id, region_id)


func get_aesthetics_label_at_world_position(view_id: ViewIds.Id, world_position: Vector2) -> String:
	var region_id: int = RoomRegionService.get_region_id_for_world_position(view_id, world_position)
	return get_region_aesthetics_label(view_id, region_id)


func satisfaction_bonus_for(score: float) -> float:
	if score >= 2.0:
		return 0.10
	if score >= 1.0:
		return 0.05
	if score >= -0.9:
		return 0.0
	if score >= -2.0:
		return -0.08
	return -0.16
