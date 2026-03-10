import Foundation
import GRDB

struct DownloadRecord: Codable, Sendable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "downloads"

    var id: UUID
    var url: String
    var filename: String
    var fileSize: Int64?
    var progress: Double
    var status: String
    var segments: Int
    var headersJSON: String?
    var createdAt: Date
    var completedAt: Date?
    var filePath: String?
    var aria2Gid: String?

    var headers: [String: String] {
        guard let headersJSON, let data = headersJSON.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    init(
        id: UUID = UUID(),
        url: String,
        filename: String,
        fileSize: Int64? = nil,
        progress: Double = 0,
        status: String = DownloadStatus.waiting.rawValue,
        segments: Int = 8,
        headersJSON: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        filePath: String? = nil,
        aria2Gid: String? = nil
    ) {
        self.id = id
        self.url = url
        self.filename = filename
        self.fileSize = fileSize
        self.progress = progress
        self.status = status
        self.segments = segments
        self.headersJSON = headersJSON
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.filePath = filePath
        self.aria2Gid = aria2Gid
    }

    init(item: DownloadItem) {
        self.id = item.id
        self.url = item.url.absoluteString
        self.filename = item.filename
        self.fileSize = item.fileSize
        self.progress = item.progress
        self.status = item.status.rawValue
        self.segments = item.segments
        self.createdAt = item.createdAt
        self.completedAt = item.completedAt
        self.filePath = item.filePath
        self.aria2Gid = item.aria2Gid

        if !item.headers.isEmpty, let data = try? JSONEncoder().encode(item.headers) {
            self.headersJSON = String(data: data, encoding: .utf8)
        } else {
            self.headersJSON = nil
        }
    }
}
