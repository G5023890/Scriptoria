import Foundation

protocol SearchIndexRepository {
    func upsert(_ document: SearchDocument) async throws
    func remove(noteID: NoteID) async throws
    func allDocuments() async throws -> [SearchDocument]
}

struct LocalSearchIndexRepository: SearchIndexRepository {
    let dataSource: SearchLocalDataSource

    func upsert(_ document: SearchDocument) async throws {
        try dataSource.upsert(document)
    }

    func remove(noteID: NoteID) async throws {
        try dataSource.remove(noteID: noteID)
    }

    func allDocuments() async throws -> [SearchDocument] {
        try dataSource.allDocuments()
    }
}
