import Combine
import Foundation
import UIKit

// Pocket:Boost Day
// AppCore/HapticsManager.swift

@MainActor
public final class HapticsManager: ObservableObject {

    // MARK: - Singleton
    public static let shared = HapticsManager()

    // MARK: - Published settings
    @Published public var isEnabled: Bool = true {
        didSet { if isEnabled { prepare() } }
    }

    // MARK: - Generators (cached)
    private var selectionGen = UISelectionFeedbackGenerator()
    private var notifyGen    = UINotificationFeedbackGenerator()
    private var lightGen     = UIImpactFeedbackGenerator(style: .light)
    private var mediumGen    = UIImpactFeedbackGenerator(style: .medium)
    private var heavyGen     = UIImpactFeedbackGenerator(style: .heavy)
    private var softGen: UIImpactFeedbackGenerator?  = {
        if #available(iOS 13.0, *) { return UIImpactFeedbackGenerator(style: .soft) }
        return nil
    }()
    private var rigidGen: UIImpactFeedbackGenerator? = {
        if #available(iOS 13.0, *) { return UIImpactFeedbackGenerator(style: .rigid) }
        return nil
    }()

    // MARK: - Throttle (avoid over-vibration)
    private var lastFire: [String: TimeInterval] = [:]
    private let minImpactInterval: TimeInterval = 0.05
    private let minNotifyInterval: TimeInterval = 0.20

    // MARK: - Init
    private init() {
        prepare()
    }

    // MARK: - Public API (simple defaults)

    /// Subtle tap for generic button interactions.
    public func tap() {
        impact(.light)
    }

    /// Highlight changes in segmented controls or list selection.
    public func selection() {
        guard isEnabled, shouldFire(key: "selection", minInterval: minImpactInterval) else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// Strong confirmation (e.g., routine completed → rocket launch).
    public func success() {
        notify(.success)
    }

    /// Non-blocking warning (e.g., trying to reset week).
    public func warning() {
        notify(.warning)
    }

    /// Error feedback (e.g., invalid action).
    public func error() {
        notify(.error)
    }

    /// Fine-grained control for impact styles.
    public func impact(_ style: ImpactStyle) {
        guard isEnabled, shouldFire(key: "impact.\(style.rawValue)", minInterval: minImpactInterval) else { return }

        switch style {
        case .light:
            lightGen.impactOccurred()
            lightGen.prepare()
        case .medium:
            mediumGen.impactOccurred()
            mediumGen.prepare()
        case .heavy:
            heavyGen.impactOccurred()
            heavyGen.prepare()
        case .soft:
            if let g = softGen {
                g.impactOccurred()
                g.prepare()
            } else {
                // Fallback for iOS < 13
                lightGen.impactOccurred()
                lightGen.prepare()
            }
        case .rigid:
            if let g = rigidGen {
                g.impactOccurred()
                g.prepare()
            } else {
                // Fallback for iOS < 13
                heavyGen.impactOccurred()
                heavyGen.prepare()
            }
        }
    }

    /// A composed, satisfying launch confirmation (rigid + success).
    public func launchSuccess() {
        impact(.rigid)
        success()
    }

    // MARK: - Utilities

    /// Recreate & pre-arm generators (best called on app start / enable).
    public func prepare() {
        selectionGen = UISelectionFeedbackGenerator()
        notifyGen    = UINotificationFeedbackGenerator()
        lightGen     = UIImpactFeedbackGenerator(style: .light)
        mediumGen    = UIImpactFeedbackGenerator(style: .medium)
        heavyGen     = UIImpactFeedbackGenerator(style: .heavy)
        if #available(iOS 13.0, *) {
            softGen  = UIImpactFeedbackGenerator(style: .soft)
            rigidGen = UIImpactFeedbackGenerator(style: .rigid)
        }

        selectionGen.prepare()
        notifyGen.prepare()
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        softGen?.prepare()
        rigidGen?.prepare()
    }

    // MARK: - Private

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled, shouldFire(key: "notify.\(type.rawValue)", minInterval: minNotifyInterval) else { return }
        notifyGen.notificationOccurred(type)
        notifyGen.prepare()
    }

    private func shouldFire(key: String, minInterval: TimeInterval) -> Bool {
        let now = CACurrentMediaTime()
        if let last = lastFire[key], now - last < minInterval {
            return false
        }
        lastFire[key] = now
        return true
    }

    // MARK: - Types

    public enum ImpactStyle: String {
        case light, medium, heavy, soft, rigid
    }
}
