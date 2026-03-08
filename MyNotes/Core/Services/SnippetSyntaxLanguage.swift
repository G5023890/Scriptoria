import Foundation
import UniformTypeIdentifiers

enum SnippetSyntaxLanguage {
    static let auto = "auto"

    struct Option: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let aliases: [String]
    }

    static let supportedOptions: [Option] = [
        Option(id: auto, title: "Auto", aliases: []),
        Option(id: "plaintext", title: "Plain Text", aliases: ["text", "plain"]),
        Option(id: "swift", title: "Swift", aliases: []),
        Option(id: "java", title: "Java", aliases: []),
        Option(id: "kotlin", title: "Kotlin", aliases: ["kt"]),
        Option(id: "javascript", title: "JavaScript", aliases: ["js"]),
        Option(id: "typescript", title: "TypeScript", aliases: ["ts"]),
        Option(id: "json", title: "JSON", aliases: []),
        Option(id: "html", title: "HTML", aliases: []),
        Option(id: "css", title: "CSS", aliases: []),
        Option(id: "xml", title: "XML", aliases: []),
        Option(id: "yaml", title: "YAML", aliases: ["yml"]),
        Option(id: "sql", title: "SQL", aliases: []),
        Option(id: "bash", title: "Bash", aliases: ["shell", "sh", "zsh"]),
        Option(id: "python", title: "Python", aliases: ["py"]),
        Option(id: "markdown", title: "Markdown", aliases: ["md"])
    ]

    static func normalizedID(for rawLanguage: String?) -> String {
        let candidate = rawLanguage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let candidate, !candidate.isEmpty else {
            return auto
        }

        if candidate == auto {
            return auto
        }

        if let option = supportedOptions.first(where: {
            $0.id == candidate || $0.aliases.contains(candidate)
        }) {
            return option.id
        }

        return candidate
    }

    static func displayName(for rawLanguage: String?) -> String {
        let normalized = normalizedID(for: rawLanguage)
        if let option = supportedOptions.first(where: { $0.id == normalized }) {
            return option.title
        }

        return normalized.isEmpty ? "Auto" : normalized.uppercased()
    }

    static func isAuto(_ rawLanguage: String?) -> Bool {
        normalizedID(for: rawLanguage) == auto
    }

    static func detectAttachmentLanguage(fileName: String, mimeType: String?) -> String {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if let utType = UTType(filenameExtension: fileExtension) {
            if utType.conforms(to: .json) { return "json" }
            if utType.conforms(to: .xml) { return "xml" }
            if utType.conforms(to: .html) { return "html" }
            if utType.conforms(to: .sourceCode) { return normalizedID(for: fileExtension) }
        }

        if let mimeType {
            switch mimeType.lowercased() {
            case "application/json":
                return "json"
            case "application/xml", "text/xml":
                return "xml"
            case "text/html":
                return "html"
            case "text/css":
                return "css"
            case "text/markdown":
                return "markdown"
            case "application/sql", "text/sql":
                return "sql"
            case "application/x-sh", "text/x-shellscript":
                return "bash"
            case "text/x-python":
                return "python"
            default:
                break
            }
        }

        switch fileExtension {
        case "swift":
            return "swift"
        case "java":
            return "java"
        case "kt", "kts":
            return "kotlin"
        case "js", "mjs", "cjs":
            return "javascript"
        case "ts", "tsx":
            return "typescript"
        case "json":
            return "json"
        case "html", "htm":
            return "html"
        case "css":
            return "css"
        case "xml":
            return "xml"
        case "yaml", "yml":
            return "yaml"
        case "sql":
            return "sql"
        case "sh", "bash", "zsh":
            return "bash"
        case "py":
            return "python"
        case "md":
            return "markdown"
        case "txt":
            return "plaintext"
        default:
            return auto
        }
    }
}
