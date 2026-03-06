import Foundation

@MainActor
final class WalletHomeViewModel: ObservableObject {
    @Published var selectedGroupID: UUID?
    @Published var sortOption: CardSortOption = .latest
    @Published var viewMode: CardViewMode = .card
    @Published var searchQuery: String = ""
    @Published var showFavoritesOnly: Bool = false

    @Published var isPresentingAddGroup = false
    @Published var newGroupName = ""

    @Published var isPresentingScan = false
    @Published var isPresentingOCRReview = false
    @Published var pendingDraft: NewCardDraft?

    func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
