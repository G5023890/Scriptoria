import Foundation

struct SeedSampleDataUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository
    let assignLabelsUseCase: AssignLabelsUseCase
    let markdownService: any MarkdownService
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func executeIfNeeded() async throws {
        guard try await notesRepository.count() == 0 else {
            return
        }

        let sampleData = SampleDataFactory.make(markdownService: markdownService, dateService: dateService)
        for label in sampleData.labels {
            try await labelsRepository.create(label: label)
        }
        for note in sampleData.notes {
            try await notesRepository.create(note: note)
            try await assignLabelsUseCase.execute(
                noteID: note.id,
                labelIDs: sampleData.labelAssignments[note.id] ?? []
            )
        }
        for attachment in sampleData.attachments {
            try await attachmentsRepository.add(attachment: attachment)
        }
        for note in sampleData.notes {
            let snippets = sampleData.snippets.filter { $0.noteID == note.id }
            _ = try await attachmentsRepository.replaceSnippets(snippets, for: note.id)
            try await indexNoteForSearchUseCase.execute(noteID: note.id)
        }
    }
}
