import SwiftUI

enum RepSyncTheme {
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x1A1A1A)
    static let card = Color(hex: 0x2C2C2E)
    static let cardElevated = Color(hex: 0x3A3A3C)
    static let primaryGreen = Color(hex: 0x8DAF8E)
    static let primaryGreenDark = Color(hex: 0x7E9D7C)
    static let destructive = Color(hex: 0xC48B8B)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xB0B0B0)
    static let textOnLight = Color(hex: 0x1C1C1E)
    static let textOnLightSecondary = Color(hex: 0x6C6C6E)
    static let cardLight = Color(hex: 0xD1D1D6)
    static let input = Color(hex: 0x48484A)
    static let divider = Color(hex: 0x48484A)
    static let checkmark = Color(hex: 0x6BBF6B)
    static let calendarWorkoutDay = primaryGreen
}

extension Color {
    init(hex: UInt64) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
