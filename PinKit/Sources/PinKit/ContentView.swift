import SwiftUI
import SDWebImage

public struct ContentView: View {

    public init() {
        SDWebImageManager.shared.cacheKeyFilter = SDWebImageCacheKeyFilter { url in
            if url.host() == "humane.center" {
                return url.absoluteString
            }
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            return components?.url?.absoluteString ?? ""
        }
    }
    
    public var body: some View {
        CapturesView()
            .modifier(AuthHandlerViewModifier())
    }
}

#Preview {
    ContentView()
}
