import SwiftUI

struct DownloadListView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: DownloadListViewModel?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .task {
            let vm = DownloadListViewModel(
                repository: container.repository,
                aria2: container.aria2Client
            )
            viewModel = vm
            await vm.loadDownloads()
        }
        .task(id: "polling") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await viewModel?.updateFromAria2()
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isAddURLPresented ?? false },
            set: { viewModel?.isAddURLPresented = $0 }
        )) {
            if let vm = viewModel {
                AddURLSheet { url, headers, directory, segments in
                    await vm.addDownload(
                        url: url,
                        headers: headers,
                        directory: directory,
                        segments: segments
                    )
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel?.errorMessage != nil },
                set: { if !$0 { viewModel?.errorMessage = nil } }
            ),
            presenting: viewModel?.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "Download Already Exists",
            isPresented: Binding(
                get: { viewModel?.pendingDuplicate != nil },
                set: { if !$0 { viewModel?.cancelDuplicate() } }
            ),
            presenting: viewModel?.pendingDuplicate
        ) { _ in
            Button("Skip", role: .cancel) { viewModel?.cancelDuplicate() }
            Button("Download") { viewModel?.confirmDuplicate() }
        } message: { item in
            Text(duplicateMessage(for: item))
        }
    }

    private var sidebar: some View {
        List(FilterOption.allCases, id: \.self, selection: Binding(
            get: { viewModel?.filterOption ?? .active },
            set: { viewModel?.filterOption = $0 }
        )) { option in
            Label(option.displayName, systemImage: iconForFilter(option))
        }
        .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detail: some View {
        if let vm = viewModel {
            downloadList(vm: vm)
                .navigationTitle(vm.filterOption.displayName)
                .toolbar { toolbarContent(vm: vm) }
                .searchable(text: Binding(
                    get: { vm.searchText },
                    set: { vm.searchText = $0 }
                ), prompt: "Search downloads")
        }
    }

    @ViewBuilder
    private func downloadList(vm: DownloadListViewModel) -> some View {
        let items = vm.filteredDownloads
        if items.isEmpty {
            ContentUnavailableView {
                Label("No Downloads", systemImage: "arrow.down.circle")
            } description: {
                Text(vm.searchText.isEmpty
                     ? "Downloads will appear here when you start one."
                     : "No downloads match your search.")
            } actions: {
                if vm.searchText.isEmpty {
                    Button("Add URL") { vm.isAddURLPresented = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        } else {
            List(selection: Binding(
                get: { vm.selectedDownloadIDs },
                set: { vm.selectedDownloadIDs = $0 }
            )) {
                ForEach(items) { item in
                    DownloadRowView(item: item)
                        .tag(item.id)
                        .contextMenu { contextMenu(vm: vm, item: item) }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    @ViewBuilder
    private func contextMenu(vm: DownloadListViewModel, item: DownloadItem) -> some View {
        switch item.status {
        case .downloading, .waiting:
            Button("Pause") { Task { await vm.pauseDownload(item) } }
        case .paused:
            Button("Resume") { Task { await vm.resumeDownload(item) } }
        default:
            EmptyView()
        }

        Divider()

        Button("Remove", role: .destructive) { Task { await vm.removeDownload(item) } }

        if item.status == .completed {
            Button("Reveal in Finder") { vm.revealInFinder(item) }
        }

        Divider()

        Button("Copy URL") { vm.copyURL(item) }
    }

    @ToolbarContentBuilder
    private func toolbarContent(vm: DownloadListViewModel) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                vm.isAddURLPresented = true
            } label: {
                Label("Add URL", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            if let selected = selectedItem(vm: vm) {
                switch selected.status {
                case .downloading, .waiting:
                    Button {
                        Task { await vm.pauseDownload(selected) }
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                case .paused:
                    Button {
                        Task { await vm.resumeDownload(selected) }
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                default:
                    EmptyView()
                }
            }

            Button {
                guard let selected = selectedItem(vm: vm) else { return }
                Task { await vm.removeDownload(selected) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(selectedItem(vm: vm) == nil)

            if let selected = selectedItem(vm: vm), selected.status == .completed {
                Button {
                    vm.revealInFinder(selected)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
    }

    private func selectedItem(vm: DownloadListViewModel) -> DownloadItem? {
        guard let id = vm.selectedDownloadIDs.first, vm.selectedDownloadIDs.count == 1 else {
            return nil
        }
        return vm.filteredDownloads.first { $0.id == id }
    }

    private func duplicateMessage(for item: DownloadItem) -> String {
        var lines: [String] = []
        let urlString = item.url.absoluteString
        lines.append(urlString.count > 80 ? String(urlString.prefix(77)) + "..." : urlString)
        if let path = item.filePath {
            lines.append("Location: \(path)")
        }
        if let size = item.fileSize, size > 0 {
            lines.append("Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        }
        lines.append("Added: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
        return lines.joined(separator: "\n")
    }

    private func iconForFilter(_ option: FilterOption) -> String {
        switch option {
        case .active: "arrow.down.circle"
        case .completed: "checkmark.circle"
        case .all: "list.bullet"
        }
    }
}
