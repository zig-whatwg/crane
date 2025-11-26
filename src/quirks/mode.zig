//! Quirks Mode Enumeration
//!
//! Defines the three document compatibility modes per WHATWG Quirks Mode Standard.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//!
//! ## Modes
//!
//! - **No-Quirks Mode**: Standards mode, modern DOCTYPE present
//! - **Quirks Mode**: Legacy/missing DOCTYPE, full quirks apply
//! - **Limited-Quirks Mode**: Partial quirks (mainly table-related)

const std = @import("std");

/// Document compatibility mode per WHATWG Quirks Mode Standard.
///
/// Determines which backward-compatible behaviors apply to CSS parsing,
/// selector matching, and layout calculations.
///
/// ## Algorithm Selection
///
/// The mode is typically set during HTML parsing based on the DOCTYPE:
/// - Modern DOCTYPE (e.g., `<!DOCTYPE html>`) → `no_quirks`
/// - Legacy DOCTYPE or missing → `quirks`
/// - Certain legacy DOCTYPEs → `limited_quirks`
///
/// ## Usage
///
/// ```zig
/// const mode = QuirksMode.no_quirks;
///
/// if (mode == .quirks) {
///     // Apply quirks mode behavior
/// }
/// ```
pub const QuirksMode = enum {
    /// No-quirks mode (standards mode).
    ///
    /// Modern rendering behavior. Used when a proper DOCTYPE is present.
    /// No backward-compatible quirks are applied.
    no_quirks,

    /// Full quirks mode.
    ///
    /// Maximum backward compatibility for legacy documents.
    /// All quirks defined in the WHATWG Quirks Mode Standard apply:
    /// - CSS quirks (hashless hex colors, unitless lengths, etc.)
    /// - Selector quirks (:active/:hover on non-links)
    /// - Layout quirks (percentage height, table sizing, etc.)
    quirks,

    /// Limited quirks mode (almost standards mode).
    ///
    /// Partial backward compatibility. Only certain quirks apply:
    /// - Line height calculation quirk
    /// - Blocks ignore line-height quirk
    ///
    /// Other quirks (hashless hex colors, unitless lengths, etc.) do NOT apply.
    limited_quirks,

    /// Returns true if this mode enables full quirks.
    pub fn isQuirks(self: QuirksMode) bool {
        return self == .quirks;
    }

    /// Returns true if this mode enables limited quirks.
    pub fn isLimitedQuirks(self: QuirksMode) bool {
        return self == .limited_quirks;
    }

    /// Returns true if this mode is standards mode (no quirks).
    pub fn isNoQuirks(self: QuirksMode) bool {
        return self == .no_quirks;
    }

    /// Returns true if line height quirks apply (quirks OR limited-quirks mode).
    ///
    /// Per WHATWG Quirks spec, line height quirks apply in both
    /// quirks mode and limited-quirks mode.
    pub fn hasLineHeightQuirks(self: QuirksMode) bool {
        return self == .quirks or self == .limited_quirks;
    }

    /// Returns true if CSS value quirks apply (quirks mode ONLY).
    ///
    /// Per WHATWG Quirks spec, CSS value quirks (hashless hex colors,
    /// unitless lengths) only apply in full quirks mode.
    pub fn hasCssValueQuirks(self: QuirksMode) bool {
        return self == .quirks;
    }

    /// Returns true if selector quirks apply (quirks mode ONLY).
    ///
    /// Per WHATWG Quirks spec, the :active/:hover quirk only applies
    /// in full quirks mode.
    pub fn hasSelectorQuirks(self: QuirksMode) bool {
        return self == .quirks;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "QuirksMode - no_quirks mode" {
    const mode = QuirksMode.no_quirks;

    try std.testing.expect(mode.isNoQuirks());
    try std.testing.expect(!mode.isQuirks());
    try std.testing.expect(!mode.isLimitedQuirks());
    try std.testing.expect(!mode.hasLineHeightQuirks());
    try std.testing.expect(!mode.hasCssValueQuirks());
    try std.testing.expect(!mode.hasSelectorQuirks());
}

test "QuirksMode - quirks mode" {
    const mode = QuirksMode.quirks;

    try std.testing.expect(!mode.isNoQuirks());
    try std.testing.expect(mode.isQuirks());
    try std.testing.expect(!mode.isLimitedQuirks());
    try std.testing.expect(mode.hasLineHeightQuirks());
    try std.testing.expect(mode.hasCssValueQuirks());
    try std.testing.expect(mode.hasSelectorQuirks());
}

test "QuirksMode - limited_quirks mode" {
    const mode = QuirksMode.limited_quirks;

    try std.testing.expect(!mode.isNoQuirks());
    try std.testing.expect(!mode.isQuirks());
    try std.testing.expect(mode.isLimitedQuirks());
    try std.testing.expect(mode.hasLineHeightQuirks());
    try std.testing.expect(!mode.hasCssValueQuirks());
    try std.testing.expect(!mode.hasSelectorQuirks());
}
