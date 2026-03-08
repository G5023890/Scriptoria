import SwiftUI

struct NoteReadView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            if markdown.isEmpty {
                ContentUnavailableView(
                    "No Content",
                    systemImage: "doc.text",
                    description: Text("Switch to Edit mode to start writing.")
                )
                .frame(maxWidth: .infinity)
            } else {
                Text(.init(markdown))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
