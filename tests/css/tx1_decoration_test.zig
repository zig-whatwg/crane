//! CSS Text Decoration 3/4: specified values, computed ownership and defaults.
const std = @import("std");
const css = @import("css");

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingDecorationProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;color:red");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try std.testing.expectEqualStrings(specified, out.items);
    if (specified.len == 0) return;
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px;color:red");
    defer child_block.deinit();
    _ = try child_block.setProperty(.{ .allocator = allocator }, name, "inherit", "");
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    if (property == .shorthand) return;
    for ([_]*const css.computed_style.ComputedStyle{ parent, child }) |style| {
        out.clearRetainingCapacity();
        try style.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(computed, out.items);
    }
}

test "decoration keyword groups canonicalize while rejecting duplicates and interleaving" {
    const cases = .{
        .{ "text-decoration-line", "blink line-through overline underline", "underline overline line-through blink" },
        .{ "text-decoration-line", "spelling-error", "spelling-error" },
        .{ "text-decoration-line", "grammar-error", "grammar-error" },
        .{ "text-decoration-skip-spaces", "end start", "start end" },
        .{ "text-underline-position", "left from-font", "from-font left" },
        .{ "text-emphasis-position", "auto", "auto" },
    };
    inline for (cases) |c| try check(std.testing.allocator, c[0], c[1], c[2], c[2]);
    try check(std.testing.allocator, "text-emphasis-position", "right under", "under right", "under");
    try check(std.testing.allocator, "text-emphasis-position", "over right", "over right", "over");
    const invalid = .{
        .{ "text-decoration-line", "underline underline" },
        .{ "text-decoration-line", "spelling-error underline" },
        .{ "text-decoration-skip-spaces", "all start" },
        .{ "text-underline-position", "under from-font" },
        .{ "text-underline-position", "left auto" },
        .{ "text-emphasis-position", "left" },
        .{ "text-emphasis-position", "auto over" },
        .{ "text-emphasis-style", "filled circle open" },
        .{ "text-decoration", "overline blue underline" },
        .{ "text-emphasis", "filled red circle" },
    };
    inline for (invalid) |c| try check(std.testing.allocator, c[0], c[1], "", "");
}

test "decoration numeric values compute before explicit inheritance" {
    const cases = .{
        .{ "text-decoration-thickness", "-0.5em", "-0.5em", "-10px" },
        .{ "text-decoration-thickness", "calc(20% - 1em)", "calc(20% - 1em)", "calc(20% - 20px)" },
        .{ "text-underline-offset", "-2em", "-2em", "-40px" },
        .{ "text-decoration-inset", "2em 2em", "2em", "40px" },
        .{ "text-decoration-inset", "calc(20% + 1em) -1em", "calc(20% + 1em) -1em", "calc(20% + 20px) -20px" },
    };
    inline for (cases) |c| try check(std.testing.allocator, c[0], c[1], c[2], c[3]);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-decoration-inset", "calc(20% + 1em) -1em", "calc(20% + 1em) -1em", "calc(20% + 20px) -20px" });
}

test "decoration shorthands reset defaults and keep each component group contiguous" {
    try check(std.testing.allocator, "text-decoration", "double overline underline", "underline overline double", "");
    try check(std.testing.allocator, "text-decoration", "underline solid currentcolor auto", "underline", "");
    try check(std.testing.allocator, "text-decoration", "red from-font overline", "overline from-font red", "");
    try check(std.testing.allocator, "text-emphasis", "red filled circle", "filled circle red", "");
    try check(std.testing.allocator, "text-emphasis", "currentcolor", "none", "");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-decoration", "red calc(2em + 1px) underline", "underline calc(2em + 1px) red", "" });
}

fn emphasis(allocator: std.mem.Allocator, writing_mode: []const u8, input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup("text-emphasis-style") orelse return error.MissingDecorationProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "writing-mode", writing_mode, "");
    _ = try block.setProperty(.{ .allocator = allocator }, "text-emphasis-style", input, "");
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "writing-mode:horizontal-tb;text-orientation:upright");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for ([_]*const css.computed_style.ComputedStyle{ parent, child }) |style| {
        out.clearRetainingCapacity();
        try style.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(expected, out.items);
    }
}

test "emphasis shape follows typographic mode then inherits its computed shape" {
    try emphasis(std.testing.allocator, "horizontal-tb", "filled", "circle");
    try emphasis(std.testing.allocator, "vertical-rl", "open", "open sesame");
    try emphasis(std.testing.allocator, "vertical-lr", "filled circle", "circle");
    try emphasis(std.testing.allocator, "sideways-rl", "open", "open circle");
    try check(std.testing.allocator, "text-emphasis-style", "'abc'", "\"abc\"", "\"abc\"");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, emphasis, .{ "vertical-rl", "open", "open sesame" });
}

test "text shadows keep the Decor3 three-length grammar and compute each length" {
    try check(std.testing.allocator, "text-shadow", "1em 2em red, blue -1px 2px 3px", "red 1em 2em, blue -1px 2px 3px", "rgb(255, 0, 0) 20px 40px 0px, rgb(0, 0, 255) -1px 2px 3px");
    try check(std.testing.allocator, "text-shadow", "1px 2px calc(-1px)", "1px 2px calc(-1px)", "rgb(255, 0, 0) 1px 2px 0px");
    inline for (.{ "1px 2px 3px 4px", "inset 1px 2px", "1px red 2px", "1px 2px -1px", "1% 2px", "1px 2px,", "none, 1px 2px" }) |input| try check(std.testing.allocator, "text-shadow", input, "", "");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-shadow", "1em 2em red, blue -1px 2px 3px", "red 1em 2em, blue -1px 2px 3px", "rgb(255, 0, 0) 20px 40px 0px, rgb(0, 0, 255) -1px 2px 3px" });
}

fn checkDefaults(allocator: std.mem.Allocator) !void {
    const cases = .{
        .{ "text-decoration-line", "underline", "none" },
        .{ "text-decoration-style", "wavy", "solid" },
        .{ "text-decoration-color", "red", "rgb(0, 0, 255)" },
        .{ "text-decoration-thickness", "2em", "auto" },
        .{ "text-decoration-inset", "2em 1em", "0px" },
        .{ "text-decoration-skip-ink", "none", "none" },
        .{ "text-decoration-skip-spaces", "end", "end" },
        .{ "text-underline-position", "under left", "under left" },
        .{ "text-underline-offset", "2em", "40px" },
        .{ "text-emphasis-color", "currentcolor", "rgb(0, 0, 255)" },
        .{ "text-emphasis-position", "under left", "under left" },
        .{ "text-emphasis-style", "circle", "circle" },
        .{ "text-shadow", "1em 2em", "rgb(0, 0, 255) 20px 40px 0px" },
    };
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;color:red");
    defer block.deinit();
    inline for (cases) |entry| _ = try block.setProperty(.{ .allocator = allocator }, entry[0], entry[1], "");
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px;color:blue");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    inline for (cases) |entry| {
        const property = css.properties.lookup(entry[0]) orelse return error.MissingDecorationProperty;
        out.clearRetainingCapacity();
        try child.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(entry[2], out.items);
    }
    const initial = try css.computed_style.ComputedStyle.initial(allocator);
    defer initial.destroy();
    inline for (.{ .{ "text-decoration-skip-spaces", "start end" }, .{ "text-emphasis-position", "over" } }) |entry| {
        const property = css.properties.lookup(entry[0]) orelse return error.MissingDecorationProperty;
        out.clearRetainingCapacity();
        try initial.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(entry[1], out.items);
    }
}

test "decoration defaults and inheritance preserve symbolic colors and absolute lengths" {
    try checkDefaults(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkDefaults, .{});
}
