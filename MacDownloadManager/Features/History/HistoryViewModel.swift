import Foundation

@Observable @MainActor
final class HistoryViewModel {
    private let repository: any DownloadRepository

    var records: [DownloadItem] = []
    var searchText = ""

    var filteredRecords: [DownloadItem] {
        guard !searchText.isEmpty else { return records }
        return records.filter {
            $0.filename.localizedCaseInsensitiveContains(searchText) ||
            $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }

    init(repository: any DownloadRepository) {
        self.repository = repository
    }

    func loadHistory() async {
        do {
            let downloadRecords = try await repository.fetchAll()
            records = downloadRecords.map { DownloadItem(record: $0) }
        } catch {
            records = []
        }
    }

    func deleteRecord(_ item: DownloadItem) async {
        do {
            try await repository.delete(id: item.id)
            records.removeAll { $0.id == item.id }
        } catch {
            await loadHistory()
        }
    }

    func clearHistory() async {
        do {
            for record in records where !record.isActive {
                try await repository.delete(id: record.id)
            }
            await loadHistory()
        } catch {
            await loadHistory()
        }
    }
}
