//! CSS Parser Context
//!
//! Provides context for CSS property value parsing, including quirks mode
//! support for hashless hex colors and unitless lengths.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//!
//! ## Usage
//!
//! ```zig
//! const css = @import("css");
//! const quirks = @import("quirks");
//!
//! // Create context for quirks mode document
//! const ctx = css.ParserContext.init(allocator, .quirks);
//! defer ctx.deinit();
//!
//! // Check if quirks apply for a specific property
//! if (ctx.allowsHashlessHexColor("color")) {
//!     // Parse "ffffff" as "#ffffff"
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const quirks = @import("quirks");
const QuirksMode = quirks.QuirksMode;
const QuirksModeContext = quirks.QuirksModeContext;

/// Context for CSS property value parsing.
///
/// Maintains the quirks mode state and provides methods to check
/// whether specific quirks should be applied during parsing.
pub const ParserContext = struct {
    allocator: Allocator,

    /// Quirks mode context from the document.
    quirks_ctx: QuirksModeContext,

    const Self = @This();

    /// Create a new parser context.
    ///
    /// ## Parameters
    /// - `allocator`: Memory allocator for parsing operations
    /// - `mode`: Document's quirks mode
    pub fn init(allocator: Allocator, mode: QuirksMode) Self {
        return .{
            .allocator = allocator,
            .quirks_ctx = QuirksModeContext.init(mode),
        };
    }

    /// Create a parser context from an existing quirks mode context.
    pub fn initFromQuirksContext(allocator: Allocator, quirks_ctx: QuirksModeContext) Self {
        return .{
            .allocator = allocator,
            .quirks_ctx = quirks_ctx,
        };
    }

    /// Create a parser context for standards mode (no quirks).
    pub fn noQuirks(allocator: Allocator) Self {
        return init(allocator, .no_quirks);
    }

    /// Clean up parser context.
    pub fn deinit(self: *Self) void {
        _ = self;
        // No cleanup needed currently, but method provided for future use
    }

    // ========================================================================
    // Quirks Mode Queries
    // ========================================================================

    /// Get the current quirks mode.
    pub fn getQuirksMode(self: *const Self) QuirksMode {
        return self.quirks_ctx.getMode();
    }

    /// Check if in quirks mode.
    pub fn isQuirksMode(self: *const Self) bool {
        return self.quirks_ctx.isQuirksMode();
    }

    /// Check if hashless hex color is allowed for a property.
    ///
    /// In quirks mode, certain properties accept hex colors without the `#` prefix.
    /// For example, `color: ffffff` is treated as `color: #ffffff`.
    ///
    /// ## Parameters
    /// - `property`: CSS property name (case-insensitive)
    ///
    /// ## Returns
    /// `true` if hashless hex color is allowed for this property in current mode.
    pub fn allowsHashlessHexColor(self: *const Self, property: []const u8) bool {
        return self.quirks_ctx.allowsHashlessHexColor(property);
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
    /// `true` if unitless length is allowed for this property in current mode.
    ///
    /// ## Note
    /// The value `0` is always unitless in CSS (even in standards mode).
    pub fn allowsUnitlessLength(self: *const Self, property: []const u8) bool {
        return self.quirks_ctx.allowsUnitlessLength(property);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ParserContext - init" {
    const allocator = std.testing.allocator;

    var ctx = ParserContext.init(allocator, .quirks);
    defer ctx.deinit();

    try std.testing.expect(ctx.isQuirksMode());
    try std.testing.expectEqual(QuirksMode.quirks, ctx.getQuirksMode());
}

test "ParserContext - noQuirks" {
    const allocator = std.testing.allocator;

    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    try std.testing.expect(!ctx.isQuirksMode());
    try std.testing.expectEqual(QuirksMode.no_quirks, ctx.getQuirksMode());
}

test "ParserContext - allowsHashlessHexColor" {
    const allocator = std.testing.allocator;

    // Quirks mode
    var ctx_quirks = ParserContext.init(allocator, .quirks);
    defer ctx_quirks.deinit();

    try std.testing.expect(ctx_quirks.allowsHashlessHexColor("color"));
    try std.testing.expect(ctx_quirks.allowsHashlessHexColor("background-color"));
    try std.testing.expect(!ctx_quirks.allowsHashlessHexColor("background"));

    // No-quirks mode
    var ctx_no_quirks = ParserContext.noQuirks(allocator);
    defer ctx_no_quirks.deinit();

    try std.testing.expect(!ctx_no_quirks.allowsHashlessHexColor("color"));
}

test "ParserContext - allowsUnitlessLength" {
    const allocator = std.testing.allocator;

    // Quirks mode
    var ctx_quirks = ParserContext.init(allocator, .quirks);
    defer ctx_quirks.deinit();

    try std.testing.expect(ctx_quirks.allowsUnitlessLength("width"));
    try std.testing.expect(ctx_quirks.allowsUnitlessLength("margin-top"));
    try std.testing.expect(!ctx_quirks.allowsUnitlessLength("color"));

    // No-quirks mode
    var ctx_no_quirks = ParserContext.noQuirks(allocator);
    defer ctx_no_quirks.deinit();

    try std.testing.expect(!ctx_no_quirks.allowsUnitlessLength("width"));
}
