# [GDD] 중세 여관 경영 시뮬레이션: 'Innkeeper's Legacy' (가제)

이 문서는 1인 개발을 위한 중세 여관 경영 게임의 **기획(GDD)** 과 **Godot 구현 가이드**를 함께 담습니다.  
`welcome-traveller` 저장소의 현재 코드 상태를 반영하며, *(기획)* / **(구현)** / *(미구현)* 으로 구분합니다.

## 1. 프로젝트 개요

- **저장소:** `welcome-traveller` (Godot 4.x)
- **장르:** 2D 탑다운 경영 시뮬레이션
- **핵심 루프:** [수집/농사] -> [요리 개발/판매] -> [수익 창출] -> [여관 확장/업그레이드] -> [평판 관리]
- **현재 플레이 가능 루프 (구현):** 건설·가구 배치 → 영업 시작 → 손님 접대(식사/숙박) → 마감·정산 → 다음 날
- **세계관 핵심:** 여관은 왕국 교역로의 **허브(Hub)** — 상인, 수도사, 도적, 귀족 등이 오가며 소문·의뢰·이야기가 쌓이는 공간.
- **개발 엔진:** Godot — 2D 타일·프로시저럴 드로잉, `NavigationAgent2D`, GDScript, Autoload 싱글톤
- **해상도:** 1280×720, 정수 스케일 뷰포트 (`DisplayManager`, `ResolutionPresets`)
- **활성 뷰:** `OUTSIDE`(야외 줄) · `INN_F1`(1층 운영) — 2·3층·지하는 ID만 정의, 콘텐츠 미구현

## 2. 게임 모드
- **스토리 모드:** 단계별 퀘스트를 수행하여 가문의 빚을 갚고 왕실 인증 여관으로 성장시키는 목표 지향 모드.
  - **채권자 NPC:** 빚의 채권자가 정기적으로 등장. 매주 이자 상환, 협상, 특별 의뢰를 통해 긴장감 유지.
- **무한 모드:** 파산 없이 최대한 오랫동안 경영하여 왕국 랭킹 1위를 달성하는 기록 지향 모드.
- **유산(Legacy) 메타:** 한 판이 끝나도 해금된 레시피, 인테리어 테마, 손님 도감은 다음 판에 이월되어 재플레이 동기 제공.

## 3. 핵심 시스템

### A. 경제 및 경영

#### 기획
- **대출 시스템:** 초기 자금 확보 가능, 이자 부담 존재.
- **파산 조건:** 7일 연속 적자 발생 시 게임 오버.
- **경고 주간(Warning Week):** 7일 연속 적자 직전, 손님 감소·직원 불만 등 패널티가 선행 발생하여 갑작스러운 패배 방지.
- **야간 vs 주간 이원화:** 주간 식당·마을 거래 / 야간 숙박·암시장. *(숙박 FSM만 구현)*
- **동적 가격·수요:** 날씨, 이벤트, 평판에 따른 메뉴별 수요. *(미구현)*
- **공급망:** 인근 마을·항구 주 1회 거래 계약. *(곡물 시장만 구현)*

#### 구현 (`EconomyManager`, `MarketService`, `FoodStorage`)

| 항목 | 값 / 동작 |
| :--- | :--- |
| 시작 골드 | 320 |
| 시작 대출 | 200 |
| 일일 유지비 | 8골드 (`DAILY_UPKEEP`) |
| 대출 이자 | 잔액의 5%/일 (`LOAN_INTEREST_RATE`) |
| 파산 | 골드 < 0 이 **3일 연속** (`BANKRUPT_NEGATIVE_GOLD_DAYS`) |
| 경고 | 골드 < 0이면 `is_warning_week()` — 정산 팝업에 N/3일 표시 |
| 식재료 시작량 | 100 (`FoodStorage.STARTING_FOOD`) |
| 시장 | 곡물 배치 주문 (`MarketConstants`), 영업 시작 시 결제·배송 (`MarketService.try_settle_pending`) |

- **평판 (`ReputationManager`):** 시작 3.2/5.0, 리뷰 누적 평균. 스폰 간격 6~18초 (`get_spawn_interval()` — 평판 높을수록 손님 빈도↑).
- **매출 기록:** `EconomyManager.record_sale()` — 식사·숙박 결제 시. `record_expense()` — 건설·시장·유지비·이자.

### B. 컨텐츠 구성

#### 기획
- **여관 확장 및 인테리어:** 1~3층 확장, 테마별 고객층 변화.
- **요리:** 레시피 개발·실험·전승. *(기초 메뉴 2종 + 가마솥 업그레이드만 구현)*
- **농사·테루아·보관·부패:** *(미구현)*

#### 구현 — 건설·가구·미관

**게임 모드 (`GameModes`)**
- `PLAY` — 손님·직원 시뮬, 엔티티 클릭
- `BUILD` — 바닥·벽·문 타일 페인트 (골드 소모)
- `FURNITURE` — 가구 배치·회전(R)·제거(RMB)

**배치 가능 가구 (`FurnitureCatalog.playable_def_ids`)**

| def_id | 이름 | 용도 |
| :--- | :--- | :--- |
| `counter` | 카운터 | 손님 주문 접수 (필수) |
| `chair` | 의자 | 식사 좌석 (테이블 인접) |
| `table` | 테이블 | 2×1, 그룹 식사 앵커 |
| `waiting_chair` | 대기의자 | 카운터 줄·그룹 동행 대기 |
| `bed` | 침대 | 숙박 |
| `cauldron` | 가마솥 | 주방 — 메뉴·만족도 보너스 |
| `barrel` | 통 | 장식·미관 |
| `room_door` | 방문 | 내부 구역 분리 |

**미관 (`RoomAestheticsService`)**
- 구역(`RoomRegionService`)별 가구 미관 점수 + 오염(`FilthService`) 합산
- 손님 만족도 보너스: 구역 점수 ≥2.0 → +0.10, ≤-2.0 → -0.16
- 손님 패널·가구 패널에 구역 미관 표시

**오염 (`FilthService`)**
- 식사 후 빈 그릇(`FOOD_SCRAP`) 테이블 인접 스폰
- 여관주인 `CLEAN` 업무로 제거 — 미관·위생에 반영

**기본 레이아웃 시드**
- `GridLayoutSeeder` — 1층 바닥·벽·문
- `FurnitureLayoutSeeder` — 카운터, 4인 테이블+의자 4, 대기의자 4, 가마솥 등 (신규 게임 시)

### C. 이벤트 및 환경 변수
- **계절·축제 캘린더:** 수확제, 왕실 사냥, 성탄 등 고정 이벤트로 메뉴·손님 유형·물가 변화. 복합 환경(전쟁 + 가뭄 등)은 캘린더에 사전 표시.
- **환경 이벤트:** 전쟁(물가 상승), 가뭄(농작물 감소), 태풍, 불량배 난입 등.
- **특수 이벤트:** VIP 방문, 왕실 연회 의뢰 등.
- **선택형 이벤트:**

| 이벤트 | 효과 | 플레이어 선택 |
| :--- | :--- | :--- |
| **역병** | 손님 감소, 약초 수요↑ | 문 닫기 vs 위험 수익 |
| **왕실 사절** | 단기 평판 폭등 기회 | 고급 재료 투입 vs 저렴하게 대접 |
| **도적 협박** | 매일 "보호비" 요구 | 경비 고용 / 신고 / 협상 |
| **순례 대열** | 저마진·대량 손님 | 무료 수프 vs 평판·축복 버프 |

- **연쇄 이벤트 체인:** 2~3단계로 설계. (예: 가뭄 → 곡물 가격↑ → 빵 폭동 → 왕실 빵 배급 의뢰)
- **게스트북 연쇄:** 특정 손님 조합(예: 용병 3명 동일 방) 시 후속 이벤트 발생.

### D. 내러티브 및 세계관
- **허브 NPC:** 상인, 수도사, 도적, 귀족 등이 정기적으로 등장하며 대화·의뢰·소문 제공.
- **게스트북(Guestbook):** VIP·용병·행상인 등 손님의 짧은 일기·평이 누적. 세계관 몰입 및 힌트(레시피, 이벤트) 제공.
- **채권자 서사:** 스토리 모드에서 빚 상환·협상·특별 의뢰가 메인 퀘스트 라인과 교차.

### E. 소문(Spread) 시스템 *(기획)*
- 만족/불만 손님이 마을에 소문을 퍼뜨림 → 며칠 뒤 특정 유형 손님 증감.
- 평판·게스트북·손님 AI Memory와 연동.

### F. 구현 시스템 — 시간·영업

**게임 페이즈 (`GamePhases`)**

| 페이즈 | 설명 | 시간 흐름 |
| :--- | :--- | :--- |
| `PRE_OPEN` | 영업 준비 | 정지 (일시정지) |
| `OPEN` | 영업 중 | 흐름 (배속 가능) |
| `CLOSING` | 마감 처리 | 흐름 (최대 2시간) |
| `SETTLEMENT` | 일일 정산 UI | 정지 |
| `GAME_OVER` | 파산 | 정지 |

**영업 시간 (`GameClock`)**
- 기본 12:00~22:00 (`DEFAULT_OPEN_HOUR` / `DEFAULT_CLOSE_HOUR`) — HUD 영업시간 패널에서 예약 변경 가능
- 1 게임시간 = 36실초 (`SECONDS_PER_HOUR`)
- 마감 후 `CLOSING` 2시간 → 잔여 손님 처리 후 `SETTLEMENT`

**일일 정산 데이터 (`DayStatsService.build_summary`)**
- `guests_total`, `meals_served`, `lodgings_served`
- `food_start` / `food_end` / `food_delta`
- `exit_reason_counts` — `CustomerExitReasons` (인내심 소진, 좌석 부족 등)

## 4. AI 에이전트 설계 가이드 (NPC 및 고객)
게임의 생동감을 위해 각 NPC는 독립적인 AI 에이전트로서 행동합니다.

### A. 고객 AI (Customer Agent)

#### FSM 상태 (`CustomerStates.Id`) — 구현

| 상태 | 설명 |
| :--- | :--- |
| `TO_COUNTER` | 입구 → 카운터 이동 |
| `REQUEST_PENDING` | 상담석에서 요청 확인 (여관주인 접수 대기) |
| `TO_QUEUE_SLOT` / `WAITING_IN_QUEUE` | 카운터 줄·대기의자 슬롯 |
| `WAITING_AT_COUNTER` | 카운터 맨 앞 주문 대기 |
| `TO_CHAIR` / `EATING` | 식사 좌석 이동·식사 (0.5~1h) |
| `TO_BED` / `DROPPING_BAGS` / `SLEEPING` | 숙박 |
| `TO_BED_AFTER_MEAL` | 식사+숙박 콤보 후 침대 복귀 |
| `LEAVING` / `DONE` | 퇴장 |

**주문 유형 (`CustomerOrderTypes`)**
- `FOOD` — 식사만
- `LODGING` — 숙박만 *(야간 메뉴 `MenuCatalog.get_night_menu`)*
- `FOOD_AND_LODGING` — 당일 식사 후 숙박

**페르소나 (`CustomerPersonas`)** — Traveler / Merchant / Noble / Mercenary  
팁 배율: Noble 1.6×, Merchant 1.2×, Mercenary 0.9×

**욕구 (`CustomerNeeds`)** — hunger, sleep, fatigue, cleanliness, fun, health (0~100)  
상태별 tick rate 차등. 인내심(`patience`, max 100)은 대기·식사 대기 시 감소:
- 대기의자: 2/5분
- 카운터: 5/5분
- 음식 미서빙: 8/5분

**만족도·리뷰**
- 조리 품질(`FoodQuality`), 주방 업그레이드(`KitchenUpgradeService`), 구역 미관 보너스 반영
- 퇴장 시 `ReputationManager.add_review()` — HUD 별점·최근 리뷰 알림

**그룹 식사 (2~4인)** — `GroupDiningConstants`, `CustomerService`  
→ §7.C 참고

**미구현:** Memory(재방문), RumorSystem 연동

### B. 직원 AI (Staff Agent)

#### 구현 — 여관주인 1인 (`StaffService` + `InnkeeperEntity`)

**업무 종류 (`StaffTasks`)**

| Task | 설명 |
| :--- | :--- |
| `COUNTER` | 카운터 상주 |
| `TAKE_ORDER` | 맨 앞 손님 주문 접수 → `CustomerService.complete_take_order` |
| `COOK` | `KitchenService` 큐에서 조리 (최대 4동시, 4초/인분) |
| `SERVE` | 완료 음식 테이블 배달 (`TableFoodService`) |
| `CLEAN` | `FilthService` 오염 제거 |
| `REST` | 근무 외 휴식 |

**우선순위 (기획 vs 구현)**  
기획: 청소 > 요리 > 서빙 > 농사.  
구현: `StaffService` job queue — 손님 스폰·주문·조리 완료·오염 발생 시 `schedule_work()`로 재배정. 카운터 배치 최대 4명 일괄 접수(`MAX_COUNTER_BATCH_SIZE`).

**근무 시간:** `GameClock` 12~22시 (`is_work_hours`). 영업 외 `REST`.

#### 미구현
- Traits, 성장·이탈, 다중 직원, 시너지

## 5. 메타 진행 및 무한 모드

### A. 왕국 랭킹 (무한 모드)
- 총 수익만이 아닌 **복합 점수:** 평판, 위생, 독창 메뉴, 지속 가능성(비축·자급률) 등.
- **시즌 테마:** 매주 다른 최적화 목표. (예: "이번 시즌: 지속 가능 경영")

### B. 도전 과제
- **데일리/위클리:** "3일 연속 5성", "단일 요리 100인분" 등 단기 목표.
- 모바일 UI(Phase 3)와 연동하여 접속 동기 제공.

### C. 유산(Legacy) 이월
- 해금 항목: 레시피, 인테리어 테마, 손님 도감, 직원 Traits 풀.
- 스토리·무한 모드 공통 적용.

## 6. UX 설계

### A. 여관장의 아침 브리핑
- ~~하루 시작 전 **1장 요약** 제공~~ → **현재 구현:** `PRE_OPEN` 단계에서 HUD **[영업시작]** 버튼으로 영업 개시 (`GameTimeManager.start_open_day()`).
- 아침 브리핑 팝업(`morning_briefing`)은 **deprecated** — 시장 결제·영업 시작은 HUD에서 처리.
- 하루 종료 시 **일일 정산 팝업** (`day_settlement_popup`) — 손님·식사·숙박·재고 변동·퇴장 사유 요약.

### B. 시간 스케일
- 바쁜 날/한가한 날에 **가속·일시정지** 지원. 1·2·3키 / 스페이스(일시정지), HUD 하단 컨트롤.
- **영업 페이즈:** `PRE_OPEN` → `OPEN` → `CLOSING` → `SETTLEMENT` → 다음 날 `PRE_OPEN`.

### C. 실패도 콘텐츠
- 경고 주간, 채권자 압박, 직원 이탈 예고 등 **패배 전 피드백 루프** 제공. *(기획)*
- 게임 오버 시 게스트북 하이라이트·유산 해금 요약 표시. *(기획)*

### D. 플레이 HUD (구현) — `player_hud.gd`

**상단 바**
- 골드, 평판 별점(5점 만점, 소수 2자리), 설정

**시간 패널 (상단 중앙)**
- N일차 · 영업 상태 / 시각 · 배속
- 손님 수 (안쪽 활성 인원)
- **대기 줄 요약** (`CustomerService.get_player_queue_summary`) — 야외·카운터·pending·단체석·대기의자

**좌하단 정보 패널** (`CustomerPanel` — 손님·직원·음식·가구 공용)
- **손님 클릭:** 제목 `ID · N인 대표/동행`, 상세 — 분류·인내심·만족도·구역 미관·그룹·욕구 6종·활동 상태
- **가구 클릭:** 이름·사용자(의자/대기의자/침대/가마솥 점유 손님)·미관 점수
- **여관주인 클릭:** 근무 상태·현재 업무
- **테이블 음식 클릭:** 메뉴·품질 정보

**우하단**
- 시간 컨트롤: 1x / 2x / 3x / 정지
- 시장 버튼 → 곡물 주문·예약 관리 (`MarketService`)

**알림 (`NoticeLabel`, 4초)**
- 주문 거절: `손님ID · N인 대표 퇴장: 사유`
- 그룹 부분 입장: `N인 일행 중 M명 야외 대기`
- 리뷰, 시장 배송·취소 등

**단축키**
- `B` — 건설 모드 / `F` — 가구 모드 / 플레이 복귀
- `F3` — 디버그 HUD
- `1` `2` `3` — 배속 / `Space` — 일시정지 (영업 중)

### E. 입력·카메라
- `grid_input_controller.gd` — 모드별 클릭: 건설 페인트, 가구 배치, 플레이 선택(손님·가구·직원)
- `camera_controller.gd` — 팬·줌
- 선택 우선순위: 음식 > 손님 > 직원 > 가구 (동시 패널은 하나만 표시)

## 7. Godot 구현 가이드

### A. 프로젝트 디렉터리

```
welcome-traveller/
├── autoload/           # 싱글톤 서비스 (CustomerService, EventBus, …)
├── scenes/
│   ├── main.tscn       # 루트 — view, HUD, 정산 팝업
│   ├── entities/       # customer, innkeeper, outside_customer
│   ├── ui/             # player_hud, debug_hud, build_toolbar, settings
│   └── views/          # view_root, outside_view_root
├── scripts/
│   ├── core/           # 도메인 상수·헬퍼 (class_name)
│   ├── entities/       # CharacterBody2D FSM
│   ├── input/          # grid_input, camera
│   ├── ui/             # HUD·팝업 스크립트
│   └── views/          # 렌더러·고스트
├── assets/             # tiles, character, chair_directions
└── docs/
    └── group_dining_plan.md
```

### B. 아키텍처 (현재 코드베이스)

**렌더·입력**
- 그리드: `BuildingGrid` + `CellData` (바닥·벽·문 슬롯)
- 경로: `NavService` → `FloorPathfinder` / `NavPolygonBuilder` — 가구·벽 변경 시 재빌드
- 레이아웃 쿼리: `InnLayoutHelper` — 카운터·입구·좌석·침대·N석 테이블 탐색
- 뷰: `ViewManager` — `ViewRoot` / `OutsideViewRoot`
- 모드: `GameModeManager` — PLAY / BUILD / FURNITURE

**Autoload 싱글톤 (전체)**

| Autoload | 역할 |
| :--- | :--- |
| `EventBus` | 전역 시그널 (§7.I) |
| `DebugService` | F3 디버그 모드 |
| `DisplayManager` | 해상도 프리셋 |
| `GameModeManager` | 플레이/건설/가구 |
| `DayNightManager` | 주·야 주기 (배경) |
| `ThemeService` | 인테리어 테마 |
| `GridService` | 타일 저장·로드 |
| `RoomRegionService` | 방 구역 ID |
| `RoomAestheticsService` | 구역 미관 점수 |
| `FilthService` | 오염 스폰·청소 |
| `ViewManager` | 뷰 전환 |
| `FurnitureService` | 가구 인스턴스·선택 |
| `NavService` | 내비 메시 |
| `EntityService` | 유닛(적) — 디버그용 |
| `GameTimeManager` | 페이즈·배속·일일 루프 |
| `GameClock` | 시각·영업시간 |
| `EconomyManager` | 골드·대출·정산 |
| `ReputationManager` | 평판·리뷰 |
| `CustomerService` | 손님·큐·그룹 |
| `StaffService` | 여관주인 job queue |
| `KitchenService` | pending→cooking→ready |
| `TableFoodService` | 테이블 음식 비주얼 |
| `FoodStorage` | 식재료 재고 |
| `MarketService` | 곡물 주문 |
| `DayStatsService` | 당일 통계 |

**핵심 엔티티 씬**
- `scenes/entities/customer_entity.tscn` → `CustomerEntity`
- `scenes/entities/outside_customer_entity.tscn` → `OutsideCustomerEntity`
- `scenes/entities/innkeeper_entity.tscn` → `InnkeeperEntity`

**데이터·상수 (`scripts/core/`, class_name)**
- 고객: `CustomerStates`, `CustomerOrderTypes`, `CustomerPersonas`, `CustomerNeeds`, `CustomerExitReasons`, `MenuCatalog`, `GroupDiningConstants`
- 가구: `FurnitureCatalog`, `FurnitureInstance`, `FurnitureLayoutSeeder`, `FurnitureInfoHelper`
- 주방: `KitchenUpgradeService`, `FoodQuality`, `FoodQualityResolver`
- 그리드: `GridCoord`, `CellData`, `GridLayoutSeeder`, `GridLayoutRules`
- 기타: `GamePhases`, `GameModes`, `ViewIds`, `InnLayoutHelper`

### C. 손님 파이프라인 (구현 상세)

```
[OutsideView] spawn → _outside_queue (최대 6그룹 압력)
       ↓ _try_start_next_outside_admission (대기의자/카운터 여유)
[문] _entering_outside_customer (1명)
       ↓ _complete_outside_admission
[Inn F1] CustomerEntity spawn → TO_COUNTER
       ↓ (그룹) _admit_inside_group_waiting_companions / _pending_outside_companions
_counter_queue + waiting_chair 예약
       ↓ StaffService TAKE_ORDER
complete_take_order → chair/bed 예약 → KitchenService.enqueue
       ↓ COOK → SERVE
EATING → 리뷰·결제 → LEAVING
```

**`CustomerService` 주요 상태 필드**
- `_outside_queue`, `_entering_outside_customer`
- `_counter_queue`, `_waiting_chair_reservations`, `_furniture_reservations`
- `_pending_outside_companions: group_id → OutsideCustomerEntity[]`
- `_customers: id → CustomerEntity`

**스폰 조건 (`_try_spawn_customer`)**
- 영업 중·시간 흐름·오픈 시간·내비 동기화·서비스 공간·카운터·빈 의자 존재
- 총 압력 < 6, outside 큐 < `MAX_OUTSIDE_QUEUE_SIZE`(6)
- 간격: `ReputationManager.get_spawn_interval()` (6~18초)

**주문 실패 사유 (`_get_order_block_reason`)**
- 식재료 부족, N인 단체석 부족, 침대 부족, 영업 종료 등 → `_fail_group_order` / `on_order_rejected`

### D. N인 그룹 식사 (구현 완료)

상세 플랜·QA: `docs/group_dining_plan.md`

**상수 (`GroupDiningConstants`)**
- 발생 확률 35% (`GROUP_DINING_CHANCE`)
- 인원 가중: 2인 55% / 3인 30% / 4인 15%
- 입장 정책: `PARTIAL_WITH_OUTSIDE_WAIT` (대표 우선 입장)

**입장 정책**
- `_has_counter_entry_capacity()` — partial 모드: 카운터 비었거나 대기의자 1개 이상
- 대표 입장 후 `_admit_inside_group_waiting_companions()` — 동행을 waiting_chair에 최대한 배치
- 못 들어온 동행 → `_pending_outside_companions` (outside NPC 유지, 인내심 대표와 동기화)
- 의자 비면 `_try_admit_outside_group_companions()` — FIFO 순차 inside waiting companion 스폰

**Outside 그룹 비주얼**
- `OutsideCustomerEntity.group_companions[]`, 오프셋 3종 (`OUTSIDE_GROUP_COMPANION_OFFSETS`)
- `reposition_as_group_cluster()` — pending 클러스터 재배치

**N석 탐색 (`InnLayoutHelper`)**
- `find_available_chairs_for_table(count)` — 한 테이블에 인접 의자 N개
- `find_max_seatable_group_size()` / `get_max_group_size_for_table()`
- `count_waiting_chairs()` / `get_table_group_capacity_entries()` — HUD·디버그

**주문 시 동행 배정 (`_assign_group_companion_order`)**
1. 안쪽 대기 동행 (`is_group_companion_waiting_for_leader`)
2. pending outside NPC (persona 승계, queue_free)
3. `_spawn_group_companion` (신규 엔티티 — 최후 수단)

**퇴장 동기화 (`on_group_member_meal_finished`)**
- `EATING` 상태 식사 손님 전원 `group_meal_finished` 후 `complete_group_food_exit()` 일괄 호출
- 인원 미달 시에도 **식사 중인 멤버만** 동기화 (조기 개별 퇴장 버그 수정)

### E. 주방·메뉴 파이프라인

**메뉴 (`KitchenUpgradeService.FOOD_MENU`)**
| id | 이름 | 가격 | 재료 |
| :--- | :--- | :--- | :--- |
| bread | 빵 | 1 | 1 |
| basic_meal | 기본음식 | 3 | 2 |

**조리 큐 (`KitchenService`)**
- `pending` → `cooking`(최대 4, 4초) → `ready` → 서빙
- 그룹 주문 시 인분 = `group_size` (대표 기준)
- `FoodQualityResolver` — 가마솧·난이도 기반 품질 → 만족도 보너스

### F. 가구 선택 UI

| 파일 | 역할 |
| :--- | :--- |
| `autoload/furniture_service.gd` | `select_instance()`, `EventBus.furniture_selected` |
| `scripts/views/furniture_visual.gd` | 의자=골드 링, 기타=골드 아웃라인 |
| `scripts/core/furniture/furniture_info_helper.gd` | 패널·사용자 조회 (`chair`/`waiting_chair`/`bed`/`cauldron`) |
| `scripts/input/grid_input_controller.gd` | PLAY 모드 클릭 hit-test |
| `scripts/ui/player_hud.gd` | `_furniture_panel` 좌하단 |

### G. 일일 루프 (타임라인)

```
PRE_OPEN (정지)
  │ [영업시작] → MarketService.try_settle_pending()
  │              DayStatsService.begin_day()
  ▼
OPEN (12:00~22:00, 배속 가능)
  │ 손님 스폰·서비스
  │ [마감] 또는 22:00 도달
  ▼
CLOSING (최대 2h, 잔여 손님 처리)
  ▼
SETTLEMENT — day_settlement_popup
  │ EconomyManager.end_of_day_settlement()
  │ DayStatsService.build_summary() 병합
  │ [확인] → current_day++, PRE_OPEN
  ▼
(골드<0 3일) → GAME_OVER
```

### H. 디버그·QA (F3 — `debug_hud.gd`)

| 기능 | 설명 |
| :--- | :--- |
| 줄 상태 | `get_debug_queue_status_text()` — 야외·pending·카운터·주방·테이블 수용 |
| 그룹 QA 버튼 | `4인 단체` / `대기의자1` / `의자해제` / `QA리포트` |
| `spawn_debug_group_outside(4)` | 확률 무시 4인 그룹 스폰 |
| `debug_set_waiting_chair_limit(1)` | QA 시나리오1 재현 |
| `get_group_qa_report()` | 시나리오1/2/3 패턴 자동 판별 |

기타: 손님 강제 스폰, 건설 페인트, 테마·가구 배치, 저장/로드, 유닛 스폰

### I. EventBus 주요 시그널

| 시그널 | 용도 |
| :--- | :--- |
| `day_started` / `day_ended` / `day_settlement_requested` | 일일 루프 |
| `customer_spawned` / `customer_selected` / `customer_order_rejected` | 손님 |
| `group_outside_wait_notice` | N인 부분 입장 HUD 알림 |
| `furniture_placed` / `furniture_selected` | 레이아웃·UI |
| `navigation_map_ready` | 경로 재빌드 후 손님 활성화 |
| `economy_changed` / `reputation_changed` / `food_changed` | HUD 갱신 |
| `market_delivered` / `market_orders_cancelled` | 시장 |

### J. 데이터 흐름 (개요)

```
GameClock / GameTimeManager (페이즈·시간)
     ↓
CustomerService (스폰·큐·그룹 입장)
     ↓
StaffService + KitchenService (주문·조리)
     ↓
CustomerEntity FSM (식사·리뷰·퇴장)
     ↓
DayStatsService + EconomyManager + ReputationManager
     ↓
day_settlement_popup (일일 정산 UI)
```

*(미구현)* `GameCalendar`, `RumorSystem`

### K. 기획 대비 미구현 Autoload·시스템

- `GameCalendar` — 계절, 축제, 이벤트 스케줄
- `RumorSystem` — 소문 전파, 손님 유형 증감
- 손님 Memory, 게스트북 UI, 채권자 NPC, Legacy 메타

## 8. 승리 및 패배 조건

### 기획
| 모드 | 승리 조건 | 패배 조건 |
| :--- | :--- | :--- |
| **스토리** | 최종 퀘스트(왕실 인증) 달성 | 7일 연속 적자 / 평판 최저치 / 위생 사고 |
| **무한** | 매주 높은 랭킹 유지 / 시즌 1위 | 7일 연속 적자 / 폐업 |

### 구현 (`EconomyManager`)
- **파산:** 골드 < 0 이 **3일 연속** → `GamePhases.GAME_OVER`
- **경고:** 골드 < 0 첫날부터 정산 팝업에 `N/3일` 표시
- 스토리/무한 모드 분기·승리 조건 UI는 *(미구현)*

## 9. 개발 로드맵 (1인 개발 전략)

### 현재 진행 (welcome-traveller MVP+)

| 영역 | 상태 | 핵심 파일·동작 |
| :--- | :--- | :--- |
| 그리드·건설 | ✅ | `GridService`, `building_grid.gd` — 바닥/벽/문, 건설 비용 |
| 가구 배치 | ✅ | `FurnitureService`, `build_toolbar.gd` — 8종 가구, 회전·제거 |
| 가구 선택 UI | ✅ | `furniture_visual.gd`, `FurnitureInfoHelper`, `player_hud` 패널 |
| 구역·미관·오염 | ✅ | `RoomAestheticsService`, `FilthService` — 만족도·청소 업무 |
| 손님 FSM·대기열 | ✅ | `customer_entity.gd`, `customer_service.gd` — outside→카운터→서비스 |
| N인 그룹 식사 | ✅ | `group_dining_constants.gd`, `_pending_outside_companions`, QA 도구 |
| 직원·주방 | ✅ | `staff_service.gd`, `kitchen_service.gd` — 접수·조리(4동시)·서빙 |
| 메뉴·품질 | ✅ | `kitchen_upgrade_service.gd`, `food_quality.gd` — 빵/기본음식, 가마솥 |
| 경제·평판 | ✅ | `economy_manager.gd`, `reputation_manager.gd` — 대출·이자·리뷰 |
| 시장·식재료 | ✅ | `market_service.gd`, `food_storage.gd` — 곡물 배치 주문 |
| 일일 루프 | ✅ | `game_time_manager.gd`, `day_settlement_popup.gd` |
| 플레이 HUD | ✅ | `player_hud.gd` — 줄 요약, 알림, 시장, 영업시간 |
| 야외 뷰 | ✅ | `outside_view_root.gd` — 줄·파라랙스·건물 외관 |
| 저장/로드 | ✅ | `GridService` grid save, autoload `export_save_data` |
| 게스트북·소문 | ⬜ | 기획만 |
| 농사·테루아 | ⬜ | 기획만 |
| 2~3층·지하 플레이 | ⬜ | `ViewIds`만 정의 |
| 스토리·채권자·Legacy | ⬜ | 기획만 |

### Phase 1 — MVP
- 기본 경영 루프: 서빙 → 판매 → 수익. **(대부분 구현)**
- 고객 FSM (입장·주문·식사·퇴장), 기본 평판. **(구현)**
- ~~**아침 브리핑** UI~~ → **HUD [영업시작] + 일일 정산** 으로 대체. **(구현)**
- Autoload 골격: `EconomyManager`, `ReputationManager`. **(구현)**

### Phase 2 — 확장
- 여관 1~2층 확장, 인테리어 테마, 고객층 변화. *(1층·테마·미관 부분 구현)*
- 농사 + **테루아** 품질 등급.
- **야간 숙박** / 주간 식당 이원화. *(숙박 FSM은 있음, 야간 콘텐츠 이원화는 미구현)*
- **게스트북**, **소문 시스템** (기본).
- 직원 AI, Traits, 업무 우선순위. *(여관주인 1인 구현)*

### Phase 3 — 깊이
- 보관·부패, 공급망 거래. *(시장 곡물 주문만 구현)*
- 요리 실험·레시피 전승, 동적 가격·수요.
- 환경·선택형·연쇄 이벤트, **계절·축제 캘린더**.
- 직원 성장·이탈, 조합 시너지.
- 채권자 NPC, 스토리 퀘스트 라인.

### Phase 4 — 메타·플랫폼
- 무한 모드 **복합 랭킹**, 시즌 테마, 도전 과제.
- **Legacy** 이월, 손님 도감.
- 모바일 UI 최적화, 시간 스케일·가속. *(데스크톱 HUD·배속 구현)*
- AI 복잡도 상향 (Memory, Persona 태그 세분화). *(페르소나·욕구 기초만)*

### 우선순위 (다음 작업 권장)
1. **게스트북 + 소문** — AI·내러티브 대비 몰입감 높음.
2. **야간 숙박 / 주간 식당** — 동일 맵으로 콘텐츠 2배.
3. **계절 캘린더 + 보관·부패** — 농사·요리·환경 이벤트 통합.

### 관련 문서
- `docs/group_dining_plan.md` — N인 그룹 식사 구현·QA·입장 정책 상세

---

## 10. AI 에이전트 작업 가이드

새 기능·버그 수정 시 참고할 **코드 진입점**과 **규칙**입니다.

### A. 작업 전 확인
1. `GamePhases` / `GameModes` — 현재 페이즈·모드에서 코드가 실행되는지
2. `EventBus` — 기존 시그널 재사용 우선 (새 싱글톤 남발 금지)
3. `InnLayoutHelper` — 좌석·침대·카운터 탐색은 여기서, 중복 로직 금지
4. 그룹 손님 — `GroupDiningConstants`, `_pending_outside_companions` 흐름 유지

### B. 기능별 수정 위치

| 작업 | 주 파일 |
| :--- | :--- |
| 손님 행동·FSM | `scripts/entities/customer_entity.gd` |
| 스폰·큐·그룹 | `autoload/customer_service.gd` |
| 주문 접수·배정 | `customer_service.complete_take_order`, `staff_service.gd` |
| 조리·서빙 | `kitchen_service.gd`, `innkeeper_entity.gd` |
| 가구·레이아웃 | `furniture_service.gd`, `inn_layout_helper.gd` |
| HUD·알림 | `player_hud.gd`, `event_bus.gd` |
| 일일 루프 | `game_time_manager.gd`, `day_settlement_popup.gd` |
| 경제·평판 | `economy_manager.gd`, `reputation_manager.gd` |
| 디버그·QA | `debug_hud.gd`, `CustomerService.get_group_qa_report` |

### C. 그룹 식사 수정 시 체크리스트
- [ ] 대표-only 입장 (`uses_partial_outside_wait`)
- [ ] pending outside 인내심 동기화 (`_sync_pending_outside_companion_patience`)
- [ ] 주문 시 pending 우선 배정 (`_assign_group_companion_order`)
- [ ] 퇴장 동기화 (`on_group_member_meal_finished` — EATING 멤버만)
- [ ] HUD/거절 메시지 N인 표기 (`get_customer_display_label`)
- [ ] F3 QA 리포트 시나리오 패턴 유지

### D. 코딩 규칙
- 도메인 상수는 `scripts/core/**`에 `class_name`으로 — autoload에 매직넘버 금지
- Godot 미등록 class_name은 `preload` 사용 (`FurnitureInfoHelper` 등)
- UI 문자열 한국어 유지
- 최소 diff — 요청 범위 밖 리팩터 금지

### E. 테스트 (수동)
1. F3 → 영업 시작 → `4인 단체` + `대기의자1` → QA리포트
2. 주문·식사·동시 퇴장 확인
3. 가구 클릭 → 패널·하이라이트
4. 마감 → 정산 팝업 수치

---

*본 문서는 Godot 엔진 환경에서의 개발을 전제로 작성되었습니다.*  
*최종 업데이트: welcome-traveller — 그룹 식사·가구 선택·일일 정산·HUD·디렉터리·AI 가이드 (2026)*
