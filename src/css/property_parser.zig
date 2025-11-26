//! CSS Property Parser Framework
//!
//! Provides property-level parsing that routes to the appropriate value parser
//! based on the CSS property name. Integrates with quirks mode for legacy
//! compatibility.
//!
//! ## W3C Specifications
//!
//! - CSS Cascading and Inheritance Level 4: https://drafts.csswg.org/css-cascade-4/
//! - CSS Values and Units Level 4: https://drafts.csswg.org/css-values-4/
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//!
//! ## Design
//!
//! The property parser:
//! 1. Identifies the property type (color, length, etc.)
//! 2. Routes to the appropriate value parser
//! 3. Returns a tagged union of possible value types
//!
//! ## Usage
//!
//! ```zig
//! const css = @import("css");
//!
//! var ctx = css.ParserContext.init(allocator, .quirks);
//! defer ctx.deinit();
//!
//! var tok = css.Tokenizer.init("red");
//! const result = try css.PropertyParser.parse(&tok, "color", &ctx);
//!
//! switch (result) {
//!     .color => |c| // Handle color value,
//!     .length => |l| // Handle length value,
//!     // ...
//! }
//! ```

const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Tokenizer = tokenizer.Tokenizer;
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;
const context = @import("context.zig");
const ParserContext = context.ParserContext;
const color_parser = @import("values/color.zig");
const Color = color_parser.Color;
const ColorParser = color_parser.ColorParser;
const ColorParseError = color_parser.ColorParseError;
const length_parser = @import("values/length.zig");
const Length = length_parser.Length;
const LengthParser = length_parser.LengthParser;
const LengthParseError = length_parser.LengthParseError;
const quirks = @import("quirks");

/// Parsed CSS property value.
///
/// A tagged union representing the different types of values
/// a CSS property can have.
pub const PropertyValue = union(enum) {
    /// Color value (e.g., #fff, rgb(255,0,0), red)
    color: Color,

    /// Length value (e.g., 10px, 1.5em, 50%)
    length: Length,

    /// Length that can also be 'auto'
    length_or_auto: ?Length,

    /// Keyword value (inherit, initial, unset, revert)
    keyword: Keyword,

    /// Raw identifier (for properties we don't fully parse)
    ident: []const u8,

    /// Check if this is a global keyword.
    pub fn isGlobalKeyword(self: PropertyValue) bool {
        return self == .keyword;
    }
};

/// CSS-wide keywords (global values).
pub const Keyword = enum {
    inherit,
    initial,
    unset,
    revert,
    revert_layer,

    /// Parse a keyword from a string.
    pub fn fromString(s: []const u8) ?Keyword {
        if (std.ascii.eqlIgnoreCase(s, "inherit")) return .inherit;
        if (std.ascii.eqlIgnoreCase(s, "initial")) return .initial;
        if (std.ascii.eqlIgnoreCase(s, "unset")) return .unset;
        if (std.ascii.eqlIgnoreCase(s, "revert")) return .revert;
        if (std.ascii.eqlIgnoreCase(s, "revert-layer")) return .revert_layer;
        return null;
    }
};

/// Property parsing errors.
pub const PropertyParseError = error{
    /// Unknown property name.
    UnknownProperty,

    /// Invalid value for this property.
    InvalidValue,

    /// Unexpected token.
    UnexpectedToken,

    /// Property doesn't accept this value type.
    TypeMismatch,
};

/// Property type classification.
pub const PropertyType = enum {
    /// Property accepts color values.
    color,

    /// Property accepts length values.
    length,

    /// Property accepts length or 'auto'.
    length_or_auto,

    /// Property accepts multiple value types (needs special handling).
    mixed,

    /// Unknown property type.
    unknown,
};

/// CSS property parser.
pub const PropertyParser = struct {
    /// Parse a property value.
    ///
    /// ## Parameters
    /// - `tok`: Tokenizer positioned at the start of the value
    /// - `property`: CSS property name
    /// - `ctx`: Parser context with quirks mode
    ///
    /// ## Returns
    /// Parsed property value.
    pub fn parse(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) PropertyParseError!PropertyValue {
        // First, check for CSS-wide keywords
        tok.skipWhitespace();
        const peeked = tok.peek();
        if (peeked.token_type == .ident) {
            if (Keyword.fromString(peeked.value)) |kw| {
                _ = tok.next(); // Consume the keyword
                return PropertyValue{ .keyword = kw };
            }
        }

        // Route to appropriate parser based on property type
        const prop_type = getPropertyType(property);

        return switch (prop_type) {
            .color => parseColor(tok, property, ctx),
            .length => parseLength(tok, property, ctx),
            .length_or_auto => parseLengthOrAuto(tok, property, ctx),
            .mixed => parseMixed(tok, property, ctx),
            .unknown => parseUnknown(tok),
        };
    }

    /// Get the type classification for a property.
    pub fn getPropertyType(property: []const u8) PropertyType {
        // Color properties
        if (quirks.isColorProperty(property)) {
            return .color;
        }

        // Length-or-auto properties
        if (isLengthOrAutoProperty(property)) {
            return .length_or_auto;
        }

        // Length properties
        if (quirks.isLengthProperty(property)) {
            return .length;
        }

        return .unknown;
    }

    fn parseColor(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) PropertyParseError!PropertyValue {
        const result = ColorParser.parse(tok, property, ctx) catch |err| {
            return switch (err) {
                ColorParseError.InvalidColor => PropertyParseError.InvalidValue,
                ColorParseError.UnexpectedToken => PropertyParseError.UnexpectedToken,
                ColorParseError.MissingCloseParen => PropertyParseError.InvalidValue,
                ColorParseError.InvalidComponent => PropertyParseError.InvalidValue,
            };
        };
        return PropertyValue{ .color = result };
    }

    fn parseLength(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) PropertyParseError!PropertyValue {
        const result = LengthParser.parse(tok, property, ctx) catch |err| {
            return switch (err) {
                LengthParseError.InvalidLength => PropertyParseError.InvalidValue,
                LengthParseError.UnexpectedToken => PropertyParseError.UnexpectedToken,
                LengthParseError.UnknownUnit => PropertyParseError.InvalidValue,
                LengthParseError.UnitlessNotAllowed => PropertyParseError.InvalidValue,
            };
        };
        return PropertyValue{ .length = result };
    }

    fn parseLengthOrAuto(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) PropertyParseError!PropertyValue {
        const result = LengthParser.parseWithAuto(tok, property, ctx) catch |err| {
            return switch (err) {
                LengthParseError.InvalidLength => PropertyParseError.InvalidValue,
                LengthParseError.UnexpectedToken => PropertyParseError.UnexpectedToken,
                LengthParseError.UnknownUnit => PropertyParseError.InvalidValue,
                LengthParseError.UnitlessNotAllowed => PropertyParseError.InvalidValue,
            };
        };
        return PropertyValue{ .length_or_auto = result };
    }

    fn parseMixed(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) PropertyParseError!PropertyValue {
        // For mixed properties, try each parser in order
        // Save position to restore on failure
        const saved_pos = tok.pos;
        const saved_line = tok.line;
        const saved_column = tok.column;

        // Try color first (for properties like 'background')
        if (quirks.isColorProperty(property)) {
            if (ColorParser.parse(tok, property, ctx)) |color_result| {
                return PropertyValue{ .color = color_result };
            } else |_| {
                // Restore position and try next parser
                tok.pos = saved_pos;
                tok.line = saved_line;
                tok.column = saved_column;
            }
        }

        // Try length
        if (quirks.isLengthProperty(property)) {
            if (LengthParser.parse(tok, property, ctx)) |length_result| {
                return PropertyValue{ .length = length_result };
            } else |_| {
                tok.pos = saved_pos;
                tok.line = saved_line;
                tok.column = saved_column;
            }
        }

        // Fall back to ident
        return parseUnknown(tok);
    }

    fn parseUnknown(tok: *Tokenizer) PropertyParseError!PropertyValue {
        tok.skipWhitespace();
        const token = tok.next();

        if (token.token_type == .ident) {
            return PropertyValue{ .ident = token.value };
        }

        return PropertyParseError.UnexpectedToken;
    }
};

/// Check if a property accepts 'auto' in addition to lengths.
fn isLengthOrAutoProperty(property: []const u8) bool {
    const auto_properties = [_][]const u8{
        "width",
        "height",
        "min-width",
        "min-height",
        "max-width",
        "max-height",
        "margin",
        "margin-top",
        "margin-right",
        "margin-bottom",
        "margin-left",
        "top",
        "right",
        "bottom",
        "left",
    };

    for (auto_properties) |prop| {
        if (std.ascii.eqlIgnoreCase(property, prop)) {
            return true;
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "PropertyParser - color property" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // Named color
    {
        var tok = Tokenizer.init("red");
        const result = try PropertyParser.parse(&tok, "color", &ctx);
        try std.testing.expect(result == .color);
        try std.testing.expectEqual(@as(u8, 255), result.color.r);
    }

    // Hex color
    {
        var tok = Tokenizer.init("#00ff00");
        const result = try PropertyParser.parse(&tok, "background-color", &ctx);
        try std.testing.expect(result == .color);
        try std.testing.expectEqual(@as(u8, 0), result.color.r);
        try std.testing.expectEqual(@as(u8, 255), result.color.g);
    }
}

test "PropertyParser - length property" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // Dimension
    {
        var tok = Tokenizer.init("10px");
        const result = try PropertyParser.parse(&tok, "padding-top", &ctx);
        try std.testing.expect(result == .length);
        try std.testing.expectEqual(@as(f64, 10), result.length.value);
    }

    // Percentage
    {
        var tok = Tokenizer.init("50%");
        const result = try PropertyParser.parse(&tok, "font-size", &ctx);
        try std.testing.expect(result == .length);
        try std.testing.expectEqual(@as(f64, 50), result.length.value);
    }
}

test "PropertyParser - length-or-auto property" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // auto
    {
        var tok = Tokenizer.init("auto");
        const result = try PropertyParser.parse(&tok, "width", &ctx);
        try std.testing.expect(result == .length_or_auto);
        try std.testing.expect(result.length_or_auto == null);
    }

    // Length value
    {
        var tok = Tokenizer.init("100px");
        const result = try PropertyParser.parse(&tok, "height", &ctx);
        try std.testing.expect(result == .length_or_auto);
        try std.testing.expectEqual(@as(f64, 100), result.length_or_auto.?.value);
    }
}

test "PropertyParser - global keywords" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    const keywords = [_][]const u8{ "inherit", "initial", "unset", "revert" };

    for (keywords) |kw| {
        var tok = Tokenizer.init(kw);
        const result = try PropertyParser.parse(&tok, "color", &ctx);
        try std.testing.expect(result == .keyword);
    }
}

test "PropertyParser - quirks mode hashless hex" {
    const allocator = std.testing.allocator;

    // Quirks mode
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("ff0000");
        const result = try PropertyParser.parse(&tok, "color", &ctx);
        try std.testing.expect(result == .color);
        try std.testing.expectEqual(@as(u8, 255), result.color.r);
    }

    // No-quirks mode - should fail
    {
        var ctx = ParserContext.noQuirks(allocator);
        defer ctx.deinit();

        var tok = Tokenizer.init("ff0000");
        const result = PropertyParser.parse(&tok, "color", &ctx);
        try std.testing.expectError(PropertyParseError.InvalidValue, result);
    }
}

test "PropertyParser - quirks mode unitless length" {
    const allocator = std.testing.allocator;

    // Quirks mode
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("100");
        const result = try PropertyParser.parse(&tok, "width", &ctx);
        try std.testing.expect(result == .length_or_auto);
        try std.testing.expectEqual(@as(f64, 100), result.length_or_auto.?.value);
    }

    // No-quirks mode - should fail
    {
        var ctx = ParserContext.noQuirks(allocator);
        defer ctx.deinit();

        var tok = Tokenizer.init("100");
        const result = PropertyParser.parse(&tok, "width", &ctx);
        try std.testing.expectError(PropertyParseError.InvalidValue, result);
    }
}

test "PropertyParser.getPropertyType" {
    try std.testing.expectEqual(PropertyType.color, PropertyParser.getPropertyType("color"));
    try std.testing.expectEqual(PropertyType.color, PropertyParser.getPropertyType("background-color"));
    try std.testing.expectEqual(PropertyType.length_or_auto, PropertyParser.getPropertyType("width"));
    try std.testing.expectEqual(PropertyType.length_or_auto, PropertyParser.getPropertyType("margin-top"));
    try std.testing.expectEqual(PropertyType.length, PropertyParser.getPropertyType("padding-top"));
    try std.testing.expectEqual(PropertyType.length, PropertyParser.getPropertyType("font-size"));
    try std.testing.expectEqual(PropertyType.unknown, PropertyParser.getPropertyType("display"));
}
