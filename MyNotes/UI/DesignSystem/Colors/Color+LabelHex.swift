import SwiftUI

extension Color {
    init?(labelHex: String) {
        let normalizedHex = LabelAppearanceCatalog.normalizedHex(labelHex)
        guard
            let normalizedHex,
            normalizedHex.count == 7
        else {
            return nil
        }

        let startIndex = normalizedHex.index(after: normalizedHex.startIndex)
        let hexDigits = String(normalizedHex[startIndex...])
        guard let rgbValue = UInt32(hexDigits, radix: 16) else {
            return nil
        }

        let red = Double((rgbValue >> 16) & 0xFF) / 255
        let green = Double((rgbValue >> 8) & 0xFF) / 255
        let blue = Double(rgbValue & 0xFF) / 255

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
