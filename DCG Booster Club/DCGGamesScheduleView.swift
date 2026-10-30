import SwiftUI
import Combine

// MARK: - Game Model

struct DCGGame: Decodable, Identifiable {

    let id: String
    let title: String
    let sport: String
    let level: String
    let start: String
    let location: String?
    let status: String?
    let url: String?

    var displayTitle: String {
        // Remove the sport label and trailing "(Varsity)" from Bound summaries.
        let parts = title.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let event = String(parts.count == 2 ? parts[1] : parts[0])
            .replacingOccurrences(
                of: #"\s*\([^)]*\)\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if event.isEmpty {
            return "\(sport) Event"
        }
        return event.replacingOccurrences(
            of: "Dallas Center-Grimes",
            with: "DCG",
            options: .caseInsensitive
        )
    }

    var startDate: Date? {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: start) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: start)
    }
}

// MARK: - API Response

private struct DCGGamesResponse: Decodable {
    let games: [DCGGame]
}

// MARK: - Games Service

@MainActor
final class DCGGamesService: ObservableObject {

    @Published var games: [DCGGame] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let endpoint = URL(
        string: "https://dcgboosterclub.com/wp-json/dcg/v1/games"
    )!

    func refresh() async {

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(
                DCGGamesResponse.self,
                from: data
            )

            games = decoded.games.sorted {
                ($0.startDate ?? .distantFuture) <
                ($1.startDate ?? .distantFuture)
            }

            print("DCG Games: Loaded \(games.count) events")

        } catch {
            let nsError = error as NSError

            if error is CancellationError ||
                (nsError.domain == NSURLErrorDomain &&
                 nsError.code == NSURLErrorCancelled) {
                return
            }

            errorMessage = error.localizedDescription
            print("DCG Games Error: \(error)")
        }
    }

    func refreshKeepingRequestAlive() async {
        let task = Task {
            await self.refresh()
        }

        await task.value
    }
}

// MARK: - Native Games Schedule

struct DCGGamesScheduleView: View {

    @ObservedObject var service: DCGGamesService
    @ObservedObject var streams: StreamService

    @State private var selectedSport = "All Sports"
    @State private var selectedLevel = "All Levels"

    private struct GameDay: Identifiable {
        let date: Date
        let games: [DCGGame]
        var id: Date { date }
    }

    private var sports: [String] {
        ["All Sports"] + Set(service.games.map(\.sport)).sorted()
    }

    private var levels: [String] {
        ["All Levels"] + Set(service.games.map(\.level)).sorted()
    }

    private var filteredGames: [DCGGame] {
        service.games.filter { game in
            (selectedSport == "All Sports" || game.sport == selectedSport) &&
            (selectedLevel == "All Levels" || game.level == selectedLevel)
        }
    }

    private var groupedGames: [GameDay] {
        let valid = filteredGames.compactMap { game -> (Date, DCGGame)? in
            guard let date = game.startDate else { return nil }
            return (Calendar.current.startOfDay(for: date), game)
        }
        let groups = Dictionary(grouping: valid, by: { $0.0 })
        return groups.keys.sorted().map { date in
            GameDay(
                date: date,
                games: (groups[date] ?? []).map { $0.1 }.sorted {
                    ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
                }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mustang Athletics")
                    .font(.title2.bold())
                Text("Upcoming DCG games and events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Menus remain usable when a calendar has dozens of sports and levels.
            HStack(spacing: 10) {
                Menu {
                    Picker("Sport", selection: $selectedSport) {
                        ForEach(sports, id: \.self) { sport in
                            Text(sport).tag(sport)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sportscourt")
                        Text(selectedSport)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.dcgRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }

                Menu {
                    Picker("Level", selection: $selectedLevel) {
                        ForEach(levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedLevel)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.dcgRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }

            if selectedSport != "All Sports" || selectedLevel != "All Levels" {
                Button("Clear filters") {
                    selectedSport = "All Sports"
                    selectedLevel = "All Levels"
                }
                .font(.caption.bold())
                .tint(Color.dcgRed)
            }

            if service.isLoading && service.games.isEmpty {
                ProgressView("Loading Mustang schedule...")
                    .frame(maxWidth: .infinity)
                    .padding(30)
            } else if service.games.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No games available")
                        .font(.headline)
                    if let error = service.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Try Again") {
                        Task { await service.refreshKeepingRequestAlive() }
                    }
                    .tint(Color.dcgRed)
                }
                .padding(20)
            } else {
                Text("\(filteredGames.count) upcoming events")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if filteredGames.isEmpty {
                    Text("No games match your filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedGames) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(
                                        group.date,
                                        format: .dateTime
                                            .weekday(.wide)
                                            .month(.abbreviated)
                                            .day()
                                    )
                                    .font(.headline)

                                    Spacer()

                                    Text("\(group.games.count) \(group.games.count == 1 ? "event" : "events")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)

                                ForEach(group.games) { game in
                                    DCGGameCard(
                                        game: game,
                                        stream: DCGGameStreamMatcher.matchedStream(
                                            for: game,
                                            in: service.games,
                                            broadcasts: streams.streams
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if let error = service.errorMessage, !service.games.isEmpty {
                Text("Couldn't refresh: \(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Link(
                "View Full Schedule on Bound",
                destination: URL(
                    string: "https://www.gobound.com/ia/schools/dallascentergrimes"
                )!
            )
            .font(.subheadline.bold())
            .foregroundStyle(Color.dcgRed)
            .padding(.vertical, 10)
        }
        .task {
            await service.refreshKeepingRequestAlive()
        }
    }
}

// MARK: - Individual Game Card

struct DCGGameCard: View {

    let game: DCGGame
    let stream: DCGStream?

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Label(
                    game.sport,
                    systemImage: "sportscourt.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(Color.dcgRed)

                Spacer()

                Text(game.level)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(game.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if let date = game.startDate {

                Label {
                    Text(
                        date,
                        format: .dateTime
                            .weekday(.wide)
                            .month(.abbreviated)
                            .day()
                            .hour()
                            .minute()
                    )
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let location = game.location,
               !location.isEmpty {

                Label(
                    location,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let status = game.status,
               status.uppercased() != "CONFIRMED" {

                Text(status.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            // Only display a broadcast button for a unique, verified match.
            if let stream,
               let streamURL = URL(string: stream.url),
               streamURL.scheme?.lowercased() == "https" {

                Link(destination: streamURL) {
                    Label(
                        stream.isLive ? "LIVE — Watch on DCGTV" : "Watch on DCGTV",
                        systemImage: "play.rectangle.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(stream.isLive ? Color.red : Color.dcgRed)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if let urlString = game.url,
               let url = URL(string: urlString),
               url.scheme == "https" {

                Link(destination: url) {

                    HStack {

                        Text("Game Details")

                        Spacer()

                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.dcgRed)
                }
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

// Shared between Home and Schedule so both tabs follow the same matching rules.
enum DCGGameStreamMatcher {
    // Match only when the sport, opponent and start time agree. Ambiguous
    // matches are deliberately skipped rather than linking the wrong game.
    static func matchedStream(for game: DCGGame, in games: [DCGGame], broadcasts: [DCGStream]) -> DCGStream? {
        let candidates = broadcasts.filter { matches(game: game, stream: $0) }
        guard candidates.count == 1, let candidate = candidates.first else { return nil }

        // The same broadcast must not be attached to several Bound events
        // (for example, JV and varsity games against the same school).
        let matchingGames = games.filter { matches(game: $0, stream: candidate) }
        return matchingGames.count == 1 ? candidate : nil
    }

    private static func matches(game: DCGGame, stream: DCGStream) -> Bool {
        guard let gameDate = game.startDate,
              let streamDate = stream.startDate,
              abs(gameDate.timeIntervalSince(streamDate)) <= 3 * 60 * 60,
              let opponent = opponentName(from: game.title)
        else { return false }

        let title = normalized(stream.title)
        let team = normalized(opponent)
        let sport = normalized(game.sport)
        let coreSport = sport
            .replacingOccurrences(of: "boys ", with: "")
            .replacingOccurrences(of: "girls ", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard team.count >= 4,
              title.contains(team),
              !coreSport.isEmpty,
              title.contains(coreSport)
        else { return false }

        // Never attach a girls game to a boys broadcast or vice versa.
        if sport.hasPrefix("boys ") && title.contains("girls ") { return false }
        if sport.hasPrefix("girls ") && title.contains("boys ") { return false }

        // A titled varsity stream must not attach to a JV or freshman game.
        let level = normalized(game.level)
        if title.contains("varsity") && level != "varsity" { return false }
        if (title.contains("junior varsity") || title.contains(" jv ")) &&
            level == "varsity" { return false }

        return true
    }

    private static func opponentName(from title: String) -> String? {
        // Bound can list either team first. Resolve the non-DCG side rather
        // than assuming the opponent always follows "vs".
        let withoutSport = title.components(separatedBy: ":").dropFirst()
            .joined(separator: ":")
        let matchup = withoutSport.isEmpty ? title : withoutSport

        let parts: [String]
        if let range = matchup.range(of: " vs ", options: .caseInsensitive) {
            parts = [String(matchup[..<range.lowerBound]),
                     String(matchup[range.upperBound...])]
        } else if let range = matchup.range(of: " at ", options: .caseInsensitive) {
            parts = [String(matchup[..<range.lowerBound]),
                     String(matchup[range.upperBound...])]
        } else {
            return nil
        }

        let teams = parts.map {
            $0.components(separatedBy: "(").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func isDCG(_ team: String) -> Bool {
            let value = normalized(team)
            return value == "dcg" || value.contains("dallas center grimes")
        }

        guard teams.count == 2 else { return nil }
        if isDCG(teams[0]) && !isDCG(teams[1]) { return teams[1] }
        if isDCG(teams[1]) && !isDCG(teams[0]) { return teams[0] }
        return nil
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

}
