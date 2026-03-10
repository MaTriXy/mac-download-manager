import Foundation

enum Aria2Error: Error, Sendable {
    case processNotRunning
    case connectionFailed(underlying: any Error)
    case invalidResponse(Data)
    case rpcError(code: Int, message: String)
    case requestFailed(statusCode: Int)
    case encodingFailed
}
