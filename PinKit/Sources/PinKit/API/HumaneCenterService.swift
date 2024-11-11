import Foundation
import Models

public enum FeatureFlag: String, Codable {
    case visionAccess
    case betaAccess
}

@Observable public class HumaneCenterService: Sendable {
    public static let shared = HumaneCenterService.live

    public var accessToken: String? {
        get {
            (UserDefaults(suiteName: "group.com.ericlewis.Pin-Pal") ?? .standard).string(forKey: Constants.ACCESS_TOKEN)
        }
        set {
            (UserDefaults(suiteName: "group.com.ericlewis.Pin-Pal") ?? .standard).setValue(newValue, forKey: Constants.ACCESS_TOKEN)
        }
    }
    
    public var captures: (Int, Int) async throws -> PageableMemoryContentEnvelope
    public var memory: (UUID) async throws -> MemoryContentEnvelope
    public var deviceIdentifiers: () async throws -> [String]

    public var download: (UUID, FileAsset) async throws -> Data

    required public init(
        captures: @escaping (Int, Int) async throws -> PageableMemoryContentEnvelope,
        memory: @escaping (UUID) async throws -> MemoryContentEnvelope,
        deviceIdentifiers: @escaping () async throws -> [String],
        download: @escaping (UUID, FileAsset) async throws -> Data
    ) {
        self.captures = captures
        self.memory = memory
        self.deviceIdentifiers = deviceIdentifiers
        self.download = download
    }
    
    public func isLoggedIn() -> Bool {
        self.accessToken != nil // TODO: also check cookies
    }
}

func extractValue(from text: String, forKey key: String) -> String? {
    let pattern = #"\\"\#(key)\\"[:]\\"([^"]+)\\""#
    
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    
    if let match = regex?.firstMatch(in: text, options: [], range: nsRange) {
        if let valueRange = Range(match.range(at: 1), in: text) {
            return String(text[valueRange])
        }
    }
    
    return nil
}
