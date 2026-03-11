import Observation
import SwiftUI

struct SearchResultsView: View {
    @Bindable var viewModel: SearchViewModel
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            List(viewModel.results, selection: $coordinator.selectedNoteID) { result in
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: iconName(for: result.kind))
                            .foregroundStyle(.secondary)
                        Text(result.title)
                            .font(AppTypography.bodySemibold)
                    }
                    Text(result.excerpt)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    HStack {
                        Text(result.matchedField)
                        Spacer()
                        Text(result.kind.rawValue.capitalized)
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(result.noteID)
            }
        }
        .overlay {
            if viewModel.results.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No notes matched \"\(viewModel.queryText)\".")
                )
            }
        }
    }

    private func iconName(for kind: SearchResult.Kind) -> String {
        switch kind {
        case .note:
            "doc.text"
        case .snippet:
            AppIcons.code
        case .attachment:
            AppIcons.attachment
        case .label:
            "tag"
        }
    }
}
