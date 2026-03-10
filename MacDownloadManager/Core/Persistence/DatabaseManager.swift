import Foundation
import GRDB

final class DatabaseManager: Sendable {
    let dbQueue: DatabaseQueue

    init(inMemory: Bool = false) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let appSupportURL = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Mac Download Manager", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            dbQueue = try DatabaseQueue(path: appSupportURL.appendingPathComponent("downloads.db").path)
        }
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "downloads") { t in
                t.primaryKey("id", .text).notNull()
                t.column("url", .text).notNull()
                t.column("filename", .text).notNull()
                t.column("fileSize", .integer)
                t.column("progress", .double).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "waiting")
                t.column("segments", .integer).notNull().defaults(to: 8)
                t.column("headersJSON", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("completedAt", .datetime)
                t.column("filePath", .text)
                t.column("aria2Gid", .text)
            }
        }

        return migrator
    }
}
