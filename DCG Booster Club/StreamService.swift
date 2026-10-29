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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: scheduledStart) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: scheduledStart)
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

    private var lastAttempt: Date?
    private let minimumRefreshInterval: TimeInterval = 60
    private let endpoint = URL(string: "https://dcgboosterclub.com/wp-json/dcg/v1/streams")!

    func loadStreams(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, let lastAttempt,
           Date().timeIntervalSince(lastAttempt) < minimumRefreshInterval { return }

        lastAttempt = Date()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            print("DCGTV HTTP Status: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("DCGTV server response: \(body)")
                throw NSError(domain: "DCGTV", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(httpResponse.statusCode)"])
            }

            let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
            streams = decoded.streams
                .filter { $0.isLive || $0.status.lowercased() == "upcoming" }
                .sorted { a, b in
                    if a.isLive != b.isLive { return a.isLive }
                    return (a.startDate ?? .distantFuture) < (b.startDate ?? .distantFuture)
                }
            replays = decoded.replays ?? []
            lastUpdated = Date()
            print("DCGTV: Loaded \(streams.count) broadcasts and \(replays.count) replays")
        } catch {
            let nsError = error as NSError
            if error is CancellationError ||
               (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) {
                print("DCGTV: Request cancelled")
                lastAttempt = nil
                return
            }
            errorMessage = error.localizedDescription
            print("DCGTV API Error: \(error)")
        }
    }

    func refreshKeepingRequestAlive(force: Bool = false) async {
        let requestTask = Task { await self.loadStreams(force: force) }
        await requestTask.value
    }
}
