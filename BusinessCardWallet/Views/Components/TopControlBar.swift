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
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial, in: Circle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups) { group in
                        let isSelected = selectedGroupID == group.id
                        Button(group.name) {
                            selectedGroupID = group.id
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isSelected ? .blue : .gray.opacity(0.3))
                    }
                }
            }

            Button(action: onTapAddGroup) {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial, in: Circle())
            }
        }
    }
}
