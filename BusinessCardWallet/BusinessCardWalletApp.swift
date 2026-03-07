import SwiftUI
import SwiftData

@main
struct BusinessCardWalletApp: App {
    init() {
        UIPageControl.appearance().currentPageIndicatorTintColor = .systemBlue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray3.withAlphaComponent(0.9)
    }

    var body: some Scene {
        WindowGroup {
            WalletHomeView()
        }
        .modelContainer(for: [CardGroup.self, BusinessCard.self])
    }
}
