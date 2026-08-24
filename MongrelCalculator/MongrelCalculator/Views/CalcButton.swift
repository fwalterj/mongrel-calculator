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

    var background: Color {
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
    let kind: CalcKeyKind
    let height: CGFloat
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let radius = height * 0.36
        configuration.label
            .background(kind.background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(kind == .op ? 0.12 : 0.07), lineWidth: 0.5)
            )
            // Active-operator highlight: white tint so the pending op stays lit
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.14 : 0.00))
            )
            .shadow(color: Color.black.opacity(0.30), radius: 3, y: 2)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

// MARK: - CalcButton

struct CalcButton: View {
    let key: String
    let width: CGFloat
    let height: CGFloat
    var isActive: Bool = false
    let action: () -> Void

    private var kind: CalcKeyKind { CalcKeyKind(key: key) }

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(kind == .scientific
                      ? .system(size: 13, weight: .medium, design: .rounded)
                      : .system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: width, height: height)
        }
        .buttonStyle(GlassCalcButtonStyle(kind: kind, height: height, isActive: isActive))
        .focusEffectDisabled(true)
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
