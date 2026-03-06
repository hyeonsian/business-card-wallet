import SwiftUI

struct TopControlBar: View {
    let groups: [CardGroup]
    @Binding var selectedGroupID: UUID?
    @Binding var sortOption: CardSortOption
    let onTapAddGroup: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("정렬", selection: $sortOption) {
                    ForEach(CardSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(.black.opacity(0.07)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups) { group in
                        let isSelected = selectedGroupID == group.id
                        Button(group.name) {
                            selectedGroupID = group.id
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? .blue : .white.opacity(0.9))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? .blue : .black.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }

            Button(action: onTapAddGroup) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(.black.opacity(0.07)))
            }
        }
    }
}
