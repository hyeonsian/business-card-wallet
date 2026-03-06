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
