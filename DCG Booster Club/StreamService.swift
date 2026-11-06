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
    private let fetch: @MainActor () async throws -> StreamResponse
    private let saveCache: @MainActor (StreamResponse) -> Void

    init(
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
        self.fetch = fetch
        self.saveCache = saveCache
        if let cached = loadCache() {
            apply(cached.value)
            lastUpdated = cached.savedAt
        }
    }

    func loadStreams(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, let lastAttempt,
           Date().timeIntervalSince(lastAttempt) < minimumRefreshInterval { return }

        lastAttempt = Date()
        isLoading = true
        // Keep the failure visible while retrying; only success restores confidence.
        defer { isLoading = false }

        do {
            let decoded = try await fetch()
            apply(decoded)
            lastUpdated = Date()
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
