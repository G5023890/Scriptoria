import SwiftUI

enum AppColors {
    #if os(macOS)
    static let chipBackground = Color(nsColor: .selectedControlColor).opacity(0.12)
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    #else
    static let chipBackground = Color(uiColor: .secondarySystemFill)
    static let panelBackground = Color(uiColor: .systemBackground)
    #endif
    static let panelBorder = Color.primary.opacity(0.08)
}
