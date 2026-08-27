import SwiftUI
import AppKit

@main
struct MongrelCalculatorApp: App {
    @StateObject private var appearance = MongrelAppearanceModel()

    var body: some Scene {
        WindowGroup {
            CalculatorWindow()
                .preferredColorScheme(.dark)
                .mongrelAccessibleAppearance()
                .environmentObject(appearance)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 372, height: 572)
        .windowResizability(.contentSize)
        .commands {
            CalculatorCommands()
        }

        Settings {
            Form {
                MongrelAppearanceControls()
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 500, height: appearance.mode == .custom ? 620 : 360)
            .preferredColorScheme(.dark)
            .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
            .animation(.easeInOut(duration: 0.18), value: appearance.mode)
            .environmentObject(appearance)
        }
    }
}

/// A fresh root view is created for every native window or tab, so calculation
/// state never leaks between calculator sessions.
private struct CalculatorWindow: View {
    @StateObject private var engine = CalculatorEngine()

    var body: some View {
        CalculatorView()
            .environmentObject(engine)
            .focusedSceneValue(\.calculatorEngine, engine)
    }
}

private struct CalculatorEngineFocusedKey: FocusedValueKey {
    typealias Value = CalculatorEngine
}

extension FocusedValues {
    var calculatorEngine: CalculatorEngine? {
        get { self[CalculatorEngineFocusedKey.self] }
        set { self[CalculatorEngineFocusedKey.self] = newValue }
    }
}

private struct CalculatorCommands: Commands {
    @FocusedValue(\.calculatorEngine) private var engine

    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button("Copy Result") {
                guard let engine else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(engine.display, forType: .string)
            }
            .keyboardShortcut("c")
            .disabled(engine == nil)

            Button("Paste Number") {
                guard let engine,
                      let value = NSPasteboard.general.string(forType: .string) else {
                    return
                }
                engine.pasteNumber(value)
            }
            .keyboardShortcut("v")
            .disabled(engine == nil)
        }

        CommandMenu("Calculation") {
            Button("Clear Calculation") {
                engine?.input("C")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(engine == nil)

            Button("Clear History") {
                engine?.clearHistory()
            }
            .disabled(engine == nil)
        }
    }
}
