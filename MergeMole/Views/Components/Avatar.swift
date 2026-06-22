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

/// A compact, overlapping stack of requested-reviewer avatars — "who still owes a
/// review." Caps at four with a +N overflow so a crowded PR doesn't run wide.
struct ReviewerAvatars: View {
    let reviewers: [PRReviewer]
    var size: CGFloat = 16

    private var shown: [PRReviewer] { Array(reviewers.prefix(4)) }
    private var overflow: Int { reviewers.count - shown.count }

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(shown) { reviewer in
                Avatar(url: reviewer.avatarURL, size: size)
                    .overlay(Circle().strokeBorder(Color.appSurface, lineWidth: 1.5))
                    .help(reviewer.login)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.appTextSecondary)
                    .padding(.leading, size * 0.35 + 3)
            }
        }
    }
}
