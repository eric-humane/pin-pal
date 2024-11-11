import SwiftData
import Foundation
import Models

public typealias Capture = SchemaV1.Capture

extension SchemaV1 {
    
    @Model
    public final class Capture {
        
        @Attribute(.unique)
        public var uuid: UUID
        
        public let state: CaptureState
        public let type: RemoteCaptureType
        public let isPhoto: Bool
        public let isVideo: Bool
        
        public let thumbnailUUID: UUID
        public let thumbnailAccessToken: String
        
        public let isFavorite: Bool
        public let createdAt: Date
        public let modifiedAt: Date
        
        public var locallyDownloaded: Bool
        public var lastSyncDate: Date?
        public var processingStatus: ProcessingStatus
        
        // MARK: - Enums
        public enum ProcessingStatus: String, Codable {
            case pending
            case processing
            case completed
            case failed
        }
        
        public init(
            uuid: UUID,
            state: CaptureState,
            type: RemoteCaptureType,
            isPhoto: Bool,
            isVideo: Bool,
            thumbnailUUID: UUID,
            thumbnailAccessToken: String,
            isFavorite: Bool,
            createdAt: Date,
            modifiedAt: Date,
            locallyDownloaded: Bool = false,
            lastSyncDate: Date? = nil,
            processingStatus: ProcessingStatus = .pending) {
                self.uuid = uuid
                self.state = state
                self.type = type
                self.isPhoto = isPhoto
                self.isVideo = isVideo
                self.thumbnailUUID = thumbnailUUID
                self.thumbnailAccessToken = thumbnailAccessToken
                self.createdAt = createdAt
                self.isFavorite = isFavorite
                self.modifiedAt = modifiedAt
                self.locallyDownloaded = locallyDownloaded
                self.lastSyncDate = lastSyncDate
                self.processingStatus = processingStatus
            }
        
        public convenience init(from content: MemoryContentEnvelope) {
                    guard let capture: CaptureEnvelope = content.get() else {
                        fatalError()
                    }
                    
                    let thumbnail = capture.thumbnail
                    
                    self.init(
                        uuid: content.id,
                        state: capture.state,
                        type: capture.type,
                        isPhoto: capture.type == .photo,
                        isVideo: capture.type == .video,
                        thumbnailUUID: thumbnail.fileUUID,
                        thumbnailAccessToken: thumbnail.accessToken,
                        isFavorite: content.favorite,
                        createdAt: content.userCreatedAt,
                        modifiedAt: content.userLastModified,
                        lastSyncDate: Date(),
                        processingStatus: .completed
                    )
                }
    }
    
}

extension Capture {
    public static func all(
        limit: Int? = nil,
        order: SortOrder = .reverse,
        predicate: Predicate<Capture>? = nil
    ) -> FetchDescriptor<Capture> {
        var descriptor = FetchDescriptor<Capture>(
            predicate: predicate, sortBy: [.init(\.createdAt, order: order)]
        )
        
        if let limit {
            descriptor.fetchLimit = limit
        }
        
        return descriptor
    }
}

