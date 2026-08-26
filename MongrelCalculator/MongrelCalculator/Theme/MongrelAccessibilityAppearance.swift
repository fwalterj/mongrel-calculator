import SwiftUI

enum MongrelViewingMode: String, CaseIterable, Identifiable {
    case standard
    case contrast
    case custom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MongrelLocalAppearance {
    static let modeKey = "mongrelAppearanceMode"
    static let backgroundHueKey = "mongrelCustomBackgroundHue"
    static let backgroundSaturationKey = "mongrelCustomBackgroundSaturation"
    static let backgroundBrightnessKey = "mongrelCustomBackgroundBrightness"
    static let textHueKey = "mongrelCustomTextHue"
    static let textSaturationKey = "mongrelCustomTextSaturation"
    static let textBrightnessKey = "mongrelCustomTextBrightness"

    static var mode: MongrelViewingMode {
        MongrelViewingMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .standard
    }

    static var backgroundHue: Double { value(backgroundHueKey, fallback: 0.545) }
    static var backgroundSaturation: Double { value(backgroundSaturationKey, fallback: 0.35) }
    static var backgroundBrightness: Double { value(backgroundBrightnessKey, fallback: 0.06) }
    static var textHue: Double { value(textHueKey, fallback: 0.545) }
    static var textSaturation: Double { value(textSaturationKey, fallback: 0.04) }
    static var textBrightness: Double { value(textBrightnessKey, fallback: 1.0) }

    static var background: Color {
        switch mode {
        case .standard: return Color(hue: 0.545, saturation: 0.35, brightness: 0.06)
        case .contrast: return .black
        case .custom: return Color(hue: backgroundHue, saturation: backgroundSaturation, brightness: backgroundBrightness)
        }
    }

    static var text: Color {
        switch mode {
        case .standard: return Color.white.opacity(0.94)
        case .contrast: return .white
        case .custom: return Color(hue: textHue, saturation: textSaturation, brightness: textBrightness)
        }
    }

    static func surface(lift: Double) -> Color {
        guard mode == .custom else { return mode == .contrast ? .black : background }
        return Color(hue: backgroundHue,
                     saturation: backgroundSaturation,
                     brightness: min(1, backgroundBrightness + lift))
    }

    static var backgroundHex: String {
        mode == .contrast ? "#000000" : hex(h: backgroundHue, s: backgroundSaturation, v: backgroundBrightness)
    }

    static var textHex: String {
        mode == .contrast ? "#FFFFFF" : hex(h: textHue, s: textSaturation, v: textBrightness)
    }

    private static func value(_ key: String, fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }

    private static func hex(h: Double, s: Double, v: Double) -> String {
        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let rgb: (Double, Double, Double)
        switch i % 6 {
        case 0: rgb = (v, t, p)
        case 1: rgb = (q, v, p)
        case 2: rgb = (p, v, t)
        case 3: rgb = (p, q, v)
        case 4: rgb = (t, p, v)
        default: rgb = (v, p, q)
        }
        return String(format: "#%02X%02X%02X",
                      Int((rgb.0 * 255).rounded()),
                      Int((rgb.1 * 255).rounded()),
                      Int((rgb.2 * 255).rounded()))
    }
}

struct MongrelAppearanceControls: View {
    @AppStorage(MongrelLocalAppearance.modeKey) private var modeRaw = MongrelViewingMode.standard.rawValue
    @AppStorage(MongrelLocalAppearance.backgroundHueKey) private var backgroundHue = 0.545
    @AppStorage(MongrelLocalAppearance.backgroundSaturationKey) private var backgroundSaturation = 0.35
    @AppStorage(MongrelLocalAppearance.backgroundBrightnessKey) private var backgroundBrightness = 0.06
    @AppStorage(MongrelLocalAppearance.textHueKey) private var textHue = 0.545
    @AppStorage(MongrelLocalAppearance.textSaturationKey) private var textSaturation = 0.04
    @AppStorage(MongrelLocalAppearance.textBrightnessKey) private var textBrightness = 1.0

    private var mode: Binding<MongrelViewingMode> {
        Binding(
            get: { MongrelViewingMode(rawValue: modeRaw) ?? .standard },
            set: { modeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Section("Viewing mode") {
            Picker("Viewing mode", selection: mode) {
                ForEach(MongrelViewingMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.wrappedValue == .contrast
                 ? "Pure black surfaces with blooming white text, borders, and active cues."
                 : mode.wrappedValue == .custom
                    ? "Independent color sliders shape the background and every primary text cue."
                    : "The original Mongrel palette.")
                .font(.caption)
                .foregroundStyle(MongrelLocalAppearance.text.opacity(0.72))
        }

        if mode.wrappedValue == .custom {
            colorSection("Background",
                         hue: $backgroundHue,
                         saturation: $backgroundSaturation,
                         brightness: $backgroundBrightness,
                         preview: MongrelLocalAppearance.background)
            colorSection("Text and cues",
                         hue: $textHue,
                         saturation: $textSaturation,
                         brightness: $textBrightness,
                         preview: MongrelLocalAppearance.text)
        }

        Section("Appearance preview") {
            Label("Readable text and active cues", systemImage: "eye.fill")
                .font(.headline)
                .foregroundStyle(MongrelLocalAppearance.text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MongrelLocalAppearance.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MongrelLocalAppearance.text.opacity(0.55)))
                .shadow(color: mode.wrappedValue == .contrast ? .white.opacity(0.48) : .clear, radius: 3)
        }
    }

    @ViewBuilder
    private func colorSection(
        _ title: String,
        hue: Binding<Double>,
        saturation: Binding<Double>,
        brightness: Binding<Double>,
        preview: Color
    ) -> some View {
        Section(title) {
            appearanceSlider("Hue", value: hue)
            appearanceSlider("Saturation", value: saturation)
            appearanceSlider("Brightness", value: brightness)
            HStack {
                Text("Result")
                Spacer()
                Circle().fill(preview).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(MongrelLocalAppearance.text.opacity(0.55)))
            }
        }
    }

    private func appearanceSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%").monospacedDigit().opacity(0.7)
            }
            Slider(value: value, in: 0...1)
                .tint(MongrelLocalAppearance.text)
        }
    }
}

private struct MongrelAppearanceRefreshModifier: ViewModifier {
    @AppStorage(MongrelLocalAppearance.modeKey) private var mode = MongrelViewingMode.standard.rawValue
    @AppStorage(MongrelLocalAppearance.backgroundHueKey) private var backgroundHue = 0.545
    @AppStorage(MongrelLocalAppearance.backgroundSaturationKey) private var backgroundSaturation = 0.35
    @AppStorage(MongrelLocalAppearance.backgroundBrightnessKey) private var backgroundBrightness = 0.06
    @AppStorage(MongrelLocalAppearance.textHueKey) private var textHue = 0.545
    @AppStorage(MongrelLocalAppearance.textSaturationKey) private var textSaturation = 0.04
    @AppStorage(MongrelLocalAppearance.textBrightnessKey) private var textBrightness = 1.0

    func body(content: Content) -> some View {
        content
            .background(MongrelLocalAppearance.background.ignoresSafeArea())
            .tint(MongrelLocalAppearance.text)
            .shadow(color: mode == MongrelViewingMode.contrast.rawValue ? .white.opacity(0.18) : .clear, radius: 2)
    }
}

extension View {
    func mongrelAccessibleAppearance() -> some View {
        modifier(MongrelAppearanceRefreshModifier())
    }
}
