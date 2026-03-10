import AppKit
import Foundation

@Observable @MainActor
final class MenuBarViewModel {
    private let repository: any DownloadRepository
    private let aria2: Aria2Client

    var activeDownloads: [DownloadItem] = []
    var globalSpeed: Int64 = 0

    init(repository: any DownloadRepository, aria2: Aria2Client) {
        self.repository = repository
        self.aria2 = aria2
    }

    func refresh() async {
        do {
            let records = try await repository.fetchActive()
            activeDownloads = records.map { DownloadItem(record: $0) }
            let stat = try await aria2.getGlobalStat()
            globalSpeed = Int64(stat.downloadSpeed) ?? 0
        } catch {
            activeDownloads = []
            globalSpeed = 0
        }
    }

    func pauseAll() async {
        for download in activeDownloads {
            guard let gid = download.aria2Gid, download.status == .downloading else { continue }
            do {
                try await aria2.pause(gid: gid)
            } catch {}
        }
        await refresh()
    }

    func resumeAll() async {
        for download in activeDownloads {
            guard let gid = download.aria2Gid, download.status == .paused else { continue }
            do {
                try await aria2.resume(gid: gid)
            } catch {}
        }
        await refresh()
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(#selector(NSApplication.newWindowForTab(_:)), to: nil, from: nil)
        }
    }
}
