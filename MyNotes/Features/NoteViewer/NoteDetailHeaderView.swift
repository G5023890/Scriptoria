import SwiftUI

struct NoteDetailHeaderView: View {
    let snapshot: NoteSnapshot
    @Binding var mode: NoteDetailMode
    let titleBinding: Binding<String>?
    let availableLabels: [Label]
    let selectedLabels: [Label]
    let newLabelName: Binding<String>?
    let saveStatusText: String?
    let isSaving: Bool
    let isCreatingLabel: Bool
    let onToggleLabel: (Label) -> Void
    let onCreateLabel: () -> Void
    let onAddTask: () -> Void
    let onAddSnippet: () -> Void
    let onAddAttachment: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isShowingLabelsPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if let titleBinding, mode != .read {
                TextField("Title", text: titleBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.hero)
            } else {
                Text(snapshot.note.displayTitle)
                    .font(AppTypography.hero)
            }

            HStack(alignment: .center, spacing: AppSpacing.medium) {
                metadataRow
                Spacer(minLength: AppSpacing.small)
                modePicker
            }

            controlBar
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            if snapshot.labels.isEmpty {
                Text("Unlabeled")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.small) {
                        ForEach(snapshot.labels) { label in
                            LabelChipView(label: label)
                        }
                    }
                }
                .frame(maxWidth: 360, alignment: .leading)
            }

            if let saveStatusText, mode != .read {
                saveStatusView(text: saveStatusText)
            }
        }
    }

    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                labelsButton

                labeledToolbarButton(title: "Add Task", systemImage: AppIcons.tasks, action: onAddTask)
                    .disabled(snapshot.note.isDeleted)

                labeledToolbarButton(title: "Add Snippet", systemImage: AppIcons.code, action: onAddSnippet)
                    .disabled(snapshot.note.isDeleted)

                labeledToolbarButton(title: "Add Attachment", systemImage: AppIcons.attachment, action: onAddAttachment)
                    .disabled(snapshot.note.isDeleted)

                if snapshot.note.isDeleted {
                    compactToolbarButton(systemImage: "arrow.uturn.backward.circle", action: onRestore)
                } else {
                    compactToolbarButton(systemImage: "trash", action: onDelete)
                }

                compactToolbarButton(
                    systemImage: snapshot.note.isPinned ? "pin.fill" : "pin",
                    action: onTogglePin
                )
                .disabled(snapshot.note.isDeleted)

                compactToolbarButton(
                    systemImage: snapshot.note.isFavorite ? "star.fill" : "star",
                    action: onToggleFavorite
                )
                .disabled(snapshot.note.isDeleted)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.chipBackground)
            )
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(NoteDetailMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
        .controlSize(.small)
        .disabled(snapshot.note.isDeleted)
    }

    @ViewBuilder
    private var labelsButton: some View {
        compactToolbarButton(systemImage: "tag") {
            isShowingLabelsPopover.toggle()
        }
        .disabled(snapshot.note.isDeleted)
        .popover(isPresented: $isShowingLabelsPopover, arrowEdge: .bottom) {
            labelsPopover
        }
    }

    private func compactToolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func labeledToolbarButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(AppTypography.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func saveStatusView(text: String) -> some View {
        HStack(spacing: 6) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var labelsPopover: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Labels")
                .font(AppTypography.section)

            if let newLabelName {
                HStack(spacing: AppSpacing.small) {
                    TextField("New label", text: newLabelName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add", action: onCreateLabel)
                        .disabled(
                            isCreatingLabel ||
                            newLabelName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }

            if availableLabels.isEmpty {
                Text("No labels yet")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        ForEach(availableLabels) { label in
                            let isSelected = selectedLabels.contains(where: { $0.id == label.id })

                            Button {
                                onToggleLabel(label)
                            } label: {
                                HStack(spacing: AppSpacing.small) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                    Text(label.name)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 280)
    }
}
