class_name InteriorThemeCatalog
extends RefCounted

static func all_theme_ids() -> Array[String]:
	return ["rustic", "noble", "mercenary", "cellar"] as Array[String]


static func get_theme(theme_id: String) -> InteriorTheme:
	match theme_id:
		"cellar":
			var cellar_theme := InteriorTheme.new()
			cellar_theme.theme_id = "cellar"
			cellar_theme.display_name = "지하실"
			cellar_theme.floor_color = Color(0.16, 0.15, 0.17, 0.96)
			cellar_theme.wall_color = Color(0.10, 0.10, 0.12, 0.98)
			cellar_theme.door_color = Color(0.22, 0.18, 0.14, 0.98)
			cellar_theme.preferred_guest_tags = PackedStringArray(["storage", "brewer"])
			return cellar_theme
		"noble":
			var theme := InteriorTheme.new()
			theme.theme_id = "noble"
			theme.display_name = "귀족"
			theme.floor_color = Color(0.34, 0.28, 0.20, 0.96)
			theme.wall_color = Color(0.20, 0.17, 0.24, 0.98)
			theme.door_color = Color(0.40, 0.28, 0.16, 0.98)
			theme.preferred_guest_tags = PackedStringArray(["noble", "scholar"])
			return theme
		"mercenary":
			var merc_theme := InteriorTheme.new()
			merc_theme.theme_id = "mercenary"
			merc_theme.display_name = "용병"
			merc_theme.floor_color = Color(0.24, 0.20, 0.16, 0.96)
			merc_theme.wall_color = Color(0.14, 0.14, 0.16, 0.98)
			merc_theme.door_color = Color(0.30, 0.20, 0.12, 0.98)
			merc_theme.preferred_guest_tags = PackedStringArray(["mercenary", "rogue"])
			return merc_theme
		_:
			var rustic_theme := InteriorTheme.new()
			rustic_theme.theme_id = "rustic"
			rustic_theme.display_name = "소박"
			rustic_theme.floor_color = DarkFantasyPalette.floor_wood
			rustic_theme.wall_color = DarkFantasyPalette.wall_stone
			rustic_theme.door_color = DarkFantasyPalette.door_oak
			rustic_theme.preferred_guest_tags = PackedStringArray(["merchant", "traveler"])
			return rustic_theme
