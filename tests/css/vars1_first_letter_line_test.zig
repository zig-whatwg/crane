//! The properties that apply to ::first-letter and ::first-line (CSS Pseudo 4
//! 2.2.4 and 2.1.2; lane vars1, integrator ruling (b)): a declaration of any
//! other longhand in a rule for one of them is not applied - the pseudo-
//! element keeps the value it inherits or its initial value, whether the
//! declaration is direct or substituted from var(). Custom properties apply
//! to both. Every other pseudo-element and the element itself take every
//! longhand. Cases from css/css-pseudo/first-letter-allowed-properties.html,
//! first-line-allowed-properties.html and css/css-variables/
//! variable-first-letter.html, variable-first-line.html.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;

/// The originating element's style from `parent_text`, then the style of its
/// `pseudo` from `text`; the caller destroys both.
const Pair = struct {
    element: *ComputedStyle,
    pseudo: *ComputedStyle,

    fn init(parent_text: []const u8, pseudo: ?[]const u8, text: []const u8) !Pair {
        const element = try styleFor(null, null, parent_text);
        errdefer element.destroy();
        return .{ .element = element, .pseudo = try styleFor(element, pseudo, text) };
    }

    fn deinit(self: Pair) void {
        self.pseudo.destroy();
        self.element.destroy();
    }
};

fn styleFor(parent: ?*const ComputedStyle, pseudo: ?[]const u8, text: []const u8) !*ComputedStyle {
    var block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    const matched = [_]cascade_mod.Matched{.{ .block = &block, .source = .{ .origin = .author } }};
    return cascade_mod.cascade(.{ .allocator = testing.allocator, .parent = parent, .is_root = parent == null, .pseudo = pseudo }, &matched);
}

fn expectResolved(style: *const ComputedStyle, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{l.name()});
        return err;
    };
}

const declarations =
    \\position: absolute; float: right; margin-top: 3px; padding-left: 4px;
    \\border-top-style: solid; border-top-width: 2px; color: rgb(10, 20, 30);
    \\font-size: 30px; letter-spacing: 12px; opacity: 0.5; direction: ltr;
    \\z-index: 3; --kept: yes
;

test "::first-letter applies its list and keeps the rest at the inherited or initial value" {
    const pair = try Pair.init("direction: rtl", "first-letter", declarations);
    defer pair.deinit();
    const s = pair.pseudo;
    // Not in 2.2.4's list: position (the bug both pseudo-elements had), z-index,
    // and direction, inherited from the originating element.
    try expectResolved(s, .position, "static");
    try expectResolved(s, .z_index, "auto");
    try expectResolved(s, .direction, "rtl");
    // In it: float (CSS 2.2 5.12.2), margins, paddings, borders, color, fonts,
    // typesetting, opacity.
    try expectResolved(s, .float, "right");
    try expectResolved(s, .margin_top, "3px");
    try expectResolved(s, .padding_left, "4px");
    try expectResolved(s, .border_top_width, "2px");
    try expectResolved(s, .color, "rgb(10, 20, 30)");
    try expectResolved(s, .font_size, "30px");
    try expectResolved(s, .letter_spacing, "12px");
    try expectResolved(s, .opacity, "0.5");
    try testing.expectEqualStrings("yes", s.customValue("--kept").?.bytes);
}

test "::first-line applies its shorter list: no box properties" {
    const pair = try Pair.init("direction: rtl", "first-line", declarations);
    defer pair.deinit();
    const s = pair.pseudo;
    try expectResolved(s, .position, "static");
    try expectResolved(s, .float, "none");
    try expectResolved(s, .margin_top, "0px");
    try expectResolved(s, .padding_left, "0px");
    try expectResolved(s, .border_top_width, "0px");
    try expectResolved(s, .z_index, "auto");
    try expectResolved(s, .direction, "rtl");
    try expectResolved(s, .color, "rgb(10, 20, 30)");
    try expectResolved(s, .font_size, "30px");
    try expectResolved(s, .letter_spacing, "12px");
    try expectResolved(s, .opacity, "0.5");
    try testing.expectEqualStrings("yes", s.customValue("--kept").?.bytes);
}

test "a substituted value is filtered like a direct one (variable-first-letter.html, variable-first-line.html)" {
    inline for (.{ "first-letter", "first-line" }) |pseudo| {
        const pair = try Pair.init("", pseudo,
            \\position: var(--p); --p: absolute;
            \\z-index: var(--z1); --z1: var(--z2); --z2: 4;
            \\color: var(--c); --c: rgb(0, 0, 255)
        );
        defer pair.deinit();
        try expectResolved(pair.pseudo, .position, "static");
        try expectResolved(pair.pseudo, .z_index, "auto");
        try expectResolved(pair.pseudo, .color, "rgb(0, 0, 255)");
        try testing.expectEqualStrings("absolute", pair.pseudo.customValue("--p").?.bytes);
    }
}

test "a shorthand sets only the longhands that apply" {
    const pair = try Pair.init("", "first-line", "margin: 5px; font: italic 20px serif; inset: 1px");
    defer pair.deinit();
    try expectResolved(pair.pseudo, .margin_left, "0px");
    try expectResolved(pair.pseudo, .font_style, "italic");
    try expectResolved(pair.pseudo, .font_size, "20px");
    try expectResolved(pair.pseudo, .top, "auto");
}

test "other pseudo-elements and the element itself take every longhand" {
    inline for (.{ null, "before", "after" }) |pseudo| {
        const pair = try Pair.init("", pseudo, "position: absolute; z-index: 3");
        defer pair.deinit();
        try expectResolved(pair.pseudo, .position, "absolute");
        try expectResolved(pair.pseudo, .z_index, "3");
    }
}
