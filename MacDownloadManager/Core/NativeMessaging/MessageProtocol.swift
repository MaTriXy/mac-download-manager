import Foundation

struct NativeMessage: Codable, Sendable {
    let url: String
    let headers: [String: String]?
    let filename: String?
    let fileSize: Int64?
    let referrer: String?
}

struct NativeResponse: Codable, Sendable {
    let accepted: Bool
    let error: String?
    let activeCount: Int?
}

struct StatusUpdate: Codable, Sendable {
    let type: String
    let activeCount: Int
    let globalSpeed: Int64
}
