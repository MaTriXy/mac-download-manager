import SwiftUI

struct HistoryView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: HistoryViewModel?
    @State private var showClearConfirmation = false
    @State private var selection: DownloadItem.ID?

    var body: some View {
        Group {
            if let viewModel {
                historyContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = HistoryViewModel(repository: container.repository)
            self.viewModel = vm
            await vm.loadHistory()
        }
    }

    @ViewBuilder
    private func historyContent(_ viewModel: HistoryViewModel) -> some View {
        @Bindable var vm = viewModel
        Group {
            if viewModel.filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(viewModel.searchText.isEmpty
                        ? "Completed downloads will appear here."
                        : "No results for \"\(viewModel.searchText)\".")
                )
            } else {
                Table(viewModel.filteredRecords, selection: $selection) {
                    TableColumn("Filename") { item in
                        HStack(spacing: 6) {
                            Image(systemName: iconForStatus(item.status))
                                .foregroundStyle(colorForStatus(item.status))
                            Text(item.filename)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 200)

                    TableColumn("Size") { item in
                        Text(formattedSize(item.fileSize))
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Date") { item in
                        Text(formattedDate(item.completedAt ?? item.createdAt))
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Status") { item in
                        Text(item.status.rawValue.capitalized)
                    }
                    .width(min: 80, ideal: 100)
                }
                .contextMenu(forSelectionType: DownloadItem.ID.self) { ids in
                    if let id = ids.first,
                       let item = viewModel.filteredRecords.first(where: { $0.id == id }) {
                        contextMenuItems(for: item, viewModel: viewModel)
                    }
                } primaryAction: { _ in }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search history")
        .toolbar { toolbarContent(viewModel) }
    }

    @ViewBuilder
    private func contextMenuItems(for item: DownloadItem, viewModel: HistoryViewModel) -> some View {
        if let filePath = item.filePath {
            Button {
                NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
        } label: {
            Label("Copy URL", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            Task { await viewModel.deleteRecord(item) }
        } label: {
            Label("Delete from History", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(_ viewModel: HistoryViewModel) -> some ToolbarContent {
        @Bindable var vm = viewModel
        ToolbarItem(placement: .automatic) {
            Button {
                showClearConfirmation = true
            } label: {
                Label("Clear History", systemImage: "trash")
            }
            .disabled(viewModel.records.isEmpty)
            .alert("Clear History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    Task { await viewModel.clearHistory() }
                }
            } message: {
                Text("This will remove all non-active downloads from history. This action cannot be undone.")
            }
        }
    }

    private func iconForStatus(_ status: DownloadStatus) -> String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .downloading: "arrow.down.circle.fill"
        case .paused: "pause.circle.fill"
        case .waiting: "clock.fill"
        case .removed: "xmark.circle.fill"
        }
    }

    private func colorForStatus(_ status: DownloadStatus) -> Color {
        switch status {
        case .completed: .green
        case .error: .red
        case .downloading: .blue
        case .paused: .orange
        case .waiting: .secondary
        case .removed: .secondary
        }
    }

    private func formattedSize(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
