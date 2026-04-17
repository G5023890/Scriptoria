import Foundation
import Highlightr

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
protocol SyntaxHighlightService {
    func highlight(code: String, language: String?) -> AttributedString
    func highlightBackgroundColor() -> ColorComponents?
}

struct ColorComponents: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

@MainActor
final class HighlightrSyntaxHighlightService: SyntaxHighlightService {
    private let highlightr: Highlightr?

    init(themeName: String = "github") {
        guard Self.hasBundledResources else {
            self.highlightr = nil
            return
        }

        let highlightr = Highlightr()
        _ = highlightr?.setTheme(to: themeName)
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        highlightr?.theme.setCodeFont(font)
        #elseif canImport(UIKit)
        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        highlightr?.theme.setCodeFont(font)
        #endif
        self.highlightr = highlightr
    }

    func highlight(code: String, language: String?) -> AttributedString {
        let normalizedLanguage = normalizedHighlightLanguage(for: language)

        guard
            let highlightr,
            let attributed = highlightr.highlight(code, as: normalizedLanguage)
        else {
            return AttributedString(code)
        }

        return AttributedString(attributed)
    }

    func highlightBackgroundColor() -> ColorComponents? {
        #if os(macOS)
        guard let color = highlightr?.theme.themeBackgroundColor?.usingColorSpace(.deviceRGB) else {
            return nil
        }

        return ColorComponents(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
        #elseif canImport(UIKit)
        guard let color = highlightr?.theme.themeBackgroundColor else {
            return nil
        }

        let components = color.cgColor.components ?? [0.95, 0.96, 0.98, 1.0]
        let red = components.count > 0 ? Double(components[0]) : 0.95
        let green = components.count > 1 ? Double(components[1]) : 0.96
        let blue = components.count > 2 ? Double(components[2]) : 0.98
        let alpha = color.cgColor.alpha

        return ColorComponents(
            red: red,
            green: green,
            blue: blue,
            alpha: Double(alpha)
        )
        #else
        return nil
        #endif
    }

    private func normalizedHighlightLanguage(for rawLanguage: String?) -> String? {
        let normalized = SnippetSyntaxLanguage.normalizedID(for: rawLanguage)
        return normalized == SnippetSyntaxLanguage.auto ? nil : normalized
    }

    private static var hasBundledResources: Bool {
        let bundleName = "Highlightr_Highlightr.bundle"
        let candidateURLs = [
            Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent(bundleName, isDirectory: true),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName, isDirectory: true)
        ].compactMap { $0 }

        return candidateURLs.contains { FileManager.default.fileExists(atPath: $0.path) }
    }
}
