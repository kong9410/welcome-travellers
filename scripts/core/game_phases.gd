class_name GamePhases
extends RefCounted

enum Id {
	PRE_OPEN,
	OPEN,
	CLOSING,
	SETTLEMENT,
	GAME_OVER,
}

const LABELS: Dictionary = {
	Id.PRE_OPEN: "영업 준비",
	Id.OPEN: "영업 중",
	Id.CLOSING: "마감 중",
	Id.SETTLEMENT: "정산",
	Id.GAME_OVER: "게임 오버",
}


static func label_for(phase: Id) -> String:
	return LABELS.get(phase, "Unknown")


static func migrate_saved_phase(raw_phase: int, save_version: int) -> Id:
	if save_version < 8:
		match raw_phase:
			0:
				return Id.PRE_OPEN
			1:
				return Id.OPEN
			2:
				return Id.GAME_OVER
			_:
				return Id.PRE_OPEN
	if raw_phase < Id.PRE_OPEN or raw_phase > Id.GAME_OVER:
		return Id.PRE_OPEN
	return raw_phase as Id
