//! CSS Length Value Parser
//!
//! Implements CSS Values and Units Level 4 length parsing with quirks mode
//! support for unitless lengths.
//!
//! ## W3C Specifications
//!
//! - CSS Values and Units Level 4: https://drafts.csswg.org/css-values-4/
//! - CSS Values Level 4 §C (Quirky Lengths): https://drafts.csswg.org/css-values-4/#deprecated-quirky-length
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode §3.2: https://quirks.spec.whatwg.org/#the-unitless-length-quirk
//!
//! ## Supported Units
//!
//! - Absolute: px, cm, mm, in, pt, pc, Q
//! - Font-relative: em, rem, ex, ch, lh, rlh
//! - Viewport: vw, vh, vmin, vmax, vi, vb
//! - Percentage: %
//! - Unitless (quirks mode only): bare numbers treated as px

const std = @import("std");
const tokenizer = @import("../tokenizer.zig");
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;
const Tokenizer = tokenizer.Tokenizer;
const context = @import("../context.zig");
const ParserContext = context.ParserContext;

/// CSS length unit types.
pub const LengthUnit = enum {
    // Absolute lengths
    px, // Pixels
    cm, // Centimeters
    mm, // Millimeters
    in, // Inches
    pt, // Points
    pc, // Picas
    Q, // Quarter-millimeters

    // Font-relative lengths
    em, // Relative to font-size
    rem, // Relative to root font-size
    ex, // x-height
    ch, // Width of "0"
    lh, // Line-height
    rlh, // Root line-height

    // Viewport-relative lengths
    vw, // Viewport width
    vh, // Viewport height
    vmin, // Smaller of vw/vh
    vmax, // Larger of vw/vh
    vi, // Viewport inline size
    vb, // Viewport block size

    // Percentages (special case)
    percent,

    /// Convert unit name to enum (case-insensitive).
    pub fn fromString(s: []const u8) ?LengthUnit {
        if (s.len == 0) return null;

        // Check percentage first
        if (s.len == 1 and s[0] == '%') return .percent;

        // Unit lookup
        const units = [_]struct { name: []const u8, unit: LengthUnit }{
            .{ .name = "px", .unit = .px },
            .{ .name = "cm", .unit = .cm },
            .{ .name = "mm", .unit = .mm },
            .{ .name = "in", .unit = .in },
            .{ .name = "pt", .unit = .pt },
            .{ .name = "pc", .unit = .pc },
            .{ .name = "q", .unit = .Q },
            .{ .name = "em", .unit = .em },
            .{ .name = "rem", .unit = .rem },
            .{ .name = "ex", .unit = .ex },
            .{ .name = "ch", .unit = .ch },
            .{ .name = "lh", .unit = .lh },
            .{ .name = "rlh", .unit = .rlh },
            .{ .name = "vw", .unit = .vw },
            .{ .name = "vh", .unit = .vh },
            .{ .name = "vmin", .unit = .vmin },
            .{ .name = "vmax", .unit = .vmax },
            .{ .name = "vi", .unit = .vi },
            .{ .name = "vb", .unit = .vb },
        };

        for (units) |entry| {
            if (std.ascii.eqlIgnoreCase(s, entry.name)) {
                return entry.unit;
            }
        }

        return null;
    }

    /// Get unit name.
    pub fn toString(self: LengthUnit) []const u8 {
        return switch (self) {
            .px => "px",
            .cm => "cm",
            .mm => "mm",
            .in => "in",
            .pt => "pt",
            .pc => "pc",
            .Q => "Q",
            .em => "em",
            .rem => "rem",
            .ex => "ex",
            .ch => "ch",
            .lh => "lh",
            .rlh => "rlh",
            .vw => "vw",
            .vh => "vh",
            .vmin => "vmin",
            .vmax => "vmax",
            .vi => "vi",
            .vb => "vb",
            .percent => "%",
        };
    }
};

/// CSS length value.
pub const Length = struct {
    /// Numeric value.
    value: f64,

    /// Unit type.
    unit: LengthUnit,

    /// Create a length.
    pub fn init(value: f64, unit: LengthUnit) Length {
        return .{ .value = value, .unit = unit };
    }

    /// Create a pixel length.
    pub fn px(value: f64) Length {
        return init(value, .px);
    }

    /// Create an em length.
    pub fn em(value: f64) Length {
        return init(value, .em);
    }

    /// Create a percentage.
    pub fn percent(value: f64) Length {
        return init(value, .percent);
    }

    /// Zero length (always unitless in CSS).
    pub const zero = Length{ .value = 0, .unit = .px };

    /// Check if this is zero.
    pub fn isZero(self: Length) bool {
        return self.value == 0;
    }

    /// Check if two lengths are equal.
    pub fn eql(self: Length, other: Length) bool {
        return self.value == other.value and self.unit == other.unit;
    }

    /// Convert to pixels (for absolute units only).
    ///
    /// Note: Font-relative and viewport-relative units require context
    /// (font-size, viewport size) and cannot be converted here.
    pub fn toPixels(self: Length) ?f64 {
        return switch (self.unit) {
            .px => self.value,
            .cm => self.value * 37.7953, // 1cm = 37.7953px
            .mm => self.value * 3.77953, // 1mm = 3.77953px
            .in => self.value * 96.0, // 1in = 96px
            .pt => self.value * (96.0 / 72.0), // 1pt = 96/72px
            .pc => self.value * 16.0, // 1pc = 16px
            .Q => self.value * 0.944882, // 1Q = 0.944882px
            else => null, // Relative units need context
        };
    }
};

/// Length parsing errors.
pub const LengthParseError = error{
    /// Invalid length format.
    InvalidLength,

    /// Unexpected token.
    UnexpectedToken,

    /// Unknown unit.
    UnknownUnit,

    /// Unitless length not allowed (in standards mode).
    UnitlessNotAllowed,
};

/// CSS length value parser.
pub const LengthParser = struct {
    /// Parse a length value from tokens.
    ///
    /// ## Parameters
    /// - `tok`: Tokenizer positioned at the start of the length value
    /// - `property`: CSS property name (for quirks mode check)
    /// - `ctx`: Parser context with quirks mode state
    ///
    /// ## Returns
    /// Parsed length value.
    ///
    /// ## Errors
    /// Returns an error if the value is not a valid length.
    pub fn parse(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) LengthParseError!Length {
        tok.skipWhitespace();
        const token = tok.next();

        switch (token.token_type) {
            // 10px, 1.5em
            .dimension => {
                const value = token.numeric_value orelse return LengthParseError.InvalidLength;
                const unit_str = token.unit orelse return LengthParseError.UnknownUnit;
                const unit = LengthUnit.fromString(unit_str) orelse return LengthParseError.UnknownUnit;
                return Length.init(value, unit);
            },

            // 50%
            .percentage => {
                const value = token.numeric_value orelse return LengthParseError.InvalidLength;
                return Length.percent(value);
            },

            // Bare number (unitless)
            .number => {
                const value = token.numeric_value orelse return LengthParseError.InvalidLength;

                // Zero is always allowed unitless
                if (value == 0) {
                    return Length.zero;
                }

                // In quirks mode, allow unitless for certain properties
                if (ctx.allowsUnitlessLength(property)) {
                    return Length.px(value);
                }

                return LengthParseError.UnitlessNotAllowed;
            },

            // Special keywords
            .ident => {
                // Check for 'auto' which is common but not a length
                // Return error - the caller should handle 'auto' separately
                return LengthParseError.InvalidLength;
            },

            else => return LengthParseError.UnexpectedToken,
        }
    }

    /// Parse a length that allows 'auto'.
    pub fn parseWithAuto(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) LengthParseError!?Length {
        tok.skipWhitespace();
        const token = tok.peek();

        if (token.token_type == .ident and std.ascii.eqlIgnoreCase(token.value, "auto")) {
            _ = tok.next();
            return null; // null represents 'auto'
        }

        const result = try parse(tok, property, ctx);
        return result;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LengthUnit - fromString" {
    try std.testing.expectEqual(LengthUnit.px, LengthUnit.fromString("px").?);
    try std.testing.expectEqual(LengthUnit.px, LengthUnit.fromString("PX").?);
    try std.testing.expectEqual(LengthUnit.em, LengthUnit.fromString("em").?);
    try std.testing.expectEqual(LengthUnit.rem, LengthUnit.fromString("rem").?);
    try std.testing.expectEqual(LengthUnit.vw, LengthUnit.fromString("vw").?);
    try std.testing.expect(LengthUnit.fromString("unknown") == null);
}

test "Length - toPixels" {
    try std.testing.expectEqual(@as(f64, 10), Length.px(10).toPixels().?);
    try std.testing.expectApproxEqAbs(@as(f64, 96), Length.init(1, .in).toPixels().?, 0.01);
    try std.testing.expect(Length.em(1).toPixels() == null); // Relative unit
}

test "LengthParser - dimensions" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // 10px
    {
        var tok = Tokenizer.init("10px");
        const len = try LengthParser.parse(&tok, "width", &ctx);
        try std.testing.expectEqual(@as(f64, 10), len.value);
        try std.testing.expectEqual(LengthUnit.px, len.unit);
    }

    // 1.5em
    {
        var tok = Tokenizer.init("1.5em");
        const len = try LengthParser.parse(&tok, "width", &ctx);
        try std.testing.expectApproxEqAbs(@as(f64, 1.5), len.value, 0.001);
        try std.testing.expectEqual(LengthUnit.em, len.unit);
    }
}

test "LengthParser - percentage" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    var tok = Tokenizer.init("50%");
    const len = try LengthParser.parse(&tok, "width", &ctx);
    try std.testing.expectEqual(@as(f64, 50), len.value);
    try std.testing.expectEqual(LengthUnit.percent, len.unit);
}

test "LengthParser - zero is always unitless" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    var tok = Tokenizer.init("0");
    const len = try LengthParser.parse(&tok, "width", &ctx);
    try std.testing.expectEqual(@as(f64, 0), len.value);
}

test "LengthParser - unitless in quirks mode" {
    const allocator = std.testing.allocator;

    // Quirks mode - should accept unitless for width
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("100");
        const len = try LengthParser.parse(&tok, "width", &ctx);
        try std.testing.expectEqual(@as(f64, 100), len.value);
        try std.testing.expectEqual(LengthUnit.px, len.unit);
    }

    // Quirks mode - should accept unitless for margin
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("20");
        const len = try LengthParser.parse(&tok, "margin-top", &ctx);
        try std.testing.expectEqual(@as(f64, 20), len.value);
        try std.testing.expectEqual(LengthUnit.px, len.unit);
    }

    // Quirks mode - should NOT accept unitless for disallowed properties
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("100");
        const result = LengthParser.parse(&tok, "color", &ctx);
        try std.testing.expectError(LengthParseError.UnitlessNotAllowed, result);
    }

    // No-quirks mode - should NOT accept unitless (non-zero)
    {
        var ctx = ParserContext.noQuirks(allocator);
        defer ctx.deinit();

        var tok = Tokenizer.init("100");
        const result = LengthParser.parse(&tok, "width", &ctx);
        try std.testing.expectError(LengthParseError.UnitlessNotAllowed, result);
    }
}

test "LengthParser - parseWithAuto" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // auto
    {
        var tok = Tokenizer.init("auto");
        const result = try LengthParser.parseWithAuto(&tok, "width", &ctx);
        try std.testing.expect(result == null);
    }

    // Regular length
    {
        var tok = Tokenizer.init("100px");
        const result = try LengthParser.parseWithAuto(&tok, "width", &ctx);
        try std.testing.expectEqual(@as(f64, 100), result.?.value);
    }
}
