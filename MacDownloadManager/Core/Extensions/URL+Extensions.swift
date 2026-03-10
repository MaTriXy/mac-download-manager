import Foundation

extension URL {
    var fileExtension: String {
        pathExtension.lowercased()
    }

    var suggestedFilename: String {
        let name = lastPathComponent
            .removingPercentEncoding ?? lastPathComponent

        if name.isEmpty || name == "/" {
            return "download"
        }

        return name
    }

    static var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }
}
