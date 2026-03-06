import Foundation
import UIKit

enum ImageStore {
    static func saveJPEG(_ image: UIImage, compressionQuality: CGFloat = 0.85) throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(domain: "ImageStore", code: -1)
        }

        let filename = "card-\(UUID().uuidString).jpg"
        let url = try imageDirectoryURL().appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url.path
    }

    static func saveThumbnailJPEG(_ image: UIImage, maxDimension: CGFloat = 320, compressionQuality: CGFloat = 0.8) throws -> String {
        let thumbnail = resizedImage(image, maxDimension: maxDimension)
        return try saveJPEG(thumbnail, compressionQuality: compressionQuality)
    }

    private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }

        let ratio = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func imageDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = documents.appendingPathComponent("BusinessCardImages", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }
}
