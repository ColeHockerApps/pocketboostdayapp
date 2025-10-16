import Combine
import Foundation

// Pocket:Boost Day
// Resources/AdviceProvider.swift
//
// EN-only, local tips (no networking).
// Deterministic selection by day key to keep the “advice of the day” stable.

public enum AdviceProvider {

    /// Short, practical tips for mornings and focus.
    private static let advices: [String] = [
        // Hydration & breath
        "Take one deep breath before the first step.",
        "Drink a glass of water slowly, not in a rush.",
        "Inhale for 4, hold 2, exhale 6 — twice.",
        "Open a window for one minute of fresh air.",
        "Roll your shoulders back; breathe a bit deeper.",
        // Posture & movement
        "Stand tall for 10 seconds — posture wakes you up.",
        "Stretch your neck gently left and right.",
        "Do 10 slow calf raises while you wait.",
        "Walk 60 steps indoors to warm up the body.",
        "Loosen wrists and ankles; tiny moves count.",
        // Attention & focus
        "Put your phone face down for the first 10 minutes.",
        "Write a single line about your goal for today.",
        "Start with the smallest possible action.",
        "Ask: what would make today feel ‘launched’?",
        "Clear one tiny surface — desk, shelf, or inbox.",
        // Mindset & mood
        "Name how you feel; naming lowers the noise.",
        "Smile to yourself in the mirror. It helps.",
        "Say out loud: ‘I can start small.’",
        "Pick one win you can finish in 5 minutes.",
        "Progress over perfection — launch, then adjust.",
        // Energy & routine
        "Cold splash on the face; count 5 seconds.",
        "Warm your hands; rub palms until they tingle.",
        "Prepare your outfit or workspace for later.",
        "Make the bed — one tidy signal to the brain.",
        "Set a 10-minute timer and move until it rings.",
        // Clarity & planning
        "Choose three tasks, then highlight only one.",
        "Block 15 minutes for focus in your calendar.",
        "Write a ‘not today’ list — free your head.",
        "If it takes under 2 minutes, do it now.",
        "Plan your break before you start the work.",
        // Calm & recovery
        "Sip water; slow down the first five gulps.",
        "Sit still for 30 seconds and notice your breath.",
        "Lower your shoulders; unclench your jaw.",
        "Light stretch for the back: reach up, then forward.",
        "Say thanks for one small thing from yesterday.",
        // Environment
        "Tidy one square foot of space.",
        "Place your phone out of arm’s reach.",
        "Turn on softer light for a calmer start.",
        "Open curtains; let daylight do its work.",
        "Put a sticky note with today’s one goal where you see it."
    ]

    /// Returns a stable advice string for the provided day key (e.g., "yyyy-MM-dd").
    public static func adviceFor(dayKey: String) -> String {
        guard !advices.isEmpty else { return "Start with one small step." }
        let idx = stableIndex(for: dayKey, count: advices.count)
        return advices[idx]
    }

    /// Returns an advice string for any arbitrary seed (e.g., user id or session id).
    public static func adviceFor(seed: String) -> String {
        guard !advices.isEmpty else { return "Start with one small step." }
        let idx = stableIndex(for: seed, count: advices.count)
        return advices[idx]
    }

    /// Returns a random advice (non-deterministic).
    public static func randomAdvice() -> String {
        advices.randomElement() ?? "Start with one small step."
    }

    // MARK: - Helpers

    private static func stableIndex(for key: String, count: Int) -> Int {
        var hasher = Hasher()
        hasher.combine("pbday.advice")
        hasher.combine(key)
        let value = hasher.finalize()
        let positive = value == Int.min ? 0 : abs(value)
        return positive % max(count, 1)
    }
}
