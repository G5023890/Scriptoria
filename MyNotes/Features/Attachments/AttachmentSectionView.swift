import AppKit
import QuickLookUI
import SwiftUI

struct AttachmentSectionView: View {
    let title: String
    let attachments: [AttachmentItem]
    let emptyText: String
    let allowsRemoval: Bool
    let syntaxHighlightService: any SyntaxHighlightService
    let onPreview: (Attachment) -> Void
    let onOpen: (Attachment) -> Void
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
                            syntaxHighlightService: syntaxHighlightService,
                            onPreview: { onPreview(item.attachment) },
                            onOpen: { onOpen(item.attachment) },
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

private struct AttachmentRowView: View {
    let item: AttachmentItem
    let allowsRemoval: Bool
    let syntaxHighlightService: any SyntaxHighlightService
    let onPreview: () -> Void
    let onOpen: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                categoryChip(systemImage: "paperclip")

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
                    Text(item.title)
                        .font(AppTypography.chip.weight(.semibold))
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.small)

                actionStrip
            }

            if let codePreview = item.codePreview, let codeLanguage = item.codeLanguage {
                SyntaxHighlightedCodeView(
                    code: codePreview,
                    language: codeLanguage,
                    syntaxHighlightService: syntaxHighlightService,
                    lineLimit: 6
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
            if allowsRemoval, let onRemove {
                Button("Remove", role: .destructive, action: onRemove)
                    .buttonStyle(.borderless)
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
