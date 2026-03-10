import Testing
@testable import Mac_Download_Manager

@Suite
struct DownloadRepositoryTests {
    @Test func inMemorySaveAndFetch() async throws {
        let repo = InMemoryDownloadRepository()
        let record = DownloadRecord(
            url: "https://example.com/file.zip",
            filename: "file.zip",
            fileSize: 1024,
            status: DownloadStatus.downloading.rawValue,
            segments: 8
        )

        try await repo.save(record)
        let fetched = try await repo.fetch(id: record.id)
        #expect(fetched != nil)
        #expect(fetched?.filename == "file.zip")
        #expect(fetched?.fileSize == 1024)
    }

    @Test func inMemoryFetchActive() async throws {
        let repo = InMemoryDownloadRepository()

        let active = DownloadRecord(
            url: "https://example.com/a.zip",
            filename: "a.zip",
            status: DownloadStatus.downloading.rawValue
        )
        let completed = DownloadRecord(
            url: "https://example.com/b.zip",
            filename: "b.zip",
            status: DownloadStatus.completed.rawValue
        )

        try await repo.save(active)
        try await repo.save(completed)

        let activeRecords = try await repo.fetchActive()
        #expect(activeRecords.count == 1)
        #expect(activeRecords.first?.filename == "a.zip")
    }

    @Test func inMemoryDelete() async throws {
        let repo = InMemoryDownloadRepository()
        let record = DownloadRecord(
            url: "https://example.com/file.zip",
            filename: "file.zip"
        )

        try await repo.save(record)
        try await repo.delete(id: record.id)
        let fetched = try await repo.fetch(id: record.id)
        #expect(fetched == nil)
    }

    @Test func inMemorySearch() async throws {
        let repo = InMemoryDownloadRepository()

        let r1 = DownloadRecord(url: "https://example.com/photo.jpg", filename: "photo.jpg")
        let r2 = DownloadRecord(url: "https://example.com/video.mp4", filename: "video.mp4")

        try await repo.save(r1)
        try await repo.save(r2)

        let results = try await repo.search(query: "photo")
        #expect(results.count == 1)
        #expect(results.first?.filename == "photo.jpg")
    }

    @Test func grdbSaveAndFetch() async throws {
        let db = try DatabaseManager(inMemory: true)
        let repo = GRDBDownloadRepository(dbQueue: db.dbQueue)

        let record = DownloadRecord(
            url: "https://example.com/file.dmg",
            filename: "file.dmg",
            fileSize: 2048,
            status: DownloadStatus.waiting.rawValue,
            segments: 16,
            aria2Gid: "abc123"
        )

        try await repo.save(record)
        let fetched = try await repo.fetch(id: record.id)
        #expect(fetched != nil)
        #expect(fetched?.filename == "file.dmg")
        #expect(fetched?.aria2Gid == "abc123")

        let byGid = try await repo.fetchByGid("abc123")
        #expect(byGid != nil)
        #expect(byGid?.id == record.id)
    }
}
