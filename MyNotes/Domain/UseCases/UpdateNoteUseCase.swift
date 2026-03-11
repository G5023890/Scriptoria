import Foundation

struct UpdateNoteUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let markdownService: any MarkdownService
    let dateService: any DateService
    let createSnippetUseCase: CreateSnippetUseCase
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(draft: NoteDraft) async throws -> Note? {
        guard var note = try await notesRepository.note(id: draft.noteID) else { return nil }
        let now = dateService.now()
        note.title = draft.title
        note.bodyMarkdown = draft.bodyMarkdown
        note.bodyPlainText = markdownService.plainText(from: draft.bodyMarkdown)
        note.previewText = markdownService.previewText(from: draft.bodyMarkdown, limit: 160)
        note.primaryType = markdownService.detectPrimaryType(in: draft.bodyMarkdown)
        note.snippetLanguageHint = markdownService.detectSnippetLanguageHint(in: draft.bodyMarkdown)
        note.updatedAt = now
        note.sortDate = now
        note.version += 1
        try await notesRepository.update(note: note)
        try await labelsRepository.assign(labelIDs: draft.labels.map(\.id), to: draft.noteID)
        _ = try await createSnippetUseCase.execute(for: note)
        try await indexNoteForSearchUseCase.execute(noteID: draft.noteID)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
        return note
    }
}
