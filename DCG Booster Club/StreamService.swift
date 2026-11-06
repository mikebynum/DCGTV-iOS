import Foundation
import Combine

struct DCGStream: Codable, Identifiable {
    let id: String
    let title: String
    let scheduledStart: String?
    let status: String
    let thumbnail: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, title, status, thumbnail, url
        case scheduledStart = "scheduled_start"
    }

    var startDate: Date? {
        guard let scheduledStart else { return nil }
        return DCGDateParsing.flexibleISO8601(scheduledStart)
    }

    var isLive: Bool { status.lowercased() == "live" }
}

struct StreamResponse: Codable {
    let channel: String
    let streams: [DCGStream]
    // Optional, so older WordPress responses remain compatible.
    let replays: [DCGStream]?
}

@MainActor
final class StreamService: ObservableObject {
    @Published private(set) var streams: [DCGStream] = []
    @Published private(set) var replays: [DCGStream] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isStatusCurrent = false

    private var lastAttempt: Date?
    private let minimumRefreshInterval: TimeInterval = 60
    private let maximumStatusAge: TimeInterval = 120
    private let now: @MainActor () -> Date
    private let sleep: @MainActor (TimeInterval) async throws -> Void
    private let fetch: @MainActor () async throws -> StreamResponse
    private let saveCache: @MainActor (StreamResponse) -> Void

    init(
        now: @escaping @MainActor () -> Date = { Date() },
        sleep: @escaping @MainActor (TimeInterval) async throws -> Void = {
            try await Task.sleep(for: .seconds($0))
        },
        loadCache: @MainActor () -> (value: StreamResponse, savedAt: Date)? = {
            DCGCache.load(StreamResponse.self, from: "streams.json")
        },
        saveCache: @escaping @MainActor (StreamResponse) -> Void = {
            DCGCache.save($0, as: "streams.json")
        },
        fetch: @escaping @MainActor () async throws -> StreamResponse = {
            guard let url = URL(string: "https://dcgboosterclub.com/wp-json/dcg/v1/streams") else {
                throw URLError(.badURL)
            }
            return try await DCGNetworking.fetchJSON(StreamResponse.self, from: url)
        }
    ) {
        self.now = now
        self.sleep = sleep
        self.fetch = fetch
        self.saveCache = saveCache
        if let cached = loadCache() {
            apply(cached.value)
            lastUpdated = cached.savedAt
        }
    }

    func loadStreams(force: Bool = false) async {
        expireStatusIfNeeded()
        guard !Task.isCancelled, !isLoading else { return }
        if !force, let lastAttempt {
            let elapsed = now().timeIntervalSince(lastAttempt)
            if elapsed >= 0 && elapsed < minimumRefreshInterval { return }
        }

        lastAttempt = now()
        isLoading = true
        // Keep the failure visible while retrying; only success restores confidence.
        defer { isLoading = false }

        do {
            let decoded = try await fetch()
            try Task.checkCancellation()
            apply(decoded)
            lastUpdated = now()
            errorMessage = nil
            isStatusCurrent = true
            saveCache(decoded)
            print("DCGTV: Loaded \(streams.count) broadcasts and \(replays.count) replays")
        } catch {
            if DCGNetworking.isCancellation(error) {
                print("DCGTV: Request cancelled")
                lastAttempt = nil
                return
            }
            isStatusCurrent = false
            errorMessage = error.localizedDescription
            print("DCGTV API Error: \(error)")
        }
    }

    // Called on activation as well as by the independent freshness task.
    // A clock correction must not make an old response appear fresh.
    func expireStatusIfNeeded() {
        guard isStatusCurrent, let lastUpdated else { return }
        let age = now().timeIntervalSince(lastUpdated)
        if age < 0 || age >= maximumStatusAge {
            isStatusCurrent = false
        }
    }

    // The caller owns this task's lifetime. Both children cancel when the
    // scene becomes inactive; automatic requests do not outlive that task.
    func refreshWhileActive() async {
        expireStatusIfNeeded()
        async let refreshes: Void = refreshPeriodically()
        async let freshness: Void = monitorFreshness()
        _ = await (refreshes, freshness)
    }

    private func refreshPeriodically() async {
        while !Task.isCancelled {
            await loadStreams()
            do {
                try await sleep(minimumRefreshInterval)
            } catch {
                return
            }
        }
    }

    private func monitorFreshness() async {
        while !Task.isCancelled {
            expireStatusIfNeeded()
            let delay: TimeInterval
            if isStatusCurrent, let lastUpdated {
                delay = max(1, maximumStatusAge - now().timeIntervalSince(lastUpdated))
            } else {
                delay = maximumStatusAge
            }
            do {
                try await sleep(delay)
            } catch {
                return
            }
        }
    }

    private func apply(_ decoded: StreamResponse) {
        streams = decoded.streams
            .filter { $0.isLive || $0.status.lowercased() == "upcoming" }
            .sorted { a, b in
                if a.isLive != b.isLive { return a.isLive }
                return (a.startDate ?? .distantFuture) < (b.startDate ?? .distantFuture)
            }
        replays = decoded.replays ?? []
    }

    func refreshKeepingRequestAlive(force: Bool = false) async {
        let requestTask = Task { await self.loadStreams(force: force) }
        await requestTask.value
    }
}
