import Combine
import Foundation


// AppCore/AppState.swift

@MainActor
public final class AppState: ObservableObject {

    // MARK: - Tabs

    public enum AppTab: String, CaseIterable, Identifiable {
        case today
        case routine
        case stats
        case reflections
        case settings

        public var id: String { rawValue }

        /// SF Symbols icon name for TabBar
        public var systemIcon: String {
            switch self {
            case .today:       return "sparkles"
            case .routine:     return "flame.fill"
            case .stats:       return "chart.bar.fill"
            case .reflections: return "text.justify"
            case .settings:    return "gearshape.fill"
            }
        }

        /// Short, user-facing title (EN only as requested)
        public var title: String {
            switch self {
            case .today:       return "Today"
            case .routine:     return "Routine"
            case .stats:       return "Stats"
            case .reflections: return "Reflections"
            case .settings:    return "Settings"
            }
        }
    }

    // MARK: - Published State

    /// Currently selected tab
    @Published public var selectedTab: AppTab = .today

    /// Start-of-day (local) for "today"
    @Published public private(set) var today: Date

    /// A simple day key like "2025-10-15" for storage grouping
    @Published public private(set) var todayKey: String

    // MARK: - Private

    private var bag = Set<AnyCancellable>()
    private let calendar = Calendar.current
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Init

    public init(now: Date = Date()) {
        let start = Calendar.current.startOfDay(for: now)
        self.today = start
        self.todayKey = Self.makeKey(from: start)

        // Keep "today" fresh across midnight boundaries with a lightweight timer
        // (fires every 60s; cheap and reliable without notifications)
        Timer
            .publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshDayIfNeeded()
            }
            .store(in: &bag)
    }

    // MARK: - API

    public func select(tab: AppTab) {
        selectedTab = tab
    }

    /// Recompute start-of-day & key if device date has crossed midnight.
    public func refreshDayIfNeeded(reference now: Date = Date()) {
        let newStart = calendar.startOfDay(for: now)
        guard newStart != today else { return }
        today = newStart
        todayKey = Self.makeKey(from: newStart)
    }

    // MARK: - Helpers

    private static func makeKey(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
