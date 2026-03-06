import SwiftUI

struct BusinessCardTileView: View {
    let card: BusinessCard
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                LocalCardImageView(imagePath: card.imageLocalPath, fallbackPath: nil)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Button(action: onToggleFavorite) {
                    Image(systemName: card.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(card.isFavorite ? .yellow : .white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(card.name ?? "이름 없음")
                    .font(.title3.weight(.semibold))
                Text(card.company ?? "회사 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let jobTitle = card.jobTitle, !jobTitle.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "briefcase.fill")
                            .font(.caption)
                        Text(jobTitle)
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 8) {
                    if let phone = card.phone, !phone.isEmpty {
                        infoChip(system: "phone.fill", text: phone)
                    }
                    if let email = card.email, !email.isEmpty {
                        infoChip(system: "envelope.fill", text: email)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }

    private func infoChip(system: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.05), in: Capsule())
    }
}
