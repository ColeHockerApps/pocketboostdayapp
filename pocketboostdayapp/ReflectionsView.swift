import Combine
import SwiftUI
import Foundation



// UI/Reflections/ReflectionsView.swift

public struct ReflectionsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel

    // Read current reflections directly from the shared store (source of truth)
    @StateObject private var store = LocalStore.shared

    @State private var inputText: String = ""
    @State private var showClearConfirm: Bool = false

    private let maxLen = 160

    public init() {}

    public var body: some View {
        let th = themeManager.theme

        VStack(spacing: th.metrics.spacingL) {

            header(th)

            addCard(th)

            listCard(th)

            Spacer(minLength: th.metrics.spacingXL)
        }
        .padding(.horizontal, th.metrics.spacingL)
        .padding(.top, th.metrics.spacingL)
        .background(th.palette.background.ignoresSafeArea())
        .confirmationDialog(
            "Clear all reflections?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear all", role: .destructive) {
                clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved reflections.")
        }
    }

    // MARK: - Header

    private func header(_ th: AppTheme) -> some View {
        HStack {
            Text("Reflections")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(th.palette.textPrimary)
            Spacer()
            Image(systemName: "text.justify")
                .font(.title2)
                .foregroundStyle(th.palette.accentGradient)
                .padding(10)
                .background(th.palette.card, in: RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous))
        }
    }

    // MARK: - Add new reflection

    private func addCard(_ th: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: th.metrics.spacingM) {
            Text("What made your day good?")
                .font(.headline)
                .foregroundStyle(th.palette.textPrimary)

            HStack(spacing: th.metrics.spacingM) {
                TextField("Write one line…", text: $inputText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .lineLimit(3...4)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous)
                            .fill(th.palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous)
                            .stroke(th.palette.divider, lineWidth: 1)
                    )
                    .onChange(of: inputText) { _, new in
                        if new.count > maxLen {
                            inputText = String(new.prefix(maxLen))
                            haptics.selection()
                        }
                    }

                Button {
                    submit()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(AccentIconButtonStyle(theme: th))
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }

            HStack {
                Text("\(inputText.count)/\(maxLen)")
                    .font(.caption)
                    .foregroundStyle(th.palette.textSecondary)
                Spacer()
                Button {
                    showClearConfirm = true
                } label: {
                    Label("Clear all", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(SoftButtonStyle(theme: th, role: .destructive))
            }
        }
        .themedCard(th)
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            haptics.warning()
            return
        }
        vm.addReflection(text: text)
        inputText = ""
        haptics.tap()
    }

    private func clearAll() {
        // Delete via VM one by one to keep haptics consistent (single warning enough).
        let ids = store.reflections.map { $0.id }
        ids.forEach { vm.deleteReflection(id: $0) }
        haptics.warning()
    }

    // MARK: - List of reflections

    private func listCard(_ th: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: th.metrics.spacingM) {
            HStack {
                Label("Recent", systemImage: "clock")
                    .font(.headline)
                    .foregroundStyle(th.palette.textPrimary)
                Spacer()
                Text("\(store.reflections.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(th.palette.textSecondary)
            }

            // We show a clean list with swipe-to-delete behavior.
            List {
                ForEach(groupedByDay(store.reflections).indices, id: \.self) { sectionIdx in
                    let section = groupedByDay(store.reflections)[sectionIdx]
                    Section {
                        ForEach(section.items) { item in
                            ReflectionRow(entry: item, isToday: item.dayKey == appState.todayKey, theme: th)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(th.palette.card)
                                .swipeActions(allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        vm.deleteReflection(id: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(section.title)
                            .foregroundStyle(th.palette.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 240, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: th.metrics.cornerL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: th.metrics.cornerL, style: .continuous)
                    .stroke(th.palette.divider, lineWidth: 1)
            )
        }
        .themedCard(th)
    }

    // MARK: - Grouping

    private struct DaySection: Identifiable {
        let id: String
        let title: String
        let items: [ReflectionEntry]
    }

    private func groupedByDay(_ entries: [ReflectionEntry]) -> [DaySection] {
        let byDay = Dictionary(grouping: entries) { $0.dayKey }
        let sortedKeys = byDay.keys.sorted(by: >)
        return sortedKeys.map { key in
            let items = (byDay[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            let title: String = {
                if key == appState.todayKey { return "Today" }
                if let d = Formatters.dayKey.date(from: key) {
                    return Formatters.shortDay.string(from: d)
                }
                return key
            }()
            return DaySection(id: key, title: title, items: items)
        }
    }
}

// MARK: - Row

private struct ReflectionRow: View {
    let entry: ReflectionEntry
    let isToday: Bool
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.spacingM) {
            Image(systemName: isToday ? "sparkles" : "quote.opening")
                .foregroundStyle(isToday ? theme.palette.accent : theme.palette.textSecondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .foregroundStyle(theme.palette.textPrimary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timestamp(entry.createdAt))
                    .foregroundStyle(theme.palette.textSecondary)
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.metrics.spacingM)
        .padding(.vertical, 8)
    }

    private func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Button styles

private struct AccentIconButtonStyle: ButtonStyle {
    let theme: AppTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerL, style: .continuous)
                    .fill(theme.accentGradient)
            )
            .foregroundStyle(Color.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SoftButtonStyle: ButtonStyle {
    enum Role { case normal, destructive }
    let theme: AppTheme
    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        let stroke = role == .destructive ? theme.palette.danger : theme.palette.accent
        configuration.label
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerM, style: .continuous)
                    .fill(theme.palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerM, style: .continuous)
                    .stroke(stroke.opacity(0.6), lineWidth: 1)
            )
            .foregroundStyle(theme.palette.textPrimary)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
