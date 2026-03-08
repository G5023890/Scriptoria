import Foundation
import SQLite3

enum DatabaseError: LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case transactionFailed(String)
    case missingColumn(String)
    case typeMismatch(column: String, expected: String)
    case migrationFailed(version: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "SQLite open failed: \(message)"
        case .prepareFailed(let message):
            "SQLite prepare failed: \(message)"
        case .bindFailed(let message):
            "SQLite bind failed: \(message)"
        case .stepFailed(let message):
            "SQLite step failed: \(message)"
        case .transactionFailed(let message):
            "SQLite transaction failed: \(message)"
        case .missingColumn(let column):
            "SQLite row is missing column '\(column)'"
        case .typeMismatch(let column, let expected):
            "SQLite column '\(column)' is not a valid \(expected)"
        case .migrationFailed(let version, let message):
            "Migration \(version) failed: \(message)"
        }
    }
}

enum SQLiteValue: Sendable {
    case integer(Int64)
    case double(Double)
    case text(String)
    case null
}

struct SQLiteRow {
    private let statement: OpaquePointer
    private let columnIndexes: [String: Int32]

    init(statement: OpaquePointer) {
        self.statement = statement

        var indexes: [String: Int32] = [:]
        let count = sqlite3_column_count(statement)
        for index in 0..<count {
            guard let name = sqlite3_column_name(statement, index) else { continue }
            indexes[String(cString: name)] = index
        }
        columnIndexes = indexes
    }

    func string(_ column: String) throws -> String? {
        guard let index = columnIndexes[column] else {
            throw DatabaseError.missingColumn(column)
        }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        guard let text = sqlite3_column_text(statement, index) else {
            throw DatabaseError.typeMismatch(column: column, expected: "TEXT")
        }
        return String(cString: text)
    }

    func requiredString(_ column: String) throws -> String {
        guard let value = try string(column) else {
            throw DatabaseError.typeMismatch(column: column, expected: "non-null TEXT")
        }
        return value
    }

    func int64(_ column: String) throws -> Int64? {
        guard let index = columnIndexes[column] else {
            throw DatabaseError.missingColumn(column)
        }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    func requiredInt64(_ column: String) throws -> Int64 {
        guard let value = try int64(column) else {
            throw DatabaseError.typeMismatch(column: column, expected: "non-null INTEGER")
        }
        return value
    }

    func int(_ column: String) throws -> Int? {
        guard let value = try int64(column) else {
            return nil
        }
        return Int(value)
    }

    func requiredInt(_ column: String) throws -> Int {
        guard let value = try int(column) else {
            throw DatabaseError.typeMismatch(column: column, expected: "non-null INTEGER")
        }
        return value
    }

    func double(_ column: String) throws -> Double? {
        guard let index = columnIndexes[column] else {
            throw DatabaseError.missingColumn(column)
        }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    func bool(_ column: String) throws -> Bool {
        try requiredInt64(column) != 0
    }
}

struct SQLiteConnection {
    fileprivate let handle: OpaquePointer

    func execute(statement: String, bindings: [SQLiteValue] = []) throws {
        let prepared = try prepare(statement: statement, bindings: bindings)
        defer { sqlite3_finalize(prepared) }

        while true {
            let result = sqlite3_step(prepared)
            switch result {
            case SQLITE_ROW:
                continue
            case SQLITE_DONE:
                return
            default:
                throw DatabaseError.stepFailed(lastErrorMessage())
            }
        }
    }

    func query<T>(
        statement: String,
        bindings: [SQLiteValue] = [],
        map: (SQLiteRow) throws -> T
    ) throws -> [T] {
        let prepared = try prepare(statement: statement, bindings: bindings)
        defer { sqlite3_finalize(prepared) }

        var results: [T] = []
        while true {
            let result = sqlite3_step(prepared)
            switch result {
            case SQLITE_ROW:
                results.append(try map(SQLiteRow(statement: prepared)))
            case SQLITE_DONE:
                return results
            default:
                throw DatabaseError.stepFailed(lastErrorMessage())
            }
        }
    }

    func queryOne<T>(
        statement: String,
        bindings: [SQLiteValue] = [],
        map: (SQLiteRow) throws -> T
    ) throws -> T? {
        try query(statement: statement, bindings: bindings, map: map).first
    }

    func scalarInt(statement: String, bindings: [SQLiteValue] = []) throws -> Int? {
        try queryOne(statement: statement, bindings: bindings) { row in
            try row.requiredInt("value")
        }
    }

    func userVersion() throws -> Int {
        try queryOne(statement: "PRAGMA user_version;") { row in
            try row.requiredInt("user_version")
        } ?? 0
    }

    private func prepare(statement: String, bindings: [SQLiteValue]) throws -> OpaquePointer {
        var prepared: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, statement, -1, &prepared, nil)
        guard result == SQLITE_OK, let prepared else {
            throw DatabaseError.prepareFailed(lastErrorMessage())
        }

        do {
            try bind(bindings, to: prepared)
        } catch {
            sqlite3_finalize(prepared)
            throw error
        }

        return prepared
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32

            switch binding {
            case .integer(let value):
                result = sqlite3_bind_int64(statement, index, value)
            case .double(let value):
                result = sqlite3_bind_double(statement, index, value)
            case .text(let value):
                result = sqlite3_bind_text(statement, index, value, -1, sqliteTransientDestructor)
            case .null:
                result = sqlite3_bind_null(statement, index)
            }

            guard result == SQLITE_OK else {
                throw DatabaseError.bindFailed(lastErrorMessage())
            }
        }
    }

    private func lastErrorMessage() -> String {
        guard let message = sqlite3_errmsg(handle) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

enum DatabaseDateCodec {
    static func encode(_ date: Date) -> String {
        formatters[0].string(from: date)
    }

    static func decode(_ value: String) throws -> Date {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        throw DatabaseError.typeMismatch(column: "date", expected: "ISO8601 date")
    }

    private static let formatters: [ISO8601DateFormatter] = {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        return [withFractionalSeconds, withoutFractionalSeconds]
    }()
}

final class DatabaseManager {
    private let fileService: any FileService
    private let queue = DispatchQueue(label: "MyNotes.DatabaseManager")
    private var handle: OpaquePointer?
    private var isPrepared = false

    init(fileService: any FileService) {
        self.fileService = fileService
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func prepareIfNeeded() throws {
        try queue.syncThrowing {
            try prepareIfNeededLocked()
        }
    }

    func read<T>(_ body: (SQLiteConnection) throws -> T) throws -> T {
        try queue.syncThrowing {
            try prepareIfNeededLocked()
            return try body(connection)
        }
    }

    func write<T>(_ body: (SQLiteConnection) throws -> T) throws -> T {
        try read(body)
    }

    func transaction<T>(_ body: (SQLiteConnection) throws -> T) throws -> T {
        try queue.syncThrowing {
            try prepareIfNeededLocked()

            do {
                try connection.execute(statement: "BEGIN IMMEDIATE;")
                let result = try body(connection)
                try connection.execute(statement: "COMMIT;")
                return result
            } catch {
                try? connection.execute(statement: "ROLLBACK;")
                throw DatabaseError.transactionFailed(error.localizedDescription)
            }
        }
    }

    private var connection: SQLiteConnection {
        SQLiteConnection(handle: handle!)
    }

    private func prepareIfNeededLocked() throws {
        guard !isPrepared else { return }

        try fileService.ensureBaseDirectories()
        try openIfNeededLocked()
        try configureLocked()
        try runMigrationsLocked()
        isPrepared = true
    }

    private func openIfNeededLocked() throws {
        guard handle == nil else { return }

        let databaseURL = try fileService.databaseURL()
        var openedHandle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(databaseURL.path, &openedHandle, flags, nil) == SQLITE_OK, let openedHandle else {
            let message = openedHandle.flatMap(sqlite3_errmsg).map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_close(openedHandle)
            throw DatabaseError.openFailed(message)
        }

        handle = openedHandle
    }

    private func configureLocked() throws {
        try connection.execute(statement: "PRAGMA foreign_keys = ON;")
        try connection.execute(statement: "PRAGMA journal_mode = WAL;")
        try connection.execute(statement: "PRAGMA synchronous = NORMAL;")
        try connection.execute(statement: "PRAGMA temp_store = MEMORY;")
    }

    private func runMigrationsLocked() throws {
        let currentVersion = try connection.userVersion()

        for migration in DatabaseMigrations.all where migration.version > currentVersion {
            do {
                try connection.execute(statement: "BEGIN IMMEDIATE;")
                for statement in migration.statements {
                    try connection.execute(statement: statement)
                }
                try connection.execute(statement: "PRAGMA user_version = \(migration.version);")
                try connection.execute(statement: "COMMIT;")
            } catch {
                try? connection.execute(statement: "ROLLBACK;")
                throw DatabaseError.migrationFailed(version: migration.version, message: error.localizedDescription)
            }
        }
    }
}

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension DispatchQueue {
    func syncThrowing<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        sync {
            result = Result { try work() }
        }
        return try result.get()
    }
}
