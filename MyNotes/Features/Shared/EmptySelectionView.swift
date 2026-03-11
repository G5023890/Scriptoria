import SwiftUI

struct EmptySelectionView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Text("Select a note")
                .font(AppTypography.hero)
            Text("Choose a note from the middle column or create a new one directly in this window.")
                .foregroundStyle(.secondary)
            HStack(spacing: AppSpacing.medium) {
                Button("New Note") {
                    coordinator.requestNewNote()
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
