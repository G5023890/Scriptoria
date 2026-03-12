import SwiftUI

struct LabelChipView: View {
    let label: Label

    var body: some View {
        HStack(spacing: 6) {
            LabelIconView(label: label)
                .font(.system(size: 11, weight: .semibold))
            Text(label.name)
                .lineLimit(1)
        }
        .font(AppTypography.chip)
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, 4)
        .background(AppColors.chipBackground)
        .clipShape(Capsule())
    }
}
