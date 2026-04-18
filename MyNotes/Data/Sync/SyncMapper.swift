import CloudKit
import Foundation

struct SyncMapper {
    enum RecordType {
        static let note = "Note"
        static let label = "Label"
        static let toDo = "ToDo"
        static let attachment = "Attachment"
        static let snippet = "Snippet"
        static let noteLabel = "NoteLabel"
    }

    enum Field {
        static let attachmentAsset = "fileAsset"
    }

    struct RemoteNotePayload: Sendable {
        let note: Note
    }

    struct RemoteLabelPayload: Sendable {
        let label: Label
    }

    struct RemoteAttachmentPayload: Sendable {
        let attachment: Attachment
        let asset: CKAsset?
    }

    struct RemoteSnippetPayload: Sendable {
        let snippet: NoteSnippet
    }

    struct RemoteToDoPayload: Sendable {
        let toDo: ToDo
    }

    struct RemoteNoteLabelPayload: Sendable {
        let noteID: NoteID
        let labelID: LabelID
        let updatedAt: Date
        let version: Int
    }

    func noteRecord(for note: Note, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.note, recordID: recordID(for: .note, entityID: note.id.rawValue, zoneID: zoneID))
        record["localID"] = note.id.rawValue as CKRecordValue
        record["title"] = note.title as CKRecordValue
        record["bodyMarkdown"] = note.bodyMarkdown as CKRecordValue
        record["bodyPlainText"] = note.bodyPlainText as CKRecordValue
        record["previewText"] = note.previewText as CKRecordValue
        record["primaryType"] = note.primaryType.rawValue as CKRecordValue
        record["snippetLanguageHint"] = note.snippetLanguageHint as CKRecordValue?
        record["createdAt"] = note.createdAt as NSDate
        record["updatedAt"] = note.updatedAt as NSDate
        record["sortDate"] = note.sortDate as NSDate
        record["isPinned"] = NSNumber(value: note.isPinned)
        record["isFavorite"] = NSNumber(value: note.isFavorite)
        record["isArchived"] = NSNumber(value: note.isArchived)
        record["isDeleted"] = NSNumber(value: note.isDeleted)
        record["deletedAt"] = note.deletedAt as NSDate?
        record["version"] = NSNumber(value: note.version)
        return record
    }

    func labelRecord(for label: Label, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.label, recordID: recordID(for: .label, entityID: label.id.rawValue, zoneID: zoneID))
        record["localID"] = label.id.rawValue as CKRecordValue
        record["name"] = label.name as CKRecordValue
        record["color"] = label.color as CKRecordValue?
        record["iconName"] = label.iconName as CKRecordValue?
        record["isSystem"] = NSNumber(value: label.isSystem)
        record["createdAt"] = label.createdAt as NSDate
        record["updatedAt"] = label.updatedAt as NSDate
        record["isDeleted"] = NSNumber(value: label.isDeleted)
        record["deletedAt"] = label.deletedAt as NSDate?
        record["version"] = NSNumber(value: label.version)
        return record
    }

    func toDoRecord(for toDo: ToDo, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.toDo, recordID: recordID(for: .toDo, entityID: toDo.id.rawValue, zoneID: zoneID))
        record["localID"] = toDo.id.rawValue as CKRecordValue
        record["noteID"] = toDo.noteID.rawValue as CKRecordValue
        record["title"] = toDo.title as CKRecordValue
        record["details"] = toDo.details as CKRecordValue
        record["isCompleted"] = NSNumber(value: toDo.isCompleted)
        record["isArchived"] = NSNumber(value: toDo.isArchived)
        record["dueDate"] = toDo.dueDate as NSDate?
        record["hasTimeComponent"] = NSNumber(value: toDo.hasTimeComponent)
        record["snoozedUntil"] = toDo.snoozedUntil as NSDate?
        record["completedAt"] = toDo.completedAt as NSDate?
        record["sortOrder"] = NSNumber(value: toDo.sortOrder)
        record["priority"] = toDo.priority as CKRecordValue?
        record["createdAt"] = toDo.createdAt as NSDate
        record["updatedAt"] = toDo.updatedAt as NSDate
        record["isDeleted"] = NSNumber(value: toDo.isDeleted)
        record["deletedAt"] = toDo.deletedAt as NSDate?
        record["version"] = NSNumber(value: toDo.version)
        return record
    }

    func attachmentRecord(for attachment: Attachment, assetFileURL: URL?, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.attachment,
            recordID: recordID(for: .attachment, entityID: attachment.id.rawValue, zoneID: zoneID)
        )
        record["localID"] = attachment.id.rawValue as CKRecordValue
        record["noteID"] = attachment.noteID.rawValue as CKRecordValue
        record["fileName"] = attachment.fileName as CKRecordValue
        record["originalFileName"] = attachment.originalFileName as CKRecordValue
        record["mimeType"] = attachment.mimeType as CKRecordValue?
        record["category"] = attachment.category.rawValue as CKRecordValue
        record["description"] = attachment.description as CKRecordValue?
        record["relativePath"] = attachment.relativePath as CKRecordValue
        record["fileSize"] = attachment.fileSize.map(NSNumber.init(value:)) as CKRecordValue?
        record["checksum"] = attachment.checksum as CKRecordValue?
        record["width"] = attachment.width.map(NSNumber.init(value:)) as CKRecordValue?
        record["height"] = attachment.height.map(NSNumber.init(value:)) as CKRecordValue?
        record["duration"] = attachment.duration.map(NSNumber.init(value:)) as CKRecordValue?
        record["pageCount"] = attachment.pageCount.map(NSNumber.init(value:)) as CKRecordValue?
        record["createdAt"] = attachment.createdAt as NSDate
        record["updatedAt"] = attachment.updatedAt as NSDate
        record["isArchived"] = NSNumber(value: attachment.isArchived)
        record["isDeleted"] = NSNumber(value: attachment.isDeleted)
        record["deletedAt"] = attachment.deletedAt as NSDate?
        record["version"] = NSNumber(value: attachment.version)
        if let assetFileURL {
            record[Field.attachmentAsset] = CKAsset(fileURL: assetFileURL)
        }
        return record
    }

    func snippetRecord(for snippet: NoteSnippet, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.snippet, recordID: recordID(for: .snippet, entityID: snippet.id, zoneID: zoneID))
        record["localID"] = snippet.id as CKRecordValue
        record["noteID"] = snippet.noteID.rawValue as CKRecordValue
        record["language"] = snippet.language as CKRecordValue
        record["title"] = snippet.title as CKRecordValue?
        record["description"] = snippet.snippetDescription as CKRecordValue?
        record["code"] = snippet.code as CKRecordValue
        record["startOffset"] = snippet.startOffset.map(NSNumber.init(value:)) as CKRecordValue?
        record["endOffset"] = snippet.endOffset.map(NSNumber.init(value:)) as CKRecordValue?
        record["sourceType"] = snippet.sourceType.rawValue as CKRecordValue
        record["createdAt"] = snippet.createdAt as NSDate
        record["updatedAt"] = snippet.updatedAt as NSDate
        record["isArchived"] = NSNumber(value: snippet.isArchived)
        record["isDeleted"] = NSNumber(value: snippet.isDeleted)
        record["deletedAt"] = snippet.deletedAt as NSDate?
        record["version"] = NSNumber(value: snippet.version)
        return record
    }

    func noteLabelRecords(noteID: NoteID, labelIDs: [LabelID], payloadVersion: Int, updatedAt: Date, zoneID: CKRecordZone.ID) -> [CKRecord] {
        labelIDs.map { labelID in
            let record = CKRecord(
                recordType: RecordType.noteLabel,
                recordID: noteLabelRecordID(noteID: noteID, labelID: labelID, zoneID: zoneID)
            )
            record["noteID"] = noteID.rawValue as CKRecordValue
            record["labelID"] = labelID.rawValue as CKRecordValue
            record["version"] = NSNumber(value: payloadVersion)
            record["updatedAt"] = updatedAt as NSDate
            return record
        }
    }

    func notePayload(from record: CKRecord) -> RemoteNotePayload? {
        guard
            let localID = record["localID"] as? String,
            let title = record["title"] as? String,
            let bodyMarkdown = record["bodyMarkdown"] as? String,
            let bodyPlainText = record["bodyPlainText"] as? String,
            let previewText = record["previewText"] as? String,
            let primaryTypeRaw = record["primaryType"] as? String,
            let primaryType = NotePrimaryType(rawValue: primaryTypeRaw),
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let sortDate = record["sortDate"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        let note = Note(
            id: NoteID(rawValue: localID),
            title: title,
            bodyMarkdown: bodyMarkdown,
            bodyPlainText: bodyPlainText,
            previewText: previewText,
            primaryType: primaryType,
            snippetLanguageHint: record["snippetLanguageHint"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortDate: sortDate,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            isFavorite: (record["isFavorite"] as? NSNumber)?.boolValue ?? false,
            isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false,
            isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
            deletedAt: record["deletedAt"] as? Date,
            version: versionNumber.intValue
        )
        return RemoteNotePayload(note: note)
    }

    func labelPayload(from record: CKRecord) -> RemoteLabelPayload? {
        guard
            let localID = record["localID"] as? String,
            let name = record["name"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        return RemoteLabelPayload(
            label: Label(
                id: LabelID(rawValue: localID),
                name: name,
                color: record["color"] as? String,
                iconName: record["iconName"] as? String,
                isSystem: (record["isSystem"] as? NSNumber)?.boolValue ?? false,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
                deletedAt: record["deletedAt"] as? Date,
                version: versionNumber.intValue
            )
        )
    }

    func attachmentPayload(from record: CKRecord) -> RemoteAttachmentPayload? {
        guard
            let localID = record["localID"] as? String,
            let noteID = record["noteID"] as? String,
            let fileName = record["fileName"] as? String,
            let originalFileName = record["originalFileName"] as? String,
            let categoryRaw = record["category"] as? String,
            let category = AttachmentCategory(rawValue: categoryRaw),
            let relativePath = record["relativePath"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        return RemoteAttachmentPayload(
            attachment: Attachment(
                id: AttachmentID(rawValue: localID),
                noteID: NoteID(rawValue: noteID),
                fileName: fileName,
                originalFileName: originalFileName,
                mimeType: record["mimeType"] as? String,
                category: category,
                description: record["description"] as? String,
                relativePath: relativePath,
                fileSize: (record["fileSize"] as? NSNumber)?.int64Value,
                checksum: record["checksum"] as? String,
                width: (record["width"] as? NSNumber)?.intValue,
                height: (record["height"] as? NSNumber)?.intValue,
                duration: (record["duration"] as? NSNumber)?.doubleValue,
                pageCount: (record["pageCount"] as? NSNumber)?.intValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false,
                isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
                deletedAt: record["deletedAt"] as? Date,
                version: versionNumber.intValue
            ),
            asset: record[Field.attachmentAsset] as? CKAsset
        )
    }

    func snippetPayload(from record: CKRecord) -> RemoteSnippetPayload? {
        guard
            let localID = record["localID"] as? String,
            let noteID = record["noteID"] as? String,
            let language = record["language"] as? String,
            let code = record["code"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        return RemoteSnippetPayload(
            snippet: NoteSnippet(
                id: localID,
                noteID: NoteID(rawValue: noteID),
                language: language,
                title: record["title"] as? String,
                snippetDescription: record["description"] as? String,
                code: code,
                startOffset: (record["startOffset"] as? NSNumber)?.intValue,
                endOffset: (record["endOffset"] as? NSNumber)?.intValue,
                sourceType: NoteSnippetSourceType(rawValue: (record["sourceType"] as? String) ?? NoteSnippetSourceType.automatic.rawValue) ?? .automatic,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false,
                isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
                deletedAt: record["deletedAt"] as? Date,
                version: versionNumber.intValue
            )
        )
    }

    func toDoPayload(from record: CKRecord) -> RemoteToDoPayload? {
        guard
            let localID = record["localID"] as? String,
            let noteID = record["noteID"] as? String,
            let title = record["title"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        return RemoteToDoPayload(
            toDo: ToDo(
                id: ToDoID(rawValue: localID),
                noteID: NoteID(rawValue: noteID),
                title: title,
                details: (record["details"] as? String) ?? "",
                isCompleted: (record["isCompleted"] as? NSNumber)?.boolValue ?? false,
                isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false,
                dueDate: record["dueDate"] as? Date,
                hasTimeComponent: (record["hasTimeComponent"] as? NSNumber)?.boolValue ?? false,
                snoozedUntil: record["snoozedUntil"] as? Date,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: record["completedAt"] as? Date,
                sortOrder: (record["sortOrder"] as? NSNumber)?.intValue ?? 0,
                priority: record["priority"] as? String,
                version: versionNumber.intValue,
                isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
                deletedAt: record["deletedAt"] as? Date
            )
        )
    }

    func noteLabelPayload(from record: CKRecord) -> RemoteNoteLabelPayload? {
        guard
            let noteID = record["noteID"] as? String,
            let labelID = record["labelID"] as? String,
            let updatedAt = record["updatedAt"] as? Date,
            let versionNumber = record["version"] as? NSNumber
        else {
            return nil
        }

        return RemoteNoteLabelPayload(
            noteID: NoteID(rawValue: noteID),
            labelID: LabelID(rawValue: labelID),
            updatedAt: updatedAt,
            version: versionNumber.intValue
        )
    }

    func recordID(for entityType: SyncQueueItem.EntityType, entityID: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        let prefix: String
        switch entityType {
        case .note:
            prefix = "note"
        case .label:
            prefix = "label"
        case .toDo:
            prefix = "todo"
        case .attachment:
            prefix = "attachment"
        case .snippet:
            prefix = "snippet"
        case .noteLabel:
            prefix = "noteLabel"
        }
        return CKRecord.ID(recordName: "\(prefix).\(entityID)", zoneID: zoneID)
    }

    func noteLabelRecordID(noteID: NoteID, labelID: LabelID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "noteLabel.\(noteID.rawValue).\(labelID.rawValue)", zoneID: zoneID)
    }
}
