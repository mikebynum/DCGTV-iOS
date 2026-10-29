
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

        // WordPress may return an empty array for errors.
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

// MARK: - Playlist Sections

struct DCGPlaylistSectionsView: View {

    @StateObject private var service = DCGPlaylistService()

    // Tracks the selected episode for in-app playback.
    @State private var selectedVideo: SelectedPlaylistVideo?

    var body: some View {

        VStack(alignment: .leading, spacing: 24) {

            playlistSection(
                "Mustang Full Gallop",
                key: "full_gallop",
                symbol: "mic.fill"
            )

            playlistSection(
                "Senior Spotlight",
                key: "senior_spotlight",
                symbol: "star.fill"
            )
        }
        .task {
            await service.refreshKeepingRequestAlive()
        }

        // Present the same browser used by Watch and replays.
        .sheet(item: $selectedVideo) { video in

            VideoBrowserView(url: video.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Playlist Section

    private func playlistSection(
        _ title: String,
        key: String,
        symbol: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Label(title, systemImage: symbol)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Loading
            if service.isLoading && service.lastUpdated == nil {

                ProgressView("Loading videos...")
                    .frame(maxWidth: .infinity)
                    .padding()

            // Error
            } else if let error =
                        service.errors[key] ?? service.errors["general"],
                      (service.playlists[key] ?? []).isEmpty {

                VStack(alignment: .leading, spacing: 8) {

                    Text("Videos couldn't be loaded.")
                        .font(.subheadline.bold())

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
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )

            // Empty playlist
            } else if (service.playlists[key] ?? []).isEmpty {

                Text("No public videos found in this playlist yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            // Videos
            } else {

                ForEach(
                    Array((service.playlists[key] ?? []).prefix(5))
                ) { video in

                    videoCard(video)
                }
            }
        }
    }

    // MARK: - Video Card

    private func videoCard(
        _ video: DCGPlaylistVideo
    ) -> some View {

        Button {

            guard let url = URL(string: video.url),
                  ["https", "http"].contains(
                      url.scheme?.lowercased() ?? ""
                  )
            else {
                return
            }

            selectedVideo = SelectedPlaylistVideo(url: url)

        } label: {

            HStack(spacing: 12) {

                // Thumbnail
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

                                Image(
                                    systemName: "play.rectangle.fill"
                                )
                                .foregroundStyle(Color.dcgRed)
                            }
                    }
                }
                .frame(width: 120, height: 72)
                .clipped()
                .clipShape(
                    RoundedRectangle(cornerRadius: 9)
                )

                // Episode information
                VStack(alignment: .leading, spacing: 7) {

                    Text(video.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Label(
                        "Watch Video",
                        systemImage: "play.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(Color.dcgRed)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color(uiColor: .secondarySystemGroupedBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }
}

