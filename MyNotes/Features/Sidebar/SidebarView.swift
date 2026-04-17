import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    var showsTasks: Bool = true
    var title: String = "MyNotes"

    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage?.isEmpty == false },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }

    var body: some View {
        sidebarList
        #if os(macOS)
        .listStyle(.sidebar)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(title)
        .sheet(item: $viewModel.labelBeingEdited) { item in
            editLabelSheet(for: item)
        }
        .alert("Label Error", isPresented: errorAlertPresented) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var sidebarList: some View {
        #if os(iOS)
        List {
            browseSection
            Divider()
            labelsSection
        }
        #else
        List(selection: $viewModel.selection) {
            browseSection
            Divider()
            labelsSection
        }
        #endif
    }

    private var browseSection: some View {
        Section("Browse") {
            ForEach(SmartCollection.allCases.filter { showsTasks || $0 != .tasks }) { collection in
                collectionRow(for: collection)
            }
        }
    }

    private var labelsSection: some View {
        Section("Labels") {
            ForEach(viewModel.labels) { item in
                labelRow(for: item)
            }
        }
    }

    @ViewBuilder
    private func collectionRow(for collection: SmartCollection) -> some View {
        sidebarRow(selection: .collection(collection)) {
            HStack(spacing: AppSpacing.small) {
                SwiftUI.Label(collection.title, systemImage: collection.systemImage)
                Spacer()
                InfoBadge(text: "\(viewModel.noteCount(for: collection))")
            }
        } onTap: {
            viewModel.selection = .collection(collection)
        } contextMenu: {
            collectionContextMenu(for: collection)
        }
    }

    @ViewBuilder
    private func collectionContextMenu(for collection: SmartCollection) -> some View {
        if collection == .trash {
            Button("Empty Trash") {
                viewModel.requestEmptyTrash()
            }
        }
    }

    @ViewBuilder
    private func labelRow(for item: SidebarLabelSummary) -> some View {
        sidebarRow(selection: .label(item.label.id)) {
            HStack(spacing: AppSpacing.small) {
                LabelIconView(label: item.label)
                    .font(.system(size: 13, weight: .semibold))
                Text(item.label.name)
                Spacer()
                InfoBadge(text: "\(item.noteCount)")
            }
        } onTap: {
            viewModel.selection = .label(item.label.id)
        } contextMenu: {
            Button("Edit") {
                viewModel.beginEditing(for: item)
            }

            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteLabel(item)
                }
            }
            .disabled(item.label.isSystem)
        }
    }

    @ViewBuilder
    private func sidebarRow<Content: View>(
        selection: SidebarSelection,
        @ViewBuilder content: () -> Content,
        onTap: @escaping () -> Void,
        @ViewBuilder contextMenu: () -> some View
    ) -> some View {
        #if os(iOS)
        Button(action: onTap) {
            content()
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenu()
        }
        #else
        content()
            .tag(selection)
            .contextMenu {
                contextMenu()
            }
        #endif
    }

    @ViewBuilder
    private func editLabelSheet(for item: SidebarLabelSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Edit Label")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("Name")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)

                        TextField("Label Name", text: $viewModel.draftLabelName)
                            .textFieldStyle(.roundedBorder)
                            .disabled(item.label.isSystem)
                    }

                    previewSection
                    iconPickerSection
                    colorPickerSection
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                Button("Save") {
                    Task {
                        await viewModel.saveEditedLabel()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.large)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 620)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Preview")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: AppSpacing.small) {
                LabelIconView(iconName: viewModel.draftLabelIconName, colorHex: viewModel.draftLabelColorHex)
                    .font(.system(size: 16, weight: .semibold))

                Text(viewModel.draftLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Label" : viewModel.draftLabelName)
                    .font(AppTypography.bodySemibold)

                if viewModel.draftHasLegacyIcon {
                    Text("Legacy icon")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.draftHasCustomColor {
                    Text("Custom color")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(AppSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.chipBackground)
            )
        }
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Icon")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.small), count: 5),
                alignment: .leading,
                spacing: AppSpacing.small
            ) {
                ForEach(LabelAppearanceCatalog.allowedIconNames, id: \.self) { iconName in
                    Button {
                        viewModel.selectDraftIcon(iconName)
                    } label: {
                        LabelIconView(iconName: iconName, colorHex: viewModel.draftLabelColorHex)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(iconButtonBackground(for: iconName))
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(iconName == viewModel.draftLabelIconName ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Icon Color")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.small), count: 3),
                alignment: .leading,
                spacing: AppSpacing.small
            ) {
                ForEach(LabelAppearanceCatalog.colorOptions) { option in
                    Button {
                        viewModel.selectDraftColor(option.hex)
                    } label: {
                        HStack(spacing: AppSpacing.small) {
                            colorSwatch(for: option)
                            Text(option.name)
                                .font(AppTypography.caption)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(colorButtonBackground(for: option))
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LabelAppearanceCatalog.normalizedHex(option.hex) == viewModel.draftLabelColorHex
                                    ? Color.accentColor
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
            }
        }
    }

    private func iconButtonBackground(for iconName: String) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(iconName == viewModel.draftLabelIconName ? Color.accentColor.opacity(0.14) : AppColors.chipBackground)
    }

    private func colorButtonBackground(for option: LabelColorOption) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LabelAppearanceCatalog.normalizedHex(option.hex) == viewModel.draftLabelColorHex
                    ? Color.accentColor.opacity(0.14)
                    : AppColors.chipBackground
            )
    }

    @ViewBuilder
    private func colorSwatch(for option: LabelColorOption) -> some View {
        if let hex = option.hex, let color = Color(labelHex: hex) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                .frame(width: 12, height: 12)
                .background(Circle().fill(Color.clear))
        }
    }
}
