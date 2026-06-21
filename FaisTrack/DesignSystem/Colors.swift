import SwiftUI

extension Color {
    static let ftAccent = Color("AccentRed")         // #FF2D2D
    static let ftAccentOrange = Color("AccentOrange") // #FF6B00
    static let ftBackground = Color("Background")
    static let ftCard = Color("Card")
    static let ftTextPrimary = Color("TextPrimary")
    static let ftTextSecondary = Color("TextSecondary")

    static let ftGradient = LinearGradient(
        colors: [.ftAccent, .ftAccentOrange],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let speedGreen = Color.green
    static let speedOrange = Color.orange
    static let speedRed = Color.red

    static func speedColor(for kmh: Double) -> Color {
        if kmh < 60 { return .speedGreen }
        if kmh < 100 { return .speedOrange }
        return .speedRed
    }
}
