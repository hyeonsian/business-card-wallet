import SwiftUI

struct BusinessCardTileView: View {
    let card: BusinessCard
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                LocalCardImageView(imagePath: card.imageLocalPath, fallbackPath: nil)
                    .aspectRatio(1.72, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))

                HStack {
                    Button(action: onToggleFavorite) {
                        Image(systemName: card.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(card.isFavorite ? .yellow : .white)
                            .padding(8)
                            .background(.black.opacity(0.45), in: Circle())
                    }

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.red.opacity(0.82), in: Circle())
                    }
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(card.name ?? "이름 없음")
                    .font(.title3.weight(.semibold))

                Text(card.company ?? "회사 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let jobTitle = card.jobTitle, !jobTitle.isEmpty {
                    labelChip(system: "briefcase.fill", text: jobTitle, tint: .blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(system: "phone.fill", title: "전화", value: card.phone)
                    infoRow(system: "envelope.fill", title: "이메일", value: card.email)
                    infoRow(system: "location.fill", title: "주소", value: card.address)
                    infoRow(system: "globe", title: "웹사이트", value: card.website)
                    infoRow(system: "parkingsign.circle.fill", title: "주차", value: card.parkingInfo)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

                if let memo = card.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }

    private func labelChip(system: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.caption)
            Text(text)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func infoRow(system: String, title: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: system)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .center)
                Text("\(title)  \(value)")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
    }
}
