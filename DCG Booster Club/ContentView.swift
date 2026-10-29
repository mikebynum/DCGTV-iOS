import SwiftUI
import WebKit
import UIKit
import Combine

// MARK: - DCG Brand Colors

extension Color {
    static let dcgRed = Color(
        red: 200.0 / 255.0,
        green: 16.0 / 255.0,
        blue: 46.0 / 255.0
    )
}

// MARK: - App Tabs

enum AppTab: Int, CaseIterable, Identifiable {

    case home
    case dcgtv
    case memberships
    case volunteer

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .dcgtv: return "DCGTV"
        case .memberships: return "Memberships"
        case .volunteer: return "Volunteer"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dcgtv: return "play.rectangle.fill"
        case .memberships: return "ticket.fill"
        case .volunteer: return "hands.sparkles.fill"
        }
    }

    var url: URL {
        switch self {
        case .home:
            return URL(string:
                "https://dcgboosterclub.com/")!

        case .dcgtv:
            return URL(string:
                "https://dcgtv.com/")!

        case .memberships:
            return URL(string:
                "https://dcgboosterclub.com/memberships/")!

        case .volunteer:
            return URL(string:
                "https://dcgboosterclub.com/volunteer/")!
        }
    }
}

// MARK: - Browser Model

@MainActor
final class BrowserModel: ObservableObject {

    @Published var isLoading = true
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var errorMessage: String?

    let webView: WKWebView
    let homeURL: URL

    init(url: URL) {

        self.homeURL = url

        let configuration = WKWebViewConfiguration()

        configuration.defaultWebpagePreferences
            .allowsContentJavaScript = true

        webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        // Enable swipe gestures for Back and Forward
        webView.allowsBackForwardNavigationGestures = true

        // Enable vertical bouncing for pull-to-refresh
        webView.scrollView.alwaysBounceVertical = true

        // Native pull-to-refresh
        let refreshControl = UIRefreshControl()

        refreshControl.tintColor = UIColor(
            red: 200.0 / 255.0,
            green: 16.0 / 255.0,
            blue: 46.0 / 255.0,
            alpha: 1
        )

        refreshControl.addTarget(
            self,
            action: #selector(pulledToRefresh),
            for: .valueChanged
        )

        webView.scrollView.refreshControl = refreshControl
    }

    func loadHome() {

        errorMessage = nil

        let request = URLRequest(
            url: homeURL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 30
        )

        isLoading = true
        webView.load(request)
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    func refresh() {

        errorMessage = nil

        if webView.url == nil {
            loadHome()
        } else {
            webView.reload()
        }
    }

    @objc private func pulledToRefresh() {
        refresh()
    }

    func updateNavigation() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func finishLoading() {

        isLoading = false

        webView.scrollView
            .refreshControl?
            .endRefreshing()

        updateNavigation()
    }
}

// MARK: - WebView

struct DCGWebView: UIViewRepresentable {

    @ObservedObject var browser: BrowserModel

    func makeCoordinator() -> Coordinator {
        Coordinator(browser: browser)
    }

    func makeUIView(context: Context) -> WKWebView {

        let webView = browser.webView

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        browser.loadHome()

        return webView
    }

    func updateUIView(
        _ uiView: WKWebView,
        context: Context
    ) {
        // Preserve the current browser and page.
    }

    // MARK: - WebView Coordinator

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate {

        let browser: BrowserModel

        init(browser: BrowserModel) {
            self.browser = browser
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            browser.isLoading = true
            browser.errorMessage = nil
            browser.updateNavigation()
        }

        func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            browser.updateNavigation()
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            browser.errorMessage = nil
            browser.finishLoading()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleError(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleError(error)
        }

        private func handleError(_ error: Error) {

            let nsError = error as NSError

            if nsError.code == NSURLErrorCancelled {
                return
            }

            browser.errorMessage = error.localizedDescription
            browser.finishLoading()
        }

        // Handle links that open new browser windows.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {

            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {

                if url.scheme == "https" ||
                   url.scheme == "http" {

                    webView.load(
                        URLRequest(url: url)
                    )

                } else {
                    UIApplication.shared.open(url)
                }
            }

            return nil
        }

        // Handle links to external apps.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {

            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased()
            else {
                decisionHandler(.allow)
                return
            }

            if ["https", "http", "about", "blob", "data"]
                .contains(scheme) {

                decisionHandler(.allow)

            } else {

                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - Browser Screen

struct BrowserScreen: View {

    let tab: AppTab

    @StateObject private var browser: BrowserModel

    init(tab: AppTab) {

        self.tab = tab

        _browser = StateObject(
            wrappedValue: BrowserModel(url: tab.url)
        )
    }

    var body: some View {

        VStack(spacing: 0) {

            // Website content
            ZStack {

                DCGWebView(browser: browser)

                // Loading indicator
                if browser.isLoading {

                    VStack(spacing: 12) {

                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.dcgRed)

                        Text("Loading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }

                // Error display
                if let error = browser.errorMessage {

                    VStack(spacing: 16) {

                        Image(
                            systemName: "wifi.exclamationmark"
                        )
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                        Text("Unable to Load Page")
                            .font(.headline)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            browser.refresh()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.dcgRed)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
            }

            // Browser navigation toolbar
            HStack(spacing: 20) {

                Button {
                    browser.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!browser.canGoBack)
                .accessibilityLabel("Go Back")

                Button {
                    browser.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!browser.canGoForward)
                .accessibilityLabel("Go Forward")

                Spacer()

                Text(tab.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    browser.loadHome()
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("Tab Home")

                Button {
                    browser.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Page")
            }
            .font(.system(size: 18))
            .foregroundStyle(Color.dcgRed)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}



// MARK: - Main App View

struct ContentView: View {

   @State private var selectedTab: AppTab = .home

   var body: some View {

       TabView(selection: $selectedTab) {

           // Native Home Screen

           HomeView(selectedTab: $selectedTab)
               .tabItem {
                   Label(
                       "Home",
                       systemImage: "house.fill"
                   )
               }
               .tag(AppTab.home)

           // Native DCGTV Screen

           DCGTVView()
               .tabItem {
                   Label(
                       "DCGTV",
                       systemImage: "play.rectangle.fill"
                   )
               }
               .tag(AppTab.dcgtv)

           // Existing WordPress Screens

           ForEach(
               AppTab.allCases.filter {
                   $0 != .home && $0 != .dcgtv
               }
           ) { tab in

               BrowserScreen(tab: tab)
                   .tabItem {
                       Label(
                           tab.title,
                           systemImage: tab.icon
                       )
                   }
                   .tag(tab)
           }
       }
       .tint(Color.dcgRed)
   }
}

// MARK: - Preview

#Preview {
   ContentView()
}
