import SwiftUI
import OSLog

@Observable public class NotesRepository {
    let logger = Logger()
    var api: HumaneCenterService
    var data: PageableMemoryContentEnvelope?
    var content: [ContentEnvelope] = []
    var isLoading: Bool = false
    var isFinished: Bool = false
    var hasMoreData: Bool = false
    var hasContent: Bool {
        !isLoading && isFinished && !content.isEmpty
    }
        
    public init(api: HumaneCenterService) {
        self.api = api
    }
}

extension NotesRepository {
    private func load(page: Int = 0, size: Int = 10) async {
        isLoading = true
        do {
            let data = try await api.notes(page, size)
            self.data = data
            self.hasMoreData = data.totalPages > 1
            withAnimation {
                self.content = data.content
            }
        } catch {
            logger.debug("\(error)")
        }
        isFinished = true
        isLoading = false
    }
    
    public func initial() async {
        guard !isFinished else { return }
        await load()
    }
    
    public func reload() async {
        await load()
    }
    
    public func loadMore() async {
        guard let data, hasMoreData else {
            return
        }
        let nextPage = min(data.pageable.pageNumber + 1, data.totalPages)
        logger.debug("next page: \(nextPage)")
        await load(page: nextPage)
    }
    
    public func remove(offsets: IndexSet) async {
        do {
            for i in offsets {
                let note = withAnimation {
                    content.remove(at: i)
                }
                try await api.delete(note)
            }
        } catch {
            logger.debug("\(error)")
        }
    }
    
    public func toggleFavorite(content: ContentEnvelope) async {
        do {
            if content.favorite {
                try await api.unfavorite(content)
            } else {
                try await api.favorite(content)
            }
            guard let idx = self.content.firstIndex(where: { $0.uuid == content.uuid }) else {
                return
            }
            self.content[idx].favorite = !content.favorite
        } catch {
            
        }
    }
    
    public func create(note: Note) async {
        do {
            let note = try await api.create(note)
            withAnimation {
                content.insert(note, at: 0)
            }
        } catch {
            logger.debug("\(error)")
        }
    }
    
    public func update(note: Note) async {
        do {
            let note = try await api.update(note.memoryId!.uuidString, .init(text: note.text, title: note.title))
            guard let idx = self.content.firstIndex(where: { $0.uuid == note.uuid }) else {
                return
            }
            withAnimation {
                self.content[idx] = note
            }
        } catch {
            logger.debug("\(error)")
        }
    }
}
