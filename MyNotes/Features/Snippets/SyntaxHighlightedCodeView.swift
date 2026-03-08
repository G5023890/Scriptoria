import SwiftUI

struct SyntaxHighlightedCodeView: View {
    let code: String
    let language: String
    let syntaxHighlightService: any SyntaxHighlightService
    var lineLimit: Int?

    var body: some View {
        Text(syntaxHighlightService.highlight(code: code, language: language))
            .textSelection(.enabled)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }

    private var backgroundColor: Color {
        guard let components = syntaxHighlightService.highlightBackgroundColor() else {
            return Color(.sRGB, red: 0.95, green: 0.96, blue: 0.98, opacity: 1)
        }

        return Color(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}
