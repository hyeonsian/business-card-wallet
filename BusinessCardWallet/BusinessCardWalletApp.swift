import SwiftUI
import SwiftData

@main
struct BusinessCardWalletApp: App {
    var body: some Scene {
        WindowGroup {
            WalletHomeView()
        }
        .modelContainer(for: [CardGroup.self, BusinessCard.self])
    }
}
