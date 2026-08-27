# Changelog

## 0.9.1-beta.1 - 2026-08-27

### Fixed

- Contrast is now the first-launch default; the original appearance remains available as Classic.
- Contrast mode now uses exact black and white throughout the calculator at a measured 21:1 ratio.
- Appearance changes now update every open calculator and Settings window from one shared live model.
- Custom color preferences are clamped when loaded and persist reliably between launches.
- Settings remain readable even when a custom pair has little or no contrast.
- The generated test bundle now includes its required Info.plist, so the documented test command works without code-signing workarounds.

### Added

- Settings show the current hexadecimal colors, measured contrast ratio, and WCAG AA/AAA status.
- Low-contrast custom pairs can be repaired with one click or returned to the default palette.
- Six regression tests cover the default mode, exact Contrast output, cue opacity, persistence, invalid stored values, readability repair, and reset behavior.

## 0.9.0-beta.1 - 2026-08-25

### Added

- Standard, high-contrast, and custom background/text appearance modes.
- Native copy-result and paste-number commands.
- Full calculation-history popover with clear-history control.
- Specific, recoverable messages for invalid arithmetic.
- VoiceOver labels, keyboard help, and Reduce Motion support.
- Universal macOS beta packaging with optional Developer ID signing, notarization, stapling, and a SHA-256 checksum.

### Fixed

- Very small nonzero results no longer round down to zero.
- Division by zero during operator chaining now stops the expression instead of silently replacing the operator.
- Overflow and non-finite memory values can no longer poison later calculations.
- Command, Control, and Option shortcuts are no longer consumed as ordinary calculator keystrokes.
- Forward Delete, decimal comma, and X now behave as expected keyboard aliases.
- Pasted decimal and grouping separators are interpreted according to locale, including mixed US and European number formats.
- Native tabs retain isolated calculation, history, memory, and keyboard state.
