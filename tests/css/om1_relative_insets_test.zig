//! CSSOM §9 and CSS Positioned Layout 3 §3.3, style-only inset resolution.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Longhand = css.properties.Longhand;
const Computed = css.computed_style.ComputedStyle;

fn make(allocator: std.mem.Allocator, text: []const u8) !*Computed {
    var declarations = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer declarations.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &declarations, .source = .{ .origin = .author } }});
}

fn resolved(allocator: std.mem.Allocator, style: *const Computed, property: Longhand, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(property, &text, allocator);
    try std.testing.expectEqualStrings(expected, text.items);
}

fn physical(allocator: std.mem.Allocator) !void {
    const style = try make(allocator, "display: block; position: relative; top: auto; bottom: 3px; left: calc(2px + 3px); right: auto");
    defer style.destroy();
    try resolved(allocator, style, .top, "-3px");
    try resolved(allocator, style, .bottom, "3px");
    try resolved(allocator, style, .left, "5px");
    try resolved(allocator, style, .right, "-5px");
    // CSS Typed OM and inherit still see the computed values, not these
    // CSSOM resolved values. Reading never rewrites the computed style.
    try std.testing.expectEqual(css.style_values.Keyword.auto, style.get(.top).keyword);
    try std.testing.expectEqual(css.style_values.Keyword.auto, style.get(.right).keyword);
}

test "relative auto physical sides negate the opposite absolute computed length with OOM cleanup" {
    try std.testing.checkAllAllocationFailures(a, physical, .{});
}

test "relative both-auto zero and over-constrained non-auto sides preserve their computed values" {
    const zero = try make(a, "display: block; position: relative");
    defer zero.destroy();
    for ([_]Longhand{ .top, .right, .bottom, .left, .inset_block_start, .inset_block_end, .inset_inline_start, .inset_inline_end }) |property|
        try resolved(a, zero, property, "0px");
    const specified = try make(a, "display: block; position: relative; top: 1px; right: 2px; bottom: 3px; left: 4px");
    defer specified.destroy();
    for ([_]Longhand{ .top, .right, .bottom, .left }, [_][]const u8{ "1px", "2px", "3px", "4px" }) |property, expected|
        try resolved(a, specified, property, expected);
}

test "logical auto insets follow their existing physical mapping for all writing modes and directions" {
    for ([_][]const u8{ "horizontal-tb", "vertical-rl", "vertical-lr", "sideways-rl", "sideways-lr" }) |mode| {
        for ([_][]const u8{ "ltr", "rtl" }) |direction| {
            const input = try std.fmt.allocPrint(a, "display:block; position:relative; writing-mode:{s}; direction:{s}; inset-inline-start:auto; inset-inline-end:2em; inset-block-start:3px; inset-block-end:auto; font-size:10px", .{ mode, direction });
            defer a.free(input);
            const style = try make(a, input);
            defer style.destroy();
            try resolved(a, style, .inset_inline_start, "-20px");
            try resolved(a, style, .inset_inline_end, "20px");
            try resolved(a, style, .inset_block_start, "3px");
            try resolved(a, style, .inset_block_end, "-3px");
        }
    }
}

test "relative inset resolver leaves geometry other positions and non-applicable display untouched" {
    for ([_][]const u8{
        "display:block; position:relative; bottom:20%; right:calc(10% + 2px)",
        "display:none; position:relative; bottom:3px; right:4px",
        "display:contents; position:relative; bottom:3px; right:4px",
        "display:table-column; position:relative; bottom:3px; right:4px",
        "display:table-column-group; position:relative; bottom:3px; right:4px",
        "display:block; position:static; bottom:3px; right:4px",
        "display:block; position:sticky; bottom:3px; right:4px",
        "display:block; position:absolute; bottom:3px; right:4px",
        "display:block; position:fixed; bottom:3px; right:4px",
    }) |input| {
        const style = try make(a, input);
        defer style.destroy();
        try resolved(a, style, .top, "auto");
        try resolved(a, style, .left, "auto");
    }
}
