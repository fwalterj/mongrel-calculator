import XCTest
import AppKit
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
        XCTAssertEqual(engine.issue, .divisionByZero)

        enter("7")
        XCTAssertEqual(engine.display, "7")
        XCTAssertNil(engine.issue)
    }

    func test_divisionByZeroDuringChainingDoesNotSilentlyReplaceOperator() {
        enter("8", "÷", "0", "+")

        XCTAssertEqual(engine.display, "Error")
        XCTAssertEqual(engine.issue, .divisionByZero)
        XCTAssertNil(engine.activeOperation)

        enter("+")
        XCTAssertEqual(engine.display, "Error")

        enter("4", "+", "3", "=")
        XCTAssertEqual(engine.display, "7")
    }

    func test_negativeSquareRootReportsSpecificIssueAndClearEntryRecovers() {
        enter("9", "±", "√")
        XCTAssertEqual(engine.display, "Error")
        XCTAssertEqual(engine.issue, .negativeSquareRoot)

        enter("CE")
        XCTAssertEqual(engine.display, "0")
        XCTAssertNil(engine.issue)
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

    func test_readoutShowsPendingExpressionAsItIsEntered() {
        enter("45", "+")
        XCTAssertEqual(engine.readout, "45 +")

        enter("86")
        XCTAssertEqual(engine.readout, "45 + 86")

        enter("=")
        XCTAssertEqual(engine.readout, "131")
    }

    func test_readoutTracksOperatorReplacementAndChaining() {
        enter("5", "+", "×")
        XCTAssertEqual(engine.readout, "5 ×")

        enter("2", "+")
        XCTAssertEqual(engine.readout, "10 +")
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

    func test_tinyNonzeroResultsUseScientificNotationInsteadOfRoundingToZero() {
        enter("1", "÷")
        XCTAssertTrue(engine.pasteNumber("1000000000000000"))
        enter("=")

        XCTAssertNotEqual(engine.display, "0")
        XCTAssertEqual(Double(engine.display), 1e-15)
        XCTAssertTrue(engine.display.contains("e"))
    }

    func test_overflowBecomesRecoverableError() {
        XCTAssertTrue(engine.pasteNumber("1e308"))
        enter("x²")

        XCTAssertEqual(engine.display, "Error")
        XCTAssertEqual(engine.issue, .resultOutOfRange)

        enter("2")
        XCTAssertEqual(engine.display, "2")
        XCTAssertNil(engine.issue)
    }

    func test_validPasteCanBeUsedAsSecondOperand() {
        enter("5", "+")
        XCTAssertTrue(engine.pasteNumber("2.5"))
        enter("=")

        XCTAssertEqual(engine.display, "7.5")
    }

    func test_pasteAcceptsDecimalCommaAndRejectsNonNumbers() {
        let germanLocale = Locale(identifier: "de_DE")
        XCTAssertTrue(engine.pasteNumber(" 12,5\n", locale: germanLocale))
        XCTAssertEqual(engine.display, "12.5")

        XCTAssertFalse(engine.pasteNumber("twelve"))
        XCTAssertEqual(engine.display, "Error")
        XCTAssertEqual(engine.issue, .invalidNumber)
    }

    func test_pasteDisambiguatesGroupingAndDecimalSeparatorsByLocale() {
        let usLocale = Locale(identifier: "en_US")
        let germanLocale = Locale(identifier: "de_DE")

        XCTAssertTrue(engine.pasteNumber("1,234", locale: usLocale))
        XCTAssertEqual(engine.display, "1234")

        XCTAssertTrue(engine.pasteNumber("1,234", locale: germanLocale))
        XCTAssertEqual(engine.display, "1.234")

        XCTAssertTrue(engine.pasteNumber("1.234,5", locale: germanLocale))
        XCTAssertEqual(engine.display, "1234.5")

        XCTAssertTrue(engine.pasteNumber("1,234.5", locale: usLocale))
        XCTAssertEqual(engine.display, "1234.5")
    }

    func test_commonBinaryFloatingPointCaseFormatsAsExpected() {
        enter("0", ".", "1", "+", "0", ".", "2", "=")
        XCTAssertEqual(engine.display, "0.3")
    }

    func test_memoryOverflowDoesNotStoreInfinity() {
        XCTAssertTrue(engine.pasteNumber("1e308"))
        enter("M+", "M+")

        XCTAssertEqual(engine.display, "Error")
        XCTAssertEqual(engine.issue, .resultOutOfRange)
        XCTAssertEqual(engine.memoryValue, 1e308)
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

    func test_unaryOperationsAreRecordedAndHistoryCanBeCleared() {
        enter("9", "√")
        XCTAssertEqual(engine.history, ["√(9) = 3"])

        engine.clearHistory()
        XCTAssertTrue(engine.history.isEmpty)
    }

    func test_separateCalculatorSessionsDoNotShareState() {
        let otherEngine = CalculatorEngine()

        enter("45", "+", "86", "=")

        XCTAssertEqual(engine.display, "131")
        XCTAssertEqual(engine.history, ["45 + 86 = 131"])
        XCTAssertEqual(otherEngine.display, "0")
        XCTAssertTrue(otherEngine.history.isEmpty)
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

final class CalculatorKeyboardMapperTests: XCTestCase {
    func test_commandShortcutsAreNotConsumedAsCalculatorInput() {
        XCTAssertNil(
            CalculatorKeyboardMapper.map(
                keyCode: 8,
                characters: "c",
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            CalculatorKeyboardMapper.map(
                keyCode: 9,
                characters: "v",
                modifiers: [.command]
            )
        )
    }

    func test_plainKeyboardAliasesMapToCalculatorOperations() {
        XCTAssertEqual(map(keyCode: 7, character: "x"), "×")
        XCTAssertEqual(map(keyCode: 44, character: "/"), "÷")
        XCTAssertEqual(map(keyCode: 43, character: ","), ".")
        XCTAssertEqual(map(keyCode: 117, character: nil), "⌫")
    }

    private func map(keyCode: UInt16, character: String?) -> String? {
        CalculatorKeyboardMapper.map(
            keyCode: keyCode,
            characters: character,
            modifiers: []
        )
    }
}

@MainActor
final class MongrelAppearanceModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MongrelAppearanceModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testContrastModeIsExactBlackAndWhiteAtMaximumRatio() {
        let appearance = MongrelAppearanceModel(defaults: defaults)

        XCTAssertEqual(appearance.mode, .contrast)
        XCTAssertEqual(appearance.backgroundHex, "#000000")
        XCTAssertEqual(appearance.textHex, "#FFFFFF")
        XCTAssertEqual(appearance.contrastRatio, 21, accuracy: 0.0001)
        XCTAssertEqual(appearance.foregroundOpacity(0.28), 0.72)
    }

    func testCustomColorsPersistAcrossModelInstances() {
        let appearance = MongrelAppearanceModel(defaults: defaults)
        appearance.mode = .custom
        appearance.backgroundHue = 0.12
        appearance.backgroundSaturation = 0.34
        appearance.backgroundBrightness = 0.56
        appearance.textHue = 0.78
        appearance.textSaturation = 0.21
        appearance.textBrightness = 0.92

        let restored = MongrelAppearanceModel(defaults: defaults)
        XCTAssertEqual(restored.mode, .custom)
        XCTAssertEqual(restored.backgroundHue, 0.12, accuracy: 0.0001)
        XCTAssertEqual(restored.backgroundSaturation, 0.34, accuracy: 0.0001)
        XCTAssertEqual(restored.backgroundBrightness, 0.56, accuracy: 0.0001)
        XCTAssertEqual(restored.textHue, 0.78, accuracy: 0.0001)
        XCTAssertEqual(restored.textSaturation, 0.21, accuracy: 0.0001)
        XCTAssertEqual(restored.textBrightness, 0.92, accuracy: 0.0001)
    }

    func testClassicModePreservesOriginalSecondaryCueOpacity() {
        let appearance = MongrelAppearanceModel(defaults: defaults)
        appearance.mode = .classic

        XCTAssertEqual(appearance.foregroundOpacity(0.28), 0.28)
    }

    func testImproveReadabilityRepairsAnIllegibleCustomPair() {
        let appearance = MongrelAppearanceModel(defaults: defaults)
        appearance.mode = .custom
        appearance.backgroundHue = 0
        appearance.backgroundSaturation = 0
        appearance.backgroundBrightness = 0.5
        appearance.textHue = 0
        appearance.textSaturation = 0
        appearance.textBrightness = 0.5

        XCTAssertEqual(appearance.contrastRatio, 1, accuracy: 0.0001)
        appearance.improveCustomReadability()
        XCTAssertGreaterThanOrEqual(appearance.contrastRatio, 7)
    }

    func testInvalidStoredSliderValuesAreClamped() {
        defaults.set(2.5, forKey: MongrelAppearanceModel.backgroundBrightnessKey)
        defaults.set(-1.0, forKey: MongrelAppearanceModel.textBrightnessKey)

        let appearance = MongrelAppearanceModel(defaults: defaults)
        XCTAssertEqual(appearance.backgroundBrightness, 1)
        XCTAssertEqual(appearance.textBrightness, 0)
    }

    func testResetCustomColorsRestoresAccessibleDefaults() {
        let appearance = MongrelAppearanceModel(defaults: defaults)
        appearance.mode = .custom
        appearance.backgroundBrightness = 1
        appearance.textBrightness = 0

        appearance.resetCustomColors()

        XCTAssertEqual(appearance.backgroundHue, MongrelAppearanceModel.defaultBackgroundHue)
        XCTAssertEqual(appearance.backgroundBrightness, MongrelAppearanceModel.defaultBackgroundBrightness)
        XCTAssertEqual(appearance.textHue, MongrelAppearanceModel.defaultTextHue)
        XCTAssertEqual(appearance.textBrightness, MongrelAppearanceModel.defaultTextBrightness)
        XCTAssertGreaterThanOrEqual(appearance.contrastRatio, 7)
    }
}
