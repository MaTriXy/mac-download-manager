import Foundation

final class Aria2ProcessManager {
    private var process: Process?

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func launch(
        secret: String,
        port: Int,
        downloadDir: String,
        maxConcurrent: Int
    ) throws {
        let binaryPath = Self.findBinary()
        guard let binaryPath else {
            throw Aria2Error.processNotRunning
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "--enable-rpc",
            "--rpc-listen-port=\(port)",
            "--rpc-listen-all=false",
            "--rpc-secret=\(secret)",
            "--continue=true",
            "--max-concurrent-downloads=\(maxConcurrent)",
            "--dir=\(downloadDir)",
            "--file-allocation=none",
            "--auto-file-renaming=false"
        ]
        process.standardOutput = nil
        process.standardError = nil

        try process.run()
        self.process = process
    }

    func terminate() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }

    private static func findBinary() -> String? {
        if let resourcePath = Bundle.main.resourcePath {
            let bundled = (resourcePath as NSString).appendingPathComponent("aria2c")
            if FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }

        let candidates = [
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c"
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
