import Observation
import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: QuickCaptureViewModel
    let onCaptured: @MainActor (Note) -> Void

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    TextField("Title", text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $viewModel.body)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 240)
                        .modifier(PanelSurfaceModifier())

                    if !viewModel.availableLabels.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text("Labels")
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.small)],
                                alignment: .leading,
                                spacing: AppSpacing.small
                            ) {
                                ForEach(viewModel.availableLabels) { label in
                                    Button {
                                        viewModel.toggleLabel(label.id)
                                    } label: {
                                        Text(label.name)
                                            .font(AppTypography.chip)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                viewModel.selectedLabelIDs.contains(label.id)
                                                    ? Color.accentColor.opacity(0.18)
                                                    : AppColors.chipBackground,
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Toggle("Pin immediately", isOn: $viewModel.isPinned)
                        Toggle("Mark as favorite", isOn: $viewModel.isFavorite)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: AppSpacing.small) {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    Task {
                        if let note = await viewModel.capture() {
                            onCaptured(note)
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isSaving)
            }
            .padding(.top, AppSpacing.small)
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
}
