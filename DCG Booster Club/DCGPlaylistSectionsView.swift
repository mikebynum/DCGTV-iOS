
import SwiftUI
import Combine

// MARK: - Video Model

struct DCGPlaylistVideo: Decodable, Identifiable {

    let id: String
    let title: String
    let thumbnail: String
    let publishedAt: String?
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, title, thumbnail, url
        case publishedAt = "published_at"
    }

    var publicationDate: Date? {
        guard let publishedAt else { return nil }

        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: publishedAt) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]

        return formatter.date(from: publishedAt)
    }
}

// MARK: - Playlist API Response

private struct DCGPlaylistResponse: Decodable {

    let playlists: [String: [DCGPlaylistVideo]]
    let errors: [String: String]

    enum CodingKeys: String, CodingKey {
        case playlists, errors
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        playlists = try container.decode(
            [String: [DCGPlaylistVideo]].self,
            forKey: .playlists
        )

        if let dictionary = try? container.decode(
            [String: String].self,
            forKey: .errors
        ) {
            errors = dictionary

        } else if let array = try? container.decode(
            [String].self,
            forKey: .errors
        ), array.isEmpty {
            errors = [:]

        } else if !container.contains(.errors) {
            errors = [:]

        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .errors,
                in: container,
                debugDescription: "Unexpected errors format"
            )
        }
    }
}

// MARK: - Playlist Service

@MainActor
private final class DCGPlaylistService: ObservableObject {

    @Published var playlists: [String: [DCGPlaylistVideo]] = [:]
    @Published var errors: [String: String] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    private let endpoint = URL(
        string: "https://dcgboosterclub.com/wp-json/dcg/v1/videos"
    )!

    func refresh() async {

        guard !isLoading else { return }

        isLoading = true
        errors = [:]

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

            let result = try JSONDecoder().decode(
                DCGPlaylistResponse.self,
                from: data
            )

            playlists = result.playlists
            errors = result.errors
            lastUpdated = Date()

            print("DCG Playlists loaded successfully")
            print(
                "Full Gallop: \(playlists["full_gallop"]?.count ?? 0) videos"
            )
            print(
                "Senior Spotlight: \(playlists["senior_spotlight"]?.count ?? 0) videos"
            )

        } catch {

            let nsError = error as NSError

            if error is CancellationError ||
               (nsError.domain == NSURLErrorDomain &&
                nsError.code == NSURLErrorCancelled) {
                return
            }

            errors["general"] = error.localizedDescription
            print("DCG Playlist Error: \(error)")
        }
    }

    func refreshKeepingRequestAlive() async {

        let task = Task {
            await self.refresh()
        }

        await task.value
    }
}

// MARK: - Selected Video

private struct SelectedPlaylistVideo: Identifiable {

    let id = UUID()
    let url: URL
}

// MARK: - Shows Tab Content

struct DCGPlaylistSectionsView: View {

    @StateObject private var service = DCGPlaylistService()

    @State private var selectedVideo: SelectedPlaylistVideo?

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            if service.isLoading && service.lastUpdated == nil {

                ProgressView("Loading DCGTV shows...")
                    .frame(maxWidth: .infinity)
                    .padding()

            } else {

                showCard(
                    title: "Mustang Full Gallop",
                    subtitle: "Football conversations and interviews",
                    key: "full_gallop",
                    symbol: "mic.fill"
                )

                showCard(
                    title: "Senior Spotlight",
                    subtitle: "Celebrating DCG senior athletes",
                    key: "senior_spotlight",
                    symbol: "star.fill"
                )
            }

            if let error = service.errors["general"] {

                VStack(alignment: .leading, spacing: 10) {

                    Text("Unable to refresh shows")
                        .font(.headline)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        Task {
                            await service.refreshKeepingRequestAlive()
                        }
                    }
                    .tint(Color.dcgRed)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )
            }
        }
        .task {
            await service.refreshKeepingRequestAlive()
        }
        .sheet(item: $selectedVideo) { video in
            VideoBrowserView(url: video.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Show Card

    private func showCard(
        title: String,
        subtitle: String,
        key: String,
        symbol: String
    ) -> some View {

        let videos = service.playlists[key] ?? []

        return NavigationLink {

            DCGShowEpisodesView(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                videos: videos,
                errorMessage: service.errors[key],
                onSelectVideo: openVideo
            )

        } label: {

            HStack(spacing: 16) {

                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.dcgRed)
                    .frame(width: 60, height: 60)
                    .background(
                        Color.dcgRed.opacity(0.10)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 6) {

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    Text(
                        "\(videos.count) " +
                        (videos.count == 1 ? "episode" : "episodes")
                    )
                    .font(.caption.bold())
                    .foregroundStyle(Color.dcgRed)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Open Video

    private func openVideo(_ video: DCGPlaylistVideo) {

        guard let url = URL(string: video.url),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme)
        else {
            return
        }

        selectedVideo = SelectedPlaylistVideo(url: url)
    }
}

// MARK: - Dedicated Show Episode Page

private struct DCGShowEpisodesView: View {

    let title: String
    let subtitle: String
    let symbol: String
    let videos: [DCGPlaylistVideo]
    let errorMessage: String?
    let onSelectVideo: (DCGPlaylistVideo) -> Void

    private var sortedVideos: [DCGPlaylistVideo] {

        videos.sorted {

            ($0.publicationDate ?? .distantPast) >
            ($1.publicationDate ?? .distantPast)
        }
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                // MARK: Show Header

                HStack(spacing: 14) {

                    Image(systemName: symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.dcgRed)
                        .frame(width: 64, height: 64)
                        .background(
                            Color.dcgRed.opacity(0.10)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )

                    VStack(alignment: .leading, spacing: 6) {

                        Text(title)
                            .font(.title2.bold())

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Episode Count

                Text(
                    "\(videos.count) " +
                    (videos.count == 1 ? "Episode" : "Episodes")
                )
                .font(.headline)

                // MARK: Episodes

                if let errorMessage, videos.isEmpty {

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                } else if videos.isEmpty {

                    Text("No public episodes are available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                } else {

                    LazyVStack(spacing: 12) {

                        ForEach(sortedVideos) { video in

                            Button {
                                onSelectVideo(video)
                            } label: {

                                DCGShowEpisodeCard(video: video)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 35)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Episode Card

private struct DCGShowEpisodeCard: View {

    let video: DCGPlaylistVideo

    var body: some View {

        HStack(alignment: .center, spacing: 12) {

            AsyncImage(
                url: URL(string: video.thumbnail)
            ) { phase in

                if case .success(let image) = phase {

                    image
                        .resizable()
                        .scaledToFill()

                } else {

                    Rectangle()
                        .fill(Color.dcgRed.opacity(0.12))
                        .overlay {

                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.dcgRed)
                        }
                }
            }
            .frame(width: 120, height: 72)
            .clipped()
            .clipShape(
                RoundedRectangle(cornerRadius: 9)
            )

            VStack(alignment: .leading, spacing: 7) {

                Text(video.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let date = video.publicationDate {

                    Text(date, format: .dateTime
                        .month(.abbreviated)
                        .day()
                        .year()
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Label(
                    "Watch Episode",
                    systemImage: "play.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(Color.dcgRed)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 14)
        )
    }
}

