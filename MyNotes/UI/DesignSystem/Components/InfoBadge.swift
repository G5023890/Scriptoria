import SwiftUI

struct InfoBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTypography.caption)
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, 4)
            .background(AppColors.chipBackground)
            .clipShape(Capsule())
    }
}
