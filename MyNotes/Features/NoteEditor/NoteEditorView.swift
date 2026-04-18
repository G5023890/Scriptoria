import Observation
import SwiftUI

struct NoteEditorPane: View {
    @Bindable var viewModel: NoteEditorViewModel
    let mode: NoteDetailMode
    let focusedToDoID: ToDoID?

    var body: some View {
        Group {
            switch mode {
            case .read:
                EmptyView()
            case .edit:
                editor
            }
        }
    }

    private var editor: some View {
        ScrollViewReader { proxy in
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

                    if viewModel.draft != nil {
                        NoteMetadataSectionsView(
                            toDoItems: viewModel.toDoItems,
                            deletedToDoItems: viewModel.deletedToDoItems,
                            attachmentItems: viewModel.attachmentItems,
                            snippetItems: viewModel.snippetItems,
                            allowsTaskMutation: true,
                            allowsTaskCompletionToggle: true,
                            allowsAttachmentRemoval: true,
                            focusedToDoID: focusedToDoID,
                            onToggleToDoCompletion: viewModel.toggleToDoCompletion,
                            onEditToDo: viewModel.presentEditToDoSheet,
                            onDeleteToDo: viewModel.deleteToDo,
                            onRemoveToDo: viewModel.removeToDo,
                            onRestoreToDo: viewModel.restoreToDo,
                            onMoveToDo: viewModel.moveToDo,
                            onFocusRequest: { toDoID in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(toDoID, anchor: .center)
                                }
                            },
                            onArchiveRevealRequest: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(noteArchiveBottomAnchorID, anchor: .bottom)
                                }
                            },
                            syntaxHighlightService: viewModel.syntaxHighlightService,
                            onPreviewAttachment: viewModel.previewAttachment,
                            onOpenAttachment: viewModel.openAttachment,
                            onEditAttachment: viewModel.presentEditAttachmentSheet,
                            onArchiveAttachment: { attachment in
                                Task {
                                    await viewModel.archiveAttachment(attachment)
                                }
                            },
                            onRemoveAttachment: { attachment in
                                Task {
                                    await viewModel.removeAttachment(attachment)
                                }
                            },
                            onCopySnippet: viewModel.copySnippet,
                            onPreviewSnippet: nil,
                            onArchiveSnippet: { snippet in
                                Task {
                                    await viewModel.archiveSnippet(snippet)
                                }
                            },
                            onEditSnippet: viewModel.presentEditSnippetSheet,
                            onRemoveSnippet: { snippet in
                                Task {
                                    await viewModel.removeSnippet(snippet)
                                }
                            }
                        )
                    }

                    HStack {
                        Text("Autosave persists note content. Tasks, attachments and snippets are managed as separate note containers.")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .sheet(
            item: Binding(
                get: { viewModel.activeToDoDraft },
                set: { _ in
                    viewModel.dismissToDoSheet()
                }
            )
        ) { draft in
            ToDoEditorSheet(
                draft: draft,
                onCancel: {
                    viewModel.dismissToDoSheet()
                },
                onSave: { draft in
                    Task {
                        if draft.toDoID == nil {
                            await viewModel.createToDo(draft: draft)
                        } else {
                            await viewModel.updateToDo(draft: draft)
                        }
                        viewModel.dismissToDoSheet()
                    }
                }
            )
        }
    }

}
