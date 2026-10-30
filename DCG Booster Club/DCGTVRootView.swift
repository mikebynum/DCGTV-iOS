
import SwiftUI

// MARK: - DCGTV Navigation

private enum DCGTVTab: Hashable {
    case home
    case watch
    case schedule
    case shows
}

// MARK: - Root View

struct DCGTVRootView: View {

    @State private var selectedTab: DCGTVTab = .home
    @StateObject private var streams = StreamService()

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {

        TabView(selection: $selectedTab) {

            DCGTVHomeScreen(
                streams: streams,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(DCGTVTab.home)

            DCGTVWatchScreen(streams: streams)
                .tabItem {
                    Label("Watch", systemImage: "play.tv.fill")
                }
                .tag(DCGTVTab.watch)

            DCGTVScheduleScreen(streams: streams)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(DCGTVTab.schedule)

            DCGTVShowsScreen()
                .tabItem {
                    Label("Shows", systemImage: "film.stack.fill")
                }
                .tag(DCGTVTab.shows)
        }
        .tint(Color.dcgRed)
        .task {
            await streams.refreshKeepingRequestAlive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await streams.refreshKeepingRequestAlive()
                }
            }
        }
    }
}

// MARK: - Home Screen

private struct DCGTVHomeScreen: View {

    @ObservedObject var streams: StreamService
    @Binding var selectedTab: DCGTVTab

    private var featuredStream: DCGStream? {
        streams.streams.first
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 24) {

                // DCGTV Logo

                Image("DCGTVLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text("Mustang Athletics & Activities")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                // Featured Broadcast

                VStack(alignment: .leading, spacing: 12) {

                    Text("Featured Broadcast")
                        .font(.title2.bold())

                    if let featuredStream {

                        StreamCardView(stream: featuredStream)

                    } else if streams.isLoading {

                        ProgressView("Loading broadcasts...")
                            .frame(maxWidth: .infinity)
                            .padding()

                    } else {

                        emptyMessage(
                            "No broadcasts scheduled",
                            subtitle: "Check back for the next DCGTV event."
                        )
                    }

                    Button {
                        selectedTab = .schedule
                    } label: {

                        Label(
                            "View Broadcast Schedule",
                            systemImage: "calendar"
                        )
                        .font(.subheadline.bold())
                    }
                    .tint(Color.dcgRed)
                }

                // Watch DCGTV

                VStack(alignment: .leading, spacing: 12) {

                    Text("Watch DCGTV")
                        .font(.title2.bold())

                    Button {
                        selectedTab = .watch
                    } label: {

                        Label(
                            "Live & Recent Broadcasts",
                            systemImage: "play.rectangle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .foregroundStyle(.white)
                        .background(Color.dcgRed)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )
                    }

                    Button {
                        selectedTab = .shows
                    } label: {
                        Label(
                            "Explore DCGTV Shows",
                            systemImage: "film.stack"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .foregroundStyle(.white)
                        .background(Color.dcgRed.opacity(0.35))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Booster Club

                VStack(alignment: .leading, spacing: 10) {

                    Text("Support DCGTV")
                        .font(.title2.bold())

                    Text(
                        "DCGTV is supported by the DCG Booster Club."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Link(
                        "Visit the DCG Booster Club",
                        destination: URL(
                            string: "https://dcgboosterclub.com/"
                        )!
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.dcgRed)
                }
            }
            .padding(16)
            .padding(.bottom, 35)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            await streams.refreshKeepingRequestAlive(force: true)
        }
    }
}


// MARK: - Watch Screen

private struct DCGTVWatchScreen: View {

   @ObservedObject var streams: StreamService

   private var liveStreams: [DCGStream] {
       streams.streams.filter { $0.isLive }
   }

   private var recentBroadcasts: [DCGStream] {
       Array(
           streams.replays
               .sorted {
                   ($0.startDate ?? .distantPast) >
                   ($1.startDate ?? .distantPast)
               }
               .prefix(10)
       )
   }

   var body: some View {

       ScrollView {

           VStack(alignment: .leading, spacing: 22) {

               // MARK: Header

               VStack(alignment: .leading, spacing: 6) {

                   Text("Watch DCGTV")
                       .font(.largeTitle.bold())

                   Text("Watch Mustang games live or on demand")
                       .font(.subheadline)
                       .foregroundStyle(.secondary)
               }

               // MARK: Live Broadcasts

               VStack(alignment: .leading, spacing: 14) {

                   HStack {

                       Image(systemName: "dot.radiowaves.left.and.right")
                           .foregroundStyle(Color.dcgRed)

                       Text("Live Now")
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

                       VStack(alignment: .leading, spacing: 8) {

                           Text("Nothing live right now")
                               .font(.headline)

                           Text("Check the Schedule tab for upcoming broadcasts.")
                               .font(.subheadline)
                               .foregroundStyle(.secondary)
                       }
                       .frame(
                           maxWidth: .infinity,
                           alignment: .leading
                       )
                       .padding(20)
                       .background(
                           Color(uiColor: .secondarySystemGroupedBackground)
                       )
                       .clipShape(
                           RoundedRectangle(cornerRadius: 16)
                       )

                   } else {

                       ForEach(liveStreams) { stream in
                           StreamCardView(stream: stream)
                       }
                   }
               }

               // MARK: Recent Broadcasts

               VStack(alignment: .leading, spacing: 14) {

                   HStack {

                       Image(systemName: "clock.arrow.circlepath")
                           .foregroundStyle(Color.dcgRed)

                       Text("Recent Broadcasts")
                           .font(.title2.bold())

                       Spacer()

                       if !recentBroadcasts.isEmpty {

                           Text("\(recentBroadcasts.count)")
                               .font(.caption)
                               .foregroundStyle(.secondary)
                       }
                   }

                   if recentBroadcasts.isEmpty {

                       VStack(alignment: .leading, spacing: 8) {

                           Text("No recent broadcasts available")
                               .font(.headline)

                           Text("Completed DCGTV broadcasts will appear here.")
                               .font(.subheadline)
                               .foregroundStyle(.secondary)
                       }
                       .frame(
                           maxWidth: .infinity,
                           alignment: .leading
                       )
                       .padding(20)
                       .background(
                           Color(uiColor: .secondarySystemGroupedBackground)
                       )
                       .clipShape(
                           RoundedRectangle(cornerRadius: 16)
                       )

                   } else {

                       ForEach(recentBroadcasts) { stream in
                           StreamCardView(stream: stream)
                       }
                   }
               }

               // MARK: YouTube Channel

               Link(
                   destination: URL(
                       string: "https://www.youtube.com/@DCGActivities/streams"
                   )!
               ) {

                   HStack(spacing: 12) {

                       Image(systemName: "play.rectangle.fill")
                           .font(.title3)

                       Text("Browse All Broadcasts")
                           .font(.subheadline.bold())

                       Spacer()

                       Image(systemName: "arrow.up.right")
                   }
                   .padding(16)
                   .foregroundStyle(.white)
                   .background(Color.dcgRed)
                   .clipShape(
                       RoundedRectangle(cornerRadius: 14)
                   )
               }

               // MARK: Status

               if let lastUpdated = streams.lastUpdated {

                   Text("Updated \(lastUpdated, style: .relative) ago")
                       .font(.caption)
                       .foregroundStyle(.secondary)
               }

               if streams.errorMessage != nil {

                   Text("Couldn't refresh. Showing previous results.")
                       .font(.caption)
                       .foregroundStyle(.orange)
               }
           }
           .padding(16)
           .padding(.bottom, 35)
       }
       .background(
           Color(uiColor: .systemGroupedBackground)
       )
       .refreshable {
           await streams.refreshKeepingRequestAlive(force: true)
       }
   }
}

// MARK: - Schedule Screen

private struct DCGTVScheduleScreen: View {

    @ObservedObject var streams: StreamService

    private var scheduled: [DCGStream] {
        streams.streams.filter {
            $0.status.lowercased() == "upcoming"
        }
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 18) {

                Text("Broadcast Schedule")
                    .font(.largeTitle.bold())
                
                DCGGamesScheduleView(streams: streams)

                Text("Upcoming DCGTV livestreams")
                    .foregroundStyle(.secondary)

                if scheduled.isEmpty {

                    emptyMessage(
                        "No upcoming broadcasts",
                        subtitle: "New events will appear when scheduled on YouTube."
                    )

                } else {

                    ForEach(scheduled) { stream in
                        StreamCardView(stream: stream)
                    }
                }

                Link(
                    "Full YouTube Schedule",
                    destination: URL(
                        string: "https://www.youtube.com/@DCGActivities/streams"
                    )!
                )
                .foregroundStyle(Color.dcgRed)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            await streams.refreshKeepingRequestAlive(force: true)
        }
    }
}


// MARK: - Shows Screen

private struct DCGTVShowsScreen: View {

   private let channelURL = URL(
       string: "https://www.youtube.com/@DCGActivities/videos"
   )!

   var body: some View {

       NavigationStack {

           ScrollView {

               VStack(alignment: .leading, spacing: 24) {

                   // MARK: Header

                   VStack(alignment: .leading, spacing: 8) {

                       Text("DCGTV Originals")
                           .font(.largeTitle.bold())

                       Text(
                           "Original programming, interviews, " +
                           "and stories from DCGTV."
                       )
                       .font(.subheadline)
                       .foregroundStyle(.secondary)
                   }

                   // MARK: Actual YouTube Playlist Episodes

                   DCGPlaylistSectionsView()

                   // MARK: YouTube Channel Link

                   Link(destination: channelURL) {

                       HStack(spacing: 12) {

                           Image(systemName: "play.rectangle.fill")
                               .font(.title3)

                           Text("Browse All DCGTV Videos")
                               .font(.subheadline.bold())

                           Spacer()

                           Image(systemName: "arrow.up.right")
                       }
                       .padding(16)
                       .foregroundStyle(.white)
                       .background(Color.dcgRed)
                       .clipShape(
                           RoundedRectangle(cornerRadius: 14)
                       )
                   }

                   // MARK: Footer

                   Text("Mustang Athletics & Activities")
                       .font(.caption)
                       .foregroundStyle(.secondary)
                       .frame(maxWidth: .infinity)
               }
               .padding(16)
               .padding(.bottom, 35)
           }
           .background(
               Color(uiColor: .systemGroupedBackground)
           )
       }
   }
}


// MARK: - Shared Empty State

private func emptyMessage(
    _ title: String,
    subtitle: String
) -> some View {

    VStack(alignment: .leading, spacing: 8) {

        Text(title)
            .font(.headline)

        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
        Color(uiColor: .secondarySystemGroupedBackground)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
}

