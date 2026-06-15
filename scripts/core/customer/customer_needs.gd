class_name CustomerNeeds
extends RefCounted

const MAX_VALUE: float = 100.0
const LODGING_MEAL_HUNGER_THRESHOLD: float = 42.0

var hunger: float = MAX_VALUE
var sleep: float = MAX_VALUE
var fatigue: float = MAX_VALUE
var cleanliness: float = MAX_VALUE
var fun: float = MAX_VALUE
var health: float = MAX_VALUE


static func random_initial() -> CustomerNeeds:
	var needs := CustomerNeeds.new()
	needs.hunger = randf_range(72.0, MAX_VALUE)
	needs.sleep = randf_range(68.0, MAX_VALUE)
	needs.fatigue = randf_range(70.0, MAX_VALUE)
	needs.cleanliness = randf_range(75.0, MAX_VALUE)
	needs.fun = randf_range(65.0, MAX_VALUE)
	needs.health = randf_range(80.0, MAX_VALUE)
	return needs


static func random_initial_for_combo_guest() -> CustomerNeeds:
	var needs := random_initial()
	needs.hunger = randf_range(28.0, 88.0)
	return needs


func clamp_all() -> void:
	hunger = clampf(hunger, 0.0, MAX_VALUE)
	sleep = clampf(sleep, 0.0, MAX_VALUE)
	fatigue = clampf(fatigue, 0.0, MAX_VALUE)
	cleanliness = clampf(cleanliness, 0.0, MAX_VALUE)
	fun = clampf(fun, 0.0, MAX_VALUE)
	health = clampf(health, 0.0, MAX_VALUE)


func format_line(label: String, value: float) -> String:
	return "%s: %d" % [label, int(round(clampf(value, 0.0, MAX_VALUE)))]
