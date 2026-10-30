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
private final class DCGGamesService: ObservableObject {

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

    @StateObject private var service = DCGGamesService()

    @State private var selectedSport = "All Sports"
    @State private var selectedLevel = "All Levels"

    private var sports: [String] {
        ["All Sports"] +
        Array(
            Set(service.games.map(\.sport))
        ).sorted()
    }

    private var levels: [String] {
        ["All Levels"] +
        Array(
            Set(service.games.map(\.level))
        ).sorted()
    }

    private var filteredGames: [DCGGame] {

        service.games.filter { game in

            let matchesSport =
                selectedSport == "All Sports" ||
                game.sport == selectedSport

            let matchesLevel =
                selectedLevel == "All Levels" ||
                game.level == selectedLevel

            return matchesSport && matchesLevel
        }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            // MARK: - Header

            VStack(alignment: .leading, spacing: 6) {

                Text("Mustang Athletics")
                    .font(.title2.bold())

                Text("Upcoming DCG games and events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Filters

            HStack(spacing: 12) {

                Picker("Sport", selection: $selectedSport) {

                    ForEach(sports, id: \.self) { sport in
                        Text(sport).tag(sport)
                    }
                }
                .tint(Color.dcgRed)

                Picker("Level", selection: $selectedLevel) {

                    ForEach(levels, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .tint(Color.dcgRed)
            }

            // MARK: - Loading

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
                        Task {
                            await service.refreshKeepingRequestAlive()
                        }
                    }
                    .tint(Color.dcgRed)
                }
                .padding(20)

            } else {

                Text("\(filteredGames.count) upcoming events")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVStack(spacing: 12) {

                    ForEach(filteredGames) { game in
                        DCGGameCard(game: game)
                    }
                }

                if filteredGames.isEmpty {

                    Text("No games match the selected filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            // MARK: - Bound Link

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

private struct DCGGameCard: View {

    let game: DCGGame

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

            Text(game.title)
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
