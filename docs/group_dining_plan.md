# 3·4인 그룹 손님 개발 플랜

## 입장 정책 (확정)

**대기의자가 모자라면 동행은 outside에서 대기한다** (`GroupDiningConstants.PARTIAL_WITH_OUTSIDE_WAIT`).

| 역할 | 대기의자 충분 | 대기의자 부족 |
|------|----------------|----------------|
| 대표 | 카운터(또는 카운터 대기열 1번)로 **입장** | 동일 |
| 동행 (최대 group_size−1) | 빈 `waiting_chair`에 **입장** 후 대기 | **outside 대기열**에 남음 |
| outside 표시 | 입장한 만큼만 NPC 제거 | 남은 동행은 줄지어 표시 |

### 기존(현행) vs 목표

- **현행:** `_has_counter_entry_capacity()` — `(group_size − 1)`개 대기의자가 **모두** 있어야 대표도 문을 못 듦.
- **목표:** 대표 입장은 카운터 여유만 확인. 동행은 `min(필요 인원, 빈 대기의자)`만큼만 안으로, 나머지는 `_outside_queue`에 그룹으로 유지.
- **추가 입장:** 안쪽 동행이 카운터로 이동·퇴장 등으로 `waiting_chair`가 비면, 같은 `group_id` outside 동행을 순차 입장.

### outside 대기 동행 데이터

- `OutsideCustomerEntity.group_companions: Array` (Phase 4)
- `pending_outside_group_id` / `remaining_outside_companions` 등으로 대표 입장 후에도 연결 유지
- 인내심은 일행 공유(현행 2인과 동일)

---

## Phase 0 — 상수·레이아웃 ✅

- [x] `scripts/core/customer/group_dining_constants.gd`
- [x] 기본 맵: 4인 테이블(의자 4) + 대기의자 4
- [x] `customer_service.gd` 상수 → `GroupDiningConstants` 참조

## Phase 1 — N석 탐색 ✅

- [x] `InnLayoutHelper.find_available_chairs_for_table(count)`
- [x] `find_max_seatable_group_size()`
- [x] `find_best_table_for_group(count)`
- [x] `get_max_group_size_for_table(table)`
- [x] `find_available_chair_pair_for_table()` → 2인 래퍼

## Phase 2 — 그룹 크기 롤·판별·부분 입장 ✅

- [x] `GroupDiningConstants.roll_group_size(max_seatable)`
- [x] `_resolve_group_dining_size()` — 롤 + 테이블 검증 + 다운그레이드
- [x] `_is_group_dining_leader`: `group_size >= MIN_GROUP_SIZE`
- [x] `_has_counter_entry_capacity` → 대표-only (부분 입장)
- [x] `_admit_inside_group_waiting_companions()` / `_try_admit_outside_group_companions()`
- [x] `_pending_outside_companions` — outside 대기 동행 추적
- [x] outside 그룹 N-1명 스폰 (`group_companions`)
- [x] 주문 수락 시 `group_chairs[1..N-1]` 배정

## Phase 3 — 내부 동행 N명 ✅

- [x] `_spawn_group_waiting_companions(leader, max_count)` — 일괄 대기 동행 생성
- [x] `_get_group_waiting_companions()` — FIFO 대기 동행 목록
- [x] 주문 수락 시 `group_chairs[1..N-1]` 루프 + `assigned_dining_companions` 추적
- [x] `_reject_group_waiting_companions()` — 복수 reject
- [x] `_fail_group_order()` — 주문/입장 실패 통합 처리
- [x] `_rollback_assigned_dining_companions()` — 부분 배정 롤백
- [x] `_depart_pending_outside_companions()` — outside pending 퇴장

## Phase 4 — Outside 다중 NPC ✅

- [x] `group_companions` 배열, 오프셋 N개
- [x] 부분 입장 시 남은 companion만 outside 유지 (`_pending_outside_companions`)
- [x] pending 동행 인내심 ↔ inside 대표 `patience` 매 프레임 동기화
- [x] 대표 인내심 소진 / 대표 없음 → pending 동행 퇴장
- [x] pending 동행 그룹 클러스터 배치 (`reposition_as_group_cluster`)
- [x] 손님 압력·디버그 HUD에 pending 동행 반영

## Phase 5 — UX·디버그 ✅

- [x] HUD/거절 메시지 N인 대응
- [x] debug: 테이블 수용 인원, outside 대기 동행 수

## Phase 6 — QA ✅

- [x] 4인 + 대기의자 1 → 대표+동행1 inside, 동행2 outside
- [x] 대기의자 비면 outside 동행 순차 입장
- [x] 4석 테이블 주문·퇴장 동기화

### QA 재현 (F3 디버그)

1. **영업 시작** 후 F3 → `4인 단체` → `대기의자1` 클릭
2. 대표 입장 후 **QA리포트**에서 `시나리오1 패턴` 확인
3. 대기 동행 1명이 카운터로 이동해 의자가 비면 **pending 동행 순차 입장** (`시나리오2`)
4. 4인 주문 수락 → 식사 완료 시 **4명 동시 퇴장** (`시나리오3`)

### 코드 수정 (QA 중 발견)

- `on_group_member_meal_finished`: 식사 중인 멤버만 동기화 퇴장
- `_assign_group_companion_order`: pending outside 동행을 주문 시 우선 배정 (중복 스폰 방지)

---

## 작업 순서

```
Phase 0 → Phase 1 → Phase 2(입장 정책 포함) → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

PR 제안: **PR1** = Phase 0–1, **PR2** = Phase 2–3 + 입장 정책, **PR3** = Phase 4–5.
