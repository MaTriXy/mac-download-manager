import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadRowView: View {
    let item: DownloadItem

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            fileIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.filename)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    statusBadge
                }

                if item.isActive {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                }

                HStack(spacing: 16) {
                    if let fileSize = item.fileSize, fileSize > 0 {
                        Text(formattedSize(downloaded: item.downloadedSize, total: fileSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if item.status == .downloading, item.speed > 0 {
                        Text("\(formattedBytes(item.speed))/s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let eta = item.eta, item.status == .downloading {
                        Text(formattedETA(eta))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if item.isActive {
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: some View {
        let ext = (item.filename as NSString).pathExtension
        let utType = UTType(filenameExtension: ext) ?? .data
        let icon = NSWorkspace.shared.icon(for: utType)
        return Image(nsImage: icon)
            .resizable()
            .frame(width: 32, height: 32)
    }

    private var statusBadge: some View {
        Text(statusLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var statusLabel: String {
        switch item.status {
        case .waiting: "Waiting"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Completed"
        case .error: "Error"
        case .removed: "Removed"
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }

    private func formattedSize(downloaded: Int64, total: Int64) -> String {
        "\(formattedBytes(downloaded)) / \(formattedBytes(total))"
    }

    private func formattedETA(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 {
            return "\(seconds)s remaining"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s remaining"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m remaining"
        }
    }
}
