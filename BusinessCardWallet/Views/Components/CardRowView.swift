import SwiftUI

struct CardRowView: View {
    let card: BusinessCard
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            LocalCardImageView(
                imagePath: card.thumbnailLocalPath ?? card.imageLocalPath,
                fallbackPath: card.thumbnailLocalPath == nil ? nil : card.imageLocalPath
            )
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(card.name ?? "이름 없음")
                    .font(.headline.weight(.semibold))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
    }
}
