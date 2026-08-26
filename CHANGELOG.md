# Changelog

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
