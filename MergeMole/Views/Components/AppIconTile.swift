import SwiftUI

/// The rounded brand tile standing in for the app icon — a soft accent-tinted
/// square with the brand glyph. Shared by onboarding's welcome step and the About
/// pane. Corner radius + glyph scale track `size` so it reads right at any size.
struct AppIconTile: View {
    var size: CGFloat = 76

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.236, style: .continuous)
            .fill(Color.appAccent.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.appAccent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.236, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
    }
}
