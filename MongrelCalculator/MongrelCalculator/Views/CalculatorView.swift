import SwiftUI
import AppKit

struct CalculatorView: View {
    @EnvironmentObject private var engine: CalculatorEngine

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
            Color(hue: 0.55, saturation: 0.20, brightness: 0.08)
                .opacity(0.91)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                historyTape
                Rectangle()
                    .fill(Color.white.opacity(0.08))
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
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(Array(engine.history.suffix(4).enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .bottomTrailing)
        .padding(.horizontal, hPad)
        .padding(.vertical, 6)
    }

    // MARK: - Display

    private var displayArea: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if engine.hasMemory {
                Text("M")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hue: 0.545, saturation: 0.75, brightness: 0.82))
                    .padding(.bottom, 6)
            }
            Spacer(minLength: 0)
            Text(engine.readout)
                .font(.system(size: 46, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
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

        /// Map a raw NSEvent to the engine's key names (unicode operators + special keys).
        private static func mapKey(_ event: NSEvent) -> String? {
            switch event.keyCode {
            case 51: return "⌫"        // Delete / Backspace
            case 53: return "CE"       // Escape
            case 36, 76: return "="    // Return, numpad Enter
            default: break
            }
            guard let c = event.characters, c.count == 1 else { return nil }
            switch c {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".":
                return c
            case "+": return "+"
            case "-": return "−"       // normalize ASCII minus → unicode minus sign
            case "*": return "×"
            case "/": return "÷"
            case "=": return "="
            case "%": return "%"
            case "c": return "CE"
            case "C": return "C"
            default: return nil
            }
        }
    }
}
