import Foundation
import GRDB

struct GRDBDownloadRepository: DownloadRepository {
    let dbQueue: DatabaseQueue

    func fetchAll() async throws -> [DownloadRecord] {
        try await dbQueue.read { db in
            try DownloadRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchActive() async throws -> [DownloadRecord] {
        let activeStatuses = [
            DownloadStatus.waiting.rawValue,
            DownloadStatus.downloading.rawValue,
            DownloadStatus.paused.rawValue,
        ]
        return try await dbQueue.read { db in
            try DownloadRecord
                .filter(activeStatuses.contains(Column("status")))
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetch(id: UUID) async throws -> DownloadRecord? {
        try await dbQueue.read { db in
            try DownloadRecord.fetchOne(db, id: id)
        }
    }

    func fetchByGid(_ gid: String) async throws -> DownloadRecord? {
        try await dbQueue.read { db in
            try DownloadRecord
                .filter(Column("aria2Gid") == gid)
                .fetchOne(db)
        }
    }

    func fetchByURL(_ url: String) async throws -> DownloadRecord? {
        try await dbQueue.read { db in
            try DownloadRecord
                .filter(Column("url") == url)
                .fetchOne(db)
        }
    }

    func save(_ record: DownloadRecord) async throws {
        try await dbQueue.write { db in
            try record.insert(db)
        }
    }

    func update(_ record: DownloadRecord) async throws {
        try await dbQueue.write { db in
            try record.update(db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await dbQueue.write { db in
            try DownloadRecord.deleteOne(db, id: id)
        }
    }

    func search(query: String) async throws -> [DownloadRecord] {
        try await dbQueue.read { db in
            try DownloadRecord
                .filter(
                    Column("filename").like("%\(query)%")
                        || Column("url").like("%\(query)%")
                )
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }
}
