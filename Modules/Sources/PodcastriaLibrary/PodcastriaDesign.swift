import SwiftUI

/// Semantic design tokens for Podcastria Library surfaces.
///
/// Derived from the directional wireframe (`docs/wireframes/Podcastria.dc.html`):
/// warm near-black surfaces, bone text, a single muted brass accent used only
/// for meaning (active state, progress, AI-organised markers), serif display
/// type and monospaced metadata. The wireframe is not an implementation
/// contract (D9); these tokens respect Dynamic Type and both colour schemes.
@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
public enum PodcastriaDesign {
    public struct Palette: Sendable {
        public let background: Color
        public let card: Color
        public let cardBorder: Color
        public let hairline: Color
        public let text: Color
        public let secondaryText: Color
        public let tertiaryText: Color
        public let accent: Color
        public let artworkPlaceholder: Color
    }

    /// Warm near-black scheme from the wireframe.
    public static let dark = Palette(
        background: Color(red: 0.075, green: 0.071, blue: 0.063),        // #131210
        card: Color(red: 0.106, green: 0.098, blue: 0.086),              // #1B1916
        cardBorder: bone.opacity(0.08),
        hairline: bone.opacity(0.09),
        text: bone,                                                      // #EDE7DC
        secondaryText: bone.opacity(0.55),
        tertiaryText: bone.opacity(0.35),
        accent: Color(red: 0.761, green: 0.631, blue: 0.369),            // #C2A15E
        artworkPlaceholder: Color(red: 0.165, green: 0.149, blue: 0.125) // #2A2620
    )

    /// Warm paper counterpart so the module never overrides a light system setting.
    public static let light = Palette(
        background: Color(red: 0.969, green: 0.953, blue: 0.918),        // #F7F3EA
        card: Color(red: 0.996, green: 0.988, blue: 0.965),              // #FEFCF6
        cardBorder: ink.opacity(0.10),
        hairline: ink.opacity(0.12),
        text: ink,                                                       // #14120F
        secondaryText: ink.opacity(0.60),
        tertiaryText: ink.opacity(0.42),
        accent: Color(red: 0.541, green: 0.427, blue: 0.204),            // #8A6D34
        artworkPlaceholder: Color(red: 0.898, green: 0.871, blue: 0.816) // #E5DED0
    )

    public static func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }

    private static let bone = Color(red: 0.929, green: 0.906, blue: 0.863) // #EDE7DC
    private static let ink = Color(red: 0.078, green: 0.071, blue: 0.059)  // #14120F
}

@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
extension Font {
    /// Serif display face for show, subject and episode-group titles.
    static func podcastriaDisplay(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif).weight(.medium)
    }

    /// Monospaced small-caps style used for counts, dates and durations.
    static var podcastriaMeta: Font {
        .system(.caption2, design: .monospaced).weight(.medium)
    }
}

/// Uppercased, tracked metadata label ("24 EP · 2 SERIES", "SERIES · 4 PARTS").
@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
struct PodcastriaMetaLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.podcastriaMeta)
            .kerning(1.2)
            .foregroundStyle(color)
    }
}
