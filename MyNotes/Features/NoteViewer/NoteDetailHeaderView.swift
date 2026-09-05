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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    titleAndMetadata
                    Spacer(minLength: AppSpacing.medium)
                    modePicker
                    controlBar
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    titleAndMetadata
                    HStack(alignment: .center, spacing: AppSpacing.medium) {
                        metadataRow
                        Spacer(minLength: AppSpacing.small)
                        modePicker
                    }
                    controlBar
                }
            }
        }
    }

    private var titleAndMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let titleBinding, mode != .read {
                TextField("Title", text: titleBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.hero)
            } else {
                Text(snapshot.note.displayTitle)
                    .font(AppTypography.hero)
                    .lineLimit(1)
            }

            if horizontalSizeClass == .regular {
                metadataRow
            }
        }
        .frame(minWidth: 140, maxWidth: 360, alignment: .leading)
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            if selectedLabels.isEmpty {
                Text("Unlabeled")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ViewThatFits(in: .horizontal) {
                    ForEach(Array((0...selectedLabels.count).reversed()), id: \.self) { visibleCount in
                        HStack(spacing: AppSpacing.small) {
                            ForEach(Array(selectedLabels.prefix(visibleCount))) { label in
                                LabelChipView(label: label)
                            }
                            if visibleCount < selectedLabels.count {
                                HiddenNoteLabelsButton(labels: Array(selectedLabels.dropFirst(visibleCount)))
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
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

                labeledToolbarButton(title: "Task", systemImage: AppIcons.tasks, action: onAddTask)
                    .disabled(snapshot.note.isDeleted)

                labeledToolbarButton(title: "Snippet", systemImage: AppIcons.code, action: onAddSnippet)
                    .disabled(snapshot.note.isDeleted)

                labeledToolbarButton(title: "Attachment", systemImage: AppIcons.attachment, action: onAddAttachment)
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
        .fixedSize(horizontal: horizontalSizeClass == .regular, vertical: false)
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
        #if os(macOS)
        .popover(isPresented: $isShowingLabelsPopover, arrowEdge: .bottom) {
            LabelsPickerContent(
                availableLabels: availableLabels,
                selectedLabels: selectedLabels,
                newLabelName: newLabelName,
                isCreatingLabel: isCreatingLabel,
                onToggleLabel: onToggleLabel,
                onCreateLabel: onCreateLabel,
                isFullWidthLayout: false
            )
        }
        #else
        .sheet(isPresented: $isShowingLabelsPopover) {
            NavigationStack {
                LabelsPickerContent(
                    availableLabels: availableLabels,
                    selectedLabels: selectedLabels,
                    newLabelName: newLabelName,
                    isCreatingLabel: isCreatingLabel,
                    onToggleLabel: onToggleLabel,
                    onCreateLabel: onCreateLabel,
                    isFullWidthLayout: true
                )
                .navigationTitle("Labels")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isShowingLabelsPopover = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        #endif
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

}

private struct HiddenNoteLabelsButton: View {
    let labels: [Label]
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            InfoBadge(text: "+\(labels.count)")
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show hidden tags: \(labels.count)")
        .popover(isPresented: $isPresented) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Tags").font(.headline)
                    ForEach(labels) { label in
                        HStack(alignment: .top) {
                            LabelIconView(label: label)
                            Text(label.name).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Button("Done") { isPresented = false }
                }
                .padding()
            }
            .frame(idealWidth: 300, idealHeight: 320)
        }
    }
}

private struct LabelsPickerContent: View {
    let availableLabels: [Label]
    let selectedLabels: [Label]
    let newLabelName: Binding<String>?
    let isCreatingLabel: Bool
    let onToggleLabel: (Label) -> Void
    let onCreateLabel: () -> Void
    let isFullWidthLayout: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !isFullWidthLayout {
                Text("Labels")
                    .font(AppTypography.section)
            }

            if let newLabelName {
                labelCreationRow(newLabelName: newLabelName)
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
                                    LabelIconView(label: label)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(label.name)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: isFullWidthLayout ? .infinity : 220, alignment: .topLeading)
            }
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(macOS)
        .frame(width: isFullWidthLayout ? nil : 280)
        #endif
    }

    @ViewBuilder
    private func labelCreationRow(newLabelName: Binding<String>) -> some View {
        if isFullWidthLayout {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                TextField("New label", text: newLabelName)
                    .textFieldStyle(.roundedBorder)

                Button("Add", action: onCreateLabel)
                    .disabled(addButtonDisabled(newLabelName))
            }
        } else {
            HStack(spacing: AppSpacing.small) {
                TextField("New label", text: newLabelName)
                    .textFieldStyle(.roundedBorder)

                Button("Add", action: onCreateLabel)
                    .disabled(addButtonDisabled(newLabelName))
            }
        }
    }

    private func addButtonDisabled(_ newLabelName: Binding<String>) -> Bool {
        isCreatingLabel ||
        newLabelName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
