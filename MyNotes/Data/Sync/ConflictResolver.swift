import Foundation

struct ResolvedNoteConflict: Sendable {
    let note: Note
    let labelIDs: [LabelID]
    let attachments: [Attachment]
}

struct ConflictResolver {
    private let syncPolicy: SyncPolicy

    init(syncPolicy: SyncPolicy = SyncPolicy()) {
        self.syncPolicy = syncPolicy
    }

    func resolveNote(
        local: Note,
        remote: Note,
        localLabels: [LabelID],
        remoteLabels: [LabelID],
        localAttachments: [Attachment],
        remoteAttachments: [Attachment]
    ) -> ResolvedNoteConflict {
        let title = lastWriteWins(local.title, localDate: local.updatedAt, remote.title, remoteDate: remote.updatedAt)
        let bodyMarkdown = lastWriteWins(
            local.bodyMarkdown,
            localDate: local.updatedAt,
            remote.bodyMarkdown,
            remoteDate: remote.updatedAt
        )
        let bodyPlainText = lastWriteWins(
            local.bodyPlainText,
            localDate: local.updatedAt,
            remote.bodyPlainText,
            remoteDate: remote.updatedAt
        )
        let previewText = lastWriteWins(
            local.previewText,
            localDate: local.updatedAt,
            remote.previewText,
            remoteDate: remote.updatedAt
        )
        let primaryType = lastWriteWins(
            local.primaryType,
            localDate: local.updatedAt,
            remote.primaryType,
            remoteDate: remote.updatedAt
        )
        let snippetLanguageHint = lastWriteWins(
            local.snippetLanguageHint,
            localDate: local.updatedAt,
            remote.snippetLanguageHint,
            remoteDate: remote.updatedAt
        )
        let isPinned = lastWriteWins(
            local.isPinned,
            localDate: local.updatedAt,
            remote.isPinned,
            remoteDate: remote.updatedAt
        )
        let isFavorite = lastWriteWins(
            local.isFavorite,
            localDate: local.updatedAt,
            remote.isFavorite,
            remoteDate: remote.updatedAt
        )
        let isArchived = lastWriteWins(
            local.isArchived,
            localDate: local.updatedAt,
            remote.isArchived,
            remoteDate: remote.updatedAt
        )

        let deletion = resolveDeletion(
            localIsDeleted: local.isDeleted,
            localDeletedAt: local.deletedAt,
            localUpdatedAt: local.updatedAt,
            localVersion: local.version,
            remoteIsDeleted: remote.isDeleted,
            remoteDeletedAt: remote.deletedAt,
            remoteUpdatedAt: remote.updatedAt,
            remoteVersion: remote.version
        )
        let updatedAt = max(local.updatedAt, remote.updatedAt)

        let note = Note(
            id: local.id,
            title: title,
            bodyMarkdown: bodyMarkdown,
            bodyPlainText: bodyPlainText,
            previewText: previewText,
            primaryType: primaryType,
            snippetLanguageHint: snippetLanguageHint,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: updatedAt,
            sortDate: deletion.deletedAt ?? updatedAt,
            isPinned: isPinned,
            isFavorite: isFavorite,
            isArchived: isArchived,
            isDeleted: deletion.isDeleted,
            deletedAt: deletion.deletedAt,
            version: max(local.version, remote.version) + 1
        )

        return ResolvedNoteConflict(
            note: note,
            labelIDs: syncPolicy.mergedLabelIDs(local: localLabels, remote: remoteLabels),
            attachments: mergeAttachments(local: localAttachments, remote: remoteAttachments)
        )
    }

    func resolveLabel(local: Label, remote: Label) -> Label {
        let winner = preferred(local: local, remote: remote)
        let deletion = resolveDeletion(
            localIsDeleted: local.isDeleted,
            localDeletedAt: local.deletedAt,
            localUpdatedAt: local.updatedAt,
            localVersion: local.version,
            remoteIsDeleted: remote.isDeleted,
            remoteDeletedAt: remote.deletedAt,
            remoteUpdatedAt: remote.updatedAt,
            remoteVersion: remote.version
        )

        return Label(
            id: winner.id,
            name: winner.name,
            color: winner.color,
            iconName: winner.iconName,
            isSystem: winner.isSystem,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            isDeleted: deletion.isDeleted,
            deletedAt: deletion.deletedAt,
            version: max(local.version, remote.version) + 1
        )
    }

    func resolveToDo(local: ToDo, remote: ToDo) -> ToDo {
        let winner = preferred(local: local, remote: remote)
        let deletion = resolveDeletion(
            localIsDeleted: local.isDeleted,
            localDeletedAt: local.deletedAt,
            localUpdatedAt: local.updatedAt,
            localVersion: local.version,
            remoteIsDeleted: remote.isDeleted,
            remoteDeletedAt: remote.deletedAt,
            remoteUpdatedAt: remote.updatedAt,
            remoteVersion: remote.version
        )

        return ToDo(
            id: winner.id,
            noteID: winner.noteID,
            title: winner.title,
            details: winner.details,
            isCompleted: winner.isCompleted,
            isArchived: winner.isArchived,
            dueDate: winner.dueDate,
            hasTimeComponent: winner.hasTimeComponent,
            snoozedUntil: winner.snoozedUntil,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            completedAt: winner.completedAt,
            sortOrder: winner.sortOrder,
            priority: winner.priority,
            version: max(local.version, remote.version) + 1,
            isDeleted: deletion.isDeleted,
            deletedAt: deletion.deletedAt
        )
    }

    func resolveAttachment(local: Attachment, remote: Attachment) -> Attachment {
        let winner = preferred(local: local, remote: remote)
        let deletion = resolveDeletion(
            localIsDeleted: local.isDeleted,
            localDeletedAt: local.deletedAt,
            localUpdatedAt: local.updatedAt,
            localVersion: local.version,
            remoteIsDeleted: remote.isDeleted,
            remoteDeletedAt: remote.deletedAt,
            remoteUpdatedAt: remote.updatedAt,
            remoteVersion: remote.version
        )

        return Attachment(
            id: winner.id,
            noteID: winner.noteID,
            fileName: winner.fileName,
            originalFileName: winner.originalFileName,
            mimeType: winner.mimeType,
            category: winner.category,
            description: winner.description,
            relativePath: winner.relativePath,
            fileSize: winner.fileSize,
            checksum: winner.checksum,
            width: winner.width,
            height: winner.height,
            duration: winner.duration,
            pageCount: winner.pageCount,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            isArchived: winner.isArchived,
            isDeleted: deletion.isDeleted,
            deletedAt: deletion.deletedAt,
            version: max(local.version, remote.version) + 1
        )
    }

    func resolveSnippet(local: NoteSnippet, remote: NoteSnippet) -> NoteSnippet {
        let winner = preferred(local: local, remote: remote)
        let deletion = resolveDeletion(
            localIsDeleted: local.isDeleted,
            localDeletedAt: local.deletedAt,
            localUpdatedAt: local.updatedAt,
            localVersion: local.version,
            remoteIsDeleted: remote.isDeleted,
            remoteDeletedAt: remote.deletedAt,
            remoteUpdatedAt: remote.updatedAt,
            remoteVersion: remote.version
        )

        return NoteSnippet(
            id: winner.id,
            noteID: winner.noteID,
            language: winner.language,
            title: winner.title,
            snippetDescription: winner.snippetDescription,
            code: winner.code,
            startOffset: winner.startOffset,
            endOffset: winner.endOffset,
            sourceType: winner.sourceType,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            isArchived: winner.isArchived,
            isDeleted: deletion.isDeleted,
            deletedAt: deletion.deletedAt,
            version: max(local.version, remote.version) + 1
        )
    }

    private func mergeAttachments(local: [Attachment], remote: [Attachment]) -> [Attachment] {
        let grouped = Dictionary(grouping: local + remote, by: \.id)

        return grouped.values.compactMap { candidates in
            candidates.max { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.version < rhs.version
            }
        }
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    private func lastWriteWins<T>(_ local: T, localDate: Date, _ remote: T, remoteDate: Date) -> T {
        localDate >= remoteDate ? local : remote
    }

    private func preferred<T: VersionedSyncEntity>(local: T, remote: T) -> T {
        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? local : remote
        }
        if local.version != remote.version {
            return local.version > remote.version ? local : remote
        }
        return remote
    }

    private func resolveDeletion(
        localIsDeleted: Bool,
        localDeletedAt: Date?,
        localUpdatedAt: Date,
        localVersion: Int,
        remoteIsDeleted: Bool,
        remoteDeletedAt: Date?,
        remoteUpdatedAt: Date,
        remoteVersion: Int
    ) -> (isDeleted: Bool, deletedAt: Date?) {
        guard localIsDeleted != remoteIsDeleted else {
            if localIsDeleted {
                return (true, [localDeletedAt, remoteDeletedAt].compactMap { $0 }.max())
            }
            return (false, nil)
        }

        let localDeletionDate = localDeletedAt ?? localUpdatedAt
        let remoteDeletionDate = remoteDeletedAt ?? remoteUpdatedAt

        if localDeletionDate != remoteDeletionDate {
            if localDeletionDate > remoteDeletionDate {
                return (localIsDeleted, localIsDeleted ? localDeletedAt ?? localUpdatedAt : nil)
            }
            return (remoteIsDeleted, remoteIsDeleted ? remoteDeletedAt ?? remoteUpdatedAt : nil)
        }

        if localVersion != remoteVersion {
            if localVersion > remoteVersion {
                return (localIsDeleted, localIsDeleted ? localDeletedAt ?? localUpdatedAt : nil)
            }
            return (remoteIsDeleted, remoteIsDeleted ? remoteDeletedAt ?? remoteUpdatedAt : nil)
        }

        return (remoteIsDeleted, remoteIsDeleted ? remoteDeletedAt ?? remoteUpdatedAt : nil)
    }
}

private protocol VersionedSyncEntity {
    var updatedAt: Date { get }
    var version: Int { get }
}

extension Label: VersionedSyncEntity {}
extension ToDo: VersionedSyncEntity {}
extension Attachment: VersionedSyncEntity {}
extension NoteSnippet: VersionedSyncEntity {}
