import SwiftUI

@MainActor
struct NoteEditorHostView: View {
    @State private var viewModel: NoteEditorViewModel
    let mode: NoteDetailMode

    init(
        noteID: NoteID,
        environment: AppEnvironment,
        mode: NoteDetailMode,
        onSave: @escaping @MainActor () async -> Void
    ) {
        _viewModel = State(initialValue: environment.makeNoteEditorViewModel(noteID: noteID, onSave: onSave))
        self.mode = mode
    }

    var body: some View {
        NoteEditorPane(viewModel: viewModel, mode: mode, focusedToDoID: nil)
    }
}
