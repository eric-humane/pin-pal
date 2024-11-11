import Foundation
import Get
import Models

enum API {
    
    static let rootUrl = URL(string: "https://webapi.prod.humane.cloud/")!
    static let captureUrl = rootUrl.appending(path: "capture")
    static let memoryUrl = rootUrl.appending(path: "capture").appending(path: "memory")
    static let noteUrl = rootUrl.appending(path: "capture").appending(path: "note")
    static let aiBusUrl = rootUrl.appending(path: "ai-bus")
    static let deviceAssignmentUrl = rootUrl.appending(path: "device-assignments")
    static let eventsUrl = rootUrl.appending(path: "notable-events")
    static let subscriptionUrl = rootUrl.appending(path: "subscription")
    static let lostDeviceUrl = subscriptionUrl.appending(path: "deviceAuthorization/lostDevice")
    static let subscriptionV3Url = subscriptionUrl.appending(path: "v3/subscription")
    static let featureFlagsUrl = rootUrl.appending(path: "feature-flags/v0/feature-flag/flags")
    static let sessionUrl = URL(string: "https://humane.center/api/auth/session")!

    static func session() -> Request<Session> {
        .init(url: API.sessionUrl)
    }

    static func captures(
        page: Int = 0,
        size: Int = 10,
        sort: String = "userCreatedAt,DESC",
        onlyContainingFavorited: Bool = false
    ) -> Request<PageableMemoryContentEnvelope> {
        .init(url: API.captureUrl.appending(path: "captures"), query: [
            ("page", String(page)),
            ("size", String(size)),
            ("sort", sort),
            ("onlyContainingFavorited", onlyContainingFavorited ? "true" : "false")
        ])
    }

    static func memory(uuid: UUID) -> Request<MemoryContentEnvelope> {
        .init(url: API.memoryUrl.appending(path: uuid.uuidString))
    }
    
    static func deviceIdentifiers() -> Request<[String]> {
        .init(url: deviceAssignmentUrl.appending(path: "devices"))
    }

    static func download(memoryUUID: UUID, asset: FileAsset) -> Request<Data> {
        .init(
            url: memoryUrl.appending(path: "\(memoryUUID)/file/\(asset.fileUUID)/download"),
            query: [
                ("token", asset.accessToken),
                ("rawData", "false")
            ]
        )
    }
}

enum OverallFeedbackCategory: String, Codable {
    case positive = "OVERALL_FEEDBACK_CATEGORY_POSITIVE"
    case negative = "OVERALL_FEEDBACK_CATEGORY_NEGATIVE"
}

public enum AiMicFeedbackCategory: String, Codable {
    case wrongAnswer = "AI_MIC_FEEDBACK_CATEGORY_WRONG_ANSWER"
    case wrongTranscription = "AI_MIC_FEEDBACK_CATEGORY_WRONG_TRANSCRIPTION"
    case inaccurate = "AI_MIC_FEEDBACK_CATEGORY_INACCURATE_ANSWER"
    case inappropriateOrOffensive = "AI_MIC_FEEDBACK_CATEGORY_INAPPROPRIATE_OR_OFFENSIVE_ANSWER"
    case dangerousOrHarmful = "AI_MIC_FEEDBACK_CATEGORY_DANGEROUS_OR_HARMFUL_ANSWER"
    case unspecifiedPositive = "AI_MIC_FEEDBACK_CATEGORY_UNSPECIFIED_POSITIVE"
    case other = "AI_MIC_FEEDBACK_CATEGORY_OTHER"
    
    static let type = "FEEDBACK_TYPE_AI_MIC"
}

struct AiMicImprovementFeedback: Codable {
    
    struct Feedback: Codable {
        struct Data: Codable {
            var category: AiMicFeedbackCategory
            var request: String
            var response: String
            var notableEventUuid: String
        }
        
        var aiMicFeedbackData: Data
    }
    
    var type = AiMicFeedbackCategory.type
    var userId: String
    var eventTimeIsoFormat: Date
    var data: Feedback
    var overallCategory: OverallFeedbackCategory
}
