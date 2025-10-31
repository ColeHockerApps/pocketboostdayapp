import Combine
import Foundation
import SwiftUI


// ViewModels/AppViewModel.swift

@MainActor
public final class AppViewModel: ObservableObject {

    // MARK: - Dependencies

    private let store: LocalStore
    private let appState: AppState
    private let haptics: HapticsManager

    // MARK: - Published UI State

    @Published public private(set) var steps: [RoutineStep] = []
    @Published public private(set) var todayRecord: DayRecord
    @Published public private(set) var stats: StatsSnapshot
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var progress: Double = 0.0     // 0…1
    @Published public private(set) var isRoutineComplete: Bool = false
    @Published public private(set) var moodIndex: Int? = nil      // 0…4

    // Derived lists
    public var activeSteps: [RoutineStep] { steps.filter { $0.isActive } }
    public var activeStepIDs: [UUID] { activeSteps.map { $0.id } }

    // MARK: - Combine

    private var bag = Set<AnyCancellable>()

    // MARK: - Init

    public init(store: LocalStore = .shared,
                appState: AppState,
                haptics: HapticsManager = .shared)
    {
        self.store = store
        self.appState = appState
        self.haptics = haptics

        // ❗️Важно: никаких обращений к self.* пока не проставили все свойства.
        let stepsNow = store.steps
        let key = appState.todayKey
        let record = store.record(for: key)
        let activeIDs = stepsNow.filter { $0.isActive }.map { $0.id }
        let statsNow = store.weeklySnapshot(endDayKey: key, activeStepIds: activeIDs)
        let progressNow = Self.computeProgress(completed: record.completedStepIds, active: activeIDs)
        let isCompleteNow = Self.computeIsComplete(completed: record.completedStepIds, active: activeIDs)

        // Инициализируем все @Published свойства
        self.steps = stepsNow
        self.todayRecord = record
        self.stats = statsNow
        self.streak = statsNow.streak
        self.progress = progressNow
        self.isRoutineComplete = isCompleteNow
        self.moodIndex = record.mood

        bind()
    }

    // MARK: - Bindings

    private func bind() {

        // Keep steps in sync
        store.$steps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSteps in
                guard let self else { return }
                self.steps = newSteps
                self.recomputeFromToday()
            }
            .store(in: &bag)

        // Keep day records in sync → update today record + progress
        store.$dayRecords
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadTodayRecord()
            }
            .store(in: &bag)

        // React to day change (midnight tick from AppState)
        appState.$todayKey
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadTodayRecord()
            }
            .store(in: &bag)
    }

    // MARK: - Public API — Routine

    public func toggleStep(_ stepId: UUID) {
        let key = appState.todayKey
        let beforeComplete = isRoutineComplete

        store.toggleStep(for: key, stepId: stepId)

        // Local immediate feedback
        haptics.tap()

        // After store updates, we recompute
        reloadTodayRecord()

        // If became complete just now → launch confirmation
        if !beforeComplete && isRoutineComplete {
            haptics.launchSuccess()
        }
    }

    public func setMood(_ index: Int?) {
        let key = appState.todayKey
        store.setMood(for: key, moodIndex: index)
        moodIndex = index
        haptics.selection()
        // stats might use mood average → recompute
        recomputeStats()
    }

    public func clearToday() {
        let key = appState.todayKey
        store.clearDay(key)
        reloadTodayRecord()
        haptics.warning()
    }

    // MARK: - Public API — Steps editing (Settings)

    public func setSteps(_ new: [RoutineStep]) {
        store.setSteps(new)
        haptics.selection()
    }

    public func addStep(title: String, emoji: String, isActive: Bool = true) {
        store.addStep(title: title, emoji: emoji, isActive: isActive)
        haptics.tap()
    }

    public func updateStep(_ step: RoutineStep) {
        store.updateStep(step)
        haptics.selection()
    }

    public func removeStep(id: UUID) {
        store.removeStep(id: id)
        haptics.warning()
    }

    public func reorderSteps(from source: IndexSet, to destination: Int) {
        store.reorderSteps(from: source, to: destination)
        haptics.selection()
    }

    // MARK: - Public API — Reflections

    public func addReflection(text: String) {
        let key = appState.todayKey
        store.addReflection(text: text, dayKey: key)
        haptics.tap()
    }

    public func deleteReflection(id: UUID) {
        store.deleteReflection(id: id)
        haptics.warning()
    }

    // MARK: - Public API — Stats

    public func weeklySnapshot() -> StatsSnapshot {
        store.weeklySnapshot(endDayKey: appState.todayKey, activeStepIds: activeStepIDs)
    }

    public func resetWeek() {
        store.resetWeek(ending: appState.todayKey)
        haptics.warning()
        recomputeStats()
        reloadTodayRecord()
    }

    public func resetAll() {
        store.resetAll()
        haptics.error()
        recomputeFromToday()
    }

    // MARK: - Public API — Settings

    public var settings: SettingsModel { store.settings }

    public func updateSettings(_ modify: (inout SettingsModel) -> Void) {
        store.updateSettings(modify)
        haptics.selection()
    }

    // MARK: - Private recomputations

    private func reloadTodayRecord() {
        let key = appState.todayKey
        let record = store.record(for: key)
        todayRecord = record
        moodIndex = record.mood
        recomputeProgress(using: record)
        recomputeStats()
    }

    private func recomputeFromToday() {
        reloadTodayRecord()
        recomputeStats()
    }

    private func recomputeProgress(using record: DayRecord) {
        let p = Self.computeProgress(completed: record.completedStepIds, active: activeStepIDs)
        progress = p
        isRoutineComplete = Self.computeIsComplete(completed: record.completedStepIds, active: activeStepIDs)
    }

    private func recomputeStats() {
        let s = store.weeklySnapshot(endDayKey: appState.todayKey, activeStepIds: activeStepIDs)
        stats = s
        streak = s.streak
    }

    // MARK: - Static helpers

    private static func computeProgress(completed: [UUID], active: [UUID]) -> Double {
        guard !active.isEmpty else { return 0 }
        let count = completed.filter { active.contains($0) }.count
        return Double(count) / Double(active.count)
    }

    private static func computeIsComplete(completed: [UUID], active: [UUID]) -> Bool {
        guard !active.isEmpty else { return false }
        let setC = Set(completed)
        return active.allSatisfy { setC.contains($0) }
    }
}
