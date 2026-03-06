import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let card: BusinessCard

    @State private var name: String
    @State private var company: String
    @State private var jobTitle: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var website: String
    @State private var memo: String

    @State private var scaleBase: CGFloat = 1
    @State private var scaleDelta: CGFloat = 1
    @State private var saveError: String?
    @State private var showDeleteConfirm = false

    init(card: BusinessCard) {
        self.card = card
        _name = State(initialValue: card.name ?? "")
        _company = State(initialValue: card.company ?? "")
        _jobTitle = State(initialValue: card.jobTitle ?? "")
        _phone = State(initialValue: card.phone ?? "")
        _email = State(initialValue: card.email ?? "")
        _address = State(initialValue: card.address ?? "")
        _website = State(initialValue: card.website ?? "")
        _memo = State(initialValue: card.memo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("원본 명함") {
                    LocalCardImageView(imagePath: card.imageLocalPath, fallbackPath: nil)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .scaleEffect(scaleBase * scaleDelta)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scaleDelta = value
                                }
                                .onEnded { value in
                                    scaleBase = clampScale(scaleBase * value)
                                    scaleDelta = 1
                                }
                        )
                        .onTapGesture(count: 2) {
                            scaleBase = 1
                            scaleDelta = 1
                        }

                    Text("더블 탭으로 확대 초기화")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("기본 정보") {
                    TextField("이름", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("회사", text: $company)
                        .textInputAutocapitalization(.words)
                    TextField("직함", text: $jobTitle)
                        .textInputAutocapitalization(.words)
                }

                Section("연락처") {
                    TextField("전화", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("주소", text: $address)
                    TextField("웹사이트", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("메모") {
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("명함 삭제", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("명함 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveChanges()
                    }
                }
            }
            .confirmationDialog("명함을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    deleteCard()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제 후 복구할 수 없습니다.")
            }
        }
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }

    private func saveChanges() {
        saveError = nil

        card.name = normalizedOptional(name)
        card.company = normalizedOptional(company)
        card.jobTitle = normalizedOptional(jobTitle)
        card.phone = normalizedOptional(phone)
        card.email = normalizedOptional(email)
        card.address = normalizedOptional(address)
        card.website = normalizedOptional(website)
        card.memo = normalizedOptional(memo)
        card.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func deleteCard() {
        saveError = nil

        modelContext.delete(card)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func normalizedOptional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
