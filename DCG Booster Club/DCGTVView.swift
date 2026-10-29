import SwiftUI

struct DCGTVView: View {
    @StateObject private var service = StreamService()
    @Environment(\.scenePhase) private var scenePhase

    private let youtubeURL = URL(string: "https://www.youtube.com/@DCGActivities/streams")!
    private var liveStreams: [DCGStream] { service.streams.filter { $0.isLive } }
    private var upcomingStreams: [DCGStream] {
        service.streams.filter { $0.status.lowercased() == "upcoming" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 10) {
                        Image("DCGTVLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 230)
                            .frame(height: 120)
                            .accessibilityLabel("DCGTV")
                        Text("Mustang Athletics & Activities")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    if service.isLoading && service.lastUpdated == nil {
                        ProgressView("Loading DCGTV...")
                            .frame(maxWidth: .infinity)
                            .padding(30)
                    } else if let error = service.errorMessage, service.lastUpdated == nil {
                        VStack(spacing: 12) {
                            Label("Unable to load broadcasts", systemImage: "wifi.exclamationmark")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Try Again") {
                                Task { await service.loadStreams(force: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.dcgRed)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundStyle(Color.dcgRed)
                                Text("Live Broadcasts")
                                    .font(.title2.bold())
                                Spacer()
                                if !liveStreams.isEmpty {
                                    Text("LIVE")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                            if liveStreams.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Nothing live right now")
                                            .font(.subheadline.bold())
                                        Text("Check below for upcoming streams.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                ForEach(liveStreams) { stream in
                                    StreamCardView(stream: stream)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color.dcgRed)
                                Text("Upcoming Broadcasts")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(upcomingStreams.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            if upcomingStreams.isEmpty {
                                Text("No upcoming broadcasts scheduled.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                ForEach(upcomingStreams) { stream in
                                    StreamCardView(stream: stream)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "play.square.stack")
                                    .foregroundStyle(Color.dcgRed)
                                Text("Recent Broadcasts")
                                    .font(.title2.bold())
                                Spacer()
                            }
                            if service.replays.isEmpty {
                                Text("No public replays found yet. Check back after a broadcast ends.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                ForEach(service.replays) { replay in
                                    ReplayCardView(replay: replay)
                                }
                            }
                        }
                    }

                    // Manually uploaded DCGTV series from YouTube playlists.
                    DCGPlaylistSectionsView()

                    Link(destination: youtubeURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3)
                            Text("Visit DCG Activities on YouTube")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding(16)
                        .foregroundStyle(.white)
                        .background(Color.dcgRed)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    if let lastUpdated = service.lastUpdated {
                        Text("Updated \(lastUpdated, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if service.errorMessage != nil && service.lastUpdated != nil {
                        Label("Couldn't refresh. Showing previous results.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 35)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable {
                await service.refreshKeepingRequestAlive(force: true)
            }
            .task {
                await service.refreshKeepingRequestAlive()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await service.refreshKeepingRequestAlive() }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ReplayCardView: View {
    let replay: DCGStream

    var body: some View {
        Link(destination: URL(string: replay.url)!) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: replay.thumbnail)) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color.dcgRed.opacity(0.1))
                            .overlay { Image(systemName: "play.rectangle.fill").foregroundStyle(Color.dcgRed) }
                    }
                }
                .frame(width: 128, height: 76)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 7) {
                    Text(replay.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let date = replay.startDate {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label("Watch Replay", systemImage: "play.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.dcgRed)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
    