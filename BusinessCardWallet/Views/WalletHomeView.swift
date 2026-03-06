import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [CardGroup]
    @Query private var cards: [BusinessCard]

    @StateObject private var viewModel = WalletHomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TopControlBar(
                    groups: groups,
                    selectedGroupID: $viewModel.selectedGroupID,
                    sortOption: $viewModel.sortOption,
                    onTapAddGroup: { viewModel.isPresentingAddGroup = true }
                )
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Picker("보기", selection: $viewModel.viewMode) {
                        ForEach(CardViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("즐겨찾기", isOn: $viewModel.showFavoritesOnly)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .overlay(alignment: .leading) {
                            Text("즐겨찾기만")
                                .font(.caption)
                                .offset(x: -62)
                        }
                }
                .padding(.horizontal)

                TextField("이름, 회사, 이메일, 전화로 검색", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                contentView

                Button {
                    viewModel.isPresentingScan = true
                } label: {
                    Label("명함 스캔", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            .navigationTitle("명함 지갑")
            .onAppear(perform: ensureDefaultGroup)
            .alert("새 그룹", isPresented: $viewModel.isPresentingAddGroup) {
                TextField("그룹 이름", text: $viewModel.newGroupName)
                Button("취소", role: .cancel) {}
                Button("추가", action: addGroup)
            } message: {
                Text("그룹 이름을 입력하세요")
            }
            .sheet(isPresented: $viewModel.isPresentingScan) {
                ScanCaptureView { draft in
                    viewModel.pendingDraft = draft
                    viewModel.isPresentingScan = false
                    viewModel.isPresentingOCRReview = true
                }
            }
            .sheet(isPresented: $viewModel.isPresentingOCRReview) {
                if let draft = viewModel.pendingDraft {
                    OCRReviewEditView(draft: draft) { finalDraft in
                        save(draft: finalDraft)
                        viewModel.pendingDraft = nil
                    }
                }
            }
        }
    }

    private var filteredCards: [BusinessCard] {
        var result = cards

        if let groupID = viewModel.selectedGroupID {
            result = result.filter { $0.groupID == groupID }
        }

        if viewModel.showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }

        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { card in
                [card.name, card.company, card.jobTitle, card.phone, card.email, card.fullText]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(query) }
            }
        }

        switch viewModel.sortOption {
        case .latest:
            result.sort { $0.createdAt > $1.createdAt }
        case .alphabetical:
            result.sort {
                ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
            }
        }

        return result
    }

    @ViewBuilder
    private var contentView: some View {
        if filteredCards.isEmpty {
            ContentUnavailableView("표시할 명함이 없습니다", systemImage: "tray")
                .frame(maxHeight: .infinity)
        } else {
            switch viewModel.viewMode {
            case .card:
                TabView {
                    ForEach(filteredCards) { card in
                        BusinessCardTileView(card: card) {
                            toggleFavorite(card)
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            case .list:
                List(filteredCards) { card in
                    CardRowView(card: card) {
                        toggleFavorite(card)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func ensureDefaultGroup() {
        guard groups.isEmpty else {
            if viewModel.selectedGroupID == nil {
                viewModel.selectedGroupID = groups.first?.id
            }
            return
        }

        let defaultGroup = CardGroup(name: "기본", isDefault: true)
        modelContext.insert(defaultGroup)
        try? modelContext.save()
        viewModel.selectedGroupID = defaultGroup.id
    }

    private func addGroup() {
        let trimmed = viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let group = CardGroup(name: trimmed)
        modelContext.insert(group)
        try? modelContext.save()

        viewModel.newGroupName = ""
        viewModel.selectedGroupID = group.id
    }

    private func save(draft: NewCardDraft) {
        guard let groupID = viewModel.selectedGroupID ?? groups.first?.id else { return }

        let card = BusinessCard(
            groupID: groupID,
            imageLocalPath: draft.imageLocalPath,
            fullText: draft.fullText,
            name: draft.name,
            company: draft.company,
            jobTitle: draft.jobTitle,
            phone: draft.phone,
            email: draft.email,
            address: draft.address,
            website: draft.website,
            memo: draft.memo
        )

        modelContext.insert(card)
        try? modelContext.save()
    }

    private func toggleFavorite(_ card: BusinessCard) {
        card.isFavorite.toggle()
        card.updatedAt = .now
        try? modelContext.save()
    }
}

#Preview {
    WalletHomeView()
        .modelContainer(for: [CardGroup.self, BusinessCard.self], inMemory: true)
}
