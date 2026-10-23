//! Values4 §8.3 and Values5 §4.2: physical and logical positions without layout.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectPosition(input: []const u8, declarations: []const u8, expected: []const u8) !void {
    const p = css.properties.lookup("object-position") orelse return error.PositionNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments));
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, declarations);
    defer block.deinit();
    try block.entries.ensureUnusedCapacity(testing.allocator, 1);
    assignments.items[0].value.retain();
    block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = p.longhand, .value = assignments.items[0].value, .important = false } });
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(p.longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "object-position computes physical edges and inward offsets" {
    try expectPosition("top", "", "50% 0%");
    try expectPosition("20%", "", "20% 50%");
    try expectPosition("right 20% bottom 10px", "", "80% calc(100% - 10px)");
    try expectPosition("right -1em bottom -2%", "font-size:20px", "calc(100% + 20px) 102%");
    try expectPosition("right 0px bottom 0px", "", "100% 100%");
}

test "position logical axes use the element writing mode and direction" {
    try expectPosition("x-start y-start", "direction:rtl", "100% 0%");
    try expectPosition("x-start y-start", "writing-mode:vertical-rl;direction:rtl", "100% 100%");
    try expectPosition("x-start y-start", "writing-mode:sideways-lr;direction:ltr", "0% 100%");
    try expectPosition("block-start inline-end", "writing-mode:horizontal-tb;direction:ltr", "100% 0%");
    try expectPosition("block-start inline-end", "writing-mode:vertical-rl;direction:ltr", "100% 100%");
    try expectPosition("block-start 1em inline-end 20%", "writing-mode:vertical-rl;direction:ltr;font-size:20px", "calc(100% - 20px) 80%");
    try expectPosition("start end", "writing-mode:horizontal-tb;direction:ltr", "100% 0%");
}

test "mask and object position reject the background-only three value grammar" {
    for ([_][]const u8{ "object-position", "mask-position" }) |name| {
        const p = css.properties.lookup(name) orelse return error.PositionNotImplemented;
        for ([_][]const u8{ "left 1px top", "right top 2px", "center left 1px", "bottom 2% center", "top 2%", "left right", "start left", "auto" }) |input| {
            var assignments: std.ArrayList(css.properties.Assignment) = .empty;
            defer {
                for (assignments.items) |a| a.value.release();
                assignments.deinit(testing.allocator);
            }
            try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments));
        }
    }
}
