import SwiftUI

/// A shimmering placeholder shown during the first load, in place of a spinner —
/// it previews the shape of the cards about to arrive, so the panel eases from
/// "empty" to "full" instead of popping. Pure chrome: no data, not interactive.
struct SkeletonList: View {
    var count = 3
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                if i > 0 { Hairline() }
                SkeletonCard(spec: Self.specs[i % Self.specs.count])
            }
            Spacer(minLength: 0)
        }
        // One synchronized breath across the whole stack — gentle, not a strobe.
        .opacity(pulse ? 1 : 0.6)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Loading pull requests")
    }

    /// A few hand-picked width sets so the placeholder stack reads as natural
    /// content rather than identical rows. (Panel is a fixed 400pt wide.)
    private static let specs: [SkeletonCard.Spec] = [
        .init(badge:  96, title: (236, 132), repo: 150, summary: (340, 212), branch: 196, stats: [72, 96, 64]),
        .init(badge:  84, title: (204, 150), repo: 122, summary: (300, 150), branch: 150, stats: [72, 100]),
        .init(badge: 108, title: (216, 100), repo: 168, summary: (326, 176), branch: 172, stats: [72, 92, 72]),
    ]
}

/// One placeholder card. Mirrors `PRCard` row-for-row — same gutter, padding, and
/// stacking, with bar heights matching each text style — so the skeleton occupies
/// the same footprint as a real card and there's no layout jump on arrival.
private struct SkeletonCard: View {
    struct Spec {
        var badge: CGFloat
        var title: (CGFloat, CGFloat)
        var repo: CGFloat
        var summary: (CGFloat, CGFloat)
        var branch: CGFloat
        var stats: [CGFloat]
    }

    let spec: Spec
    private static let fill = Color.appText.opacity(0.09)

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Layout.accentBar)   // matches the card's priority gutter
            VStack(alignment: .leading, spacing: Layout.base) {
                bar(spec.badge, 20, radius: 10)          // size / priority badge

                HStack(alignment: .top, spacing: Layout.base) {   // avatar + title (headline)
                    Circle().fill(Self.fill).frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: Layout.tight) {
                        bar(spec.title.0, 14)
                        bar(spec.title.1, 14)
                    }
                }

                bar(spec.repo, 13)                       // repo · number

                VStack(alignment: .leading, spacing: Layout.tight) {   // summary / rationale
                    bar(spec.summary.0, 13)
                    bar(spec.summary.1, 13)
                }

                bar(spec.branch, 13)                     // branch → base

                HStack(spacing: Layout.base) {           // stats + status
                    ForEach(Array(spec.stats.enumerated()), id: \.offset) { _, w in
                        bar(w, 16, radius: 8)
                    }
                }
            }
            .padding(.vertical, Layout.generous)
            .padding(.leading, Layout.margin - Layout.accentBar)   // align with real cards
            .padding(.trailing, Layout.margin)
        }
    }

    private func bar(_ width: CGFloat, _ height: CGFloat, radius: CGFloat = 4) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Self.fill)
            .frame(width: width, height: height)
    }
}

#Preview {
    SkeletonList()
        .frame(width: 400, height: 600)
        .background(Color.appBackground)
}
