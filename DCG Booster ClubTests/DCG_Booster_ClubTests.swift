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

    @Test func liveStatusExpiresAtTwoMinutesAndRefreshRestoresIt() async {
        var now = Date(timeIntervalSince1970: 1_000)
        let fresh = response
        let service = StreamService(
            now: { now }, loadCache: { nil }, saveCache: { _ in },
            fetch: { fresh }
        )
        await service.loadStreams()
        now += 119
        service.expireStatusIfNeeded()
        #expect(service.isStatusCurrent)

        now += 1
        service.expireStatusIfNeeded()
        #expect(!service.isStatusCurrent)
        #expect(service.streams.first?.id == "live")
        #expect(service.errorMessage == nil)

        await service.loadStreams()
        #expect(service.isStatusCurrent)
        #expect(service.lastUpdated == now)
    }

    @Test func clockMovingBackwardInvalidatesStatus() async {
        var now = Date(timeIntervalSince1970: 1_000)
        let fresh = response
        let service = StreamService(
            now: { now }, loadCache: { nil }, saveCache: { _ in },
            fetch: { fresh }
        )
        await service.loadStreams()
        now -= 1
        service.expireStatusIfNeeded()
        #expect(!service.isStatusCurrent)
        await service.loadStreams()
        #expect(service.isStatusCurrent)
    }

    @Test func activeLoopRetriesAfterOneMinuteAndRecovers() async {
        var now = Date(timeIntervalSince1970: 1_000)
        var attempts = 0
        var refreshSleeps = 0
        let fresh = response
        let service = StreamService(
            now: { now },
            sleep: { delay in
                // Advance one polling interval, then end both test loops.
                guard delay == 60 else { throw CancellationError() }
                refreshSleeps += 1
                guard refreshSleeps == 1 else { throw CancellationError() }
                now += delay
            },
            loadCache: { nil }, saveCache: { _ in },
            fetch: {
                attempts += 1
                if attempts == 1 { throw URLError(.notConnectedToInternet) }
                return fresh
            }
        )
        await service.refreshWhileActive()
        #expect(attempts == 2)
        #expect(refreshSleeps == 2)
        #expect(service.isStatusCurrent)
        #expect(service.errorMessage == nil)
    }

    @Test func freshnessExpiresEvenWhileRefreshIsSuspended() async {
        var now = Date(timeIntervalSince1970: 1_000)
        let fresh = response
        let started = AsyncStream<Void>.makeStream()
        var pendingFetch: CheckedContinuation<StreamResponse, Error>?
        var attempts = 0
        var expirySleeps = 0
        var service: StreamService?
        let subject = StreamService(
            now: { now },
            sleep: { delay in
                guard delay != 60 else { throw CancellationError() }
                expirySleeps += 1
                if expirySleeps == 1 {
                    // Wait until the network request is suspended.
                    for await _ in started.stream { break }
                    await service?.loadStreams(force: true)
                    #expect(attempts == 2)
                    now += delay
                } else {
                    #expect(service?.isLoading == true)
                    #expect(service?.isStatusCurrent == false)
                    pendingFetch?.resume(throwing: CancellationError())
                    pendingFetch = nil
                    throw CancellationError()
                }
            },
            loadCache: { nil }, saveCache: { _ in },
            fetch: {
                attempts += 1
                if attempts == 1 { return fresh }
                return try await withCheckedThrowingContinuation { continuation in
                    pendingFetch = continuation
                    started.continuation.yield(())
                }
            }
        )
        service = subject
        await subject.loadStreams()
        now += 61
        await subject.refreshWhileActive()
        #expect(expirySleeps == 2)
        #expect(!subject.isStatusCurrent)
        #expect(subject.streams.first?.id == "live")
        #expect(!subject.isLoading)
        started.continuation.finish()
    }

    @Test func cancellingActiveLoopStopsBothSleeps() async {
        let sleeping = AsyncStream<Void>.makeStream()
        var attempts = 0
        var cancelledSleeps = 0
        let fresh = response
        let service = StreamService(
            sleep: { _ in
                sleeping.continuation.yield(())
                do {
                    try await Task.sleep(for: .seconds(3_600))
                } catch {
                    cancelledSleeps += 1
                    throw error
                }
            },
            loadCache: { nil }, saveCache: { _ in },
            fetch: { attempts += 1; return fresh }
        )
        let task = Task { await service.refreshWhileActive() }
        var count = 0
        for await _ in sleeping.stream {
            count += 1
            if count == 2 { break }
        }
        task.cancel()
        await task.value
        #expect(attempts == 1)
        #expect(cancelledSleeps == 2)
        sleeping.continuation.finish()
    }

    @Test func cancelledFetchCannotPublishLateSuccess() async {
        let started = AsyncStream<Void>.makeStream()
        var pendingFetch: CheckedContinuation<StreamResponse, Never>?
        var saves = 0
        let fresh = response
        let service = StreamService(
            loadCache: { nil }, saveCache: { _ in saves += 1 },
            fetch: {
                await withCheckedContinuation { continuation in
                    pendingFetch = continuation
                    started.continuation.yield(())
                }
            }
        )
        let task = Task { await service.loadStreams() }
        for await _ in started.stream { break }
        task.cancel()
        pendingFetch?.resume(returning: fresh)
        await task.value

        #expect(!service.isStatusCurrent)
        #expect(service.lastUpdated == nil)
        #expect(service.streams.isEmpty)
        #expect(service.errorMessage == nil)
        #expect(saves == 0)
        started.continuation.finish()
    }
}


struct DCGScheduleFilterTests {
    private func game(_ id: String, sport: String = "Football", level: String = "Varsity", start: String) -> DCGGame {
        DCGGame(id: id, title: "Football: DCG vs Valley (Varsity)", sport: sport,
                level: level, start: start, location: nil, status: nil, url: nil, externalStream: nil)
    }

    @Test func selectionsKeepTodayAndUndatedAndRespectFavorites() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = DCGDateParsing.flexibleISO8601("2026-11-10T18:00:00Z")!
        let games = [
            game("past", start: "2026-11-09T23:00:00Z"),
            game("today", start: "2026-11-10T08:00:00Z"),
            game("future", sport: "Wrestling", start: "2026-11-11T20:00:00Z"),
            game("undated", start: "invalid")
        ]
        func ids(_ selection: DCGScheduleSelection, favorites: Set<String> = []) -> [String] {
            DCGScheduleFilter.games(games, selection: selection, favorites: favorites,
                                    sport: "All Sports", level: "All Levels", query: "",
                                    now: now, calendar: calendar).map(\.id)
        }
        #expect(ids(.upcoming) == ["today", "future", "undated"])
        #expect(ids(.starred).isEmpty)
        #expect(ids(.starred, favorites: ["Football"]) == ["today", "undated"])
        #expect(ids(.allSports) == ["past", "today", "future", "undated"])
    }

    @Test func sportLevelAndTrimmedSearchIntersect() {
        let games = [game("varsity", start: "2026-11-10T20:00:00Z"),
                     game("jv", level: "JV", start: "2026-11-10T18:00:00Z")]
        let filtered = DCGScheduleFilter.games(games, selection: .allSports, favorites: [],
                                               sport: "Football", level: "Varsity", query: "  vAlLeY  ")
        #expect(filtered.map(\.id) == ["varsity"])
        #expect(DCGScheduleFilter.games(games, selection: .allSports, favorites: [],
                                        sport: "Wrestling", level: "All Levels", query: "").isEmpty)
    }
}
