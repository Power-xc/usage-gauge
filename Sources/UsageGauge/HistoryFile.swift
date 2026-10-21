import Foundation
import UsageGaugeCore

/// The usage history on disk (provider ids, timestamps and percentages only). A missing file is an
/// empty history; an unreadable one is logged and replaced by the next save.
struct HistoryFile {
    let url: URL

    static let standard = HistoryFile(
        url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UsageGauge", isDirectory: true)
            .appendingPathComponent("history.json"))

    func load() -> UsageHistory {
        guard let data = try? Data(contentsOf: url) else { return UsageHistory() }
        do {
            return try JSONDecoder().decode(UsageHistory.self, from: data)
        } catch {
            NSLog("usage-gauge: ignoring unreadable history at \(url.path): \(error)")
            return UsageHistory()
        }
    }

    func save(_ history: UsageHistory) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(history).write(to: url, options: .atomic)
        } catch {
            NSLog("usage-gauge: could not save history to \(url.path): \(error)")
        }
    }
}
