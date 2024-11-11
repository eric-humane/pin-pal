import SwiftUI
import AppIntents
import Models

@Observable public class Navigation: @unchecked Sendable {
    public static let shared = Navigation()

    public var authenticationPresented = false
        
    public init() {}

}
