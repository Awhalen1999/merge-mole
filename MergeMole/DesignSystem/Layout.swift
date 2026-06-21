import Foundation

/// Spacing + radius scale. One place to tune density, same as colors live in one
/// place. Views use these names, never raw numbers, so the rhythm stays even.
enum Layout {
    static let hair: CGFloat   = 2   // around hairlines
    static let tight: CGFloat  = 4   // within a tight group
    static let snug: CGFloat   = 6   // between pills
    static let base: CGFloat   = 8   // between rows / sections
    static let roomy: CGFloat  = 12  // card padding, list gaps

    static let cardRadius: CGFloat = 10
}
