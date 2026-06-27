import Foundation

/// Spacing + radius scale. One place to tune density, same as colors live in one
/// place. Views use these names, never raw numbers, so the rhythm stays even.
enum Layout {
    static let hair: CGFloat   = 2   // around hairlines
    static let tight: CGFloat  = 4   // within a tight group
    static let snug: CGFloat   = 6   // between pills
    static let base: CGFloat   = 8   // between rows / sections
    static let roomy: CGFloat  = 12  // card padding, list gaps
    static let generous: CGFloat = 16  // airier outer margin for the sectioned list

    static let cardRadius: CGFloat = 10
    static let accentBar: CGFloat = 3  // a card's priority edge-bar width

    static let controlHeight: CGFloat = 24  // header buttons share one height
    static let controlRadius: CGFloat = 6   // …and one corner radius
    static let headerHeight: CGFloat = 40   // the panel's top bar

    /// The panel's left/right margin. The header, tab bar, and card content all
    /// align to it, so everything shares one vertical edge.
    static var margin: CGFloat { generous }
}
