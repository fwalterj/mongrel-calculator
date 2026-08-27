import SwiftUI
import AppKit

// MARK: - Key Kind

enum CalcKeyKind {
    case digit      // 0–9, .
    case op         // +, −, ×, ÷, =
    case clear      // C, CE, ⌫, +/−, %
    case scientific // MC, MR, M+, M−, √, x², 1/x

    init(key: String) {
        switch key {
        case "+", "−", "×", "÷", "=":
            self = .op
        case "C", "CE", "⌫", "±", "%":
            self = .clear
        case "MC", "MR", "M+", "M−", "√", "x²", "1/x":
            self = .scientific
        default:
            self = .digit
        }
    }

    @MainActor
    func background(using appearance: MongrelAppearanceModel) -> Color {
        if appearance.mode != .classic {
            switch self {
            case .op: return appearance.text.opacity(0.22)
            case .clear: return appearance.surface(lift: 0.11)
            case .scientific: return appearance.surface(lift: 0.08)
            case .digit: return appearance.surface(lift: 0.055)
            }
        }
        switch self {
        case .digit:      return Color(white: 0.16)
        case .op:         return Color(hue: 0.545, saturation: 0.68, brightness: 0.58)
        case .clear:      return Color(white: 0.25)
        case .scientific: return Color(white: 0.21)
        }
    }
}

// MARK: - Button style

struct GlassCalcButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var appearance: MongrelAppearanceModel

    let kind: CalcKeyKind
    let height: CGFloat
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let radius = height * 0.36
        configuration.label
            .background(kind.background(using: appearance))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(appearance.text.opacity(appearance.mode == .contrast ? 0.72 : (kind == .op ? 0.12 : 0.07)), lineWidth: 0.5)
            )
            // Active-operator highlight: white tint so the pending op stays lit
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(appearance.text.opacity(isActive ? 0.18 : 0.00))
            )
            .shadow(color: Color.black.opacity(0.30), radius: 3, y: 2)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.90 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

// MARK: - CalcButton

struct CalcButton: View {
    @EnvironmentObject private var appearance: MongrelAppearanceModel

    let key: String
    let width: CGFloat
    let height: CGFloat
    var isActive: Bool = false
    let action: () -> Void

    private var kind: CalcKeyKind { CalcKeyKind(key: key) }
    private var accessibleName: String {
        switch key {
        case "C": return "Clear all"
        case "CE": return "Clear entry"
        case "⌫": return "Delete last digit"
        case "÷": return "Divide"
        case "×": return "Multiply"
        case "−": return "Subtract"
        case "+": return "Add"
        case "=": return "Equals"
        case "±": return "Change sign"
        case ".": return "Decimal point"
        case "MC": return "Clear memory"
        case "MR": return "Recall memory"
        case "M+": return "Add to memory"
        case "M−": return "Subtract from memory"
        case "√": return "Square root"
        case "x²": return "Square"
        case "1/x": return "Reciprocal"
        default: return key
        }
    }

    private var helpText: String {
        switch key {
        case "C": return "Clear the calculation (Shift-C)"
        case "CE": return "Clear the current entry (C or Escape)"
        case "⌫": return "Delete the last digit (Delete)"
        case "÷": return "Divide (/)"
        case "×": return "Multiply (* or X)"
        case "−": return "Subtract (-)"
        case "+": return "Add (+)"
        case "=": return "Calculate (= or Return)"
        case "%": return "Convert to or apply a percentage (%)"
        default: return accessibleName
        }
    }

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(kind == .scientific
                      ? .system(size: 13, weight: .medium, design: .rounded)
                      : .system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(appearance.text)
                .frame(width: width, height: height)
        }
        .buttonStyle(GlassCalcButtonStyle(appearance: appearance, kind: kind, height: height, isActive: isActive))
        .focusEffectDisabled(true)
        .accessibilityLabel(accessibleName)
        .accessibilityHint(helpText)
        .help(helpText)
    }
}

// MARK: - Glass background (NSVisualEffectView)

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = .fullScreenUI
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
