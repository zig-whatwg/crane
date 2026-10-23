//! Filter Effects1 §§6.2–6.3: computed currentcolor remains symbolic.
//! WPT css/filter-effects/drop-shadow-currentcolor-inheritance.html passes
//! both assertions in aligned Chrome, Firefox and Safari runs (2026-10-22).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn inheritance(allocator: std.mem.Allocator, filter: []const u8) !void {
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;font-size:20px");
    defer parent_block.deinit();
    try testing.expect(try parent_block.setProperty(.{ .allocator = allocator }, "filter", filter, ""));
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:green;font-size:10px;filter:inherit");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    parent_block.clear();
    child_block.clear();
    // The child borrows the parent's computed filter, with absolute parent
    // lengths but currentcolor still resolved against the receiving element.
    const filter_value = child.get(.filter);
    try testing.expect(filter_value == .filter);
    const shadow = filter_value.filter.items[0].function.argument.shadow;
    try testing.expect(shadow.color.?.eql(.current));
    try testing.expectEqual(@as(f64, 20), shadow.lengths[0].length.value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings("drop-shadow(rgb(0, 128, 0) 20px 2px 0px)", out.items);
    out.clearRetainingCapacity();
    try parent.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings("drop-shadow(rgb(255, 0, 0) 20px 2px 0px)", out.items);
}

test "inherited drop shadows preserve currentcolor and absolute parent lengths" {
    for ([_][]const u8{ "drop-shadow(1em 2px currentcolor)", "drop-shadow(1em 2px)" }) |filter| {
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{filter});
    }
}
