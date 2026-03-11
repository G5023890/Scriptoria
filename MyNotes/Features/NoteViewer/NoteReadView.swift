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
                NoteRenderedContentView(markdown: markdown)
            }
        }
    }
}

struct NoteRenderedContentView: View {
    let markdown: String

    var body: some View {
        if prefersPlainCodeRendering {
            ScrollView(.horizontal) {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            Text(.init(markdown))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var prefersPlainCodeRendering: Bool {
        guard markdown.count >= 6_000 else { return false }

        let lowercase = markdown.lowercased()
        let htmlSignals = [
            "<!doctype html",
            "<html",
            "<head",
            "<body",
            "<div",
            "<span",
            "<script",
            "<style",
            "</"
        ]

        let htmlMatchCount = htmlSignals.reduce(into: 0) { count, signal in
            if lowercase.contains(signal) {
                count += 1
            }
        }

        return htmlMatchCount >= 3 || markdown.count >= 20_000
    }
}
