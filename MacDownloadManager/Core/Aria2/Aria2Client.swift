import Foundation

actor Aria2Client {
    private let baseURL: URL
    private let secret: String
    private let session: URLSession
    private var requestId: Int = 0

    init(port: Int, secret: String) {
        self.baseURL = URL(string: "http://localhost:\(port)/jsonrpc")!
        self.secret = secret
        self.session = URLSession(configuration: .ephemeral)
    }

    func addDownload(
        url: URL,
        headers: [String: String] = [:],
        dir: String,
        segments: Int = 16
    ) async throws(Aria2Error) -> String {
        var options: [String: String] = [
            "split": "\(segments)",
            "max-connection-per-server": "\(segments)",
            "dir": dir
        ]

        if let filename = extractFilename(from: url) {
            options["out"] = filename
        }

        var params: [AnyCodable] = [
            .string(tokenParam),
            .stringArray([url.absoluteString])
        ]

        if !headers.isEmpty {
            let headerStrings = headers.map { "\($0.key): \($0.value)" }
            options["header"] = headerStrings.joined(separator: "\n")
        }

        params.append(.dict(options))

        return try await call(method: "aria2.addUri", params: params)
    }

    func pause(gid: String) async throws(Aria2Error) {
        let _: String = try await call(
            method: "aria2.pause",
            params: [tokenParam, gid]
        )
    }

    func resume(gid: String) async throws(Aria2Error) {
        let _: String = try await call(
            method: "aria2.unpause",
            params: [tokenParam, gid]
        )
    }

    func remove(gid: String) async throws(Aria2Error) {
        let _: String = try await call(
            method: "aria2.remove",
            params: [tokenParam, gid]
        )
    }

    func forceRemove(gid: String) async throws(Aria2Error) {
        let _: String = try await call(
            method: "aria2.forceRemove",
            params: [tokenParam, gid]
        )
    }

    func tellActive() async throws(Aria2Error) -> [Aria2Status] {
        try await call(
            method: "aria2.tellActive",
            params: [tokenParam]
        )
    }

    func tellWaiting(offset: Int, count: Int) async throws(Aria2Error) -> [Aria2Status] {
        let params: [AnyCodable] = [.string(tokenParam), .int(offset), .int(count)]
        return try await call(method: "aria2.tellWaiting", params: params)
    }

    func tellStopped(offset: Int, count: Int) async throws(Aria2Error) -> [Aria2Status] {
        let params: [AnyCodable] = [.string(tokenParam), .int(offset), .int(count)]
        return try await call(method: "aria2.tellStopped", params: params)
    }

    func getGlobalStat() async throws(Aria2Error) -> Aria2GlobalStat {
        try await call(
            method: "aria2.getGlobalStat",
            params: [tokenParam]
        )
    }

    func changeGlobalOption(options: [String: String]) async throws(Aria2Error) {
        let params: [AnyCodable] = [.string(tokenParam), .dict(options)]
        let _: String = try await call(method: "aria2.changeGlobalOption", params: params)
    }

    // MARK: - Private

    private var tokenParam: String { "token:\(secret)" }

    private func nextRequestId() -> String {
        requestId += 1
        return "mac-dl-\(requestId)"
    }

    private func call<Params: Encodable, Result: Decodable>(
        method: String,
        params: Params
    ) async throws(Aria2Error) -> Result {
        let rpcRequest = Aria2Request(
            id: nextRequestId(),
            method: method,
            params: params
        )

        let body: Data
        do {
            body = try JSONEncoder().encode(rpcRequest)
        } catch {
            throw .encodingFailed
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .connectionFailed(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw .requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded: Aria2Response<Result>
        do {
            decoded = try JSONDecoder().decode(Aria2Response<Result>.self, from: data)
        } catch {
            throw .invalidResponse(data)
        }

        if let rpcError = decoded.error {
            throw .rpcError(code: rpcError.code, message: rpcError.message)
        }

        guard let result = decoded.result else {
            throw .invalidResponse(data)
        }

        return result
    }

    private func extractFilename(from url: URL) -> String? {
        let lastComponent = url.lastPathComponent
        guard !lastComponent.isEmpty, lastComponent != "/" else { return nil }
        return lastComponent
    }
}
