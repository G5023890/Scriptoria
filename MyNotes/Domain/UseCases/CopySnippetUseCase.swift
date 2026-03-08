import Foundation

struct CopySnippetUseCase {
    let clipboardService: any ClipboardService

    func execute(snippet: NoteSnippet) {
        clipboardService.copy(snippet.code)
    }
}
