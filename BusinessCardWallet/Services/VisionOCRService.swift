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

    private let companyKeywords = [
        "inc", "corp", "co.", "co,", "company", "ltd", "llc", "group", "studio", "systems", "tech", "solutions",
        "주식회사", "회사", "그룹", "스튜디오", "테크", "랩", "연구소"
    ]

    private let titleKeywords = [
        "ceo", "cto", "cfo", "coo", "cmo", "manager", "director", "lead", "engineer", "developer", "designer", "consultant",
        "대표", "대표이사", "이사", "매니저", "팀장", "실장", "과장", "차장", "부장", "책임", "수석", "선임", "연구원", "디자이너", "개발자"
    ]

    private let addressKeywords = [
        "street", "st.", "road", "rd.", "ave", "city", "district", "building", "floor",
        "시", "도", "구", "군", "동", "읍", "면", "로", "길"
    ]

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
                    .map { Self.normalizeLine($0) }
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

        let phone = detectPhone(in: fullText)
        let email = detectEmail(in: fullText)
        let website = detectWebsite(in: fullText)
        let address = detectAddress(in: lines)
        let jobTitle = detectJobTitle(in: lines)
        let company = detectCompany(in: lines)
        let name = detectName(in: lines, company: company, jobTitle: jobTitle, email: email)

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

    private func detectPhone(in fullText: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        let nsText = fullText as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return detector?.firstMatch(in: fullText, options: [], range: range)?.phoneNumber
    }

    private func detectEmail(in fullText: String) -> String? {
        let regex = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let found = fullText.range(of: regex, options: .regularExpression) else { return nil }
        return String(fullText[found])
    }

    private func detectWebsite(in fullText: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsText = fullText as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return detector?.firstMatch(in: fullText, options: [], range: range)?.url?.absoluteString
    }

    private func detectAddress(in lines: [String]) -> String? {
        lines.max { scoreAddress($0) < scoreAddress($1) }.flatMap { scoreAddress($0) > 0 ? $0 : nil }
    }

    private func detectJobTitle(in lines: [String]) -> String? {
        lines.max { scoreJobTitle($0) < scoreJobTitle($1) }.flatMap { scoreJobTitle($0) > 0 ? $0 : nil }
    }

    private func detectCompany(in lines: [String]) -> String? {
        lines.max { scoreCompany($0) < scoreCompany($1) }.flatMap { scoreCompany($0) > 0 ? $0 : nil }
    }

    private func detectName(in lines: [String], company: String?, jobTitle: String?, email: String?) -> String? {
        let blocked = Set([company, jobTitle, email].compactMap { $0?.lowercased() })

        var best: (line: String, score: Int)?

        for line in lines {
            let lower = line.lowercased()
            if blocked.contains(lower) { continue }

            let score = scoreName(line)
            guard score > 0 else { continue }

            if best == nil || score > best!.score {
                best = (line, score)
            }
        }

        return best?.line
    }

    private func scoreName(_ line: String) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return -100 }
        if containsAny(trimmed, keywords: addressKeywords) { return -50 }
        if containsAny(trimmed, keywords: companyKeywords) { return -40 }
        if containsAny(trimmed, keywords: titleKeywords) { return -30 }
        if trimmed.contains("@") || trimmed.lowercased().contains("www") || trimmed.contains("http") { return -100 }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { return -20 }

        let compactCount = trimmed.replacingOccurrences(of: " ", with: "").count
        if compactCount < 2 || compactCount > 24 { return -20 }

        var score = 0
        if compactCount <= 10 { score += 4 }
        if compactCount <= 6 { score += 2 }

        let words = trimmed.split(separator: " ")
        if words.count >= 1 && words.count <= 3 { score += 3 }

        if isLikelyKoreanName(trimmed) || isLikelyEnglishName(trimmed) { score += 5 }

        return score
    }

    private func scoreCompany(_ line: String) -> Int {
        let lower = line.lowercased()
        if lower.contains("@") { return -50 }

        var score = 0
        if containsAny(line, keywords: companyKeywords) { score += 8 }
        if lower.contains("team") || lower.contains("lab") || lower.contains("division") { score += 2 }
        if line.count >= 3 && line.count <= 40 { score += 2 }
        if hasUppercaseAcronym(line) { score += 1 }
        return score
    }

    private func scoreJobTitle(_ line: String) -> Int {
        let lower = line.lowercased()
        if lower.contains("@") { return -50 }

        var score = 0
        if containsAny(line, keywords: titleKeywords) { score += 10 }
        if lower.contains("head") || lower.contains("owner") || lower.contains("founder") { score += 3 }
        if line.count >= 2 && line.count <= 30 { score += 1 }
        return score
    }

    private func scoreAddress(_ line: String) -> Int {
        var score = 0
        if containsAny(line, keywords: addressKeywords) { score += 10 }
        if line.rangeOfCharacter(from: .decimalDigits) != nil { score += 2 }
        if line.count >= 8 { score += 1 }
        return score
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        let lower = text.lowercased()
        return keywords.contains(where: { lower.contains($0) })
    }

    private func hasUppercaseAcronym(_ text: String) -> Bool {
        let tokens = text.split(separator: " ")
        return tokens.contains { token in
            token.count >= 2 && token.count <= 5 && token.allSatisfy { $0.isUppercase }
        }
    }

    private func isLikelyKoreanName(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 2 && compact.count <= 4 else { return false }
        let pattern = "^[가-힣]+$"
        return compact.range(of: pattern, options: .regularExpression) != nil
    }

    private func isLikelyEnglishName(_ text: String) -> Bool {
        let pattern = #"^[A-Za-z]+(?:\s[A-Za-z]+){0,2}$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func normalizeLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
