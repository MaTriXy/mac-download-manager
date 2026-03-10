import Foundation

final class SocketServer: Sendable {
    private struct State: Sendable {
        var serverFD: Int32 = -1
        var clientFDs: Set<Int32> = []
        var isRunning = false
        var socketPath: String = ""
    }

    private let state = LockedValue(State())
    private let onMessageHandler = LockedValue<(@Sendable (NativeMessage) async -> NativeResponse)?>(nil)

    var onMessage: (@Sendable (NativeMessage) async -> NativeResponse)? {
        get { onMessageHandler.withLock { $0 } }
        set { onMessageHandler.withLock { $0 = newValue } }
    }

    func start(socketPath: String) throws {
        stop()

        unlink(socketPath)

        let dir = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketError.createFailed(errno: errno)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_len) + MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw SocketError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(104)) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw SocketError.bindFailed(errno: errno)
        }

        guard listen(fd, 8) == 0 else {
            close(fd)
            throw SocketError.listenFailed(errno: errno)
        }

        state.withLock {
            $0.serverFD = fd
            $0.isRunning = true
            $0.socketPath = socketPath
        }

        Task.detached { [weak self] in
            self?.acceptLoop(serverFD: fd)
        }
    }

    func stop() {
        state.withLock { s in
            if s.serverFD >= 0 {
                close(s.serverFD)
            }
            for clientFD in s.clientFDs {
                close(clientFD)
            }
            if !s.socketPath.isEmpty {
                unlink(s.socketPath)
            }
            s.serverFD = -1
            s.clientFDs.removeAll()
            s.isRunning = false
        }
    }

    func broadcast(_ message: StatusUpdate) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let frame = lengthPrefixedFrame(data)

        let clients = state.withLock { $0.clientFDs }
        for clientFD in clients {
            frame.withUnsafeBytes { ptr in
                var offset = 0
                while offset < ptr.count {
                    let n = send(clientFD, ptr.baseAddress! + offset, ptr.count - offset, MSG_NOSIGNAL)
                    if n <= 0 { break }
                    offset += n
                }
            }
        }
    }

    private func acceptLoop(serverFD: Int32) {
        while state.withLock({ $0.isRunning }) {
            var clientAddr = sockaddr_un()
            var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverFD, sockaddrPtr, &addrLen)
                }
            }

            guard clientFD >= 0 else { break }

            _ = state.withLock { $0.clientFDs.insert(clientFD) }

            Task.detached { [weak self] in
                await self?.handleClient(clientFD: clientFD)
            }
        }
    }

    private func handleClient(clientFD: Int32) async {
        defer {
            close(clientFD)
            _ = state.withLock { $0.clientFDs.remove(clientFD) }
        }

        while state.withLock({ $0.isRunning }) {
            guard let data = readFrame(from: clientFD) else { break }

            guard let message = try? JSONDecoder().decode(NativeMessage.self, from: data) else {
                let errorResponse = NativeResponse(accepted: false, error: "Invalid message format", activeCount: nil)
                if let responseData = try? JSONEncoder().encode(errorResponse) {
                    writeFrame(responseData, to: clientFD)
                }
                continue
            }

            let handler = onMessageHandler.withLock { $0 }
            let response: NativeResponse
            if let handler {
                response = await handler(message)
            } else {
                response = NativeResponse(accepted: false, error: "No handler registered", activeCount: nil)
            }

            if let responseData = try? JSONEncoder().encode(response) {
                writeFrame(responseData, to: clientFD)
            }
        }
    }

    private func readFrame(from fd: Int32) -> Data? {
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        guard readExact(fd: fd, buffer: &lengthBytes, count: 4) else { return nil }

        let length = Int(UInt32(bigEndian: lengthBytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        }))

        guard length > 0, length < 10_000_000 else { return nil }

        var payload = [UInt8](repeating: 0, count: length)
        guard readExact(fd: fd, buffer: &payload, count: length) else { return nil }

        return Data(payload)
    }

    private func writeFrame(_ data: Data, to fd: Int32) {
        let frame = lengthPrefixedFrame(data)
        frame.withUnsafeBytes { ptr in
            var offset = 0
            while offset < ptr.count {
                let n = send(fd, ptr.baseAddress! + offset, ptr.count - offset, MSG_NOSIGNAL)
                if n <= 0 { break }
                offset += n
            }
        }
    }

    private func readExact(fd: Int32, buffer: inout [UInt8], count: Int) -> Bool {
        buffer.withUnsafeMutableBytes { ptr in
            var offset = 0
            while offset < count {
                let n = recv(fd, ptr.baseAddress! + offset, count - offset, 0)
                if n <= 0 { return false }
                offset += n
            }
            return true
        }
    }

    private func lengthPrefixedFrame(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(data)
        return frame
    }
}

private let MSG_NOSIGNAL: Int32 = 0

enum SocketError: Error {
    case createFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case pathTooLong
}

final class LockedValue<Value: Sendable>: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
