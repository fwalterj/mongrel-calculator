import XCTest
@testable import MongrelCalculator

@MainActor
final class CalculatorEngineTests: XCTestCase {

    private var engine: CalculatorEngine!

    override func setUp() {
        super.setUp()
        engine = CalculatorEngine()
    }

    func test_basicArithmetic() {
        enter("12", "+", "8", "=")
        XCTAssertEqual(engine.display, "20")

        enter("C", "9", "−", "4", "=")
        XCTAssertEqual(engine.display, "5")

        enter("C", "7", "×", "6", "=")
        XCTAssertEqual(engine.display, "42")

        enter("C", "8", "÷", "4", "=")
        XCTAssertEqual(engine.display, "2")
    }

    func test_divisionByZeroRecoversOnNextDigit() {
        enter("8", "÷", "0", "=")
        XCTAssertEqual(engine.display, "Error")

        enter("7")
        XCTAssertEqual(engine.display, "7")
    }

    func test_additivePercentageUsesFirstOperandAsBase() {
        enter("200", "+", "10", "%", "=")
        XCTAssertEqual(engine.display, "220")
    }

    func test_multiplicativePercentageUsesFraction() {
        enter("200", "×", "10", "%", "=")
        XCTAssertEqual(engine.display, "20")
    }

    func test_divisionByPercentageUsesFraction() {
        enter("200", "÷", "10", "%", "=")
        XCTAssertEqual(engine.display, "2000")
    }

    func test_percentageResultParticipatesInChainedOperation() {
        enter("200", "+", "10", "%", "×", "2", "=")
        XCTAssertEqual(engine.display, "440")
    }

    func test_operatorCanBeReplacedBeforeSecondOperand() {
        enter("5", "+", "×", "2", "=")
        XCTAssertEqual(engine.display, "10")
    }

    func test_repeatedEqualsReplaysLastOperation() {
        enter("5", "+", "2", "=", "=", "=")
        XCTAssertEqual(engine.display, "11")
        XCTAssertEqual(engine.history, ["5 + 2 = 7", "7 + 2 = 9", "9 + 2 = 11"])
    }

    func test_newDigitAfterResultClearsRepeatedOperation() {
        enter("5", "+", "2", "=", "9", "=")
        XCTAssertEqual(engine.display, "9")
    }

    func test_newDigitCanReplaceLongResult() {
        enter("999999999999999", "+", "1", "=", "2")
        XCTAssertEqual(engine.display, "2")
    }

    func test_decimalOutputAlwaysRoundTripsWithPeriod() {
        enter("1", "÷", "2", "=")
        XCTAssertEqual(engine.display, "0.5")

        enter("×", "2", "=")
        XCTAssertEqual(engine.display, "1")
    }

    func test_memoryRecallStartsFreshEntry() {
        enter("8", "M+", "C", "MR", "3")
        XCTAssertEqual(engine.display, "3")
        XCTAssertTrue(engine.hasMemory)
    }

    func test_historyIsCappedAtThirtyEntries() {
        for _ in 0..<35 {
            enter("1", "+", "1", "=", "C")
        }
        XCTAssertEqual(engine.history.count, 30)
    }

    private func enter(_ keys: String...) {
        for keyGroup in keys {
            if keyGroup.allSatisfy(\.isNumber) {
                keyGroup.forEach { engine.input(String($0)) }
            } else {
                engine.input(keyGroup)
            }
        }
    }
}
