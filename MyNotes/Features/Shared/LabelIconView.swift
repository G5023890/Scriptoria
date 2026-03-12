import SwiftUI

struct LabelIconView: View {
    let iconName: String?
    let colorHex: String?

    init(label: Label) {
        self.iconName = label.iconName
        self.colorHex = label.color
    }

    init(iconName: String?, colorHex: String?) {
        self.iconName = iconName
        self.colorHex = colorHex
    }

    var body: some View {
        Image(systemName: LabelAppearanceCatalog.displayIconName(iconName))
            .foregroundStyle(iconStyle)
    }

    private var iconStyle: AnyShapeStyle {
        if let color = colorHex.flatMap(Color.init(labelHex:)) {
            return AnyShapeStyle(color)
        }
        return AnyShapeStyle(.secondary)
    }
}
