class_name GamePhases
extends RefCounted

enum Id {
	BRIEFING,
	RUNNING,
	GAME_OVER,
}

const LABELS: Dictionary = {
	Id.BRIEFING: "아침 브리핑",
	Id.RUNNING: "영업 중",
	Id.GAME_OVER: "게임 오버",
}


static func label_for(phase: Id) -> String:
	return LABELS.get(phase, "Unknown")
