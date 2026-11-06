import SwiftUI

/// Cost palette: 1 grey, 2 green, 3 blue, 4 purple, 5 gold. The app's only accent colors.
public enum CostColor {
    public static func color(for cost: Int) -> Color {
        switch cost {
        case 1: Color(red: 0.62, green: 0.64, blue: 0.68)
        case 2: Color(red: 0.20, green: 0.75, blue: 0.40)
        case 3: Color(red: 0.20, green: 0.55, blue: 0.95)
        case 4: Color(red: 0.70, green: 0.35, blue: 0.95)
        case 5: Color(red: 0.98, green: 0.76, blue: 0.22)
        default: unknown
        }
    }

    /// Border for slots whose champion isn't in the catalog.
    public static let unknown = Color(white: 0.35)
}

/// Solid dark surfaces (no Liquid Glass).
public enum Surface {
    public static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    public static let card = Color(red: 0.10, green: 0.10, blue: 0.12)
    public static let raised = Color(red: 0.15, green: 0.15, blue: 0.18)
}
