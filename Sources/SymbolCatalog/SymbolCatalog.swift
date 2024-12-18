import SwiftUI
import Combine
import AppKit

// MARK: - Models
struct SymbolMetadata: Decodable {
    let fileName: String
    let unicodeKey: String
    let keywords: [String]
}

struct SymbolItem: Identifiable, Decodable {
    let symbol: String
    let name: String
    let metadata: SymbolMetadata

    var id: String { symbol }

    enum CodingKeys: String, CodingKey {
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let symbolKey = container.allKeys.first(where: { $0.stringValue != "metadata" }) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "No symbol key found"
            ))
        }

        symbol = symbolKey.stringValue
        name = try container.decode(String.self, forKey: symbolKey)
        metadata = try container.decode(SymbolMetadata.self, forKey: .metadata)
    }
}

// MARK: - Color Management
enum NamedColor: CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple
    case pink, brown, white, gray, black, primary, secondary, tertiary
    case quaternary, accent

    var name: String {
        String(describing: self).localizedCapitalized
    }

    var id: String { name }

    var nsColor: NSColor {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .systemMint
        case .teal: return .systemTeal
        case .cyan: return .systemCyan
        case .blue: return .blue
        case .indigo: return .systemIndigo
        case .purple: return .purple
        case .pink: return .systemPink
        case .brown: return .brown
        case .white: return .white
        case .gray: return .gray
        case .black: return .black
        case .primary: return .labelColor
        case .secondary: return .secondaryLabelColor
        case .tertiary: return .tertiaryLabelColor
        case .quaternary: return .quaternaryLabelColor
        case .accent: return .controlAccentColor
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    private static var swatchCache: [NamedColor: NSImage] = [:]

    var swatch: NSImage {
        if let cached = Self.swatchCache[self] {
            return cached
        }

        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { rect in
            nsColor.setFill()
            rect.fill()
            return true
        }
        image.cacheMode = .always
        Self.swatchCache[self] = image
        return image
    }

    static func clearCache() {
        swatchCache.removeAll()
    }
}

// MARK: - View Model
@Observable
final class SymbolCatalogViewModel {
    private(set) var symbols: [String: SymbolItem] = [:]
    private(set) var error: Error?
    var searchText: String = ""

    private let pageSize = 50
    private var currentPage = 0

    var filteredSymbols: [SymbolItem] {
        let allItems = Array(symbols.values)
        guard !searchText.isEmpty else {
            return Array(allItems.prefix(pageSize * (currentPage + 1)))
        }

        let query = searchText.lowercased()
        return allItems.filter { item in
            item.name.lowercased().contains(query) ||
            item.metadata.keywords.joined(separator: " ").lowercased().contains(query)
        }
    }

    func loadNextPage() {
        currentPage += 1
    }

    init() {
        loadSymbols()
    }

    func loadSymbols() {
        guard let url = Bundle.main.url(forResource: "AiPin-SymbolsVF-Metadata", withExtension: "json") else {
            error = NSError(domain: "SymbolCatalog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metadata file not found"])
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decodedArray = try JSONDecoder().decode([SymbolItem].self, from: data)
            self.symbols = Dictionary(uniqueKeysWithValues: decodedArray.map { ($0.symbol, $0) })
            error = nil
        } catch {
            self.error = error
        }
    }
}

// MARK: - Views
struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            Text("Error Loading Symbols")
                .font(.headline)
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct SymbolCell: View {
    let item: SymbolItem

    var body: some View {
        VStack {
            Text(item.symbol)
                .font(.largeTitle)
                .frame(height: 40)
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct InspectorView: View {
    @Binding var selectedName: String
    @Binding var colorName: Color
    @Binding var background: Color
    @Binding var opacity: Double

    var body: some View {
        VStack {
            VStack(spacing: 15) {
                VStack {
                    GroupBox {
                        ZStack {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 1)
                            Text(String(selectedName))
                                .font(.custom("Ai Pin", size: 100))
                                .padding()
                                .foregroundStyle(colorName.opacity(opacity))
                        }
                    }
                    Text("asdfasdf")
                        .font(.headline)
                }

                // MARK: Color Picker Section
                VStack(alignment: .leading) {
                    Text("Color")
                        .font(.headline)
                    HStack {
                        Picker("Color", selection: $colorName.animation()) {
                            ForEach(NamedColor.allCases) { color in
                                HStack {
                                    Image(nsImage: color.swatch)
                                    Text(color.name)
                                }.tag(color.color)
                            }
                        }
                        .labelsHidden()
                        TextField("Opacity", value: $opacity.animation(), format: .percent)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 55)
                            .focusable(false)
                    }
                }

                // MARK: Background Picker Section
                VStack(alignment: .leading) {
                    Text("Background")
                        .font(.headline)
                    Picker("Background", selection: $background) {
                        ForEach([NamedColor.black, .white]) { color in
                            HStack {
                                Image(nsImage: color.swatch)
                                Text(color.name)
                            }.tag(color.color)
                        }
                    }
                    .labelsHidden()
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct ContentView: View {
    @State private var viewModel = SymbolCatalogViewModel()
    @State private var sidebarOpen = true
    @State private var primaryColor = Color.primary
    @State private var backgroundColor = Color.black
    @State private var opacity = 1.0
    @State private var selectedName: String = ""

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            Color.clear
                .accessibilityHidden(true)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(0)
        } content: {
            Color.clear
                .accessibilityHidden(true)
                .navigationSplitViewColumnWidth(0)
                .navigationTitle("All")
                .navigationSubtitle("\(viewModel.symbols.count) Symbols")
        } detail: {
            Group {
                if let error = viewModel.error {
                    ErrorView(error: error)
                } else if viewModel.symbols.isEmpty {
                    ProgressView("Loading symbols...")
                } else if viewModel.filteredSymbols.isEmpty {
                    Text("No symbols match your search")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [.init(.adaptive(minimum: 100, maximum: 120), spacing: 30)], spacing: 20) {
                            ForEach(viewModel.filteredSymbols) { item in
                                VStack {
                                    ZStack {
                                        backgroundColor
                                        Text(String(item.symbol))
                                            .font(.custom("Ai Pin", size: 40))
                                            .foregroundStyle(primaryColor)
                                    }
                                    .frame(width: 100, height: 80)
                                    .aspectRatio(contentMode: .fit)
                                    .border(.quaternary, width: 3)
                                    .onTapGesture {
                                        selectedName = item.symbol
                                    }
                                    Text(item.name)
                                        .lineLimit(2, reservesSpace: true)
                                        .multilineTextAlignment(.center)
                                }
                                .onAppear {
                                    if item == viewModel.filteredSymbols.last {
                                        viewModel.loadNextPage()
                                    }
                                }
                            }
                        }
                        .safeAreaPadding()
                    }
                }
            }
            .background(.background)
            .inspector(isPresented: $sidebarOpen) {
                InspectorView(
                    selectedName: $selectedName,
                    colorName: $primaryColor,
                    background: $backgroundColor,
                    opacity: $opacity
                )
                .interactiveDismissDisabled()
                .inspectorColumnWidth(min: 400, ideal: 400)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: .infinity, max: .infinity)
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ControlGroup {
                    Picker("View Style", selection: .constant("")) {
                        Label("Grid", systemImage: "square.grid.2x2").tag("")
                        Label("List", systemImage: "list.bullet")
                        Label("Detail", systemImage: "squares.below.rectangle")
                    }
                    .pickerStyle(.segmented)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Toggle Inspector", systemImage: "sidebar.trailing") {
                    sidebarOpen.toggle()
                }
                .offset(x: 10, y: 0)
            }
        }
    }
}

@main
struct SymbolCatalogApp: App {
    init() {
        verifyFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func verifyFonts() {
        guard let fontURL = Bundle.main.url(forResource: "AiPin", withExtension: "ttf"),
              CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) else {
            fatalError("Required font 'Ai Pin' is missing")
        }
    }
}

#Preview {
    ContentView()
}
