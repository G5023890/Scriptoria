import SwiftUI

struct AttachmentEditSheet: View {
    @Binding var draft: AttachmentEditDraft
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Edit Attachment")
                .font(AppTypography.hero)

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.originalFileName)
                    .font(AppTypography.section)
                Text(draft.metadataSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Description", text: $draft.description)
                .textFieldStyle(.roundedBorder)

            Text("Description is included in search and shown in attachment rows.")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(isSaving)
            }
        }
        .padding(AppSpacing.large)
        #if os(macOS)
        .frame(width: 620)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}
