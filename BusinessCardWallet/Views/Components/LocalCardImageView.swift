import SwiftUI
import UIKit

struct LocalCardImageView: View {
    let imagePath: String
    let fallbackPath: String?

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white.opacity(0.9))
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
        .task(id: taskKey) {
            await loadImageIfNeeded()
        }
    }

    private var taskKey: String {
        if let fallbackPath {
            return "\(imagePath)|\(fallbackPath)"
        }
        return imagePath
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard uiImage == nil else { return }

        let loaded = UIImage(contentsOfFile: imagePath) ?? fallbackPath.flatMap { UIImage(contentsOfFile: $0) }
        uiImage = loaded
    }
}
