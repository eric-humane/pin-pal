import SwiftUI
import SwiftData

struct CapturesView: View {
    
    enum Filter {
        case all
        case photo
        case video
        case favorites
    }

    @Environment(\.database)
    private var database
    
    @Environment(HumaneCenterService.self)
    private var service
    
    @Environment(AppState.self)
    private var app

    @State
    private var query = ""
    
    @State
    private var isLoading = false
    
    @State
    private var isFirstLoad = true

    @State
    private var imageContentMode = ContentMode.fill
    
    @State
    private var ids: [UUID] = []
 
    var body: some View {
        let captureFilter = app.captureFilter
        NavigationStack {
            list
                .environment(\.imageContentMode, imageContentMode)
                .task(id: query, search)
                .onChange(of: captureFilter.order) {
                    withAnimation(.snappy) {
                        captureFilter.sort.order = captureFilter.order
                    }
                }
                .environment(\.isLoading, isLoading)
                .environment(\.isFirstLoad, isFirstLoad)
                .overlay(alignment: .bottom) {
                    SyncStatusView(
                        current: \.numberOfCapturesSynced,
                        total: \.totalCapturesToSync
                    )
                }
                .refreshable(action: load)
                .searchable(text: $query)
                .navigationTitle("Captures")
                .toolbar {
                    toolbar
                }
        }
        .task(initial)
    }
    
    var predicate: Predicate<Capture> {
        if !query.isEmpty {
            return #Predicate<Capture> {
                ids.contains($0.uuid)
            }
        } else {
            switch app.captureFilter.type {
            case .all:
                return #Predicate<Capture> { _ in
                    true
                }
            case .photo:
                return #Predicate<Capture> {
                    $0.isPhoto
                }
            case .video:
                return #Predicate<Capture> {
                    !$0.isPhoto
                }
            case .favorites:
                return #Predicate<Capture> {
                    $0.isFavorite
                }
            }
        }
    }
    
    @ViewBuilder
    var list: some View {
        var descriptor = app.captureFilter.filter
        let _ = descriptor.predicate = predicate
        let _ = descriptor.sortBy = [app.captureFilter.sort]
        QueryGridView(descriptor: descriptor) { capture in
            NavigationLink {
                CaptureDetailView(capture: capture)
            } label: {
                CaptureCellView(capture: capture, isFavorite: capture.isFavorite)
            }
            .contextMenu {
                CaptureMenuContents(capture: capture, isFavorite: capture.isFavorite)
            } preview: {
                CaptureImageView(capture: capture)
            }
            .buttonStyle(.plain)
        } placeholder: {
            ContentUnavailableView("No captures yet", systemImage: "camera.aperture")
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Select") {
                
            }
            .disabled(true)
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            @Bindable var captureFilter = app.captureFilter
            if imageContentMode == .fill {
                Button("Aspect Ratio Grid", systemImage: "rectangle.arrowtriangle.2.inward") {
                    withAnimation(.snappy) {
                        imageContentMode = .fit
                    }
                }
            } else {
                Button("Square Photo Grid", systemImage: "rectangle.arrowtriangle.2.outward") {
                    withAnimation(.snappy) {
                        imageContentMode = .fill
                    }
                }
            }
            Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                Toggle("All Items", systemImage: "photo.on.rectangle", isOn: captureFilter.toggle(filter: .all))
                Section {
                    Toggle("Favorites", systemImage: "heart", isOn: captureFilter.toggle(filter: .favorites))
                    Toggle("Photos", systemImage: "photo", isOn: captureFilter.toggle(filter: .photo))
                    Toggle("Videos", systemImage: "video", isOn: captureFilter.toggle(filter: .video))
                }
            }
            .symbolVariant(captureFilter.type == .all ? .none : .fill)
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Toggle("Created At", isOn: captureFilter.toggle(sortedBy: \.createdAt))
                Toggle("Modified At", isOn: captureFilter.toggle(sortedBy: \.modifiedAt))
                Section("Order") {
                    Picker("Order", selection: $captureFilter.order) {
                        Label("Ascending", systemImage: "arrow.up").tag(SortOrder.forward)
                        Label("Descending", systemImage: "arrow.down").tag(SortOrder.reverse)
                    }
                }
            }
        }
    }
}

extension CapturesView {
    func search() async {
        do {
            isLoading = true
            try await Task.sleep(for: .milliseconds(300))
            let intent = SearchCapturesIntent()
            intent.query = query
            intent.service = service
            guard !query.isEmpty, let result = try await intent.perform().value else {
                self.ids = []
                self.isLoading = false
                return
            }
            withAnimation(.snappy) {
                self.ids = result.map(\.id)
                isLoading = false
            }
        } catch is CancellationError {
            
        } catch {
            
        }
    }
    
    func initial() async {
        guard !isLoading, isFirstLoad else { return }
        Task.detached {
            await load()
        }
    }
    
    func load() async {
        isLoading = true
        do {
            let intent = SyncCapturesIntent()
            intent.database = database
            intent.service = service
            intent.app = app
            try await intent.perform()
        } catch {
            print(error)
        }
        isLoading = false
        isFirstLoad = false
    }
}
