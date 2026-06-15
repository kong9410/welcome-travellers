class_name DayPeriods
extends RefCounted

enum Id {
	DAY,
	NIGHT,
}

const LABELS: Dictionary = {
	Id.DAY: "낮 (식당)",
	Id.NIGHT: "밤 (숙박)",
}


static func label_for(period: DayPeriods.Id) -> String:
	return LABELS.get(period, "Unknown")
