//! CSS Color Value Parser
//!
//! Implements CSS Color Level 4 color parsing with quirks mode support
//! for hashless hex colors.
//!
//! ## W3C Specifications
//!
//! - CSS Color Level 4: https://drafts.csswg.org/css-color-4/
//! - CSS Color Level 4 §B (Quirky Colors): https://drafts.csswg.org/css-color-4/#quirky-color
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode §3.1: https://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk
//!
//! ## Supported Formats
//!
//! - Hex colors: #fff, #ffffff, #ffff, #ffffffff
//! - RGB functions: rgb(255, 0, 0), rgba(255, 0, 0, 0.5)
//! - Named colors: red, blue, transparent, etc.
//! - Hashless hex (quirks mode only): ffffff, fff

const std = @import("std");
const tokenizer = @import("../tokenizer.zig");
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;
const Tokenizer = tokenizer.Tokenizer;
const isHexColor = tokenizer.isHexColor;
const context = @import("../context.zig");
const ParserContext = context.ParserContext;

/// RGBA color value.
pub const Color = struct {
    /// Red component (0-255).
    r: u8,

    /// Green component (0-255).
    g: u8,

    /// Blue component (0-255).
    b: u8,

    /// Alpha component (0.0-1.0).
    a: f32 = 1.0,

    /// Create an opaque color.
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    /// Create a color with alpha.
    pub fn rgba(r: u8, g: u8, b: u8, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Predefined colors.
    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0.0 };
    pub const black = Color.rgb(0, 0, 0);
    pub const white = Color.rgb(255, 255, 255);
    pub const red = Color.rgb(255, 0, 0);
    pub const green = Color.rgb(0, 128, 0);
    pub const blue = Color.rgb(0, 0, 255);

    /// Check if two colors are equal.
    pub fn eql(self: Color, other: Color) bool {
        return self.r == other.r and self.g == other.g and
            self.b == other.b and @abs(self.a - other.a) < 0.001;
    }
};

/// Color parsing errors.
pub const ColorParseError = error{
    /// Invalid color format.
    InvalidColor,

    /// Unexpected token.
    UnexpectedToken,

    /// Missing closing parenthesis.
    MissingCloseParen,

    /// Invalid component value.
    InvalidComponent,
};

/// CSS color value parser.
pub const ColorParser = struct {
    /// Parse a color value from tokens.
    ///
    /// ## Parameters
    /// - `tok`: Tokenizer positioned at the start of the color value
    /// - `property`: CSS property name (for quirks mode check)
    /// - `ctx`: Parser context with quirks mode state
    ///
    /// ## Returns
    /// Parsed color value.
    ///
    /// ## Errors
    /// Returns an error if the value is not a valid color.
    pub fn parse(tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) ColorParseError!Color {
        tok.skipWhitespace();
        const token = tok.next();

        switch (token.token_type) {
            // #fff or #ffffff
            .hash => return parseHexColor(token.value),

            // rgb(...) or rgba(...)
            .function => {
                if (std.ascii.eqlIgnoreCase(token.value, "rgb") or
                    std.ascii.eqlIgnoreCase(token.value, "rgba"))
                {
                    return parseRgbFunction(tok);
                }
                return ColorParseError.InvalidColor;
            },

            // Named color or hashless hex in quirks mode
            .ident => {
                // Try named color first
                if (getNamedColor(token.value)) |color| {
                    return color;
                }

                // In quirks mode, try hashless hex for allowed properties
                if (ctx.allowsHashlessHexColor(property) and isHexColor(token.value)) {
                    return parseHexDigits(token.value);
                }

                return ColorParseError.InvalidColor;
            },

            else => return ColorParseError.UnexpectedToken,
        }
    }

    /// Parse a hash color (#fff or #ffffff).
    fn parseHexColor(value: []const u8) ColorParseError!Color {
        // Skip the '#' prefix
        if (value.len == 0 or value[0] != '#') {
            return ColorParseError.InvalidColor;
        }
        return parseHexDigits(value[1..]);
    }

    /// Parse hex digits (without # prefix).
    fn parseHexDigits(hex: []const u8) ColorParseError!Color {
        switch (hex.len) {
            // #rgb
            3 => {
                const r = parseHexPair(&[_]u8{ hex[0], hex[0] }) catch return ColorParseError.InvalidColor;
                const g = parseHexPair(&[_]u8{ hex[1], hex[1] }) catch return ColorParseError.InvalidColor;
                const b = parseHexPair(&[_]u8{ hex[2], hex[2] }) catch return ColorParseError.InvalidColor;
                return Color.rgb(r, g, b);
            },
            // #rgba
            4 => {
                const r = parseHexPair(&[_]u8{ hex[0], hex[0] }) catch return ColorParseError.InvalidColor;
                const g = parseHexPair(&[_]u8{ hex[1], hex[1] }) catch return ColorParseError.InvalidColor;
                const b = parseHexPair(&[_]u8{ hex[2], hex[2] }) catch return ColorParseError.InvalidColor;
                const a_int = parseHexPair(&[_]u8{ hex[3], hex[3] }) catch return ColorParseError.InvalidColor;
                return Color.rgba(r, g, b, @as(f32, @floatFromInt(a_int)) / 255.0);
            },
            // #rrggbb
            6 => {
                const r = parseHexPair(hex[0..2]) catch return ColorParseError.InvalidColor;
                const g = parseHexPair(hex[2..4]) catch return ColorParseError.InvalidColor;
                const b = parseHexPair(hex[4..6]) catch return ColorParseError.InvalidColor;
                return Color.rgb(r, g, b);
            },
            // #rrggbbaa
            8 => {
                const r = parseHexPair(hex[0..2]) catch return ColorParseError.InvalidColor;
                const g = parseHexPair(hex[2..4]) catch return ColorParseError.InvalidColor;
                const b = parseHexPair(hex[4..6]) catch return ColorParseError.InvalidColor;
                const a_int = parseHexPair(hex[6..8]) catch return ColorParseError.InvalidColor;
                return Color.rgba(r, g, b, @as(f32, @floatFromInt(a_int)) / 255.0);
            },
            else => return ColorParseError.InvalidColor,
        }
    }

    fn parseHexPair(hex: *const [2]u8) !u8 {
        return std.fmt.parseInt(u8, hex, 16);
    }

    /// Parse rgb() or rgba() function.
    fn parseRgbFunction(tok: *Tokenizer) ColorParseError!Color {
        // Expect '('
        tok.skipWhitespace();
        var token = tok.next();
        if (token.token_type != .left_paren) {
            return ColorParseError.UnexpectedToken;
        }

        // Parse R
        const r = try parseColorComponent(tok);

        // Expect ',' or whitespace
        tok.skipWhitespace();
        token = tok.peek();
        if (token.token_type == .comma) {
            _ = tok.next();
        }

        // Parse G
        const g = try parseColorComponent(tok);

        // Expect ',' or whitespace
        tok.skipWhitespace();
        token = tok.peek();
        if (token.token_type == .comma) {
            _ = tok.next();
        }

        // Parse B
        const b = try parseColorComponent(tok);

        // Optional alpha
        tok.skipWhitespace();
        token = tok.peek();
        var alpha: f32 = 1.0;

        if (token.token_type == .comma or token.token_type == .delim) {
            _ = tok.next(); // Skip comma or '/'
            alpha = try parseAlphaComponent(tok);
        }

        // Expect ')'
        tok.skipWhitespace();
        token = tok.next();
        if (token.token_type != .right_paren) {
            return ColorParseError.MissingCloseParen;
        }

        return Color.rgba(r, g, b, alpha);
    }

    fn parseColorComponent(tok: *Tokenizer) ColorParseError!u8 {
        tok.skipWhitespace();
        const token = tok.next();

        switch (token.token_type) {
            .number => {
                const value = token.numeric_value orelse return ColorParseError.InvalidComponent;
                return clampColorComponent(value);
            },
            .percentage => {
                const value = token.numeric_value orelse return ColorParseError.InvalidComponent;
                return clampColorComponent(value * 2.55);
            },
            else => return ColorParseError.InvalidComponent,
        }
    }

    fn parseAlphaComponent(tok: *Tokenizer) ColorParseError!f32 {
        tok.skipWhitespace();
        const token = tok.next();

        switch (token.token_type) {
            .number => {
                const value = token.numeric_value orelse return ColorParseError.InvalidComponent;
                return std.math.clamp(@as(f32, @floatCast(value)), 0.0, 1.0);
            },
            .percentage => {
                const value = token.numeric_value orelse return ColorParseError.InvalidComponent;
                return std.math.clamp(@as(f32, @floatCast(value / 100.0)), 0.0, 1.0);
            },
            else => return ColorParseError.InvalidComponent,
        }
    }

    fn clampColorComponent(value: f64) u8 {
        const clamped = std.math.clamp(@as(i32, @intFromFloat(@round(value))), 0, 255);
        return @intCast(clamped);
    }
};

/// Get a named color by name (case-insensitive).
fn getNamedColor(name: []const u8) ?Color {
    // Basic named colors (CSS Color Level 4)
    const named_colors = [_]struct { name: []const u8, color: Color }{
        .{ .name = "transparent", .color = Color.transparent },
        .{ .name = "black", .color = Color.rgb(0, 0, 0) },
        .{ .name = "white", .color = Color.rgb(255, 255, 255) },
        .{ .name = "red", .color = Color.rgb(255, 0, 0) },
        .{ .name = "green", .color = Color.rgb(0, 128, 0) },
        .{ .name = "blue", .color = Color.rgb(0, 0, 255) },
        .{ .name = "yellow", .color = Color.rgb(255, 255, 0) },
        .{ .name = "cyan", .color = Color.rgb(0, 255, 255) },
        .{ .name = "magenta", .color = Color.rgb(255, 0, 255) },
        .{ .name = "gray", .color = Color.rgb(128, 128, 128) },
        .{ .name = "grey", .color = Color.rgb(128, 128, 128) },
        .{ .name = "silver", .color = Color.rgb(192, 192, 192) },
        .{ .name = "maroon", .color = Color.rgb(128, 0, 0) },
        .{ .name = "olive", .color = Color.rgb(128, 128, 0) },
        .{ .name = "lime", .color = Color.rgb(0, 255, 0) },
        .{ .name = "aqua", .color = Color.rgb(0, 255, 255) },
        .{ .name = "teal", .color = Color.rgb(0, 128, 128) },
        .{ .name = "navy", .color = Color.rgb(0, 0, 128) },
        .{ .name = "fuchsia", .color = Color.rgb(255, 0, 255) },
        .{ .name = "purple", .color = Color.rgb(128, 0, 128) },
        .{ .name = "orange", .color = Color.rgb(255, 165, 0) },
        .{ .name = "pink", .color = Color.rgb(255, 192, 203) },
        .{ .name = "brown", .color = Color.rgb(165, 42, 42) },
    };

    for (named_colors) |entry| {
        if (std.ascii.eqlIgnoreCase(name, entry.name)) {
            return entry.color;
        }
    }

    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "ColorParser - hex colors" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    // #fff
    {
        var tok = Tokenizer.init("#fff");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectEqual(@as(u8, 255), color.r);
        try std.testing.expectEqual(@as(u8, 255), color.g);
        try std.testing.expectEqual(@as(u8, 255), color.b);
    }

    // #123456
    {
        var tok = Tokenizer.init("#123456");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectEqual(@as(u8, 0x12), color.r);
        try std.testing.expectEqual(@as(u8, 0x34), color.g);
        try std.testing.expectEqual(@as(u8, 0x56), color.b);
    }
}

test "ColorParser - named colors" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    {
        var tok = Tokenizer.init("red");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectEqual(@as(u8, 255), color.r);
        try std.testing.expectEqual(@as(u8, 0), color.g);
        try std.testing.expectEqual(@as(u8, 0), color.b);
    }

    {
        var tok = Tokenizer.init("transparent");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), color.a, 0.001);
    }
}

test "ColorParser - rgb function" {
    const allocator = std.testing.allocator;
    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();

    {
        var tok = Tokenizer.init("rgb(255, 128, 64)");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectEqual(@as(u8, 255), color.r);
        try std.testing.expectEqual(@as(u8, 128), color.g);
        try std.testing.expectEqual(@as(u8, 64), color.b);
    }
}

test "ColorParser - hashless hex in quirks mode" {
    const allocator = std.testing.allocator;

    // Quirks mode - should accept hashless hex for color property
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("ffffff");
        const color = try ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectEqual(@as(u8, 255), color.r);
        try std.testing.expectEqual(@as(u8, 255), color.g);
        try std.testing.expectEqual(@as(u8, 255), color.b);
    }

    // Quirks mode - should accept hashless hex for background-color
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("ff0000");
        const color = try ColorParser.parse(&tok, "background-color", &ctx);
        try std.testing.expectEqual(@as(u8, 255), color.r);
        try std.testing.expectEqual(@as(u8, 0), color.g);
        try std.testing.expectEqual(@as(u8, 0), color.b);
    }

    // Quirks mode - should NOT accept hashless hex for disallowed properties
    {
        var ctx = ParserContext.init(allocator, .quirks);
        defer ctx.deinit();

        var tok = Tokenizer.init("ffffff");
        const result = ColorParser.parse(&tok, "background", &ctx);
        try std.testing.expectError(ColorParseError.InvalidColor, result);
    }

    // No-quirks mode - should NOT accept hashless hex
    {
        var ctx = ParserContext.noQuirks(allocator);
        defer ctx.deinit();

        var tok = Tokenizer.init("ffffff");
        const result = ColorParser.parse(&tok, "color", &ctx);
        try std.testing.expectError(ColorParseError.InvalidColor, result);
    }
}
