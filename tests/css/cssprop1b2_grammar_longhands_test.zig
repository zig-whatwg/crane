//! Lane cssprop1 batch 2 (cluster C01b, the rest): longhands and shorthands
//! with their own grammars, each per its definition table - grammar,
//! specified and computed serialization, initial value, inheritance and how
//! it combines:
//! - Masking 1 Appendix A clip: auto | rect(<top>, <right>, <bottom>, <left>);
//! - Sizing 4 §4.1 aspect-ratio (auto || <ratio>, Values 4 §5.7) and §5.2
//!   contain-intrinsic-width/-height/-inline-size/-block-size with their
//!   contain-intrinsic-size shorthand;
//! - Box 4 §3.3 margin-trim;
//! - Anchor Position 2 §2.1 container-type: anchored;
//! - Borders 4 §§3.7-3.8 the corner-*-shape longhands and shorthands, and
//!   §3.9.6 their superellipse interpolation;
//! - Color HDR 1 §3 dynamic-range-limit and dynamic-range-limit-mix();
//! - Scrollbars 1 §§2-3 scrollbar-color and scrollbar-width;
//! - SVG 2 §9.3.2 d and §13.5.6 stroke-dasharray.
//! Expected values are the WPT files' (css/css-masking/parsing/clip-*.html,
//! css/css-sizing/aspect-ratio/parsing/*, css/css-sizing/
//! contain-intrinsic-size/parsing/*, css/css-box/parsing/margin-trim*.html,
//! css/css-anchor-position/container-queries/container-type-anchored-
//! computed.html, css/css-borders/corner-shape/corner-shape-computed.html,
//! css/css-color-hdr/{parsing,computed}.html, css/css-scrollbars/
//! scrollbar-color-parsing.html, web-animations/responsive/{clip,d,
//! strokeDasharray}.html and animation-types/property-types.js).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;
const interpolation = css.interpolation;

fn lookup(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.UnsupportedProperty;
}

fn read(style: *const Style, name: []const u8, out: *std.ArrayList(u8)) !void {
    out.clearRetainingCapacity();
    switch (try lookup(name)) {
        .longhand => |l| try style.serializeResolved(l, out, testing.allocator),
        .shorthand => |s| {
            var assigned: [8]css.properties.Assigned = undefined;
            const ls = s.longhands();
            for (ls, 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
            try testing.expect(try css.properties.serializeShorthand(s, assigned[0..ls.len], .computed, out, testing.allocator));
        },
    }
}

/// `input` is valid: it reads back as `specified` and computes to
/// `computed` on an element whose color is lime and font size 16px.
fn valid(name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, "")) catch |err| {
        std.debug.print("rejected: {s}: {s}\n", .{ name, input });
        return err;
    };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    testing.expectEqualStrings(specified, text.items) catch |err| {
        std.debug.print("specified: {s}: {s}\n", .{ name, input });
        return err;
    };
    _ = try block.setProperty(.{ .allocator = allocator }, "color", "lime", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try read(style, name, &text);
    testing.expectEqualStrings(computed, text.items) catch |err| {
        std.debug.print("computed: {s}: {s}\n", .{ name, input });
        return err;
    };
}

fn invalid(name: []const u8, input: []const u8) !void {
    _ = try lookup(name);
    var block = Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue(name, &text);
    testing.expectEqualStrings("", text.items) catch |err| {
        std.debug.print("accepted: {s}: {s}\n", .{ name, input });
        return err;
    };
}

fn initial(name: []const u8, expected: []const u8, inherited: bool) !void {
    const l = (try lookup(name)).longhand;
    try testing.expectEqual(inherited, l.inherited());
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try read(style, name, &text);
    try testing.expectEqualStrings(expected, text.items);
}

test "clip: auto | rect() of four lengths or autos, computed as absolute lengths" {
    try initial("clip", "auto", false);
    try valid("clip", "auto", "auto", "auto");
    try valid("clip", "rect(10px, 20px, -30px, 40px)", "rect(10px, 20px, -30px, 40px)", "rect(10px, 20px, -30px, 40px)");
    try valid("clip", "rect(10px, -20px, auto, auto)", "rect(10px, -20px, auto, auto)", "rect(10px, -20px, auto, auto)");
    // Masking 1: "may also support separation without commas (but not a
    // combination)"; all three browsers serialize commas.
    try valid("clip", "rect(10px 20px 30px 40px)", "rect(10px, 20px, 30px, 40px)", "rect(10px, 20px, 30px, 40px)");
    try valid("clip", "rect(1em, 2em, AUTO, 0)", "rect(1em, 2em, auto, 0px)", "rect(16px, 32px, auto, 0px)");
    try valid("clip", "rect(10px, 20px, calc(-1em + 10px), 1em)", "rect(10px, 20px, calc(-1em + 10px), 1em)", "rect(10px, 20px, -6px, 16px)");
    try invalid("clip", "rect(10px, 20px 30px, 40px)");
    try invalid("clip", "rect(10%, 0px, 0px, 0px)");
    try invalid("clip", "rect(1px, 2px, 3px)");
    try invalid("clip", "rect(1px, 2px, 3px, 4px, 5px)");
    try invalid("clip", "rect(auto)");
    try invalid("clip", "none");
    try invalid("clip", "inset(1px)");
}

test "aspect-ratio: auto || <ratio>, both numbers always serialized" {
    try initial("aspect-ratio", "auto", false);
    try valid("aspect-ratio", "auto", "auto", "auto");
    try valid("aspect-ratio", "1", "1 / 1", "1 / 1");
    try valid("aspect-ratio", "16/9", "16 / 9", "16 / 9");
    try valid("aspect-ratio", "16.3 / 9.5", "16.3 / 9.5", "16.3 / 9.5");
    try valid("aspect-ratio", "0 / 0", "0 / 0", "0 / 0");
    try valid("aspect-ratio", "auto 1", "auto 1 / 1", "auto 1 / 1");
    try valid("aspect-ratio", "16 auto", "auto 16 / 1", "auto 16 / 1");
    try valid("aspect-ratio", "0 auto", "auto 0 / 1", "auto 0 / 1");
    try valid("aspect-ratio", "calc(1 + 1) / 4", "calc(2) / 4", "2 / 4");
    try invalid("aspect-ratio", "-1");
    try invalid("aspect-ratio", "1 / -1");
    try invalid("aspect-ratio", "auto auto");
    try invalid("aspect-ratio", "1 / 2 / 3");
    try invalid("aspect-ratio", "1 /");
    try invalid("aspect-ratio", "auto 16 /");
    try invalid("aspect-ratio", "auto 1 / auto");
    try invalid("aspect-ratio", "auto 1 auto");
    try invalid("aspect-ratio", "1px");
    try invalid("aspect-ratio", "none");
}

test "contain-intrinsic-*: auto? [none | <length [0,inf]>], and the shorthand" {
    for ([_][]const u8{ "contain-intrinsic-width", "contain-intrinsic-height" }) |name| try initial(name, "none", false);
    try valid("contain-intrinsic-width", "none", "none", "none");
    try valid("contain-intrinsic-width", "1px", "1px", "1px");
    try valid("contain-intrinsic-width", "2em", "2em", "32px");
    try valid("contain-intrinsic-width", "auto 1px", "auto 1px", "auto 1px");
    try valid("contain-intrinsic-height", "auto none", "auto none", "auto none");
    try valid("contain-intrinsic-block-size", "auto 2em", "auto 2em", "auto 32px");
    try valid("contain-intrinsic-inline-size", "1px", "1px", "1px");
    try invalid("contain-intrinsic-width", "-1px");
    try invalid("contain-intrinsic-width", "auto");
    try invalid("contain-intrinsic-width", "none auto");
    try invalid("contain-intrinsic-width", "10%");
    try invalid("contain-intrinsic-width", "1px 2px");
    try invalid("contain-intrinsic-height", "auto auto 1px");
    // Sizing 4 §5.2: width then height, an equal pair as one value.
    try valid("contain-intrinsic-size", "none", "none", "none");
    try valid("contain-intrinsic-size", "5px 5px", "5px", "5px");
    try valid("contain-intrinsic-size", "none none", "none", "none");
    try valid("contain-intrinsic-size", "1px none", "1px none", "1px none");
    try valid("contain-intrinsic-size", "auto 1px auto 1px", "auto 1px", "auto 1px");
    try valid("contain-intrinsic-size", "1px auto 1px", "1px auto 1px", "1px auto 1px");
    try valid("contain-intrinsic-size", "auto 1px 1px", "auto 1px 1px", "auto 1px 1px");
    try valid("contain-intrinsic-size", "2em 3px", "2em 3px", "32px 3px");
    try invalid("contain-intrinsic-size", "1px 2px 3px");
    try invalid("contain-intrinsic-size", "auto");
}

test "margin-trim: none | block | [ block-start || block-end ], the pair as block" {
    try initial("margin-trim", "none", false);
    try valid("margin-trim", "none", "none", "none");
    try valid("margin-trim", "block", "block", "block");
    try valid("margin-trim", "block-start", "block-start", "block-start");
    try valid("margin-trim", "block-end", "block-end", "block-end");
    try valid("margin-trim", "block-start block-end", "block", "block");
    try valid("margin-trim", "block-end block-start", "block", "block");
    for ([_][]const u8{ "block block", "block block-start block-end", "block-start block-start", "none block", "inline", "inline-start", "block inline", "block-start inline-start", "auto", "block 10px" }) |input|
        try invalid("margin-trim", input);
}

test "container-type: anchored alone or with the size and scroll-state types" {
    try valid("container-type", "anchored", "anchored", "anchored");
    try valid("container-type", "anchored size", "size anchored", "size anchored");
    try valid("container-type", "inline-size anchored", "inline-size anchored", "inline-size anchored");
    try valid("container-type", "anchored scroll-state inline-size", "inline-size scroll-state anchored", "inline-size scroll-state anchored");
    try invalid("container-type", "anchored anchored");
    try invalid("container-type", "normal anchored");
}

test "corner-*-shape: keywords and superellipse(), computed as superellipse()" {
    for ([_][]const u8{ "corner-top-left-shape", "corner-top-right-shape", "corner-bottom-right-shape", "corner-bottom-left-shape" }) |name|
        try initial(name, "superellipse(1)", false);
    try valid("corner-top-left-shape", "round", "round", "superellipse(1)");
    try valid("corner-top-left-shape", "scoop", "scoop", "superellipse(-1)");
    try valid("corner-top-left-shape", "bevel", "bevel", "superellipse(0)");
    try valid("corner-top-left-shape", "notch", "notch", "superellipse(-infinity)");
    try valid("corner-top-left-shape", "square", "square", "superellipse(infinity)");
    try valid("corner-top-left-shape", "squircle", "squircle", "superellipse(2)");
    try valid("corner-top-left-shape", "superellipse(5)", "superellipse(5)", "superellipse(5)");
    try valid("corner-top-left-shape", "superellipse(0.2)", "superellipse(0.2)", "superellipse(0.2)");
    try valid("corner-top-left-shape", "superellipse( -1)", "superellipse(-1)", "superellipse(-1)");
    try valid("corner-top-left-shape", "superellipse(infinity)", "superellipse(infinity)", "superellipse(infinity)");
    try valid("corner-top-left-shape", "superellipse(-infinity)", "superellipse(-infinity)", "superellipse(-infinity)");
    try valid("corner-bottom-left-shape", "superellipse(calc(1 + 2))", "superellipse(calc(3))", "superellipse(3)");
    for ([_][]const u8{ "superellipse()", "superellipse(1px)", "superellipse(1, 2)", "round round", "superellipse(inf)", "none", "1" }) |input|
        try invalid("corner-top-left-shape", input);
    // §3.8.2: top-left, top-right, bottom-right, bottom-left, as border-radius.
    try valid("corner-shape", "round", "round", "superellipse(1)");
    try valid("corner-shape", "superellipse(5) round", "superellipse(5) round", "superellipse(5) superellipse(1)");
    try valid("corner-shape", "bevel superellipse(0.1) round squircle", "bevel superellipse(0.1) round squircle", "superellipse(0) superellipse(0.1) superellipse(1) superellipse(2)");
    try valid("corner-shape", "round round round round", "round", "superellipse(1)");
    try valid("corner-shape", "superellipse(-1) superellipse(3) square", "superellipse(-1) superellipse(3) square", "superellipse(-1) superellipse(3) superellipse(infinity)");
    try valid("corner-shape", "bevel superellipse(1) squircle round", "bevel superellipse(1) squircle round", "superellipse(0) superellipse(1) superellipse(2)");
    try invalid("corner-shape", "round round round round round");
    // §3.8.1: a side's two corners.
    try valid("corner-top-shape", "round scoop", "round scoop", "superellipse(1) superellipse(-1)");
    try valid("corner-left-shape", "round scoop", "round scoop", "superellipse(1) superellipse(-1)");
    try valid("corner-bottom-shape", "scoop scoop", "scoop", "superellipse(-1)");
    try valid("corner-right-shape", "superellipse(-1.5) superellipse(3)", "superellipse(-1.5) superellipse(3)", "superellipse(-1.5) superellipse(3)");
    try valid("corner-block-start-shape", "round scoop", "round scoop", "superellipse(1) superellipse(-1)");
    try valid("corner-inline-start-shape", "round scoop", "round scoop", "superellipse(1) superellipse(-1)");
    try valid("corner-inline-end-shape", "superellipse(-1.5) superellipse(3)", "superellipse(-1.5) superellipse(3)", "superellipse(-1.5) superellipse(3)");
    try valid("corner-block-end-shape", "scoop scoop", "scoop", "superellipse(-1)");
}

test "the flow-relative corner shapes map onto the physical corners by writing mode" {
    const allocator = testing.allocator;
    const Case = struct { mode: []const u8, direction: []const u8, physical: []const u8 };
    // Borders 4 §3.7: corner-`block`-`inline`-shape.
    const cases = [_]Case{
        .{ .mode = "horizontal-tb", .direction = "ltr", .physical = "corner-top-left-shape" },
        .{ .mode = "horizontal-tb", .direction = "rtl", .physical = "corner-top-right-shape" },
        .{ .mode = "vertical-rl", .direction = "ltr", .physical = "corner-top-right-shape" },
        .{ .mode = "vertical-lr", .direction = "rtl", .physical = "corner-bottom-left-shape" },
    };
    for (cases) |case| {
        var block = Block.init(allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = allocator }, "writing-mode", case.mode, "");
        _ = try block.setProperty(.{ .allocator = allocator }, "direction", case.direction, "");
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "corner-start-start-shape", "scoop", ""));
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try read(style, case.physical, &text);
        try testing.expectEqualStrings("superellipse(-1)", text.items);
        try read(style, "corner-start-start-shape", &text);
        try testing.expectEqualStrings("superellipse(-1)", text.items);
    }
}

test "dynamic-range-limit: keywords and dynamic-range-limit-mix(), normalized when computed" {
    try initial("dynamic-range-limit", "no-limit", true);
    for ([_][]const u8{ "standard", "no-limit", "constrained" }) |k| try valid("dynamic-range-limit", k, k, k);
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 80%, standard 20%)", "dynamic-range-limit-mix(no-limit 80%, standard 20%)", "dynamic-range-limit-mix(standard 20%, no-limit 80%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(80% no-limit, standard 20%)", "dynamic-range-limit-mix(no-limit 80%, standard 20%)", "dynamic-range-limit-mix(standard 20%, no-limit 80%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 100%, standard 0%)", "dynamic-range-limit-mix(no-limit 100%, standard 0%)", "no-limit");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 100%, standard 100%)", "dynamic-range-limit-mix(no-limit 100%, standard 100%)", "dynamic-range-limit-mix(standard 50%, no-limit 50%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 80%, standard 60%, constrained 60%)", "dynamic-range-limit-mix(no-limit 80%, standard 60%, constrained 60%)", "dynamic-range-limit-mix(standard 30%, constrained 30%, no-limit 40%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 25%, standard 25%, standard 25%, standard 25%)", "dynamic-range-limit-mix(no-limit 25%, standard 25%, standard 25%, standard 25%)", "dynamic-range-limit-mix(standard 75%, no-limit 25%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(dynamic-range-limit-mix(standard 10%, no-limit 30%) 20%, standard 80%)", "dynamic-range-limit-mix(dynamic-range-limit-mix(standard 10%, no-limit 30%) 20%, standard 80%)", "dynamic-range-limit-mix(standard 85%, no-limit 15%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(no-limit 10%, dynamic-range-limit-mix(standard 25%, constrained 75%) 20%, dynamic-range-limit-mix(constrained 10%, no-limit 30%) 20%)", "dynamic-range-limit-mix(no-limit 10%, dynamic-range-limit-mix(standard 25%, constrained 75%) 20%, dynamic-range-limit-mix(constrained 10%, no-limit 30%) 20%)", "dynamic-range-limit-mix(standard 10%, constrained 40%, no-limit 50%)");
    try valid("dynamic-range-limit", "dynamic-range-limit-mix(standard calc(50% * sign(10em - 1px)), constrained 50%)", "dynamic-range-limit-mix(standard calc(50% * sign(10em - 1px)), constrained 50%)", "dynamic-range-limit-mix(standard 50%, constrained 50%)");
    for ([_][]const u8{
        "dynamic-range-limit-mix(no-limit 80%, standard 20%, )",
        "dynamic-range-limit-mix(no-limit, standard 20%)",
        "dynamic-range-limit-mix(no-limit 1%)",
        "dynamic-range-limit-mix(no-limit 80% standard 20%)",
        "dynamic-range-limit-mix(no-limit 101%, standard 1%)",
        "dynamic-range-limit-mix(no-limit -1%, standard 1%)",
        "dynamic-range-limit-mix(no-limit 0%, standard 0%)",
        "dynamic-range-limit-mix(dynamic-range-limit-mix(no-limit 1%, standard 2%) 3%, dynamic-range-limit-mix(constrained 0%, no-limit 0%) 6%)",
        "none",
        "high",
    }) |input| try invalid("dynamic-range-limit", input);
}

test "scrollbar-color: auto | <color>{2}; scrollbar-width: auto | thin | none" {
    try initial("scrollbar-color", "auto", true);
    try valid("scrollbar-color", "auto", "auto", "auto");
    try valid("scrollbar-color", "red green", "red green", "rgb(255, 0, 0) rgb(0, 128, 0)");
    try valid("scrollbar-color", "#FF0000 #00FF00", "rgb(255, 0, 0) rgb(0, 255, 0)", "rgb(255, 0, 0) rgb(0, 255, 0)");
    try valid("scrollbar-color", "currentcolor currentcolor", "currentcolor currentcolor", "rgb(0, 255, 0) rgb(0, 255, 0)");
    for ([_][]const u8{ "auto auto", "auto currentcolor", "red", "red green blue", "none" }) |input| try invalid("scrollbar-color", input);
    try initial("scrollbar-width", "auto", false);
    for ([_][]const u8{ "auto", "thin", "none" }) |k| try valid("scrollbar-width", k, k, k);
    try invalid("scrollbar-width", "thick");
    try invalid("scrollbar-width", "1px");
}

test "d: none | path(<string>), the path data canonicalized" {
    try initial("d", "none", false);
    try valid("d", "none", "none", "none");
    try valid("d", "path(\"M 0 0 H 100\")", "path(\"M 0 0 H 100\")", "path(\"M 0 0 H 100\")");
    try valid("d", "path('m 10 20 h 5')", "path(\"m 10 20 h 5\")", "path(\"m 10 20 h 5\")");
    for ([_][]const u8{ "path(evenodd, \"M 0 0\")", "\"M 0 0\"", "path(\"\")", "path(\"L 1 1\")", "circle(1px)" }) |input| try invalid("d", input);
}

test "stroke-dasharray: none | <dasharray>, numbers computed to px" {
    try initial("stroke-dasharray", "none", true);
    try valid("stroke-dasharray", "none", "none", "none");
    try valid("stroke-dasharray", "10 20", "10, 20", "10px, 20px");
    try valid("stroke-dasharray", "10px, 20%", "10px, 20%", "10px, 20%");
    try valid("stroke-dasharray", "1em 2, 3", "1em, 2, 3", "16px, 2px, 3px");
    try valid("stroke-dasharray", "1 2 3 4 5 6", "1, 2, 3, 4, 5, 6", "1px, 2px, 3px, 4px, 5px, 6px");
    for ([_][]const u8{ "-1", "10,", ", 10", "10,,20", "10 -2", "red" }) |input| try invalid("stroke-dasharray", input);
}

// ---------------------------------------------------------------------------
// Combination (Values 4 §3, Web Animations 1 §5.2): both endpoints computed
// through the cascade, combined, fed back as a typed declaration (as the
// animation origin does) and read as the resolved value.

const Op = enum { interpolate, add };

fn computeOne(allocator: Allocator, name: []const u8, text: []const u8) !*Style {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, text, "")) return error.Rejected;
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn combined(op: Op, name: []const u8, from: []const u8, to: []const u8, p: f64, expected: []const u8) !void {
    const allocator = testing.allocator;
    const l = (try lookup(name)).longhand;
    const a = try computeOne(allocator, name, from);
    defer a.destroy();
    const b = try computeOne(allocator, name, to);
    defer b.destroy();
    const raw = switch (op) {
        .interpolate => try interpolation.interpolate(allocator, l, a.get(l), b.get(l), p),
        .add => try interpolation.add(allocator, l, a.get(l), b.get(l)),
    };
    const result = interpolation.clampFinal(l, raw);
    var block = Block.init(allocator);
    defer block.deinit();
    block.entries.append(allocator, .{ .typed = .{ .longhand = l, .value = .{ .value = result }, .important = false } }) catch |err| {
        result.release();
        return err;
    };
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("case: {s} {s} {s} -> {s} at {d}\n", .{ @tagName(op), name, from, to, p });
        return err;
    };
}

test "clip, contain-intrinsic-*, scrollbar-color and aspect-ratio combine component by component" {
    try combined(.interpolate, "clip", "rect(10px, 10px, 10px, 10px)", "rect(50px, 50px, 50px, 50px)", 0.5, "rect(30px, 30px, 30px, 30px)");
    try combined(.interpolate, "clip", "rect(10px, 20px, 30px, auto)", "rect(410px, 420px, 30px, auto)", 0.75, "rect(310px, 320px, 30px, auto)");
    // An auto against a length, or auto against rect(), is discrete.
    try combined(.interpolate, "clip", "rect(10px, 10px, 10px, 10px)", "rect(10px, 10px, 10px, auto)", 0.25, "rect(10px, 10px, 10px, 10px)");
    try combined(.interpolate, "clip", "auto", "rect(10px, 10px, 10px, 10px)", 0.75, "rect(10px, 10px, 10px, 10px)");
    try combined(.add, "clip", "rect(100px, 100px, 100px, 100px)", "rect(10px, 10px, 10px, 10px)", 0, "rect(110px, 110px, 110px, 110px)");
    try combined(.interpolate, "contain-intrinsic-width", "auto 10px", "auto 30px", 0.5, "auto 20px");
    try combined(.interpolate, "contain-intrinsic-width", "10px", "30px", 1.5, "40px");
    try combined(.interpolate, "contain-intrinsic-width", "auto 10px", "auto 30px", -1, "auto 0px");
    try combined(.interpolate, "contain-intrinsic-width", "auto 10px", "30px", 0.25, "auto 10px");
    try combined(.interpolate, "scrollbar-color", "rgb(255, 0, 0) rgb(0, 0, 255)", "rgb(0, 0, 255) rgb(0, 255, 0)", 0.5, "rgb(128, 0, 128) rgb(0, 128, 128)");
    try combined(.interpolate, "scrollbar-color", "#ff000066 #ff000066", "#0000ffcc #00ff00cc", 0.5, "rgba(85, 0, 170, 0.6) rgba(85, 170, 0, 0.6)");
    try combined(.interpolate, "scrollbar-color", "auto", "red blue", 0.25, "auto");
    // Values 4 §5.7.1: the logarithm of the ratio; never additive.
    try combined(.interpolate, "aspect-ratio", "1 / 1", "4 / 1", 0.5, "2 / 1");
    try combined(.interpolate, "aspect-ratio", "auto 1 / 4", "auto 4 / 1", 0.5, "auto 1 / 1");
    try combined(.interpolate, "aspect-ratio", "auto 1 / 1", "4 / 1", 0.25, "auto 1 / 1");
    try combined(.interpolate, "aspect-ratio", "0 / 1", "4 / 1", 0.25, "0 / 1");
    try combined(.add, "aspect-ratio", "2 / 1", "3 / 1", 0, "3 / 1");
}

test "corner shapes interpolate in normalized half-corner space" {
    try combined(.interpolate, "corner-top-left-shape", "round", "round", 0.5, "superellipse(1)");
    try combined(.interpolate, "corner-top-left-shape", "scoop", "round", 0.5, "superellipse(0)");
    try combined(.interpolate, "corner-top-left-shape", "bevel", "square", 1.5, "superellipse(infinity)");
    try combined(.interpolate, "corner-top-left-shape", "bevel", "notch", 1.5, "superellipse(-infinity)");
    try combined(.interpolate, "corner-top-left-shape", "superellipse(2)", "superellipse(2)", 0.3, "superellipse(2)");
    try combined(.add, "corner-top-left-shape", "round", "squircle", 0, "superellipse(2)");
}

test "dynamic-range-limit interpolates as a dynamic-range-limit-mix()" {
    try combined(.interpolate, "dynamic-range-limit", "standard", "no-limit", 0.25, "dynamic-range-limit-mix(standard 75%, no-limit 25%)");
    try combined(.interpolate, "dynamic-range-limit", "standard", "no-limit", 1, "no-limit");
    try combined(.interpolate, "dynamic-range-limit", "dynamic-range-limit-mix(standard 50%, constrained 50%)", "constrained", 0.5, "dynamic-range-limit-mix(standard 25%, constrained 75%)");
}

test "stroke-dasharray is a repeatable list, neither additive nor cumulative; d interpolates its path" {
    try combined(.interpolate, "stroke-dasharray", "8, 16, 4", "4, 8, 12, 16", 0.5, "6px, 12px, 8px, 12px, 10px, 6px, 10px, 16px, 4px, 8px, 14px, 10px");
    try combined(.interpolate, "stroke-dasharray", "2, 50%, 6, 10", "6, 30%, 2, 2", 0.5, "4px, 40%, 4px, 6px");
    try combined(.interpolate, "stroke-dasharray", "none", "10px, 20px", 0.25, "none");
    try combined(.add, "stroke-dasharray", "6, 30%, 2px", "1, 2, 3, 4, 5", 0, "1px, 2px, 3px, 4px, 5px");
    try combined(.interpolate, "d", "path(\"M 0 0 H 100\")", "path(\"M 0 0 H 400\")", 0.5, "path(\"M 0 0 H 250\")");
}

test "the d presentation attribute is the d property's path()" {
    const p = css.svg_presentation;
    var out: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (out.items) |assignment| assignment.value.release();
        out.deinit(testing.allocator);
    }
    const options: css.properties.ParseOptions = .{ .allocator = testing.allocator };
    try testing.expect(try p.parse(options, p.svg_namespace, "path", "d", "M 0 0 L 10 \"20\"", &out) == false);
    try testing.expect(try p.parse(options, p.svg_namespace, "path", "d", "m0,0 l10,20z", &out));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try css.properties.serializeValue((try lookup("d")).longhand, out.items[0].value.value, &text, testing.allocator);
    try testing.expectEqualStrings("path(\"m 0 0 l 10 20 Z\")", text.items);
    try testing.expect(!try p.parse(options, p.svg_namespace, "rect", "d", "M 0 0", &out));
}

test "a scrollbar-color pair is clipped only as the final value" {
    // property-types.js colorPairType "overflowed from and to values":
    // rgb(128, 128, 128) rgb(0, 0, 0) underlying, each keyframe added onto
    // it, the halfway point clipped at the end.
    const allocator = testing.allocator;
    const l = (try lookup("scrollbar-color")).longhand;
    const underlying = try computeOne(allocator, "scrollbar-color", "rgb(128, 128, 128) rgb(0, 0, 0)");
    defer underlying.destroy();
    const from = try computeOne(allocator, "scrollbar-color", "rgb(255, 0, 0) rgb(0, 0, 255)");
    defer from.destroy();
    const to = try computeOne(allocator, "scrollbar-color", "rgb(0, 0, 255) rgb(255, 0, 0)");
    defer to.destroy();
    const a = try interpolation.add(allocator, l, underlying.get(l), from.get(l));
    defer a.release();
    const b = try interpolation.add(allocator, l, underlying.get(l), to.get(l));
    defer b.release();
    const result = interpolation.clampFinal(l, try interpolation.interpolate(allocator, l, a, b, 0.5));
    defer result.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(l, result, &out, allocator);
    try testing.expectEqualStrings("rgb(255, 128, 255) rgb(128, 0, 128)", out.items);
}
