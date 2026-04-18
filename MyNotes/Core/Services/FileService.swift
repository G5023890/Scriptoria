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
    func copyBundledResourceIfNeeded(
        named resourceName: String,
        withExtension resourceExtension: String,
        subdirectory: String?,
        toRelativePath relativePath: String
    ) throws
    func importAttachment(from sourceURL: URL, noteID: NoteID, attachmentID: AttachmentID) throws -> ImportedAttachmentFile
    func absoluteURL(for relativePath: String) throws -> URL
    func writeFile(atRelativePath relativePath: String, from sourceURL: URL) throws
    func temporaryFileURL(forFileNamed fileName: String) throws -> URL
    func readTextFile(atRelativePath relativePath: String, maxCharacters: Int) throws -> String?
    func deleteItem(atRelativePath relativePath: String) throws
    func cleanupStorage(
        retainingAttachmentRelativePaths retainedRelativePaths: Set<String>,
        maximumRetainedBackups: Int,
        purgeCloudKitAssetCache: Bool
    ) throws -> StorageCleanupReport
}

struct StorageCleanupReport: Sendable {
    var orphanedAttachmentFilesRemoved: Int = 0
    var emptyAttachmentDirectoriesRemoved: Int = 0
    var backupArtifactsRemoved: Int = 0
    var temporarySyncFilesRemoved: Int = 0
    var cloudKitCacheEntriesRemoved: Int = 0

    static let empty = StorageCleanupReport()
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

    func copyBundledResourceIfNeeded(
        named resourceName: String,
        withExtension resourceExtension: String,
        subdirectory: String? = nil,
        toRelativePath relativePath: String
    ) throws {
        try ensureBaseDirectories()

        let destinationURL = try absoluteURL(for: relativePath)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return
        }

        guard let sourceURL = resourceBundle.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: subdirectory
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let parentDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func importAttachment(from sourceURL: URL, noteID: NoteID, attachmentID: AttachmentID) throws -> ImportedAttachmentFile {
        try ensureBaseDirectories()

        let scopedAccessStarted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scopedAccessStarted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

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

    func writeFile(atRelativePath relativePath: String, from sourceURL: URL) throws {
        try ensureBaseDirectories()

        let destinationURL = try absoluteURL(for: relativePath)
        let parentDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func temporaryFileURL(forFileNamed fileName: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("ScriptoriaCloudKit", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let destinationURL = directory.appendingPathComponent("\(UUID().uuidString.lowercased())-\(fileName)")
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        return destinationURL
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

    func cleanupStorage(
        retainingAttachmentRelativePaths retainedRelativePaths: Set<String>,
        maximumRetainedBackups: Int = 2,
        purgeCloudKitAssetCache: Bool
    ) throws -> StorageCleanupReport {
        try ensureBaseDirectories()

        var report = StorageCleanupReport.empty
        let baseDirectory = try applicationSupportDirectory()

        report.orphanedAttachmentFilesRemoved += try cleanupOrphanedAttachmentFiles(
            in: baseDirectory,
            retainingRelativePaths: retainedRelativePaths
        )
        report.emptyAttachmentDirectoriesRemoved += try removeEmptyAttachmentDirectories(in: baseDirectory)
        report.backupArtifactsRemoved += try trimBackupArtifacts(
            in: baseDirectory,
            maximumRetainedBackups: maximumRetainedBackups
        )
        report.temporarySyncFilesRemoved += try clearTemporarySyncFiles()

        if purgeCloudKitAssetCache {
            report.cloudKitCacheEntriesRemoved += try purgeCloudKitAssetCacheIfPresent(
                applicationSupportDirectory: baseDirectory
            )
        }

        return report
    }

    private var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
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

    private func cleanupOrphanedAttachmentFiles(
        in baseDirectory: URL,
        retainingRelativePaths retainedRelativePaths: Set<String>
    ) throws -> Int {
        let attachmentsRoot = baseDirectory.appendingPathComponent("attachments", isDirectory: true)
        guard fileManager.fileExists(atPath: attachmentsRoot.path) else { return 0 }

        let enumerator = fileManager.enumerator(
            at: attachmentsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var removedCount = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = normalizedRelativePath(from: baseDirectory, to: fileURL)
            guard !retainedRelativePaths.contains(relativePath) else { continue }

            try fileManager.removeItem(at: fileURL)
            removedCount += 1
        }

        return removedCount
    }

    private func removeEmptyAttachmentDirectories(in baseDirectory: URL) throws -> Int {
        let attachmentsRoot = baseDirectory.appendingPathComponent("attachments", isDirectory: true)
        guard fileManager.fileExists(atPath: attachmentsRoot.path) else { return 0 }

        let enumerator = fileManager.enumerator(
            at: attachmentsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var directories: [URL] = []
        while let directoryURL = enumerator?.nextObject() as? URL {
            let values = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                directories.append(directoryURL)
            }
        }

        var removedCount = 0
        for directoryURL in directories.sorted(by: { $0.path.count > $1.path.count }) {
            guard directoryURL != attachmentsRoot else { continue }
            let contents = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
            guard contents.isEmpty else { continue }
            try fileManager.removeItem(at: directoryURL)
            removedCount += 1
        }

        return removedCount
    }

    private func trimBackupArtifacts(
        in baseDirectory: URL,
        maximumRetainedBackups: Int
    ) throws -> Int {
        let backupsDirectory = baseDirectory.appendingPathComponent("backups", isDirectory: true)
        guard fileManager.fileExists(atPath: backupsDirectory.path) else { return 0 }

        let children = try fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        guard children.count > maximumRetainedBackups else { return 0 }

        let sortedChildren = try children.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        var removedCount = 0
        for child in sortedChildren.dropFirst(maximumRetainedBackups) {
            try fileManager.removeItem(at: child)
            removedCount += 1
        }

        return removedCount
    }

    private func clearTemporarySyncFiles() throws -> Int {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("ScriptoriaCloudKit", isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }

        let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for child in children {
            try fileManager.removeItem(at: child)
        }
        return children.count
    }

    private func purgeCloudKitAssetCacheIfPresent(applicationSupportDirectory: URL) throws -> Int {
        guard let cloudKitCacheDirectory = cloudKitCacheDirectory(
            from: applicationSupportDirectory
        ) else {
            return 0
        }

        guard fileManager.fileExists(atPath: cloudKitCacheDirectory.path) else { return 0 }
        let children = try fileManager.contentsOfDirectory(
            at: cloudKitCacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for child in children {
            try fileManager.removeItem(at: child)
        }

        return children.count
    }

    private func cloudKitCacheDirectory(from applicationSupportDirectory: URL) -> URL? {
        let libraryDirectory = applicationSupportDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard libraryDirectory.lastPathComponent == "Library" else {
            return nil
        }

        return libraryDirectory.appendingPathComponent("Caches/CloudKit", isDirectory: true)
    }

    private func normalizedRelativePath(from baseDirectory: URL, to fileURL: URL) -> String {
        let basePath = baseDirectory.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        guard filePath.hasPrefix(basePath) else {
            return fileURL.lastPathComponent
        }

        return String(filePath.dropFirst(basePath.count + 1))
    }
}
