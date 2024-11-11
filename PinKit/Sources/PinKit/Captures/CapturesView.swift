import SwiftUI
import SwiftData

struct CapturesView: View {
    
    enum Filter {
        case all
        case photo
        case video
        case favorites
    }

    @Environment(Navigation.self)
    private var navigation
    
    @Environment(AppState.self)
    private var app

    @State
    private var isFirstLoad = true

    @State
    private var imageContentMode = ContentMode.fill

    var body: some View {
        let captureFilter = app.captureFilter
        NavigationStack {
            list
                .environment(\.imageContentMode, imageContentMode)
                .onChange(of: captureFilter.order) {
                    withAnimation(.snappy) {
                        captureFilter.sort.order = captureFilter.order
                    }
                }
                .environment(\.isLoading, app.isCapturesLoading)
                .environment(\.isFirstLoad, isFirstLoad)
                .navigationTitle("Captures")
                .toolbar {
                    toolbar
                }
        }
        .task(intent: SyncCapturesIntent())
        .onChange(of: app.isCapturesLoading) {
            if !app.isCapturesLoading {
                isFirstLoad = false
            }
        }
    }
    
    var predicate: Predicate<Capture> {
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
    
    @ViewBuilder
    var list: some View {
        var descriptor = app.captureFilter.filter
        let _ = descriptor.predicate = predicate
        let _ = descriptor.sortBy = [app.captureFilter.sort]
        QueryGridView(descriptor: descriptor) { capture in
            NavigationLink {
                CaptureDetailView(capture: capture)
            } label: {
                CaptureCellView(
                    capture: capture,
                    isFavorite: capture.isFavorite,
                    state: capture.state,
                    type: capture.type
                )
            }
            .buttonStyle(.plain)
        } placeholder: {
            ContentUnavailableView("No captures yet", systemImage: "camera.aperture")
        } emptyPlaceholder: {
            ProgressView("syncing: \(app.numberOfCapturesSynced)/\(app.totalCapturesToSync)",
                         value: Float(app.numberOfCapturesSynced),
                         total: Float(app.totalCapturesToSync))
            .progressViewStyle(.circular)
        }
        .refreshable(intent: SyncCapturesIntent())
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        if !app.hasPhotosPermission {
            ToolbarItem(placement: .status) {
                Text("Need permission.")
            }
        } else if app.isCapturesLoading {
            ToolbarItem(placement: .status) {
                Text("syncing: \(app.numberOfCapturesSynced)/\(app.totalCapturesToSync)")
                    .monospaced()
            }
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
            Section {
                Button("Sign Out", role: .destructive, intent: _SignOutIntent())
                .tint(.red)
            }
        }
    }
}
