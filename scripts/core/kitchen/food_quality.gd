class_name FoodQuality
extends RefCounted

enum Id {
	BAD,
	NORMAL,
	GOOD,
	EXCELLENT,
}

const DEFAULT_QUALITY: Id = Id.NORMAL

const LABELS: Dictionary = {
	Id.BAD: "나쁨",
	Id.NORMAL: "보통",
	Id.GOOD: "좋음",
	Id.EXCELLENT: "훌륭함",
}

const SATISFACTION_BONUSES: Dictionary = {
	Id.BAD: -0.10,
	Id.NORMAL: 0.0,
	Id.GOOD: 0.08,
	Id.EXCELLENT: 0.15,
}


static func label_for(quality: Id) -> String:
	return LABELS.get(quality, "보통")


static func satisfaction_bonus_for(quality: Id) -> float:
	return float(SATISFACTION_BONUSES.get(quality, 0.0))


static func from_value(value) -> Id:
	if value is int:
		return int(value) as Id
	if value is float:
		return int(value) as Id
	return DEFAULT_QUALITY
