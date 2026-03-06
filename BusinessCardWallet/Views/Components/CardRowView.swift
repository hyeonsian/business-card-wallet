import SwiftUI

struct CardRowView: View {
    let card: BusinessCard
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            LocalCardImageView(imagePath: card.imageLocalPath)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name ?? "이름 없음")
                    .font(.headline)
                Text(card.company ?? "회사 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(card.email ?? card.phone ?? "연락처 정보 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: card.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(card.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
