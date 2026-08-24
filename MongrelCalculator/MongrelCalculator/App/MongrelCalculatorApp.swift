import SwiftUI

@main
struct MongrelCalculatorApp: App {
    @StateObject private var engine = CalculatorEngine()

    var body: some Scene {
        WindowGroup {
            CalculatorView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 372, height: 572)
        .windowResizability(.contentSize)
    }
}
