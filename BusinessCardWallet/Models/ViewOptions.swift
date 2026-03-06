import Foundation

enum CardSortOption: String, CaseIterable, Identifiable {
    case latest = "최신순"
    case alphabetical = "A-Z"

    var id: String { rawValue }
}

enum CardViewMode: String, CaseIterable, Identifiable {
    case card = "카드형"
    case list = "리스트형"

    var id: String { rawValue }
}

struct NewCardDraft {
    var imageLocalPath: String
    var thumbnailLocalPath: String?
    var fullText: String
    var name: String
    var company: String
    var jobTitle: String
    var phone: String
    var email: String
    var address: String
    var website: String
    var memo: String
}
