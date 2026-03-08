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

        let deletion = resolveDeletion(local: local, remote: remote)
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

    private func resolveDeletion(local: Note, remote: Note) -> (isDeleted: Bool, deletedAt: Date?) {
        if local.isDeleted || remote.isDeleted {
            return (true, [local.deletedAt, remote.deletedAt].compactMap { $0 }.max())
        }
        return (false, nil)
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
}
