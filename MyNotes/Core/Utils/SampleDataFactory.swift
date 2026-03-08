import Foundation

struct SampleDataBundle {
    let notes: [Note]
    let labels: [Label]
    let labelAssignments: [NoteID: [LabelID]]
    let attachments: [Attachment]
    let snippets: [NoteSnippet]
}

enum SampleDataFactory {
    static func make(markdownService: any MarkdownService, dateService: any DateService) -> SampleDataBundle {
        let now = dateService.now()
        let labels = makeLabels(now: now)
        let notes = makeNotes(markdownService: markdownService, now: now)
        let attachment = makeAttachment(now: now)
        let snippet = makeSnippet(now: now)

        return SampleDataBundle(
            notes: notes,
            labels: labels,
            labelAssignments: [
                NoteID(rawValue: "note-welcome"): [labels[2].id],
                NoteID(rawValue: "note-swift-snippet"): [labels[0].id],
                NoteID(rawValue: "note-attachments"): [labels[2].id, labels[1].id]
            ],
            attachments: [attachment],
            snippets: [snippet]
        )
    }
}
