class_name ViewIds
extends RefCounted

enum Id {
	OUTSIDE,
	INN_F1,
	INN_F2,
	INN_F3,
	INN_BASEMENT,
}

const LABELS: Dictionary = {
	Id.OUTSIDE: "야외",
	Id.INN_F1: "여관 1층",
	Id.INN_F2: "여관 2층",
	Id.INN_F3: "여관 3층",
	Id.INN_BASEMENT: "지하",
}

static func label_for(view_id: Id) -> String:
	return LABELS.get(view_id, "Unknown")


static func all() -> Array[Id]:
	return [
		Id.OUTSIDE,
		Id.INN_F1,
		Id.INN_F2,
		Id.INN_F3,
		Id.INN_BASEMENT,
	] as Array[Id]
