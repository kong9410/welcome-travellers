class_name GroupDiningConstants
extends RefCounted

## 단체 식사 손님이 발생할 확률 (식사 주문 대상).
const GROUP_DINING_CHANCE: float = 0.35

const MIN_GROUP_SIZE: int = 2
const MAX_GROUP_SIZE: int = 4

## 단체 발생 시 인원 가중치 (합 100).
const GROUP_SIZE_WEIGHTS: Dictionary = {
	2: 55,
	3: 30,
	4: 15,
}

## 카운터 근처에 두면 좋은 대기의자 권장 수 (4인 일행 + 여유 1).
const RECOMMENDED_WAITING_CHAIR_COUNT: int = 4

## 4인 테이블에 필요한 식사 의자 수.
const RECOMMENDED_DINING_CHAIRS_PER_TABLE: int = 4


enum OutsideWaitPolicy {
	## (구) 대기의자가 (group_size - 1)개 없으면 일행 전원 outside 대기열 진입 불가.
	ALL_OR_NOTHING,
	## (목표) 대표는 입장; 대기의자만큼만 동행 입장, 나머지는 outside에서 대기.
	PARTIAL_WITH_OUTSIDE_WAIT,
}

## Phase 2+ 입장 정책.
const OUTSIDE_WAIT_POLICY: OutsideWaitPolicy = OutsideWaitPolicy.PARTIAL_WITH_OUTSIDE_WAIT


static func is_valid_group_size(size: int) -> bool:
	return size >= MIN_GROUP_SIZE and size <= MAX_GROUP_SIZE


static func uses_partial_outside_wait() -> bool:
	return OUTSIDE_WAIT_POLICY == OutsideWaitPolicy.PARTIAL_WITH_OUTSIDE_WAIT


static func roll_group_size(max_seatable: int) -> int:
	if max_seatable < MIN_GROUP_SIZE:
		return 1

	var capped_max: int = mini(max_seatable, MAX_GROUP_SIZE)
	var eligible_sizes: Array[int] = []
	var total_weight: int = 0
	for size_key: int in GROUP_SIZE_WEIGHTS.keys():
		if size_key < MIN_GROUP_SIZE or size_key > capped_max:
			continue
		eligible_sizes.append(size_key)
		total_weight += int(GROUP_SIZE_WEIGHTS[size_key])

	if eligible_sizes.is_empty() or total_weight <= 0:
		return MIN_GROUP_SIZE

	eligible_sizes.sort()
	var roll: int = randi() % total_weight
	var accumulated: int = 0
	for size: int in eligible_sizes:
		accumulated += int(GROUP_SIZE_WEIGHTS[size])
		if roll < accumulated:
			return size
	return eligible_sizes[0]
