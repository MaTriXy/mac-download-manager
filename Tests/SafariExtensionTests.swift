import XCTest

@testable import MacDownloadManager

final class SafariExtensionTests: XCTestCase {

    // MARK: - SafariDownloadMonitor Tests

    @MainActor
    func testMonitorStartAndStop() async {
        let monitor = SafariDownloadMonitor { _ in }
        monitor.start()
        // Starting twice should be safe (idempotent)
        monitor.start()
        monitor.stop()
        // Stopping twice should be safe
        monitor.stop()
    }

    @MainActor
    func testMonitorParsesDownloadRequest() async {
        let appGroupId = "group.com.macdownloadmanager"
        let pendingDownloadsKey = "pendingDownloads"

        let expectation = XCTestExpectation(description: "Download request received")

        var receivedMessage: NativeMessage?

        let monitor = SafariDownloadMonitor { message in
            receivedMessage = message
            expectation.fulfill()
        }

        // Write a mock download request to the App Group UserDefaults
        if let defaults = UserDefaults(suiteName: appGroupId) {
            let request: [[String: Any]] = [
                [
                    "url": "https://example.com/file.zip",
                    "filename": "file.zip",
                    "headers": ["cookie": "session=abc123"],
                    "referrer": "https://example.com/",
                    "fileSize": 1048576,
                    "timestamp": Date().timeIntervalSince1970,
                ],
            ]
            defaults.set(request, forKey: pendingDownloadsKey)
        }

        monitor.start()

        await fulfillment(of: [expectation], timeout: 5.0)

        monitor.stop()

        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.url, "https://example.com/file.zip")
        XCTAssertEqual(receivedMessage?.filename, "file.zip")
        XCTAssertEqual(receivedMessage?.referrer, "https://example.com/")
        XCTAssertEqual(receivedMessage?.fileSize, 1_048_576)
        XCTAssertEqual(receivedMessage?.headers?["cookie"], "session=abc123")

        // Verify the pending downloads were cleared
        if let defaults = UserDefaults(suiteName: appGroupId) {
            let remaining =
                defaults.array(forKey: pendingDownloadsKey) as? [[String: Any]]
            XCTAssertNil(remaining, "Pending downloads should be cleared after processing")
        }
    }

    @MainActor
    func testMonitorIgnoresEmptyUrl() async {
        let appGroupId = "group.com.macdownloadmanager"
        let pendingDownloadsKey = "pendingDownloads"

        var downloadCount = 0

        let monitor = SafariDownloadMonitor { _ in
            downloadCount += 1
        }

        // Write a request with empty URL
        if let defaults = UserDefaults(suiteName: appGroupId) {
            let request: [[String: Any]] = [
                [
                    "url": "",
                    "filename": "file.zip",
                ],
            ]
            defaults.set(request, forKey: pendingDownloadsKey)
        }

        monitor.start()

        // Wait for at least one poll cycle
        try? await Task.sleep(for: .seconds(3))

        monitor.stop()

        XCTAssertEqual(downloadCount, 0, "Should not process requests with empty URL")
    }

    @MainActor
    func testMonitorHandlesOptionalFields() async {
        let appGroupId = "group.com.macdownloadmanager"
        let pendingDownloadsKey = "pendingDownloads"

        let expectation = XCTestExpectation(description: "Download request received")

        var receivedMessage: NativeMessage?

        let monitor = SafariDownloadMonitor { message in
            receivedMessage = message
            expectation.fulfill()
        }

        // Write a minimal request (only URL)
        if let defaults = UserDefaults(suiteName: appGroupId) {
            let request: [[String: Any]] = [
                [
                    "url": "https://example.com/archive.tar.gz",
                ],
            ]
            defaults.set(request, forKey: pendingDownloadsKey)
        }

        monitor.start()

        await fulfillment(of: [expectation], timeout: 5.0)

        monitor.stop()

        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.url, "https://example.com/archive.tar.gz")
        XCTAssertNil(receivedMessage?.filename)
        XCTAssertNil(receivedMessage?.headers)
        XCTAssertNil(receivedMessage?.referrer)
        XCTAssertNil(receivedMessage?.fileSize)
    }
}
