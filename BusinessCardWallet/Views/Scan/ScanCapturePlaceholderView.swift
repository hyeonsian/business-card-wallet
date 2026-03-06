import SwiftUI

struct ScanCapturePlaceholderView: View {
    let onMockComplete: (NewCardDraft) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("MVP 초안: 실제 카메라/OCR 연결 전 플레이스홀더")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("목업 스캔 결과 생성") {
                    onMockComplete(
                        NewCardDraft(
                            imageLocalPath: "local://mock-card.jpg",
                            fullText: "홍길동 ABC Solutions CTO 010-1234-5678 gildong@example.com",
                            name: "홍길동",
                            company: "ABC Solutions",
                            jobTitle: "CTO",
                            phone: "010-1234-5678",
                            email: "gildong@example.com",
                            address: "서울시 강남구",
                            website: "abc.example.com",
                            memo: "컨퍼런스에서 만남"
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("명함 스캔")
        }
    }
}
