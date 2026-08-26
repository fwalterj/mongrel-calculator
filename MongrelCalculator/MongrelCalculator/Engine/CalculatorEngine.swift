import Foundation

enum CalculatorIssue: Error, Equatable {
    case divisionByZero
    case negativeSquareRoot
    case resultOutOfRange
    case invalidNumber

    var message: String {
        switch self {
        case .divisionByZero:
            return "Cannot divide by zero"
        case .negativeSquareRoot:
            return "Square root requires a non-negative number"
        case .resultOutOfRange:
            return "Result is outside the supported range"
        case .invalidNumber:
            return "That is not a valid number"
        }
    }
}

// MARK: - Calculator Engine

@MainActor
final class CalculatorEngine: ObservableObject {
    @Published private(set) var display = "0"
    @Published private(set) var history: [String] = []
    @Published private(set) var memoryValue: Double = 0
    @Published private(set) var activeOperation: String?
    @Published private(set) var issue: CalculatorIssue?

    private var firstOperand: Double?
    private var pendingOperation: String?
    private var shouldResetDisplay = false
    private var hasEnteredSecondOperand = false
    private var repeatedOperation: String?
    private var repeatedOperand: Double?

    var hasMemory: Bool { memoryValue != 0 }

    /// The complete in-progress expression shown in the primary readout.
    /// `display` remains the parseable current operand used by the engine.
    var readout: String {
        guard let firstOperand, let pendingOperation else { return display }

        let expression = "\(format(firstOperand)) \(pendingOperation)"
        return hasEnteredSecondOperand ? "\(expression) \(display)" : expression
    }

    private let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 15
        formatter.minimumSignificantDigits = 1
        formatter.maximumFractionDigits = 15
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = "."
        return formatter
    }()

    private let scientificFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 12
        formatter.minimumSignificantDigits = 1
        formatter.exponentSymbol = "e"
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = "."
        return formatter
    }()

    // MARK: - Input

    func input(_ key: String) {
        if key.count == 1, let character = key.first, character.isNumber {
            appendDigit(key)
        } else if key == "." {
            appendDecimal()
        } else {
            handleOperation(key)
        }
        activeOperation = pendingOperation
    }

    /// Replaces the current entry with a finite, parseable number from the pasteboard.
    @discardableResult
    func pasteNumber(_ rawValue: String, locale: Locale = .current) -> Bool {
        var candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
        candidate = normalizeSeparators(in: candidate, locale: locale)

        let allowed = CharacterSet(charactersIn: "+-.eE0123456789")
        guard !candidate.isEmpty,
              candidate.unicodeScalars.allSatisfy(allowed.contains),
              candidate.filter(\.isNumber).count <= 18,
              let value = Double(candidate),
              value.isFinite else {
            fail(.invalidNumber)
            return false
        }

        issue = nil
        display = format(value)
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
        clearRepeatedOperationIfStartingNewCalculation()
        return true
    }

    func clearHistory() {
        history.removeAll()
    }

    // MARK: - Digit / decimal entry

    private func appendDigit(_ digit: String) {
        recoverForFreshEntryIfNeeded()

        if shouldResetDisplay {
            clearRepeatedOperationIfStartingNewCalculation()
            display = digit == "0" ? "0" : digit
            shouldResetDisplay = false
            hasEnteredSecondOperand = pendingOperation != nil
            return
        }

        guard display.filter(\.isNumber).count < 15 else { return }
        display = display == "0" ? digit : display + digit
    }

    private func appendDecimal() {
        recoverForFreshEntryIfNeeded()

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

    private func handleOperation(_ operation: String) {
        switch operation {
        case "C":
            clear()
        case "CE":
            clearEntry()
        case "⌫":
            backspace()
        case "MC":
            memoryValue = 0
        case "MR":
            recallMemory()
        default:
            guard issue == nil else { return }
            switch operation {
            case "±": toggleSign()
            case "%": percentage()
            case "√": squareRoot()
            case "x²": square()
            case "1/x": reciprocal()
            case "+", "−", "×", "÷": setPendingOperation(operation)
            case "=": calculate()
            case "M+": adjustMemory(by: 1)
            case "M−": adjustMemory(by: -1)
            default: break
            }
        }
    }

    private func clear() {
        display = "0"
        issue = nil
        resetOperationState()
        shouldResetDisplay = false
    }

    private func clearEntry() {
        if issue != nil {
            clear()
            return
        }

        display = "0"
        shouldResetDisplay = false
        hasEnteredSecondOperand = pendingOperation != nil
        clearRepeatedOperationIfStartingNewCalculation()
    }

    private func backspace() {
        guard issue == nil, !shouldResetDisplay else { return }
        if display.count <= 1 || (display.count == 2 && display.hasPrefix("-")) {
            display = "0"
        } else {
            display.removeLast()
        }
    }

    private func toggleSign() {
        guard let value = parseDisplay() else { return }
        display = format(-value)
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func percentage() {
        guard let value = parseDisplay() else { return }
        let result: Double

        // Add/subtract use a percentage of the first operand. Multiply/divide
        // use the entered value as a conventional fractional percentage.
        if let base = firstOperand,
           pendingOperation == "+" || pendingOperation == "−" {
            result = base * value / 100
        } else {
            result = value / 100
        }

        guard result.isFinite else {
            fail(.resultOutOfRange)
            return
        }
        display = format(result)
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func squareRoot() {
        guard let value = parseDisplay() else { return }
        guard value >= 0 else {
            fail(.negativeSquareRoot)
            return
        }

        let result = Foundation.sqrt(value)
        display = format(result)
        pushHistory("√(\(format(value))) = \(display)")
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func square() {
        guard let value = parseDisplay() else { return }
        let result = value * value
        guard result.isFinite else {
            fail(.resultOutOfRange)
            return
        }

        display = format(result)
        pushHistory("\(format(value))² = \(display)")
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func reciprocal() {
        guard let value = parseDisplay() else { return }
        guard value != 0 else {
            fail(.divisionByZero)
            return
        }

        let result = 1 / value
        guard result.isFinite else {
            fail(.resultOutOfRange)
            return
        }

        display = format(result)
        pushHistory("1 ÷ \(format(value)) = \(display)")
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func setPendingOperation(_ operation: String) {
        guard let currentValue = parseDisplay() else { return }

        if let existing = pendingOperation,
           let first = firstOperand,
           hasEnteredSecondOperand {
            switch perform(existing, lhs: first, rhs: currentValue) {
            case .success(let result):
                firstOperand = result
                display = format(result)
            case .failure(let calculationIssue):
                fail(calculationIssue)
                return
            }
        } else if pendingOperation == nil {
            firstOperand = currentValue
        }

        pendingOperation = operation
        shouldResetDisplay = true
        hasEnteredSecondOperand = false
        repeatedOperation = nil
        repeatedOperand = nil
    }

    private func calculate() {
        let operation: String
        let first: Double
        let second: Double

        if let pendingOperation,
           let firstOperand,
           let currentValue = parseDisplay() {
            operation = pendingOperation
            first = firstOperand
            second = currentValue
        } else if let repeatedOperation,
                  let repeatedOperand,
                  let currentValue = parseDisplay() {
            operation = repeatedOperation
            first = currentValue
            second = repeatedOperand
        } else {
            return
        }

        switch perform(operation, lhs: first, rhs: second) {
        case .success(let result):
            repeatedOperation = operation
            repeatedOperand = second
            pushHistory("\(format(first)) \(operation) \(format(second)) = \(format(result))")
            display = format(result)
            firstOperand = nil
            pendingOperation = nil
            shouldResetDisplay = true
            hasEnteredSecondOperand = false
        case .failure(let calculationIssue):
            fail(calculationIssue)
        }
    }

    private func perform(
        _ operation: String,
        lhs: Double,
        rhs: Double
    ) -> Result<Double, CalculatorIssue> {
        let result: Double
        switch operation {
        case "+": result = lhs + rhs
        case "−": result = lhs - rhs
        case "×": result = lhs * rhs
        case "÷":
            guard rhs != 0 else { return .failure(.divisionByZero) }
            result = lhs / rhs
        default:
            return .failure(.invalidNumber)
        }

        guard result.isFinite else { return .failure(.resultOutOfRange) }
        return .success(result)
    }

    // MARK: - Memory

    private func recallMemory() {
        issue = nil
        display = format(memoryValue)
        shouldResetDisplay = true
        hasEnteredSecondOperand = pendingOperation != nil
    }

    private func adjustMemory(by multiplier: Double) {
        guard let value = parseDisplay() else { return }
        let result = memoryValue + (value * multiplier)
        guard result.isFinite else {
            fail(.resultOutOfRange)
            return
        }
        memoryValue = result
    }

    // MARK: - Helpers

    private func parseDisplay() -> Double? {
        guard let value = Double(display), value.isFinite else { return nil }
        return value
    }

    private func normalizeSeparators(in value: String, locale: Locale) -> String {
        let hasComma = value.contains(",")
        let hasPeriod = value.contains(".")

        if hasComma && hasPeriod,
           let commaIndex = value.lastIndex(of: ","),
           let periodIndex = value.lastIndex(of: ".") {
            let commaIsDecimal = commaIndex > periodIndex
            return commaIsDecimal
                ? value.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                : value.replacingOccurrences(of: ",", with: "")
        }

        guard hasComma else { return value }
        if locale.decimalSeparator == "," || !looksLikeGroupedInteger(value, separator: ",") {
            return value.replacingOccurrences(of: ",", with: ".")
        }
        return value.replacingOccurrences(of: ",", with: "")
    }

    private func looksLikeGroupedInteger(_ value: String, separator: Character) -> Bool {
        let unsigned = value.first == "+" || value.first == "-"
            ? String(value.dropFirst())
            : value
        let groups = unsigned.split(separator: separator, omittingEmptySubsequences: false)
        guard groups.count > 1,
              (1...3).contains(groups[0].count),
              groups.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            return false
        }
        return groups.dropFirst().allSatisfy { $0.count == 3 }
    }

    private func recoverForFreshEntryIfNeeded() {
        guard issue != nil else { return }
        display = "0"
        issue = nil
        resetOperationState()
    }

    private func resetOperationState() {
        firstOperand = nil
        pendingOperation = nil
        hasEnteredSecondOperand = false
        repeatedOperation = nil
        repeatedOperand = nil
        activeOperation = nil
    }

    private func clearRepeatedOperationIfStartingNewCalculation() {
        guard pendingOperation == nil else { return }
        repeatedOperation = nil
        repeatedOperand = nil
    }

    private func fail(_ calculationIssue: CalculatorIssue) {
        display = "Error"
        issue = calculationIssue
        resetOperationState()
        shouldResetDisplay = true
    }

    private func format(_ value: Double) -> String {
        guard value.isFinite else { return "Error" }
        guard value != 0 else { return "0" }

        let magnitude = abs(value)
        let formatter = magnitude >= 1e15 || magnitude < 1e-10
            ? scientificFormatter
            : decimalFormatter
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func pushHistory(_ line: String) {
        history.append(line)
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
    }
}
