import SwiftUI

struct SnippetsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Snippets", systemImage: "curlybraces.square")
    }
}
