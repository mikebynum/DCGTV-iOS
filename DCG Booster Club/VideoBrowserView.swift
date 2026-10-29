
import SwiftUI
import SafariServices

struct VideoBrowserView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(
        context: Context
    ) -> SFSafariViewController {

        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false

        let browser = SFSafariViewController(
            url: url,
            configuration: configuration
        )

        browser.preferredControlTintColor = UIColor(
            red: 200 / 255,
            green: 16 / 255,
            blue: 46 / 255,
            alpha: 1
        )

        return browser
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {
    }
}
