import Foundation
import SwiftData

@Model
final class BusinessCard {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var imageLocalPath: String
    var thumbnailLocalPath: String?

    var fullText: String
    var name: String?
    var company: String?
    var jobTitle: String?
    var phone: String?
    var email: String?
    var address: String?
    var website: String?
    var parkingInfo: String?
    var memo: String?

    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        groupID: UUID,
        imageLocalPath: String,
        thumbnailLocalPath: String? = nil,
        fullText: String,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        website: String? = nil,
        parkingInfo: String? = nil,
        memo: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.groupID = groupID
        self.imageLocalPath = imageLocalPath
        self.thumbnailLocalPath = thumbnailLocalPath
        self.fullText = fullText
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.phone = phone
        self.email = email
        self.address = address
        self.website = website
        self.parkingInfo = parkingInfo
        self.memo = memo
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
