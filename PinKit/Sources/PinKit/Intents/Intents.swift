import AppIntents
import Foundation
import PinKit
import SwiftUI
import Models
import SwiftData
import CollectionConcurrencyKit

public protocol DatabaseIntent {
    var database: any Database { get set }
}

public protocol ServiceIntent {
    var service: HumaneCenterService { get set }
}

public protocol AppStateIntent {
    var app: AppState { get set }
}

public typealias TaskableIntent = DatabaseIntent & ServiceIntent & AppStateIntent

// MARK: Util

extension EntityQuerySort.Ordering {
    /// Convert sort information from `EntityQuerySort` to  Foundation's `SortOrder`.
    var sortOrder: SortOrder {
        switch self {
        case .ascending:
            return SortOrder.forward
        case .descending:
            return SortOrder.reverse
        }
    }
}

// MARK: Device

import WebKit
public struct _SignOutIntent: AppIntent {
    public static var title: LocalizedStringResource = "Sign Out Account"

    public init() {}

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false
    
    @Dependency
    public var service: HumaneCenterService
    
    @Dependency
    public var navigation: Navigation
    
    @Dependency
    public var database: any Database

    @MainActor
    public func perform() async throws -> some IntentResult {
        let sessionCookieStorage = URLSession.shared.configuration.httpCookieStorage
        sessionCookieStorage?.removeCookies(since: .distantPast)
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
        try? await database.delete(where: #Predicate<Capture>{ _ in true })
        
        try await database.save()
        
        service.accessToken = nil
        
        navigation.authenticationPresented = true
        
        return .result()
    }
    
    enum Error: Swift.Error {
       
    }
}
