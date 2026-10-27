//! The CSS reads and writes the inline formatting commands make
//! (specs/w3c/execCommand.md, "Inline formatting commands"), with no layout:
//!
//! - resolved values: dom.style.computedStyle and the css layer's
//!   ComputedStyle.serializeResolved, the same strings getComputedStyle()
//!   returns (CSSOM "resolved value");
//! - the style attribute: the element's own CSSStyleDeclaration through the
//!   generated interfaces (HTMLElement.style), as a script would;
//! - colors: the css layer's <color> parser ("valid CSS color", the RGBA
//!   components compared by the color commands' equivalent values, and the
//!   simple color serialization <font color> takes);
//! - font sizes: the keyword table and the legacy font size algorithm.
//!
//! Properties are named by string and looked up at run time
//! (css.properties.lookup), so a property the css layer does not support
//! yet reads as unset rather than failing to compile.
//! TODO(row 124): text-decoration has no longhands on this base; until
//! Codex row 124's text-decoration-line lands, every text-decoration read
//! answers "not found" (no fallback).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const css = @import("css");
const common = @import("common.zig");

const Instance = runtime.Instance;
const DOMString = runtime.DOMString;
const ComputedStyle = css.computed_style.ComputedStyle;
const Allocator = std.mem.Allocator;

// ============================================================================
// Resolved values
// ============================================================================

fn computedStyleOf(element: *Instance) ?*const ComputedStyle {
    if (!common.isElement(element)) return null;
    return dom.style.computedStyle(element, null) catch null;
}

/// The resolved value of the longhand `name` on `element`, allocated with
/// `allocator`; "" when the property is unsupported, not a longhand, or the
/// element has no computed style (as getComputedStyle answers then).
pub fn resolved(allocator: Allocator, element: *Instance, name: []const u8) ![]const u8 {
    const style = computedStyleOf(element) orelse return "";
    const property = css.properties.lookup(name) orelse return "";
    const longhand = switch (property) {
        .longhand => |l| l,
        .shorthand => return "",
    };
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try style.serializeResolved(longhand, &out, allocator);
    return try out.toOwnedSlice(allocator);
}

/// Whether the resolved "background-color" of `element` is fully
/// transparent (alpha zero), or the element has no computed style.
pub fn backgroundIsTransparent(allocator: Allocator, element: *Instance) !bool {
    const value = try resolved(allocator, element, "background-color");
    defer if (value.len > 0) allocator.free(value);
    const rgba = parseColor(allocator, value) orelse return value.len == 0;
    return rgba.a == 0;
}

/// Whether `element`'s resolved "display" is exactly "inline".
pub fn displayIsInline(element: *Instance) bool {
    const style = computedStyleOf(element) orelse return false;
    const display = style.display();
    return display.box == .normal and display.outer == .inline_ and display.inner == .flow and !display.list_item;
}

/// Whether the resolved "text-decoration-line" of `element` contains
/// `word` ("underline" or "line-through"): the spec's "the
/// 'text-decoration' property ... has resolved value containing" - the
/// shorthand's resolved value lists the line keywords its longhand holds.
/// False while the css layer has no text-decoration-line (TODO(row 124)).
pub fn textDecorationContains(allocator: Allocator, element: *Instance, word: []const u8) !bool {
    const value = try resolved(allocator, element, "text-decoration-line");
    defer if (value.len > 0) allocator.free(value);
    return containsWord(value, word);
}

/// Whether the space-separated `value` contains the keyword `word`.
pub fn containsWord(value: []const u8, word: []const u8) bool {
    var words = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
    while (words.next()) |w| if (std.ascii.eqlIgnoreCase(w, word)) return true;
    return false;
}

// ============================================================================
// The style attribute
// ============================================================================

/// `element`'s inline CSSStyleDeclaration, or null for an element that is
/// not an HTML element (the commands only write HTML elements' styles).
fn declarationOf(element: *Instance) !?*Instance {
    if (!try common.isHtmlElement(element)) return null;
    return try interfaces.HTMLElement.get_style(element);
}

/// The value the style attribute sets `name` to (a longhand or a
/// shorthand, as CSSStyleDeclaration.getPropertyValue serializes it), or ""
/// when it does not set it. Allocated with `allocator` when non-empty.
pub fn inlineValue(allocator: Allocator, element: *Instance, name: []const u8) ![]const u8 {
    const declaration = (try declarationOf(element)) orelse return "";
    var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(declaration, DOMString.initInterned(name));
    defer value.deinit(element.ctx.allocator);
    if (value.asSlice().len == 0) return "";
    return try allocator.dupe(u8, value.asSlice());
}

/// The number of declarations in the style attribute (longhands, as
/// CSSStyleDeclaration.length counts them).
pub fn inlineCount(element: *Instance) !u32 {
    const declaration = (try declarationOf(element)) orelse return 0;
    return try interfaces.CSSStyleDeclaration.get_length(declaration);
}

/// Whether the style attribute sets exactly one CSS property, `name`: every
/// declaration is `name` itself or one of its longhands, and there is at
/// least one. (The spec counts properties as written; CSSOM expands a
/// shorthand into its longhands, so they are grouped back here.)
pub fn inlineSetsOnly(element: *Instance, name: []const u8) !bool {
    const declaration = (try declarationOf(element)) orelse return false;
    const count = try interfaces.CSSStyleDeclaration.get_length(declaration);
    if (count == 0) return false;
    const property = css.properties.lookup(name) orelse return false;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        var item = try interfaces.CSSStyleDeclaration.call_item(declaration, i);
        defer item.deinit(element.ctx.allocator);
        if (!belongsTo(item.asSlice(), property)) return false;
    }
    return true;
}

fn belongsTo(declared: []const u8, property: css.properties.Property) bool {
    switch (property) {
        .longhand => |l| return std.ascii.eqlIgnoreCase(declared, l.name()),
        .shorthand => |s| {
            if (std.ascii.eqlIgnoreCase(declared, s.name())) return true;
            for (s.longhands()) |l| if (std.ascii.eqlIgnoreCase(declared, l.name())) return true;
            return false;
        },
    }
}

/// Set `name` to `value` in the style attribute (CSSStyleDeclaration
/// setProperty, as `element.style[property] = value` does; an invalid value
/// changes nothing).
pub fn setInline(element: *Instance, name: []const u8, value: []const u8) !void {
    const declaration = (try declarationOf(element)) orelse return;
    try interfaces.CSSStyleDeclaration.call_setProperty(declaration, DOMString.initInterned(name), DOMString.initInterned(value), webidl.Opt(DOMString).notPassed());
}

/// Unset `name` in the style attribute, then drop a style attribute left
/// empty - the reference implementation's `if (getAttribute("style") == "")
/// removeAttribute("style")` after every unset, which the WPT expectations
/// (and the browsers) follow.
pub fn removeInline(element: *Instance, name: []const u8) !void {
    const declaration = (try declarationOf(element)) orelse return;
    var old = try interfaces.CSSStyleDeclaration.call_removeProperty(declaration, DOMString.initInterned(name));
    old.deinit(element.ctx.allocator);
    try dropEmptyStyleAttribute(element);
}

/// Remove a style attribute whose value is the empty string.
pub fn dropEmptyStyleAttribute(element: *Instance) !void {
    var value = (try interfaces.Element.call_getAttribute(element, DOMString.initInterned("style"))) orelse return;
    defer value.deinit(element.ctx.allocator);
    if (value.asSlice().len == 0) try common.removeAttribute(element, "style");
}

// ============================================================================
// Colors
// ============================================================================

pub const Rgba = struct {
    r: u8,
    g: u8,
    b: u8,
    a: f32,

    pub fn eql(self: Rgba, other: Rgba) bool {
        return self.r == other.r and self.g == other.g and self.b == other.b and @abs(self.a - other.a) < 0.002;
    }
};

/// `text` as a valid CSS color, or null when it is not one. currentcolor
/// counts as valid (callers reject it themselves where the spec says so).
pub fn parseColor(allocator: Allocator, text: []const u8) ?Rgba {
    const float = css.color.ColorParser.parseWithoutContext(text, allocator) catch return null;
    const quantized = float.quantize();
    return .{ .r = quantized.r, .g = quantized.g, .b = quantized.b, .a = quantized.a };
}

/// Whether `text` is a valid CSS color.
pub fn isValidColor(allocator: Allocator, text: []const u8) bool {
    return parseColor(allocator, text) != null;
}

/// Whether `text` is the keyword currentcolor (ASCII case-insensitively).
pub fn isCurrentColor(text: []const u8) bool {
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, text, " \t\n\r\x0c"), "currentcolor");
}

/// The color commands' equivalent values: "Either both strings are valid
/// CSS colors and have the same red, green, blue, and alpha components, or
/// neither string is a valid CSS color."
pub fn colorsEquivalent(allocator: Allocator, a: []const u8, b: []const u8) bool {
    const left = parseColor(allocator, a);
    const right = parseColor(allocator, b);
    if (left == null and right == null) return true;
    if (left == null or right == null) return false;
    return left.?.eql(right.?);
}

/// "fully opaque with red, green, and blue components in the range 0 to
/// 255": the rules for serializing simple color values applied to it - a
/// "#rrggbb" in lowercase hex, written into `buffer`; null when `text` is
/// not such a color.
pub fn simpleColor(allocator: Allocator, text: []const u8, buffer: *[7]u8) ?[]const u8 {
    if (isCurrentColor(text)) return null;
    const float = css.color.ColorParser.parseWithoutContext(text, allocator) catch return null;
    if (float.alpha < 1) return null;
    for (float.rgb) |channel| if (channel < 0 or channel > 1) return null;
    const rgba = float.quantize();
    return std.fmt.bufPrint(buffer, "#{x:0>2}{x:0>2}{x:0>2}", .{ rgba.r, rgba.g, rgba.b }) catch null;
}

// ============================================================================
// Font sizes
// ============================================================================

/// The fontSize command's keyword for each legacy size 1-7 (fontSize action
/// step 11; "xxx-large" for 7 is not a CSS keyword before CSS Fonts 4, and
/// force the value writes a <font size=7> for it).
pub const legacy_keywords = [_][]const u8{ "x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large" };

/// The resolved font-size, in pixels, of a <font> whose size attribute is
/// 1-7: the CSS absolute-size keyword it maps to (HTML 15.3.4), at the
/// cascade's keyword sizes for a 16px medium (src/css/cascade.zig: x-small
/// 10, small 13, medium 16, large 18, x-large 24, xx-large 32, xxx-large
/// 48 - the sizes every browser uses).
pub const legacy_size_px = [_]f64{ 10, 13, 16, 18, 24, 32, 48 };

/// The 1-based legacy size of the keyword `text`, or null.
pub fn legacySizeOfKeyword(text: []const u8) ?u8 {
    for (legacy_keywords, 0..) |keyword, i| if (std.mem.eql(u8, text, keyword)) return @intCast(i + 1);
    return null;
}

/// The pixel value of `text` when it is "<number>px", or null.
pub fn parsePx(text: []const u8) ?f64 {
    if (!std.mem.endsWith(u8, text, "px")) return null;
    return std.fmt.parseFloat(f64, text[0 .. text.len - 2]) catch null;
}

/// "legacy font size for" `pixel_size`: the first size 1-6 whose average
/// with the next size's pixels exceeds pixel_size, else 7.
pub fn legacyFontSizeFor(pixel_size: f64) u8 {
    var returned_size: u8 = 1;
    while (returned_size < 7) : (returned_size += 1) {
        const lower_bound = legacy_size_px[returned_size - 1];
        const upper_bound = legacy_size_px[returned_size];
        const average = (lower_bound + upper_bound) / 2;
        if (pixel_size < average) return returned_size;
    }
    return 7;
}

test "legacy font size for pixel sizes" {
    try std.testing.expectEqual(@as(u8, 1), legacyFontSizeFor(10));
    try std.testing.expectEqual(@as(u8, 2), legacyFontSizeFor(13));
    try std.testing.expectEqual(@as(u8, 3), legacyFontSizeFor(16));
    try std.testing.expectEqual(@as(u8, 4), legacyFontSizeFor(17));
    try std.testing.expectEqual(@as(u8, 5), legacyFontSizeFor(24));
    try std.testing.expectEqual(@as(u8, 7), legacyFontSizeFor(48));
    try std.testing.expectEqual(@as(u8, 7), legacyFontSizeFor(100));
}

test "containsWord matches whole keywords" {
    try std.testing.expect(containsWord("underline line-through", "line-through"));
    try std.testing.expect(!containsWord("none", "underline"));
    try std.testing.expect(!containsWord("", "underline"));
}
