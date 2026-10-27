//! The font element's presentational hints (HTML 15.3.4 "Phrasing
//! content", specs/whatwg/html.md): its color attribute through the rules
//! for parsing a legacy color value (2.3.6), its face attribute as
//! 'font-family', its size attribute through the rules for parsing a legacy
//! font size. HTML gives them as algorithms, not CSS rules, so they cannot
//! live in html-hints.css; they enter the cascade as one declaration block
//! at the presentational hint origin, cached on the element's style state
//! the way resource_loading.backgroundHint caches the background hint.
//!
//! The two microsyntaxes are also the Editing spec's: the specified command
//! value of a <font> for foreColor and fontSize is "the value that the hint
//! sets" (src/html/execcommand/inline.zig).

const std = @import("std");
const css = @import("css");
const ElementStyle = @import("element_style.zig").ElementStyle;

const Allocator = std.mem.Allocator;
const DeclarationBlock = css.declarations.DeclarationBlock;

/// A font element's color, face and size attribute values, as the style
/// engine's attribute scan finds them (borrowed for the resolve).
pub const Attributes = struct {
    color: ?[]const u8 = null,
    face: ?[]const u8 = null,
    size: ?[]const u8 = null,

    /// Note the no-namespace attribute `name` = `value` if it is one of the
    /// three.
    pub fn take(self: *Attributes, name: []const u8, value: []const u8) void {
        if (std.mem.eql(u8, name, "color")) {
            self.color = value;
        } else if (std.mem.eql(u8, name, "face")) {
            self.face = value;
        } else if (std.mem.eql(u8, name, "size")) {
            self.size = value;
        }
    }

    fn any(self: Attributes) bool {
        return self.color != null or self.face != null or self.size != null;
    }
};

/// One font element's hint: the inputs it was built from (owned copies) and
/// the declarations. No DOM or realm back link.
pub const FontHint = struct {
    allocator: Allocator,
    color: ?[]u8,
    face: ?[]u8,
    size: ?[]u8,
    block: DeclarationBlock,

    pub fn destroy(self: *FontHint) void {
        self.block.deinit();
        if (self.color) |v| self.allocator.free(v);
        if (self.face) |v| self.allocator.free(v);
        if (self.size) |v| self.allocator.free(v);
        self.allocator.destroy(self);
    }

    fn matches(self: *const FontHint, attributes: Attributes) bool {
        return sameInput(self.color, attributes.color) and sameInput(self.face, attributes.face) and sameInput(self.size, attributes.size);
    }
};

fn sameInput(owned: ?[]u8, given: ?[]const u8) bool {
    if (owned == null and given == null) return true;
    if (owned == null or given == null) return false;
    return std.mem.eql(u8, owned.?, given.?);
}

fn dupeInput(allocator: Allocator, value: ?[]const u8) Allocator.Error!?[]u8 {
    const v = value orelse return null;
    return try allocator.dupe(u8, v);
}

/// The presentational hint block of an HTML font element with
/// `attributes`, cached on `state` and rebuilt only when an input string
/// changes; null when none of the three attributes gives a hint (the cache
/// is dropped then).
pub fn fontHint(state: *ElementStyle, attributes: Attributes) Allocator.Error!?*const DeclarationBlock {
    if (!attributes.any()) {
        state.dropFontHint();
        return null;
    }
    if (state.font_hint) |old| {
        if (old.matches(attributes)) return &old.block;
    }
    const allocator = state.allocator;
    const hint = try allocator.create(FontHint);
    errdefer allocator.destroy(hint);
    hint.* = .{ .allocator = allocator, .color = null, .face = null, .size = null, .block = DeclarationBlock.init(allocator) };
    errdefer {
        hint.block.deinit();
        if (hint.color) |v| allocator.free(v);
        if (hint.face) |v| allocator.free(v);
        if (hint.size) |v| allocator.free(v);
    }
    hint.color = try dupeInput(allocator, attributes.color);
    hint.face = try dupeInput(allocator, attributes.face);
    hint.size = try dupeInput(allocator, attributes.size);
    // color: the rules for parsing a legacy color value; failure is no hint.
    if (attributes.color) |input| {
        if (parseLegacyColor(input, cssNamedColor)) |color| {
            var buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrint(&buffer, "rgb({d}, {d}, {d})", .{ color.r, color.g, color.b }) catch unreachable;
            _ = try hint.block.setProperty(.{ .allocator = allocator }, "color", text, "");
        }
    }
    // face: 'font-family' set to the attribute's value (a value that does
    // not parse as a font-family sets nothing).
    if (attributes.face) |input| {
        _ = try hint.block.setProperty(.{ .allocator = allocator }, "font-family", input, "");
    }
    // size: the rules for parsing a legacy font size' keyword.
    if (attributes.size) |input| {
        if (parseLegacyFontSize(input)) |size| {
            _ = try hint.block.setProperty(.{ .allocator = allocator }, "font-size", legacy_font_size_keywords[size - 1], "");
        }
    }
    state.dropFontHint();
    state.font_hint = hint;
    return &hint.block;
}

/// A color the rules for parsing a legacy color value produce: an opaque
/// sRGB color.
pub const LegacyColor = struct { r: u8, g: u8, b: u8 };

/// HTML 2.3.6 "rules for parsing a legacy color value", given `input`:
/// the color, or null for failure. `isNamedColor` answers step 4 - the CSS
/// named colors only (not transparent, not the CSS2 system colors) - as an
/// opaque color, or null.
pub fn parseLegacyColor(input_in: []const u8, comptime namedColor: fn ([]const u8) ?LegacyColor) ?LegacyColor {
    // Step 1: "If input is the empty string, then return failure."
    if (input_in.len == 0) return null;
    // Step 2: "Strip leading and trailing ASCII whitespace from input."
    const input = std.mem.trim(u8, input_in, " \t\n\x0c\r");
    // Step 3: "If input is an ASCII case-insensitive match for
    // "transparent", then return failure."
    if (std.ascii.eqlIgnoreCase(input, "transparent")) return null;
    // Step 4: a named color.
    if (namedColor(input)) |color| return color;
    // Step 5: "#rgb": each digit times 17.
    if (std.unicode.utf8CountCodepoints(input) catch null) |length| {
        if (length == 4 and input[0] == '#' and std.ascii.isHex(input[1]) and std.ascii.isHex(input[2]) and std.ascii.isHex(input[3])) {
            return .{ .r = hexDigit(input[1]) * 17, .g = hexDigit(input[2]) * 17, .b = hexDigit(input[3]) * 17 };
        }
    }
    // Steps 6-10 build the digit string: a code point above U+FFFF is "00"
    // (6), at most 128 code points (7), a leading # removed (8), every
    // non-hex code point "0" (9), "0"s appended to a non-zero multiple of
    // three (10).
    var digits: [384]u8 = undefined;
    var count: usize = 0;
    var code_points: usize = 0;
    var iterator = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    var first = true;
    while (iterator.nextCodepoint()) |cp| {
        if (code_points == 128) break;
        code_points += 1;
        if (first and cp == '#') {
            first = false;
            continue;
        }
        first = false;
        if (cp > 0xFFFF) {
            digits[count] = '0';
            digits[count + 1] = '0';
            count += 2;
        } else if (cp < 0x80 and std.ascii.isHex(@intCast(cp))) {
            digits[count] = @intCast(cp);
            count += 1;
        } else {
            digits[count] = '0';
            count += 1;
        }
    }
    // Invalid UTF-8 never reaches here from a DOM string; treat the rest as
    // zeros if it does.
    while (count == 0 or count % 3 != 0) : (count += 1) digits[count] = '0';
    // Step 11: three components of equal length.
    var length = count / 3;
    var components = [3][]const u8{ digits[0..length], digits[length .. 2 * length], digits[2 * length .. 3 * length] };
    // Step 12: at most the last 8 characters of each.
    if (length > 8) {
        for (&components) |*component| component.* = component.*[length - 8 ..];
        length = 8;
    }
    // Step 13: strip leading zeros shared by every component, down to two.
    while (length > 2 and components[0][0] == '0' and components[1][0] == '0' and components[2][0] == '0') {
        for (&components) |*component| component.* = component.*[1..];
        length -= 1;
    }
    // Step 14: the first two characters of each.
    if (length > 2) {
        for (&components) |*component| component.* = component.*[0..2];
    }
    // Steps 15-19: each component as a hexadecimal number.
    return .{
        .r = std.fmt.parseInt(u8, components[0], 16) catch 0,
        .g = std.fmt.parseInt(u8, components[1], 16) catch 0,
        .b = std.fmt.parseInt(u8, components[2], 16) catch 0,
    };
}

fn hexDigit(c: u8) u8 {
    return std.fmt.charToDigit(c, 16) catch 0;
}

/// The 'font-size' keyword for each legacy font size 1-7 (step 12's table).
pub const legacy_font_size_keywords = [_][]const u8{ "x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large" };

/// HTML 15.3.4 "rules for parsing a legacy font size", given `input`: the
/// value 1-7 whose keyword the hint sets, or null for no hint.
pub fn parseLegacyFontSize(input: []const u8) ?u8 {
    // Steps 1-3: skip ASCII whitespace.
    var position: usize = 0;
    while (position < input.len and isAsciiWhitespace(input[position])) position += 1;
    // Step 4: past the end - no hint.
    if (position >= input.len) return null;
    // Step 5: the mode.
    const Mode = enum { relative_plus, relative_minus, absolute };
    var mode: Mode = .absolute;
    if (input[position] == '+') {
        mode = .relative_plus;
        position += 1;
    } else if (input[position] == '-') {
        mode = .relative_minus;
        position += 1;
    }
    // Step 6: collect ASCII digits.
    const start = position;
    while (position < input.len and std.ascii.isDigit(input[position])) position += 1;
    const digits = input[start..position];
    // Step 7: no digits - no hint.
    if (digits.len == 0) return null;
    // Step 8: base ten (saturating: anything past 7 clamps anyway).
    var value: i64 = 0;
    for (digits) |d| {
        value = value * 10 + (d - '0');
        if (value > 1000) value = 1000;
    }
    // Step 9.
    switch (mode) {
        .relative_plus => value += 3,
        .relative_minus => value = 3 - value,
        .absolute => {},
    }
    // Steps 10-11: clamp to 1-7.
    if (value > 7) value = 7;
    if (value < 1) value = 1;
    return @intCast(value);
}

fn isAsciiWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == 0x0c or c == '\r';
}

/// Step 4's lookup: a CSS named color (CSS Color 4 6.1), ASCII
/// case-insensitively - not transparent, currentcolor or a system color
/// ("CSS2 System Colors are not recognized").
pub fn cssNamedColor(name: []const u8) ?LegacyColor {
    if (name.len == 0 or name.len > 32) return null;
    for (name) |c| if (!std.ascii.isAlphabetic(c)) return null;
    if (std.ascii.eqlIgnoreCase(name, "transparent") or std.ascii.eqlIgnoreCase(name, "currentcolor")) return null;
    if (css.color.SystemColor.parse(name) != null) return null;
    var buffer: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const color = css.color.ColorParser.parseWithoutContext(name, fba.allocator()) catch return null;
    const bytes = color.quantize();
    return .{ .r = bytes.r, .g = bytes.g, .b = bytes.b };
}

fn noNamedColors(_: []const u8) ?LegacyColor {
    return null;
}

fn testNamedColors(name: []const u8) ?LegacyColor {
    if (std.ascii.eqlIgnoreCase(name, "blue")) return .{ .r = 0, .g = 0, .b = 255 };
    return null;
}

test "rules for parsing a legacy font size" {
    try std.testing.expectEqual(@as(?u8, 3), parseLegacyFontSize("3"));
    try std.testing.expectEqual(@as(?u8, 4), parseLegacyFontSize(" +1"));
    try std.testing.expectEqual(@as(?u8, 2), parseLegacyFontSize("-1"));
    try std.testing.expectEqual(@as(?u8, 7), parseLegacyFontSize("9"));
    try std.testing.expectEqual(@as(?u8, 1), parseLegacyFontSize("0"));
    try std.testing.expectEqual(@as(?u8, 1), parseLegacyFontSize("-5"));
    try std.testing.expectEqual(@as(?u8, 2), parseLegacyFontSize("2em"));
    try std.testing.expectEqual(@as(?u8, 3), parseLegacyFontSize("3.9"));
    try std.testing.expectEqual(@as(?u8, null), parseLegacyFontSize(""));
    try std.testing.expectEqual(@as(?u8, null), parseLegacyFontSize("  "));
    try std.testing.expectEqual(@as(?u8, null), parseLegacyFontSize("x"));
    try std.testing.expectEqual(@as(?u8, null), parseLegacyFontSize("+"));
}

test "rules for parsing a legacy color value" {
    const parse = struct {
        fn f(input: []const u8) ?LegacyColor {
            return parseLegacyColor(input, testNamedColors);
        }
    }.f;
    try std.testing.expectEqual(@as(?LegacyColor, null), parse(""));
    try std.testing.expectEqual(@as(?LegacyColor, null), parse("transparent"));
    try std.testing.expectEqual(LegacyColor{ .r = 0, .g = 0, .b = 255 }, parse(" Blue ").?);
    try std.testing.expectEqual(LegacyColor{ .r = 0xff, .g = 0, .b = 0 }, parse("#f00").?);
    try std.testing.expectEqual(LegacyColor{ .r = 0x00, .g = 0xff, .b = 0x00 }, parse("00ff00").?);
    try std.testing.expectEqual(LegacyColor{ .r = 0x12, .g = 0x34, .b = 0x56 }, parse("#123456").?);
    // Garbage becomes zeros: "potato" -> "0000a0" -> 00 00 a0... per the
    // steps: p o t a t o -> 0 0 0 a 0 0 -> components "00","0a","00".
    try std.testing.expectEqual(LegacyColor{ .r = 0x00, .g = 0x0a, .b = 0x00 }, parse("potato").?);
    // Nine digits: three components of three ("000", "000", "fff"); the
    // third does not start with 0, so step 14 keeps two of each.
    try std.testing.expectEqual(LegacyColor{ .r = 0, .g = 0, .b = 0xff }, parse("000000fff").?);
    try std.testing.expectEqual(@as(?LegacyColor, null), parseLegacyColor("", noNamedColors));
}
