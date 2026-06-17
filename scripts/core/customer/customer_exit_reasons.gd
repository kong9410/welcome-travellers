class_name CustomerExitReasons
extends RefCounted

const SUCCESS_MEAL: String = "식사 완료"
const SUCCESS_LODGING: String = "숙박 퇴실"
const SUCCESS_NORMAL: String = "정상 퇴장"
const TABLE_MISSING: String = "테이블을 찾을 수 없습니다"


static func format_summary_lines(counts: Dictionary) -> String:
	if counts.is_empty():
		return "· 없음"
	var entries: Array[Dictionary] = []
	for reason: Variant in counts.keys():
		entries.append({
			"reason": str(reason),
			"count": int(counts[reason]),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.count) > int(b.count)
	)
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		lines.append("· %s: %d" % [entry.reason, entry.count])
	return "\n".join(lines)
