//! Lane cssprop1 batch 1 (cluster C01b, first part): longhands with their
//! own grammars - Filter Effects 1 §§15.7, 15.10 (flood-color,
//! lighting-color) and 2 §3 (backdrop-filter), Compat §3.4.6 (the
//! -webkit-text-stroke family and -webkit-text-fill-color), Text Size
//! Adjust 1 §2 (text-size-adjust), View Transitions 2 §§3.1, 4.1
//! (view-transition-name, view-transition-class) and Viewport 1 §3.1
//! (zoom): grammar, specified and computed serialization, initial value,
//! inheritance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

fn lookup(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.UnsupportedProperty;
}

fn read(style: *const Style, name: []const u8, out: *std.ArrayList(u8)) !void {
    out.clearRetainingCapacity();
    switch (try lookup(name)) {
        .longhand => |l| try style.serializeResolved(l, out, testing.allocator),
        .shorthand => |s| {
            var assigned: [8]css.properties.Assigned = undefined;
            var resolved: [8]css.style_values.Value = undefined;
            const ls = s.longhands();
            for (ls, 0..) |l, i| {
                const v = style.get(l);
                resolved[i] = if (v == .color) .{ .color = try style.resolvedColor(l, testing.allocator) } else v;
                assigned[i] = .{ .value = resolved[i] };
            }
            defer for (ls, 0..) |l, i| if (style.get(l) == .color) resolved[i].release();
            try testing.expect(try css.properties.serializeShorthand(s, assigned[0..ls.len], .computed, out, testing.allocator));
        },
    }
}

/// `input` is valid: it reads back as `specified` and computes to
/// `computed` on an element whose color is lime.
fn valid(name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings(specified, text.items);
    _ = try block.setProperty(.{ .allocator = allocator }, "color", "lime", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try read(style, name, &text);
    try testing.expectEqualStrings(computed, text.items);
}

fn invalid(name: []const u8, input: []const u8) !void {
    _ = try lookup(name);
    var block = Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings("", text.items);
}

test "flood-color and lighting-color are <color>s computed as colors" {
    try valid("flood-color", "currentcolor", "currentcolor", "rgb(0, 255, 0)");
    try valid("flood-color", "red", "red", "rgb(255, 0, 0)");
    try valid("flood-color", "#00FF00", "rgb(0, 255, 0)", "rgb(0, 255, 0)");
    try valid("flood-color", "transparent", "transparent", "rgba(0, 0, 0, 0)");
    try valid("lighting-color", "rgb(1,2,3)", "rgb(1, 2, 3)", "rgb(1, 2, 3)");
    try valid("lighting-color", "currentColor", "currentcolor", "rgb(0, 255, 0)");
    try valid("lighting-color", "rgba(1, 2, 3, 0.5)", "rgba(1, 2, 3, 0.5)", "rgba(1, 2, 3, 0.5)");
    try invalid("flood-color", "none");
    try invalid("flood-color", "red green");
    try invalid("lighting-color", "1px");
}

test "backdrop-filter shares filter's grammar and computed values" {
    try valid("backdrop-filter", "none", "none", "none");
    try valid("backdrop-filter", "blur(100px)", "blur(100px)", "blur(100px)");
    try valid("backdrop-filter", "brightness(300%)", "brightness(300%)", "brightness(3)");
    try valid("backdrop-filter", "drop-shadow(1px 2px)", "drop-shadow(1px 2px)", "drop-shadow(rgb(0, 255, 0) 1px 2px 0px)");
    try valid("backdrop-filter", "blur(10px) url(\"picture.svg#f\")", "blur(10px) url(\"picture.svg#f\")", "blur(10px) url(\"picture.svg#f\")");
    try invalid("backdrop-filter", "blur(-1px)");
    try invalid("backdrop-filter", "none blur(1px)");
}

fn strokeWidthAt48px(input: []const u8, computed: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "font-size", "48px", "");
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "-webkit-text-stroke-width", input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try read(style, "-webkit-text-stroke-width", &text);
    try testing.expectEqualStrings(computed, text.items);
}

test "the -webkit-text-stroke family and -webkit-text-fill-color" {
    // Chrome and Safari: thin, medium and thick are 1/48, 3/48 and 5/48 em.
    try strokeWidthAt48px("thin", "1px");
    try strokeWidthAt48px("medium", "3px");
    try strokeWidthAt48px("thick", "5px");
    try strokeWidthAt48px("2.5px", "2.5px");
    try strokeWidthAt48px("0.5em", "24px");
    try valid("-webkit-text-stroke-width", "thin", "thin", "0.333333px");
    try invalid("-webkit-text-stroke-width", "-1px");
    try valid("-webkit-text-stroke-color", "red", "red", "rgb(255, 0, 0)");
    try valid("-webkit-text-fill-color", "currentcolor", "currentcolor", "rgb(0, 255, 0)");
    // Compat §3.4.6.4: <line-width> || <color>.
    try valid("-webkit-text-stroke", "green", "0px green", "0px rgb(0, 128, 0)");
    try valid("-webkit-text-stroke", "3px", "3px currentcolor", "3px rgb(0, 255, 0)");
    try valid("-webkit-text-stroke", "red 1px", "1px red", "1px rgb(255, 0, 0)");
    try invalid("-webkit-text-stroke", "1px 2px");
    try invalid("-webkit-text-stroke", "red blue");

    const allocator = testing.allocator;
    const root = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer root.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try read(root, "-webkit-text-stroke-width", &text);
    try testing.expectEqualStrings("0px", text.items);
    for ([_][]const u8{ "-webkit-text-stroke-width", "-webkit-text-stroke-color", "-webkit-text-fill-color" }) |name|
        try testing.expect((try lookup(name)).longhand.inherited());
}

test "text-size-adjust: auto | none | <percentage [0,inf]>, none computing to 100%" {
    try valid("text-size-adjust", "auto", "auto", "auto");
    // Only Chrome ships the unprefixed property, and it computes none to
    // 100% (text-size-adjust-computed.html: Chrome 6/6, Firefox and Safari
    // 0/6, wpt.fyi 2026-11-11): golden rule 2 over Size Adjust 1's
    // "specified keyword or percentage".
    try valid("text-size-adjust", "none", "none", "100%");
    try valid("text-size-adjust", "200%", "200%", "200%");
    try valid("text-size-adjust", "0%", "0%", "0%");
    try valid("text-size-adjust", "calc(10% + 5%)", "calc(15%)", "15%");
    try invalid("text-size-adjust", "0");
    try invalid("text-size-adjust", "10px");
    try invalid("text-size-adjust", "-100%");
    try invalid("text-size-adjust", "reverse");
    try testing.expect((try lookup("text-size-adjust")).longhand.inherited());
}

test "view-transition-name and view-transition-class: custom idents and keywords" {
    try valid("view-transition-name", "none", "none", "none");
    try valid("view-transition-name", "foo", "foo", "foo");
    try valid("view-transition-name", "maTch-element", "match-element", "match-element");
    try valid("view-transition-name", "auto", "auto", "auto");
    try invalid("view-transition-name", "default");
    try invalid("view-transition-name", "none none");
    try invalid("view-transition-name", "foo foo");
    try invalid("view-transition-name", "\"foo\"");
    try invalid("view-transition-name", "12px");
    try valid("view-transition-class", "none", "none", "none");
    try valid("view-transition-class", "foo", "foo", "foo");
    try valid("view-transition-class", "foo bar baz", "foo bar baz", "foo bar baz");
    try invalid("view-transition-class", "foo none");
    try invalid("view-transition-class", "default");
    try invalid("view-transition-class", "foo 12px");
    try invalid("view-transition-class", "#fff");
    for ([_][]const u8{ "view-transition-name", "view-transition-class" }) |name|
        try testing.expect(!(try lookup(name)).longhand.inherited());
}

test "zoom: normal | <number [0,inf]> | <percentage [0,inf]>, computed as a number" {
    try valid("zoom", "normal", "normal", "1");
    try valid("zoom", "1.5", "1.5", "1.5");
    try valid("zoom", "150%", "150%", "1.5");
    try valid("zoom", "0", "0", "1");
    try valid("zoom", "0%", "0%", "1");
    try valid("zoom", "calc(1 - 0.5)", "calc(0.5)", "0.5");
    try valid("zoom", "calc(100% - 50%)", "calc(50%)", "0.5");
    try invalid("zoom", "auto");
    try invalid("zoom", "reset");
    try invalid("zoom", "-1");
    try invalid("zoom", "-100%");
    try testing.expect(!(try lookup("zoom")).longhand.inherited());
}
