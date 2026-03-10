import SwiftUI

@Observable @MainActor
final class DependencyContainer {
    static var shared: DependencyContainer!

    let databaseManager: DatabaseManager
    let repository: any DownloadRepository
    let aria2Client: Aria2Client
    let processManager: Aria2ProcessManager
    let socketServer: SocketServer

    let aria2Secret: String
    let aria2Port: Int

    var activeDownloadCount: Int = 0

    var menuBarIcon: String {
        activeDownloadCount > 0 ? "arrow.down.circle.fill" : "arrow.down.circle"
    }

    init() {
        aria2Secret = UUID().uuidString
        aria2Port = 6800

        databaseManager = try! DatabaseManager()
        repository = GRDBDownloadRepository(dbQueue: databaseManager.dbQueue)

        aria2Client = Aria2Client(port: 6800, secret: aria2Secret)
        processManager = Aria2ProcessManager()
        socketServer = SocketServer()
    }

    init(inMemory: Bool) {
        aria2Secret = "test"
        aria2Port = 6800
        databaseManager = try! DatabaseManager(inMemory: true)
        repository = InMemoryDownloadRepository()
        aria2Client = Aria2Client(port: 6800, secret: "test")
        processManager = Aria2ProcessManager()
        socketServer = SocketServer()
    }
}
