import Foundation
import FirebaseFirestore

/// Represents a user-submitted content report
struct ContentReport: Codable, Identifiable {
    @DocumentID var id: String?
    let reporterId: String
    let reportedUserId: String
    let contentType: ContentType
    let contentId: String
    let reason: ReportReason
    let details: String?
    let createdAt: Date
    var status: ReportStatus
    var queuedAt: Date?
    var reviewedAt: Date?
    var reviewedBy: String?
    var resolution: String?

    enum ContentType: String, Codable {
        case story
        case profile
        case displayName
        case bio
    }

    enum ReportReason: String, Codable, CaseIterable {
        case spam = "Spam or advertising"
        case harassment = "Harassment or bullying"
        case inappropriate = "Inappropriate content"
        case hateSpeech = "Hate speech"
        case violence = "Violence or threats"
        case personalInfo = "Sharing personal information"
        case impersonation = "Impersonation"
        case other = "Other"

        var description: String {
            return self.rawValue
        }
    }

    enum ReportStatus: String, Codable {
        case pending
        case queued
        case reviewed
        case resolved
        case dismissed
    }

    init(
        reporterId: String,
        reportedUserId: String,
        contentType: ContentType,
        contentId: String,
        reason: ReportReason,
        details: String? = nil
    ) {
        self.reporterId = reporterId
        self.reportedUserId = reportedUserId
        self.contentType = contentType
        self.contentId = contentId
        self.reason = reason
        self.details = details
        self.createdAt = Date()
        self.status = .pending
    }
}