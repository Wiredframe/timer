import SwiftUI

extension Color {
    /// Lime accent: start button, toggle, the work liquid.
    static let brand = Color(hex: 0x9EF01A)
    /// Accent for text and symbols: darker on light backgrounds for contrast.
    static let brandText = Color(light: 0x4A8F00, dark: 0x9EF01A)
    /// Dark ink for text on lime.
    static let ink = Color(hex: 0x0E1A00)

    /// The rising liquid in the rest phase, and the text colour on top of it.
    /// The screens themselves stay neutral (white / black).
    static let liquidRest = Color(hex: 0x1FD8E0)
    static let inkRest = Color(hex: 0x00191A)
    /// Rest label in the setup: darker aqua on light backgrounds for contrast.
    static let restLabel = Color(light: 0x0A8F96, dark: 0x1FD8E0)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// "mm:ss", or "h:mm:ss" from one hour on.
func mmss(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
    return String(format: "%02d:%02d", s / 60, s % 60)
}
