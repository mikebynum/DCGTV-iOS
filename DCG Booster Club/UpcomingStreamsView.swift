import SwiftUI

// MARK: - Upcoming Streams Section

struct UpcomingStreamsView: View {

    @ObservedObject var service: StreamService

    private let maximumStreams = 3

    private let youtubeURL = URL(
        string: "https://www.youtube.com/@DCGActivities/streams"
    )!

    private var displayedStreams: [DCGStream] {
        Array(service.streams.prefix(maximumStreams))
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            // MARK: Section Header

            HStack {

                Text("DCGTV Livestreams")
                    .font(.title2.bold())

                Spacer()

                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(Color.dcgRed)
            }

            // MARK: Loading State

            if service.isLoading && service.lastUpdated == nil {

                HStack(spacing: 12) {

                    ProgressView()

                    Text("Loading broadcasts...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)

            } else if let error = service.errorMessage,
                      service.streams.isEmpty {

                errorView(error)

            } else if service.streams.isEmpty {

                emptyStateView

            } else {

                // MARK: Stream Cards

                ForEach(displayedStreams) { stream in

                    StreamCardView(stream: stream)
                }
            }

            // MARK: View All Streams

            Link(destination: youtubeURL) {

                HStack(spacing: 8) {

                    Text("View All Streams")
                        .font(.subheadline.bold())

                    Image(systemName: "arrow.right")
                        .font(.subheadline)

                    Spacer()
                }
                .foregroundStyle(Color.dcgRed)
                .padding(.vertical, 6)
            }

            // MARK: Last Updated

            if let lastUpdated = service.lastUpdated {

                HStack(spacing: 5) {

                    Image(systemName: "arrow.clockwise")

                    Text("Updated")

                    Text(
                        lastUpdated,
                        style: .relative
                    )

                    Text("ago")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Show a warning while retaining existing results.
            if service.errorMessage != nil,
               !service.streams.isEmpty {

                Text("Couldn't refresh streams. Showing previous results.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {

        VStack(spacing: 10) {

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30))
                .foregroundStyle(Color.dcgRed)

            Text("No Upcoming Streams")
                .font(.headline)

            Text("Check back soon for upcoming DCGTV broadcasts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Error State

    private func errorView(_ message: String) -> some View {

        VStack(spacing: 12) {

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Unable to Load Streams")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await service.loadStreams(force: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.dcgRed)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}


// MARK: - Individual Stream Card

struct StreamCardView: View {

   let stream: DCGStream

    @State private var showVideo = false

   private var streamActionTitle: String {
       if stream.isLive {
           return "Watch Live"
       } else if stream.status.lowercased() == "upcoming" {
           return "View Stream"
       } else {
           return "Watch Replay"
       }
   }

   var body: some View {

       Button {
           showVideo = true
       } label: {

           HStack(alignment: .center, spacing: 12) {

               // MARK: - Thumbnail

               AsyncImage(
                   url: URL(string: stream.thumbnail)
               ) { phase in

                   switch phase {

                   case .success(let image):
                       image
                           .resizable()
                           .scaledToFill()

                   case .failure:
                       streamThumbnailPlaceholder

                   case .empty:
                       streamThumbnailPlaceholder

                   @unknown default:
                       streamThumbnailPlaceholder
                   }
               }
               .frame(width: 128, height: 76)
               .clipped()
               .clipShape(
                   RoundedRectangle(cornerRadius: 10)
               )

               // MARK: - Stream Information

               VStack(alignment: .leading, spacing: 7) {

                   if stream.isLive {
                       Label(
                           "LIVE NOW",
                           systemImage: "circle.fill"
                       )
                       .font(.caption2.bold())
                       .foregroundStyle(.red)
                   }

                   Text(stream.title)
                       .font(.subheadline.bold())
                       .foregroundStyle(.primary)
                       .lineLimit(2)
                       .multilineTextAlignment(.leading)

                   if let date = stream.startDate {
                       Text(
                           date,
                           format: .dateTime
                               .weekday(.abbreviated)
                               .month(.abbreviated)
                               .day()
                               .hour()
                               .minute()
                       )
                       .font(.caption)
                       .foregroundStyle(.secondary)
                       .lineLimit(2)
                   }

                   Label(
                       streamActionTitle,
                       systemImage: "play.fill"
                   )
                   .font(.caption.bold())
                   .foregroundStyle(Color.dcgRed)

               } // Closes information VStack

               Spacer(minLength: 0)

           } // Closes HStack

           .padding(12)
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

       } // Closes Link

       .buttonStyle(.plain)
       .sheet(isPresented: $showVideo) {
           if let url = URL(string: stream.url) {
               VideoBrowserView(url: url)
                   .ignoresSafeArea()
           }
       }
   }

   // MARK: - Thumbnail Placeholder

   private var streamThumbnailPlaceholder: some View {

       Rectangle()
           .fill(Color.dcgRed.opacity(0.10))
           .overlay {
               Image(systemName: "play.rectangle.fill")
                   .font(.system(size: 26))
                   .foregroundStyle(Color.dcgRed)
           }
   }
}
