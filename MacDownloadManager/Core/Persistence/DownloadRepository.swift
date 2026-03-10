import Foundation

protocol DownloadRepository: Sendable {
    func fetchAll() async throws -> [DownloadRecord]
    func fetchActive() async throws -> [DownloadRecord]
    func fetch(id: UUID) async throws -> DownloadRecord?
    func fetchByGid(_ gid: String) async throws -> DownloadRecord?
    func save(_ record: DownloadRecord) async throws
    func update(_ record: DownloadRecord) async throws
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [DownloadRecord]
}

actor InMemoryDownloadRepository: DownloadRepository {
    private var records: [UUID: DownloadRecord] = [:]

    func fetchAll() async throws -> [DownloadRecord] {
        records.values.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchActive() async throws -> [DownloadRecord] {
        let activeStatuses: Set<String> = [
            DownloadStatus.waiting.rawValue,
            DownloadStatus.downloading.rawValue,
            DownloadStatus.paused.rawValue,
        ]
        return records.values
            .filter { activeStatuses.contains($0.status) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetch(id: UUID) async throws -> DownloadRecord? {
        records[id]
    }

    func fetchByGid(_ gid: String) async throws -> DownloadRecord? {
        records.values.first { $0.aria2Gid == gid }
    }

    func save(_ record: DownloadRecord) async throws {
        records[record.id] = record
    }

    func update(_ record: DownloadRecord) async throws {
        records[record.id] = record
    }

    func delete(id: UUID) async throws {
        records.removeValue(forKey: id)
    }

    func search(query: String) async throws -> [DownloadRecord] {
        let lowered = query.lowercased()
        return records.values
            .filter { $0.filename.lowercased().contains(lowered) || $0.url.lowercased().contains(lowered) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
