# Latte (working folder: `Caffeinated-Clone/`)

macOS 메뉴바 유틸리티 — Mac이 sleep으로 진입하지 않도록 막습니다.

> **Status**: Phase 1.0 implementation complete (session 3 of ~10). See [ROADMAP.md](ROADMAP.md) for the full plan and [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) for the next session entry point.
>
> **App name**: Latte. Folder will be renamed before first push.

## Documents

| Document | Purpose |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Multi-session execution plan + milestone gates |
| [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) | Where to pick up next session |
| [docs/design/01-PRD.md](docs/design/01-PRD.md) | Product requirements, target user, KPIs, scope, risks |
| [docs/design/02-architecture.md](docs/design/02-architecture.md) | Module structure, concurrency, contracts, dependency policy |
| [docs/design/03-state-machine.md](docs/design/03-state-machine.md) | Trigger priority + 6-state FSM + transition table |
| [docs/design/04-data-model.md](docs/design/04-data-model.md) | Persistence schema + migration plan |

**Phase 1 스코프**: 자동화(A) + 디자인(C). iOS 동반 앱(B)은 Phase 2에서 추가.

## 차별화 (vs Amphetamine)

### 자동화 (Package A)
- **EventKit 캘린더 연동** — 회의 시간 자동 ON
- **앱별 트리거** — Zoom·Teams·Final Cut 등 실행 시 자동 ON
- **Wi-Fi 트리거** — 특정 네트워크 연결 시 ON
- **Focus 모드 연동** — 업무 Focus 활성 시 ON
- **AppIntents/Shortcuts** — 자동화 앱 통합

### 디자인 (Package C)
- Liquid Glass (macOS 26) + Vibrancy fallback (macOS 13~25)
- 풍성한 마이크로 인터랙션 (커피 잔 채워짐, 김 애니메이션)
- 사용자 정의 메뉴바 아이콘

## 기술 스택

- **언어**: Swift 5.10
- **UI**: SwiftUI (`MenuBarExtra` macOS 13+)
- **최소 OS**: macOS 13 Ventura
- **프로젝트 생성**: XcodeGen (`project.yml` → `.xcodeproj`)
- **배포**: App Store ($2.99 일회성 일단 가정, Phase 2 후 $4.99 인상 예정)

## 셋업

### 1. 사전 요구사항

```bash
# XcodeGen 설치 (Xcode 프로젝트 생성용)
brew install xcodegen

# Xcode 15+ 설치 (App Store 또는 developer.apple.com)
xcode-select --install
```

### 2. Xcode 프로젝트 생성

```bash
cd "$(pwd)"  # 이 README가 있는 디렉토리
xcodegen generate
open Latte.xcodeproj
```

### 3. 서명 설정

Xcode에서:
1. `Latte` 타겟 → `Signing & Capabilities`
2. `Team` 선택 (Apple Developer 계정)
3. `Bundle Identifier`를 본인 것으로 변경 (예: `com.yourname.latte`)

### 4. 빌드 & 실행

`⌘R` 또는 Xcode 메뉴 → Product → Run

메뉴바에 커피잔 아이콘이 나타납니다. 클릭해서 토글하세요.

## 디렉토리 구조

```
Caffeinated-Clone/                    # working folder; rename to Latte/ before push
├── README.md
├── .gitignore
├── project.yml                       # XcodeGen 스펙 (target: Latte)
├── Sources/
│   ├── App/                          # @main + composition root
│   │   ├── LatteApp.swift
│   │   └── AppEnvironment.swift
│   ├── Core/                         # Pure logic, no SwiftUI
│   │   ├── AwakeManager.swift        # 6-state FSM
│   │   ├── AwakeDuration.swift
│   │   ├── PowerAssertion.swift      # IOKit wrapper + Mock
│   │   ├── SettingsStore.swift       # protocol + 2 impls
│   │   └── Logging.swift
│   ├── Triggers/                     # Package A (stubs in s3, real in s4)
│   │   ├── Trigger.swift             # protocol + types + MockTrigger
│   │   ├── TriggerCoordinator.swift
│   │   ├── CalendarTrigger.swift
│   │   ├── AppTrigger.swift
│   │   ├── WiFiTrigger.swift
│   │   └── FocusTrigger.swift
│   ├── Intents/
│   │   └── AwakeIntents.swift        # Toggle/Start/Stop + AppShortcuts
│   └── UI/
│       ├── Theme/Theme.swift
│       ├── Components/
│       │   ├── CoffeeCupView.swift
│       │   └── LiquidGlassModifier.swift
│       ├── MenuBar/
│       │   ├── MenuBarRoot.swift
│       │   ├── HeaderView.swift
│       │   └── DurationPickerRow.swift
│       └── Settings/
│           ├── SettingsRoot.swift
│           ├── GeneralTab.swift
│           ├── TriggersTab.swift
│           └── AboutTab.swift
├── Resources/
│   ├── Info.plist
│   └── Assets.xcassets/
├── Configuration/
│   └── Latte.entitlements
└── Tests/
    ├── AwakeManagerTests.swift       # cell-by-cell + 6 worked examples
    ├── AwakeDurationTests.swift
    ├── SettingsStoreTests.swift      # parametrized base class × 2 impls
    └── TriggerCoordinatorTests.swift
```

## 로드맵

### Phase 1.0 — MVP (M1, 1~2주) ✅ 코드 작성 완료 (session 3)
- [x] 6-state FSM (Asleep / AwakeUserIndefinite / AwakeUserTimed / AwakeTriggered / CoolingDown / Snoozed)
- [x] 메뉴바 토글 (즉시/타이머 — 5m/15m/30m/1h/2h/5h/indefinite)
- [x] AppIntents 기본 (Toggle/Start/Stop) + AppShortcuts
- [x] SettingsStore 프로토콜 + UserDefaults/InMemory 구현
- [x] 단위 테스트 (transition table cell-by-cell + 6 worked examples)
- [ ] LaunchAtLogin (`ServiceManagement`) — session 4 또는 6
- [ ] 메뉴바 아이콘 토글 상태 시각화 — session 5

### Phase 1.A — 자동화 (M2~M3, 2~3주)
- [ ] EventKit 캘린더 트리거 (회의 자동 ON)
- [ ] NSWorkspace 앱 실행 트리거
- [ ] CWWiFiClient Wi-Fi 트리거
- [ ] Focus 모드 연동 (App Intents shared mode)

### Phase 1.C — 디자인 (M3~M4, 1~2주)
- [ ] CoffeeCupView 정교화 (Canvas + TimelineView)
- [ ] Liquid Glass 적용 (macOS 26+) + fallback
- [ ] Settings 창 디자인 리뉴얼
- [ ] App Icon 제작

### Phase 1.QA & Release (M4, 1주)
- [ ] App Store Connect 메타데이터
- [ ] 스크린샷 (Light/Dark, 약 5장)
- [ ] Privacy Policy (GitHub Pages)
- [ ] Notarization & 심사 제출

### Phase 2 (출시 후, 매출 검증되면)
- [ ] iOS 동반 앱 (Package B)
- [ ] Apple Watch Complication
- [ ] iCloud 설정 동기화

## 라이선스

All rights reserved. (출시 전 결정 필요)
