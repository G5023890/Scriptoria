import SwiftUI

struct LabelChipView: View {
    let label: Label

    var body: some View {
        Text(label.name)
            .font(AppTypography.chip)
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, 4)
            .background(AppColors.chipBackground)
            .clipShape(Capsule())
    }
}
