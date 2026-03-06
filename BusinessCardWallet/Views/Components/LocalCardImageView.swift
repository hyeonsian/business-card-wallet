import SwiftUI
import UIKit

struct LocalCardImageView: View {
    let imagePath: String

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.15))
                    .overlay {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: imagePath) {
            await loadImageIfNeeded()
        }
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard uiImage == nil else { return }

        let loaded = UIImage(contentsOfFile: imagePath)
        uiImage = loaded
    }
}
