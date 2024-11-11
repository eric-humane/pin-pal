import SwiftUI
import AppIntents
import PinKit
import SwiftData
import BackgroundTasks

@main
struct PinPalApp: App {

    @State
    private var sceneAppState: AppState

    @State
    private var sceneNavigationStore: Navigation
    
    @State
    private var sceneService: HumaneCenterService

    @State
    private var sceneModelContainer: ModelContainer

    @Environment(\.scenePhase)
    private var phase
    
    let sceneDatabase: any Database

    init() {
        let navigationStore = Navigation.shared
        sceneNavigationStore = navigationStore
        
        let service = HumaneCenterService.live()
        sceneService = service

        let schema = Schema(CurrentScheme.models)
        let modelContainer: ModelContainer = {
            do {
                let modelContainerConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: modelContainerConfig)
            } catch {
                let modelContainerConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: modelContainerConfig)
                } catch {
                    fatalError("\(error)")
                }
            }
        }()
        sceneModelContainer = modelContainer
        
        let database = SharedDatabase(modelContainer: modelContainer).database
        sceneDatabase = database
        
        let appState = AppState()
        sceneAppState = appState

        AppDependencyManager.shared.add(dependency: appState)
        AppDependencyManager.shared.add(dependency: navigationStore)
        AppDependencyManager.shared.add(dependency: service)
        AppDependencyManager.shared.add(dependency: database)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sceneNavigationStore)
                .environment(sceneService)
                .environment(sceneAppState)
                .environment(\.database, sceneDatabase)
                .defaultAppStorage(.init(suiteName: "group.com.ericlewis.Pin-Pal") ?? .standard)
                .modelContainer(sceneModelContainer)
                .onChange(of: phase) { oldPhase, newPhase in
                    switch (oldPhase, newPhase) {
                    case (.inactive, .background):
                        if sceneService.isLoggedIn() {
                            requestRefreshBackgroundTask(for: .captures)
                        }
                    default: break
                    }
                }
#if os(visionOS)
                .onAppear {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                        fatalError()
                    }
                    let geometryRequest = UIWindowScene.GeometryPreferences.Vision(
                        resizingRestrictions: .uniform
                    )
                    windowScene.requestGeometryUpdate(geometryRequest)
                }
#elseif targetEnvironment(macCatalyst)
                .onAppear {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                        fatalError()
                    }
                    windowScene.titlebar?.titleVisibility = .hidden
                }
#endif
        }
        .backgroundTask(.appRefresh(Constants.taskId(for: .captures))) {
            await handleCapturesRefresh()
        }
        #if os(visionOS)
        .defaultSize(width: 730, height: 1000)
        #endif
    }
}

extension PinPalApp {
    func requestRefreshBackgroundTask(for id: SyncIdentifier) {
        let request = BGAppRefreshTaskRequest(identifier: Constants.taskId(for: id))
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60) // 1 min
        do {
            try BGTaskScheduler.shared.submit(request)
            print("submitted bg task: \(id.rawValue)")
        } catch {
            print("Could not schedule app refresh: \(error) for \(id.rawValue)")
        }
    }

    func handleCapturesRefresh() async {
        do {
            let intent = SyncCapturesIntent()
            intent.database = sceneDatabase
            intent.service = sceneService
            intent.app = sceneAppState
            intent.navigation = sceneNavigationStore
            let _ = try await intent.perform()
            requestRefreshBackgroundTask(for: .captures)
        } catch {
            print(error)
        }
    }
}
