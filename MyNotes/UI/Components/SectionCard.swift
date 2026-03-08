import SwiftUI

struct SectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            content
        }
        .padding(AppSpacing.medium)
        .modifier(PanelSurfaceModifier())
    }
}
