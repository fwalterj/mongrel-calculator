import Foundation
import SwiftUI

enum MongrelViewingMode: String, CaseIterable, Identifiable {
    case classic = "standard"
    case contrast
    case custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic"
        case .contrast: return "Contrast"
        case .custom: return "Custom"
        }
    }
}

struct MongrelRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    static let black = MongrelRGB(red: 0, green: 0, blue: 0)
    static let white = MongrelRGB(red: 1, green: 1, blue: 1)

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        let h = Self.clamp(hue)
        let s = Self.clamp(saturation)
        let v = Self.clamp(brightness)
        let sector = Int(h * 6)
        let fraction = h * 6 - Double(sector)
        let p = v * (1 - s)
        let q = v * (1 - fraction * s)
        let t = v * (1 - (1 - fraction) * s)

        switch sector % 6 {
        case 0: self.init(red: v, green: t, blue: p)
        case 1: self.init(red: q, green: v, blue: p)
        case 2: self.init(red: p, green: v, blue: t)
        case 3: self.init(red: p, green: q, blue: v)
        case 4: self.init(red: t, green: p, blue: v)
        default: self.init(red: v, green: p, blue: q)
        }
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    var relativeLuminance: Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red)
            + 0.7152 * linearize(green)
            + 0.0722 * linearize(blue)
    }

    func contrastRatio(with other: MongrelRGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

@MainActor
final class MongrelAppearanceModel: ObservableObject {
    static let modeKey = "mongrelAppearanceMode"
    static let backgroundHueKey = "mongrelCustomBackgroundHue"
    static let backgroundSaturationKey = "mongrelCustomBackgroundSaturation"
    static let backgroundBrightnessKey = "mongrelCustomBackgroundBrightness"
    static let textHueKey = "mongrelCustomTextHue"
    static let textSaturationKey = "mongrelCustomTextSaturation"
    static let textBrightnessKey = "mongrelCustomTextBrightness"

    static let defaultBackgroundHue = 0.545
    static let defaultBackgroundSaturation = 0.35
    static let defaultBackgroundBrightness = 0.06
    static let defaultTextHue = 0.545
    static let defaultTextSaturation = 0.04
    static let defaultTextBrightness = 1.0

    @Published var mode: MongrelViewingMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.modeKey) }
    }
    @Published var backgroundHue: Double {
        didSet { defaults.set(backgroundHue, forKey: Self.backgroundHueKey) }
    }
    @Published var backgroundSaturation: Double {
        didSet { defaults.set(backgroundSaturation, forKey: Self.backgroundSaturationKey) }
    }
    @Published var backgroundBrightness: Double {
        didSet { defaults.set(backgroundBrightness, forKey: Self.backgroundBrightnessKey) }
    }
    @Published var textHue: Double {
        didSet { defaults.set(textHue, forKey: Self.textHueKey) }
    }
    @Published var textSaturation: Double {
        didSet { defaults.set(textSaturation, forKey: Self.textSaturationKey) }
    }
    @Published var textBrightness: Double {
        didSet { defaults.set(textBrightness, forKey: Self.textBrightnessKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = MongrelViewingMode(rawValue: defaults.string(forKey: Self.modeKey) ?? "") ?? .contrast
        backgroundHue = Self.value(Self.backgroundHueKey, fallback: Self.defaultBackgroundHue, in: defaults)
        backgroundSaturation = Self.value(Self.backgroundSaturationKey, fallback: Self.defaultBackgroundSaturation, in: defaults)
        backgroundBrightness = Self.value(Self.backgroundBrightnessKey, fallback: Self.defaultBackgroundBrightness, in: defaults)
        textHue = Self.value(Self.textHueKey, fallback: Self.defaultTextHue, in: defaults)
        textSaturation = Self.value(Self.textSaturationKey, fallback: Self.defaultTextSaturation, in: defaults)
        textBrightness = Self.value(Self.textBrightnessKey, fallback: Self.defaultTextBrightness, in: defaults)
    }

    var backgroundRGB: MongrelRGB {
        switch mode {
        case .classic:
            return MongrelRGB(hue: 0.545, saturation: 0.35, brightness: 0.06)
        case .contrast:
            return .black
        case .custom:
            return customBackgroundRGB
        }
    }

    var textRGB: MongrelRGB {
        switch mode {
        case .classic, .contrast:
            return .white
        case .custom:
            return customTextRGB
        }
    }

    var customBackgroundRGB: MongrelRGB {
        MongrelRGB(hue: backgroundHue, saturation: backgroundSaturation, brightness: backgroundBrightness)
    }

    var customTextRGB: MongrelRGB {
        MongrelRGB(hue: textHue, saturation: textSaturation, brightness: textBrightness)
    }

    var background: Color { backgroundRGB.color }

    var text: Color {
        mode == .classic ? Color.white.opacity(0.94) : textRGB.color
    }

    var backgroundHex: String { backgroundRGB.hex }
    var textHex: String { textRGB.hex }
    var contrastRatio: Double { backgroundRGB.contrastRatio(with: textRGB) }

    func foregroundOpacity(_ requestedOpacity: Double) -> Double {
        mode == .classic ? requestedOpacity : max(0.72, requestedOpacity)
    }

    func foreground(opacity: Double) -> Color {
        text.opacity(foregroundOpacity(opacity))
    }

    func surface(lift: Double) -> Color {
        switch mode {
        case .classic:
            return background
        case .contrast:
            return .black
        case .custom:
            return MongrelRGB(
                hue: backgroundHue,
                saturation: backgroundSaturation,
                brightness: min(1, backgroundBrightness + lift)
            ).color
        }
    }

    func improveCustomReadability() {
        let whiteRatio = customBackgroundRGB.contrastRatio(with: .white)
        let blackRatio = customBackgroundRGB.contrastRatio(with: .black)

        textHue = 0
        textSaturation = 0
        if whiteRatio >= blackRatio {
            textBrightness = 1
            backgroundBrightness = min(backgroundBrightness, 0.10)
        } else {
            textBrightness = 0
            backgroundSaturation = min(backgroundSaturation, 0.10)
            backgroundBrightness = max(backgroundBrightness, 0.90)
        }
    }

    func resetCustomColors() {
        backgroundHue = Self.defaultBackgroundHue
        backgroundSaturation = Self.defaultBackgroundSaturation
        backgroundBrightness = Self.defaultBackgroundBrightness
        textHue = Self.defaultTextHue
        textSaturation = Self.defaultTextSaturation
        textBrightness = Self.defaultTextBrightness
    }

    private static func value(_ key: String, fallback: Double, in defaults: UserDefaults) -> Double {
        guard let number = defaults.object(forKey: key) as? NSNumber else { return fallback }
        return min(1, max(0, number.doubleValue))
    }
}

struct MongrelAppearanceControls: View {
    @EnvironmentObject private var appearance: MongrelAppearanceModel

    private var contrastGrade: String {
        switch appearance.contrastRatio {
        case 7...: return "AAA"
        case 4.5...: return "AA"
        default: return "Low"
        }
    }

    private var contrastGradeColor: Color {
        appearance.contrastRatio >= 7 ? .green : appearance.contrastRatio >= 4.5 ? .yellow : .red
    }

    var body: some View {
        Section("Viewing mode") {
            Picker("Viewing mode", selection: $appearance.mode) {
                ForEach(MongrelViewingMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.segmented)

            Text(modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if appearance.mode == .custom {
            colorSection(
                "Background",
                hue: $appearance.backgroundHue,
                saturation: $appearance.backgroundSaturation,
                brightness: $appearance.backgroundBrightness,
                preview: appearance.customBackgroundRGB.color,
                hex: appearance.customBackgroundRGB.hex
            )
            colorSection(
                "Text and cues",
                hue: $appearance.textHue,
                saturation: $appearance.textSaturation,
                brightness: $appearance.textBrightness,
                preview: appearance.customTextRGB.color,
                hex: appearance.customTextRGB.hex
            )
        }

        Section("Appearance preview") {
            Label("Readable text and active cues", systemImage: "eye.fill")
                .font(.headline)
                .foregroundStyle(appearance.text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearance.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.text.opacity(0.7), lineWidth: 1))
                .shadow(color: appearance.mode == .contrast ? .white.opacity(0.48) : .clear, radius: 3)

            HStack {
                Text("Contrast ratio")
                Spacer()
                Text(String(format: "%.2f:1", appearance.contrastRatio))
                    .monospacedDigit()
                Text(contrastGrade)
                    .font(.caption.bold())
                    .foregroundStyle(contrastGradeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(contrastGradeColor.opacity(0.15), in: Capsule())
            }

            if appearance.mode == .custom {
                HStack {
                    Button("Improve Readability") {
                        appearance.improveCustomReadability()
                    }
                    .disabled(appearance.contrastRatio >= 7)

                    Button("Reset Custom Colors") {
                        appearance.resetCustomColors()
                    }
                }

                if appearance.contrastRatio < 4.5 {
                    Label("This pair is difficult to read. Settings remain legible so you can recover it.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var modeDescription: String {
        switch appearance.mode {
        case .classic:
            return "The original Mongrel palette."
        case .contrast:
            return "Pure #000000 surfaces and #FFFFFF text with a maximum 21:1 contrast ratio."
        case .custom:
            return "Independent color sliders shape the background and primary text cues."
        }
    }

    @ViewBuilder
    private func colorSection(
        _ title: String,
        hue: Binding<Double>,
        saturation: Binding<Double>,
        brightness: Binding<Double>,
        preview: Color,
        hex: String
    ) -> some View {
        Section(title) {
            appearanceSlider("Hue", value: hue)
            appearanceSlider("Saturation", value: saturation)
            appearanceSlider("Brightness", value: brightness)
            HStack {
                Text("Result")
                Spacer()
                Text(hex).font(.caption.monospaced()).foregroundStyle(.secondary)
                Circle().fill(preview).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(.primary.opacity(0.55)))
            }
        }
    }

    private func appearanceSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
        }
    }
}

private struct MongrelAppearanceModifier: ViewModifier {
    @EnvironmentObject private var appearance: MongrelAppearanceModel

    func body(content: Content) -> some View {
        content
            .background(appearance.background.ignoresSafeArea())
            .tint(appearance.text)
            .shadow(color: appearance.mode == .contrast ? .white.opacity(0.18) : .clear, radius: 2)
    }
}

extension View {
    func mongrelAccessibleAppearance() -> some View {
        modifier(MongrelAppearanceModifier())
    }
}
