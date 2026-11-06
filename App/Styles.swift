import PinCompUI
import SwiftUI

/// Solid filled button; avoids the system's glass button styles.
struct SolidButtonStyle: ButtonStyle {
    var fill: Color = Surface.raised
    var foreground: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(fill, in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// Solid near-black navigation bar instead of the default translucent/glass one.
    func solidNavigationBar() -> some View {
        toolbarBackground(Surface.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

extension Text {
    static func relativeTime(_ date: Date?) -> Text {
        guard let date else { return Text("Never") }
        return Text(date, format: .relative(presentation: .named))
    }
}
