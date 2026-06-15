class_name CustomerStates
extends RefCounted

enum Id {
	TO_COUNTER,
	TO_QUEUE_SLOT,
	WAITING_IN_QUEUE,
	WAITING_AT_COUNTER,
	TO_CHAIR,
	TO_BED,
	DROPPING_BAGS,
	EATING,
	TO_BED_AFTER_MEAL,
	SLEEPING,
	LEAVING,
	DONE,
	REQUEST_PENDING,
}

const LABELS: Dictionary = {
	Id.TO_COUNTER: "카운터로 이동",
	Id.REQUEST_PENDING: "요청 상담 중",
	Id.TO_QUEUE_SLOT: "줄 위치로 이동",
	Id.WAITING_IN_QUEUE: "줄 서는 중",
	Id.WAITING_AT_COUNTER: "카운터 대기",
	Id.TO_CHAIR: "좌석으로 이동",
	Id.TO_BED: "방으로 이동",
	Id.DROPPING_BAGS: "짐 내려놓는 중",
	Id.EATING: "식사 중",
	Id.TO_BED_AFTER_MEAL: "숙소로 복귀",
	Id.SLEEPING: "숙박 중",
	Id.LEAVING: "퇴장 중",
	Id.DONE: "완료",
}


static func label_for(state: Id) -> String:
	return LABELS.get(state, "Unknown")


static func activity_label_for(state: Id, food_served: bool = false) -> String:
	match state:
		Id.TO_QUEUE_SLOT, Id.TO_COUNTER:
			return "카운터로 이동중"
		Id.REQUEST_PENDING:
			return "요청 상담 중"
		Id.WAITING_IN_QUEUE, Id.WAITING_AT_COUNTER:
			return "줄서는 중"
		Id.TO_CHAIR:
			return "식사중" if food_served else "식사하러 이동"
		Id.TO_BED, Id.TO_BED_AFTER_MEAL:
			return "이동중"
		Id.LEAVING:
			return "퇴장중"
		Id.EATING:
			return "식사중" if food_served else "식사대기중"
		Id.SLEEPING:
			return "숙소 휴식"
		Id.DROPPING_BAGS:
			return "휴식중"
		Id.DONE:
			return "완료"
		_:
			return label_for(state)


static func is_moving(state: Id) -> bool:
	return state in [
		Id.TO_COUNTER,
		Id.TO_QUEUE_SLOT,
		Id.TO_CHAIR,
		Id.TO_BED,
		Id.TO_BED_AFTER_MEAL,
		Id.LEAVING,
	]


static func is_queue_walking(state: Id) -> bool:
	return state == Id.TO_QUEUE_SLOT
