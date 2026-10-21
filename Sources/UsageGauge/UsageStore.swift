import Foundation
import UsageGaugeCore

/// Holds the latest usage and refreshes it off the main thread. A failed refresh keeps the
/// previous numbers on screen and surfaces the reason in the panel header instead.
@MainActor
final class UsageStore: ObservableObject {
    /// A refresh asked for (panel shown, Mac woken) is skipped when the data is newer than this.
    private static let freshness: TimeInterval = 60

    @Published private var fetched: [ProviderUsage] = []
    @Published private(set) var lastFetched: Date?
    @Published private(set) var lastError: UsageFetchError?
    @Published private(set) var now = Date()

    private let cli: CodexBarCLI?
    private var isFetching = false

    init(cli: CodexBarCLI? = .locate()) {
        self.cli = cli
    }

    /// Usage as it stands now: windows whose reset has passed already read as full.
    var providers: [ProviderUsage] {
        fetched.map { $0.resolved(at: now) }
    }

    /// When the numbers were measured — the oldest provider reading, since CodexBar may serve
    /// cached data — or why they could not be read.
    var statusText: String {
        if let lastError { return lastError.message }
        let measured = fetched.compactMap(\.measuredAt).min() ?? lastFetched
        guard let measured else { return "불러오는 중" }
        return "\(measured.formatted(date: .omitted, time: .shortened)) 기준"
    }

    func refresh() {
        guard !isFetching else { return }
        guard let cli else {
            lastError = .cliNotFound
            return
        }
        isFetching = true
        Task.detached(priority: .utility) {
            let result = Result { try cli.fetchUsage() }
            await self.apply(result)
        }
    }

    /// Refreshes unless the data is already fresh.
    func refreshIfStale() {
        if let lastFetched, Date().timeIntervalSince(lastFetched) < Self.freshness { return }
        refresh()
    }

    /// Advances the clock; when a window's reset has just passed, fetches the new numbers.
    func tick() {
        let previous = now
        now = Date()
        let resetPassed = fetched.contains { usage in
            usage.nextReset(after: previous).map { $0 <= now } ?? false
        }
        if resetPassed { refresh() }
    }

    private func apply(_ result: Result<[ProviderUsage], Error>) {
        isFetching = false
        now = Date()
        switch result {
        case .success(let usage):
            fetched = ProviderCatalog.merge(latest: usage, previous: fetched)
            lastFetched = now
            lastError = nil
        case .failure(let error):
            lastError = error as? UsageFetchError ?? .invalidOutput
        }
    }
}
