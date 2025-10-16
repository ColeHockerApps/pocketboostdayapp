import Combine
import SwiftUI
import Foundation

// Pocket:Boost Day
// UI/Components/MoodPickerView.swift
//
// Reusable horizontal mood picker (0…4) with colored highlight and haptics.
// - Bind to optional Int? where 0=😞 … 4=😄, nil = not selected.
// - Uses ThemeManager + HapticsManager via EnvironmentObjects.
// - Minimal animations; accessible labels for VoiceOver.

public struct MoodPickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @Binding private var selected: Int?
    private let allowDeselect: Bool

    private struct Item: Identifiable {
        let id: Int
        let emoji: String
        let title: String
    }

    private let items: [Item] = [
        .init(id: 0, emoji: "😞", title: "Very bad"),
        .init(id: 1, emoji: "🙁", title: "Bad"),
        .init(id: 2, emoji: "😐", title: "Okay"),
        .init(id: 3, emoji: "🙂", title: "Good"),
        .init(id: 4, emoji: "😄", title: "Great")
    ]

    public init(selected: Binding<Int?>, allowDeselect: Bool = false) {
        self._selected = selected
        self.allowDeselect = allowDeselect
    }

    public var body: some View {
        let th = themeManager.theme
        HStack(spacing: th.metrics.spacingM) {
            ForEach(items) { item in
                let isSel = (item.id == selected)
                Button {
                    if isSel, allowDeselect {
                        selected = nil
                    } else {
                        selected = item.id
                    }
                    haptics.selection()
                } label: {
                    Text(item.emoji)
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous)
                                .fill(isSel ? th.moodColor(index: item.id).opacity(0.25) : th.palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous)
                                .stroke(isSel ? th.moodColor(index: item.id) : th.palette.divider, lineWidth: isSel ? 2 : 1)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSel)
                        .accessibilityLabel(Text(item.title))
                        .accessibilityAddTraits(isSel ? [.isSelected, .isButton] : [.isButton])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview (kept for development builds)

#Preview {
    @State var selection: Int? = 3
    let theme = ThemeManager(default: .dark)
    return VStack(spacing: 16) {
        MoodPickerView(selected: $selection)
            .environmentObject(theme)
            .environmentObject(HapticsManager.shared)
            .padding()
            .background(theme.theme.palette.background)
        Text("Selected: \(selection.map(String.init) ?? "nil")")
            .foregroundStyle(theme.theme.palette.textSecondary)
    }
    .preferredColorScheme(.dark)
}
