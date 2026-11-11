import SwiftUI

struct StreamCardView: View {

   let stream: DCGStream
   let isStatusCurrent: Bool
   var isFeatured = false

    @State private var showVideo = false

   private var streamActionTitle: LocalizedStringKey {
       if stream.isLive {
           return isStatusCurrent ? "Watch Live" : "View Stream"
       } else if stream.status.lowercased() == "upcoming" {
           return "View Stream"
       } else {
           return "Watch Replay"
       }
   }

   // Only present HTTPS video URLs supplied by the CMS.
   private var validStreamURL: URL? {
       guard let url = URL(string: stream.url),
             let scheme = url.scheme?.lowercased(),
             scheme == "https"
       else { return nil }
       return url
   }

   var body: some View {

       Button {
           if validStreamURL != nil {
               showVideo = true
           }
       } label: {

           if isFeatured {
               featuredContent
           } else {
               compactContent
           }
       } // Closes Button

       .buttonStyle(.plain)
       .sheet(isPresented: $showVideo) {
           if let url = validStreamURL {
               VideoBrowserView(url: url)
                   .ignoresSafeArea()
           }
       }
   }

   private var compactContent: some View {
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
                       isStatusCurrent ? "LIVE NOW" : "LIVE AT LAST UPDATE",
                       systemImage: "circle.fill"
                   )
                   .font(.caption2.bold())
                   .foregroundStyle(isStatusCurrent ? .red : .secondary)
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

   }

   // The same CMS broadcast and playback sheet, presented more prominently on Home.
   private var featuredContent: some View {
       VStack(alignment: .leading, spacing: 0) {
           GeometryReader { geometry in
               AsyncImage(url: URL(string: stream.thumbnail)) { phase in
                   if case .success(let image) = phase {
                       image.resizable().scaledToFill()
                   } else {
                       Rectangle()
                           .fill(LinearGradient(colors: [Color(white: 0.12), Color.dcgRed.opacity(0.5)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                   }
               }
               .frame(width: geometry.size.width, height: geometry.size.height)
               .clipped()
           }
           .aspectRatio(16.0 / 9.0, contentMode: .fit)
           .accessibilityHidden(true)

           VStack(alignment: .leading, spacing: 4) {
               if stream.isLive {
                   Label(isStatusCurrent ? "LIVE NOW" : "LIVE AT LAST UPDATE",
                         systemImage: isStatusCurrent ? "dot.radiowaves.left.and.right" : "clock")
                       .font(.caption.bold())
                       .padding(.horizontal, 10)
                       .padding(.vertical, 6)
                       .background(isStatusCurrent ? Color.dcgRed : Color(white: 0.3),
                                   in: RoundedRectangle(cornerRadius: 6))
               }

               Text(stream.featuredTitle)
                   .font(.headline)
                   .accessibilityLabel(stream.title)
                   .fixedSize(horizontal: false, vertical: true)
               if let date = stream.startDate {
                   Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated)
                       .day().hour().minute())
                       .font(.caption)
                       .foregroundStyle(.white.opacity(0.85))
               }
               Label(stream.status.lowercased() == "upcoming" ? "View Upcoming Stream" : streamActionTitle,
                     systemImage: stream.status.lowercased() == "upcoming" ? "calendar" : "play.fill")
                   .font(.headline)
                   .frame(maxWidth: .infinity, minHeight: 44)
                   .background(Color.dcgRed, in: RoundedRectangle(cornerRadius: 12))
                   .padding(.top, 2)
           }
           .padding(.horizontal, 12)
           .padding(.vertical, 10)
       }
       .foregroundStyle(.white)
       .multilineTextAlignment(.leading)
       .frame(maxWidth: .infinity, alignment: .leading)
       .background(Color(white: 0.08))
       .clipShape(RoundedRectangle(cornerRadius: 20))
       .overlay {
           RoundedRectangle(cornerRadius: 20)
               .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
       }
       .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
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
