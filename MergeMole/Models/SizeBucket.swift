import Foundation

/// Native size classification derived purely from line counts — no AI involved.
///
/// Per PLAN.md we always show the AI effort tier *next to* this native bucket,
/// never instead of it. The contrast between "this PR is 40 lines" and "this PR
/// will take real effort" is the feature, so size lives on the data, not the AI.
enum SizeBucket: String, CaseIterable, Sendable, Comparable {
    case xs = "XS"
    case s  = "S"
    case m  = "M"
    case l  = "L"
    case xl = "XL"

    /// Ordered smallest → largest by declaration order.
    static func < (lhs: SizeBucket, rhs: SizeBucket) -> Bool {
        guard let l = allCases.firstIndex(of: lhs),
              let r = allCases.firstIndex(of: rhs) else { return false }
        return l < r
    }

    /// GitHub-style thresholds on total changed lines (additions + deletions).
    init(changedLines: Int) {
        switch changedLines {
        case ..<10:   self = .xs
        case ..<50:   self = .s
        case ..<250:  self = .m
        case ..<1000: self = .l
        default:      self = .xl
        }
    }

    var label: String { rawValue }
}
