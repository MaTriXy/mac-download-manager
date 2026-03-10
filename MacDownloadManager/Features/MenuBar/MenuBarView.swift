import SwiftUI

struct MenuBarView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: MenuBarViewModel?

    var body: some View {
        Group {
            if let viewModel {
                menuBarContent(viewModel)
            } else {
                ProgressView()
                    .frame(width: 280, height: 100)
            }
        }
        .task {
            let vm = MenuBarViewModel(repository: container.repository, aria2: container.aria2Client)
            self.viewModel = vm
            await vm.refresh()
        }
    }

    private func menuBarContent(_ viewModel: MenuBarViewModel) -> some View {
        VStack(spacing: 0) {
            speedHeader(viewModel)

            Divider()

            if viewModel.activeDownloads.isEmpty {
                emptyState
            } else {
                downloadsList(viewModel)
            }

            Divider()

            footerButtons(viewModel)
        }
        .frame(width: 300)
    }

    private func speedHeader(_ viewModel: MenuBarViewModel) -> some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
            Text(formattedSpeed(viewModel.globalSpeed))
                .font(.headline)
            Spacer()
            Text("\(viewModel.activeDownloads.count) active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No active downloads")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func downloadsList(_ viewModel: MenuBarViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.activeDownloads) { item in
                    downloadRow(item)
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func downloadRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            ProgressView(value: item.progress)
                .progressViewStyle(.linear)

            HStack {
                Text(formattedSpeed(item.speed))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(item.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func footerButtons(_ viewModel: MenuBarViewModel) -> some View {
        VStack(spacing: 4) {
            if !viewModel.activeDownloads.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.pauseAll() }
                    } label: {
                        Label("Pause All", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        Task { await viewModel.resumeAll() }
                    } label: {
                        Label("Resume All", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            Button {
                viewModel.openMainWindow()
            } label: {
                Text("Open Mac Download Manager")
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func formattedSpeed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .file) + "/s"
    }
}
