import Foundation
import UIKit
import Vision

struct OCRExtractionResult {
    let fullText: String
    let name: String?
    let company: String?
    let jobTitle: String?
    let phone: String?
    let phoneCandidates: [String]
    let email: String?
    let emailCandidates: [String]
    let address: String?
    let website: String?
    let websiteCandidates: [String]
    let parkingInfo: String?
    let parkingCandidates: [String]
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

    private let parkingKeywords = [
        "parking", "park", "주차", "무료주차", "주차장", "주차가능", "valet"
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

        let phoneCandidates = detectPhoneCandidates(in: fullText)
        let emailCandidates = detectEmailCandidates(in: fullText)
        let websiteCandidates = detectWebsiteCandidates(in: fullText)
        let parkingCandidates = detectParkingCandidates(in: lines)

        let address = detectAddress(in: lines)
        let jobTitle = detectJobTitle(in: lines)
        let company = detectCompany(in: lines)
        let name = detectName(in: lines, company: company, jobTitle: jobTitle, email: emailCandidates.first)

        return OCRExtractionResult(
            fullText: fullText,
            name: name,
            company: company,
            jobTitle: jobTitle,
            phone: phoneCandidates.first,
            phoneCandidates: phoneCandidates,
            email: emailCandidates.first,
            emailCandidates: emailCandidates,
            address: address,
            website: websiteCandidates.first,
            websiteCandidates: websiteCandidates,
            parkingInfo: parkingCandidates.first,
            parkingCandidates: parkingCandidates
        )
    }

    private func detectPhoneCandidates(in fullText: String) -> [String] {
        var candidates: [String] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        let nsText = fullText as NSString
        let range = NSRange(location: 0, length: nsText.length)

        detector?.enumerateMatches(in: fullText, options: [], range: range) { match, _, _ in
            guard let raw = match?.phoneNumber else { return }
            guard let normalized = normalizePhone(raw) else { return }
            candidates.append(normalized)
        }

        let regex = #"(?:\+?\d[\d\-\s\(\)]{7,}\d)"#
        for raw in allMatches(regex: regex, in: fullText) {
            guard let normalized = normalizePhone(raw) else { continue }
            candidates.append(normalized)
        }

        return deduplicated(candidates)
    }

    private func detectEmailCandidates(in fullText: String) -> [String] {
        var candidates: [String] = []
        let regex = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#

        for raw in allMatches(regex: regex, in: fullText) {
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]{}<>"))
                .lowercased()
            if !normalized.isEmpty {
                candidates.append(normalized)
            }
        }

        return deduplicated(candidates)
    }

    private func detectWebsiteCandidates(in fullText: String) -> [String] {
        var candidates: [String] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsText = fullText as NSString
        let range = NSRange(location: 0, length: nsText.length)

        detector?.enumerateMatches(in: fullText, options: [], range: range) { match, _, _ in
            guard let urlString = match?.url?.absoluteString else { return }
            if let normalized = normalizeWebsite(urlString) {
                candidates.append(normalized)
            }
        }

        let regex = #"(?:www\.)?[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:/[^\s]*)?"#
        for raw in allMatches(regex: regex, in: fullText) {
            if raw.contains("@") { continue }
            if let normalized = normalizeWebsite(raw) {
                candidates.append(normalized)
            }
        }

        return deduplicated(candidates)
    }

    private func detectParkingCandidates(in lines: [String]) -> [String] {
        let rawCandidates = lines.filter { containsAny($0, keywords: parkingKeywords) }
        let cleaned = rawCandidates.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return deduplicated(cleaned.filter { !$0.isEmpty })
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
        if containsAny(trimmed, keywords: parkingKeywords) { return -50 }
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

    private func allMatches(regex: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex) else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            return nsText.substring(with: match.range)
        }
    }

    private func normalizePhone(_ raw: String) -> String? {
        let filtered = raw.filter { $0.isNumber || $0 == "+" }
        guard !filtered.isEmpty else { return nil }

        var digits = filtered
        if digits.hasPrefix("+82") {
            digits = "0" + String(digits.dropFirst(3))
        } else if digits.hasPrefix("82") && digits.count >= 10 {
            digits = "0" + String(digits.dropFirst(2))
        }

        let onlyDigits = digits.filter(\.isNumber)
        if onlyDigits.count == 11 {
            let a = onlyDigits.prefix(3)
            let b = onlyDigits.dropFirst(3).prefix(4)
            let c = onlyDigits.suffix(4)
            return "\(a)-\(b)-\(c)"
        }

        if onlyDigits.count == 10 {
            let a = onlyDigits.prefix(3)
            let b = onlyDigits.dropFirst(3).prefix(3)
            let c = onlyDigits.suffix(4)
            return "\(a)-\(b)-\(c)"
        }

        if onlyDigits.count >= 8 && onlyDigits.count <= 15 {
            return onlyDigits
        }

        return nil
    }

    private func normalizeWebsite(_ raw: String) -> String? {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]{}<>"))
            .lowercased()

        guard !value.isEmpty else { return nil }
        if value.hasPrefix("mailto:") { return nil }

        if !value.hasPrefix("http://") && !value.hasPrefix("https://") {
            value = "https://" + value
        }

        guard let url = URL(string: value), let host = url.host, host.contains(".") else {
            return nil
        }

        return url.absoluteString
    }

    private func deduplicated(_ items: [String]) -> [String] {
        var set = Set<String>()
        var result: [String] = []

        for item in items {
            if !set.contains(item) {
                set.insert(item)
                result.append(item)
            }
        }

        return result
    }
}
