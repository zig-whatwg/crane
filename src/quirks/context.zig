//! Quirks Mode Context
//!
//! Provides a context struct for threading quirks mode through CSS parsing
//! and selector matching operations.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//!
//! ## Usage
//!
//! ```zig
//! const quirks = @import("quirks");
//!
//! // Create context for quirks mode document
//! const ctx = quirks.QuirksModeContext.init(.quirks);
//!
//! // Check if quirks apply for a specific property
//! if (ctx.allowsHashlessHexColor("color")) {
//!     // Parse "ffffff" as "#ffffff"
//! }
//! ```

const std = @import("std");
const QuirksMode = @import("mode.zig").QuirksMode;
const constants = @import("constants.zig");

/// Context for quirks mode operations.
///
/// This struct holds the current quirks mode and provides methods to query
/// whether specific quirks apply. It's designed to be threaded through
/// CSS parsing and selector matching operations.
///
/// ## Design Pattern
///
/// Following the browser pattern (Chrome, Firefox, WebKit), quirks mode
/// is stored at the document level and passed through to parsers/matchers
/// via a context object.
pub const QuirksModeContext = struct {
    /// The current quirks mode.
    mode: QuirksMode,

    /// Create a new quirks mode context.
    ///
    /// ## Parameters
    /// - `mode`: The quirks mode to use
    ///
    /// ## Example
    /// ```zig
    /// const ctx = QuirksModeContext.init(.quirks);
    /// ```
    pub fn init(mode: QuirksMode) QuirksModeContext {
        return .{ .mode = mode };
    }

    /// Create a context for no-quirks (standards) mode.
    pub fn noQuirks() QuirksModeContext {
        return init(.no_quirks);
    }

    /// Create a context for full quirks mode.
    pub fn quirks() QuirksModeContext {
        return init(.quirks);
    }

    /// Create a context for limited quirks mode.
    pub fn limitedQuirks() QuirksModeContext {
        return init(.limited_quirks);
    }

    // ========================================================================
    // Mode Queries
    // ========================================================================

    /// Returns the current quirks mode.
    pub fn getMode(self: QuirksModeContext) QuirksMode {
        return self.mode;
    }

    /// Returns true if in full quirks mode.
    pub fn isQuirksMode(self: QuirksModeContext) bool {
        return self.mode.isQuirks();
    }

    /// Returns true if in limited quirks mode.
    pub fn isLimitedQuirksMode(self: QuirksModeContext) bool {
        return self.mode.isLimitedQuirks();
    }

    /// Returns true if in no-quirks (standards) mode.
    pub fn isNoQuirksMode(self: QuirksModeContext) bool {
        return self.mode.isNoQuirks();
    }

    // ========================================================================
    // CSS Value Quirks
    // ========================================================================

    /// Check if hashless hex color is allowed for a property.
    ///
    /// In quirks mode, certain properties accept hex colors without the `#` prefix.
    /// For example, `color: ffffff` is treated as `color: #ffffff`.
    ///
    /// ## Parameters
    /// - `property`: CSS property name (case-insensitive)
    ///
    /// ## Returns
    /// `true` if:
    /// 1. Current mode is quirks mode, AND
    /// 2. The property is in the hashless hex color allowlist
    ///
    /// ## Example
    /// ```zig
    /// const ctx = QuirksModeContext.init(.quirks);
    /// try std.testing.expect(ctx.allowsHashlessHexColor("color"));
    /// try std.testing.expect(!ctx.allowsHashlessHexColor("background"));
    /// ```
    pub fn allowsHashlessHexColor(self: QuirksModeContext, property: []const u8) bool {
        if (!self.mode.hasCssValueQuirks()) {
            return false;
        }
        return constants.isHashlessHexColorProperty(property);
    }

    /// Check if unitless length is allowed for a property.
    ///
    /// In quirks mode, certain properties accept bare numbers as pixel values.
    /// For example, `width: 100` is treated as `width: 100px`.
    ///
    /// ## Parameters
    /// - `property`: CSS property name (case-insensitive)
    ///
    /// ## Returns
    /// `true` if:
    /// 1. Current mode is quirks mode, AND
    /// 2. The property is in the unitless length allowlist
    ///
    /// ## Note
    /// The value `0` is always unitless in CSS (even in standards mode).
    /// This method only affects non-zero values.
    ///
    /// ## Example
    /// ```zig
    /// const ctx = QuirksModeContext.init(.quirks);
    /// try std.testing.expect(ctx.allowsUnitlessLength("width"));
    /// try std.testing.expect(!ctx.allowsUnitlessLength("color"));
    /// ```
    pub fn allowsUnitlessLength(self: QuirksModeContext, property: []const u8) bool {
        if (!self.mode.hasCssValueQuirks()) {
            return false;
        }
        return constants.isUnitlessLengthProperty(property);
    }

    // ========================================================================
    // Selector Quirks
    // ========================================================================

    /// Check if the :active/:hover selector quirk applies.
    ///
    /// In quirks mode, compound selectors using :active or :hover must not
    /// match elements unless they also match :any-link, if the selector has
    /// no type/attribute/ID/class/pseudo-class/pseudo-element selectors.
    ///
    /// ## Returns
    /// `true` if in quirks mode (selector quirks apply).
    pub fn hasSelectorQuirks(self: QuirksModeContext) bool {
        return self.mode.hasSelectorQuirks();
    }

    // ========================================================================
    // Layout Quirks
    // ========================================================================

    /// Check if line height quirks apply.
    ///
    /// In quirks mode and limited quirks mode:
    /// - Empty inline boxes with zero padding/border act as zero height
    /// - Blocks don't add a "strut" to line boxes
    ///
    /// ## Returns
    /// `true` if in quirks mode OR limited quirks mode.
    pub fn hasLineHeightQuirks(self: QuirksModeContext) bool {
        return self.mode.hasLineHeightQuirks();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "QuirksModeContext - factory methods" {
    const no_quirks = QuirksModeContext.noQuirks();
    try std.testing.expect(no_quirks.isNoQuirksMode());

    const quirks_ctx = QuirksModeContext.quirks();
    try std.testing.expect(quirks_ctx.isQuirksMode());

    const limited = QuirksModeContext.limitedQuirks();
    try std.testing.expect(limited.isLimitedQuirksMode());
}

test "QuirksModeContext - getMode" {
    const ctx = QuirksModeContext.init(.quirks);
    try std.testing.expectEqual(QuirksMode.quirks, ctx.getMode());
}

test "QuirksModeContext - allowsHashlessHexColor in quirks mode" {
    const ctx = QuirksModeContext.quirks();

    // Allowed properties
    try std.testing.expect(ctx.allowsHashlessHexColor("color"));
    try std.testing.expect(ctx.allowsHashlessHexColor("COLOR"));
    try std.testing.expect(ctx.allowsHashlessHexColor("background-color"));
    try std.testing.expect(ctx.allowsHashlessHexColor("border-color"));

    // Not allowed properties
    try std.testing.expect(!ctx.allowsHashlessHexColor("background"));
    try std.testing.expect(!ctx.allowsHashlessHexColor("width"));
}

test "QuirksModeContext - allowsHashlessHexColor in no-quirks mode" {
    const ctx = QuirksModeContext.noQuirks();

    // Even allowed properties return false in no-quirks mode
    try std.testing.expect(!ctx.allowsHashlessHexColor("color"));
    try std.testing.expect(!ctx.allowsHashlessHexColor("background-color"));
}

test "QuirksModeContext - allowsHashlessHexColor in limited-quirks mode" {
    const ctx = QuirksModeContext.limitedQuirks();

    // CSS value quirks don't apply in limited quirks mode
    try std.testing.expect(!ctx.allowsHashlessHexColor("color"));
    try std.testing.expect(!ctx.allowsHashlessHexColor("background-color"));
}

test "QuirksModeContext - allowsUnitlessLength in quirks mode" {
    const ctx = QuirksModeContext.quirks();

    // Allowed properties
    try std.testing.expect(ctx.allowsUnitlessLength("width"));
    try std.testing.expect(ctx.allowsUnitlessLength("HEIGHT"));
    try std.testing.expect(ctx.allowsUnitlessLength("margin-top"));
    try std.testing.expect(ctx.allowsUnitlessLength("font-size"));

    // Not allowed properties
    try std.testing.expect(!ctx.allowsUnitlessLength("color"));
    try std.testing.expect(!ctx.allowsUnitlessLength("display"));
}

test "QuirksModeContext - allowsUnitlessLength in no-quirks mode" {
    const ctx = QuirksModeContext.noQuirks();

    // Even allowed properties return false in no-quirks mode
    try std.testing.expect(!ctx.allowsUnitlessLength("width"));
    try std.testing.expect(!ctx.allowsUnitlessLength("margin"));
}

test "QuirksModeContext - selector quirks" {
    const quirks_ctx = QuirksModeContext.quirks();
    const no_quirks = QuirksModeContext.noQuirks();
    const limited = QuirksModeContext.limitedQuirks();

    try std.testing.expect(quirks_ctx.hasSelectorQuirks());
    try std.testing.expect(!no_quirks.hasSelectorQuirks());
    try std.testing.expect(!limited.hasSelectorQuirks());
}

test "QuirksModeContext - line height quirks" {
    const quirks_ctx = QuirksModeContext.quirks();
    const no_quirks = QuirksModeContext.noQuirks();
    const limited = QuirksModeContext.limitedQuirks();

    // Line height quirks apply in both quirks and limited-quirks mode
    try std.testing.expect(quirks_ctx.hasLineHeightQuirks());
    try std.testing.expect(!no_quirks.hasLineHeightQuirks());
    try std.testing.expect(limited.hasLineHeightQuirks());
}
