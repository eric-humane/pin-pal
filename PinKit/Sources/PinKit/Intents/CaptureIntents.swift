import AppIntents
import Foundation
import PinKit
import SwiftUI
import Models
import Photos
import Retry

public enum CaptureIntentError: LocalizedError {
    case invalidContent
    case downloadFailed
    case saveFailed
    case noPhotoAccess
    case syncFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidContent:
            return "Unable to process capture content"
        case .downloadFailed:
            return "Failed to download capture"
        case .saveFailed:
            return "Failed to save to camera roll"
        case .noPhotoAccess:
            return "No access to photo library"
        case .syncFailed:
            return "Failed to sync captures"
        }
    }
}

public enum CaptureType: String, AppEnum, Codable {
    case photo = "PHOTO"
    case video = "VIDEO"
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Capture Type")
    public static var caseDisplayRepresentations: [CaptureType: DisplayRepresentation] = [
        .photo: "Photo",
        .video: "Video"
    ]
}

public struct CaptureEntity: Identifiable {
    public let id: UUID
    
    @Property(title: "Media Type")
    public var type: CaptureType

    @Property(title: "Creation Date")
    public var createdAt: Date
    
    @Property(title: "Last Modified Date")
    public var modifiedAt: Date
    
    let url: URL?

    public init(from content: MemoryContentEnvelope) async {
        let capture: CaptureEnvelope? = content.get()
        self.id = content.id
        self.url = capture?.makeThumbnailURL()
        self.type = capture?.video == nil ? .photo : .video
        self.createdAt = content.userCreatedAt
        self.modifiedAt = content.userLastModified
    }
    
    public init(from capture: Capture) {
        self.id = capture.uuid
        self.url = nil // capture?.makeThumbnailURL()
        self.type = capture.isPhoto ? .photo : .video
        self.createdAt = capture.createdAt
        self.modifiedAt = capture.modifiedAt
    }
}

extension CaptureEntity: AppEntity {
    public var displayRepresentation: DisplayRepresentation {
        if let url {
            DisplayRepresentation(title: "\(id.uuidString)", image: .init(url: url))
        } else {
            DisplayRepresentation(title: "\(id.uuidString)")
        }
    }
    
    public static var defaultQuery: CaptureEntityQuery = CaptureEntityQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Captures"),
        // TODO: pluralize correctly
        numericFormat: LocalizedStringResource("\(placeholder: .int) captures")
    )
}

public struct CaptureEntityQuery: EntityQuery, EnumerableEntityQuery {
    
    public func allEntities() async throws -> [CaptureEntity] {
        try await database.fetch(Capture.all())
            .map(CaptureEntity.init(from:))
    }

    public static var findIntentDescription: IntentDescription? {
        IntentDescription("",
                          categoryName: "Captures",
                          searchKeywords: ["capture", "photo", "ai pin"],
                          resultValueName: "Captures")
    }
    
    @Dependency
    var service: HumaneCenterService
    
    @Dependency
    var database: any Database
    
    public init() {}
    
    public func entities(for ids: [Self.Entity.ID]) async throws -> Self.Result {
        await ids.asyncCompactMap { id in
            try? await CaptureEntity(from: service.memory(id))
        }
    }

    public func suggestedEntities() async throws -> [CaptureEntity] {
        try await database.fetch(Capture.all(limit: 30))
            .map(CaptureEntity.init(from:))
    }
}

public struct GetVideoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Video"
    public static var description: IntentDescription? = .init("Returns the video for a given capture, if it has one.",
                                                              categoryName: "Captures",
                                                              resultValueName: "Video"
    )
    public static var parameterSummary: some ParameterSummary {
        Summary("Get video from \(\.$capture)")
    }
    
    @Parameter(title: "Capture")
    public var capture: CaptureEntity

    public init(capture: CaptureEntity) {
        self.capture = capture
    }
    
    public init(capture: Capture) {
        self.capture = CaptureEntity(from: capture)
    }
    
    public init() {}
    
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true
    
    @Dependency
    public var service: HumaneCenterService

    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile?> {
        let content = try await service.memory(capture.id)
        guard let file = content.get()?.downloadVideo ?? content.get()?.video else {
            return .result(value: nil)
        }
        let data = try await service.download(capture.id, file)
        return .result(value: .init(data: data, filename: "\(file.fileUUID).mp4"))
    }
}

public struct GetBestPhotoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Best Photo"
    public static var description: IntentDescription? = .init("Returns the best photo for a given capture.",
                                                              categoryName: "Captures",
                                                              resultValueName: "Best Photo"
    )
    public static var parameterSummary: some ParameterSummary {
        Summary("Get best photo from \(\.$capture)")
    }
    
    @Parameter(title: "Capture")
    public var capture: CaptureEntity

    public init(capture: CaptureEntity) {
        self.capture = capture
    }
    
    public init(capture: Capture) {
        self.capture = CaptureEntity(from: capture)
    }
    
    public init() {}
    
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true
    
    @Dependency
    var service: HumaneCenterService

    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile?> {
        let content = try await service.memory(capture.id)
        guard let file = content.get()?.closeupAsset ?? content.get()?.thumbnail else {
            return .result(value: nil)
        }
        let data = try await service.download(capture.id, file)
        return .result(value: .init(data: data, filename: "\(file.fileUUID).jpg"))
    }
}

// MARK: - Media Save Manager
struct MediaSaveManager {
    static var cachedFilenames: Set<String> = Set<String>()
    static let cacheQueue = DispatchQueue(label: "com.example.MediaSaveManager.cacheQueue")
    
    static func saveImageToPhotoLibrary(data: Data, creationDate: Date, name: String) async throws {
        guard let image = UIImage(data: data) else {
            throw CaptureIntentError.invalidContent
        }
        
        let album = try await getAlbum(named: "Ai Pin")
        let filename = "\(name).jpg"
        
        // Check if the asset already exists using the cache
        if assetExists(filename: filename) {
            print("Image \(filename) already exists in album \(album.localizedTitle ?? "")")
            return
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = filename
            options.shouldMoveFile = true
            creationRequest.addResource(with: .photo, data: data, options: options)
            creationRequest.creationDate = creationDate
            
            if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
               let assetPlaceholder = creationRequest.placeholderForCreatedAsset {
                let enumeration: NSArray = [assetPlaceholder]
                albumChangeRequest.addAssets(enumeration)
            }
        }
        
        // Update the cache
        cacheQueue.sync {
            cachedFilenames.insert(filename)
        }
    }
    
    static func saveVideoToPhotoLibrary(data: Data, filename: String, creationDate: Date) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            let album = try await getAlbum(named: "Ai Pin")
            
            // Check if the asset already exists using the cache
            if assetExists(filename: filename) {
                print("Video \(filename) already exists in album \(album.localizedTitle ?? "")")
                return
            }
            
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                request?.creationDate = creationDate
                
                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                   let assetPlaceholder = request?.placeholderForCreatedAsset {
                    let enumeration: NSArray = [assetPlaceholder]
                    albumChangeRequest.addAssets(enumeration)
                }
            }
            try? FileManager.default.removeItem(at: tempURL)
            
            // Update the cache
            cacheQueue.sync {
                cachedFilenames.insert(filename)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw CaptureIntentError.saveFailed
        }
    }
    
    static func getAlbum(named albumName: String) async throws -> PHAssetCollection {
        // Existing code to fetch or create the album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        
        var album: PHAssetCollection
        if let existingAlbum = collection.firstObject {
            album = existingAlbum
        } else {
            var albumPlaceholder: PHObjectPlaceholder?
            try await PHPhotoLibrary.shared().performChanges {
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }
            guard let placeholder = albumPlaceholder else {
                throw CaptureIntentError.saveFailed
            }
            let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
            guard let newAlbum = fetchResult.firstObject else {
                throw CaptureIntentError.saveFailed
            }
            album = newAlbum
        }
        
        // Fetch and cache filenames
        cacheFilenames(for: album)
        
        return album
    }
    
    static func cacheFilenames(for album: PHAssetCollection) {
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        var filenames = Set<String>()
        assets.enumerateObjects { (asset, _, _) in
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                filenames.insert(resource.originalFilename)
            }
        }
        cacheQueue.sync {
            cachedFilenames = filenames
        }
    }
    
    static func assetExists(filename: String) -> Bool {
        return cacheQueue.sync {
            cachedFilenames.contains(filename)
        }
    }
}

// MARK: - Sync Captures Intent
public struct SyncCapturesIntent: AppIntent, TaskableIntent {
    public static var title: LocalizedStringResource = "Sync Captures"
    
    @Dependency public var service: HumaneCenterService
    @Dependency public var database: any Database
    @Dependency public var app: AppState
    @Dependency public var navigation: Navigation
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        defer {
            Task.detached {
                await MainActor.run {
                    app.isCapturesLoading = false
                }
            }
        }
        
        await MainActor.run {
            app.isCapturesLoading = true
        }
        
        let chunkSize = 20
        
        do {
            let total = try await service.captures(0, 1).totalElements
            let totalPages = (total + chunkSize - 1) / chunkSize
            
            // Check photo library access first
            if total > 0 {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if status == .notDetermined {
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    guard newStatus == .authorized else {
                        throw CaptureIntentError.noPhotoAccess
                    }
                }
                await MainActor.run {
                    app.hasPhotosPermission = true
                }
            }
            
            await MainActor.run {
                withAnimation {
                    app.totalCapturesToSync = total
                    app.numberOfCapturesSynced = 0
                }
            }
            
            // Process all pages concurrently
            let pageIndices = 0..<totalPages
            let processedIdsArray = try await pageIndices.concurrentMap { page in
                let data = try await service.captures(page, chunkSize)
                return try await processCaptures(data.content)
            }
            let processedIds = processedIdsArray.flatMap { $0 }
            
            // Clean up deleted captures
            try await cleanupDeletedCaptures(processedIds)
            
            await MainActor.run {
                withAnimation {
                    app.totalCapturesToSync = 0
                    app.numberOfCapturesSynced = 0
                }
            }
            
            return .result()
            
        } catch {
            await MainActor.run {
                app.totalCapturesToSync = 0
                app.numberOfCapturesSynced = 0
            }
            throw CaptureIntentError.syncFailed
        }
    }
    
    private func processCaptures(_ content: [MemoryContentEnvelope]) async throws -> [UUID] {
        try await withThrowingTaskGroup(of: UUID.self) { group in
            for envelope in content {
                group.addTask {
                    let capture = try Capture(from: envelope)
                    
                    // Only download if not already downloaded
                    let existingCapture = try? await database.fetch(
                        Capture.all(predicate: #Predicate<Capture> { $0.uuid == envelope.id })
                    ).first
                    
                    // Use existing locallyDownloaded value if available
                    let isLocallyDownloaded = existingCapture?.locallyDownloaded ?? false
                    
                    if !isLocallyDownloaded {
                        do {
                            try await self.downloadToPhotoLibrary(envelope)
                            capture.locallyDownloaded = true
                        } catch {
                            // Log error but continue with sync
                            print("Failed to download capture \(envelope.id): \(error)")
                        }
                    } else {
                        capture.locallyDownloaded = true
                    }
                    
                    capture.lastSyncDate = Date()
                    await database.insert(capture)
                    
                    await MainActor.run {
                        withAnimation {
                            app.numberOfCapturesSynced += 1
                        }
                    }
                    
                    return envelope.id
                }
            }
            
            var processedIds = [UUID]()
            for try await id in group {
                processedIds.append(id)
            }
            return processedIds
        }
    }
    
    private func downloadToPhotoLibrary(_ envelope: MemoryContentEnvelope) async throws {
        let captureEntity = await CaptureEntity(from: envelope)
        
        switch captureEntity.type {
        case .photo:
            try await retry {
                let photoIntent = GetBestPhotoIntent(capture: captureEntity)
                let result = try await photoIntent.perform()
                
                if let photo = result.value,
                   let data = photo?.data {
                    try await MediaSaveManager.saveImageToPhotoLibrary(
                        data: data,
                        creationDate: captureEntity.createdAt,
                        name: captureEntity.id.uuidString
                    )
                } else {
                    throw CaptureIntentError.downloadFailed
                }
                
            }
            
        case .video:
            try await retry {
                let videoIntent = GetVideoIntent(capture: captureEntity)
                let result = try await videoIntent.perform()
                
                if let video = result.value,
                   let data = video?.data,
                   let filename = video?.filename {
                    try await MediaSaveManager.saveVideoToPhotoLibrary(
                        data: data,
                        filename: filename,
                        creationDate: captureEntity.createdAt
                    )
                } else {
                    throw CaptureIntentError.downloadFailed
                }
            }
        }
    }
    
    private func cleanupDeletedCaptures(_ validIds: [UUID]) async throws {
        let predicate = #Predicate<Capture> {
            !validIds.contains($0.uuid)
        }
        try await database.delete(where: predicate)
        try await database.save()
    }
}
