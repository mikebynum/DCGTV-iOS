import SwiftUI

// Shared sponsor recognition for DCGTV's own broadcasts.
struct DCGLivestreamSponsorBanner: View {
    private let sponsorURL = URL(string: "https://www.charterbanker.com/")!

    var body: some View {
        Link(destination: sponsorURL) {
            VStack(spacing: 8) {
                Text("DCGTV Livestreams presented by")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Image("CharterBankLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 180)
                    .frame(height: 58)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            // Preserve the original logo's contrast even in dark mode.
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DCGTV livestreams presented by Charter Bank")
        .accessibilityHint("Opens the Charter Bank website")
    }
}
