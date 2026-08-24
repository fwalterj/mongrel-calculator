import SwiftUI

@main
struct MongrelCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            CalculatorWindow()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 372, height: 572)
        .windowResizability(.contentSize)
    }
}

/// A fresh root view is created for every native window or tab, so calculation
/// state never leaks between calculator sessions.
private struct CalculatorWindow: View {
    @StateObject private var engine = CalculatorEngine()

    var body: some View {
        CalculatorView()
            .environmentObject(engine)
    }
}
