# Mongrel Calculator

A native macOS calculator — part of the Mongrel app suite.

## Overview

Mongrel Calculator is a native macOS calculator with a premium cold-blue ominous-glass UI. Standard arithmetic, scientific functions, memory registers, keyboard input, and a history tape. Proper MVVM separation — all logic lives in `CalculatorEngine`, views own nothing stateful.

> **Work in progress:** this is a direct-distribution macOS project under active development. The repository is intended for source review, collaboration, and development builds rather than production use.

## Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI + AppKit (`NSVisualEffectView` glass, `NSEvent` keyboard) |
| Build | XcodeGen (`project.yml`) |
| Platform | macOS 14+ |

## Structure

```
MongrelCalculator/
├── project.yml
├── Tests/
│   └── CalculatorEngineTests.swift      # Arithmetic regression suite
└── MongrelCalculator/
    ├── App/
    │   ├── MongrelCalculatorApp.swift   # @main, WindowGroup, fixed size
    │   └── Info.plist
    ├── Engine/
    │   └── CalculatorEngine.swift       # ObservableObject, all logic
    └── Views/
        ├── CalculatorView.swift         # Layout, keyboard monitor
        └── CalcButton.swift             # CalcKeyKind, GlassCalcButtonStyle, GlassBackground
```

## What was built

### `CalculatorEngine.swift`
`@MainActor ObservableObject` with published display, history, memory, and active-operation state.
- **Digit/decimal entry**: 15-char cap, decimal dedup, reset-on-new-number after result.
- **Arithmetic**: `+`, `−`, `×`, `÷`, chained operations, operator replacement, and repeated equals.
- **Scientific**: `√` (negative guard → "Error"), `x²`, `1/x` (zero guard → "Error").
- **Memory**: MC, MR, M+, M−. `M` indicator appears in display area when memory is non-zero.
- **Utility**: `⌫` backspace, `±` sign toggle, context-aware `%`, C (full clear), and CE (entry clear).
- **History tape**: last 30 operations, last 4 lines shown above the display.
- `activeOperation: String?` published — the pending operator symbol (e.g. `"×"`) or `nil`. Consumed by the view to highlight the active operator button.
- POSIX decimal formatting guarantees that displayed values round-trip through the engine regardless of the Mac's region settings.

### `CalculatorView.swift`
- Layout: history tape (4 lines) → 0.5px separator → display → scientific row → 5×4 button grid.
- Button sizes tuned so scientific row inner width exactly equals main grid inner width (both 334pt).
- **Active operator highlight**: `engine.activeOperation == key` passed as `isActive` to each button — the pending operator shows a white tint overlay while waiting for second operand.
- **Keyboard monitor**: `NSEvent.addLocalMonitorForEvents`, installed `onAppear`, removed `onDisappear`. Normalises ASCII `-` → `−`, `*` → `×`, `/` → `÷`, Return/numpad-Enter → `=`, Escape → CE, and consumes handled keys to prevent duplicate responder-chain behavior.
- `[weak engine]` capture to avoid retain cycle through monitor.

### `CalcButton.swift`
- `CalcKeyKind` enum (`.digit`, `.op`, `.clear`, `.scientific`) drives background color.
  - Operators `+`, `−`, `×`, `÷`, `=`: cold blue `Color(hue: 0.545, saturation: 0.68, brightness: 0.58)`.
  - Numbers: `Color(white: 0.16)`.
  - Functions (C, CE, ⌫, ±, %): `Color(white: 0.25)`.
  - Scientific / memory (MC, MR, M+, M−, &radic;&radic;, x², 1/x): `Color(white: 0.21)`.
- `GlassCalcButtonStyle: ButtonStyle` — press drives 0.90× scale (90ms ease-out). `isActive: Bool` param adds a white tint overlay when the button is the pending operator.
- `.focusEffectDisabled(true)` on every button — suppresses macOS default blue focus ring.
- `GlassBackground: NSViewRepresentable` — `NSVisualEffectView(.fullScreenUI, .behindWindow)` + dark overlay for the ominous glass effect.

### `MongrelCalculatorApp.swift`
- `@StateObject private var engine` — single source of truth, injected via `.environmentObject`.
- `.windowStyle(.hiddenTitleBar)` — traffic lights visible, title text hidden.
- `.windowResizability(.contentSize)` — window locked to exact content size, not user-resizable.
- `.defaultSize(width: 372, height: 572)`.

## Build command

```bash
cd mongrel-calculator/MongrelCalculator
xcodegen generate
xcodebuild -project MongrelCalculator.xcodeproj \
           -scheme MongrelCalculator \
           -destination 'platform=macOS' \
           CODE_SIGNING_ALLOWED=NO test
```

## Build status

**BUILD AND 13 TESTS SUCCEEDED** — macOS, `CODE_SIGNING_ALLOWED=NO`, verified August 2026.

The XcodeGen project keeps Hardened Runtime enabled for eventual Developer ID distribution, while unsigned local builds can opt out of signing at the command line. No App Store sandbox assumptions are built into the app.

## Roadmap

- Programmer mode (hex/oct/bin, bitwise ops)
- Full scientific mode (sin/cos/tan, log, ln, eˣ, factorial)
- History popover (scrollable full log)
- Ominous-glass window chrome (custom close/minimize buttons)

## Source status

The source is visible during active development, but a formal open-source license has not been selected. No reuse license is granted yet.
