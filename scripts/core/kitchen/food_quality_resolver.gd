class_name FoodQualityResolver
extends RefCounted

const MIN_EFFECTIVE_SKILL: int = 1
const MAX_EFFECTIVE_SKILL: int = 20


static func roll_quality(order: Dictionary, cooking_level: int) -> FoodQuality.Id:
	var difficulty: int = int(order.get("difficulty", 2))
	var effective_skill: int = clampi(
		cooking_level - difficulty + 2,
		MIN_EFFECTIVE_SKILL,
		MAX_EFFECTIVE_SKILL
	)
	var roll: float = randf()
	var chances: Dictionary = _quality_chances_for_skill(effective_skill)
	var bad_chance: float = float(chances.get(FoodQuality.Id.BAD, 0.0))
	var normal_chance: float = float(chances.get(FoodQuality.Id.NORMAL, 0.0))
	var good_chance: float = float(chances.get(FoodQuality.Id.GOOD, 0.0))

	if roll < bad_chance:
		return FoodQuality.Id.BAD
	if roll < bad_chance + normal_chance:
		return FoodQuality.Id.NORMAL
	if roll < bad_chance + normal_chance + good_chance:
		return FoodQuality.Id.GOOD
	return FoodQuality.Id.EXCELLENT


static func _quality_chances_for_skill(effective_skill: int) -> Dictionary:
	var t: float = float(effective_skill - MIN_EFFECTIVE_SKILL) / float(MAX_EFFECTIVE_SKILL - MIN_EFFECTIVE_SKILL)
	var bad: float = lerpf(0.35, 0.0, t)
	var normal: float = lerpf(0.55, 0.20, t)
	var excellent: float = lerpf(0.0, 0.25, t)
	var good: float = 1.0 - bad - normal - excellent
	return {
		FoodQuality.Id.BAD: bad,
		FoodQuality.Id.NORMAL: normal,
		FoodQuality.Id.GOOD: good,
		FoodQuality.Id.EXCELLENT: excellent,
	}
