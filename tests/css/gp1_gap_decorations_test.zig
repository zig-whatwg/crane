//! Lane gaps1: CSS Gap Decorations 1 (§§3.2-3.5, §4) - parsing, computed
//! values and CSSOM serialization, no geometry. Expectations are the pinned
//! WPT css/css-gaps/parsing files (Chrome 156 passes all of them; wpt.fyi
//! stable run 07ce6e987a) and the spec's §4.8 examples.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const Value = css.style_values.Value;

/// getComputedStyle's reading: a longhand's resolved value; a shorthand's
/// serialization from its longhands' resolved components (as
/// CSSStyleDeclaration.computedValue builds them).
fn read(style: *const Style, name: []const u8, out: *std.ArrayList(u8), allocator: Allocator) !void {
    const property = css.properties.lookup(name) orelse return error.MissingGapProperty;
    if (property == .longhand) return style.serializeResolved(property.longhand, out, allocator);
    var resolved: [css.properties.max_non_all_assignments]Value = undefined;
    var assigned: [css.properties.max_non_all_assignments]css.properties.Assigned = undefined;
    var initialized: usize = 0;
    defer for (resolved[0..initialized]) |value| value.release();
    const longhands = property.shorthand.longhands();
    for (longhands, 0..) |l, i| {
        const value = style.get(l);
        if (value == .color) {
            resolved[i] = .{ .color = try style.resolvedColor(l, allocator) };
        } else if (value == .gap_list) {
            resolved[i] = try style.resolvedGapList(l, allocator);
        } else {
            value.retain();
            resolved[i] = value;
        }
        initialized += 1;
        assigned[i] = .{ .value = resolved[i] };
    }
    const start = out.items.len;
    if (!try css.properties.serializeShorthand(property.shorthand, assigned[0..longhands.len], .computed, out, allocator))
        out.shrinkRetainingCapacity(start);
}

fn compute(allocator: Allocator, block: *const Block) !*Style {
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = block, .source = .{ .origin = .author } }});
}

/// Set `name: input` on a block that also sets `prelude`, then read it back
/// specified (resolved false) or computed. An empty expectation means the
/// value is rejected (specified) or serializes as "" (computed).
fn checkWith(allocator: Allocator, prelude: []const u8, name: []const u8, input: []const u8, expected: []const u8, resolved: bool) !void {
    _ = css.properties.lookup(name) orelse return error.MissingGapProperty;
    var block = try Block.parse(.{ .allocator = allocator }, prelude);
    defer block.deinit();
    const accepted = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    if (!resolved) try testing.expectEqual(expected.len > 0, accepted);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (resolved) {
        try testing.expect(accepted);
        const style = try compute(allocator, &block);
        defer style.destroy();
        try read(style, name, &out, allocator);
    } else try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn valid(name: []const u8, input: []const u8, expected: []const u8) !void {
    try checkWith(testing.allocator, "", name, input, expected, false);
}

fn same(name: []const u8, input: []const u8) !void {
    try valid(name, input, input);
}

fn invalid(name: []const u8, input: []const u8) !void {
    try checkWith(testing.allocator, "", name, input, "", false);
}

fn computedAs(name: []const u8, input: []const u8, expected: []const u8) !void {
    try checkWith(testing.allocator, "color: lime; font-size: 40px; column-rule-style: dotted; row-rule-style: dashed", name, input, expected, true);
}

const list_axes = [_][]const u8{ "column-rule", "row-rule", "rule" };

test "color, style and width lists keep their items and repeat() notations" {
    inline for (list_axes) |axis| {
        inline for (.{
            "repeat(4, blue)",                "repeat(3, red, green, blue)",     "red",
            "green, blue",                    "repeat(3, blue), repeat(4, red)", "red, repeat(3, blue), blue, repeat(4, red, green, cyan)",
            "repeat(auto, red, green, blue)", "repeat(auto, red, green), red",   "blue, repeat(auto, red, green), repeat(4, blue, red, green)",
        }) |input| try same(axis ++ "-color", input);
        inline for (.{
            "repeat(4, dotted)", "dashed, solid", "repeat(auto, solid, double), none", "hidden",
        }) |input| try same(axis ++ "-style", input);
        inline for (.{
            "repeat(4, thin)",                                             "10px, 15px", "repeat(auto, 10px, 20px), 30px", "medium",
            "10px, repeat(auto, 20px, 30px), repeat(4, thin, 50px, 60px)",
        }) |input| try same(axis ++ "-width", input);
    }
}

test "malformed lists and repeaters are rejected by every list property" {
    inline for (list_axes) |axis| {
        inline for (.{
            "",                                           "red,",                         ", red",                        "red,,blue",
            "repeat()",                                   "repeat(0, red)",               "repeat(-1, red, blue, green)", "repeat(auto, )",
            "repeat(auto, red), red, repeat(auto, blue)", "repeat(auto, red blue green)", "red blue",                     "repeat(2, repeat(2, red))",
            "repeat(auto)",                               "repeat(2)",                    "repeat(1.5, red)",             "repeat(2 red)",
        }) |input| try invalid(axis ++ "-color", input);
        inline for (.{ "repeat(2, -20px)", "30%", "10 20 30", "thin medium thick", "repeat(auto, thin 10px thick)" }) |input|
            try invalid(axis ++ "-width", input);
        inline for (.{ "dashed dotted solid", "repeat(auto, groove dotted ridge)", "repeat(0, dotted, solid)" }) |input|
            try invalid(axis ++ "-style", input);
    }
}

test "computed lists resolve colors, snap widths and compute repeat counts" {
    inline for (list_axes) |axis| {
        try computedAs(axis ++ "-color", "currentcolor", "rgb(0, 255, 0)");
        try computedAs(axis ++ "-color", "repeat(4, yellow)", "repeat(4, rgb(255, 255, 0))");
        try computedAs(axis ++ "-color", "red, green, blue", "rgb(255, 0, 0), rgb(0, 128, 0), rgb(0, 0, 255)");
        try computedAs(axis ++ "-color", "repeat(auto, red, currentcolor)", "repeat(auto, rgb(255, 0, 0), rgb(0, 255, 0))");
        try computedAs(axis ++ "-color", "repeat(calc(5 + 3), salmon)", "repeat(8, rgb(250, 128, 114))");
        try computedAs(axis ++ "-color", "repeat(auto, rgb(from lime r g b))", "repeat(auto, color(srgb 0 1 0))");
        try computedAs(axis ++ "-width", "calc(10px + 0.5em)", "30px");
        try computedAs(axis ++ "-width", "repeat(5, 10px, calc(10px + 0.5em))", "repeat(5, 10px, 30px)");
        try computedAs(axis ++ "-width", "repeat(auto, min(5px, 10px)), repeat(5, 10px), calc(10px + 0.5em)", "repeat(auto, 5px), repeat(5, 10px), 30px");
        try computedAs(axis ++ "-width", "thin, medium, thick", "1px, 3px, 5px");
        try computedAs(axis ++ "-style", "repeat(auto, solid, none), hidden", "repeat(auto, solid, none), hidden");
    }
}

test "a single plain item stays the classic multicol value" {
    var block = try Block.parse(.{ .allocator = testing.allocator }, "column-rule: 5px solid red; row-rule-color: repeat(2, red)");
    defer block.deinit();
    const style = try compute(testing.allocator, &block);
    defer style.destroy();
    try testing.expect(style.get(.column_rule_color) == .color);
    try testing.expect(style.get(.column_rule_style) == .keyword);
    try testing.expect(style.get(.column_rule_width) == .length);
    try testing.expect(style.get(.row_rule_color) == .gap_list);
}

test "rule shorthands expand to aligned lists and serialize back only when repeater aligned" {
    inline for (list_axes) |axis| {
        inline for (.{
            "5px solid red",                                    "double",
            "repeat(auto, 5px solid green)",                    "repeat(auto, 6px blue, 5px solid red)",
            "repeat(4, 15px dotted pink)",                      "repeat(4, blue, 5px red)",
            "repeat(3, 16px, thin dashed purple, 10px dotted)", "thick, dashed, hotpink",
            "5px double salmon, repeat(4, 5px ridge red)",      "10px dotted blue, repeat(4, blue, 5px yellow), repeat(auto, 5px solid red)",
        }) |input| try same(axis, input);
        try valid(axis, "solid 10px rgb(0, 0, 255)", "10px solid rgb(0, 0, 255)");
        try valid(axis, "blue 6px", "6px blue");
        try valid(axis, "currentcolor hidden medium", "hidden");
        try valid(axis, "currentcolor none medium", "medium");
        inline for (.{
            "",                                  "red 5px solid red",  "repeat(auto, 5px solid red), 5px solid red, repeat(auto, 5px solid red)",
            "repeat(auto, red 5px green ridge)", "repeat(0, 5px red)", "5px solid red,",
        }) |input| try invalid(axis, input);
    }
    // §4.8: the longhands' items, read through the column shorthand.
    var block = try Block.parse(.{ .allocator = testing.allocator }, "column-rule: repeat(auto, blue 6px, 5px solid red)");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    inline for (.{
        .{ "column-rule-width", "repeat(auto, 6px, 5px)" },
        .{ "column-rule-style", "repeat(auto, none, solid)" },
        .{ "column-rule-color", "repeat(auto, blue, red)" },
    }) |case| {
        out.clearRetainingCapacity();
        try block.getPropertyValue(case[0], &out);
        try testing.expectEqualStrings(case[1], out.items);
    }
    // Not repeater aligned: the shorthand is "" (spec §4.8's three examples).
    inline for (.{
        .{ "column-rule: repeat(auto, 1px solid red, 2px dashed green); column-rule-width: repeat(auto, 3px, 4px, 5px)", "column-rule" },
        .{ "column-rule: repeat(2, 1px solid red, 2px dashed green); column-rule-style: dashed, dotted, solid", "column-rule" },
        .{ "column-rule: repeat(2, 1px solid red, 2px dashed green); column-rule-color: repeat(4, red, cyan)", "column-rule" },
        .{ "column-rule: 5px solid red; row-rule: 6px solid red", "rule" },
        .{ "column-rule-color: red; row-rule-color: blue", "rule-color" },
    }) |case| {
        var mixed = try Block.parse(.{ .allocator = testing.allocator }, case[0]);
        defer mixed.deinit();
        out.clearRetainingCapacity();
        try mixed.getPropertyValue(case[1], &out);
        try testing.expectEqualStrings("", out.items);
    }
    // Longhands set directly serialize through the shorthand the same way.
    var direct = try Block.parse(.{ .allocator = testing.allocator }, "column-rule-width: 1px, repeat(2, 2px); column-rule-style: solid, repeat(2, dashed); column-rule-color: red, repeat(2, green)");
    defer direct.deinit();
    out.clearRetainingCapacity();
    try direct.getPropertyValue("column-rule", &out);
    try testing.expectEqualStrings("1px solid red, repeat(2, 2px dashed green)", out.items);
}

test "computed rule shorthands write every width and color" {
    inline for (list_axes) |axis| {
        try computedAs(axis, "5px solid currentcolor", "5px solid rgb(0, 255, 0)");
        try computedAs(axis, "dotted", "3px dotted rgb(0, 255, 0)");
        try computedAs(axis, "repeat(auto, 5px solid rgb(255, 255, 0), 10px dotted rgb(0, 128, 0))", "repeat(auto, 5px solid rgb(255, 255, 0), 10px dotted rgb(0, 128, 0))");
        try computedAs(axis, "10px dotted rgb(0, 128, 128), repeat(4, 20px hidden rgb(0, 128, 128), 30px ridge rgb(255, 0, 255)), repeat(auto, 5px solid rgb(255, 0, 255))", "10px dotted rgb(0, 128, 128), repeat(4, 20px hidden rgb(0, 128, 128), 30px ridge rgb(255, 0, 255)), repeat(auto, 5px solid rgb(255, 0, 255))");
        try computedAs(axis, "repeat(2, thin)", "repeat(2, 1px rgb(0, 255, 0))");
    }
}

test "rule-break, visibility-items and overlap are keyword longhands with both-axis shorthands" {
    inline for (.{ "column-rule-break", "row-rule-break", "rule-break" }) |name| {
        inline for (.{ "none", "normal", "intersection" }) |k| try same(name, k);
        inline for (.{ "auto", "10px", "none normal", "intersection, none" }) |k| try invalid(name, k);
        try computedAs(name, "intersection", "intersection");
    }
    inline for (.{ "column-rule-visibility-items", "row-rule-visibility-items", "rule-visibility-items" }) |name| {
        inline for (.{ "all", "around", "between", "normal" }) |k| try same(name, k);
        inline for (.{ "none", "all around" }) |k| try invalid(name, k);
        try computedAs(name, "between", "between");
    }
    inline for (.{ "row-over-column", "column-over-row" }) |k| try same("rule-overlap", k);
    inline for (.{ "auto", "none", "10px", "true" }) |k| try invalid("rule-overlap", k);
    try computedAs("rule-overlap", "column-over-row", "column-over-row");
    // A both-axis shorthand reads "" unless its two axes agree.
    try checkWith(testing.allocator, "row-rule-break: intersection", "column-rule-break", "none", "none", true);
    inline for (.{ .{ "intersection", "" }, .{ "none", "none" } }) |case| {
        var block = try Block.parse(.{ .allocator = testing.allocator }, "column-rule-break: none; row-rule-break: " ++ case[0] ++ "; column-rule-visibility-items: around; row-rule-visibility-items: all");
        defer block.deinit();
        const style = try compute(testing.allocator, &block);
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try read(style, "rule-break", &out, testing.allocator);
        try testing.expectEqualStrings(case[1], out.items);
        out.clearRetainingCapacity();
        try read(style, "rule-visibility-items", &out, testing.allocator);
        try testing.expectEqualStrings("", out.items);
    }
}

test "inset longhands and their shorthands follow §3.3's fill rules" {
    inline for (.{ "column-rule", "row-rule", "rule" }) |axis| {
        const full = axis ++ "-inset";
        try valid(full, "0", "0px");
        inline for (.{ "-20px", "5%", "calc(8em + 4ex)", "10px 20px / 30px -10px", "overlap-join", "overlap-join 10px / overlap-join 10px" }) |input| try same(full, input);
        try valid(full, "10px 20px", "10px 20px / 10px 20px");
        try valid(full, "10px 20px / -5px", "10px 20px / -5px -5px");
        try valid(full, "10px / 20px", "10px 10px / 20px 20px");
        try valid(full, "overlap-join overlap-join / overlap-join overlap-join", "overlap-join");
        inline for (.{ "/ 10px", "10", "10px / 20px / 10px", "10px 10px 20px", "10px blue", "auto", "none", "overlap-join garbage" }) |input| try invalid(full, input);
        inline for (.{ "-cap", "-junction" }) |part| {
            try valid(full ++ part, "0", "0px");
            inline for (.{ "-20px", "5% 10%", "overlap-join", "calc(8em + 4ex)" }) |input| try same(full ++ part, input);
            try valid(full ++ part, "5% 5%", "5%");
            inline for (.{ "10px 20px 30px", "10px / 20px", "auto" }) |input| try invalid(full ++ part, input);
        }
        inline for (.{ "-start", "-end" }) |part| {
            inline for (.{ "-20px", "5%", "overlap-join" }) |input| try same(full ++ part, input);
            inline for (.{ "10px 20px", "auto" }) |input| try invalid(full ++ part, input);
        }
        try computedAs(full, "0.5em", "20px");
        try computedAs(full, "calc(10px - 0.5em)", "-10px");
        try computedAs(full, "calc(25% + 10px)", "calc(25% + 10px)");
        try computedAs(full, "5% / 15% 20%", "5% 5% / 15% 20%");
        try computedAs(full, "10px overlap-join / 10px overlap-join", "10px overlap-join / 10px overlap-join");
    }
    // Longhand expansion.
    var block = try Block.parse(.{ .allocator = testing.allocator }, "rule-inset: 10px / 20px 30px; column-rule-inset-cap-end: 1px");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    inline for (.{
        .{ "row-rule-inset-cap-start", "10px" },          .{ "row-rule-inset-cap-end", "10px" },
        .{ "row-rule-inset-junction-start", "20px" },     .{ "row-rule-inset-junction-end", "30px" },
        .{ "column-rule-inset", "10px 1px / 20px 30px" }, .{ "rule-inset", "" },
        .{ "row-rule-inset-start", "" },                  .{ "row-rule-inset-cap", "10px" },
        .{ "rule-inset-junction", "20px 30px" },
    }) |case| {
        out.clearRetainingCapacity();
        try block.getPropertyValue(case[0], &out);
        try testing.expectEqualStrings(case[1], out.items);
    }
}

test "css-wide keywords and var() reach every gap decoration property" {
    inline for (.{ "rule", "rule-color", "rule-inset", "rule-break", "column-rule-inset-cap-start" }) |name| {
        inline for (.{ "inherit", "initial", "unset", "revert" }) |k| try same(name, k);
    }
    try checkWith(testing.allocator, "--c: red, repeat(2, blue)", "row-rule-color", "var(--c)", "rgb(255, 0, 0), repeat(2, rgb(0, 0, 255))", true);
    try checkWith(testing.allocator, "--r: 5px solid red, repeat(auto, 1px dotted blue)", "rule", "var(--r)", "5px solid rgb(255, 0, 0), repeat(auto, 1px dotted rgb(0, 0, 255))", true);
}

fn listRoundTrip(allocator: Allocator) !void {
    var block = Block.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "rule", "10px dotted blue, repeat(4, rgb(from red r g b) 5px), repeat(auto, 5px solid currentcolor)", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "row-rule-width", "repeat(calc(1 + 2), calc(1px + 1em), thin)", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "rule-inset", "calc(1em + 2%) 3px / overlap-join", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "rule-break", "intersection", "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("column-rule", &out);
    try block.getPropertyValue("rule", &out);
    try block.getPropertyValue("row-rule-width", &out);
    const style = try compute(allocator, &block);
    defer style.destroy();
    inline for (.{ "rule", "column-rule", "row-rule-width", "row-rule-color", "rule-inset", "rule-break" }) |name|
        try read(style, name, &out, allocator);
    // Inheritance shares the computed list by reference.
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = style }, &.{});
    defer child.destroy();
}

test "gap decoration parse, compute, inherit and serialize release every allocation failure" {
    try listRoundTrip(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, listRoundTrip, .{});
}

fn inheritExplicit(allocator: Allocator) !void {
    var parent_block = try Block.parse(.{ .allocator = allocator }, "column-rule-color: red, repeat(auto, blue)");
    defer parent_block.deinit();
    const parent = try compute(allocator, &parent_block);
    defer parent.destroy();
    var block = try Block.parse(.{ .allocator = allocator }, "column-rule-color: inherit; row-rule-color: repeat(2, red)");
    defer block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try testing.expect(child.get(.column_rule_color).eql(parent.get(.column_rule_color)));
    try testing.expect(!child.get(.row_rule_color).eql(parent.get(.column_rule_color)));
}

test "an inherited gap list is shared, and every reference is released under allocation failure" {
    try inheritExplicit(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, inheritExplicit, .{});
}
