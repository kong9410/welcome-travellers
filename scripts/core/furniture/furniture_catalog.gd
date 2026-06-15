class_name FurnitureCatalog
extends RefCounted

static func all_def_ids() -> Array[String]:
	return playable_def_ids() + ["owner_bed"] as Array[String]


static func playable_def_ids() -> Array[String]:
	return [
		"chair",
		"table",
		"bed",
		"counter",
		"barrel",
		"room_door",
		"hearth",
		"prep_table",
		"cauldron",
		"pantry_shelf",
		"pot_rack",
		"bread_oven",
	] as Array[String]


static func get_definition(def_id: String) -> FurnitureDefinition:
	match def_id:
		"table":
			return _make(
				"table",
				"테이블",
				Vector2i(2, 1),
				DarkFantasyPalette.furn_table,
				"dining"
			)
		"bed":
			return _make(
				"bed",
				"침대",
				Vector2i(2, 1),
				DarkFantasyPalette.furn_bed,
				"lodging"
			)
		"owner_bed":
			return _make(
				"owner_bed",
				"주인 침대",
				Vector2i(2, 1),
				Color(0.28, 0.24, 0.36, 0.96),
				"owner_room"
			)
		"counter":
			return _make(
				"counter",
				"카운터",
				Vector2i(3, 1),
				DarkFantasyPalette.furn_counter,
				"service"
			)
		"barrel":
			return _make(
				"barrel",
				"통",
				Vector2i(1, 1),
				DarkFantasyPalette.furn_barrel,
				"storage"
			)
		"room_door":
			return _make(
				"room_door",
				"방문 (내부)",
				Vector2i(1, 1),
				DarkFantasyPalette.furn_door,
				"door",
				false,
				false
			)
		"hearth":
			return _make(
				"hearth",
				"석화로",
				Vector2i(2, 1),
				DarkFantasyPalette.furn_hearth,
				"kitchen"
			)
		"prep_table":
			return _make(
				"prep_table",
				"밀대",
				Vector2i(2, 1),
				DarkFantasyPalette.furn_kitchen,
				"kitchen"
			)
		"cauldron":
			return _make(
				"cauldron",
				"가마솥",
				Vector2i(1, 1),
				DarkFantasyPalette.iron,
				"kitchen"
			)
		"pantry_shelf":
			return _make(
				"pantry_shelf",
				"식료품 선반",
				Vector2i(2, 1),
				DarkFantasyPalette.wood_mid,
				"kitchen"
			)
		"pot_rack":
			return _make(
				"pot_rack",
				"냄비 걸이",
				Vector2i(2, 1),
				DarkFantasyPalette.wood_dark,
				"kitchen"
			)
		"bread_oven":
			return _make(
				"bread_oven",
				"빵 화덕",
				Vector2i(2, 1),
				DarkFantasyPalette.stone_mid,
				"kitchen"
			)
		_:
			return _make(
				"chair",
				"식탁 의자",
				Vector2i(1, 1),
				DarkFantasyPalette.furn_chair,
				"seating"
			)


static func allows_customer_on_tile(def_id: String) -> bool:
	return def_id in (["chair", "bed", "room_door"] as Array[String])


static func _make(
	def_id: String,
	display_name: String,
	footprint: Vector2i,
	color: Color,
	category: String,
	blocks_movement: bool = true,
	blocks_build: bool = true
) -> FurnitureDefinition:
	var definition := FurnitureDefinition.new()
	definition.def_id = def_id
	definition.display_name = display_name
	definition.footprint = footprint
	definition.placeholder_color = color
	definition.category = category
	definition.blocks_movement = blocks_movement
	definition.blocks_build = blocks_build
	return definition
