import SwiftUI

struct SnippetSectionView: View {
    let title: String
    let snippets: [SnippetItem]
    let emptyText: String?
    let syntaxHighlightService: any SyntaxHighlightService
    let showsInlineCode: Bool
    let onCopy: (NoteSnippet) -> Void
    let onPreviewSnippet: ((NoteSnippet) -> Void)?
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
                            onEdit: onEdit.map { action in
                                { action(item.snippet) }
                            },
                            onRemove: onRemove.map { action in
                                { action(item.snippet) }
                            }
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

private struct SnippetRowView: View {
    let item: SnippetItem
    let showsInlineCode: Bool
    let onPreview: () -> Void
    let onCopy: () -> Void
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                categoryChip(systemImage: "chevron.left.forwardslash.chevron.right")

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppTypography.chip.weight(.semibold))
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.small)

                HStack(spacing: AppSpacing.small) {
                    Button("Preview", action: onPreview)
                        .buttonStyle(.borderless)

                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.borderless)
                    }

                    Button("Copy", action: onCopy)
                        .buttonStyle(.borderless)

                    if let onRemove {
                        Button("Remove", role: .destructive, action: onRemove)
                            .buttonStyle(.borderless)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

private struct SnippetInlinePreviewSheet: View {
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
