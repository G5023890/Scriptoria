import Foundation

struct LabelColorOption: Identifiable, Hashable, Sendable {
    let name: String
    let hex: String?

    var id: String { hex ?? "default" }
}

enum LabelAppearanceCatalog {
    static let defaultIconName = "tag.fill"

    static let allowedIconNames: [String] = [
        "lightbulb.min",
        "swift",
        "chevron.left.forwardslash.chevron.right",
        "lamp.floor",
        "powerplug.portrait",
        "party.popper",
        "balloon",
        "laser.burst",
        "bed.double",
        "lock",
        "watch.analog",
        "minus.plus.batteryblock",
        "key.viewfinder",
        "document.viewfinder",
        "alarm",
        "cup.and.saucer",
        "archivebox",
        "bookmark",
        "xmark.bin",
        "magnifyingglass",
        "bell",
        defaultIconName,
        "tag.slash",
        "tag.slash.fill",
        "cart",
        "gearshape",
        "wallet.bifold",
        "theatermasks",
        "suitcase.rolling",
        "puzzlepiece.extension"
    ]

    static let colorOptions: [LabelColorOption] = [
        LabelColorOption(name: "Default/System", hex: nil),
        LabelColorOption(name: "Red", hex: "#FF3B30"),
        LabelColorOption(name: "Orange", hex: "#FF9500"),
        LabelColorOption(name: "Yellow", hex: "#FFCC00"),
        LabelColorOption(name: "Green", hex: "#34C759"),
        LabelColorOption(name: "Cyan", hex: "#64D2FF"),
        LabelColorOption(name: "Blue", hex: "#0A84FF"),
        LabelColorOption(name: "Indigo", hex: "#5E5CE6"),
        LabelColorOption(name: "Pink", hex: "#FF375F")
    ]

    static func displayIconName(_ iconName: String?) -> String {
        guard let iconName, !iconName.isEmpty else {
            return defaultIconName
        }
        return iconName
    }

    static func normalizedHex(_ hex: String?) -> String? {
        guard let hex else { return nil }
        let trimmedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHex.isEmpty else { return nil }

        let prefixedHex = trimmedHex.hasPrefix("#") ? trimmedHex : "#\(trimmedHex)"
        return prefixedHex.uppercased()
    }

    static func isAllowedIcon(_ iconName: String?) -> Bool {
        guard let iconName else { return false }
        return allowedIconNames.contains(iconName)
    }

    static func isLegacyIcon(_ iconName: String?) -> Bool {
        guard let iconName else { return false }
        return !isAllowedIcon(iconName)
    }

    static func isPaletteColor(_ hex: String?) -> Bool {
        let normalizedHex = normalizedHex(hex)
        return colorOptions.contains { $0.hex == normalizedHex }
    }
}
