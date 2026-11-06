import Foundation
import Testing
@testable import DCG_Booster_Club

@MainActor
struct DCG_Booster_ClubTests {
    private var response: StreamResponse {
        StreamResponse(channel: "DCGTV", streams: [
            DCGStream(id: "live", title: "Mustang game", scheduledStart: nil,
                      status: "live", thumbnail: "", url: "https://www.youtube.com/watch?v=test")
        ], replays: [])
    }

    @Test func cachedLiveBroadcastIsUnverifiedAndSurvivesFailure() async {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let cached = response
        let service = StreamService(
            loadCache: { (cached, savedAt) },
            saveCache: { _ in Issue.record("Failed refresh must not overwrite cache") },
            fetch: { throw URLError(.notConnectedToInternet) }
        )

        #expect(service.streams.first?.isLive == true)
        #expect(!service.isStatusCurrent)
        await service.loadStreams()

        #expect(service.streams.first?.id == "live")
        #expect(service.lastUpdated == savedAt)
        #expect(!service.isStatusCurrent)
        #expect(service.errorMessage != nil)
        #expect(!service.isLoading)
    }

    @Test func failureWithoutCacheIsNotAConfirmedEmptySchedule() async {
        let service = StreamService(
            loadCache: { nil }, saveCache: { _ in },
            fetch: { throw URLError(.notConnectedToInternet) }
        )
        await service.loadStreams()

        #expect(service.streams.isEmpty)
        #expect(service.lastUpdated == nil)
        #expect(!service.isStatusCurrent)
        #expect(service.errorMessage != nil)
        #expect(!service.isLoading)
    }

    @Test func explicitRetryBypassesThrottleAndRestoresCurrentStatus() async {
        var attempts = 0
        var saved: StreamResponse?
        let fresh = response
        let service = StreamService(
            loadCache: { nil }, saveCache: { saved = $0 },
            fetch: {
                attempts += 1
                if attempts == 1 { throw URLError(.timedOut) }
                return fresh
            }
        )
        await service.loadStreams()
        await service.loadStreams()
        #expect(attempts == 1)

        await service.loadStreams(force: true)
        #expect(attempts == 2)
        #expect(service.isStatusCurrent)
        #expect(service.errorMessage == nil)
        #expect(service.lastUpdated != nil)
        #expect(saved?.streams.first?.id == "live")
    }

    @Test func successfulEmptyResponseIsAConfirmedEmptySchedule() async {
        let service = StreamService(
            loadCache: { nil }, saveCache: { _ in },
            fetch: { StreamResponse(channel: "DCGTV", streams: [], replays: []) }
        )
        await service.loadStreams()

        #expect(service.streams.isEmpty)
        #expect(service.isStatusCurrent)
        #expect(service.errorMessage == nil)
        #expect(service.lastUpdated != nil)
    }

    @Test func failedRefreshInvalidatesPreviouslyCurrentStatus() async {
        var attempts = 0
        let fresh = response
        let service = StreamService(
            loadCache: { nil }, saveCache: { _ in },
            fetch: {
                attempts += 1
                if attempts > 1 { throw URLError(.timedOut) }
                return fresh
            }
        )
        await service.loadStreams()
        let lastSuccess = service.lastUpdated
        #expect(service.isStatusCurrent)

        await service.loadStreams(force: true)
        #expect(!service.isStatusCurrent)
        #expect(service.streams.first?.id == "live")
        #expect(service.lastUpdated == lastSuccess)
        #expect(service.errorMessage != nil)
    }

    @Test func cancelledRetryPreservesFailureAndAllowsAnotherAttempt() async {
        var attempts = 0
        let fresh = response
        let service = StreamService(
            loadCache: { nil }, saveCache: { _ in },
            fetch: {
                attempts += 1
                if attempts == 1 { throw URLError(.notConnectedToInternet) }
                if attempts == 2 { throw CancellationError() }
                return fresh
            }
        )
        await service.loadStreams()
        await service.loadStreams(force: true)
        #expect(service.errorMessage != nil)
        #expect(!service.isStatusCurrent)
        #expect(!service.isLoading)

        await service.loadStreams()
        #expect(attempts == 3)
        #expect(service.isStatusCurrent)
        #expect(service.errorMessage == nil)
    }
}
