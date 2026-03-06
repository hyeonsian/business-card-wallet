# SwiftUI 화면 구조 초안

## 1) 화면 트리
```text
App
└─ RootTabView (MVP는 단일 탭도 가능)
   └─ WalletHomeView
      ├─ TopControlBar
      │  ├─ SortMenuButton (...)
      │  ├─ GroupHorizontalSelector (기본 그룹 + 사용자 그룹)
      │  └─ AddGroupButton (+)
      ├─ SearchBar
      ├─ FavoriteFilterToggle (그룹 내 즐겨찾기만)
      ├─ ViewModeSwitcher (Card / List)
      ├─ CardPagerView or CardListView
      └─ FloatingScanButton (+ Scan)

Modal / Sheet
- ScanCaptureView (카메라/사진첩)
- OCRReviewEditView (인식 결과 검수/수정)
- CardDetailView (상세 보기/편집)
- GroupEditorView (그룹 생성/수정)
```

## 2) 핵심 화면 책임
- `WalletHomeView`
  - 선택 그룹/정렬/필터/검색 상태를 보유
  - 카드형/리스트형 전환
  - 스캔 플로우 진입
- `CardPagerView`
  - 카드 스와이프 탐색
  - 이미지 상단 별 버튼 토글
- `CardListView`
  - 대량 명함 스캔 결과를 빠르게 훑는 리스트 모드
- `OCRReviewEditView`
  - OCR 결과를 저장 전 최종 교정
- `CardDetailView`
  - 저장된 명함 정보 수정 및 삭제

## 3) ViewModel 구조 제안
- `WalletHomeViewModel`
  - `selectedGroupID`, `sortOption`, `viewMode`, `searchQuery`, `showFavoritesOnly`
  - `filteredCards` 계산
  - `toggleFavorite(cardID:)`, `createGroup(name:)`
- `ScanFlowViewModel`
  - 이미지 입력/전처리/OCR 실행/필드 매핑
  - `saveCard()`
- `CardDetailViewModel`
  - 상세 편집/저장/삭제

## 4) 네비게이션/상태 관리
- 기본: `NavigationStack` + `sheet` + `fullScreenCover`
- 상태: SwiftData Query + ViewModel(`@StateObject`)
- 검색: `searchable(text:)` 또는 커스텀 SearchBar

## 5) UI 컴포넌트 우선순위
1. `TopControlBar`
2. `BusinessCardImageView` (별 버튼 오버레이 포함)
3. `BusinessCardInfoSection`
4. `CardPagerView` (TabView + paging style)
5. `CardRowView` (리스트 셀)

## 6) MVP 애니메이션 가이드
- 카드 전환: 기본 paging + 짧은 easing
- 별 토글: scale + opacity 150~200ms
- 그룹 전환: 목록 fade/slide 최소 전환
- 책 넘김 효과는 v2로 분리
