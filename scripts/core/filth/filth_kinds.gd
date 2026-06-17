class_name FilthKinds
extends RefCounted

enum Id {
	FOOD_SCRAP,
	TRASH,
	DUST,
}

const NO_FILTH: int = -1

const LABELS: Dictionary = {
	Id.FOOD_SCRAP: "빈 그릇",
	Id.TRASH: "쓰레기",
	Id.DUST: "먼지",
}

const AESTHETIC_SCORES: Dictionary = {
	Id.FOOD_SCRAP: -3.0,
	Id.TRASH: -5.0,
	Id.DUST: -1.0,
}


static func label_for(kind: Id) -> String:
	return LABELS.get(kind, "오염물")


static func aesthetic_score_for(kind: Id) -> float:
	return float(AESTHETIC_SCORES.get(kind, 0.0))


static func from_value(value) -> Id:
	if value is int:
		return int(value) as Id
	return NO_FILTH
