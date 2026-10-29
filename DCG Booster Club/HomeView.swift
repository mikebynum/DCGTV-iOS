import SwiftUI

// MARK: - Native DCG Home Screen

struct HomeView: View {

    @Binding var selectedTab: AppTab

    @StateObject private var streamService = StreamService()

    @Environment(\.scenePhase) private var scenePhase

    private let dcgRed = Color(
        red: 200.0 / 255.0,
        green: 16.0 / 255.0,
        blue: 46.0 / 255.0
    )

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Booster Club Logo

                    HStack {

                        Spacer()

                        Image("BoosterClubLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .frame(height: 100)
                            .accessibilityLabel(
                                "DCG Booster Club"
                            )

                        Spacer()
                    }
                    .padding(.top, 8)

                    // MARK: Upcoming Livestreams

                    UpcomingStreamsView(
                        service: streamService
                    )

                    // MARK: Quick Access

                    VStack(alignment: .leading, spacing: 14) {

                        Text("Quick Access")
                            .font(.title2.bold())

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {

                            quickAccessButton(
                                title: "Watch DCGTV",
                                subtitle: "Livestreams",
                                icon: "play.rectangle.fill",
                                tab: .dcgtv
                            )

                            quickAccessButton(
                                title: "Memberships",
                                subtitle: "Join the Boosters",
                                icon: "ticket.fill",
                                tab: .memberships
                            )

                            quickAccessButton(
                                title: "Volunteer",
                                subtitle: "Get Involved",
                                icon: "hands.sparkles.fill",
                                tab: .volunteer
                            )

                            websiteButton()
                        }
                    }

                    // MARK: Mustang Welcome Banner

                    VStack(alignment: .leading, spacing: 12) {

                        Text("GO MUSTANGS!")
                            .font(
                                .system(
                                    size: 28,
                                    weight: .black,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white)

                        Text("Supporting DCG Athletics")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(
                            "Connecting Mustang families, fans, " +
                            "and our community."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [
                                dcgRed,
                                Color(
                                    red: 110.0 / 255.0,
                                    green: 0,
                                    blue: 25.0 / 255.0
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18)
                    )

                    // MARK: Fuel the Stampede

                    VStack(alignment: .leading, spacing: 12) {

                        Text("Fuel the Stampede")
                            .font(.title2.bold())

                        Text(
                            "The DCG Booster Club supports " +
                            "student-athletes, athletic programs, " +
                            "and school spirit throughout the " +
                            "Dallas Center-Grimes community."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                        Button {

                            selectedTab = .memberships

                        } label: {

                            HStack {

                                Text("Become a Member")
                                    .fontWeight(.semibold)

                                Spacer()

                                Image(systemName: "arrow.right")
                            }
                            .padding(16)
                            .foregroundStyle(.white)
                            .background(dcgRed)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }

                    // MARK: Footer

                    HStack {

                        Spacer()

                        Text("DCG BOOSTER CLUB")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }

            // MARK: Pull-to-Refresh

            // Pull down to refresh
            .refreshable {
                await streamService.refreshKeepingRequestAlive(force: true)
            }

            // Load streams when Home appears
            .task {
                await streamService.refreshKeepingRequestAlive()
            }

            // Refresh when the app becomes active
            .onChange(of: scenePhase) { oldPhase, newPhase in

                if newPhase == .active {

                    Task {
                        await streamService.refreshKeepingRequestAlive()
                    }
                }
            }
            
            .background(
                Color(uiColor: .systemGroupedBackground)
            )

            // Use the logo instead of a redundant title.
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Quick Access Button

    private func quickAccessButton(
        title: String,
        subtitle: String,
        icon: String,
        tab: AppTab
    ) -> some View {

        Button {

            selectedTab = tab

        } label: {

            VStack(alignment: .leading, spacing: 8) {

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(dcgRed)

                Spacer(minLength: 4)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 90,
                alignment: .leading
            )
            .padding(14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Full Website Button

    private func websiteButton() -> some View {

        Link(
            destination: URL(
                string: "https://dcgboosterclub.com/"
            )!
        ) {

            VStack(alignment: .leading, spacing: 8) {

                Image(systemName: "globe")
                    .font(.system(size: 26))
                    .foregroundStyle(dcgRed)

                Spacer(minLength: 4)

                Text("Full Website")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("Open in Safari")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 90,
                alignment: .leading
            )
            .padding(14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}
