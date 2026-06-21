import Foundation

extension Date {
    /// Compact age, GitHub-style: "now", "18m", "3h", "5d", "2w", "4mo", "1y".
    /// Pure and linear — no formatter object, no allocation per call.
    nonisolated var relativeShort: String {
        let s = max(0, Date.now.timeIntervalSince(self))
        switch s {
        case ..<60:          return "now"
        case ..<3_600:       return "\(Int(s / 60))m"
        case ..<86_400:      return "\(Int(s / 3_600))h"
        case ..<604_800:     return "\(Int(s / 86_400))d"
        case ..<2_592_000:   return "\(Int(s / 604_800))w"
        case ..<31_536_000:  return "\(Int(s / 2_592_000))mo"
        default:             return "\(Int(s / 31_536_000))y"
        }
    }
}
