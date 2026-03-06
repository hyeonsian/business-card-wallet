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
                    TextField("회사", text: $draft.company)
                    TextField("직함", text: $draft.jobTitle)
                }

                Section("연락처") {
                    TextField("전화", text: $draft.phone)
                    TextField("이메일", text: $draft.email)
                    TextField("주소", text: $draft.address)
                    TextField("웹사이트", text: $draft.website)
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
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}
