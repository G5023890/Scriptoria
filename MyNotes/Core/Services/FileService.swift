import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

struct ImportedAttachmentFile: Sendable {
    let category: AttachmentCategory
    let fileName: String
    let originalFileName: String
    let relativePath: String
    let fileSize: Int64?
    let mimeType: String
    let checksum: String
    let width: Int?
    let height: Int?
    let duration: Double?
    let pageCount: Int?
}

protocol FileService {
    func ensureBaseDirectories() throws
    func applicationSupportDirectory() throws -> URL
    func databaseURL() throws -> URL
    func thumbnailsDirectory() throws -> URL
    func attachmentsDirectory(for noteID: NoteID) throws -> URL
    func importAttachment(from sourceURL: URL, noteID: NoteID, attachmentID: AttachmentID) throws -> ImportedAttachmentFile
    func absoluteURL(for relativePath: String) throws -> URL
    func readTextFile(atRelativePath relativePath: String, maxCharacters: Int) throws -> String?
    func deleteItem(atRelativePath relativePath: String) throws
}

struct LocalFileService: FileService {
    private let fileManager: FileManager
    private let folderName: String

    init(fileManager: FileManager = .default, folderName: String = "NotesData") {
        self.fileManager = fileManager
        self.folderName = folderName
    }

    func ensureBaseDirectories() throws {
        let base = try applicationSupportDirectory()
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(
            at: base.appendingPathComponent("attachments", isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(
            at: base.appendingPathComponent("thumbnails", isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func applicationSupportDirectory() throws -> URL {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return root.appendingPathComponent(folderName, isDirectory: true)
    }

    func databaseURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("notes.sqlite", isDirectory: false)
    }

    func thumbnailsDirectory() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("thumbnails", isDirectory: true)
    }

    func attachmentsDirectory(for noteID: NoteID) throws -> URL {
        let directory = try applicationSupportDirectory()
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent("note_\(noteID.rawValue)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    func importAttachment(from sourceURL: URL, noteID: NoteID, attachmentID: AttachmentID) throws -> ImportedAttachmentFile {
        try ensureBaseDirectories()

        let originalFileName = sourceURL.lastPathComponent
        let resourceValues = try? sourceURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let resolvedType = resourceValues?.contentType ?? typeForSourceURL(sourceURL)
        let sanitizedExt = fileExtension(for: sourceURL, type: resolvedType)
        let fileName = makeInternalFileName(
            attachmentID: attachmentID,
            originalFileName: originalFileName,
            pathExtension: sanitizedExt
        )
        let destinationDirectory = try attachmentsDirectory(for: noteID)
        let destinationURL = destinationDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let relativePath = "attachments/note_\(noteID.rawValue)/\(fileName)"
        let data = try Data(contentsOf: destinationURL, options: .mappedIfSafe)
        let checksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let mimeType = resolvedType?.preferredMIMEType ?? "application/octet-stream"
        let fileSize = (try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value
        let imageMetadata = imageMetadata(for: destinationURL)
        let pageCount = pdfPageCount(for: destinationURL, type: resolvedType)
        let duration = mediaDuration(for: destinationURL, type: resolvedType)

        return ImportedAttachmentFile(
            category: category(for: resolvedType, sourceURL: destinationURL),
            fileName: fileName,
            originalFileName: originalFileName,
            relativePath: relativePath,
            fileSize: fileSize,
            mimeType: mimeType,
            checksum: checksum,
            width: imageMetadata?.width,
            height: imageMetadata?.height,
            duration: duration,
            pageCount: pageCount
        )
    }

    func absoluteURL(for relativePath: String) throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(relativePath)
    }

    func readTextFile(atRelativePath relativePath: String, maxCharacters: Int = 4_000) throws -> String? {
        let url = try absoluteURL(for: relativePath)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !data.isEmpty else { return "" }

        let encodings: [String.Encoding] = [.utf8, .utf16, .unicode, .ascii, .windowsCP1251]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return String(text.prefix(maxCharacters))
            }
        }

        return nil
    }

    func deleteItem(atRelativePath relativePath: String) throws {
        let url = try absoluteURL(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func typeForSourceURL(_ sourceURL: URL) -> UTType? {
        guard !sourceURL.pathExtension.isEmpty else { return nil }
        return UTType(filenameExtension: sourceURL.pathExtension.lowercased())
    }

    private func fileExtension(for sourceURL: URL, type: UTType?) -> String {
        if let preferredFilenameExtension = type?.preferredFilenameExtension, !preferredFilenameExtension.isEmpty {
            return preferredFilenameExtension.lowercased()
        }

        let pathExtension = sourceURL.pathExtension.lowercased()
        return pathExtension.isEmpty ? "bin" : pathExtension
    }

    private func makeInternalFileName(
        attachmentID: AttachmentID,
        originalFileName: String,
        pathExtension: String
    ) -> String {
        let baseName = URL(fileURLWithPath: originalFileName)
            .deletingPathExtension()
            .lastPathComponent
        let sanitizedBaseName = sanitizeBaseName(baseName)
        return "attachment_\(attachmentID.rawValue)_\(sanitizedBaseName).\(pathExtension)"
    }

    private func sanitizeBaseName(_ value: String) -> String {
        let sanitized = value
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: "-",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if sanitized.isEmpty {
            return "file"
        }

        return String(sanitized.prefix(40))
    }

    private func category(for type: UTType?, sourceURL: URL) -> AttachmentCategory {
        if type?.conforms(to: .image) == true { return .image }
        if type?.conforms(to: .pdf) == true { return .pdf }
        if type?.conforms(to: .audio) == true { return .audio }
        if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true { return .video }
        if type?.conforms(to: .sourceCode) == true || type?.conforms(to: .text) == true {
            return .code
        }

        switch sourceURL.pathExtension.lowercased() {
        case "md", "txt", "json", "yaml", "yml", "toml", "swift", "js", "ts", "py", "java", "rb", "rs", "css", "html":
            return .code
        default:
            return .file
        }
    }

    private func imageMetadata(for url: URL) -> (width: Int, height: Int)? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        else {
            return nil
        }

        guard
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }

        return (width, height)
    }

    private func pdfPageCount(for url: URL, type: UTType?) -> Int? {
        guard type?.conforms(to: .pdf) == true else { return nil }
        return PDFDocument(url: url)?.pageCount
    }

    private func mediaDuration(for url: URL, type: UTType?) -> Double? {
        guard type?.conforms(to: .audio) == true || type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true else {
            return nil
        }

        let asset = AVURLAsset(url: url)
        let duration = asset.duration.seconds
        guard duration.isFinite else { return nil }
        return duration
    }
}
