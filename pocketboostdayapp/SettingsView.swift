import Combine
import SwiftUI
import Foundation
import UniformTypeIdentifiers



// UI/Settings/SettingsView.swift

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openURL) private var openURL

    @StateObject private var store = LocalStore.shared
    @State private var editMode: EditMode = .inactive

    @State private var newTitle: String = ""
    @State private var newEmoji: String = ""

    @State private var showDeleteAlert: Bool = false
    @State private var stepToDelete: RoutineStep?

    @State private var showImport = false
    @State private var exportItem: ExportItem? = nil // triggers share sheet

    @State private var showResetAllConfirm = false

    public init() {}

    public var body: some View {
        let th = themeManager.theme

        NavigationStack {
            List {
                stepsSection(th)
                appearanceSection(th)
               // notificationsSection(th)
               // dataSection(th)
                aboutSection(th)
            }
            .scrollContentBackground(.hidden)
            .background(th.palette.background.ignoresSafeArea())
            .environment(\.editMode, $editMode)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { toggleEditMode() }
                        haptics.selection()
                    } label: {
                        Text(editMode == .active ? "Done" : "Edit")
                    }
                }
            }
            .tint(th.palette.accent)
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    importBackup(from: url)
                case .failure:
                    haptics.error()
                }
            }
            .sheet(item: $exportItem) { item in
                ShareView(activityItems: [item.dataFileURL])
            }
            .alert("Remove step?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let s = stepToDelete { deleteStep(s) }
                }
                Button("Cancel", role: .cancel) { stepToDelete = nil }
            } message: {
                Text("This will remove the step from your routine.")
            }
        }
    }

    // MARK: - Sections

    private func stepsSection(_ th: AppTheme) -> some View {
        Section {
            ForEach(store.steps) { step in
                StepEditorRow(
                    step: step,
                    theme: th,
                    onChangeTitle: { title in
                        var s = step; s.title = title
                        vm.updateStep(s)
                    },
                    onChangeEmoji: { emoji in
                        var s = step; s.emoji = emoji
                        vm.updateStep(s)
                    },
                    onToggleActive: { isOn in
                        var s = step; s.isActive = isOn
                        if willViolateMinActiveDisable(current: s, togglingTo: isOn) {
                            haptics.warning()
                        } else {
                            vm.updateStep(s)
                            haptics.selection()
                        }
                    },
                    onDelete: {
                        stepToDelete = step
                        showDeleteAlert = true
                    }
                )
            }
            .onMove(perform: moveSteps(_:_:))

            // Add new
            HStack(spacing: th.metrics.spacingM) {
                TextField("Title (e.g., Water)", text: $newTitle)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                TextField("Emoji", text: $newEmoji)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)
                    .onChange(of: newEmoji) { _, v in
                        // keep only first grapheme cluster
                        if v.count > 2 { newEmoji = String(v.prefix(2)) }
                    }

                Spacer(minLength: 0)
                Button {
                    addStep()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .disabled(!canAddStep)
                .opacity(canAddStep ? 1 : 0.5)
            }
        } header: {
            HStack {
                Label("Routine Steps", systemImage: "slider.horizontal.3")
                Spacer()
                Text("\(store.steps.filter{$0.isActive}.count) active")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Keep \(AppConstants.minSteps)–\(AppConstants.maxSteps) simple steps.")
                Text("You currently have \(store.steps.count) steps.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func appearanceSection(_ th: AppTheme) -> some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { ThemeKind(rawValue: store.settings.theme.rawValue) ?? .dark },
                set: { newKind in
                    vm.updateSettings { $0.theme = .init(rawValue: newKind.rawValue) ?? .dark }
                    themeManager.set(newKind)
                })) {
                    ForEach(ThemeKind.allCases) { kind in
                        HStack {
                            Text(kind.title)
                            Spacer()
                            ThemeDot(kind: kind)
                        }
                        .tag(kind)
                    }
                }
                .pickerStyle(.navigationLink)

            Toggle(isOn: Binding(
                get: { store.settings.hapticsOn },
                set: { on in
                    vm.updateSettings { $0.hapticsOn = on }
                    haptics.isEnabled = on
                    haptics.selection()
                })
            ) {
                Label("Haptics", systemImage: "waveform.path")
            }

            Toggle(isOn: Binding(
                get: { store.settings.soundOn },
                set: { on in
                    vm.updateSettings { $0.soundOn = on }
                    haptics.selection()
                })
            ) {
                Label("Sound", systemImage: "speaker.wave.2.fill")
            }
        }
    }

    private func notificationsSection(_ th: AppTheme) -> some View {
        Section("Reminder") {
            let bindingTime = Binding<Date>(
                get: {
                    let t = store.settings.remindAt ?? TimeOfDay(hour: 7, minute: 30)
                    return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
                },
                set: { newDate in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                    let h = comps.hour ?? 7, m = comps.minute ?? 30
                    vm.updateSettings { $0.remindAt = TimeOfDay(hour: h, minute: m) }
                    // Schedule (NotificationScheduler will be added as a service file)
                    NotificationScheduler.shared.scheduleDailyReminder(hour: h, minute: m)
                    haptics.selection()
                })

            DatePicker("Morning check", selection: bindingTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)

            Button {
                NotificationScheduler.shared.requestAuthorization()
                haptics.tap()
            } label: {
                Label("Enable notifications", systemImage: "bell.badge.fill")
            }
        }
    }

    private func dataSection(_ th: AppTheme) -> some View {
        Section("Data") {
            Button {
                do {
                    let data = try store.exportBackup()
                    exportItem = ExportItem(data: data, suggestedName: "PocketBoostDayBackup.json")
                    haptics.selection()
                } catch {
                    haptics.error()
                }
            } label: {
                Label("Export backup", systemImage: "square.and.arrow.up")
            }

            Button {
                showImport = true
                haptics.selection()
            } label: {
                Label("Import backup", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showResetAllConfirm = true
                haptics.warning()
            } label: {
                Label("Reset all data", systemImage: "trash")
            }
            .confirmationDialog(
                "Reset all data?",
                isPresented: $showResetAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    vm.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears steps, progress, mood, and reflections.")
            }
        }
    }

    private func aboutSection(_ th: AppTheme) -> some View {
        Section("About") {
//            HStack {
//                Label("App", systemImage: "sparkles")
//                Spacer()
//                Text(AppConstants.appName)
//                    .foregroundStyle(.secondary)
//            }
            HStack {
                Label("Version", systemImage: "number")
                Spacer()
                Text("1.01")
                    .foregroundStyle(.secondary)
            }
            Button {
                if let url = URL(string: "https://www.termsfeed.com/live/303df008-c4ed-4c30-8173-2fc58abcb937") {
                    haptics.tap()
                    openURL(url)
                } else {
                    haptics.error()
                }
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
//            NavigationLink {
//                PrivacyPolicyView() // will be provided in Resources/PrivacyPolicyView.swift
//            } label: {
//                Label("Privacy Policy", systemImage: "hand.raised.fill")
//            }
        }
    }

    // MARK: - Actions

    private var canAddStep: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !newEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && store.steps.count < AppConstants.maxSteps
    }

    private func addStep() {
        guard canAddStep else { haptics.warning(); return }
        vm.addStep(title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                   emoji: newEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
                   isActive: true)
        newTitle = ""
        newEmoji = ""
        haptics.tap()
    }

    private func deleteStep(_ step: RoutineStep) {
        // Prevent deleting below minimum active steps
        let activeCount = store.steps.filter { $0.isActive }.count
        if step.isActive && activeCount <= AppConstants.minSteps {
            haptics.warning()
            return
        }
        vm.removeStep(id: step.id)
        stepToDelete = nil
        haptics.warning()
    }

    private func moveSteps(_ source: IndexSet, _ dest: Int) {
        vm.reorderSteps(from: source, to: dest)
    }

    private func toggleEditMode() {
        editMode = (editMode == .active) ? .inactive : .active
    }

    private func willViolateMinActiveDisable(current step: RoutineStep, togglingTo isOn: Bool) -> Bool {
        guard step.isActive, isOn == false else { return false }
        let activeCount = store.steps.filter { $0.isActive }.count
        // if we turn this one OFF and activeCount would drop below min
        return activeCount <= AppConstants.minSteps
    }

    private func importBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try store.importBackup(data, merge: false)
            haptics.success()
        } catch {
            haptics.error()
        }
    }
}

// MARK: - Step Row Editor

private struct StepEditorRow: View {
    @State var step: RoutineStep
    let theme: AppTheme

    var onChangeTitle: (String) -> Void
    var onChangeEmoji: (String) -> Void
    var onToggleActive: (Bool) -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: theme.metrics.spacingM) {
            TextField("Emoji", text: Binding(
                get: { step.emoji },
                set: { v in
                    step.emoji = v
                    if v.count > 2 { step.emoji = String(v.prefix(2)) }
                    onChangeEmoji(step.emoji)
                })
            )
            .frame(width: 56)
            .multilineTextAlignment(.center)

            TextField("Title", text: Binding(
                get: { step.title },
                set: { v in
                    step.title = v
                    onChangeTitle(v)
                })
            )
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)

            Spacer(minLength: 8)

            Toggle(isOn: Binding(
                get: { step.isActive },
                set: { v in
                    // We reflect the change only after external validation
                    onToggleActive(v)
                    step.isActive = v
                })
            ) {
//                Text("Active")
//                    .font(.caption)
//                    .foregroundStyle(theme.palette.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: theme.palette.accent))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.palette.danger)
        }
    }
}

// MARK: - Theme dot indicator

private struct ThemeDot: View {
    let kind: ThemeKind
    var body: some View {
        let color: Color = {
            switch kind {
            case .dark:  return Color(hex: 0x6C8CFF)
            case .space: return Color(hex: 0x53E0E8)
            case .light: return Color(hex: 0x5B7CFF)
            }
        }()
        return Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

// MARK: - Share sheet

private struct ShareView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let dataFileURL: URL

    init(data: Data, suggestedName: String) {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        try? data.write(to: tmpURL, options: .atomic)
        self.dataFileURL = tmpURL
    }
}

// MARK: - Notification Scheduler stub (real service will exist in Services/NotificationScheduler.swift)

fileprivate final class NotificationScheduler {
    static let shared = NotificationScheduler()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Launch your day"
        content.body = "Mark your routine and mood."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: "pbday.morning", content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }
}
