import Foundation

// MARK: - Calculator Engine
// Synchronous, always called from the main thread (button actions + NSEvent main-thread callbacks).

@MainActor
final class CalculatorEngine: ObservableObject {
    @Published private(set) var display: String = "0"
    @Published private(set) var history: [String] = []
    @Published private(set) var memoryValue: Double = 0
    @Published private(set) var activeOperation: String? = nil

    private var firstOperand: Double?
    private var pendingOperation: String?
    private var shouldResetDisplay: Bool = false
    private var hasEnteredSecondOperand: Bool = false
    private var repeatedOperation: String?
    private var repeatedOperand: Double?

    var hasMemory: Bool { memoryValue != 0 }

    // Reusable formatter — never has grouping separators so Double(_:) can parse display back.
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 10
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = false
        f.locale = Locale(identifier: "en_US_POSIX")
        f.decimalSeparator = "."
        return f
    }()

    // MARK: - Input

    func input(_ key: String) {
        if key.count == 1, let ch = key.first, ch.isNumber {
            appendDigit(key)
        } else if key == "." {
            appendDecimal()
        } else {
            handleOperation(key)
        }
        activeOperation = pendingOperation
    }

    // MARK: - Digit / decimal entry

    private func appendDigit(_ digit: String) {
        if shouldResetDisplay {
            clearRepeatedOperationIfStartingNewCalculation()
            display = digit == "0" ? "0" : digit
            shouldResetDisplay = false
            hasEnteredSecondOperand = pendingOperation != nil
            return
        }
        guard display.count < 15 else { return }
        display = display == "0" ? digit : display + digit
    }

    private func appendDecimal() {
        if shouldResetDisplay {
            clearRepeatedOperationIfStartingNewCalculation()
            display = "0."
            shouldResetDisplay = false
            hasEnteredSecondOperand = pendingOperation != nil
            return
        }
        guard !display.contains(".") else { return }
        display += "."
    }

    // MARK: - Operations

    private func handleOperation(_ op: String) {
        switch op {
        case "C":    clear()
        case "CE":   clearEntry()
        case "⌫":    backspace()
        case "±":    toggleSign()
        case "%":    percentage()
        case "√":    squareRoot()
        case "x²":   square()
        case "1/x":  reciprocal()
        case "+", "−", "×", "÷": setPendingOp(op)
        case "=":    calculate()
        case "MC":   memoryValue = 0
        case "MR":
            display = format(memoryValue)
            shouldResetDisplay = true
            hasEnteredSecondOperand = pendingOperation != nil
        case "M+":
            if let v = parseDisplay() { memoryValue += v }
        case "M−":
            if let v = parseDisplay() { memoryValue -= v }
        default: break
        }
    }

    private func clear() {
        display = "0"
        firstOperand = nil
        pendingOperation = nil
        shouldResetDisplay = false
        hasEnteredSecondOperand = false
        repeatedOperation = nil
        repeatedOperand = nil
    }

    private func clearEntry() {
        display = "0"
        shouldResetDisplay = false
        hasEnteredSecondOperand = pendingOperation != nil
        clearRepeatedOperationIfStartingNewCalculation()
    }

    private func backspace() {
        guard !shouldResetDisplay else { return }
        if display.count <= 1 || (display.count == 2 && display.hasPrefix("-")) {
            display = "0"
        } else {
            display.removeLast()
        }
    }

    private func toggleSign() {
        guard let v = parseDisplay() else { return }
        display = format(-v)
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func percentage() {
        guard let v = parseDisplay() else { return }
        // Add/subtract use a percentage of the first operand. Multiply/divide
        // use the entered value as a conventional fractional percentage.
        if let base = firstOperand,
           pendingOperation == "+" || pendingOperation == "−" {
            display = format(base * v / 100)
        } else {
            display = format(v / 100)
        }
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func squareRoot() {
        guard let v = parseDisplay() else { return }
        guard v >= 0 else { display = "Error"; shouldResetDisplay = true; return }
        display = format(Foundation.sqrt(v))
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func square() {
        guard let v = parseDisplay() else { return }
        display = format(v * v)
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func reciprocal() {
        guard let v = parseDisplay(), v != 0 else {
            display = "Error"
            shouldResetDisplay = true
            return
        }
        display = format(1.0 / v)
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func setPendingOp(_ op: String) {
        if let existing = pendingOperation,
           let first = firstOperand,
           hasEnteredSecondOperand,
           let second = parseDisplay() {
            if let result = perform(existing, lhs: first, rhs: second) {
                firstOperand = result
                display = format(result)
            }
        } else {
            firstOperand = parseDisplay()
        }
        pendingOperation = op
        shouldResetDisplay = true
        hasEnteredSecondOperand = false
        repeatedOperation = nil
        repeatedOperand = nil
    }

    private func calculate() {
        let op: String
        let first: Double
        let second: Double

        if let pendingOperation,
           let firstOperand,
           let currentValue = parseDisplay() {
            op = pendingOperation
            first = firstOperand
            second = currentValue
            repeatedOperation = pendingOperation
            repeatedOperand = currentValue
        } else if let repeatedOperation,
                  let repeatedOperand,
                  let currentValue = parseDisplay() {
            op = repeatedOperation
            first = currentValue
            second = repeatedOperand
        } else {
            return
        }

        guard let result = perform(op, lhs: first, rhs: second) else {
            display = "Error"
            firstOperand = nil
            pendingOperation = nil
            shouldResetDisplay = true
            hasEnteredSecondOperand = false
            repeatedOperation = nil
            repeatedOperand = nil
            return
        }
        pushHistory("\(format(first)) \(op) \(format(second)) = \(format(result))")
        display = format(result)
        firstOperand = nil
        pendingOperation = nil
        shouldResetDisplay = true
        hasEnteredSecondOperand = false
    }

    private func perform(_ op: String, lhs: Double, rhs: Double) -> Double? {
        switch op {
        case "+": return lhs + rhs
        case "−": return lhs - rhs
        case "×": return lhs * rhs
        case "÷": return rhs == 0 ? nil : lhs / rhs
        default:  return nil
        }
    }

    // MARK: - Helpers

    private func parseDisplay() -> Double? {
        Double(display)
    }

    private func clearRepeatedOperationIfStartingNewCalculation() {
        guard pendingOperation == nil else { return }
        repeatedOperation = nil
        repeatedOperand = nil
    }

    private func format(_ value: Double) -> String {
        guard !value.isNaN, !value.isInfinite else { return "Error" }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func pushHistory(_ line: String) {
        history.append(line)
        if history.count > 30 { history.removeFirst(history.count - 30) }
    }
}
