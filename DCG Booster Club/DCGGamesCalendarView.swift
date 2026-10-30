
import SwiftUI
import WebKit

struct DCGGamesCalendarView: View {

    private let boundURL = URL(
        string: "https://www.gobound.com/ia/schools/dallascentergrimes"
    )!

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Label(
                    "DCG Varsity Sports",
                    systemImage: "calendar"
                )
                .font(.title2.bold())

                Spacer()
            }

            Text("Upcoming Mustang games and events")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DCGCalendarWebView()
                .frame(height: 600)
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )

            Link(destination: boundURL) {

                HStack {
                    Text("View Full Schedule on Bound")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.dcgRed)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct DCGCalendarWebView:
    UIViewRepresentable {

    private var calendarURL: URL {

        var components = URLComponents(
            string: "https://calendar.google.com/calendar/embed"
        )!

        components.queryItems = [
            URLQueryItem(
                name: "title",
                value: "DCG Varsity Sports"
            ),
            URLQueryItem(
                name: "ctz",
                value: "America/Chicago"
            ),
            URLQueryItem(
                name: "mode",
                value: "AGENDA"
            ),
            URLQueryItem(
                name: "showCalendars",
                value: "0"
            ),
            URLQueryItem(
                name: "showTabs",
                value: "0"
            ),
            URLQueryItem(
                name: "showPrint",
                value: "0"
            ),
            URLQueryItem(
                name: "src",
                value: "c_b5cf22dab2d4886b21fd76ef752dc305d6566f813634b082031ca918e62edd74@group.calendar.google.com"
            ),
            URLQueryItem(
                name: "src",
                value: "f0ad74vd79sts0hppltpdhehn6c54d8@import.calendar.google.com"
            )
        ]

        return components.url!
    }

    func makeUIView(
        context: Context
    ) -> WKWebView {

        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = true

        webView.load(
            URLRequest(url: calendarURL)
        )

        return webView
    }

    func updateUIView(
        _ uiView: WKWebView,
        context: Context
    ) {
    }
}
