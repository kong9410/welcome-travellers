class_name ResolutionPresets
extends RefCounted

enum Id {
	P720,
	P1K,
	P2K,
	P4K,
}

const SIZES: Dictionary = {
	Id.P720: Vector2i(1280, 720),
	Id.P1K: Vector2i(1920, 1080),
	Id.P2K: Vector2i(2560, 1440),
	Id.P4K: Vector2i(3840, 2160),
}

const LABELS: Dictionary = {
	Id.P720: "720p (1280x720)",
	Id.P1K: "1K (1920x1080)",
	Id.P2K: "2K (2560x1440)",
	Id.P4K: "4K (3840x2160)",
}


static func get_size(preset: Id) -> Vector2i:
	return SIZES.get(preset, Vector2i(1280, 720))


static func label_for(preset: Id) -> String:
	return LABELS.get(preset, "Unknown")


static func all() -> Array[Id]:
	return [Id.P720, Id.P1K, Id.P2K, Id.P4K] as Array[Id]
