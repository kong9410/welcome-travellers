class_name GameModes
extends RefCounted

enum Id {
	PLAY,
	BUILD,
	FURNITURE,
}

const LABELS: Dictionary = {
	Id.PLAY: "플레이",
	Id.BUILD: "건설",
	Id.FURNITURE: "가구",
}


static func label_for(mode: GameModes.Id) -> String:
	return LABELS.get(mode, "Unknown")
