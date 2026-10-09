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
//! - Legacy and modern rgb()/rgba(), hsl()/hsla(), hwb()
//! - Lab, LCH, Oklab, OkLCh and color() predefined spaces
//! - All named colors and transparent
//! - Initial currentColor/system colors through parseWithoutContext only
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

/// Converted sRGB channels stay unbounded until the destination requests
/// bytes. CSS Color 4 §11.2 does not gamut-map an HTML attribute value.
pub const FloatColor = struct {
    rgb: [3]f64,
    alpha: f64 = 1,

    pub fn quantize(self: FloatColor) Color {
        return .{
            .r = ColorParser.clampColorComponent(self.rgb[0] * 255),
            .g = ColorParser.clampColorComponent(self.rgb[1] * 255),
            .b = ColorParser.clampColorComponent(self.rgb[2] * 255),
            .a = @floatCast(clampAlpha(self.alpha)),
        };
    }

    fn fromBytes(color: Color) FloatColor {
        return .{ .rgb = .{ @as(f64, @floatFromInt(color.r)) / 255, @as(f64, @floatFromInt(color.g)) / 255, @as(f64, @floatFromInt(color.b)) / 255 }, .alpha = color.a };
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
    /// CSS Color 4 §4.5, without a context element. The whole input must
    /// match <color>. HTML then chooses its own destination/serialization.
    pub fn parseWithoutContext(input: []const u8, allocator: std.mem.Allocator) ColorParseError!FloatColor {
        var ctx = ParserContext.noQuirks(allocator);
        defer ctx.deinit();
        var tok = Tokenizer.init(input);
        tok.skipWhitespace();
        // §4.5 step 2: with no context, resolve using initial property
        // values. This entry point explicitly excludes stylesheet/CSSOM
        // parsing: parse() must keep its existing keyword behavior.
        const first = tok.peek();
        const initial: ?Color = if (first.token_type == .ident) blk: {
            var buffer: [512]u8 = undefined;
            const name = try decodedName(first.value, &buffer);
            break :blk getSystemColor(if (std.ascii.eqlIgnoreCase(name, "currentcolor")) "canvastext" else name);
        } else null;
        const color = if (initial) |value| blk: {
            _ = tok.next();
            break :blk FloatColor.fromBytes(value);
        } else try parseValue(FloatColor, &tok, "color", &ctx);
        tok.skipWhitespace();
        if (tok.next().token_type != .eof) return error.InvalidColor;
        return color;
    }

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
        return parseValue(Color, tok, property, ctx);
    }

    inline fn parseValue(comptime Result: type, tok: *Tokenizer, property: []const u8, ctx: *const ParserContext) ColorParseError!Result {
        tok.skipWhitespace();
        const token = tok.next();
        // Ordinary tokens need neither a decoding buffer nor its Debug-mode
        // initialization. Keep the complete escaped-name path off that path.
        if (std.mem.indexOfAny(u8, token.value, "\\\x00") == null)
            return parseTokenValue(Result, tok, token.token_type, token.value, property, ctx);
        var buffer: [512]u8 = undefined;
        return parseTokenValue(Result, tok, token.token_type, try decodedName(token.value, &buffer), property, ctx);
    }

    inline fn parseTokenValue(comptime Result: type, tok: *Tokenizer, token_type: TokenType, value: []const u8, property: []const u8, ctx: *const ParserContext) ColorParseError!Result {
        switch (token_type) {
            // #fff or #ffffff
            .hash => return byteResult(Result, try parseHexColor(value)),

            // rgb(...) or rgba(...)
            .function => return parseFunction(Result, tok, value),

            // Named color or hashless hex in quirks mode
            .ident => {
                // Try named color first
                if (getNamedColor(value)) |color| {
                    return byteResult(Result, color);
                }

                // In quirks mode, try hashless hex for allowed properties
                if (ctx.allowsHashlessHexColor(property) and isHexColor(value)) {
                    return byteResult(Result, try parseHexDigits(value));
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

    const Function = enum { rgb, hsl, hwb, lab, lch, oklab, oklch, color };
    const Component = struct {
        value: f64,
        kind: enum { number, percentage, angle, missing },

        fn scaled(self: Component, percent_reference: f64) f64 {
            return if (self.kind == .percentage) self.value / 100 * percent_reference else self.value;
        }
    };

    fn parseFunction(comptime Result: type, tok: *Tokenizer, name: []const u8) ColorParseError!Result {
        const function: Function = blk: {
            if (std.ascii.eqlIgnoreCase(name, "rgba")) break :blk .rgb;
            if (std.ascii.eqlIgnoreCase(name, "hsla")) break :blk .hsl;
            inline for (std.meta.fields(Function)) |field| {
                if (std.ascii.eqlIgnoreCase(name, field.name)) break :blk @enumFromInt(field.value);
            }
            return error.InvalidColor;
        };
        // CSS Color 4 §§4.1, 5.1, 7–10: one grammar for the three
        // components, with legacy separators only for rgb()/hsl().
        if (tok.next().token_type != .left_paren) return error.UnexpectedToken;
        var space: Space = .srgb;
        if (function == .color) {
            tok.skipWhitespace();
            const token = tok.next();
            if (token.token_type != .ident) return error.InvalidColor;
            var buffer: [512]u8 = undefined;
            space = spaceNamed(try decodedName(token.value, &buffer)) orelse return error.InvalidColor;
        }
        var components: [3]Component = undefined;
        components[0] = try parseComponent(tok, function == .hsl or function == .hwb);
        tok.skipWhitespace();
        const legacy = tok.peek().token_type == .comma;
        if (legacy and function != .rgb and function != .hsl) return error.InvalidColor;
        for (1..3) |index| {
            if (legacy and tok.next().token_type != .comma) return error.UnexpectedToken;
            components[index] = try parseComponent(tok, index == 2 and (function == .lch or function == .oklch));
            tok.skipWhitespace();
        }
        if (legacy) {
            for (components) |component| if (component.kind == .missing) return error.InvalidComponent;
            if (function == .rgb) {
                if (components[0].kind != components[1].kind or components[0].kind != components[2].kind) return error.InvalidComponent;
            } else if (components[1].kind != .percentage or components[2].kind != .percentage) return error.InvalidComponent;
        }
        var alpha: f64 = 1;
        const delimiter = tok.peek();
        if ((legacy and delimiter.token_type == .comma) or
            (!legacy and delimiter.token_type == .delim and std.mem.eql(u8, delimiter.value, "/")))
        {
            _ = tok.next();
            const component = try parseComponent(tok, false);
            if (legacy and component.kind == .missing) return error.InvalidComponent;
            alpha = clampAlpha(component.scaled(1));
        }
        tok.skipWhitespace();
        if (tok.next().token_type != .right_paren) return error.MissingCloseParen;

        // The property parser requests bytes. RGB already has that reference
        // range: clamp/round once, without an intermediate sRGB conversion.
        // Context-free callers retain the unquantized parsed components below.
        if (Result == Color and function == .rgb) return .{
            .r = clampColorComponent(components[0].scaled(255)),
            .g = clampColorComponent(components[1].scaled(255)),
            .b = clampColorComponent(components[2].scaled(255)),
            .a = @floatCast(alpha),
        };
        const rgb: [3]f64 = switch (function) {
            .rgb => .{
                clampChannel(components[0].scaled(255), 255) / 255,
                clampChannel(components[1].scaled(255), 255) / 255,
                clampChannel(components[2].scaled(255), 255) / 255,
            },
            .hsl => hslToSrgb(components[0].value, @max(0, components[1].value), components[2].value),
            .hwb => hwbToSrgb(components[0].value, components[1].value, components[2].value),
            .lab, .lch, .oklab, .oklch => blk: {
                const ok = function == .oklab or function == .oklch;
                const polar = function == .lch or function == .oklch;
                var lab: [3]f64 = .{
                    clampChannel(components[0].scaled(if (ok) 1 else 100), if (ok) 1 else 100),
                    components[1].scaled(if (ok) 0.4 else if (polar) 150 else 125),
                    components[2].scaled(if (ok) 0.4 else 125),
                };
                if (polar) {
                    const chroma = @max(0, lab[1]);
                    const hue = normalizedHue(components[2].value) * (std.math.pi / 180.0);
                    lab[1] = chroma * @cos(hue);
                    lab[2] = chroma * @sin(hue);
                }
                // §11.2 steps 3–7: Lab uses D50; Oklab uses D65.
                break :blk xyzToSrgb(if (ok) oklabToXyz(lab) else d50ToD65(labToXyz(lab)));
            },
            .color => predefinedToSrgb(space, .{ components[0].scaled(1), components[1].scaled(1), components[2].scaled(1) }),
        };
        const result = FloatColor{ .rgb = rgb, .alpha = alpha };
        return if (Result == Color) result.quantize() else result;
    }

    fn parseComponent(tok: *Tokenizer, hue: bool) ColorParseError!Component {
        tok.skipWhitespace();
        const token = tok.next();
        switch (token.token_type) {
            .number => return .{ .value = token.numeric_value orelse return error.InvalidComponent, .kind = .number },
            .percentage => {
                if (hue) return error.InvalidComponent;
                return .{ .value = token.numeric_value orelse return error.InvalidComponent, .kind = .percentage };
            },
            .ident => {
                if (!tokenizer.nameEql(token.value, "none")) return error.InvalidComponent;
                return .{ .value = 0, .kind = .missing };
            },
            .dimension => {
                if (!hue) return error.InvalidComponent;
                const unit = token.unit orelse return error.InvalidComponent;
                const scale: f64 = if (tokenizer.nameEql(unit, "deg")) 1 else if (tokenizer.nameEql(unit, "grad")) 0.9 else if (tokenizer.nameEql(unit, "rad")) 180.0 / std.math.pi else if (tokenizer.nameEql(unit, "turn")) 360 else return error.InvalidComponent;
                return .{ .value = (token.numeric_value orelse return error.InvalidComponent) * scale, .kind = .angle };
            },
            // TODO(css math functions, CSS Values 4 §10): use the shared
            // numeric-expression parser when that capability is available.
            .function => return error.InvalidComponent,
            else => return error.InvalidComponent,
        }
    }

    fn clampColorComponent(value: f64) u8 {
        // CSS Color 4 §5.1 clamps at parsed-value time; CSS Values 4
        // §10.9.2 censors NaN to zero. Clamp before the integer conversion.
        const clamped = if (std.math.isNan(value)) 0.0 else std.math.clamp(value, 0.0, 255.0);
        return @intFromFloat(@round(clamped));
    }
};

fn byteResult(comptime Result: type, color: Color) Result {
    return if (Result == Color) color else FloatColor.fromBytes(color);
}

fn decodedName(raw: []const u8, buffer: *[512]u8) ColorParseError![]const u8 {
    if (std.mem.indexOfScalar(u8, raw, '\\') == null and std.mem.indexOfScalar(u8, raw, 0) == null) return raw;
    // The longest color keyword is 20 ASCII characters; each can occupy
    // seven bytes as a CSS hex escape. Longer names cannot match this grammar.
    if (raw.len > 141) return error.InvalidColor;
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    return tokenizer.decode(fba.allocator(), raw) catch return error.InvalidColor;
}

fn clampChannel(value: f64, maximum: f64) f64 {
    return if (std.math.isNan(value)) 0 else std.math.clamp(value, 0, maximum);
}

fn clampAlpha(value: f64) f64 {
    return clampChannel(value, 1);
}

fn normalizedHue(value: f64) f64 {
    // CSS Color 4 §4.3: infinite hues normalize to zero.
    return if (std.math.isFinite(value)) @mod(value, 360) else 0;
}

fn hslToSrgb(hue: f64, saturation: f64, lightness: f64) [3]f64 {
    // CSS Color 4 §7.1. Preserve extended values until the destination.
    const h = normalizedHue(hue) / 30;
    const l = lightness / 100;
    const a = saturation / 100 * @min(l, 1 - l);
    var result: [3]f64 = undefined;
    for ([_]f64{ 0, 8, 4 }, 0..) |offset, i| {
        const k = @mod(offset + h, 12);
        result[i] = l - a * @max(-1, @min(@min(k - 3, 9 - k), 1));
    }
    return result;
}

fn hwbToSrgb(hue: f64, white: f64, black: f64) [3]f64 {
    // CSS Color 4 §8.1: normalize achromatic colors before mixing.
    const w = white / 100;
    const b = black / 100;
    if (w + b >= 1) return @splat(w / (w + b));
    var rgb = hslToSrgb(hue, 100, 50);
    for (&rgb) |*c| c.* = c.* * (1 - w - b) + w;
    return rgb;
}

const Space = enum { srgb, srgb_linear, display_p3, display_p3_linear, a98_rgb, prophoto_rgb, rec2020, xyz_d50, xyz_d65 };

fn spaceNamed(name: []const u8) ?Space {
    const spaces = std.StaticStringMap(Space).initComptime(.{
        .{ "srgb", .srgb },             .{ "srgb-linear", .srgb_linear },
        .{ "display-p3", .display_p3 }, .{ "display-p3-linear", .display_p3_linear },
        .{ "a98-rgb", .a98_rgb },       .{ "prophoto-rgb", .prophoto_rgb },
        .{ "rec2020", .rec2020 },       .{ "xyz-d50", .xyz_d50 },
        .{ "xyz-d65", .xyz_d65 },       .{ "xyz", .xyz_d65 },
    });
    var lower: [20]u8 = undefined;
    if (name.len > lower.len) return null;
    return spaces.get(std.ascii.lowerString(lower[0..name.len], name));
}

fn matrixVector(matrix: [3][3]f64, vector: [3]f64) [3]f64 {
    var result: [3]f64 = undefined;
    for (matrix, &result) |row, *output| output.* = row[0] * vector[0] + row[1] * vector[1] + row[2] * vector[2];
    return result;
}

fn linearSrgb(value: f64) f64 {
    const magnitude = @abs(value);
    return if (magnitude <= 0.04045) value / 12.92 else std.math.copysign(std.math.pow(f64, (magnitude + 0.055) / 1.055, 2.4), value);
}

fn encodedSrgb(value: f64) f64 {
    const magnitude = @abs(value);
    return if (magnitude <= 0.0031308) value * 12.92 else std.math.copysign(1.055 * std.math.pow(f64, magnitude, 1.0 / 2.4) - 0.055, value);
}

// Browsers use BT.2020's piecewise curve, not the current draft's pure
// gamma 2.4 / BT.1886 (CSS Color 4 §§10.8, 19, cached in a99cc3f07e).
// Golden rule 2: WebKit, Blink/Skia and Gecko agree. See:
// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/graphics/ColorTransferFunctions.h
// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/graphics/color.cc
// https://github.com/google/skia/blob/main/include/core/SkColorSpace.h
// https://searchfox.org/mozilla-central/source/servo/components/style/color/convert.rs
const rec2020_alpha = 1.09929682680944;
const rec2020_beta = 0.018053968510807;

fn linearRec2020(value: f64) f64 {
    const magnitude = @abs(value);
    return if (magnitude < rec2020_beta * 4.5) value / 4.5 else std.math.copysign(std.math.pow(f64, (magnitude + rec2020_alpha - 1) / rec2020_alpha, 1.0 / 0.45), value);
}

fn encodedRec2020(value: f64) f64 {
    const magnitude = @abs(value);
    return if (magnitude < rec2020_beta) value * 4.5 else std.math.copysign(rec2020_alpha * std.math.pow(f64, magnitude, 0.45) - (rec2020_alpha - 1), value);
}

fn xyzToSrgb(xyz: [3]f64) [3]f64 {
    // CSS Color 4 §11.2 steps 7–8 and §19's colorimetric matrix data.
    // sRGB here is a value, not a display: do not gamut-map or clip.
    var rgb = matrixVector(.{
        .{ 12831.0 / 3959.0, -329.0 / 214.0, -1974.0 / 3959.0 },
        .{ -851781.0 / 878810.0, 1648619.0 / 878810.0, 36519.0 / 878810.0 },
        .{ 705.0 / 12673.0, -2585.0 / 12673.0, 705.0 / 667.0 },
    }, xyz);
    for (&rgb) |*value| value.* = encodedSrgb(value.*);
    return rgb;
}

fn d50ToD65(xyz: [3]f64) [3]f64 {
    // CSS Color 4 §11.2 step 5: linear Bradford chromatic adaptation.
    return matrixVector(.{
        .{ 0.955473421488075, -0.02309845494876471, 0.06325924320057072 },
        .{ -0.0283697093338637, 1.0099953980813041, 0.021041441191917323 },
        .{ 0.012314014864481998, -0.020507649298898964, 1.330365926242124 },
    }, xyz);
}

fn labToXyz(lab: [3]f64) [3]f64 {
    // CSS Color 4 §10.11 step 1, CIE Lab inverse with the D50 white.
    const kappa = 24389.0 / 27.0;
    const epsilon = 216.0 / 24389.0;
    const fy = (lab[0] + 16) / 116;
    const f: [3]f64 = .{ lab[1] / 500 + fy, fy, fy - lab[2] / 200 };
    const white: [3]f64 = .{ 0.3457 / 0.3585, 1, (1.0 - 0.3457 - 0.3585) / 0.3585 };
    var xyz: [3]f64 = undefined;
    for (f, white, &xyz) |component, reference, *output| {
        const cube = component * component * component;
        output.* = reference * (if (cube > epsilon) cube else (116 * component - 16) / kappa);
    }
    return xyz;
}

fn oklabToXyz(lab: [3]f64) [3]f64 {
    // CSS Color 4 §10.11, Oklab inverse in the D65 reference space.
    var lms = matrixVector(.{
        .{ 1, 0.3963377773761749, 0.2158037573099136 },
        .{ 1, -0.1055613458156586, -0.0638541728258133 },
        .{ 1, -0.0894841775298119, -1.2914855480194092 },
    }, lab);
    for (&lms) |*value| value.* = value.* * value.* * value.*;
    return matrixVector(.{
        .{ 1.2268798758459243, -0.5578149944602171, 0.2813910456659647 },
        .{ -0.0405757452148008, 1.1122868032803170, -0.0717110580655164 },
        .{ -0.0763729366746601, -0.4214933324022432, 1.5869240198367816 },
    }, lms);
}

fn predefinedToSrgb(space: Space, components: [3]f64) [3]f64 {
    // CSS Color 4 §10.12 steps 1–5. The matrices are the §19 data, with
    // extended transfer functions so intermediate negative values survive.
    if (space == .srgb) return components;
    if (space == .xyz_d65) return xyzToSrgb(components);
    if (space == .xyz_d50) return xyzToSrgb(d50ToD65(components));
    var linear = components;
    for (&linear) |*value| {
        const v = value.*;
        value.* = switch (space) {
            .srgb_linear, .display_p3_linear => v,
            .display_p3 => linearSrgb(v),
            .a98_rgb => std.math.copysign(std.math.pow(f64, @abs(v), 563.0 / 256.0), v),
            .prophoto_rgb => if (@abs(v) <= 16.0 / 512.0) v / 16 else std.math.copysign(std.math.pow(f64, @abs(v), 1.8), v),
            .rec2020 => linearRec2020(v),
            else => unreachable,
        };
    }
    if (space == .srgb_linear) {
        for (&linear) |*value| value.* = encodedSrgb(value.*);
        return linear;
    }
    const matrix: [3][3]f64 = switch (space) {
        .display_p3, .display_p3_linear => .{
            .{ 608311.0 / 1250200.0, 189793.0 / 714400.0, 198249.0 / 1000160.0 },
            .{ 35783.0 / 156275.0, 247089.0 / 357200.0, 198249.0 / 2500400.0 },
            .{ 0, 32229.0 / 714400.0, 5220557.0 / 5000800.0 },
        },
        .a98_rgb => .{
            .{ 573536.0 / 994567.0, 263643.0 / 1420810.0, 187206.0 / 994567.0 },
            .{ 591459.0 / 1989134.0, 6239551.0 / 9945670.0, 374412.0 / 4972835.0 },
            .{ 53769.0 / 1989134.0, 351524.0 / 4972835.0, 4929758.0 / 4972835.0 },
        },
        .prophoto_rgb => .{
            .{ 0.79776664490064230, 0.13518129740053308, 0.03134773412839220 },
            .{ 0.28807482881940130, 0.71183523424187300, 0.00008993693872564 },
            .{ 0, 0, 0.82510460251046020 },
        },
        .rec2020 => .{
            .{ 63426534.0 / 99577255.0, 20160776.0 / 139408157.0, 47086771.0 / 278816314.0 },
            .{ 26158966.0 / 99577255.0, 472592308.0 / 697040785.0, 8267143.0 / 139408157.0 },
            .{ 0, 19567812.0 / 697040785.0, 295819943.0 / 278816314.0 },
        },
        else => unreachable,
    };
    const xyz = matrixVector(matrix, linear);
    return xyzToSrgb(if (space == .prophoto_rgb) d50ToD65(xyz) else xyz);
}

/// CSS Color 4 §6.1: the complete 148-color table.
const named_colors = std.StaticStringMap(u32).initComptime(.{
    .{ "aliceblue", 0xf0f8ff },
    .{ "antiquewhite", 0xfaebd7 },
    .{ "aqua", 0x00ffff },
    .{ "aquamarine", 0x7fffd4 },
    .{ "azure", 0xf0ffff },
    .{ "beige", 0xf5f5dc },
    .{ "bisque", 0xffe4c4 },
    .{ "black", 0x000000 },
    .{ "blanchedalmond", 0xffebcd },
    .{ "blue", 0x0000ff },
    .{ "blueviolet", 0x8a2be2 },
    .{ "brown", 0xa52a2a },
    .{ "burlywood", 0xdeb887 },
    .{ "cadetblue", 0x5f9ea0 },
    .{ "chartreuse", 0x7fff00 },
    .{ "chocolate", 0xd2691e },
    .{ "coral", 0xff7f50 },
    .{ "cornflowerblue", 0x6495ed },
    .{ "cornsilk", 0xfff8dc },
    .{ "crimson", 0xdc143c },
    .{ "cyan", 0x00ffff },
    .{ "darkblue", 0x00008b },
    .{ "darkcyan", 0x008b8b },
    .{ "darkgoldenrod", 0xb8860b },
    .{ "darkgray", 0xa9a9a9 },
    .{ "darkgreen", 0x006400 },
    .{ "darkgrey", 0xa9a9a9 },
    .{ "darkkhaki", 0xbdb76b },
    .{ "darkmagenta", 0x8b008b },
    .{ "darkolivegreen", 0x556b2f },
    .{ "darkorange", 0xff8c00 },
    .{ "darkorchid", 0x9932cc },
    .{ "darkred", 0x8b0000 },
    .{ "darksalmon", 0xe9967a },
    .{ "darkseagreen", 0x8fbc8f },
    .{ "darkslateblue", 0x483d8b },
    .{ "darkslategray", 0x2f4f4f },
    .{ "darkslategrey", 0x2f4f4f },
    .{ "darkturquoise", 0x00ced1 },
    .{ "darkviolet", 0x9400d3 },
    .{ "deeppink", 0xff1493 },
    .{ "deepskyblue", 0x00bfff },
    .{ "dimgray", 0x696969 },
    .{ "dimgrey", 0x696969 },
    .{ "dodgerblue", 0x1e90ff },
    .{ "firebrick", 0xb22222 },
    .{ "floralwhite", 0xfffaf0 },
    .{ "forestgreen", 0x228b22 },
    .{ "fuchsia", 0xff00ff },
    .{ "gainsboro", 0xdcdcdc },
    .{ "ghostwhite", 0xf8f8ff },
    .{ "gold", 0xffd700 },
    .{ "goldenrod", 0xdaa520 },
    .{ "gray", 0x808080 },
    .{ "green", 0x008000 },
    .{ "greenyellow", 0xadff2f },
    .{ "grey", 0x808080 },
    .{ "honeydew", 0xf0fff0 },
    .{ "hotpink", 0xff69b4 },
    .{ "indianred", 0xcd5c5c },
    .{ "indigo", 0x4b0082 },
    .{ "ivory", 0xfffff0 },
    .{ "khaki", 0xf0e68c },
    .{ "lavender", 0xe6e6fa },
    .{ "lavenderblush", 0xfff0f5 },
    .{ "lawngreen", 0x7cfc00 },
    .{ "lemonchiffon", 0xfffacd },
    .{ "lightblue", 0xadd8e6 },
    .{ "lightcoral", 0xf08080 },
    .{ "lightcyan", 0xe0ffff },
    .{ "lightgoldenrodyellow", 0xfafad2 },
    .{ "lightgray", 0xd3d3d3 },
    .{ "lightgreen", 0x90ee90 },
    .{ "lightgrey", 0xd3d3d3 },
    .{ "lightpink", 0xffb6c1 },
    .{ "lightsalmon", 0xffa07a },
    .{ "lightseagreen", 0x20b2aa },
    .{ "lightskyblue", 0x87cefa },
    .{ "lightslategray", 0x778899 },
    .{ "lightslategrey", 0x778899 },
    .{ "lightsteelblue", 0xb0c4de },
    .{ "lightyellow", 0xffffe0 },
    .{ "lime", 0x00ff00 },
    .{ "limegreen", 0x32cd32 },
    .{ "linen", 0xfaf0e6 },
    .{ "magenta", 0xff00ff },
    .{ "maroon", 0x800000 },
    .{ "mediumaquamarine", 0x66cdaa },
    .{ "mediumblue", 0x0000cd },
    .{ "mediumorchid", 0xba55d3 },
    .{ "mediumpurple", 0x9370db },
    .{ "mediumseagreen", 0x3cb371 },
    .{ "mediumslateblue", 0x7b68ee },
    .{ "mediumspringgreen", 0x00fa9a },
    .{ "mediumturquoise", 0x48d1cc },
    .{ "mediumvioletred", 0xc71585 },
    .{ "midnightblue", 0x191970 },
    .{ "mintcream", 0xf5fffa },
    .{ "mistyrose", 0xffe4e1 },
    .{ "moccasin", 0xffe4b5 },
    .{ "navajowhite", 0xffdead },
    .{ "navy", 0x000080 },
    .{ "oldlace", 0xfdf5e6 },
    .{ "olive", 0x808000 },
    .{ "olivedrab", 0x6b8e23 },
    .{ "orange", 0xffa500 },
    .{ "orangered", 0xff4500 },
    .{ "orchid", 0xda70d6 },
    .{ "palegoldenrod", 0xeee8aa },
    .{ "palegreen", 0x98fb98 },
    .{ "paleturquoise", 0xafeeee },
    .{ "palevioletred", 0xdb7093 },
    .{ "papayawhip", 0xffefd5 },
    .{ "peachpuff", 0xffdab9 },
    .{ "peru", 0xcd853f },
    .{ "pink", 0xffc0cb },
    .{ "plum", 0xdda0dd },
    .{ "powderblue", 0xb0e0e6 },
    .{ "purple", 0x800080 },
    .{ "rebeccapurple", 0x663399 },
    .{ "red", 0xff0000 },
    .{ "rosybrown", 0xbc8f8f },
    .{ "royalblue", 0x4169e1 },
    .{ "saddlebrown", 0x8b4513 },
    .{ "salmon", 0xfa8072 },
    .{ "sandybrown", 0xf4a460 },
    .{ "seagreen", 0x2e8b57 },
    .{ "seashell", 0xfff5ee },
    .{ "sienna", 0xa0522d },
    .{ "silver", 0xc0c0c0 },
    .{ "skyblue", 0x87ceeb },
    .{ "slateblue", 0x6a5acd },
    .{ "slategray", 0x708090 },
    .{ "slategrey", 0x708090 },
    .{ "snow", 0xfffafa },
    .{ "springgreen", 0x00ff7f },
    .{ "steelblue", 0x4682b4 },
    .{ "tan", 0xd2b48c },
    .{ "teal", 0x008080 },
    .{ "thistle", 0xd8bfd8 },
    .{ "tomato", 0xff6347 },
    .{ "turquoise", 0x40e0d0 },
    .{ "violet", 0xee82ee },
    .{ "wheat", 0xf5deb3 },
    .{ "white", 0xffffff },
    .{ "whitesmoke", 0xf5f5f5 },
    .{ "yellow", 0xffff00 },
    .{ "yellowgreen", 0x9acd32 },
});

fn getNamedColor(name: []const u8) ?Color {
    if (name.len > 20) return null;
    if (std.ascii.eqlIgnoreCase(name, "transparent")) return Color.transparent;
    // Most declarations already use lowercase. Preserve one complete table,
    // but avoid copying and case-folding a keyword that it already matches.
    if (named_colors.get(name)) |rgb| return colorFromHex(rgb);
    for (name) |char| {
        if (std.ascii.isUpper(char)) break;
    } else return null;
    var lower: [20]u8 = undefined;
    const key = std.ascii.lowerString(lower[0..name.len], name);
    const rgb = named_colors.get(key) orelse return null;
    return colorFromHex(rgb);
}

fn colorFromHex(rgb: u32) Color {
    return Color.rgb(@intCast(rgb >> 16), @truncate(rgb >> 8), @truncate(rgb));
}

// CSS Color 4 §6.2 permits a fixed UA palette. These opaque light values
// are Blink's DefaultSystemColor and default platform selection RGBs:
// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/layout/layout_theme.cc
// https://github.com/chromium/chromium/blob/main/third_party/blink/public/common/renderer_preferences/renderer_preferences.h
// TODO(style color-scheme): host/dark palettes need the style-system policy.
const light_system_colors = std.StaticStringMap(u32).initComptime(.{
    .{ "accentcolor", 0x0075ff },   .{ "accentcolortext", 0xffffff },
    .{ "activetext", 0xff0000 },    .{ "buttonborder", 0x767676 },
    .{ "buttonface", 0xefefef },    .{ "buttontext", 0x000000 },
    .{ "canvas", 0xffffff },        .{ "canvastext", 0x000000 },
    .{ "field", 0xffffff },         .{ "fieldtext", 0x000000 },
    .{ "graytext", 0x808080 },      .{ "highlight", 0x1967d2 },
    .{ "highlighttext", 0xffffff }, .{ "linktext", 0x0000ee },
    .{ "mark", 0xffff00 },          .{ "marktext", 0x000000 },
    .{ "selecteditem", 0x1967d2 },  .{ "selecteditemtext", 0xffffff },
    .{ "visitedtext", 0x551a8b },
});

// CSS Color 4 Appendix A: each deprecated keyword computes to a standard
// system color, so aliases never carry a second set of palette values.
const deprecated_system_colors = std.StaticStringMap([]const u8).initComptime(.{
    .{ "activeborder", "buttonborder" },      .{ "activecaption", "canvas" },
    .{ "appworkspace", "canvas" },            .{ "background", "canvas" },
    .{ "buttonhighlight", "buttonface" },     .{ "buttonshadow", "buttonface" },
    .{ "captiontext", "canvastext" },         .{ "inactiveborder", "buttonborder" },
    .{ "inactivecaption", "canvas" },         .{ "inactivecaptiontext", "graytext" },
    .{ "infobackground", "canvas" },          .{ "infotext", "canvastext" },
    .{ "menu", "canvas" },                    .{ "menutext", "canvastext" },
    .{ "scrollbar", "canvas" },               .{ "threeddarkshadow", "buttonborder" },
    .{ "threedface", "buttonface" },          .{ "threedhighlight", "buttonborder" },
    .{ "threedlightshadow", "buttonborder" }, .{ "threedshadow", "buttonborder" },
    .{ "window", "canvas" },                  .{ "windowframe", "buttonborder" },
    .{ "windowtext", "canvastext" },
});

fn getSystemColor(name: []const u8) ?Color {
    var lower: [20]u8 = undefined;
    if (name.len > lower.len) return null;
    const key = std.ascii.lowerString(lower[0..name.len], name);
    const standard = deprecated_system_colors.get(key) orelse key;
    return colorFromHex(light_system_colors.get(standard) orelse return null);
}

// ============================================================================
// Tests
// ============================================================================

test "color components clamp before converting to an integer" {
    const cases = .{
        .{ @as(f64, 1e100), @as(u8, 255) },
        .{ @as(f64, -1e100), @as(u8, 0) },
        .{ std.math.inf(f64), @as(u8, 255) },
        .{ -std.math.inf(f64), @as(u8, 0) },
        .{ std.math.nan(f64), @as(u8, 0) },
        .{ @as(f64, 254.5), @as(u8, 255) },
        .{ @as(f64, 0.4), @as(u8, 0) },
        .{ @as(f64, 127.6), @as(u8, 128) },
    };
    inline for (cases) |case| try std.testing.expectEqual(case[1], ColorParser.clampColorComponent(case[0]));
}

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

fn expectParsedColor(input: []const u8, expected: Color) !void {
    var ctx = ParserContext.noQuirks(std.testing.allocator);
    defer ctx.deinit();
    var tok = Tokenizer.init(input);
    const actual = try ColorParser.parse(&tok, "color", &ctx);
    tok.skipWhitespace();
    try std.testing.expectEqual(TokenType.eof, tok.next().token_type);
    try std.testing.expectEqual(expected.r, actual.r);
    try std.testing.expectEqual(expected.g, actual.g);
    try std.testing.expectEqual(expected.b, actual.b);
    try std.testing.expectApproxEqAbs(expected.a, actual.a, 0.0001);
}

test "CSS colors - named colors and escaped identifiers" {
    try expectParsedColor("crimson", Color.rgb(220, 20, 60));
    try expectParsedColor("BISQUE", Color.rgb(255, 228, 196));
    try expectParsedColor("rebeccapurple", Color.rgb(102, 51, 153));
    try expectParsedColor("lightgoldenrodyellow", Color.rgb(250, 250, 210));
    try expectParsedColor("r\\65 d", Color.red);
    try expectParsedColor("#\\66 ff", Color.white);
}

test "CSS colors - modern and legacy RGB syntax" {
    try expectParsedColor("rgb(none 100% 0 / none)", Color.rgba(0, 255, 0, 0));
    try expectParsedColor("rgba(100%, 0%, 0%, 50%)", Color.rgba(255, 0, 0, 0.5));
    try expectParsedColor("rgb(50% 127.5 0 / 0.25)", Color.rgba(128, 128, 0, 0.25));
    try expectParsedColor("rgb(1e1000 -1e1000 0)", Color.red);
}

test "CSS colors - legacy and modern separators must not mix" {
    const invalid = [_][]const u8{
        "rgb(1, 2 3)",       "rgb(1 2, 3)",   "rgb(1 2 3, .5)",
        "rgb(1, 2, 3 / .5)", "rgb(1, 2%, 3)", "rgb(none, 2, 3)",
        "rgb(1 2 3 * .5)",   "rgb(1 2 3 /)",  "hsl(0, 100, 50)",
        "hwb(0, 0%, 0%)",    "lab(50, 0, 0)", "color(unknown 1 0 0)",
    };
    var ctx = ParserContext.noQuirks(std.testing.allocator);
    defer ctx.deinit();
    for (invalid) |input| {
        var tok = Tokenizer.init(input);
        if (ColorParser.parse(&tok, "color", &ctx)) |_| return error.TestUnexpectedResult else |_| {}
    }
}

test "CSS colors - HSL and HWB conversion and hue units" {
    try expectParsedColor("hsl(150deg 100 53.5)", Color.rgb(18, 255, 136));
    try expectParsedColor("hsla(-.5turn, 100%, 50%, 25%)", Color.rgba(0, 255, 255, 0.25));
    try expectParsedColor("hsl(100grad 100% 50%)", Color.rgb(128, 255, 0));
    try expectParsedColor("hsl(3.141592653589793rad 100% 50%)", Color.rgb(0, 255, 255));
    try expectParsedColor("hsl(0 -50% 50%)", Color.rgb(128, 128, 128));
    try expectParsedColor("hwb(150 20% 10%)", Color.rgb(51, 230, 140));
    try expectParsedColor("hwb(45 40% 80%)", Color.rgb(85, 85, 85));
}

test "CSS colors - Lab LCH Oklab and Oklch conversion" {
    try expectParsedColor("lab(50% 0 0)", Color.rgb(119, 119, 119));
    try expectParsedColor("lch(50 0 123deg)", Color.rgb(119, 119, 119));
    try expectParsedColor("lab(44.36% 36.05 -58.99)", Color.rgb(118, 84, 205));
    try expectParsedColor("oklab(50% 0% 0%)", Color.rgb(99, 99, 99));
    try expectParsedColor("oklch(.5 0 45)", Color.rgb(99, 99, 99));
    try expectParsedColor("oklch(65% .15 270)", Color.rgb(108, 136, 234));
    try expectParsedColor("oklab(none none none)", Color.black);
}

test "CSS colors - predefined spaces convert through the correct whitepoint" {
    try expectParsedColor("color(srgb 100% 0% 0%)", Color.red);
    try expectParsedColor("color(srgb-linear .5 .5 .5)", Color.rgb(188, 188, 188));
    try expectParsedColor("color(display-p3 .5 0 0)", Color.rgb(140, 0, 0));
    try expectParsedColor("color(display-p3 1 0 0)", Color.red);
    try expectParsedColor("color(display-p3-linear .5 .5 .5)", Color.rgb(188, 188, 188));
    try expectParsedColor("color(a98-rgb .5 .5 .5)", Color.rgb(129, 129, 129));
    try expectParsedColor("color(prophoto-rgb .5 .5 .5)", Color.rgb(146, 146, 146));
    try expectParsedColor("color(rec2020 1 1 1)", Color.white);
    try expectParsedColor("color(xyz-d50 .2005 .14089 .4472)", Color.rgb(118, 84, 205));
    try expectParsedColor("color(xyz-d65 .21661 .14602 .59452)", Color.rgb(118, 84, 205));
    try expectParsedColor("color(xyz .21661 .14602 .59452)", Color.rgb(118, 84, 205));
}

test "context-free colors resolve initial values without changing stylesheet keywords" {
    const current = try ColorParser.parseWithoutContext(" currentColor ", std.testing.allocator);
    try std.testing.expect(current.quantize().eql(Color.black));
    const border = try ColorParser.parseWithoutContext("ActiveBorder", std.testing.allocator);
    try std.testing.expect(border.quantize().eql(Color.rgb(118, 118, 118)));
    var ctx = ParserContext.noQuirks(std.testing.allocator);
    defer ctx.deinit();
    for ([_][]const u8{ "currentColor", "CanvasText", "ActiveBorder" }) |value| {
        var tok = Tokenizer.init(value);
        try std.testing.expectError(error.InvalidColor, ColorParser.parse(&tok, "color", &ctx));
    }
    for ([_][]const u8{ "#fff;", "#fff\x00", "red blue" }) |value| {
        try std.testing.expectError(error.InvalidColor, ColorParser.parseWithoutContext(value, std.testing.allocator));
    }
    const extended = try ColorParser.parseWithoutContext("color(display-p3 1 0 0)", std.testing.allocator);
    try std.testing.expect(extended.rgb[0] > 1);
    try std.testing.expect(extended.rgb[1] < 0);
}

test "Rec2020 follows the browsers piecewise transfer curve" {
    try expectParsedColor("color(rec2020 .5 .5 .5)", Color.rgb(139, 139, 139));
    const cases = .{
        .{ @as(f64, 0), @as(f64, 0) },
        .{ @as(f64, 1), @as(f64, 1) },
        .{ @as(f64, 0.02), @as(f64, 0.0044444444444444444) },
        .{ @as(f64, 0.1), @as(f64, 0.022488867044468785) },
        .{ @as(f64, 0.5), @as(f64, 0.2597194371011775) },
    };
    inline for (cases) |case| {
        try std.testing.expectApproxEqAbs(case[1], linearRec2020(case[0]), 1e-12);
        try std.testing.expectApproxEqAbs(case[0], encodedRec2020(case[1]), 1e-12);
        try std.testing.expectApproxEqAbs(-case[1], linearRec2020(-case[0]), 1e-12);
        try std.testing.expectApproxEqAbs(-case[0], encodedRec2020(-case[1]), 1e-12);
    }
}

test "context-free colors use the fixed light system palette" {
    const cases = .{
        .{ "AccentColor", 0x0075ff },   .{ "AccentColorText", 0xffffff },
        .{ "ActiveText", 0xff0000 },    .{ "ButtonBorder", 0x767676 },
        .{ "ButtonFace", 0xefefef },    .{ "ButtonText", 0x000000 },
        .{ "Canvas", 0xffffff },        .{ "CanvasText", 0x000000 },
        .{ "Field", 0xffffff },         .{ "FieldText", 0x000000 },
        .{ "GrayText", 0x808080 },      .{ "Highlight", 0x1967d2 },
        .{ "HighlightText", 0xffffff }, .{ "LinkText", 0x0000ee },
        .{ "Mark", 0xffff00 },          .{ "MarkText", 0x000000 },
        .{ "SelectedItem", 0x1967d2 },  .{ "SelectedItemText", 0xffffff },
        .{ "VisitedText", 0x551a8b },
    };
    inline for (cases) |case| {
        const color = try ColorParser.parseWithoutContext(case[0], std.testing.allocator);
        try std.testing.expect(color.quantize().eql(colorFromHex(case[1])));
    }
}

test "context-free colors map every deprecated system keyword to its standard color" {
    const aliases = .{
        .{ "ActiveBorder", "ButtonBorder" },      .{ "ActiveCaption", "Canvas" },
        .{ "AppWorkspace", "Canvas" },            .{ "Background", "Canvas" },
        .{ "ButtonHighlight", "ButtonFace" },     .{ "ButtonShadow", "ButtonFace" },
        .{ "CaptionText", "CanvasText" },         .{ "InactiveBorder", "ButtonBorder" },
        .{ "InactiveCaption", "Canvas" },         .{ "InactiveCaptionText", "GrayText" },
        .{ "InfoBackground", "Canvas" },          .{ "InfoText", "CanvasText" },
        .{ "Menu", "Canvas" },                    .{ "MenuText", "CanvasText" },
        .{ "Scrollbar", "Canvas" },               .{ "ThreeDDarkShadow", "ButtonBorder" },
        .{ "ThreeDFace", "ButtonFace" },          .{ "ThreeDHighlight", "ButtonBorder" },
        .{ "ThreeDLightShadow", "ButtonBorder" }, .{ "ThreeDShadow", "ButtonBorder" },
        .{ "Window", "Canvas" },                  .{ "WindowFrame", "ButtonBorder" },
        .{ "WindowText", "CanvasText" },
    };
    inline for (aliases) |pair| {
        const old = try ColorParser.parseWithoutContext(pair[0], std.testing.allocator);
        const standard = try ColorParser.parseWithoutContext(pair[1], std.testing.allocator);
        try std.testing.expect(old.quantize().eql(standard.quantize()));
    }
}
