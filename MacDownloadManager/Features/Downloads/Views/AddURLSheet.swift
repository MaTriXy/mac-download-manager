import AppKit
import SwiftUI

struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var headersText = ""
    @State private var downloadDirectory: String = UserDefaults.standard.string(forKey: "downloadDirectory")
        ?? URL.downloadsDirectory.path(percentEncoded: false)
    @State private var segments: Int = UserDefaults.standard.integer(forKey: "defaultSegments").clamped(to: 1...32, default: 16)
    @State private var validationError: String?

    let onSubmit: (URL, [String: String], String, Int) async -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("URL", text: $urlString, prompt: Text("https://example.com/file.zip"))
                        .textFieldStyle(.roundedBorder)

                    Button("Paste") {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Custom Headers (one per line: Name: Value)") {
                TextEditor(text: $headersText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
            }

            Section {
                HStack {
                    TextField("Download Directory", text: $downloadDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        chooseDirectory()
                    }
                    .buttonStyle(.bordered)
                }

                Stepper("Segments: \(segments)", value: $segments, in: 1...32)
            }

            if let error = validationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Download") { submit() }
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func submit() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" else {
            validationError = "Please enter a valid HTTP or HTTPS URL."
            return
        }

        let headers = parseHeaders(headersText)

        UserDefaults.standard.set(downloadDirectory, forKey: "downloadDirectory")
        UserDefaults.standard.set(segments, forKey: "defaultSegments")

        Task {
            await onSubmit(url, headers, downloadDirectory, segments)
            dismiss()
        }
    }

    private func parseHeaders(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let name = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    result[name] = value
                }
            }
        }
        return result
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: downloadDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url.path(percentEncoded: false)
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        self == 0 ? defaultValue : Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
