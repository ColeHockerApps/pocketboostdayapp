import Combine
import Foundation
import SwiftUI


// Models/DomainModels.swift
//
// NOTE:
// Core data structs (RoutineStep, DayRecord, ReflectionEntry, SettingsModel, TimeOfDay, StatsSnapshot)
// are defined in LocalStore.swift in this project to avoid duplicate symbols.
// This file provides complementary domain enums, helpers, and small utilities used across modules.

// MARK: - Day Key

public typealias DayKey = String // e.g., "2025-10-15"

// MARK: - Mood

public enum MoodLevel: Int, CaseIterable, Codable, Identifiable {
    case veryBad = 0
    case bad     = 1
    case neutral = 2
    case good    = 3
    case veryGood = 4

    public var id: Int { rawValue }

    public var emoji: String {
        switch self {
        case .veryBad:  return "😞"
        case .bad:      return "🙁"
        case .neutral:  return "😐"
        case .good:     return "🙂"
        case .veryGood: return "😄"
        }
    }

    public var title: String {
        switch self {
        case .veryBad:  return "Very bad"
        case .bad:      return "Bad"
        case .neutral:  return "Okay"
        case .good:     return "Good"
        case .veryGood: return "Great"
        }
    }
}

// MARK: - Advice (lightweight type for local tips)

public struct Advice: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - Stats helpers

public extension StatsSnapshot {
    /// Rounded average mood index (0…4). Returns nil if NaN.
    var averageMoodRounded: Int? {
        guard !averageMood.isNaN else { return nil }
        return max(0, min(4, Int((averageMood).rounded())))
    }

    /// Human-friendly label for average mood.
    var averageMoodLabel: String {
        guard let idx = averageMoodRounded else { return "—" }
        return MoodLevel(rawValue: idx)?.title ?? "—"
    }

    /// Emoji for average mood.
    var averageMoodEmoji: String {
        guard let idx = averageMoodRounded else { return "—" }
        return MoodLevel(rawValue: idx)?.emoji ?? "—"
    }
}

// MARK: - Routine helpers

public extension Array where Element == RoutineStep {
    /// IDs of active steps (preserving order).
    var activeIDs: [UUID] {
        self.filter { $0.isActive }.map { $0.id }
    }

    /// Count of active steps.
    var activeCount: Int {
        self.filter { $0.isActive }.count
    }
}

// MARK: - Formatting helpers

public enum Formatters {
    public static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "EEE, d MMM"
        return f
    }()
}

// MARK: - UI convenience

public struct AppConstants {
    public static let appName = "Pocket:Boost Day"
    public static let minSteps = 3
    public static let maxSteps = 5
}

// MARK: - Theme utilities (bridge to map mood → color)

public extension AppTheme {
    func color(for mood: MoodLevel) -> Color {
        switch mood {
        case .veryBad:  return Color(hex: 0xFF6B6B)
        case .bad:      return Color(hex: 0xFF9E6B)
        case .neutral:  return Color(hex: 0xF1D34E)
        case .good:     return Color(hex: 0x78D8A4)
        case .veryGood: return palette.accent
        }
    }
}
