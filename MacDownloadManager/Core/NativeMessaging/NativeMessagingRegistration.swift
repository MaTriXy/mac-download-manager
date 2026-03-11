import Foundation

enum NativeMessagingBrowser: String, CaseIterable, Sendable {
    case chrome
    case firefox
    case edge
}

struct BrowserManifestPath: Sendable {
    let browser: NativeMessagingBrowser
    let directory: URL
}

enum NativeMessagingError: Error, CustomStringConvertible {
    case serializationFailed(browser: NativeMessagingBrowser, underlying: Error)

    var description: String {
        switch self {
        case .serializationFailed(let browser, let underlying):
            return "Failed to serialize native messaging manifest for \(browser.rawValue): \(underlying.localizedDescription)"
        }
    }
}

enum NativeMessagingRegistration {

    private static let manifestName = "com.macdownloadmanager.helper"

    /// Firefox extension ID matching gecko.id in the Firefox manifest.
    private static let firefoxExtensionId = "macdownloadmanager@example.com"

    /// Development extension ID derived from the deterministic public key
    /// embedded in Chrome/Edge manifest.json (see scripts/build-extensions.js).
    /// When the extension is published to the Chrome Web Store or Edge Add-ons,
    /// replace this with the store-assigned extension ID.
    private static let chromeExtensionId = "iomcmbjooojnddcbbillnngpdmionlmo"

    /// Chrome allowed origins. Each origin must be in the format
    /// `chrome-extension://EXTENSION_ID/` with an exact extension ID.
    /// Chromium does not support wildcards in allowed_origins.
    static let chromeAllowedOrigins: [String] = [
        "chrome-extension://\(chromeExtensionId)/",
    ]

    /// Edge shares the Chromium extension model and uses the same origin format
    /// and extension ID (both are built from the same public key).
    static let edgeAllowedOrigins: [String] = [
        "chrome-extension://\(chromeExtensionId)/",
    ]

    static func browserPaths() -> [BrowserManifestPath] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            BrowserManifestPath(
                browser: .chrome,
                directory: home.appendingPathComponent(
                    "Library/Application Support/Google/Chrome/NativeMessagingHosts"
                )
            ),
            BrowserManifestPath(
                browser: .firefox,
                directory: home.appendingPathComponent(
                    "Library/Application Support/Mozilla/NativeMessagingHosts"
                )
            ),
            BrowserManifestPath(
                browser: .edge,
                directory: home.appendingPathComponent(
                    "Library/Application Support/Microsoft Edge/NativeMessagingHosts"
                )
            ),
        ]
    }

    static func manifestData(for browser: NativeMessagingBrowser, helperPath: String) throws -> Data {
        var dict: [String: Any] = [
            "name": manifestName,
            "description": "Mac Download Manager Native Messaging Host",
            "path": helperPath,
            "type": "stdio",
        ]

        switch browser {
        case .chrome:
            dict["allowed_origins"] = chromeAllowedOrigins
        case .edge:
            dict["allowed_origins"] = edgeAllowedOrigins
        case .firefox:
            dict["allowed_extensions"] = [firefoxExtensionId]
        }

        do {
            return try JSONSerialization.data(
                withJSONObject: dict,
                options: [.prettyPrinted, .sortedKeys]
            )
        } catch {
            throw NativeMessagingError.serializationFailed(browser: browser, underlying: error)
        }
    }

    static func registerAll(helperPath: String) {
        for entry in browserPaths() {
            do {
                try FileManager.default.createDirectory(
                    at: entry.directory,
                    withIntermediateDirectories: true
                )
                let data = try manifestData(for: entry.browser, helperPath: helperPath)
                let manifestFile = entry.directory.appendingPathComponent("\(manifestName).json")
                try data.write(to: manifestFile)
            } catch {
                print(
                    "Failed to register native messaging manifest for \(entry.browser.rawValue): \(error)"
                )
            }
        }
    }
}
