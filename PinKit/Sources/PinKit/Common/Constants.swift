import SwiftUI

public struct Constants {
    public static let ACCESS_TOKEN = "ACCESS_TOKEN_V1"
    public static let USER_ID = "USER_ID_V1"
}

public enum SyncIdentifier: String {
    case captures
}

extension Constants {
    public static func taskId(for id: SyncIdentifier) -> String {
        switch id {
        case .captures: "com.ericlewis.Pin-Pal.Captures.refresh"
        }
    }
}
