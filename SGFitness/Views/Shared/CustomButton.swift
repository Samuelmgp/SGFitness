import SwiftUI

// MARK: - CustomButton
// Target folder: Views/Shared/
//
// A reusable styled button used across the app.
// Provides consistent sizing, color, and shape for primary and secondary actions.
// No ViewModel — this is a pure presentational component.

struct CustomButton: View {

    /// Button label text.
    let title: String

    /// SF Symbol name (optional).
    let systemImage: String?

    /// Visual style.
    let style: CustomButtonStyle

    /// Tap handler.
    let action: () -> Void

    enum CustomButtonStyle {
        case primary
        case secondary
        case destructive
    }

    init(
        _ title: String,
        systemImage: String? = nil,
        style: CustomButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Style Properties

    private var backgroundColor: Color {
        switch style {
        case .primary: return .accentColor
        case .secondary: return .secondary.opacity(0.15)
        case .destructive: return .red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
        case .destructive: return .white
        }
    }
}
