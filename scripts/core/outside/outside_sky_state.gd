class_name OutsideSkyState
extends RefCounted

enum Phase {
	DAY,
	SUNSET,
	NIGHT,
}

const SUNSET_START_HOUR: float = 16.0
const NIGHT_START_HOUR: float = 19.0


static func phase_for_hour(hour: float) -> Phase:
	if hour < SUNSET_START_HOUR:
		return Phase.DAY
	if hour < NIGHT_START_HOUR:
		return Phase.SUNSET
	return Phase.NIGHT


static func palette_for_hour(hour: float) -> Dictionary:
	var day := _day_palette()
	var sunset := _sunset_palette()
	var night := _night_palette()

	if hour < SUNSET_START_HOUR:
		return day
	if hour < NIGHT_START_HOUR:
		var blend: float = (hour - SUNSET_START_HOUR) / (NIGHT_START_HOUR - SUNSET_START_HOUR)
		return _lerp_palettes(day, sunset, _ease_in_out(blend))
	return _lerp_palettes(
		sunset,
		night,
		_ease_in_out(clampf((hour - NIGHT_START_HOUR) / 2.5, 0.0, 1.0))
	)


static func sun_disk_for_hour(hour: float) -> Dictionary:
	var palette: Dictionary = palette_for_hour(hour)
	var show_sun: bool = hour < NIGHT_START_HOUR + 0.5
	var show_moon: bool = hour >= NIGHT_START_HOUR - 0.25
	var sunset_progress: float = 0.0
	if hour >= SUNSET_START_HOUR and hour < NIGHT_START_HOUR:
		sunset_progress = (hour - SUNSET_START_HOUR) / (NIGHT_START_HOUR - SUNSET_START_HOUR)
	return {
		"show_sun": show_sun,
		"show_moon": show_moon,
		"sun_color": palette.get("sun", Color(0.92, 0.48, 0.16, 0.95)),
		"moon_color": palette.get("moon", Color(0.78, 0.82, 0.88, 0.72)),
		"sunset_progress": sunset_progress,
		"star_strength": palette.get("star_strength", 0.0),
	}


static func _day_palette() -> Dictionary:
	return {
		"top": Color(0.42, 0.68, 0.94, 1.0),
		"mid": Color(0.58, 0.78, 0.98, 1.0),
		"horizon": Color(0.82, 0.90, 0.97, 1.0),
		"sun": Color(0.98, 0.94, 0.72, 0.92),
		"moon": Color(0.78, 0.82, 0.88, 0.72),
		"star_strength": 0.0,
		"cloud_strength": 1.0,
	}


static func _sunset_palette() -> Dictionary:
	return {
		"top": Color(0.28, 0.38, 0.62, 1.0),
		"mid": Color(0.72, 0.48, 0.32, 1.0),
		"horizon": Color(0.96, 0.58, 0.28, 1.0),
		"sun": Color(0.98, 0.52, 0.18, 0.98),
		"moon": Color(0.82, 0.74, 0.62, 0.65),
		"star_strength": 0.08,
		"cloud_strength": 0.45,
	}


static func _night_palette() -> Dictionary:
	return {
		"top": Color(0.08, 0.12, 0.22, 1.0),
		"mid": Color(0.12, 0.16, 0.28, 1.0),
		"horizon": Color(0.18, 0.18, 0.24, 1.0),
		"sun": Color(0.96, 0.42, 0.12, 0.98),
		"moon": Color(0.88, 0.90, 0.96, 0.82),
		"star_strength": 0.75,
		"cloud_strength": 0.12,
	}


static func _lerp_palettes(from_palette: Dictionary, to_palette: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	for key: String in from_palette.keys():
		var from_value: Variant = from_palette[key]
		var to_value: Variant = to_palette.get(key, from_value)
		if from_value is Color:
			result[key] = (from_value as Color).lerp(to_value as Color, weight)
		elif from_value is float:
			result[key] = lerpf(from_value as float, to_value as float, weight)
		else:
			result[key] = to_value
	return result


static func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
