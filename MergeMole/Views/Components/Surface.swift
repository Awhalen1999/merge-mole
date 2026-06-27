import SwiftUI

extension View {
    /// The app's standard surface card — `appSurface` fill, hairline border, and the
    /// shared card radius. `padded` adds the standard inner inset; pass `false` for
    /// full-bleed row lists so their dividers run edge-to-edge. One definition so
    /// every card (Settings sections, the AI/radio cards) stays identical.
    func cardSurface(padded: Bool = true) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(padded ? Layout.roomy : 0)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardRadius)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
    }
}
