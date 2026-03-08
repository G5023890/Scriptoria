import SwiftUI

struct PanelSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(AppColors.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
