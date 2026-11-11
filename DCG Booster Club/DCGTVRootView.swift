
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
    @StateObject private var games = DCGGamesService()
    @StateObject private var results = DCGResultsService()
    @State private var selectedGame: DCGGame?

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {

        TabView(selection: $selectedTab) {

            DCGTVHomeScreen(
                streams: streams,
                games: games,
                results: results,
                selectedGame: $selectedGame,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(DCGTVTab.home)

            DCGTVWatchScreen(streams: streams, games: games)
                .tabItem {
                    Label("Watch", systemImage: "play.tv.fill")
                }
                .tag(DCGTVTab.watch)

            DCGTVScheduleScreen(
                streams: streams,
                games: games,
                results: results,
                selectedGame: $selectedGame
            )
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
        .sheet(item: $selectedGame) { game in
            NavigationStack {
                DCGGameDetailView(
                    game: game,
                    stream: DCGGameStreamMatcher.matchedStream(
                        for: game,
                        in: games.games,
                        broadcasts: streams.streams
                    ),
                    result: results.results.first { $0.id == game.id }
                )
            }
        }
        .task(id: scenePhase) {
            streams.expireStatusIfNeeded()
            guard scenePhase == .active else { return }
            await streams.refreshWhileActive()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            async let gamesRefresh: Void = games.refreshKeepingRequestAlive()
            async let resultsRefresh: Void = results.refreshKeepingRequestAlive()
            _ = await (gamesRefresh, resultsRefresh)
        }
    }
}

// Shared by Home, Watch, and Schedule so a failed request never looks like
// a confirmed empty schedule. Cached links remain usable during an outage.
private struct DCGBroadcastStatusView: View {
    @ObservedObject var service: StreamService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if service.isLoading {
                ProgressView("Updating broadcasts…")
            }

            if service.errorMessage != nil {
                Text(service.lastUpdated == nil
                     ? "Broadcasts couldn't be loaded. Check your connection and try again."
                     : "Couldn't refresh broadcasts. Showing saved information; live status is unverified.")
                    .font(.subheadline)
            } else if !service.isStatusCurrent, service.lastUpdated != nil {
                Text("Showing saved broadcasts. Live status is unverified until refreshed.")
                    .font(.subheadline)
            } else if !service.isStatusCurrent, !service.isLoading {
                Text("Broadcasts haven't been loaded yet.")
                    .font(.subheadline)
            }

            if let lastUpdated = service.lastUpdated {
                Text("Last updated: \(lastUpdated, format: .dateTime.month().day().hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !service.isStatusCurrent {
                Button("Retry") {
                    Task { await service.refreshKeepingRequestAlive(force: true) }
                }
                .disabled(service.isLoading)
            }
        }
    }
}

// MARK: - Home Screen

private struct DCGTVHomeScreen: View {

    @ObservedObject var streams: StreamService
    @ObservedObject var games: DCGGamesService
    @ObservedObject var results: DCGResultsService
    @Binding var selectedGame: DCGGame?
    @Binding var selectedTab: DCGTVTab

    @AppStorage("dcgtv.favoriteSports") private var favoriteSportsRaw = ""
    @State private var showingSportPicker = false
    @State private var hasScrolled = false

    private var favoriteSports: Set<String> {
        Set(favoriteSportsRaw.split(separator: "|").map(String.init))
    }

    private var availableSports: [String] {
        Array(Set(games.games.map(\.sport))).sorted()
    }

    private var prioritizedGames: [DCGGame] {
        let favorites = favoriteSports
        let upcoming = games.games.filter {
            ($0.startDate ?? .distantPast) >= Date()
        }
        guard !favorites.isEmpty else { return Array(upcoming.prefix(3)) }

        // Favorite sports only, even if that's fewer than 3 games (or none).
        return Array(upcoming.filter { favorites.contains($0.sport) }.prefix(3))
    }

    private var featuredStream: DCGStream? {
        streams.streams.first { stream in
            let title = stream.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return title != "test" &&
                !title.hasPrefix("test ") &&
                !title.hasPrefix("test:") &&
                !title.hasPrefix("[test]")
        }
    }

    var body: some View {

        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    DCGHomeBrandHeader(topInset: geometry.safeAreaInsets.top)

                    homeContent
                        .padding(.leading, geometry.safeAreaInsets.leading)
                        .padding(.trailing, geometry.safeAreaInsets.trailing)
                }
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: DCGHomeScrollOffsetKey.self,
                            value: contentGeometry.frame(in: .named("dcgtv.home.scroll")).minY
                        )
                    }
                }
            }
            .ignoresSafeArea(.container, edges: [.top, .horizontal])
            .coordinateSpace(name: "dcgtv.home.scroll")
            .onPreferenceChange(DCGHomeScrollOffsetKey.self) { offset in
                hasScrolled = offset < -1
            }
            .overlay {
                if hasScrolled, UIDevice.current.userInterfaceIdiom == .phone {
                    GeometryReader { chrome in
                        Color(uiColor: .systemGroupedBackground)
                            .frame(height: geometry.safeAreaInsets.top)
                            // The scroll view extends through the top safe area.
                            // Anchor this cover at the window's top, independent
                            // of the overlay's proposed safe-area origin.
                            .offset(y: -chrome.frame(in: .global).minY)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .modifier(DCGHomeScrollEdgeStyle())
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable {
                async let streamsRefresh: Void = streams.refreshKeepingRequestAlive(force: true)
                async let gamesRefresh: Void = games.refreshKeepingRequestAlive()
                async let resultsRefresh: Void = results.refreshKeepingRequestAlive()
                _ = await (streamsRefresh, gamesRefresh, resultsRefresh)
            }
        }
        .sheet(isPresented: $showingSportPicker) {
            DCGFavoriteSportsPicker(
                availableSports: availableSports,
                favoritesRaw: $favoriteSportsRaw
            )
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Featured Broadcast

            VStack(alignment: .leading, spacing: 10) {

                Text("Featured Broadcast")
                    .font(.title2.bold())

                if let featuredStream {

                    StreamCardView(stream: featuredStream, isStatusCurrent: streams.isStatusCurrent, isFeatured: true)

                } else if streams.isStatusCurrent {

                    emptyMessage(
                        "No broadcasts scheduled",
                        subtitle: "Check back for the next DCGTV event."
                    )
                }

                DCGBroadcastStatusView(service: streams)

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
                .frame(minHeight: 44)
            }

            // Next three games from Bound, including games not streamed on DCGTV.
            VStack(alignment: .leading, spacing: 10) {

                HStack(alignment: .firstTextBaseline) {
                    Text(favoriteSports.isEmpty ? "Upcoming Mustang Games" : "Your Mustang Games")
                        .font(.title2.bold())
                    Spacer(minLength: 12)
                    Button("See All") {
                        selectedTab = .schedule
                    }
                    .font(.subheadline.bold())
                    .tint(Color.dcgRed)
                    .fixedSize()
                    .frame(minHeight: 44)
                }

                HStack {
                    Button {
                        showingSportPicker = true
                    } label: {
                        Label(
                            favoriteSports.isEmpty ? "Choose Favorite Sports" : "Edit Favorite Sports",
                            systemImage: "star"
                        )
                        .font(.subheadline.bold())
                    }
                    .tint(Color.dcgRed)

                    Spacer()
                    if !favoriteSports.isEmpty {
                        Text("\(favoriteSports.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if games.isLoading && games.games.isEmpty {
                    ProgressView("Loading games...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if games.games.isEmpty {
                    emptyMessage(
                        "No upcoming games found",
                        subtitle: games.errorMessage ?? "Check the full schedule for updates."
                    )
                } else if prioritizedGames.isEmpty {
                    emptyMessage(
                        "No upcoming games in your favorite sports",
                        subtitle: "Check the full schedule, or edit your favorite sports above."
                    )
                } else {
                    ForEach(prioritizedGames) { game in
                        DCGHomeGameCard(
                            game: game,
                            stream: DCGGameStreamMatcher.matchedStream(
                                for: game,
                                in: games.games,
                                broadcasts: streams.streams
                            ),
                            onShowDetails: { selectedGame = game }
                        )
                    }
                }

            }

            // Keep the fuller results list in Schedule.
            DCGRecentResultsView(service: results, limit: 2, isCompact: true)

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
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}

// Track the content origin with APIs supported before iOS 18, so the
// status-bar treatment works without raising the app's deployment target.
private struct DCGHomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// iOS 26 adds a blurred scroll-edge treatment that would obscure the artwork.
private struct DCGHomeScrollEdgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

// Keep all 2:1 artwork below system chrome. Only the decorative top 8% is
// mirrored/extended behind the status bar; its lower edge meets the original
// top row continuously. The original image remains intact, without
// aspect-fill cropping or an overlay.
private struct DCGHomeBrandHeader: View {
    let topInset: CGFloat

    var body: some View {
        // A one-point overlap prevents a fractional-pixel seam at the join.
        VStack(spacing: -1) {
            if topInset > 0 {
                GeometryReader { geometry in
                    Image("DCGTVHomeHero")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.width * 0.5)
                        .scaleEffect(x: 1, y: -1, anchor: .top)
                        .offset(y: geometry.size.width * 0.5 * 0.08)
                        .scaleEffect(
                            x: 1,
                            y: topInset / (geometry.size.width * 0.5 * 0.08),
                            anchor: .top
                        )
                }
                .frame(height: topInset)
                .clipped()
                .accessibilityHidden(true)
            }

            Image("DCGTVHomeHero")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("DCGTV.com. Mustang Athletics. Live and On Demand. Presented by Charter Bank.")
                .accessibilityIdentifier("dcgtv.home.hero")
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: - Favorite Sports Picker
// AppStorage saves selections on this device, without an account or backend.
struct DCGFavoriteSportsPicker: View {

    let availableSports: [String]
    @Binding var favoritesRaw: String
    @Environment(\.dismiss) private var dismiss

    private var selected: Set<String> {
        Set(favoritesRaw.split(separator: "|").map(String.init))
    }

    private func toggle(_ sport: String) {
        var updated = selected
        if updated.contains(sport) {
            updated.remove(sport)
        } else {
            updated.insert(sport)
        }
        favoritesRaw = updated.sorted().joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose the Mustang sports you follow. Their upcoming games appear on Home and in the Schedule’s Starred selection. Favorites are saved on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if availableSports.isEmpty {
                    Section {
                        Text("Sports will appear when the Bound schedule finishes loading.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Sports") {
                        ForEach(availableSports, id: \.self) { sport in
                            Button {
                                toggle(sport)
                            } label: {
                                HStack {
                                    Text(sport)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selected.contains(sport) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.dcgRed)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(sport)
                            .accessibilityValue(selected.contains(sport) ? "Favorite" : "Not favorite")
                        }
                    }
                }

                if !selected.isEmpty {
                    Section {
                        Button("Clear All Favorite Sports", role: .destructive) {
                            favoritesRaw = ""
                        }
                    }
                }
            }
            .navigationTitle("Favorite Sports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color.dcgRed)
                }
            }
        }
    }
}


// MARK: - Compact Home Schedule Card
// The full Schedule tab intentionally keeps its more detailed game cards.
private struct DCGHomeGameCard: View {

    let game: DCGGame
    let stream: DCGStream?
    let onShowDetails: () -> Void

    private var broadcastURL: URL? {
        guard let stream,
              let url = URL(string: stream.url),
              url.scheme?.lowercased() == "https"
        else { return nil }
        return url
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let date = game.startDate {
                VStack(spacing: 2) {
                    Text(date, format: .dateTime.month(.abbreviated))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(date, format: .dateTime.day())
                        .font(.title2.bold())
                }
                .frame(minWidth: 44)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 4) {
                // The whole information block opens details, eliminating a duplicate row.
                Button(action: onShowDetails) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.sport) · \(game.level)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.dcgRed)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(game.displayTitle)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        if let date = game.startDate {
                            Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let location = game.location, !location.isEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens game details")

                if let url = broadcastURL {
                    Link(destination: url) {
                        Label("Watch on DCGTV", systemImage: "play.fill")
                            .frame(minHeight: 44)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.dcgRed)
                }

                if let external = game.externalStream, let url = external.validURL {
                    Link(destination: url) {
                        Label("Away Stream: \(external.provider)",
                              systemImage: "play.rectangle.on.rectangle")
                            .frame(minHeight: 44)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.dcgRed)
                    if let note = external.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}


// MARK: - Watch Screen

private struct DCGWatchHeader: View {
    var body: some View {
        Link(destination: URL(string: "https://www.charterbanker.com/")!) {
            Image("DCGTVWatchHeader")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("DCGTV. Watch Live & On-Demand. Presented by Charter Bank.")
        .accessibilityHint("Opens the Charter Bank website")
        .accessibilityIdentifier("dcgtv.watch.header")
        .accessibilityAddTraits(.isHeader)
    }
}

private struct DCGTVWatchScreen: View {

   @Environment(\.dynamicTypeSize) private var dynamicTypeSize

   @ObservedObject var streams: StreamService
   @ObservedObject var games: DCGGamesService

   private var upcomingAwayGames: [DCGGame] {
       Array(games.games.filter {
           ($0.startDate ?? .distantPast) >= Date().addingTimeInterval(-6 * 60 * 60) &&
           $0.externalStream?.validURL != nil
       }.prefix(10))
   }

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

           VStack(alignment: .leading, spacing: 16) {

               // MARK: Header

               DCGWatchHeader()

               DCGBroadcastStatusView(service: streams)

               // MARK: Live Broadcasts

               VStack(alignment: .leading, spacing: 10) {

                   HStack {

                       Image(systemName: "dot.radiowaves.left.and.right")
                           .foregroundStyle(Color.dcgRed)

                       Text(streams.isStatusCurrent ? "Live Now" : "Live Status Unverified")
                           .font(.title2.bold())

                       Spacer()

                       if !liveStreams.isEmpty && streams.isStatusCurrent {
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

                           Text(streams.isStatusCurrent ? "Nothing live right now" : "Live status is unavailable")
                               .font(.headline)

                           Text("Check the Schedule tab for upcoming broadcasts.")
                               .font(.subheadline)
                               .foregroundStyle(.secondary)
                       }
                       .frame(
                           maxWidth: .infinity,
                           alignment: .leading
                       )
                       .padding(14)
                       .background(
                           Color(uiColor: .secondarySystemGroupedBackground)
                       )
                       .clipShape(
                           RoundedRectangle(cornerRadius: 16)
                       )

                   } else {

                       ForEach(liveStreams) { stream in
                           StreamCardView(stream: stream, isStatusCurrent: streams.isStatusCurrent)
                       }
                   }
               }

               // MARK: Away and Other Streams

               if !upcomingAwayGames.isEmpty {
                   VStack(alignment: .leading, spacing: 12) {
                       Label("Away & Other Streams", systemImage: "play.rectangle.on.rectangle")
                           .font(.title2.bold())
                           .foregroundStyle(Color.dcgRed)

                       Text("Links to broadcasts hosted by other schools or providers. Access and availability are determined by the broadcaster.")
                           .font(.subheadline)
                           .foregroundStyle(.secondary)

                       ForEach(upcomingAwayGames) { game in
                           DCGAwayGameStreamCard(game: game)
                       }
                   }
               }

               // MARK: Recent Broadcasts

               VStack(alignment: .leading, spacing: 10) {

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
                       .padding(14)
                       .background(
                           Color(uiColor: .secondarySystemGroupedBackground)
                       )
                       .clipShape(
                           RoundedRectangle(cornerRadius: 16)
                       )

                   } else {

                       ForEach(recentBroadcasts) { stream in
                           StreamCardView(stream: stream, isStatusCurrent: streams.isStatusCurrent, isDense: true)
                       }
                   }
               }

               // MARK: YouTube Channel

               Link(
                   destination: URL(
                       string: "https://www.youtube.com/@DCGActivities/streams"
                   )!
               ) {

                   let layout = dynamicTypeSize.isAccessibilitySize
                       ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                       : AnyLayout(HStackLayout(spacing: 12))
                   layout {

                       Image(systemName: "play.rectangle.fill")
                           .font(.title3)

                       Text("Browse All Broadcasts")
                           .font(.subheadline.bold())
                           .fixedSize(horizontal: false, vertical: true)
                           .frame(maxWidth: .infinity, alignment: .leading)

                       if !dynamicTypeSize.isAccessibilitySize {
                           Image(systemName: "arrow.up.right")
                       }
                   }
                   .padding(16)
                   .foregroundStyle(.white)
                   .background(Color.dcgRed)
                   .clipShape(
                       RoundedRectangle(cornerRadius: 14)
                   )
               }
           }
           .padding(16)
           .padding(.bottom, 35)
       }
       .background(
           Color(uiColor: .systemGroupedBackground)
       )
       .refreshable {
           async let streamsRefresh: Void = streams.refreshKeepingRequestAlive(force: true)
           async let gamesRefresh: Void = games.refreshKeepingRequestAlive()
           _ = await (streamsRefresh, gamesRefresh)
       }
   }
}

// MARK: - Schedule Screen

private struct DCGTVScheduleScreen: View {

    @ObservedObject var streams: StreamService
    @ObservedObject var games: DCGGamesService
    @ObservedObject var results: DCGResultsService
    @Binding var selectedGame: DCGGame?
    @State private var showingRecentResults = false

    private var scheduled: [DCGStream] {
        streams.streams.filter {
            $0.status.lowercased() == "upcoming"
        }
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 12) {

                DCGScheduleHeader()

                DisclosureGroup(isExpanded: $showingRecentResults) {
                    DCGRecentResultsView(
                        service: results,
                        limit: 10,
                        showHeading: false
                    )
                    .padding(.top, 6)
                } label: {
                    Label("Recent Results", systemImage: "trophy.fill")
                        .font(.title3.bold())
                        .foregroundStyle(Color.dcgRed)
                }

                DCGGamesScheduleView(
                    service: games,
                    streams: streams,
                    selectedGame: $selectedGame
                )

                Text("Upcoming DCGTV Livestreams")
                    .font(.title2.bold())

                DCGBroadcastStatusView(service: streams)

                if scheduled.isEmpty && streams.isStatusCurrent {

                    emptyMessage(
                        "No upcoming broadcasts",
                        subtitle: "New events will appear when scheduled on YouTube."
                    )

                } else {

                    ForEach(scheduled) { stream in
                        StreamCardView(stream: stream, isStatusCurrent: streams.isStatusCurrent)
                    }
                }

                Link(
                    "Full YouTube Schedule",
                    destination: URL(
                        string: "https://www.youtube.com/@DCGActivities/streams"
                    )!
                )
                .foregroundStyle(Color.dcgRed)
                .frame(minHeight: 44)
            }
            .frame(maxWidth: 760)
            .padding(16)
            .padding(.bottom, 35)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            async let streamsRefresh: Void = streams.refreshKeepingRequestAlive(force: true)
            async let gamesRefresh: Void = games.refreshKeepingRequestAlive()
            async let resultsRefresh: Void = results.refreshKeepingRequestAlive()
            _ = await (streamsRefresh, gamesRefresh, resultsRefresh)
        }
    }
}


// MARK: - Shows Screen

private struct DCGTVShowsScreen: View {

   @Environment(\.dynamicTypeSize) private var dynamicTypeSize

   private let channelURL = URL(
       string: "https://www.youtube.com/@DCGActivities/videos"
   )!

   var body: some View {

       NavigationStack {

           ScrollView {

               VStack(alignment: .leading, spacing: 16) {

                   // MARK: Header

                   Image("DCGTVShowsHeader")
                       .renderingMode(.original)
                       .resizable()
                       .scaledToFit()
                       .frame(maxWidth: .infinity)
                       .accessibilityLabel("DCGTV Originals. Presented by Charter Bank.")
                       .accessibilityAddTraits(.isHeader)
                       .accessibilityIdentifier("dcgtv.shows.header")

                   // MARK: Actual YouTube Playlist Episodes

                   DCGPlaylistSectionsView()

                   // MARK: YouTube Channel Link

                   Link(destination: channelURL) {

                       let layout = dynamicTypeSize.isAccessibilitySize
                           ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                           : AnyLayout(HStackLayout(spacing: 12))
                       layout {

                           Image(systemName: "play.rectangle.fill")
                               .font(.title3)

                           Text("Browse All DCGTV Videos")
                               .font(.subheadline.bold())
                               .fixedSize(horizontal: false, vertical: true)
                               .frame(maxWidth: .infinity, alignment: .leading)

                           if !dynamicTypeSize.isAccessibilitySize {
                               Image(systemName: "arrow.up.right")
                           }
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
               .frame(maxWidth: 760)
               .padding(16)
               .padding(.bottom, 35)
               .frame(maxWidth: .infinity)
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

