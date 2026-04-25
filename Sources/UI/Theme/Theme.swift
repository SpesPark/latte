import AppKit
import SwiftUI

public enum Theme {

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 16
    }

    public enum Colors {
        public static let coffee = Color(red: 0.36, green: 0.20, blue: 0.09)
        public static let foam = Color(red: 0.96, green: 0.93, blue: 0.85)
        public static let cup = Color(red: 0.95, green: 0.95, blue: 0.97)
        /// Caramel accent for active state. Built from a dynamic `NSColor`
        /// so the brand color stays consistent regardless of the user's
        /// system tint, with light/dark variants resolved per-appearance.
        public static let accentAwake = Color(nsColor: NSColor(name: "AccentAwake") { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0.62, green: 0.40, blue: 0.18, alpha: 1.0)
                : NSColor(srgbRed: 0.42, green: 0.24, blue: 0.08, alpha: 1.0)
        })

        /// Dynamic stroke color for `CoffeeCupView`. Canvas does not always
        /// resolve `Color.primary` against the current appearance, so we use
        /// `NSColor.labelColor` directly to guarantee light/dark adaptation.
        public static let cupStroke = Color(nsColor: NSColor.labelColor.withAlphaComponent(0.55))
        public static let accentAsleep = Color.secondary
    }

    public enum Fonts {
        /// Hero / About-tab title. Use sparingly.
        public static let title = Font.system(size: 17, weight: .semibold)
        /// Section title in the menu bar header and Settings sections.
        public static let header = Font.system(size: 14, weight: .semibold)
        /// Above-body emphasis (Picker labels, secondary actions).
        public static let subheadline = Font.system(size: 12, weight: .medium)
        /// Default body text inside the menu bar window and Settings tabs.
        public static let body = Font.system(size: 13, weight: .regular)
        /// Timestamps, footnotes, "until …" subtitles. Monospaced digits so
        /// numbers don't jitter as they tick.
        public static let caption = Font.system(size: 11, weight: .regular).monospacedDigit()
    }

    public enum Sizes {
        public static let menuBarWidth: CGFloat = 280
        public static let cupView: CGFloat = 64
    }
}
