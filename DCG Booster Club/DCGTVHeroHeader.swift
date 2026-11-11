import SwiftUI

/// The bundled, unaltered IMG_3188 photograph is decorative; branding is read once.
struct DCGTVHeroHeader: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                // Fit the entire group horizontally. Only the lower body/foreground
                // is cropped on wider iPads; aspect-fill would cut off outer faces
                // on narrow phones. Dimensions match the original 1206 × 894 photo.
                let photoHeight = width * 894 / 1206

                ZStack(alignment: .top) {
                    Color(red: 0.08, green: 0.14, blue: 0.23)

                    Image("MustangPrideHero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: photoHeight)
                        .offset(y: max(0, height - photoHeight))

                    // Darken the sky for branding, leaving faces lightly shaded.
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.74), location: 0),
                            .init(color: .black.opacity(0.38), location: 0.27),
                            .init(color: .clear, location: 0.48),
                            .init(color: .black.opacity(0.08), location: 0.72),
                            .init(color: .black.opacity(0.60), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image("DCGTVLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width < 600 ? 112 : 190)
                        .padding(.top, 14)
                }
                .clipped()
            }
            .frame(height: horizontalSizeClass == .regular ? 400 : 270)

            // A flexible tagline band preserves the photo crop at every text size.
            Text("Mustang pride. Wherever you are.")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dcgRed)
                .frame(height: 3)
                .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DCGTV. Mustang pride. Wherever you are.")
        .accessibilityAddTraits(.isHeader)
    }
}
