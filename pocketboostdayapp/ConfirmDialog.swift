import Combine
import SwiftUI
import Foundation


// UI/Components/ConfirmDialog.swift
//
// Reusable confirmation dialog utilities.
// - View modifier: .confirmDialog(...)
// - Convenience ConfirmButton that shows a dialog before executing action.
//
// Uses SwiftUI's native ConfirmationDialog (iOS 15+).

// MARK: - Modifier

public struct ConfirmDialogModifier: ViewModifier {
    @Binding var isPresented: Bool

    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let confirmRole: ButtonRole
    let onConfirm: () -> Void

    public func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(confirmTitle, role: confirmRole) {
                    onConfirm()
                }
                Button(cancelTitle, role: .cancel) { }
            } message: {
                if let message {
                    Text(message)
                }
            }
    }
}

public extension View {
    /// Attach a reusable confirmation dialog to any view.
    /// - Parameters:
    ///   - isPresented: Binding to present/dismiss dialog.
    ///   - title: Title shown at the top.
    ///   - message: Optional message text.
    ///   - confirmTitle: Text for the confirm button (default "Confirm").
    ///   - cancelTitle: Text for the cancel button (default "Cancel").
    ///   - confirmRole: Role for confirm button (default .destructive).
    ///   - onConfirm: Action executed only when user confirms.
    func confirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        confirmRole: ButtonRole = .destructive,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmDialogModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            confirmRole: confirmRole,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Convenience Confirm Button

/// A button that asks for confirmation before running `action`.
public struct ConfirmButton<Label: View>: View {
    private let title: String
    private let message: String?
    private let confirmTitle: String
    private let cancelTitle: String
    private let confirmRole: ButtonRole
    private let role: ButtonRole?
    private let action: () -> Void
    private let label: () -> Label

    @State private var showDialog = false

    /// - Parameters:
    ///   - title: Dialog title.
    ///   - message: Optional dialog message.
    ///   - confirmTitle: Confirm button title (default "Confirm").
    ///   - cancelTitle: Cancel button title (default "Cancel").
    ///   - confirmRole: Confirm button role (default .destructive).
    ///   - role: Optional role for the outer button (e.g., .destructive).
    ///   - action: Executed when user confirms.
    ///   - label: Button label view.
    public init(
        title: String,
        message: String? = nil,
        confirmTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        confirmRole: ButtonRole = .destructive,
        role: ButtonRole? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.confirmRole = confirmRole
        self.role = role
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(role: role) {
            showDialog = true
        } label: {
            label()
        }
        .confirmDialog(
            isPresented: $showDialog,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            confirmRole: confirmRole,
            onConfirm: action
        )
    }
}

// MARK: - Preview (kept for development only)

#Preview("ConfirmDialog Demo") {
    struct DemoView: View {
        @State private var show = false
        @State private var result = "—"

        var body: some View {
            VStack(spacing: 16) {
                Button("Show confirm") { show = true }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                ConfirmButton(
                    title: "Reset week?",
                    message: "This will clear the last 7 days of progress and mood.",
                    confirmTitle: "Reset",
                    cancelTitle: "Cancel",
                    confirmRole: .destructive
                ) {
                    result = "Reset performed"
                } label: {
                    Label("ConfirmButton", systemImage: "trash")
                }

                Text("Result: \(result)")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .confirmDialog(
                isPresented: $show,
                title: "Are you sure?",
                message: "Custom dialog via modifier.",
                confirmTitle: "Do it",
                cancelTitle: "Nope",
                confirmRole: .destructive
            ) {
                result = "Did it"
            }
        }
    }

    return DemoView()
        .preferredColorScheme(.dark)
}
