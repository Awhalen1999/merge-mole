import SwiftUI

/// The MergeMole logo — the mole rising from its burrow, in the brand accent.
/// One definition so the panel header, the app-icon tile, and the connect screen
/// all use the identical mark. It's a template image, so the tint applies cleanly
/// and it scales crisply to any `size`.
struct BrandMark: View {
    var size: CGFloat = 18
    var tint: Color = .appAccent

    var body: some View {
        Image("HoleMole")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}
