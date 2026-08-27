# Beta Test Checklist

Run this checklist on every release candidate after the automated tests pass.

## Arithmetic

- Verify all four binary operations, decimals, negative numbers, percentages, repeated equals, and operator replacement.
- Verify division by zero, reciprocal of zero, negative square root, and overflow show a useful error and recover on the next digit.
- Verify tiny and very large finite results remain nonzero and use readable scientific notation.
- Verify MC, MR, M+, and M- across ordinary and error states.

## Input and Sessions

- Verify keypad, number row, decimal comma/period, X, Return, Escape, Backspace, and Forward Delete.
- Verify Command-C copies only the displayed value and Command-V accepts finite numbers while rejecting prose.
- Open multiple windows and native tabs; verify display, pending operation, memory, history, and keyboard input remain isolated.
- Verify closing a tab removes its transient state without altering another tab.

## Interface and Accessibility

- On a clean preferences domain, confirm Contrast is the default.
- Inspect Classic, Contrast, and Custom appearance modes, including extreme custom colors.
- Confirm Contrast reports #000000, #FFFFFF, and 21:1 in Settings.
- Set identical Custom background and text colors, confirm Settings remains readable, then use Improve Readability and verify an AAA result.
- Quit and relaunch after changing the appearance; confirm the selected mode and sliders persist.
- Run VoiceOver through the display, history, memory indicator, and every calculator key.
- Enable Reduce Motion and verify button presses no longer scale.
- Verify the full history popover scrolls and clears without changing the current calculation.

## Distribution

- Test the zip on a clean Apple silicon Mac.
- Test the zip on an Intel Mac or an Intel macOS virtual machine.
- Developer ID sign and notarize the public artifact, then verify it with codesign and spctl.
- Compare the downloaded archive against its .sha256 file.
