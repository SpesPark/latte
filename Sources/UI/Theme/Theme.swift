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
        public static let accentAwake = Color.orange
        public static let accentAsleep = Color.secondary
    }

    public enum Fonts {
        public static let header = Font.system(size: 14, weight: .semibold)
        public static let body = Font.system(size: 13, weight: .regular)
        public static let caption = Font.system(size: 11, weight: .regular).monospacedDigit()
    }

    public enum Sizes {
        public static let menuBarWidth: CGFloat = 280
        public static let cupView: CGFloat = 64
    }
}
