//! Row 118 follow-up: value grammar, resolved subgrids and Color owner APIs.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const allocator = testing.allocator;
const Color = css.style_values.Color;
const Style = css.computed_style.ComputedStyle;

fn style(text: []const u8, parent: ?*const Style) !*Style {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn property(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const p = css.properties.lookup(name) orelse return error.MissingFollowupProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |expected| {
        const result = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer result.destroy();
        try resolved(result, p.longhand, expected);
    }
}

fn resolved(value: *const Style, name: css.properties.Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try value.serializeResolved(name, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "follow-up position visibility accepts aliases and serializes grammar order" {
    // Anchor Position 1 §6.6; Q30: singular canonical values, plural aliases.
    inline for (.{
        .{ "always", "always" },
        .{ "anchor-valid", "anchor-valid" },
        .{ "ANCHOR-VISIBLE", "anchor-visible" },
        .{ "anchors-valid", "anchor-valid" },
        .{ "anchors-visible", "anchor-visible" },
        .{ "no-overflow", "no-overflow" },
        .{ "no-overflow anchors-visible anchor-valid", "anchor-valid anchor-visible no-overflow" },
        .{ "anchor-visible no-overflow", "anchor-visible no-overflow" },
        .{ "no-overflow anchor-valid", "anchor-valid no-overflow" },
        .{ "anchor-visible anchor-valid", "anchor-valid anchor-visible" },
        .{ "anchor-\\76 isible", "anchor-visible" },
    }) |case| try property("position-visibility", case[0], case[1], case[1]);
    for ([_][]const u8{ "", "normal", "always anchor-valid", "anchor-valid anchor-valid", "anchor-valid anchors-valid", "anchors-visible anchor-visible", "no-overflow no-overflow", "anchor-valid,anchor-visible", "anchor-valid garbage" }) |input|
        try property("position-visibility", input, "", null);
}

test "follow-up interpolate size grammar and the two longhands inheritance" {
    // Values 5 §11.3: inherited, computed as specified.
    try property("interpolate-size", "NUMERIC-ONLY", "numeric-only", "numeric-only");
    try property("interpolate-size", "allow-keywords", "allow-keywords", "allow-keywords");
    for ([_][]const u8{ "auto", "none", "numeric-only allow-keywords", "allow-keywords, numeric-only", "allow-keywords garbage" }) |input|
        try property("interpolate-size", input, "", null);
    const pv = (css.properties.lookup("position-visibility") orelse return error.MissingFollowupProperty).longhand;
    const size = (css.properties.lookup("interpolate-size") orelse return error.MissingFollowupProperty).longhand;
    const parent = try style("position-visibility:always;interpolate-size:allow-keywords", null);
    defer parent.destroy();
    const child = try style("", parent);
    defer child.destroy();
    try resolved(child, pv, "anchor-visible");
    try resolved(child, size, "allow-keywords");
    const inherited = try style("position-visibility:inherit;interpolate-size:initial", parent);
    defer inherited.destroy();
    try resolved(inherited, pv, "always");
    try resolved(inherited, size, "numeric-only");
}

fn subgrid(parent_text: ?[]const u8, child_text: []const u8, expected: []const u8) !void {
    const parent = if (parent_text) |text| try style(text, null) else null;
    defer if (parent) |p| p.destroy();
    const child = try style(child_text, parent);
    defer child.destroy();
    for ([_]css.properties.Longhand{ .grid_template_columns, .grid_template_rows }) |longhand| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeValue(longhand, child.get(longhand), &out, allocator);
        // Grid 2 §§7.2.5–7.2.6/9: the computed list is never rewritten.
        try testing.expectEqualStrings("subgrid [a]", out.items);
        try resolved(child, longhand, expected);
    }
}
const subgrid_text = "grid-template-columns:subgrid [a];grid-template-rows:subgrid [a];";

test "follow-up invalid subgrid resolves none without changing computed tracks" {
    try subgrid(null, subgrid_text ++ "display:grid", "none");
    try subgrid("display:block", subgrid_text ++ "display:grid", "none");
    try subgrid("display:flex", subgrid_text ++ "display:inline-grid", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;position:absolute", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;position:fixed", "none");
}

test "follow-up containment makes subgrid independent while ordinary grid stays eligible" {
    try subgrid("display:grid", subgrid_text ++ "display:grid;contain:layout", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;contain:content", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;contain:strict", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;contain:paint", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;content-visibility:auto", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid;content-visibility:hidden", "none");
    try subgrid("display:grid", subgrid_text ++ "display:grid", "subgrid [a]");
    try subgrid("display:grid", subgrid_text ++ "display:grid;contain:style", "subgrid [a]");
    try subgrid("display:block", subgrid_text ++ "display:none", "subgrid [a]");
    try subgrid("display:block", subgrid_text ++ "display:block", "subgrid [a]");
}

test "follow-up contain grammar has canonical specified and computed forms" {
    // Contain 2 §2: strict/content compute to component sets; CSSOM uses
    // their shorter keyword spellings for the computed value (pinned WPT).
    inline for (.{
        .{ "none", "none", "none" },
        .{ "STRICT", "strict", "strict" },
        .{ "content", "content", "content" },
        .{ "layout size", "size layout", "size layout" },
        .{ "paint style", "style paint", "style paint" },
        .{ "paint layout style", "layout style paint", "content" },
        .{ "paint layout style size", "size layout style paint", "strict" },
        .{ "inline-size", "inline-size", "inline-size" },
        .{ "paint inline-size style layout", "inline-size layout style paint", "inline-size layout style paint" },
        .{ "size layout paint", "size layout paint", "size layout paint" },
    }) |case| try property("contain", case[0], case[1], case[2]);
    for ([_][]const u8{ "auto", "layout layout", "none paint", "strict layout", "content size", "size inline-size", "inline-size inline-size", "paint, style", "paint junk" }) |input|
        try property("contain", input, "", null);
    const p = (css.properties.lookup("contain") orelse return error.MissingContainProperty).longhand;
    const parent = try style("contain:strict", null);
    defer parent.destroy();
    const child = try style("", parent);
    defer child.destroy();
    try resolved(child, p, "none");
}

test "follow-up display contents preserves the grid parent without retaining styles" {
    const grandparent = try style("display:grid", null);
    const parent = try style("display:contents", grandparent);
    grandparent.destroy();
    const child = try style(subgrid_text ++ "display:grid", parent);
    parent.destroy();
    defer child.destroy();
    try resolved(child, .grid_template_columns, "subgrid [a]");
    const hidden = try style("display:none", null);
    defer hidden.destroy();
    const below_hidden = try style(subgrid_text ++ "display:grid", hidden);
    defer below_hidden.destroy();
    try resolved(below_hidden, .grid_template_columns, "subgrid [a]");
}

test "follow-up transparent declared spelling and background reset stay distinct" {
    // Color 4 §§15.5/16.2; user Q86 chooses the initial keyword spelling.
    try property("background-color", "transparent", "transparent", "rgba(0, 0, 0, 0)");
    try property("background-color", "rgba(0, 0, 0, 0)", "rgba(0, 0, 0, 0)", "rgba(0, 0, 0, 0)");
    for ([_][]const u8{ "none", "border-box content-box" }) |input| {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = allocator }, "background-color", "red", "");
        _ = try block.setProperty(.{ .allocator = allocator }, "background", input, "");
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try block.getPropertyValue("background-color", &out);
        try testing.expectEqualStrings("transparent", out.items);
    }
    var initial: std.ArrayList(u8) = .empty;
    defer initial.deinit(allocator);
    try css.properties.Longhand.background_color.info().initial.color.serializeSpecified(&initial, allocator);
    try testing.expectEqualStrings("transparent", initial.items);
    // The allocation-free initial computed-style table must still contain
    // computed RGBA, rather than the declared keyword representation.
    const empty = try Style.initial(allocator);
    defer empty.destroy();
    try testing.expect(empty.get(.background_color).color == .rgba);
    try resolved(empty, .background_color, "rgba(0, 0, 0, 0)");
}

fn parsedColor(input: []const u8) !Color {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "color", input, "");
    const declaration = block.get(.color) orelse return error.InvalidColorTestInput;
    const result = declaration.value.value.color;
    result.retain();
    return result;
}

test "follow-up currentcolor query traverses every color expression variant" {
    if (comptime !@hasDecl(Color, "containsCurrentColor")) return error.MissingCurrentColorQuery;
    try testing.expect(!Color.transparent.containsCurrentColor());
    try testing.expect(!Color.black.containsCurrentColor());
    for ([_][]const u8{
        "currentcolor",                                                                           "rgb(from currentcolor r g b)",
        "color-mix(in srgb,red,currentcolor)",                                                    "light-dark(red,currentcolor)",
        "contrast-color(currentcolor)",                                                           "alpha(from currentcolor / .5)",
        "rgb(from color-mix(in srgb, red, alpha(from contrast-color(currentcolor) / .5)) r g b)", "light-dark(contrast-color(alpha(from currentcolor / .5)),blue)",
    }) |input| {
        const color = try parsedColor(input);
        defer color.release();
        try testing.expect(color.containsCurrentColor());
    }
    for ([_][]const u8{
        "transparent",                  "red",                  "CanvasText",           "rgb(12, 34, 56)",
        "color(display-p3 .1 .2 .3)",   "lab(40% 20 30)",       "oklch(.4 .2 120)",     "rgb(from red calc(r / 2) g b)",
        "color-mix(in oklab,red,blue)", "light-dark(red,blue)", "contrast-color(blue)", "alpha(from red / .5)",
    }) |input| {
        const color = try parsedColor(input);
        defer color.release();
        try testing.expect(!color.containsCurrentColor());
    }
}

test "follow-up currentcolor query observes only the selected computed light dark branch" {
    if (comptime !@hasDecl(Color, "containsCurrentColor")) return error.MissingCurrentColorQuery;
    const original = try parsedColor("light-dark(red,color-mix(in srgb,currentcolor,blue))");
    defer original.release();
    try testing.expect(original.containsCurrentColor());
    const light = try original.resolveComputed(allocator, .{ .scheme = .light });
    defer light.release();
    try testing.expect(!light.containsCurrentColor());
    const dark = try original.resolveComputed(allocator, .{ .scheme = .dark });
    defer dark.release();
    try testing.expect(dark.containsCurrentColor());
    const used = try dark.resolveComputed(allocator, .{ .current = Color.black });
    defer used.release();
    try testing.expect(!used.containsCurrentColor());
}

test "follow-up Q135 retains the normative powerless hue boundary" {
    // Q135 FINAL: integrator-probes-1023v/results/q135-{chrome,firefox,safari}.json.
    // No threshold/precision mechanism has a majority across the boundary;
    // Color 4 §4.4.1's 4e-6 threshold in f64 remains the rule.
    inline for (.{ "0.000003", "0.0000041", "0.000005", "0.000009", "0.000011" }) |x| {
        const origin = "oklab(0.2 " ++ x ++ " -0.000000001)";
        const opponent = comptime std.fmt.parseFloat(f64, x) catch unreachable;
        const powerless = opponent < 0.000004;
        inline for (.{ "oklch(from " ++ origin ++ " l c h)", "color-mix(in oklch, " ++ origin ++ ")" }) |input_text| {
            const input = try parsedColor(input_text);
            defer input.release();
            const result = try input.resolveComputed(allocator, .{});
            defer result.release();
            const components = result.expression.data.resolved.value;
            try testing.expectEqual(powerless, components.absent(2));
            try testing.expectApproxEqAbs(@as(f64, 0.2), components.channel(0), 1e-12);
            if (powerless) {
                try testing.expectEqual(@as(f64, 0), components.channel(1));
                try testing.expectEqual(@as(f64, 0), components.channel(2));
            } else {
                try testing.expectApproxEqAbs(@sqrt(opponent * opponent + 1e-18), components.channel(1), 1e-12);
                try testing.expect(components.channel(2) > 359 and components.channel(2) < 360);
            }
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(allocator);
            try result.serializeComputed(&text, allocator);
            const reparsed = try parsedColor(text.items);
            defer reparsed.release();
            const again = try reparsed.resolveComputed(allocator, .{});
            defer again.release();
            var roundtrip: std.ArrayList(u8) = .empty;
            defer roundtrip.deinit(allocator);
            try again.serializeComputed(&roundtrip, allocator);
            try testing.expectEqualStrings(text.items, roundtrip.items);
        }
    }
}
