import SwiftUI
import AppKit

struct CalculatorView: View {
    @EnvironmentObject private var engine: CalculatorEngine
    @EnvironmentObject private var appearance: MongrelAppearanceModel
    @State private var showingHistory = false

    // Button rows: operators use unicode chars that match engine's switch cases
    private let mainRows: [[String]] = [
        ["C", "CE", "⌫", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["±", "0", ".", "="],
    ]
    private let sciRow = ["MC", "MR", "M+", "M−", "√", "x²", "1/x"]

    // Sizes tuned so scientific row inner width == main grid inner width
    // Main:  4×76 + 3×10 = 334   Sci: 7×40 + 6×9 = 334  ✓
    private let mainBtnW: CGFloat = 76
    private let mainBtnH: CGFloat = 58
    private let mainSpacing: CGFloat = 10
    private let sciBtnW: CGFloat = 40
    private let sciBtnH: CGFloat = 30
    private let sciSpacing: CGFloat = 9
    private let hPad: CGFloat = 16

    var body: some View {
        ZStack {
            GlassBackground().ignoresSafeArea()
            (appearance.mode == .classic
                ? Color(hue: 0.55, saturation: 0.20, brightness: 0.08)
                : appearance.background)
                .opacity(appearance.mode == .classic ? 0.91 : 1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                historyTape
                Rectangle()
                    .fill(appearance.text.opacity(appearance.mode == .contrast ? 0.62 : 0.08))
                    .frame(height: 0.5)
                displayArea
                buttonArea
            }
        }
        .background {
            CalculatorKeyboardCapture { key in
                engine.input(key)
            }
            .frame(width: 0, height: 0)
        }
    }

    // MARK: - History tape

    private var historyTape: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: engine.history.isEmpty ? "clock" : "clock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appearance.foreground(opacity: engine.history.isEmpty ? 0.32 : 0.72))
                    .frame(width: 28, height: 28)
                    .background(appearance.text.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(engine.history.isEmpty)
            .help(engine.history.isEmpty ? "Calculation history is empty" : "Show calculation history")
            .accessibilityLabel("Calculation history")
            .accessibilityValue("\(engine.history.count) entries")
            .popover(isPresented: $showingHistory, arrowEdge: .bottom) {
                historyPopover
            }

            VStack(alignment: .trailing, spacing: 2) {
                if engine.history.isEmpty {
                    Text("History appears here")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(appearance.foreground(opacity: 0.28))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    ForEach(Array(engine.history.suffix(4).enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(appearance.foreground(opacity: 0.48))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .bottomTrailing)
        .padding(.horizontal, hPad)
        .padding(.vertical, 6)
    }

    private var historyPopover: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Button("Clear") {
                    engine.clearHistory()
                    showingHistory = false
                }
                .buttonStyle(.borderless)
            }
            .padding(12)

            Divider()

            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 10) {
                    ForEach(Array(engine.history.reversed().enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 310, height: 260)
        .background(appearance.background)
        .foregroundStyle(appearance.text)
    }

    // MARK: - Display

    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let issue = engine.issue {
                Text(issue.message)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(appearance.foreground(opacity: 0.72))
                    .lineLimit(1)
                    .accessibilityLabel("Calculator error")
                    .accessibilityValue(issue.message)
            }

            HStack(alignment: .bottom, spacing: 10) {
                if engine.hasMemory {
                    Text("M")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appearance.mode == .classic
                                         ? Color(hue: 0.545, saturation: 0.75, brightness: 0.82)
                                         : appearance.text)
                        .padding(.bottom, 6)
                        .accessibilityLabel("Memory contains a value")
                }
                Spacer(minLength: 0)
                Text(engine.readout)
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(appearance.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.30)
                    .accessibilityLabel("Calculator display")
                    .accessibilityValue(engine.readout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, hPad)
        .padding(.vertical, 14)
    }

    // MARK: - Buttons

    private var buttonArea: some View {
        VStack(spacing: mainSpacing) {
            // Scientific / memory row
            HStack(spacing: sciSpacing) {
                ForEach(sciRow, id: \.self) { key in
                    CalcButton(key: key, width: sciBtnW, height: sciBtnH) {
                        engine.input(key)
                    }
                }
            }

            // Main 5×4 grid
            ForEach(mainRows, id: \.self) { row in
                HStack(spacing: mainSpacing) {
                    ForEach(row, id: \.self) { key in
                        CalcButton(
                            key: key,
                            width: mainBtnW,
                            height: mainBtnH,
                            isActive: engine.activeOperation == key
                        ) {
                            engine.input(key)
                        }
                    }
                }
            }
        }
        .padding(hPad)
    }
}

// MARK: - Keyboard

/// A local event monitor is still needed for calculator-style single-key input,
/// but it must be scoped to one NSWindow. Native macOS tabs are separate windows;
/// an app-wide monitor would otherwise update every open calculator at once.
private struct CalculatorKeyboardCapture: NSViewRepresentable {
    var onKey: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onKey: onKey)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.connect(to: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.onKey = onKey
        DispatchQueue.main.async {
            context.coordinator.connect(to: view.window)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var onKey: (String) -> Void

        private weak var window: NSWindow?
        private var monitor: Any?

        init(onKey: @escaping (String) -> Void) {
            self.onKey = onKey
        }

        func connect(to window: NSWindow?) {
            guard let window else { return }
            guard self.window !== window || monitor == nil else { return }

            stop()
            self.window = window
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
                guard let self,
                      let window,
                      window.isKeyWindow,
                      event.window === window,
                      let key = Self.mapKey(event) else {
                    return event
                }
                self.onKey(key)
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            window = nil
        }

        private static func mapKey(_ event: NSEvent) -> String? {
            CalculatorKeyboardMapper.map(
                keyCode: event.keyCode,
                characters: event.characters,
                modifiers: event.modifierFlags
            )
        }
    }
}

enum CalculatorKeyboardMapper {
    static func map(
        keyCode: UInt16,
        characters: String?,
        modifiers: NSEvent.ModifierFlags
    ) -> String? {
        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard modifiers.intersection(shortcutModifiers).isEmpty else { return nil }

        switch keyCode {
        case 51, 117: return "⌫"     // Backspace and Forward Delete
        case 53: return "CE"          // Escape
        case 36, 76: return "="       // Return and numpad Enter
        default: break
        }

        guard let character = characters, character.count == 1 else { return nil }
        switch character {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            return character
        case ".", ",":
            return "."
        case "+":
            return "+"
        case "-":
            return "−"
        case "*", "x", "X":
            return "×"
        case "/":
            return "÷"
        case "=":
            return "="
        case "%":
            return "%"
        case "c":
            return "CE"
        case "C":
            return "C"
        default:
            return nil
        }
    }
}
