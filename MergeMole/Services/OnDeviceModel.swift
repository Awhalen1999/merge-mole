import Foundation

/// An OS-agnostic view of on-device AI availability. Everything outside the Foundation
/// Models layer talks to this, so no other file needs a macOS-version or
/// framework-availability check. On macOS below 26 — where Foundation Models doesn't
/// exist — this resolves without ever referencing the framework.
enum OnDeviceAvailability: Equatable {
    case available
    case requiresNewerOS      // macOS < 26: Foundation Models isn't present
    case appleIntelligenceOff // supported, but turned off in System Settings
    case downloading          // enabled, model assets still downloading
    case deviceNotEligible    // hardware/configuration can't run Apple Intelligence
    case unavailable          // any reason a future OS reports that we don't map yet

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// One-line reason for the Settings note, or nil when on-device AI is available.
    /// Stated as fact — it names *why*, without prescribing a fix that may not apply.
    var reason: String? {
        switch self {
        case .available:            return nil
        case .requiresNewerOS:      return "Requires macOS 26 (Tahoe) or later."
        case .appleIntelligenceOff: return "Apple Intelligence is turned off."
        case .downloading:          return "The on-device model is still downloading."
        case .deviceNotEligible:    return "This Mac isn't eligible for Apple Intelligence."
        case .unavailable:          return "On-device AI isn't available right now."
        }
    }
}

/// The single seam to the on-device model. All `@available(macOS 26, *)` and
/// `FoundationModels` usage lives behind these two calls, so the rest of the app stays
/// OS-agnostic and there's exactly one place that knows the framework exists.
enum OnDeviceModel {
    /// Current availability. Safe to read on any macOS version, and cheap enough to
    /// call while views render — it reports status and never loads the model.
    static var availability: OnDeviceAvailability {
        guard #available(macOS 26, *) else { return .requiresNewerOS }
        return FoundationModelsEngine.availability
    }

    /// An engine to run verdicts, or nil unless the model is actually usable right now.
    static func makeEngine() -> VerdictEngine? {
        guard #available(macOS 26, *), case .available = FoundationModelsEngine.availability else {
            return nil
        }
        return FoundationModelsEngine()
    }
}
