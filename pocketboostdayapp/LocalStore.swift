import Combine
import Foundation

// Pocket:Boost Day
// Storage/LocalStore.swift

@MainActor
public final class LocalStore: ObservableObject {

    // MARK: - Singleton

    public static let shared = LocalStore()

    // MARK: - Published state (single source of truth)

    @Published public private(set) var steps: [RoutineStep] = []
    @Published public private(set) var dayRecords: [String: DayRecord] = [:] // key: "yyyy-MM-dd"
    @Published public private(set) var reflections: [ReflectionEntry] = []    // latest first
    @Published public private(set) var settings: SettingsModel = .defaults

    // MARK: - Storage

    private let ud: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Keys

    private enum K {
        static let steps       = "pbday.steps.v1"
        static let dayRecords  = "pbday.dayrecords.v1"
        static let reflections = "pbday.reflections.v1"
        static let settings    = "pbday.settings.v1"
        static let backupHint  = "pbday.backup.version" // not used, reserved
    }

    // MARK: - Init

    private init(userDefaults: UserDefaults = .standard) {
        self.ud = userDefaults
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        loadAll()
        ensureDefaultStepsIfNeeded()
        migrateIfNeeded()
    }

    // MARK: - Loading

    private func loadAll() {
        if let data = ud.data(forKey: K.steps),
           let decoded = try? decoder.decode([RoutineStep].self, from: data) {
            steps = decoded
        }

        if let data = ud.data(forKey: K.dayRecords),
           let decoded = try? decoder.decode([String: DayRecord].self, from: data) {
            dayRecords = decoded
        }

        if let data = ud.data(forKey: K.reflections),
           let decoded = try? decoder.decode([ReflectionEntry].self, from: data) {
            reflections = decoded
        }

        if let data = ud.data(forKey: K.settings),
           let decoded = try? decoder.decode(SettingsModel.self, from: data) {
            settings = decoded
        }
    }

    // MARK: - Save helpers

    private func saveSteps() {
        if let data = try? encoder.encode(steps) { ud.set(data, forKey: K.steps) }
        objectWillChange.send()
    }

    private func saveDayRecords() {
        if let data = try? encoder.encode(dayRecords) { ud.set(data, forKey: K.dayRecords) }
        objectWillChange.send()
    }

    private func saveReflections() {
        if let data = try? encoder.encode(reflections) { ud.set(data, forKey: K.reflections) }
        objectWillChange.send()
    }

    private func saveSettings() {
        if let data = try? encoder.encode(settings) { ud.set(data, forKey: K.settings) }
        objectWillChange.send()
    }

    // MARK: - Defaults

    private func ensureDefaultStepsIfNeeded() {
        guard steps.isEmpty else { return }
        steps = [
            RoutineStep(id: UUID(), title: "Water",   emoji: "💧", isActive: true),
            RoutineStep(id: UUID(), title: "Stretch", emoji: "🧘‍♂️", isActive: true),
            RoutineStep(id: UUID(), title: "Wash",    emoji: "🚿", isActive: true)
        ]
        saveSteps()
    }

    private func migrateIfNeeded() {
        // room for future migrations; currently none
    }

    // MARK: - Public API — Steps

    public func setSteps(_ new: [RoutineStep]) {
        steps = new
        saveSteps()
    }

    public func addStep(title: String, emoji: String, isActive: Bool = true) {
        var s = steps
        s.append(.init(id: UUID(), title: title, emoji: emoji, isActive: isActive))
        steps = s
        saveSteps()
    }

    public func updateStep(_ step: RoutineStep) {
        guard let idx = steps.firstIndex(where: { $0.id == step.id }) else { return }
        steps[idx] = step
        saveSteps()
    }

    public func removeStep(id: UUID) {
        steps.removeAll { $0.id == id }
        // also clean from dayRecords
        for key in dayRecords.keys {
            dayRecords[key]?.completedStepIds.removeAll { $0 == id }
        }
        saveSteps()
        saveDayRecords()
    }

    public func reorderSteps(from source: IndexSet, to destination: Int) {
        // Локальная перестановка без SwiftUI
        var arr = steps

        // 1) Берём элементы по исходным индексам (в возрастающем порядке)
        let moving = source.sorted().map { arr[$0] }

        // 2) Удаляем их из массива (по убыванию индексов, чтобы не смещать оставшиеся)
        for i in source.sorted(by: >) {
            arr.remove(at: i)
        }

        // 3) Корректируем целевой индекс с учётом удаления элементов слева от destination
        var dest = destination
        for i in source {
            if i < destination { dest -= 1 }
        }
        dest = max(0, min(dest, arr.count))

        // 4) Вставляем перемещаемый блок на новое место
        arr.insert(contentsOf: moving, at: dest)

        steps = arr
        saveSteps()
    }


    // MARK: - Public API — Day

    /// Ensure record exists for a day and return it.
    public func record(for dayKey: String) -> DayRecord {
        if let r = dayRecords[dayKey] { return r }
        let r = DayRecord(key: dayKey, completedStepIds: [], mood: nil)
        dayRecords[dayKey] = r
        saveDayRecords()
        return r
    }

    public func toggleStep(for dayKey: String, stepId: UUID, completed: Bool? = nil) {
        var r = record(for: dayKey)
        let isCompleted = completed ?? !r.completedStepIds.contains(stepId)
        if isCompleted {
            if !r.completedStepIds.contains(stepId) {
                r.completedStepIds.append(stepId)
            }
        } else {
            r.completedStepIds.removeAll { $0 == stepId }
        }
        dayRecords[dayKey] = r
        saveDayRecords()
    }

    public func setMood(for dayKey: String, moodIndex: Int?) {
        var r = record(for: dayKey)
        r.mood = moodIndex
        dayRecords[dayKey] = r
        saveDayRecords()
    }

    public func clearDay(_ dayKey: String) {
        dayRecords[dayKey] = DayRecord(key: dayKey, completedStepIds: [], mood: nil)
        saveDayRecords()
    }

    // MARK: - Public API — Reflections

    public func addReflection(text: String, dayKey: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = ReflectionEntry(id: UUID(), dayKey: dayKey, text: trimmed, createdAt: Date())
        reflections.insert(entry, at: 0)
        saveReflections()
    }

    public func deleteReflection(id: UUID) {
        reflections.removeAll { $0.id == id }
        saveReflections()
    }

    public func reflections(limit: Int? = nil) -> [ReflectionEntry] {
        guard let limit else { return reflections }
        return Array(reflections.prefix(limit))
    }

    // MARK: - Public API — Stats

    /// Compute a 7-day snapshot ending at `endDayKey` (inclusive).
    public func weeklySnapshot(endDayKey: String, activeStepIds: [UUID]? = nil) -> StatsSnapshot {
        let ids = activeStepIds ?? steps.filter { $0.isActive }.map { $0.id }
        let keys = Self.lastNDaysKeys(7, endKey: endDayKey)

        var bars: [Int] = []
        var moods: [Int] = []
        var streak = 0
        var currentStreak = 0

        for key in keys {
            let r = dayRecords[key]
            let count = r?.completedStepIds.filter { ids.contains($0) }.count ?? 0
            bars.append(count)

            if let m = r?.mood { moods.append(m) }

            // streak logic: all active steps completed
            let totalActive = ids.count
            if totalActive > 0, count >= totalActive {
                currentStreak += 1
                streak = currentStreak
            } else if key == endDayKey {
                // if the end day is not fully completed, streak = currentStreak (no reset here)
            } else {
                currentStreak = 0
            }
        }

        let avgMood: Double = {
            guard !moods.isEmpty else { return .nan }
            return Double(moods.reduce(0, +)) / Double(moods.count)
        }()

        return StatsSnapshot(streak: streak, weeklyProgress: bars, averageMood: avgMood)
    }

    public func resetWeek(ending endDayKey: String) {
        let keys = Self.lastNDaysKeys(7, endKey: endDayKey)
        for k in keys { dayRecords[k] = DayRecord(key: k, completedStepIds: [], mood: nil) }
        saveDayRecords()
    }

    public func resetAll() {
        steps.removeAll()
        dayRecords.removeAll()
        reflections.removeAll()
        settings = .defaults
        saveSteps()
        saveDayRecords()
        saveReflections()
        saveSettings()
        ensureDefaultStepsIfNeeded()
    }

    // MARK: - Public API — Settings

    public func updateSettings(_ modify: (inout SettingsModel) -> Void) {
        var s = settings
        modify(&s)
        settings = s
        saveSettings()
    }

    // MARK: - Export / Import (JSON)

    public func exportBackup() throws -> Data {
        let payload = Backup(
            version: 1,
            exportedAt: Date(),
            steps: steps,
            dayRecords: dayRecords,
            reflections: reflections,
            settings: settings
        )
        return try encoder.encode(payload)
    }

    public func importBackup(_ data: Data, merge: Bool = false) throws {
        let incoming = try decoder.decode(Backup.self, from: data)

        if merge {
            // merge steps: add incoming if not present by id
            var mergedSteps = steps
            for s in incoming.steps where !mergedSteps.contains(where: { $0.id == s.id }) {
                mergedSteps.append(s)
            }
            steps = mergedSteps

            // merge day records (prefer newer by created key presence)
            for (k, v) in incoming.dayRecords {
                if var existing = dayRecords[k] {
                    // union of completed ids, prefer incoming mood if not nil
                    let union = Array(Set(existing.completedStepIds + v.completedStepIds))
                    existing.completedStepIds = union
                    if let mood = v.mood { existing.mood = mood }
                    dayRecords[k] = existing
                } else {
                    dayRecords[k] = v
                }
            }

            // merge reflections (by id)
            var mergedRefl = reflections
            for r in incoming.reflections where !mergedRefl.contains(where: { $0.id == r.id }) {
                mergedRefl.append(r)
            }
            // keep latest first
            reflections = mergedRefl.sorted { $0.createdAt > $1.createdAt }

            // settings: keep current, but adopt missing fields if needed (none for now)
        } else {
            steps = incoming.steps
            dayRecords = incoming.dayRecords
            reflections = incoming.reflections.sorted { $0.createdAt > $1.createdAt }
            settings = incoming.settings
        }

        saveSteps()
        saveDayRecords()
        saveReflections()
        saveSettings()
    }

    // MARK: - Utilities

    public static func dayKey(from date: Date, tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    public static func lastNDaysKeys(_ n: Int, endKey: String) -> [String] {
        guard n > 0 else { return [] }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: endKey) else { return [endKey] }

        var keys: [String] = []
        for i in stride(from: n - 1, through: 0, by: -1) {
            if let d = Calendar.current.date(byAdding: .day, value: -i, to: endDate) {
                keys.append(formatter.string(from: d))
            }
        }
        return keys
    }
}

// MARK: - Models

public struct RoutineStep: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var emoji: String
    public var isActive: Bool
}

public struct DayRecord: Codable, Equatable {
    public var key: String              // "yyyy-MM-dd"
    public var completedStepIds: [UUID] // subset of active steps
    public var mood: Int?               // 0…4
}

public struct ReflectionEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    public var dayKey: String
    public var text: String
    public var createdAt: Date
}

public struct SettingsModel: Codable, Equatable {
    public var hapticsOn: Bool
    public var soundOn: Bool
    public var theme: ThemePreference
    public var remindAt: TimeOfDay? // optional local reminder time

    public static let defaults = SettingsModel(
        hapticsOn: true,
        soundOn: true,
        theme: .dark,                 // Dark by default as requested
        remindAt: TimeOfDay(hour: 7, minute: 30)
    )

    public enum ThemePreference: String, Codable, CaseIterable {
        case dark
        case space
        case light
    }
}

public struct TimeOfDay: Codable, Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }
}

public struct StatsSnapshot: Codable, Equatable {
    public var streak: Int
    public var weeklyProgress: [Int] // 7 values, completed steps per day
    public var averageMood: Double   // NaN if no mood data
}

// MARK: - Backup container

private struct Backup: Codable {
    let version: Int
    let exportedAt: Date
    let steps: [RoutineStep]
    let dayRecords: [String: DayRecord]
    let reflections: [ReflectionEntry]
    let settings: SettingsModel
}
