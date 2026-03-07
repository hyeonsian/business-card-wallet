import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [CardGroup]
    @Query private var cards: [BusinessCard]

    @StateObject private var viewModel = WalletHomeViewModel()
    @State private var selectedCardPage = 0
    @State private var cardToDelete: BusinessCard?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),
                            Color(red: 0.98, green: 0.98, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 12) {
                        HStack(alignment: .center) {
                            Text("명함 지갑")
                                .font(.largeTitle.weight(.bold))
                            Spacer()

                            Button {
                                viewModel.isPresentingScan = true
                            } label: {
                                Label("명함 스캔", systemImage: "camera")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 10) {
                            TopControlBar(
                                groups: groups,
                                selectedGroupID: $viewModel.selectedGroupID,
                                sortOption: $viewModel.sortOption,
                                onTapAddGroup: { viewModel.isPresentingAddGroup = true }
                            )

                            Picker("보기", selection: $viewModel.viewMode) {
                                ForEach(CardViewMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 8) {
                                Text("즐겨찾기만")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Toggle("", isOn: $viewModel.showFavoritesOnly)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 2)
                        }
                        .padding(12)
                        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.8), lineWidth: 1)
                        )
                        .padding(.horizontal)

                        TextField("이름, 회사, 이메일, 전화로 검색", text: $viewModel.searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        contentView
                            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.9), lineWidth: 1)
                            )
                            .padding(.horizontal)

                        Spacer(minLength: 6)
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, 52))
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 10))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: ensureDefaultGroup)
            .onChange(of: filteredCards.map(\.id)) { _ in
                adjustSelectedCardPage()
            }
            .alert("새 그룹", isPresented: $viewModel.isPresentingAddGroup) {
                TextField("그룹 이름", text: $viewModel.newGroupName)
                Button("취소", role: .cancel) {}
                Button("추가", action: addGroup)
            } message: {
                Text("그룹 이름을 입력하세요")
            }
            .confirmationDialog("명함 삭제", isPresented: $showDeleteConfirm, titleVisibility: .visible, presenting: cardToDelete) { card in
                Button("삭제", role: .destructive) {
                    deleteCard(card)
                }
                Button("취소", role: .cancel) {}
            } message: { card in
                Text("\(card.name ?? "이 명함")을(를) 삭제하시겠습니까?")
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
                [
                    card.name,
                    card.company,
                    card.jobTitle,
                    card.phone,
                    card.email,
                    card.parkingInfo,
                    card.fullText
                ]
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
                VStack(spacing: 10) {
                    TabView(selection: $selectedCardPage) {
                        ForEach(Array(filteredCards.enumerated()), id: \.element.id) { index, card in
                            BusinessCardTileView(
                                card: card,
                                onToggleFavorite: { toggleFavorite(card) },
                                onDelete: { requestDelete(card) }
                            )
                            .padding(.horizontal, 10)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(minHeight: 520)

                    HStack(spacing: 10) {
                        ForEach(filteredCards.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedCardPage ? Color.blue : Color.gray.opacity(0.55))
                                .frame(width: 9, height: 9)
                        }
                    }
                    .padding(.bottom, 8)
                }
            case .list:
                List(filteredCards) { card in
                    CardRowView(
                        card: card,
                        onToggleFavorite: { toggleFavorite(card) },
                        onDelete: { requestDelete(card) }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
            thumbnailLocalPath: draft.thumbnailLocalPath,
            fullText: draft.fullText,
            name: draft.name,
            company: draft.company,
            jobTitle: draft.jobTitle,
            phone: draft.phone,
            email: draft.email,
            address: draft.address,
            website: draft.website,
            parkingInfo: draft.parkingInfo,
            memo: draft.memo
        )

        modelContext.insert(card)
        try? modelContext.save()
        adjustSelectedCardPage()
    }

    private func toggleFavorite(_ card: BusinessCard) {
        card.isFavorite.toggle()
        card.updatedAt = .now
        try? modelContext.save()
    }

    private func requestDelete(_ card: BusinessCard) {
        cardToDelete = card
        showDeleteConfirm = true
    }

    private func deleteCard(_ card: BusinessCard) {
        modelContext.delete(card)
        try? modelContext.save()
        adjustSelectedCardPage()
    }

    private func adjustSelectedCardPage() {
        let count = filteredCards.count
        if count == 0 {
            selectedCardPage = 0
        } else if selectedCardPage >= count {
            selectedCardPage = count - 1
        }
    }
}

#Preview {
    WalletHomeView()
        .modelContainer(for: [CardGroup.self, BusinessCard.self], inMemory: true)
}
