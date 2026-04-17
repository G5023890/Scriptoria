import Observation
import SwiftUI

struct SearchResultsView: View {
    @Bindable var viewModel: SearchViewModel
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            #if os(iOS)
            List(viewModel.results) { result in
                NavigationLink(value: result.noteID) {
                    resultRow(result)
                }
            }
            #else
            List(viewModel.results, selection: $coordinator.selectedNoteID) { result in
                resultRow(result)
                .tag(result.noteID)
            }
            #endif
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

    private func resultRow(_ result: SearchResult) -> some View {
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
