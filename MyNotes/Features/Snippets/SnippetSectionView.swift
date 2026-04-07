import SwiftUI

struct SnippetSectionView: View {
    let title: String
    let snippets: [SnippetItem]
    let emptyText: String?
    let syntaxHighlightService: any SyntaxHighlightService
    let showsInlineCode: Bool
    let onCopy: (NoteSnippet) -> Void
    let onPreviewSnippet: ((NoteSnippet) -> Void)?
    let onArchive: ((NoteSnippet) -> Void)?
    let onEdit: ((NoteSnippet) -> Void)?
    let onRemove: ((NoteSnippet) -> Void)?

    @State private var activePreviewItem: SnippetItem?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if snippets.isEmpty, let emptyText {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: AppIcons.code)
                        .foregroundStyle(.secondary)
                    Text(emptyText)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    ForEach(snippets) { item in
                        let allowsMutation = item.snippet.sourceType == .manual

                        SnippetRowView(
                            item: item,
                            showsInlineCode: showsInlineCode,
                            onPreview: {
                                if let onPreviewSnippet {
                                    onPreviewSnippet(item.snippet)
                                } else {
                                    activePreviewItem = item
                                }
                            },
                            onCopy: { onCopy(item.snippet) },
                            onArchive: onArchive.map { action in
                                { action(item.snippet) }
                            },
                            onEdit: allowsMutation ? onEdit.map { action in
                                { action(item.snippet) }
                            } : nil,
                            onRemove: allowsMutation ? onRemove.map { action in
                                { action(item.snippet) }
                            } : nil
                        )
                    }
                }
            }
        }
        .sheet(item: $activePreviewItem) { item in
            SnippetInlinePreviewSheet(
                item: item,
                syntaxHighlightService: syntaxHighlightService,
                onCopy: {
                    onCopy(item.snippet)
                }
            )
        }
    }
}

struct SnippetRowView: View {
    let item: SnippetItem
    let showsInlineCode: Bool
    let onPreview: () -> Void
    let onCopy: () -> Void
    let onArchive: (() -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                categoryChip(systemImage: "chevron.left.forwardslash.chevron.right")

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xSmall) {
                        Text(item.title)
                            .font(AppTypography.chip.weight(.semibold))
                            .lineLimit(1)
                        if item.isArchived {
                            InfoBadge(text: "Архив")
                        }
                    }
                    Text(item.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.small)

                HStack(spacing: AppSpacing.small) {
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.borderless)
                    }

                    Button("Copy", action: onCopy)
                        .buttonStyle(.borderless)

                    if let onArchive {
                        Button(action: onArchive) {
                            Image(systemName: AppIcons.archive)
                        }
                        .buttonStyle(.borderless)
                        .help(item.isArchived ? "Archived" : "Archive")
                        .disabled(item.isArchived)
                    }

                    if let onRemove {
                        Button(role: .destructive, action: onRemove) {
                            Image(systemName: AppIcons.delete)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove")
                    }
                }
                .font(AppTypography.caption)
                .fixedSize()
            }

            if showsInlineCode {
                Text(item.code)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.sRGB, red: 0.95, green: 0.96, blue: 0.98, opacity: 1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPreview)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(item.isArchived ? 0.86 : 1)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.chipBackground)
        )
    }

    private func categoryChip(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.08))
            )
    }
}

struct SnippetInlinePreviewSheet: View {
    let item: SnippetItem
    let syntaxHighlightService: any SyntaxHighlightService
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previewLanguage: String

    init(
        item: SnippetItem,
        syntaxHighlightService: any SyntaxHighlightService,
        onCopy: @escaping () -> Void
    ) {
        self.item = item
        self.syntaxHighlightService = syntaxHighlightService
        self.onCopy = onCopy
        _previewLanguage = State(initialValue: item.selectedLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AppTypography.section)
                    Text(item.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu(previewLanguageTitle) {
                    ForEach(SnippetSyntaxLanguage.supportedOptions) { option in
                        Button(option.title) {
                            previewLanguage = option.id
                        }
                    }
                }
                Button("Copy", action: onCopy)
                Button("Done") {
                    dismiss()
                }
            }

            ScrollView {
                SyntaxHighlightedCodeView(
                    code: item.code,
                    language: previewLanguage,
                    syntaxHighlightService: syntaxHighlightService,
                    lineLimit: nil
                )
                    .padding(AppSpacing.medium)
            }
            .modifier(PanelSurfaceModifier())
        }
        .padding(AppSpacing.large)
        .frame(minWidth: 680, minHeight: 520)
    }

    private var previewLanguageTitle: String {
        "Syntax: \(SnippetSyntaxLanguage.displayName(for: previewLanguage))"
    }
}
