import AppKit
import QuickLookUI
import SwiftUI

struct AttachmentSectionView: View {
    let title: String
    let attachments: [AttachmentItem]
    let emptyText: String
    let allowsRemoval: Bool
    let onPreview: (Attachment) -> Void
    let onOpen: (Attachment) -> Void
    let onEdit: ((Attachment) -> Void)?
    let onArchive: ((Attachment) -> Void)?
    let onRemove: ((Attachment) -> Void)?
    let headerAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if attachments.isEmpty {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: AppIcons.attachment)
                        .foregroundStyle(.secondary)
                    Text(emptyText)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    ForEach(attachments) { item in
                        AttachmentRowView(
                            item: item,
                            allowsRemoval: allowsRemoval,
                            onPreview: { onPreview(item.attachment) },
                            onOpen: { onOpen(item.attachment) },
                            onEdit: onEdit.map { action in
                                { action(item.attachment) }
                            },
                            onArchive: onArchive.map { action in
                                { action(item.attachment) }
                            },
                            onRemove: onRemove.map { action in
                                { action(item.attachment) }
                            }
                        )
                    }
                }
            }
        }
    }
}

struct AttachmentRowView: View {
    let item: AttachmentItem
    let allowsRemoval: Bool
    let onPreview: () -> Void
    let onOpen: () -> Void
    let onEdit: (() -> Void)?
    let onArchive: (() -> Void)?
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                if item.showsInlinePreview, let previewURL = item.previewURL {
                    LocalImageThumbnailView(url: previewURL)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: item.iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xSmall) {
                        Text(item.title)
                            .font(AppTypography.chip.weight(.semibold))
                            .lineLimit(1)
                        if item.isArchived {
                            InfoBadge(text: "Архив")
                        }
                    }
                    Text(item.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let descriptionText = item.descriptionText, !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: AppSpacing.small)

                actionStrip
            }

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(item.isArchived ? 0.86 : 1)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.chipBackground)
        )
    }

    private var actionStrip: some View {
        HStack(spacing: AppSpacing.small) {
            Button("Preview", action: onPreview)
                .buttonStyle(.borderless)
            Button("Open", action: onOpen)
                .buttonStyle(.borderless)
            if let onEdit {
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless)
            }
            if let onArchive {
                Button(action: onArchive) {
                    Image(systemName: AppIcons.archive)
                }
                .buttonStyle(.borderless)
                .help(item.isArchived ? "Archived" : "Archive")
                .disabled(item.isArchived)
            }
            if allowsRemoval, let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: AppIcons.delete)
                }
                .buttonStyle(.borderless)
                .help("Remove")
            }
        }
        .font(AppTypography.caption)
        .fixedSize()
    }

    private func categoryChip(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.08))
            )
    }
}

private struct LocalImageThumbnailView: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }
}

struct QuickLookPreviewSheet: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        guard let previewView = QLPreviewView(frame: .zero, style: .normal) else {
            return NSView(frame: .zero)
        }
        previewView.autostarts = true
        previewView.previewItem = url as NSURL
        return previewView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? QLPreviewView)?.previewItem = url as NSURL
    }
}
