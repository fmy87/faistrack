import SwiftUI
import UIKit

enum ToastType {
    case success, error, info, achievement
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ToastType

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// A single global toast + haptic system, called from anywhere in the app.
/// Deliberately pairs the two together — every success/error moment should
/// feel *and* look confirmed, and wiring both separately at every call site
/// would just mean half of them eventually get one but not the other.
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published private(set) var current: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func showSuccess(_ text: String) {
        show(ToastMessage(text: text, type: .success))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showError(_ text: String) {
        show(ToastMessage(text: text, type: .error))
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func showInfo(_ text: String) {
        show(ToastMessage(text: text, type: .info))
    }

    /// A distinct heavier haptic than plain success — reserved for genuine
    /// "this is a big deal" moments (new record, achievement unlocked)
    /// rather than every routine save.
    func showAchievement(_ text: String) {
        show(ToastMessage(text: text, type: .achievement))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func show(_ message: ToastMessage) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            current = message
        }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                current = nil
            }
        }
    }
}

/// Renders whatever ToastManager currently has queued — mounted once at the
/// root of the authenticated app (see MainTabView) so a toast can appear
/// over any tab or screen, rather than needing to be added individually to
/// every view that might want to show one.
struct ToastOverlayView: View {
    @ObservedObject private var manager = ToastManager.shared

    var body: some View {
        VStack {
            if let toast = manager.current {
                HStack(spacing: 10) {
                    Image(systemName: icon(for: toast.type))
                    Text(toast.text)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(14)
                .background(background(for: toast.type))
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(manager.current == nil)
    }

    private func icon(for type: ToastType) -> String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .achievement: return "trophy.fill"
        }
    }

    private func background(for type: ToastType) -> Color {
        switch type {
        case .success: return .speedGreen
        case .error: return .speedRed
        case .info: return .ftAccent
        case .achievement: return .ftAccentOrange
        }
    }
}
