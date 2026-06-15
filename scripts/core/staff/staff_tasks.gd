class_name StaffTasks
extends RefCounted

enum Id {
	REST,
	COUNTER,
	TAKE_ORDER,
	COOK,
	SERVE,
	CLEAN,
}

const LABELS: Dictionary = {
	Id.REST: "휴식",
	Id.COUNTER: "카운터 대기",
	Id.TAKE_ORDER: "주문 접수",
	Id.COOK: "조리 중",
	Id.SERVE: "서빙 중",
	Id.CLEAN: "청소 중",
}


static func label_for(task: Id) -> String:
	return LABELS.get(task, "Idle")
