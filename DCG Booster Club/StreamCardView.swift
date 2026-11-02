import SwiftUI

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

   // SFSafariViewController requires an http/https URL; validate before
   // presenting so a malformed CMS link can't crash the app.
   private var validStreamURL: URL? {
       guard let url = URL(string: stream.url),
             let scheme = url.scheme?.lowercased(),
             ["https", "http"].contains(scheme)
       else { return nil }
       return url
   }

   var body: some View {

       Button {
           if validStreamURL != nil {
               showVideo = true
           }
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
           if let url = validStreamURL {
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
