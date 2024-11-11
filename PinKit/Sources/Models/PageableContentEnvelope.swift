import Foundation

public struct PageableContentEnvelope<C: Codable>: Codable {
    public var content: [C]
    public let totalElements: Int
}

public typealias PageableMemoryContentEnvelope = PageableContentEnvelope<MemoryContentEnvelope>
