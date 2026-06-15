class_name CustomerPersonas
extends RefCounted

enum Id {
	TRAVELER,
	MERCHANT,
	NOBLE,
	MERCENARY,
}

const LABELS: Dictionary = {
	Id.TRAVELER: "Traveler",
	Id.MERCHANT: "Merchant",
	Id.NOBLE: "Noble",
	Id.MERCENARY: "Mercenary",
}


static func all() -> Array[Id]:
	return [Id.TRAVELER, Id.MERCHANT, Id.NOBLE, Id.MERCENARY] as Array[Id]


static func label_for(persona: Id) -> String:
	return LABELS.get(persona, "Guest")


static func random() -> Id:
	var personas: Array[Id] = all()
	return personas[randi() % personas.size()]


static func tip_multiplier(persona: Id) -> float:
	match persona:
		Id.NOBLE:
			return 1.6
		Id.MERCHANT:
			return 1.2
		Id.MERCENARY:
			return 0.9
		_:
			return 1.0
