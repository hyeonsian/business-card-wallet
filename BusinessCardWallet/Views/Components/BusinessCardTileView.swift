import SwiftUI

struct BusinessCardTileView: View {
    let card: BusinessCard
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.gray.opacity(0.15))
                    .frame(height: 220)
                    .overlay(
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    )

                Button(action: onToggleFavorite) {
                    Image(systemName: card.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(card.isFavorite ? .yellow : .white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "이름 없음")
                    .font(.headline)
                Text(card.company ?? "회사 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let jobTitle = card.jobTitle, !jobTitle.isEmpty {
                    Text(jobTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(8)
    }
}
