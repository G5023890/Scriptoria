import SwiftUI

struct EmptySelectionView: View {
    @Environment(\.openWindow) private var openWindow

    let coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Text("Select a note")
                .font(AppTypography.hero)
            Text("Choose a note from the middle column or use Quick Capture to create one immediately.")
                .foregroundStyle(.secondary)
            HStack(spacing: AppSpacing.medium) {
                Button("Quick Create") {
                    coordinator.openQuickCaptureWindow(using: openWindow)
                }
                .buttonStyle(.borderedProminent)

                Text("Tip: search supports filters like `label:swift`, `type:code`, `updated:today`.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(AppSpacing.xLarge)
    }
}
