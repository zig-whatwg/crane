//! HTML 4.10.5.1.14: update and serialize a color well control color.
//! CSS owns parsing/conversion; the input chooses the destination and alpha.
const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");

pub const Settings = struct {
    alpha: bool = false,
    space: enum { limited_srgb, display_p3 } = .limited_srgb,
};

/// A clean value is borrowed, so repeated input events need no sanitizer
/// allocation. Otherwise the returned DOMString owns its serialization.
pub fn sanitize(allocator: std.mem.Allocator, value: []const u8, settings: Settings) !runtime.DOMString {
    if (isSerialized(value, settings)) return runtime.DOMString.initInterned(value);
    // Update steps 3–4: parse with no context element; failure is opaque black.
    const color = css.ColorParser.parseWithoutContext(value, allocator) catch css.color.FloatColor{ .rgb = .{ 0, 0, 0 } };
    var alpha = if (settings.alpha) color.alpha else 1;
    var rgb: [3]f64 = undefined;
    if (settings.space == .limited_srgb) {
        // Serialize step 4: ALL components have eight-bit precision. The
        // CSS quantizer deliberately leaves alpha as a float; round it here.
        const bytes = color.quantize();
        if (!settings.alpha) {
            const hex = "0123456789abcdef";
            var text: [7]u8 = undefined;
            text[0] = '#';
            for ([_]u8{ bytes.r, bytes.g, bytes.b }, 0..) |byte, i| {
                text[1 + 2 * i] = hex[byte >> 4];
                text[2 + 2 * i] = hex[byte & 15];
            }
            return runtime.DOMString.initDupe(allocator, &text);
        }
        rgb = .{ @as(f64, @floatFromInt(bytes.r)) / 255, @as(f64, @floatFromInt(bytes.g)) / 255, @as(f64, @floatFromInt(bytes.b)) / 255 };
        alpha = @floor(std.math.clamp(alpha, 0, 1) * 255 + 0.5) / 255;
    } else {
        // Step 5: P3 channels remain extended, including negative values.
        rgb = color.toDisplayP3();
        // CSS Color 4 §15.4 allows an implementation-defined limit near
        // infinity (css-color-4.md:8274–8276). FloatColor's limit is f64.
        // CSS Values 4 §10.9 censors signed zero, infinity and NaN at the
        // calculation boundary (css-values-4.md:4770, 4800, 4824).
        for (&rgb) |*channel| {
            if (std.math.isNan(channel.*) or channel.* == 0) {
                channel.* = 0;
            } else if (std.math.isInf(channel.*)) {
                channel.* = std.math.copysign(std.math.floatMax(f64), channel.*);
            }
        }
    }
    // CSS Color 4 §16.5: lowercase color(), numeric components, spaces and
    // an optional non-unit alpha. Six decimal places exceed its precision bar.
    var buffer: [2048]u8 = undefined;
    const prefix = if (settings.space == .limited_srgb) "color(srgb " else "color(display-p3 ";
    @memcpy(buffer[0..prefix.len], prefix);
    var length = prefix.len;
    for (rgb, 0..) |channel, i| {
        if (i != 0) {
            buffer[length] = ' ';
            length += 1;
        }
        length += try component(buffer[length..], channel);
    }
    if (alpha != 1) {
        @memcpy(buffer[length..][0..3], " / ");
        length += 3;
        length += try component(buffer[length..], alpha);
    }
    buffer[length] = ')';
    length += 1;
    return runtime.DOMString.initDupe(allocator, buffer[0..length]);
}

fn component(buffer: []u8, value: f64) !usize {
    // Avoid overflowing the rounding multiplication for very large numbers.
    const rounded = if (@abs(value) < 1e15) @floor(value * 1e6 + 0.5) / 1e6 else value;
    const text = try std.fmt.bufPrint(buffer, "{d:.6}", .{if (rounded == 0) @as(f64, 0) else rounded});
    var length = text.len;
    if (std.mem.indexOfScalar(u8, text, '.') != null) {
        while (length > 0 and text[length - 1] == '0') length -= 1;
        if (length > 0 and text[length - 1] == '.') length -= 1;
    }
    return length;
}

/// Recognize only our own canonical spelling. In limited sRGB, a token
/// must also be a rounded byte/255, so `0.5` is NOT already sanitized.
fn isSerialized(value: []const u8, settings: Settings) bool {
    if (settings.space == .limited_srgb and !settings.alpha) {
        if (value.len != 7 or value[0] != '#') return false;
        for (value[1..]) |c| if (!std.ascii.isDigit(c) and (c < 'a' or c > 'f')) return false;
        return true;
    }
    const prefix = if (settings.space == .limited_srgb) "color(srgb " else "color(display-p3 ";
    if (!std.mem.startsWith(u8, value, prefix) or value[value.len - 1] != ')') return false;
    var tokens = std.mem.splitScalar(u8, value[prefix.len .. value.len - 1], ' ');
    for (0..3) |_| {
        const token = tokens.next() orelse return false;
        const number = canonicalNumber(token) orelse return false;
        if (settings.space == .limited_srgb and !isByteComponent(number)) return false;
    }
    if (tokens.next()) |slash| {
        if (!settings.alpha or !std.mem.eql(u8, slash, "/")) return false;
        const number = canonicalNumber(tokens.next() orelse return false) orelse return false;
        if (number < 0 or number >= 1) return false;
        if (settings.space == .limited_srgb and !isByteComponent(number)) return false;
    }
    return tokens.next() == null;
}

fn isByteComponent(value: f64) bool {
    if (value < 0 or value > 1) return false;
    const byte = @floor(value * 255 + 0.5);
    return value == @floor(byte / 255 * 1e6 + 0.5) / 1e6;
}

fn canonicalNumber(text: []const u8) ?f64 {
    if (text.len == 0) return null;
    var i: usize = if (text[0] == '-') 1 else 0;
    if (i == text.len or !std.ascii.isDigit(text[i])) return null;
    const start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
    if (i - start > 1 and text[start] == '0') return null;
    if (i < text.len) {
        if (text[i] != '.') return null;
        i += 1;
        const fraction = i;
        while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
        if (i == fraction or i - fraction > 6 or text[i - 1] == '0') return null;
    }
    if (i != text.len) return null;
    const value = std.fmt.parseFloat(f64, text) catch return null;
    if (!std.math.isFinite(value) or (value == 0 and text[0] == '-')) return null;
    return value;
}

// Pure HTML-root tests: this module can also reach the CSS parser.
test "P3 conversion censors degenerate channels and the serialization reparses" {
    const testing = std.testing;
    for ([_][]const u8{
        "color(srgb 1e300 0 0)",
        "color(srgb -1e300 0 0)",
        "color(srgb 1e300 -1e300 0)",
    }) |input| {
        var value = try sanitize(testing.allocator, input, .{ .space = .display_p3 });
        defer value.deinit(testing.allocator);
        try testing.expectEqualStrings("color(display-p3 0 0 0)", value.asSlice());
        const parsed = try css.ColorParser.parseWithoutContext(value.asSlice(), testing.allocator);
        for (parsed.rgb) |channel| {
            try testing.expect(std.math.isFinite(channel));
            try testing.expectEqual(@as(f64, 0), channel);
        }
    }
}

test "P3 matrix overflow serializes the implementation limit as CSS numbers" {
    const testing = std.testing;
    // Linear sRGB and XYZ remain finite here; two XYZ-to-P3 products overflow.
    // The CSS parser's reverse conversion is not range-safe at floatMax yet.
    var value = try sanitize(testing.allocator, "color(srgb 2.4e128 2.4e128 2.4e128)", .{ .space = .display_p3 });
    defer value.deinit(testing.allocator);
    const text = value.asSlice();
    try testing.expect(std.mem.indexOf(u8, text, "inf") == null);
    try testing.expect(std.mem.indexOf(u8, text, "nan") == null);
    const prefix = "color(display-p3 ";
    try testing.expect(std.mem.startsWith(u8, text, prefix));
    var channels = std.mem.tokenizeScalar(u8, text[prefix.len .. text.len - 1], ' ');
    for (0..2) |_| {
        const number = try std.fmt.parseFloat(f64, channels.next().?);
        try testing.expectEqual(std.math.floatMax(f64), number);
    }
    try testing.expect(std.math.isFinite(try std.fmt.parseFloat(f64, channels.next().?)));
    try testing.expect(channels.next() == null);
    // Parsing must succeed; finite internal RGB requires the CSS-wide range
    // follow-up for parseWithoutContext, transfer curves and conversion matrices.
    _ = try css.ColorParser.parseWithoutContext(text, testing.allocator);
}
