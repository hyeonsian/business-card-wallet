import SwiftUI

struct OCRReviewEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: NewCardDraft
    let onSave: (NewCardDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    TextField("회사", text: $draft.company)
                        .textInputAutocapitalization(.words)
                    TextField("직함", text: $draft.jobTitle)
                        .textInputAutocapitalization(.words)
                }

                Section("연락처") {
                    TextField("전화", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("이메일", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("주소", text: $draft.address)
                    TextField("웹사이트", text: $draft.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !draft.phoneCandidates.isEmpty || !draft.emailCandidates.isEmpty || !draft.websiteCandidates.isEmpty {
                    Section("후보 적용") {
                        if !draft.phoneCandidates.isEmpty {
                            candidatePickerRow(
                                title: "전화 후보",
                                candidates: draft.phoneCandidates
                            ) { selected in
                                draft.phone = selected
                            }
                        }

                        if !draft.emailCandidates.isEmpty {
                            candidatePickerRow(
                                title: "이메일 후보",
                                candidates: draft.emailCandidates
                            ) { selected in
                                draft.email = selected
                            }
                        }

                        if !draft.websiteCandidates.isEmpty {
                            candidatePickerRow(
                                title: "웹사이트 후보",
                                candidates: draft.websiteCandidates
                            ) { selected in
                                draft.website = selected
                            }
                        }
                    }
                }

                Section("메모") {
                    TextField("메모", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("OCR 원문") {
                    Text(draft.fullText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("OCR 검수")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(normalizedDraft())
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func candidatePickerRow(title: String, candidates: [String], onSelect: @escaping (String) -> Void) -> some View {
        Menu(title) {
            ForEach(candidates, id: \.self) { candidate in
                Button(candidate) {
                    onSelect(candidate)
                }
            }
        }
    }

    private func normalizedDraft() -> NewCardDraft {
        var result = draft
        result.name = normalize(result.name)
        result.company = normalize(result.company)
        result.jobTitle = normalize(result.jobTitle)
        result.phone = normalize(result.phone)
        result.email = normalize(result.email).lowercased()
        result.address = normalize(result.address)
        result.website = normalize(result.website).lowercased()
        result.memo = normalize(result.memo)
        return result
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
