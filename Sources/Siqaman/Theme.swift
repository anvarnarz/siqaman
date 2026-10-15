import AppKit
import SwiftUI

/// Ertaga kech design system tokens: dark-first, matte black, one copper accent.
enum Theme {
    static let accent = Color(red: 182 / 255, green: 107 / 255, blue: 59 / 255)       // #B66B3B
    static let accentHover = Color(red: 198 / 255, green: 121 / 255, blue: 72 / 255)
    static let accentPress = Color(red: 160 / 255, green: 92 / 255, blue: 49 / 255)
    static let accentSoft = accent.opacity(0.15)
    static let peach = Color(red: 232 / 255, green: 168 / 255, blue: 124 / 255)       // wave-gradient end
    static let bg = Color.black
    static let surface = Color(white: 17 / 255)                                         // #111
    static let surfaceRaised = Color(white: 26 / 255)                                   // #1A1A1A
    static let glass = Color.white.opacity(0.05)
    static let border = Color(white: 33 / 255)                                          // #212121
    static let text = Color.white
    static let text2 = Color.white.opacity(0.6)
    static let text3 = Color.white.opacity(0.5)
    static let meta = Color(white: 140 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let success = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
    static let wave = LinearGradient(colors: [accent, peach], startPoint: .leading, endPoint: .trailing)

    enum Weight: String { case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold" }
    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font { .custom("BricolageGrotesque-\(weight.rawValue)", size: size) }
    static func mono(_ size: CGFloat) -> Font { .custom("GeistMono-Medium", size: size) }
    static let overline = Font.system(size: 11, weight: .medium)

    /// Registers the bundled Bricolage Grotesque / Geist Mono fonts for this process.
    static func registerFonts(in dir: URL? = Bundle.main.resourceURL?.appendingPathComponent("Fonts")) {
        guard let dir, let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
    }
}

/// `.glow-accent`: black page lit by soft copper light from the top-right and bottom-left.
struct BrandBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.28), .clear], center: UnitPoint(x: 0.85, y: 0), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Theme.accent.opacity(0.14), .clear], center: UnitPoint(x: 0, y: 1), startRadius: 0, endRadius: 260)
        }
        .ignoresSafeArea()
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .medium))
            .foregroundStyle(enabled ? Theme.text : Theme.text.opacity(0.4))
            .padding(.horizontal, 18).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(!enabled ? Color.white.opacity(0.08) : configuration.isPressed ? Theme.accentPress : hover ? Theme.accentHover : Theme.accent))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
    }
}

struct SecondaryButton: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hover ? Theme.surfaceRaised : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
    }
}

/// Card surface: #111, 16px radius, hairline border, 1px top highlight.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .center))
            }
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View { modifier(CardBackground(radius: radius)) }
    func overline() -> some View { font(Theme.overline).tracking(0.44).textCase(.uppercase).foregroundStyle(Theme.meta) }
}

/// Segmented control in the design system's tab style.
struct Segmented<T: Hashable>: View {
    let options: [(String, T)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.1) { title, value in
                Text(title)
                    .font(Theme.font(13, .medium))
                    .foregroundStyle(selection == value ? Theme.text : Theme.text2)
                    .frame(maxWidth: .infinity).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selection == value ? Theme.surfaceRaised : .clear)
                        .shadow(color: .black.opacity(selection == value ? 0.4 : 0), radius: 2, y: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selection = value } }
            }
        }
        .padding(3)
        .card(radius: 10)
    }
}

/// Password input: #111 fill, hairline border, 1.5px copper ring on focus.
struct BrandSecureField: View {
    let placeholder: String
    @Binding var text: String
    var error = false
    var autofocus = false
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool
    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.text3))
            .textFieldStyle(.plain)
            .font(Theme.font(14))
            .foregroundStyle(Theme.text)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(error ? Theme.danger : focused ? Theme.accent : Theme.border, lineWidth: focused ? 1.5 : 1))
            .onAppear { if autofocus { focused = true } }
    }
}
