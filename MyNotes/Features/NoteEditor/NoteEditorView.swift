import Observation
import SwiftUI

struct NoteEditorPane: View {
    @Bindable var viewModel: NoteEditorViewModel
    let mode: NoteDetailMode

    var body: some View {
        Group {
            switch mode {
            case .read:
                EmptyView()
            case .edit:
                editor
            case .split:
                HSplitView {
                    editor
                    preview
                }
            }
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                TextEditor(
                    text: Binding(
                        get: { viewModel.draft?.bodyMarkdown ?? "" },
                        set: viewModel.updateBody
                    )
                )
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 320)
                .modifier(PanelSurfaceModifier())

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    if !viewModel.attachmentItems.isEmpty {
                        AttachmentSectionView(
                            title: "",
                            attachments: viewModel.attachmentItems,
                            emptyText: "Attachments will appear here after import.",
                            allowsRemoval: true,
                            syntaxHighlightService: viewModel.syntaxHighlightService,
                            onPreview: viewModel.previewAttachment,
                            onOpen: viewModel.openAttachment,
                            onRemove: { attachment in
                                Task {
                                    await viewModel.removeAttachment(attachment)
                                }
                            },
                            headerAction: nil
                        )
                    }

                    if !viewModel.snippetItems.isEmpty {
                        SnippetSectionView(
                            title: "",
                            snippets: viewModel.snippetItems,
                            emptyText: "Snippets are stored separately from the main note body.",
                            syntaxHighlightService: viewModel.syntaxHighlightService,
                            onCopy: viewModel.copySnippet,
                            onEdit: viewModel.presentEditSnippetSheet,
                            onRemove: { snippet in
                                Task {
                                    await viewModel.removeSnippet(snippet)
                                }
                            }
                        )
                    }
                }

                HStack {
                    Text("Autosave persists note content. Attachments and snippets are managed as separate note containers.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var preview: some View {
        ScrollView {
            if let markdown = viewModel.draft?.bodyMarkdown, !markdown.isEmpty {
                Text(.init(markdown))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(AppSpacing.medium)
            } else {
                ContentUnavailableView(
                    "Preview Is Empty",
                    systemImage: "doc.plaintext",
                    description: Text("Markdown preview updates as you edit the draft.")
                )
                .padding(AppSpacing.medium)
            }
        }
        .modifier(PanelSurfaceModifier())
    }

}
