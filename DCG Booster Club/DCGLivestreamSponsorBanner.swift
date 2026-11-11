import SwiftUI

// Shared sponsor recognition for DCGTV's own broadcasts.
struct DCGLivestreamSponsorBanner: View {
    private let sponsorURL = URL(string: "https://www.charterbanker.com/")!

    var body: some View {
        Link(destination: sponsorURL) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    acknowledgment
                    sponsorLogo
                }
                VStack(alignment: .leading, spacing: 4) {
                    acknowledgment
                    sponsorLogo
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
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
    private var acknowledgment: some View {
        Text("Presented by")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sponsorLogo: some View {
        Image("CharterBankLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 34)
            .accessibilityHidden(true)
    }

}
