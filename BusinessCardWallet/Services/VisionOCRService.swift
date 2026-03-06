import Foundation
import UIKit
import Vision

struct OCRExtractionResult {
    let fullText: String
    let name: String?
    let company: String?
    let jobTitle: String?
    let phone: String?
    let email: String?
    let address: String?
    let website: String?
}

enum VisionOCRServiceError: Error {
    case cgImageMissing
}

actor VisionOCRService {
    static let shared = VisionOCRService()

    func extract(from image: UIImage) async throws -> OCRExtractionResult {
        guard let cgImage = image.cgImage else {
            throw VisionOCRServiceError.cgImageMissing
        }

        let recognizedLines = try await recognizeTextLines(cgImage: cgImage)
        return parse(lines: recognizedLines)
    }

    private func recognizeTextLines(cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ko-KR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parse(lines: [String]) -> OCRExtractionResult {
        let fullText = lines.joined(separator: "\n")
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        let nsText = fullText as NSString
        let range = NSRange(location: 0, length: nsText.length)

        var phone: String?
        var email: String?
        var website: String?

        detector?.enumerateMatches(in: fullText, options: [], range: range) { match, _, _ in
            guard let match else { return }
            if let foundPhone = match.phoneNumber, phone == nil {
                phone = foundPhone
                return
            }

            guard let url = match.url else { return }
            let absolute = url.absoluteString
            if absolute.contains("mailto:") {
                if email == nil { email = absolute.replacingOccurrences(of: "mailto:", with: "") }
            } else if website == nil {
                website = absolute
            }
        }

        if email == nil {
            let emailRegex = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
            if let emailRange = fullText.range(of: emailRegex, options: .regularExpression) {
                email = String(fullText[emailRange])
            }
        }

        let name = lines.first { line in
            let compact = line.replacingOccurrences(of: " ", with: "")
            return !compact.isEmpty &&
            compact.count <= 20 &&
            compact.rangeOfCharacter(from: .decimalDigits) == nil &&
            !line.contains("@") &&
            !line.lowercased().contains("www")
        }

        let companyKeywords = ["inc", "corp", "co.", "ltd", "llc", "solutions", "studio", "주식회사", "회사"]
        let company = lines.first { line in
            let lower = line.lowercased()
            return companyKeywords.contains(where: { lower.contains($0) })
        }

        let titleKeywords = ["ceo", "cto", "cfo", "manager", "director", "engineer", "developer", "대표", "이사", "매니저", "팀장", "과장", "부장"]
        let jobTitle = lines.first { line in
            let lower = line.lowercased()
            return titleKeywords.contains(where: { lower.contains($0) })
        }

        let addressKeywords = ["street", "st.", "road", "rd.", "ave", "city", "구", "로", "길", "동"]
        let address = lines.first { line in
            let lower = line.lowercased()
            return addressKeywords.contains(where: { lower.contains($0) })
        }

        return OCRExtractionResult(
            fullText: fullText,
            name: name,
            company: company,
            jobTitle: jobTitle,
            phone: phone,
            email: email,
            address: address,
            website: website
        )
    }
}
