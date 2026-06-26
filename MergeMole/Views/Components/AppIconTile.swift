import SwiftUI

/// The rounded brand tile standing in for the app icon — a soft accent-tinted
/// square with the mole logo. Shared by onboarding's welcome step and the About
/// pane. Corner radius + mark scale track `size` so it reads right at any size.
struct AppIconTile: View {
    var size: CGFloat = 76

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.236, style: .continuous)
            .fill(Color.appAccent.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(BrandMark(size: size * 0.52))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.236, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
    }
}
