import SwiftUI

/// A circular GitHub avatar. Falls back to a neutral person glyph while loading or
/// when the URL is missing, so the card layout never shifts. Loads over the same
/// HTTPS the app already uses for the API; URLSession's cache handles re-scrolls.
struct Avatar: View {
    let url: URL?
    var size: CGFloat = 22

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.appHairline, lineWidth: 0.5))
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.appText.opacity(0.08))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.appTextTertiary)
            )
    }
}
