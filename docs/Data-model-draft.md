# 데이터 모델 초안 (SwiftData 기준)

## 1) 엔티티 정의

### `CardGroup`
- 목적: 명함 그룹(카테고리) 관리
- 필드
  - `id: UUID`
  - `name: String`
  - `createdAt: Date`
  - `updatedAt: Date`
  - `isDefault: Bool`

### `BusinessCard`
- 목적: 명함 이미지 + 정규화된 주요 필드 + 원문 텍스트 저장
- 필드
  - `id: UUID`
  - `groupID: UUID`
  - `imageLocalPath: String`
  - `thumbnailLocalPath: String?`
  - `fullText: String` (OCR 전체 텍스트)
  - `name: String?`
  - `company: String?`
  - `jobTitle: String?`
  - `phone: String?`
  - `email: String?`
  - `address: String?`
  - `website: String?`
  - `memo: String?`
  - `isFavorite: Bool`
  - `createdAt: Date`
  - `updatedAt: Date`

### `OCRRawField` (선택)
- 목적: OCR 라인/신뢰도 저장(디버깅/재매핑/개선용)
- 필드
  - `id: UUID`
  - `cardID: UUID`
  - `text: String`
  - `confidence: Double`
  - `index: Int`

## 2) 인덱싱/조회 전략
- 정렬 인덱스
  - `BusinessCard.createdAt` (최신순)
  - `BusinessCard.name` (A-Z)
- 검색 대상
  - `name`, `company`, `jobTitle`, `phone`, `email`, `fullText`
- 필터 조건
  - 그룹: `groupID == selectedGroupID`
  - 즐겨찾기: `isFavorite == true`

## 3) Swift 타입 예시
```swift
import Foundation
import SwiftData

@Model
final class CardGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }
}

@Model
final class BusinessCard {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var imageLocalPath: String
    var thumbnailLocalPath: String?

    var fullText: String
    var name: String?
    var company: String?
    var jobTitle: String?
    var phone: String?
    var email: String?
    var address: String?
    var website: String?
    var memo: String?

    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        groupID: UUID,
        imageLocalPath: String,
        thumbnailLocalPath: String? = nil,
        fullText: String,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        website: String? = nil,
        memo: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.groupID = groupID
        self.imageLocalPath = imageLocalPath
        self.thumbnailLocalPath = thumbnailLocalPath
        self.fullText = fullText
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.phone = phone
        self.email = email
        self.address = address
        self.website = website
        self.memo = memo
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

## 4) 규칙/검증
- 기본 그룹 1개는 삭제 불가 (`isDefault == true`)
- 저장 시 `updatedAt` 자동 갱신
- OCR 필드가 비어도 `fullText`는 최대한 보존
- 중복 감지(선택): `name + company + phone` 유사도 기반 경고

## 5) 마이그레이션 고려
- v2에서 `Contact` 엔티티 분리 가능
- v2에서 클라우드 동기화 시 `serverID`, `syncStatus`, `lastSyncedAt` 추가
