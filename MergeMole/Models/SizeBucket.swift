import Foundation

/// Native size classification derived purely from line counts — no AI involved.
///
/// The raw +/− line counts are the always-on size reference on the card; this
/// bucket pill is the at-a-glance version of that. Size lives on the data, not the
/// AI, so it reads the same whether AI is on or off.
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

    /// Spelled-out size for the card's size badge ("Extra Small" … "Extra Large").
    var longLabel: String {
        switch self {
        case .xs: return "Extra Small"
        case .s:  return "Small"
        case .m:  return "Medium"
        case .l:  return "Large"
        case .xl: return "Extra Large"
        }
    }

    /// How many of the five magnitude bars to ink (xs → 1 … xl → 5).
    var barCount: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}
