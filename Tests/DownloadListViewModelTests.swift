import Foundation
import Testing
@testable import Mac_Download_Manager

actor MockAria2Controller: DownloadManagingAria2 {
    struct AddCall: Equatable {
        let url: URL
        let headers: [String: String]
        let dir: String
        let segments: Int
        let outputFileName: String?
    }

    private let activeStatuses: [Aria2Status]
    private let waitingStatuses: [Aria2Status]
    private let stoppedStatuses: [Aria2Status]
    private let addResult: String
    private let resumeError: Aria2Error?

    private var resumedGIDs: [String] = []
    private var addCalls: [AddCall] = []

    init(
        activeStatuses: [Aria2Status] = [],
        waitingStatuses: [Aria2Status] = [],
        stoppedStatuses: [Aria2Status] = [],
        addResult: String = "new-gid",
        resumeError: Aria2Error? = nil
    ) {
        self.activeStatuses = activeStatuses
        self.waitingStatuses = waitingStatuses
        self.stoppedStatuses = stoppedStatuses
        self.addResult = addResult
        self.resumeError = resumeError
    }

    func addDownload(
        url: URL,
        headers: [String: String],
        dir: String,
        segments: Int,
        outputFileName: String?
    ) async throws(Aria2Error) -> String {
        addCalls.append(AddCall(
            url: url,
            headers: headers,
            dir: dir,
            segments: segments,
            outputFileName: outputFileName
        ))
        return addResult
    }

    func pause(gid: String) async throws(Aria2Error) {}

    func resume(gid: String) async throws(Aria2Error) {
        resumedGIDs.append(gid)
        if let resumeError {
            throw resumeError
        }
    }

    func forceRemove(gid: String) async throws(Aria2Error) {}

    func removeDownloadResult(gid: String) async throws(Aria2Error) {}

    func tellActive() async throws(Aria2Error) -> [Aria2Status] {
        activeStatuses
    }

    func tellWaiting(offset: Int, count: Int) async throws(Aria2Error) -> [Aria2Status] {
        waitingStatuses
    }

    func tellStopped(offset: Int, count: Int) async throws(Aria2Error) -> [Aria2Status] {
        stoppedStatuses
    }

    func recordedResumes() -> [String] {
        resumedGIDs
    }

    func recordedAddCalls() -> [AddCall] {
        addCalls
    }
}

@Suite("DownloadListViewModel")
struct DownloadListViewModelTests {
    @Test @MainActor
    func loadDownloadsClearsMissingGIDForRelaunchedApp() async throws {
        let repository = InMemoryDownloadRepository()
        let record = DownloadRecord(
            url: "https://example.com/archive.zip",
            filename: "archive.zip",
            progress: 0.42,
            status: DownloadStatus.downloading.rawValue,
            segments: 8,
            filePath: "/tmp/downloads",
            aria2Gid: "stale-gid"
        )
        try await repository.save(record)

        let aria2 = MockAria2Controller()
        let viewModel = DownloadListViewModel(repository: repository, aria2: aria2)

        await viewModel.loadDownloads()

        let loaded = try #require(viewModel.downloads.first)
        #expect(loaded.status == .paused)
        #expect(loaded.aria2Gid == nil)

        let persisted = try await repository.fetch(id: record.id)
        #expect(persisted?.status == DownloadStatus.paused.rawValue)
        #expect(persisted?.aria2Gid == nil)
    }

    @Test @MainActor
    func resumeDownloadRecreatesSessionWhenAriaRejectsPersistedGID() async throws {
        let repository = InMemoryDownloadRepository()
        let record = DownloadRecord(
            url: "https://example.com/archive.zip",
            filename: "archive.zip",
            progress: 0.42,
            status: DownloadStatus.paused.rawValue,
            segments: 12,
            filePath: "/tmp/downloads",
            aria2Gid: "stale-gid"
        )
        try await repository.save(record)

        let aria2 = MockAria2Controller(
            addResult: "fresh-gid",
            resumeError: .requestFailed(statusCode: 400)
        )
        let viewModel = DownloadListViewModel(repository: repository, aria2: aria2)
        let item = DownloadItem(record: record)
        viewModel.downloads = [item]

        await viewModel.resumeDownload(item)

        let updated = try #require(viewModel.downloads.first)
        #expect(updated.status == .downloading)
        #expect(updated.aria2Gid == "fresh-gid")
        #expect(updated.filePath == "/tmp/downloads")

        let persisted = try await repository.fetch(id: record.id)
        #expect(persisted?.status == DownloadStatus.downloading.rawValue)
        #expect(persisted?.aria2Gid == "fresh-gid")

        let resumedGIDs = await aria2.recordedResumes()
        #expect(resumedGIDs == ["stale-gid"])

        let addCalls = await aria2.recordedAddCalls()
        #expect(addCalls.count == 1)
        #expect(addCalls.first?.url == URL(string: "https://example.com/archive.zip"))
        #expect(addCalls.first?.dir == "/tmp/downloads")
        #expect(addCalls.first?.segments == 12)
        #expect(addCalls.first?.outputFileName == "archive.zip")
    }
}
